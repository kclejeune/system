# Compositor-agnostic desktop configuration shared by GNOME and Hyprland.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.libinput.enable = true;
  services.printing.enable = true;

  # -- Timezone --
  # automatic-timezoned + GeoClue flaps because beacondb doesn't know
  # our Wi-Fi APs and falls back to IP geolocation, which maps our
  # Cloudflare WARP IP to Lisbon.  tzupdate uses a different IP geo
  # service that resolves correctly through WARP.
  #
  # TODO: revisit automatic-timezoned once beacondb learns our APs or
  # a better Wi-Fi geolocation provider is available.
  #
  # services.geoclue2.enable = true;
  # services.geoclue2.enableDemoAgent = lib.mkForce true;
  # services.geoclue2.geoProviderUrl = "https://api.beacondb.net/v1/geolocate";
  # services.automatic-timezoned.enable = true;
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

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # Hold shift during POST to reveal the otherwise-hidden boot menu.
  # mkDefault so the ISO installer image variant can override with its own timeout.
  boot.loader.timeout = lib.mkDefault 0;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    extraConfig = ''
      if keystatus --shift ; then
        set timeout=-1
      else
        set timeout=0
      fi
    '';
  };

  hardware.enableAllFirmware = true;

  networking.networkmanager.enable = true;
  networking.firewall.trustedInterfaces = [
    "CloudflareWARP"
    "wt0"
    "docker0"
  ];

  # Caps Lock -> Esc on tap, Ctrl on hold
  services.keyd = {
    enable = true;
    keyboards.default.settings.main = {
      capslock = "overload(control, esc)";
    };
  };

  services.pcscd.enable = true;

  services.fprintd.enable = true;
  security.pam.services.sudo.fprintAuth = true;

  # hyprlock claims the fingerprint reader via before_sleep_cmd; after resume
  # the USB device re-enumerates and fprintd's handle goes stale, so the
  # fingerprint prompt silently never fires. Restart fprintd on resume.
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl try-restart fprintd.service || true
  '';

  # fprintd's default polkit policy is allow_active=yes, but after a
  # suspend/lock cycle polkit doesn't reliably treat the relocked session
  # as active for the user-space D-Bus caller (hyprlock), which shows up as
  # "Not Authorized: net.reactivated.fprint.device.verify" in the journal.
  # Grant the owner the fprint actions unconditionally.
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
      # The target system closure — the non-installer config. At this scope
      # `config` is the outer (base) evaluation, before iso-image.nix layers on
      # the live-ISO root filesystem and strips the target bootloader, so
      # toplevel/diskoScript here describe the system we want on disk.
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
    pkgs.firefox-devedition
    pkgs.kitty
    pkgs.yubikey-manager
    pkgs.yubioath-flutter
    pkgs.vscode
    pkgs.zed-editor
    pkgs.slack
    pkgs.signal-desktop
    pkgs.obsidian
    pkgs.zoom-us
    pkgs.dmidecode
    pkgs.pulseaudio
  ];

  hm =
    { ... }:
    {
      imports = [
        ../home-manager/1password.nix
      ];
    };
}
