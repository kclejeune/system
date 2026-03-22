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

  # Networking via DHCP (Hetzner Cloud provides DHCPv4 and DHCPv6)
  networking.usePredictableInterfaceNames = lib.mkForce false;
  networking.useNetworkd = true;
  systemd.network.networks."10-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
    dhcpV4Config.UseDNS = true;
    dhcpV6Config.UseDNS = true;
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
    # Rate-limit SSH via nftables (15 new connections per minute, burst of 5)
    extraInputRules = ''
      tcp dport 22 ct state new meter ssh-ratelimit { ip saddr limit rate 15/minute burst 5 packets } accept
      tcp dport 22 ct state new drop
    '';
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
