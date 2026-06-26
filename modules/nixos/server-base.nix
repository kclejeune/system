_: {
  # Headless server baseline — the server analog of desktop-base.nix. No GUI,
  # plymouth, fingerprint, or desktop bits; just the things every always-on
  # homelab node wants. Hosts layer hardware + role modules on top.
  flake.nixosModules.server-base =
    {
      lib,
      ...
    }:
    {
      # UEFI systemd-boot (the P3 Tiny boots UEFI). configurationLimit caps the
      # ESP so it doesn't fill; editor=false blocks cmdline editing at the menu.
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false;
      };
      boot.loader.efi.canTouchEfiVariables = true;
      # Single ESP mounted at /boot (no separate /boot partition) — systemd-boot
      # keeps kernels + initrds on the ESP. The disko layout sizes it at 1G.
      boot.loader.efi.efiSysMountPoint = "/boot";

      boot.tmp.cleanOnBoot = true;
      boot.kernelParams = [ "quiet" ];

      hardware.enableRedistributableFirmware = true;

      # Local time for human-readable logs; hosts can override.
      time.timeZone = lib.mkDefault "America/Toronto";

      # Headless networking: systemd-networkd + resolved, not NetworkManager
      # (which is desktop-oriented). A high-numbered generic DHCP network
      # matches any onboard ethernet; a host that needs a bridge defines its
      # own lower-numbered networkd files, which win for the physical NIC.
      networking.useNetworkd = true;
      services.resolved.enable = true;
      systemd.network.wait-online.anyInterface = true;
      systemd.network.networks."90-dhcp-default" = {
        matchConfig.Name = "en* eth*";
        networkConfig.DHCP = "yes";
        # These hosts set a static networking.hostName, so don't let the DHCP
        # client try to apply the lease's hostname — hostnamed refuses to
        # override a static hostname and logs a harmless "Could not set
        # hostname: Access denied" at every lease otherwise.
        dhcpV4Config.UseHostname = false;
        linkConfig.RequiredForOnline = "routable";
      };

      # ARP flux guard for hosts that may end up multi-homed on one subnet
      # (same rationale as desktop-base): only answer ARP for the receiving
      # NIC's own IP, and source announcements from the outgoing interface.
      boot.kernel.sysctl."net.ipv4.conf.all.arp_ignore" = 1;
      boot.kernel.sysctl."net.ipv4.conf.all.arp_announce" = 2;

      # Persistent journal so post-incident debugging survives reboots.
      services.journald.extraConfig = ''
        Storage=persistent
        SystemMaxUse=1G
      '';

      # OCI container runtime — podman, matching how the gateway runs its
      # netbird-proxy container.
      virtualisation.podman.enable = true;
      virtualisation.oci-containers.backend = "podman";

      # Installer-image only: resolve the PermitRootLogin clash when building
      # `nh os build-image --image-variant=iso-installer`. default.nix sets
      # mkDefault "no" and the upstream installation-device profile sets
      # mkDefault "yes" — two equal-priority mkDefaults collide. mkForce wins,
      # and because this lives under image.modules.iso-installer it applies
      # ONLY to the live installer; the installed system keeps "no".
      image.modules.iso-installer.services.openssh.settings.PermitRootLogin = lib.mkForce "yes";
    };
}
