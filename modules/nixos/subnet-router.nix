_: {
  # Router / exit-node role (homelab nodes + gateway), so forwarding and NIC
  # tuning stay off laptops.
  flake.nixosModules.subnet-router =
    { pkgs, ... }:
    {
      # Declared so forwarding doesn't depend on netbird flipping it at runtime.
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;

        # Loose rp_filter: forwarded overlay->LAN traffic has an asymmetric return
        # path that strict mode drops.
        "net.ipv4.conf.all.rp_filter" = 2;
        "net.ipv4.conf.default.rp_filter" = 2;
      };

      # For inspecting offloads by hand.
      environment.systemPackages = [ pkgs.ethtool ];

      # UDP GRO forwarding for subnet-router throughput
      # (https://tailscale.com/s/ethtool-config-udp-gro). A drop-in to
      # 99-default.link, not a standalone .link: only the first matching .link
      # applies, so a standalone one would lose NamePolicy and rename NICs; and
      # nixpkgs' typed linkConfig rejects this systemd-260 key.
      environment.etc."systemd/network/99-default.link.d/10-udp-gro-forwarding.conf".text = ''
        [Link]
        GenericReceiveOffloadUDPForwarding=yes
      '';
    };
}
