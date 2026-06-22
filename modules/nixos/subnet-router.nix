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

      # ethtool kept on router nodes for manual offload inspection
      # (`ethtool -k <dev>`); the GRO tuning itself is declarative below.
      environment.systemPackages = [ pkgs.ethtool ];

      # UDP GRO forwarding offload — tailscale warns "UDP GRO forwarding is
      # suboptimally configured on <dev>" and recommends
      # `ethtool -K <dev> rx-udp-gro-forwarding on rx-gro-list off`
      # (https://tailscale.com/s/ethtool-config-udp-gro) for subnet-router
      # throughput. systemd 260 exposes rx-udp-gro-forwarding as the .link
      # [Link] key GenericReceiveOffloadUDPForwarding (verified accepted by the
      # 260.1 parser; the matching rx-gro-list key isn't in 260.1 yet, but
      # rx-gro-list defaults off — exactly what tailscale wants — so it needs no
      # action).
      #
      # Delivered as a DROP-IN to systemd's shipped 99-default.link, NOT a
      # standalone .link, for two reasons:
      #   1. Only the first matching .link is applied. A standalone .link
      #      matching en*/eth* would beat 99-default.link and, lacking
      #      NamePolicy, leave NICs on kernel names (eth0 not eno2) — breaking
      #      the en*/eth* matches in server-base/haven. A drop-in merges into
      #      99-default.link's [Link] section, so its NamePolicy is preserved
      #      (verified: `udevadm test-builtin net_setup_link` still yields
      #      ID_NET_NAME=eno2).
      #   2. nixpkgs' typed `systemd.network.links.*.linkConfig` predates the
      #      systemd-260 key and hard-errors on it; environment.etc has no such
      #      validation.
      # udev applies it when the NIC appears (no oneshot / PATH deps). It hits
      # every NIC 99-default.link governs on the host; unsupported devices skip
      # it. Verify post-deploy with `ethtool -k <dev> | grep rx-udp-gro`.
      environment.etc."systemd/network/99-default.link.d/10-udp-gro-forwarding.conf".text = ''
        [Link]
        GenericReceiveOffloadUDPForwarding=yes
      '';
    };
}
