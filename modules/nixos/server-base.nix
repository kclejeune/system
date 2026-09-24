_: {
  # Headless server baseline (the server analog of desktop-base).
  flake.nixosModules.server-base =
    {
      lib,
      ...
    }:
    {
      # configurationLimit keeps the ESP from filling; editor=false blocks cmdline edits.
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false;
      };
      boot.loader.efi.canTouchEfiVariables = true;
      boot.loader.efi.efiSysMountPoint = "/boot";

      boot.tmp.cleanOnBoot = true;
      boot.kernelParams = [ "quiet" ];

      hardware.enableRedistributableFirmware = true;

      time.timeZone = lib.mkDefault "America/Toronto";

      # networkd, not NetworkManager. Hosts needing a bridge add lower-numbered
      # files, which win for the NIC.
      networking.useNetworkd = true;
      services.resolved.enable = true;
      systemd.network.wait-online.anyInterface = true;
      systemd.network.networks."90-dhcp-default" = {
        matchConfig.Name = "en* eth*";
        networkConfig.DHCP = "yes";
        # Static hostnames: letting DHCP set one only logs "Access denied".
        dhcpV4Config.UseHostname = false;
        linkConfig.RequiredForOnline = "routable";
      };

      # Only answer ARP for the receiving NIC's own IP (multi-homed hosts).
      boot.kernel.sysctl."net.ipv4.conf.all.arp_ignore" = 1;
      boot.kernel.sysctl."net.ipv4.conf.all.arp_announce" = 2;

      # Persistent journal so post-incident debugging survives reboots.
      services.journald.settings.Journal = {
        Storage = "persistent";
        SystemMaxUse = "1G";
      };

      virtualisation.podman.enable = true;
      virtualisation.oci-containers.backend = "podman";

      # Installer image only: default.nix and the installation-device profile both
      # mkDefault PermitRootLogin, which collide.
      image.modules.iso-installer.services.openssh.settings.PermitRootLogin = lib.mkForce "yes";
    };
}
