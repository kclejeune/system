_: {
  flake.nixosModules.tailscale =
    { config, lib, ... }:
    {
      services.tailscale = {
        enable = true;
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

      networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
    };
}
