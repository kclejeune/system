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
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };

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
          command = "${pkgs.dbus}/bin/dbus-run-session ${lib.getExe pkgs.cage} -s -m last -- ${lib.getExe pkgs.regreet}";
          user = "greeter";
        };
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
      # The seeded `state.toml` pre-selects `kclejeune` + the plain
      # `Hyprland` session so the greeter just shows a password field
      # on first boot — no need to click through user/session pickers.
      # `C` means "copy if missing": ReGreet's runtime writes (last
      # user / last session bookkeeping) take over after first login.
      systemd.tmpfiles.rules =
        let
          initialState = pkgs.writeText "regreet-initial-state.toml" ''
            last_user = "${config.user.name}"
            [user_to_last_sess]
            ${config.user.name} = "Hyprland"
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
          accents = [ "blue" ];
          variant = "mocha";
        })
        pkgs.catppuccin-cursors.mochaDark
        pkgs.papirus-icon-theme
      ];

      fonts.packages = [ pkgs.open-sans ];

      # ReGreet config. Mirrors the user's HM gtk theme so the greeter
      # carries the same Catppuccin Mocha / Open Sans / Papirus look as
      # the noctalia lock screen the user sees mid-session.
      environment.etc."greetd/regreet.toml".text = ''
        [GTK]
        application_prefer_dark_theme = true
        cursor_theme_name = "catppuccin-mocha-dark-cursors"
        cursor_blink = true
        font_name = "Open Sans 13"
        icon_theme_name = "Papirus-Dark"
        theme_name = "catppuccin-mocha-blue-standard"

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
      environment.etc."greetd/regreet.css".text = ''
        @define-color base #1e1e2e;
        @define-color mantle #181825;
        @define-color crust #11111b;
        @define-color surface0 #313244;
        @define-color surface1 #45475a;
        @define-color overlay0 #6c7086;
        @define-color text #cdd6f4;
        @define-color subtext1 #bac2de;
        @define-color blue #89b4fa;
        @define-color lavender #b4befe;
        @define-color yellow #f9e2af;
        @define-color red #f38ba8;

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

      hardware.graphics.enable = true;

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

      # Lid close → suspend; ignore lid close when docked (external
      # monitors). Power button → suspend. Noctalia's built-in
      # idle/lockOnSuspend is disabled in settings.json so hypridle
      # (configured in the home module) is the single coordinator for
      # both idle timeouts and logind PrepareForSleep hooks.
      services.logind.settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchDocked = "ignore";
        HandlePowerKey = "suspend";
      };

      hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
    };
}
