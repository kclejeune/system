{ config, ... }:
let
  flakeCfg = config;
in
{
  flake.nixosModules.hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      theme = flakeCfg.flake.lib.mkTheme pkgs;

      # First-boot seed only; noctalia's wallpaperChange hook keeps the
      # runtime copy in sync afterwards.
      greeterBackground =
        pkgs.runCommandLocal "regreet-background.png"
          {
            nativeBuildInputs = [ pkgs.imagemagick ];
          }
          ''
            magick ${./assets/regreet-background.png} -blur 0x16 $out
          '';

      # regreet draws [background] via GStreamer, but nixpkgs' wrapper never
      # sets GST_PLUGIN_SYSTEM_PATH, so it aborts on the first frame and
      # greetd crash-loops. Direct buildInputs make wrapGAppsHook4 set it.
      regreet = pkgs.regreet.overrideAttrs (old: {
        buildInputs =
          (old.buildInputs or [ ])
          ++ (with pkgs.gst_all_1; [
            gstreamer
            gst-plugins-base
            gst-plugins-good
          ]);
      });

      # greetd gives the session tty1 as stdio: route stderr to the journal
      # so mesa/wlroots/libseat noise doesn't paint over the splash, and
      # clear tty1 around cage (it SIGSEGVs on teardown, leaving fbcon
      # scrollback visible). The -w guard avoids a "Permission denied" on
      # tty1 before logind hands the greeter ownership.
      greeterCommand = pkgs.writeShellScript "greeter-session" ''
        exec 2> >(${pkgs.systemd}/bin/systemd-cat -t greeter-session)

        clear_tty1() {
          if [ -w /dev/tty1 ]; then
            ${pkgs.util-linux}/bin/setterm --clear all --cursor off >/dev/tty1
          fi
        }
        clear_tty1
        trap clear_tty1 EXIT

        # NOT `exec` — we need bash to outlive dbus-run-session so the
        # EXIT trap fires after cage returns. Without it the framebuffer
        # is left in whatever state cage left, and the kernel fbcon
        # redraws plymouth's retained splash (from `plymouth quit
        # --retain-splash`) into the cage→hyprland gap.
        ${pkgs.dbus}/bin/dbus-run-session \
          ${lib.getExe pkgs.cage} -s -m last -- ${greeterApp}
      '';

      # cage has no scale flag (regreet is tiny on HiDPI); the output may be
      # absent when docked, hence `|| true`.
      greeterScales = config.services.greeter.outputScales;
      greeterApp =
        if greeterScales == { } then
          lib.getExe regreet
        else
          pkgs.writeShellScript "regreet-scaled" ''
            ${lib.concatStrings (
              lib.mapAttrsToList (output: scale: ''
                ${lib.getExe pkgs.wlr-randr} --output ${output} --scale ${toString scale} || true
              '') greeterScales
            )}
            exec ${lib.getExe regreet}
          '';
    in
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
        withUWSM = true;
      };

      # withUWSM alone doesn't expose uwsm's template units to the user
      # manager, so `uwsm start` bounces back to the greeter.
      # waylandCompositors stays empty: its generated session file would
      # collide with the one pkgs.hyprland ships.
      programs.uwsm.enable = true;

      services.greetd = {
        enable = true;
        # With plymouth-quit ordered after greetd below, cage takes the
        # framebuffer before plymouth releases it: no fbcon flash.
        greeterManagesPlymouth = true;
        settings.default_session = {
          command = "${greeterCommand}";
          user = "greeter";
        };
      };

      # pam_systemd sets HOME from passwd, overriding the unit's env; the
      # default /var/empty is unwritable and every toolkit warns onto tty1.
      users.users.greeter.home = "/var/lib/regreet";

      users.users.greeter.extraGroups = [ "tty" ];

      # cage SIGSEGVs on every greeter exit; skip the coredump journal flood.
      systemd.services.greetd.serviceConfig.LimitCORE = "0";

      # Both services inherit PID 1's stderr (tty1), so user-manager status
      # lines would paint over the cage→Hyprland handoff.
      systemd.services.greetd.serviceConfig.StandardError = "journal";
      systemd.services.greetd.serviceConfig.StandardOutput = "journal";
      systemd.services."user@".serviceConfig = {
        StandardError = "journal";
        StandardOutput = "journal";
        Environment = [
          "SYSTEMD_LOG_LEVEL=err"
          "SYSTEMD_LOG_TARGET=journal"
        ];
      };

      # We don't run seatd; skip libseat's failing probe, whose error lands on tty1.
      environment.variables.LIBSEAT_BACKEND = "logind";

      systemd.services.plymouth-quit.unitConfig.After = [ "greetd.service" ];

      # The kernel cmdline only quiets PID 1; the user manager's status
      # lines would otherwise hit tty1 during the handoff.
      systemd.user.settings.Manager = {
        LogLevel = "err";
        LogTarget = "journal";
        ShowStatus = "no";
      };

      # uwsm has no -q flag; its startup chatter would paint tty1.
      environment.variables.UWSM_SILENT_START = "1";

      # greetd substacks `login` (fingerprint then password), and fprintAuth
      # is inert there. A fingerprint login can't unlock the keyring, so
      # `greeter.fingerprint = false` points greetd's auth at a
      # fingerprint-free copy; tpm-keyring-unlock solves it with the TPM instead.
      assertions = [
        {
          assertion = config.services.greeter.fingerprint || !config.services.tpm-keyring-unlock.enable;
          message = "services.greeter.fingerprint = false conflicts with services.tpm-keyring-unlock, which owns greetd's auth stack.";
        }
      ];
      security.pam.services.greetd-password = lib.mkIf (!config.services.greeter.fingerprint) {
        fprintAuth = false;
        enableGnomeKeyring = true;
      };
      security.pam.services.greetd.rules.auth = lib.mkIf (!config.services.greeter.fingerprint) (
        lib.mkForce {
          password = {
            order = 100;
            control = "substack";
            modulePath = "greetd-password";
          };
        }
      );

      # ReGreet crashes if its compiled-in paths are missing. The seeded
      # state preselects the user + UWSM session (must match the .desktop
      # Name=); `C` lets ReGreet's own bookkeeping take over afterwards.
      systemd.tmpfiles.rules =
        let
          initialState = pkgs.writeText "regreet-initial-state.toml" ''
            last_user = "${config.user.name}"
            [user_to_last_sess]
            ${config.user.name} = "Hyprland (uwsm-managed)"
          '';
          # regreet.toml applies the theme after GTK init (one white
          # Adwaita frame), and greetd's PAM env drops GTK_THEME; only
          # settings.ini is read before the first frame.
          gtk4Settings = pkgs.writeText "regreet-gtk4-settings.ini" ''
            [Settings]
            gtk-theme-name=${theme.gtk.themeName}
            gtk-icon-theme-name=${theme.gtk.iconThemeName}
            gtk-cursor-theme-name=${theme.gtk.cursorName}
            gtk-font-name=${theme.gtk.fontName} 15
            gtk-application-prefer-dark-theme=true
          '';
        in
        [
          "d /var/lib/regreet 0755 greeter greeter - -"
          "d /var/log/regreet 0755 greeter greeter - -"
          "C /var/lib/regreet/state.toml 0644 greeter greeter - ${initialState}"
          # User-owned so the wallpaper hook can overwrite it; world-readable
          # for the greeter.
          "C /var/lib/regreet/background.png 0644 ${config.user.name} users - ${greeterBackground}"
          "d /var/lib/regreet/.config 0755 greeter greeter - -"
          "d /var/lib/regreet/.config/gtk-4.0 0755 greeter greeter - -"
          "L+ /var/lib/regreet/.config/gtk-4.0/settings.ini - - - - ${gtk4Settings}"
        ];

      systemd.services.greetd.environment = {
        HOME = "/var/lib/regreet";
        XDG_DATA_DIRS = "/run/current-system/sw/share";
        GTK_THEME = theme.gtk.themeName;
      };

      # The greeter looks these up by name; it can't see the user's HM profile.
      environment.systemPackages = [
        (pkgs.catppuccin-gtk.override {
          accents = [ theme.gtk.accent ];
          variant = theme.gtk.variant;
        })
        pkgs.catppuccin-cursors.mochaDark
        pkgs.papirus-icon-theme
      ];

      fonts.packages = [ pkgs.open-sans ];

      environment.etc."greetd/regreet.toml".text = ''
        [GTK]
        application_prefer_dark_theme = true
        cursor_theme_name = "${theme.gtk.cursorName}"
        cursor_blink = true
        # Greeter runs full-screen with proportionally larger UI than
        # a desktop window, so it gets a slightly larger font than the
        # shared `theme.gtk.fontSize` (13) the desktop apps use — the
        # family still tracks the theme constant.
        font_name = "${theme.gtk.fontName} 15"
        icon_theme_name = "${theme.gtk.iconThemeName}"
        theme_name = "${theme.gtk.themeName}"

        [commands]
        reboot = ["systemctl", "reboot"]
        poweroff = ["systemctl", "poweroff"]

        # Blurred wallpaper as the greeter backdrop. The path is a
        # tmpfile-managed slot (/var/lib/regreet/background.png)
        # rather than a /nix/store derivation so noctalia's
        # `wallpaperChange` hook can mutate it at runtime as the user
        # rotates wallpapers. Seeded from the build-time
        # `greeterBackground` fallback on first boot via tmpfiles `C`.
        # `Cover` fills the screen and preserves aspect, matching how
        # noctalia paints its lockscreen wallpaper.
        [background]
        path = "/var/lib/regreet/background.png"
        fit = "Cover"

        [appearance]
        greeting_msg = "Welcome back"

        [widget.clock]
        format = "%A, %B %-d  ·  %H:%M"
        resolution = "1s"
        timezone = "America/Toronto"
        label_width = 360
      '';

      # Styled to match noctalia's lock screen. Widget IDs come from
      # ReGreet's relm4 templates (src/gui/templates.rs).
      environment.etc."greetd/regreet.css".text =
        let
          p = theme.palettes.dark;
        in
        ''
          @define-color base #${p.base};
          @define-color mantle #${p.mantle};
          @define-color crust #${p.crust};
          @define-color surface0 #${p.surface0};
          @define-color surface1 #${p.surface1};
          @define-color overlay0 #${p.overlay0};
          @define-color text #${p.text};
          @define-color subtext1 #${p.subtext1};
          @define-color blue #${p.blue};
          @define-color lavender #${p.lavender};
          @define-color yellow #${p.yellow};
          @define-color red #${p.red};

          /* System font (Open Sans) across the whole greeter.
             regreet.toml's [GTK] font_name already sets gtk-font-name
             to "${theme.gtk.fontName} 15", but an explicit
             font-family here makes it unambiguous and survives any
             GTK default-font fallback. Per-widget font-size rules
             (the clock card, the hidden frame label) override the
             size; this rule only touches the family. */
          window, window * {
            font-family: "${theme.gtk.fontName}", sans-serif;
          }

          /* Opaque Catppuccin base behind everything. ReGreet draws
             the [background] wallpaper as a Gtk.Picture *child* of
             the window, on top of window.background — so this color
             is invisible once the wallpaper renders, but covers the
             one-frame gap during regreet's startup where the
             Picture hasn't loaded yet (otherwise the transparent
             window would show whatever cage/kernel-fb has, which
             reads as a brief light flash on logout transitions).
             We don't try to push the clock card down with
             padding-top here: it just moves the whole layout (clock
             still glued to its parent's top edge), so the visual
             relationship of "clock-at-screen-top" doesn't change. */
          window.background,
          #background {
            background-color: @base;
            color: @text;
          }

          /* GtkFrame renders its `label` widget as a title outside
             the styled box border (defaults to "regreet" — the app
             name). ReGreet doesn't expose a config knob for it, so
             we zero it out in CSS. `font-size: 0` collapses the
             glyph metrics; min-height: 0 + padding/margin zero
             reclaims the line of vertical space it was occupying. */
          #clock_frame > label {
            font-size: 0;
            min-height: 0;
            padding: 0;
            margin: 0;
          }

          /* Centered login frame — dark card floating over the
             blurred wallpaper. `@mantle` is one step darker than
             `@base` in Catppuccin Mocha, so the card reads as the
             deepest surface in the stack (wallpaper → window/base
             → card/mantle → entries/base). High alpha (0.9) keeps
             a hint of wallpaper bleed for the floating feel without
             the "frosted glass" weakness. */
          frame.background {
            background-color: alpha(@mantle, 0.9);
            border: 1px solid alpha(@overlay0, 0.4);
            border-radius: 24px;
            box-shadow: 0 12px 40px alpha(@crust, 0.6);
            padding: 16px 20px;
          }

          /* Welcome card at the top — noctalia uses a wider rounded
             pill containing greeting + date + time, floating with
             clear space above and rounded on all four corners.
             ReGreet's #clock_frame is the closest equivalent, but
             its relm4 template applies an inline_css that flattens
             the top two corners and zeroes the top margin to dock
             the card to the screen edge. `!important` beats inline
             styles, so we use it on the two properties ReGreet
             actually sets — border-radius and margin-top — and let
             the rest cascade normally. The toml-side clock format
             (`%A, %B %-d  ·  %H:%M`) is the date+time content,
             paired with `greeting_msg = "Welcome back"` above it. */
          #clock_frame {
            background-color: alpha(@mantle, 0.9);
            border: 1px solid alpha(@overlay0, 0.4);
            border-radius: 28px !important;
            box-shadow: 0 8px 32px alpha(@crust, 0.55);
            padding: 22px 48px;
            margin: 56px 0 0 0 !important;
            font-size: 22px;
            font-weight: 500;
            letter-spacing: 0.3px;
            color: @text;
          }

          /* Password / username inputs — pill shape, ~28px radius.
             Fully opaque so the input reads as a solid affordance
             rather than a frosted-glass overlay. The container
             frame is the only translucent surface at this layer. */
          entry,
          #secret_entry,
          #visible_entry,
          #username_entry,
          #session_entry {
            background-color: @base;
            border: 1px solid alpha(@overlay0, 0.5);
            border-radius: 28px;
            padding: 10px 20px;
            color: @text;
            caret-color: @lavender;
          }

          entry:focus,
          #secret_entry:focus,
          #visible_entry:focus {
            border-color: @lavender;
            box-shadow: 0 0 0 2px alpha(@lavender, 0.35);
          }

          /* All three buttons share the same surface as the cards —
             alpha(@mantle, 0.9), matching #clock_frame and
             frame.background — so the whole composition reads as one
             material. Only the outline + label color encodes the
             action semantics. Hover lifts the fill one shade lighter
             (alpha(@surface0, 0.9), same alpha) and saturates the
             outline, so the button reads as "pressed" without the
             fill ever picking up an accent tint. Matches noctalia's
             lock-screen pill row: identical neutral pills, only the
             border/text distinguishes the destructive action. */

          /* Login — primary action, lavender accent. */
          #login_button,
          button.suggested-action {
            background-image: none;
            background-color: alpha(@mantle, 0.9);
            border: 1px solid alpha(@lavender, 0.7);
            color: @lavender;
            border-radius: 24px;
            padding: 9px 28px;
            font-weight: 600;
          }

          #login_button:hover,
          button.suggested-action:hover {
            background-color: alpha(@surface0, 0.9);
            border-color: @lavender;
            color: @lavender;
          }

          /* Reboot — neutral action, blue accent. */
          #reboot_button {
            background-image: none;
            background-color: alpha(@mantle, 0.9);
            border: 1px solid alpha(@blue, 0.55);
            border-radius: 24px;
            color: @subtext1;
            padding: 9px 24px;
          }

          #reboot_button:hover {
            background-color: alpha(@surface0, 0.9);
            border-color: @blue;
            color: @text;
          }

          /* Power Off — destructive, red accent. Selectors split
             from #reboot_button so destructive never bleeds onto
             Reboot. */
          #poweroff_button,
          button.destructive-action {
            background-image: none;
            background-color: alpha(@mantle, 0.9);
            border: 1px solid alpha(@red, 0.6);
            border-radius: 24px;
            color: @subtext1;
            padding: 9px 24px;
          }

          #poweroff_button:hover,
          button.destructive-action:hover {
            background-color: alpha(@surface0, 0.9);
            border-color: @red;
            color: @text;
          }

          /* Error info bar — uses Catppuccin red, less alarming than
             Adwaita's default error styling. */
          #error_info {
            background-color: alpha(@red, 0.22);
            color: @red;
            border-radius: 20px;
            padding: 10px 18px;
          }

          /* Combo boxes (user / session pickers) get the same pill
             treatment as inputs — fully opaque to match. */
          combobox > button.combo {
            background-image: none;
            background-color: @base;
            border: 1px solid alpha(@overlay0, 0.5);
            border-radius: 24px;
            padding: 6px 16px;
            color: @text;
          }
        '';

      programs.gnupg.agent.pinentryPackage = pkgs.pinentry-gnome3;

      xdg.portal = {
        enable = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
      };

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        wireplumber.enable = true;
      };

      security.polkit.enable = true;

      hardware.bluetooth.enable = true;

      services.gnome.gnome-keyring.enable = true;

      # Imported here because it needs greetd, fprintd and gnome-keyring, which
      # this module owns; tpm-unlock enables it once Secure Boot is on.
      imports = [
        flakeCfg.flake.nixosModules.tpm-keyring-unlock
        {
          options.services.greeter.outputScales = lib.mkOption {
            type = lib.types.attrsOf (lib.types.either lib.types.int lib.types.float);
            default = { };
            example = {
              eDP-1 = 2;
            };
            description = "Per-output scale applied to the greetd/regreet cage session.";
          };
          options.services.greeter.fingerprint = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether the greeter accepts fingerprint login. Fingerprint
              logins can't unlock the GNOME login keyring (no password to
              hand it), so disable this for password-only greeter auth.
              Other PAM services (sudo, the lock screen) are unaffected.
            '';
          };
        }
      ];

      # fprintd keeps a stale USB handle across suspend ("Device was already
      # claimed" on resume); it's dbus-activated, so it restarts on demand.
      systemd.services.fprintd.unitConfig = {
        Conflicts = [ "sleep.target" ];
        Before = [ "sleep.target" ];
      };

      services.upower.enable = true;
      services.power-profiles-daemon.enable = lib.mkDefault true;

      hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
    };
}
