# Shared configuration for Hetzner Cloud VMs provisioned via nixos-infect.
{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # Hardware / boot
  boot.loader.grub.device = "/dev/sda";
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "xen_blkfront"
    "vmw_pvscsi"
  ];
  boot.initrd.kernelModules = [ "nvme" ];
  boot.tmp.cleanOnBoot = true;

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  zramSwap.enable = true;

  # Workaround for https://github.com/NixOS/nix/issues/8502
  services.logrotate.checkConfig = false;

  # Limit nix to 1 core so builds don't starve the system on small VMs
  nix.settings = {
    max-jobs = 1;
    cores = 1;
  };

  # Networking: DHCPv4 + static IPv6 from metadata API
  # Hetzner Cloud doesn't send Router Advertisements — the VM must configure
  # IPv6 statically. The address/gateway are fetched from the metadata API at
  # boot and written as a networkd drop-in before networkd starts.
  networking.usePredictableInterfaceNames = lib.mkForce false;
  networking.useNetworkd = true;
  systemd.network.networks."10-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    dhcpV4Config.UseDNS = true;
  };

  systemd.services.hetzner-ipv6 = {
    description = "Configure IPv6 from Hetzner Cloud metadata";
    wantedBy = [ "network-pre.target" ];
    before = [ "systemd-networkd.service" ];
    after = [ "network-pre.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [
      curl
      coreutils
      gawk
    ];
    script = ''
      set -euo pipefail
      METADATA=$(curl -sf http://169.254.169.254/hetzner/v1/metadata)

      IPV6_ADDR=$(echo "$METADATA" | awk '/type: static/{found=1} found && /address:/{print $2; exit}')
      IPV6_GW=$(echo "$METADATA" | awk '/type: static/{found=1} found && /gateway:/{print $2; exit}')
      IPV6_DNS=$(echo "$METADATA" | awk '/type: static/{found=1} found && /dns_nameservers:/{dns=1; next} dns && /^ *-/{print $2; next} dns{exit}')

      if [ -z "$IPV6_ADDR" ]; then
        echo "No IPv6 address found in Hetzner metadata, skipping"
        exit 0
      fi

      mkdir -p /etc/systemd/network/10-eth0.network.d
      {
        echo "[Network]"
        echo "Address=$IPV6_ADDR"
        echo "$IPV6_DNS" | while read -r dns; do
          [ -n "$dns" ] && echo "DNS=$dns"
        done
        echo ""
        echo "[Route]"
        echo "Gateway=$IPV6_GW"
        echo "Destination=::/0"
      } > /etc/systemd/network/10-eth0.network.d/ipv6.conf
    '';
  };

  # Harden SSH for a public-facing server
  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    AllowAgentForwarding = true;
    AllowTcpForwarding = false;
    MaxAuthTries = 3;
    LoginGraceTime = 30;
  };

  # Use nftables over iptables
  networking.nftables.enable = true;

  # Firewall (SSH only by default; consumers should open additional ports)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    # Log dropped packets for audit visibility
    logRefusedConnections = true;
    logRefusedPackets = true;
    logReversePathDrops = true;
    # Drop rather than reject to reduce information leakage
    rejectPackets = false;
  };

  # fail2ban
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    ignoreIP = [
      "127.0.0.0/8"
      "100.64.0.0/10" # Tailscale
      "100.100.0.0/16" # Netbird
    ];
    bantime-increment = {
      enable = true;
      maxtime = "48h";
    };
    jails = {
      sshd = {
        settings = {
          enabled = true;
          filter = "sshd[mode=aggressive]";
          maxretry = 3;
        };
      };
    };
  };

  networking.nftables.tables.audit = {
    family = "inet";
    content = ''
      chain input {
        type filter hook input priority -10; policy accept;
        ct state new log prefix "nftables-new-conn: " flags all
      }
    '';
  };

  # Per-host rate limiting is in gateway.nix extraInputRules.
  # Removed the generic rate-limit table that had:
  # - ct count over 500 (too low for a gateway running many services)
  # - 25/s SYN limit (conflicts with gateway.nix's 200/s)
  # - ICMPv6 blanket drop (breaks IPv6 neighbor discovery)

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    openFirewall = true;
  };

  # Kernel hardening
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
  };

  time.timeZone = "UTC";
}
