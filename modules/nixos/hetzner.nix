# Shared configuration for Hetzner Cloud VMs provisioned via nixos-infect.
{
  config,
  lib,
  modulesPath,
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

  # Sensible default firewall (SSH only; consumers should open additional ports)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  time.timeZone = "UTC";
}
