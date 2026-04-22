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

  # Keep fprintd running so lock screen fingerprint auth is instant
  # (default behavior auto-deactivates after idle, causing 30s+ cold start)
  systemd.services.fprintd.serviceConfig.TimeoutStopSec = "infinity";
  systemd.services.fprintd.wantedBy = [ "multi-user.target" ];

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
      installScript = pkgs.writeShellApplication {
        name = "install-image";
        runtimeInputs = with pkgs; [
          util-linux
          cryptsetup
          lvm2
        ];
        text = ''
          # Only run from a live ISO (squashfs root) — refuse on installed systems
          if ! findmnt -n -o FSTYPE / | grep -q squashfs; then
            echo "ERROR: install-image should only be run from a live ISO environment."
            echo "       Refusing to run on an installed system to prevent data loss."
            exit 1
          fi

          TOPLEVEL=$(readlink -f /run/current-system)
          echo "NixOS Offline Installer"
          echo "======================="
          echo "System closure: $TOPLEVEL"
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
            --system "$TOPLEVEL" \
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
