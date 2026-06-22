_: {
  # Host role: overlay subnet router. Enrolled on the homelab nodes that
  # forward Tailscale / NetBird traffic onto the LAN (haven / forge / atlas /
  # vault). Bundles the kernel + NIC tuning that subnet routing needs but the
  # tailscale/netbird modules don't set, so the relaxations stay scoped to
  # router nodes and don't ship to laptops (phil/wally) or the gateway.
  flake.nixosModules.subnet-router =
    { pkgs, ... }:
    {
      # IP forwarding, declared rather than left to whatever netbird flips at
      # runtime — survives the daemon being down and makes the role explicit.
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;

        # Loose reverse-path filtering (2) instead of default.nix's strict (1).
        # Forwarded overlay -> LAN traffic (and its asymmetric return path)
        # fails the strict rp_filter check and gets silently dropped; netbird
        # relaxes this itself when it has routes, but doing it declaratively
        # means subnet routing works the moment a route is assigned rather than
        # only after the daemon has flipped the knob. Plain assignment (prio
        # 100) overrides default.nix's mkDefault 1 (prio 1000). default.nix
        # anticipates exactly this: "routers or VPN concentrators could
        # override if needed".
        "net.ipv4.conf.all.rp_filter" = 2;
        "net.ipv4.conf.default.rp_filter" = 2;
      };

      environment.systemPackages = [ pkgs.ethtool ];

      # Tailscale warns "UDP GRO forwarding is suboptimally configured on
      # <dev>" because it only auto-tunes the offload when running as a
      # subnet-router/exit-node (useRoutingFeatures = "server"/"both") and
      # skips bridge devices entirely — neither applies here. Apply the tweak
      # ourselves on the default-route interface (and, if it's a bridge like
      # haven's br0, its physical members, where rx offload actually lands).
      # See https://tailscale.com/s/ethtool-config-udp-gro — pure throughput
      # optimisation, independent of whether routing itself works.
      systemd.services.tailscale-udp-gro = {
        description = "Tune UDP GRO forwarding on the default-route interface for overlay subnet routing";
        after = [
          "network-online.target"
          "tailscaled.service"
        ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.ethtool
          pkgs.iproute2
          pkgs.gawk # `awk` to parse the default-route line
          pkgs.coreutils # `basename` for bridge members
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -eu
          dev=$(ip -o route show default | awk '{print $5; exit}')
          [ -n "''${dev:-}" ] || { echo "no default-route interface; skipping"; exit 0; }

          tune() {
            echo "tuning UDP GRO forwarding on $1"
            # Errors (e.g. a bridge that doesn't expose the flag) are non-fatal.
            ethtool -K "$1" rx-udp-gro-forwarding on rx-gro-list off || true
          }

          tune "$dev"

          # If the default route is via a bridge, also tune the enslaved NICs —
          # that's where receive offload is actually performed.
          if [ -d "/sys/class/net/$dev/bridge" ]; then
            for member in /sys/class/net/"$dev"/brif/*; do
              [ -e "$member" ] && tune "$(basename "$member")"
            done
          fi
        '';
      };
    };
}
