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

  # Networking: DHCPv4 + static IPv6 (Hetzner doesn't provide DHCPv6 or RA)
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

  # Fetch IPv6 config from Hetzner metadata API at boot and apply via networkd drop-in
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
      jq
      coreutils
      gawk
    ];
    script = ''
      set -euo pipefail
      METADATA=$(curl -sf http://169.254.169.254/hetzner/v1/metadata)

      # Parse IPv6 address and gateway from the YAML metadata
      IPV6_ADDR=$(echo "$METADATA" | awk '/type: static/{found=1} found && /address:/{print $2; exit}')
      IPV6_GW=$(echo "$METADATA" | awk '/type: static/{found=1} found && /gateway:/{print $2; exit}')
      IPV6_DNS=$(echo "$METADATA" | awk '/type: static/{found=1} found && /dns_nameservers:/{dns=1; next} dns && /^ *-/{print $2; next} dns{exit}')

      if [ -z "$IPV6_ADDR" ]; then
        echo "No IPv6 address found in Hetzner metadata, skipping"
        exit 0
      fi

      mkdir -p /etc/systemd/network/10-eth0.network.d
      cat > /etc/systemd/network/10-eth0.network.d/ipv6.conf <<EOF
      [Network]
      Address=$IPV6_ADDR
      DNS=$(echo "$IPV6_DNS" | head -1)
      DNS=$(echo "$IPV6_DNS" | tail -1)

      [Route]
      Gateway=$IPV6_GW
      Destination=::/0
      EOF

      # Remove leading whitespace from heredoc
      sed -i 's/^[[:space:]]*//' /etc/systemd/network/10-eth0.network.d/ipv6.conf
    '';
  };

  # Harden SSH for a public-facing server
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
    AllowAgentForwarding = true;
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

  # Logging: nftables connection tracking + journald for full audit trail
  # Log new connections with source IP, destination port, and protocol
  networking.nftables.tables.audit = {
    family = "inet";
    content = ''
      chain input {
        type filter hook input priority -10; policy accept;
        ct state new log prefix "nftables-new-conn: " flags all
      }
    '';
  };

  # Tailscale
  services.tailscale.enable = true;

  time.timeZone = "UTC";
}
