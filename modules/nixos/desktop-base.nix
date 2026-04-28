{ config, ... }:
let
  flakeCfg = config;
in
{
  # Compositor-agnostic desktop configuration shared by GNOME and Hyprland.
  flake.nixosModules.desktop-base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        flakeCfg.flake.nixosModules.fonts
        flakeCfg.flake.nixosModules.keyd
      ];

      hm.desktop.enable = true;

      services.libinput.enable = true;
      services.printing.enable = true;

      # -- Timezone --
      # automatic-timezoned + GeoClue flaps because beacondb doesn't know
      # our Wi-Fi APs and falls back to IP geolocation, which maps our
      # Cloudflare WARP IP to Lisbon.  tzupdate uses a different IP geo
      # service that resolves correctly through WARP.
      services.tzupdate = {
        enable = true;
        timer.interval = "*:0/15";
      };

      networking.networkmanager.dispatcherScripts = [
        {
          source = pkgs.writeText "tzupdate-on-connectivity" ''
            #!/bin/sh
            [ "$2" = "connectivity-change" ] && systemctl start tzupdate.service || true
          '';
        }
      ];

      systemd.services.timezone-seed = {
        description = "Seed default timezone before tzupdate";
        before = [ "tzupdate.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/timedatectl set-timezone America/Toronto";
        };
      };

      boot.kernel.sysctl."net.core.rmem_max" = 2097152;
      boot.kernel.sysctl."net.core.rmem_default" = 1048576;

      # Plymouth + quiet boot. Covers the gap between bootloader and
      # greeter so the user doesn't watch kernel/systemd unit logs
      # scroll past on every boot. Mocha theme keeps the visual
      # consistent with the rest of the session (greeter + noctalia
      # lock + GTK theme are all Catppuccin Mocha).
      boot.plymouth = {
        enable = true;
        theme = "catppuccin-mocha";
        themePackages = [ (pkgs.catppuccin-plymouth.override { variant = "mocha"; }) ];
      };

      # `quiet`            — kernel-level message suppression
      # `splash`           — tells initrd to start plymouth
      # `loglevel=3`       — only KERN_ERR and worse
      # `rd.systemd.*` / `rd.udev.*` — same, but inside the initrd
      # `udev.log_priority=3` — quiet udev once we're past initrd
      # `vt.global_cursor_default=0` — no blinking VT cursor peeking
      #                       through plymouth or between greeter/
      #                       compositor handoffs
      boot.kernelParams = [
        "quiet"
        "splash"
        "loglevel=3"
        "systemd.show_status=false"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
        "vt.global_cursor_default=0"
      ];
      boot.consoleLogLevel = 0;
      boot.initrd.verbose = false;

      # Smooth plymouth → greeter handoff. The upstream
      # `plymouth-quit.service` calls `plymouth quit` (no
      # `--retain-splash`), so plymouth releases the framebuffer
      # immediately and the kernel fbcon flashes underneath for the
      # split second before cage grabs the framebuffer for the greeter.
      # `--retain-splash` keeps the splash image painted until
      # something else draws over it — cage's first frame.
      # Leading `-` (matches the upstream unit) makes systemd treat a
      # non-zero exit as success — necessary because the service has
      # `RemainAfterExit=yes`, so a config switch restarts it after
      # plymouth has long since exited and the second `plymouth quit`
      # would otherwise fail activation.
      systemd.services.plymouth-quit.serviceConfig.ExecStart =
        lib.mkForce "-${lib.getExe' pkgs.plymouth "plymouth"} quit --retain-splash";

      # systemd-boot. Kernel + initrd land on the ESP (vfat, 512M);
      # the separate /boot ext4 partition that GRUB used is left
      # untouched and effectively unused — not worth reformatting.
      # `configurationLimit` caps generations so the ESP doesn't fill
      # (each generation is ~80–130 MB of kernel + initrd).
      # `editor = false` blocks kernel-cmdline editing at the boot
      # menu, which would otherwise be a way to bypass disk encryption.
      # mkDefault on `timeout` so the ISO installer image can override.
      # Boot menu reveal: tap Space (or any key) during the brief flash
      # — systemd-boot's equivalent of GRUB's hold-shift trick.
      boot.loader.timeout = lib.mkDefault 0;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.loader.efi.efiSysMountPoint = "/boot/efi";
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false;
      };

      hardware.enableAllFirmware = true;

      networking.networkmanager.enable = true;
      networking.firewall.trustedInterfaces = [
        "CloudflareWARP"
        "wt0"
        "docker0"
      ];

      services.pcscd.enable = true;

      services.fprintd.enable = true;
      # `fprintAuth` defaults to `services.fprintd.enable` for every PAM
      # service, so sudo / su / polkit / login / etc. inherit it for free.
      # GDM used to force-disable it on `login` (we kept an mkForce to win
      # over that override so noctalia's PAM auth against /etc/pam.d/login
      # would work); SDDM doesn't, so the default is correct as-is.

      # Firmware updates via LVFS (Dell BIOS/EC, Thunderbolt controllers, etc.)
      services.fwupd.enable = true;

      # Thunderbolt device authorization daemon.
      services.hardware.bolt.enable = true;

      # Intel thermal daemon — improves sustained perf/thermals on Alder Lake
      # and later. No-op on non-Intel hardware.
      services.thermald.enable = true;

      # fprintd's default polkit policy is allow_active=yes, but after a
      # suspend/lock cycle polkit doesn't reliably treat the relocked session
      # as active. Grant the owner the fprint actions unconditionally.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id.indexOf("net.reactivated.fprint.") == 0 &&
              subject.user == "${config.user.name}") {
            return polkit.Result.YES;
          }
        });
      '';

      # Passwordless sudo via SSH agent forwarding
      security.pam.services.sudo.rssh.enable = true;
      services.openssh.settings.StreamLocalBindUnlink = true;

      programs.nano.enable = false;
      environment.variables.EDITOR = "nvim";

      services.logind.settings.Login = {
        HandlePowerKey = "suspend";
        HandlePowerKeyLongPress = "poweroff";
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "ignore";
      };

      security.sudo.extraConfig = ''
        Defaults timestamp_timeout=30
        Defaults timestamp_type=tty
      '';

      virtualisation.docker.enable = true;
      virtualisation.docker.daemon.settings.features.containerd-snapshotter = true;

      programs._1password.enable = true;
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = [ config.user.name ];
      };

      # nix-ld for running unpatched dynamic binaries (VS Code, Zed, Brave extensions)
      programs.nix-ld.enable = true;
      programs.nix-ld.libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        openssl
        icu
        curl
        glib
        nss
        nspr
        libx11
        libxcomposite
        libxdamage
        libxrandr
        mesa
        libGL
        alsa-lib
        at-spi2-atk
        cups
        dbus
        expat
        gtk3
      ];

      environment.etc."determinate/config.json".text = builtins.toJSON {
        authentication.additionalNetrcSources = [ "/etc/nix/netrc" ];
      };

      # Extend the built-in iso-installer with install-image + disko tooling.
      # Build: nh os build-image --image-variant=iso-installer -H "<hostname>"
      image.modules.iso-installer =
        let
          # The target system closure — the non-installer config.
          targetToplevel = config.system.build.toplevel;
          installScript = pkgs.writeShellApplication {
            name = "install-image";
            runtimeInputs = with pkgs; [
              util-linux
              cryptsetup
              lvm2
            ];
            text = ''
              # Live ISOs mount / as tmpfs and expose the source medium at /iso.
              # Refuse to run anywhere else so we don't clobber an installed system.
              if ! mountpoint -q /iso; then
                echo "ERROR: install-image should only be run from a live ISO environment."
                echo "       Refusing to run on an installed system to prevent data loss."
                exit 1
              fi

              echo "NixOS Offline Installer"
              echo "======================="
              echo "System closure: ${targetToplevel}"
              echo ""
              echo "WARNING: This will format disks according to the disko configuration."
              read -rp "Type YES to continue: " confirm
              [ "$confirm" = "YES" ] || { echo "Aborted."; exit 1; }

              echo ""
              echo "=== Step 1: Partitioning and formatting with disko ==="
              ${config.system.build.diskoScript}

              echo ""
              echo "=== Step 2: Installing NixOS (offline) ==="
              nixos-install \
                --system ${targetToplevel} \
                --no-root-passwd \
                --no-channel-copy \
                --option substituters ""

              echo ""
              echo "=== Done — reboot into your new system ==="
            '';
          };
        in
        {
          environment.systemPackages = [
            installScript
            pkgs.parted
          ];
        };

      environment.systemPackages = [
        pkgs.brave
        pkgs.dmidecode
        pkgs.firefox-devedition
        pkgs.kitty
        pkgs.localsend
        pkgs.obsidian
        pkgs.pulseaudio
        pkgs.signal-desktop
        pkgs.slack
        pkgs.vscode
        pkgs.yubikey-manager
        pkgs.yubioath-flutter
        pkgs.zed-editor
        pkgs.zoom-us

        # Standalone GNOME apps — usable without gnome-shell. Picked to
        # complement noctalia, which already provides bar / notifications /
        # launcher / lock / OSD / wallpaper / night-light.
        pkgs.gnome-disk-utility
        pkgs.nautilus
        pkgs.baobab
        pkgs.file-roller
        pkgs.loupe
        pkgs.evince
        pkgs.gnome-calculator
        pkgs.mission-center

        # Per-app audio routing UI; not GNOME, but the standard companion
        # for pipewire/pulse on a non-GNOME session.
        pkgs.pavucontrol
      ];

      # Backing services for nautilus + gnome-disk-utility on a non-GNOME
      # session. gvfs powers trash, mounted volumes, and network shares;
      # tumbler renders thumbnails; udisks2 backs gnome-disks.
      services.gvfs.enable = true;
      services.tumbler.enable = true;
      services.udisks2.enable = true;
      programs.dconf.enable = true;

      hm.imports = [ flakeCfg.flake.homeModules.onepassword ];
    };
}
