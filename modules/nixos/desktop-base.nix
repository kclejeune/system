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
        flakeCfg.flake.nixosModules.nix-ld
      ];

      hm.desktop.enable = true;

      services.libinput.enable = true;
      services.printing.enable = true;
      services.netbird.clients.default.autoStart = false;

      # tzupdate, not automatic-timezoned: GeoClue's IP fallback puts WARP in Lisbon.
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

      # Docked wired + wifi share a subnet: only answer/announce ARP from the owning NIC.
      boot.kernel.sysctl."net.ipv4.conf.all.arp_ignore" = 1;
      boot.kernel.sysctl."net.ipv4.conf.all.arp_announce" = 2;

      # systemd-shutdown ignores the log cmdline flags and writes to tty1, but
      # inherits PID 1's env: route it to kmsg so nothing paints the splash.
      systemd.managerEnvironment = {
        SYSTEMD_LOG_LEVEL = "err";
        SYSTEMD_LOG_TARGET = "kmsg";
      };

      boot.plymouth = {
        enable = true;
        theme = "catppuccin-mocha";
        themePackages = [ (pkgs.catppuccin-plymouth.override { variant = "mocha"; }) ];
      };

      # Keep kernel, udev and PID 1 (incl. initrd) output off the console so
      # nothing paints over plymouth or the greeter/compositor handoff.
      boot.kernelParams = [
        "quiet"
        "splash"
        "loglevel=3"
        "systemd.show_status=false"
        "rd.systemd.show_status=false"
        "systemd.log_level=err"
        "rd.systemd.log_level=err"
        "systemd.log_target=journal-or-kmsg"
        "rd.systemd.log_target=journal-or-kmsg"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
        "vt.global_cursor_default=0"
      ];
      boot.consoleLogLevel = 0;
      boot.initrd.verbose = false;

      # --retain-splash holds the splash until cage draws (no fbcon flash); the
      # leading `-` tolerates the re-run on switch after plymouth has exited.
      systemd.services.plymouth-quit.serviceConfig.ExecStart =
        lib.mkForce "-${lib.getExe' pkgs.plymouth "plymouth"} quit --retain-splash";

      # `editor = false` blocks cmdline edits that could bypass disk encryption.
      # mkDefault timeout so the ISO image can override it.
      boot.loader.timeout = lib.mkDefault 0;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.loader.efi.efiSysMountPoint = "/boot/efi";
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false;
      };

      hardware.enableAllFirmware = true;

      # 32-bit for Steam, Wine and some Electron apps.
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      networking.networkmanager.enable = true;
      # resolved routes per-interface DNS; with resolvconf, tailscaled's MagicDNS
      # takes over every lookup until it's fully up.
      services.resolved.enable = true;
      networking.networkmanager.dns = "systemd-resolved";
      # Delays graphical.target (and so UWSM logins) by up to 30s.
      systemd.services.NetworkManager-wait-online.enable = false;

      services.pcscd.enable = true;

      services.fprintd.enable = true;

      services.fwupd.enable = true;

      services.hardware.bolt.enable = true;

      services.thermald.enable = true;

      # polkit may not treat a relocked session as active, so allow verify for the
      # owner's local sessions without requiring `active`. Only verify: enroll
      # stays on fprintd's default policy, so nobody can add a finger (which would
      # then pass sudo, greetd and the TPM keyring) without authenticating.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "net.reactivated.fprint.device.verify" &&
              subject.local &&
              subject.user == "${config.user.name}") {
            return polkit.Result.YES;
          }
        });
      '';

      services.logind.settings.Login = {
        HandlePowerKey = "suspend";
        HandlePowerKeyLongPress = "poweroff";
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "ignore";
      };

      # Terminal sudo can't show a polkit popup; `run0` gets the noctalia fingerprint prompt.
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

      # The module (not just the package) opens the firewall for discovery.
      programs.localsend.enable = true;

      # GUI libs for unpatched desktop binaries, on top of the nix-ld module's base set.
      programs.nix-ld.libraries = with pkgs; [
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
        pkgs.firefox
        pkgs.google-chrome
        pkgs.kitty
        pkgs.obsidian
        pkgs.pulseaudio
        pkgs.signal-desktop
        pkgs.slack
        pkgs.vscode
        pkgs.vulkan-tools
        pkgs.yubikey-manager
        pkgs.yubioath-flutter
        pkgs.zed-editor
        pkgs.zoom-us

        # Standalone GNOME apps alongside noctalia.
        pkgs.gnome-disk-utility
        pkgs.nautilus
        pkgs.baobab
        pkgs.file-roller
        pkgs.loupe
        pkgs.evince
        pkgs.gnome-calculator
        pkgs.mission-center
        pkgs.snapshot

        pkgs.pavucontrol
      ];

      # Backends for nautilus / gnome-disks outside GNOME.
      services.gvfs.enable = true;
      services.tumbler.enable = true;
      services.udisks2.enable = true;
      programs.dconf.enable = true;

      # ReGreet needs accountsservice for its user list, or it falls back to an unstyled form.
      services.accounts-daemon.enable = true;

      hm.imports = [ flakeCfg.flake.homeModules.onepassword ];
    };
}
