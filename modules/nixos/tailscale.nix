_: {
  flake.nixosModules.tailscale =
    { config, lib, ... }:
    {
      services.tailscale = {
        enable = true;
        # "client", not "both" or "server". useRoutingFeatures only toggles
        # host-global knobs: "client"/"both" sets networking.firewall
        # .checkReversePath = "loose" (wanted on every node — any client may use
        # an exit node), while "server"/"both" additionally sets the IP-forwarding
        # sysctls. Forwarding is a *router* capability, so it's owned solely by the
        # subnet-router role module (enrolled on the homelab P3 nodes and the
        # Hetzner gateway exit node), keeping it off laptops. Leaving the VPN
        # daemons at "client" also means tailscale and netbird no longer both
        # define net.ipv{4,6}.conf.all.forwarding, which used to collide (that
        # value type rejects a second definition even when both are `true`).
        useRoutingFeatures = "client";
        openFirewall = true;
      };

      # Force tailscaled to manage netfilter via native nftables instead of the
      # iptables-nft compat layer. With networking.nftables.enable = true (our
      # default), iptables-nft can fail to parse rules added by other nftables
      # users, breaking tailscale's `-C` rule check with "cmp sreg undef" and
      # leaving the FORWARD/ts-forward jump missing — subnet routing silently
      # half-works.
      systemd.services.tailscaled.environment.TS_DEBUG_FIREWALL_MODE =
        lib.mkIf config.networking.nftables.enable "nftables";

      networking.firewall.trustedInterfaces = [
        config.services.tailscale.interfaceName
        config.services.netbird.clients.default.interface
      ];
    };
}
