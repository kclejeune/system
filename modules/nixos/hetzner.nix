_: {
  # Shared configuration for Hetzner Cloud VMs provisioned via nixos-infect.
  flake.nixosModules.hetzner =
    {
      config,
      lib,
      modulesPath,
      pkgs,
      ...
    }:
    {
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

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

      # Limit nix to 1 core so builds don't starve the system on small VMs
      nix.settings = {
        max-jobs = 1;
        cores = 1;
      };

      # Hetzner Cloud sends no Router Advertisements, so IPv6 comes from the
      # metadata API, written before networkd starts.
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

      # Public host: not a jump host. Agent forwarding stays on for pam_rssh sudo
      # (deploy / nh --target-host).
      services.openssh.settings = {
        AllowAgentForwarding = true;
        AllowTcpForwarding = false;
      };

      networking.firewall = {
        allowedTCPPorts = [ 22 ];
        logRefusedConnections = true;
        logRefusedPackets = true;
        logReversePathDrops = true;
        # Drop rather than reject to reduce information leakage
        rejectPackets = false;
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

      time.timeZone = "UTC";
    };
}
