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
      # Theme constants — see modules/shared/theme.nix. mkTheme is a
      # function (not a static attrset) because base16.nix's YAML
      # loader needs `pkgs`.
      theme = flakeCfg.flake.lib.mkTheme pkgs;
    in
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
        # Adds pkgs.uwsm to PATH (so `uwsm`, `uwsm-app`, `uuctl`, etc.
        # are reachable as bare commands). The HM hyprland module uses
        # `uwsm-app -- <cmd>` in exec-once and keybinds to put apps in
        # app.slice as transient scopes instead of compositor children.
        # This is NOT enough to run a UWSM session — the
        # template units (wayland-session-bindpid@.service,
        # wayland-wm@.service, wayland-wm-env@.service) ship in
        # `share/systemd/user/` of pkgs.uwsm, and NixOS only aggregates
        # `lib/systemd/user/`, so the user systemd manager never sees
        # them. Without `programs.uwsm.enable` below, `uwsm start` fails
        # at `systemctl --user start wayland-session-bindpid@<pid>` with
        # exit code 5 (unit not found) and the user is bounced back to
        # the greeter.
        withUWSM = true;
      };

      # Wires up UWSM properly: adds pkgs.uwsm to `systemd.packages` so
      # the template units land in the user manager's search path, and
      # adds `share/wayland-sessions` + `share/uwsm` to
      # `environment.pathsToLink`. We deliberately leave
      # `waylandCompositors` empty — that option auto-generates a
      # `<name>-uwsm.desktop` session file, which would collide with the
      # `hyprland-uwsm.desktop` already bundled by pkgs.hyprland.
      # (Side effect: forces `services.dbus.implementation = "broker"`,
      # which is already what this host runs.)
      programs.uwsm.enable = true;

      # greetd + ReGreet. ReGreet is a GTK4 layer-shell greeter and
      # needs a Wayland host, so we wrap it in `cage` (a single-app
      # Wayland kiosk). dbus-run-session gives ReGreet its own session
      # bus so AT-SPI / GTK portal lookups don't hit the system bus.
      #
      # gnome-keyring unlock: the upstream greetd nixos module
      # auto-sets `security.pam.services.greetd.enableGnomeKeyring`
      # from `services.gnome.gnome-keyring.enable` (set below), so the
      # greeter's PAM stack already includes pam_gnome_keyring.
      services.greetd = {
        enable = true;
        # Don't wait for plymouth to exit before starting the greeter.
        # Combined with the `plymouth-quit.unitConfig.After = greetd`
        # override below, this flips the order: cage takes the
        # framebuffer first, *then* plymouth quits with
        # `--retain-splash`. Without this, plymouth releases the fb
        # at multi-user.target → kernel fbcon flashes whatever was in
        # its scrollback → cage starts → greeter appears.
        greeterManagesPlymouth = true;
        settings.default_session = {
          # Wrap cage to blank tty1 before AND after each greeter cycle.
          # cage 0.2.1 reliably SIGSEGVs in `wl_display_destroy → ...
          # → handle_output_destroy` when wlroots 0.19 tears down its DRM
          # backend (upstream race; the cage process is dying anyway, so
          # the crash is post-handoff cosmetic). The bigger UX symptom is
          # that the segfault leaves the framebuffer in an undefined state,
          # so on the cage→hyprland and hyprland→cage handoffs fbcon
          # briefly redraws whatever scrollback / kernel-trap text was last
          # there. Pre-clearing tty1 before cage runs and post-clearing on
          # exit (trap survives a SIGSEGV in the child) hides the leak.
          command = "${pkgs.bash}/bin/bash -c \"${pkgs.util-linux}/bin/setterm --clear all --cursor off >/dev/tty1; trap '${pkgs.util-linux}/bin/setterm --clear all --cursor off >/dev/tty1' EXIT; ${pkgs.dbus}/bin/dbus-run-session ${lib.getExe pkgs.cage} -s -m last -- ${lib.getExe pkgs.regreet}\"";
          user = "greeter";
        };
      };

      # The greetd module creates the `greeter` system user with no
      # supplementary groups. The setterm wrapper above writes to
      # /dev/tty1 (mode `crw-------`, group `tty`); the greeter user
      # ends up owning tty1 once logind transfers session ownership,
      # but logind does that at PAM session-open time and the very
      # first setterm in the wrapper races that. Adding `tty` group
      # gives unconditional access so the clear always succeeds.
      users.users.greeter.extraGroups = [ "tty" ];

      # cage SIGSEGVs every greeter cycle (see command wrapper above).
      # Setting RLIMIT_CORE=0 on greetd propagates to its children, so the
      # kernel never asks systemd-coredump to record the dump. Net effect:
      # the journal stops getting flooded with "Module libseat.so.1
      # without build-id" backtrace listings (cage links libseat for
      # logind seat management; the libseat frame shows up because cage's
      # crash happens during wlroots' DRM teardown). Cage still dies with
      # SIGSEGV — we just don't ceremonially preserve the body.
      #
      # The directive must be `LimitCORE` (uppercase rlimit name);
      # `LimitCore` is silently ignored with `Unknown key 'LimitCore' in
      # section [Service]` in the journal, leaving RLIMIT_CORE at its
      # inherited value and the coredump flood intact.
      systemd.services.greetd.serviceConfig.LimitCORE = "0";

      # The kernel `loglevel`, `quiet`, and PID-1's `systemd.show_status`
      # only silence the *system* manager. greetd.service and
      # user@.service default to `StandardError=inherit`, which chains up
      # to PID 1's stderr → /dev/console → tty1, so the user-systemd
      # manager's "Started …" / "Reached target …" lines paint over the
      # framebuffer in the cage→Hyprland handoff window. Redirect both
      # services' stderr to the journal so nothing from that chain hits
      # the console, and bump the user manager's log level to warning so
      # info-level status chatter is filtered at the source even if some
      # child re-attaches stderr to a terminal.
      systemd.services.greetd.serviceConfig.StandardError = "journal";
      systemd.services."user@".serviceConfig = {
        StandardError = "journal";
        Environment = [ "SYSTEMD_LOG_LEVEL=warning" ];
      };

      # Pair to `greeterManagesPlymouth = true`: defer
      # `plymouth-quit.service` until greetd is up. Once greetd is
      # active, cage has the framebuffer; plymouth's quit is then
      # purely cosmetic (no fb release → no fbcon flash window).
      systemd.services.plymouth-quit.unitConfig.After = [ "greetd.service" ];

      # Greeter UX: password only. fprintd's PAM hook would otherwise
      # stack `pam_fprintd.so sufficient` ahead of pam_unix and the
      # user sees a fingerprint scan request alongside the password
      # field. Sudo / TTY login still inherit fprintAuth — only the
      # ReGreet PAM service is opted out.
      security.pam.services.greetd.fprintAuth = false;

      # ReGreet bakes these paths in at compile time and crashes if
      # they don't exist. Owned by the `greeter` system user that the
      # greetd module creates.
      #
      # The seeded `state.toml` pre-selects `kclejeune` + the
      # UWSM-managed Hyprland session so the greeter just shows a
      # password field on first boot — no need to click through
      # user/session pickers. The session name matches the `Name=` field
      # of `share/wayland-sessions/hyprland-uwsm.desktop` shipped by the
      # hyprland package (the bare `Hyprland` entry remains as a UWSM
      # fallback). `C` means "copy if missing": ReGreet's runtime writes
      # (last user / last session bookkeeping) take over after first
      # login.
      systemd.tmpfiles.rules =
        let
          initialState = pkgs.writeText "regreet-initial-state.toml" ''
            last_user = "${config.user.name}"
            [user_to_last_sess]
            ${config.user.name} = "Hyprland (uwsm-managed)"
          '';
        in
        [
          "d /var/lib/regreet 0755 greeter greeter - -"
          "d /var/log/regreet 0755 greeter greeter - -"
          "C /var/lib/regreet/state.toml 0644 greeter greeter - ${initialState}"
        ];

      # The greeter runs as the `greeter` system user with no $HOME
      # and a near-empty environment. We need:
      #   - HOME so GTK4 has somewhere to cache (/var/lib/regreet is
      #     already greeter-owned, no extra tmpfile needed),
      #   - XDG_DATA_DIRS so GTK can find the Catppuccin theme and
      #     cursor / icon themes installed via systemPackages below.
      systemd.services.greetd.environment = {
        HOME = "/var/lib/regreet";
        XDG_DATA_DIRS = "/run/current-system/sw/share";
      };

      # Themes / cursors / icons that the greeter looks up by name in
      # /etc/greetd/regreet.toml. Catppuccin Mocha + Papirus + Open
      # Sans match the user's HM session, so the greeter blends with
      # noctalia's lock surface instead of falling back to Adwaita.
      environment.systemPackages = [
        (pkgs.catppuccin-gtk.override {
          accents = [ theme.gtk.accent ];
          variant = theme.gtk.variant;
        })
        pkgs.catppuccin-cursors.mochaDark
        pkgs.papirus-icon-theme
      ];

      fonts.packages = [ pkgs.open-sans ];

      # ReGreet config. Mirrors the user's HM gtk theme so the greeter
      # carries the same Catppuccin Mocha / Open Sans / Papirus look as
      # the noctalia lock screen the user sees mid-session. Theme name
      # constants come from `flake.theme.gtk` (modules/shared/theme.nix)
      # so the greeter and home session can never drift.
      environment.etc."greetd/regreet.toml".text = ''
        [GTK]
        application_prefer_dark_theme = true
        cursor_theme_name = "${theme.gtk.cursorName}"
        cursor_blink = true
        font_name = "${theme.gtk.fontName} ${toString theme.gtk.fontSize}"
        icon_theme_name = "${theme.gtk.iconThemeName}"
        theme_name = "${theme.gtk.themeName}"

        [commands]
        reboot = ["systemctl", "reboot"]
        poweroff = ["systemctl", "poweroff"]

        [appearance]
        greeting_msg = "Welcome back"

        [widget.clock]
        format = "%A, %B %-d  ·  %H:%M"
        resolution = "1s"
        timezone = "America/Toronto"
        label_width = 360
      '';

      # Custom CSS overlays the Catppuccin GTK theme to push the
      # greeter closer to noctalia's lock surface: a translucent
      # surface0 card centered on the mocha base, with rounded
      # password input and lavender login accent. Widget IDs come from
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

          window.background,
          #background {
            background-color: @base;
            color: @text;
          }

          /* Centered login card — matches noctalia's surface0 panel. */
          frame.background {
            background-color: alpha(@surface0, 0.92);
            border: 1px solid alpha(@overlay0, 0.4);
            border-radius: 20px;
            box-shadow: 0 8px 32px alpha(@crust, 0.6);
            padding: 12px;
          }

          /* Top-center clock card. ReGreet flattens its top edge inline
             via inline_css; we just style the visible bottom-rounded
             half. */
          #clock_frame {
            background-color: alpha(@surface0, 0.92);
            border: 1px solid alpha(@overlay0, 0.4);
            padding: 12px 32px;
            font-size: 18px;
            font-weight: 500;
            color: @text;
          }

          /* Password / username inputs — high border-radius mirrors
             noctalia's passwordInputRadius=30. */
          entry,
          #secret_entry,
          #visible_entry,
          #username_entry,
          #session_entry {
            background-color: alpha(@base, 0.6);
            border: 1px solid alpha(@overlay0, 0.5);
            border-radius: 30px;
            padding: 8px 16px;
            color: @text;
            caret-color: @lavender;
          }

          entry:focus,
          #secret_entry:focus,
          #visible_entry:focus {
            border-color: @lavender;
            box-shadow: 0 0 0 2px alpha(@lavender, 0.35);
          }

          /* Login (suggested-action) button. */
          #login_button,
          button.suggested-action {
            background-image: none;
            background-color: @lavender;
            color: @crust;
            border: none;
            border-radius: 20px;
            padding: 8px 24px;
            font-weight: 600;
          }

          #login_button:hover,
          button.suggested-action:hover {
            background-color: @blue;
          }

          /* Reboot / Power Off pills at the bottom edge. */
          #reboot_button,
          #poweroff_button,
          button.destructive-action {
            background-image: none;
            background-color: alpha(@surface0, 0.92);
            border: 1px solid alpha(@overlay0, 0.5);
            border-radius: 20px;
            color: @text;
            padding: 8px 20px;
          }

          #reboot_button:hover {
            background-color: alpha(@yellow, 0.85);
            color: @crust;
          }

          #poweroff_button:hover,
          button.destructive-action:hover {
            background-color: alpha(@red, 0.85);
            color: @crust;
          }

          /* Error info bar — uses Catppuccin red, less alarming than
             Adwaita's default error styling. */
          #error_info {
            background-color: alpha(@red, 0.18);
            color: @red;
            border-radius: 16px;
            padding: 8px 16px;
          }

          /* Combo boxes (user / session pickers) get the same pill
             treatment as inputs. */
          combobox > button.combo {
            background-image: none;
            background-color: alpha(@base, 0.6);
            border: 1px solid alpha(@overlay0, 0.5);
            border-radius: 20px;
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

      # Force-stop fprintd before s2idle so its in-flight Verify session
      # (bound to the pre-suspend Goodix USB handle) is torn down cleanly.
      # Without this, the kernel re-enumerates the device on resume but
      # fprintd keeps the stale handle, and noctalia's next Claim returns
      # "Device was already claimed". fprintd is dbus-activated, so the
      # first call after resume auto-launches a fresh instance.
      systemd.services.fprintd.unitConfig = {
        Conflicts = [ "sleep.target" ];
        Before = [ "sleep.target" ];
      };

      services.upower.enable = true;
      services.power-profiles-daemon.enable = lib.mkDefault true;

      # Lid/power-key handling comes from `desktop-base`. Noctalia's
      # built-in idle/lockOnSuspend is disabled in settings.json so
      # hypridle (configured in the home module) is the sole coordinator
      # for idle timeouts and logind PrepareForSleep hooks.

      hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
    };
}
