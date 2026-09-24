_: {
  flake.nixosModules.tailscale =
    { config, lib, ... }:
    {
      services.tailscale = {
        enable = true;
        # "client" only relaxes rp_filter. Forwarding belongs to subnet-router so it
        # stays off laptops, and setting it here too collides with netbird's
        # forwarding sysctls.
        useRoutingFeatures = "client";
        openFirewall = true;
      };

      # Native nftables: iptables-nft can't parse other nftables users' rules,
      # and subnet routing silently half-works.
      systemd.services.tailscaled.environment.TS_DEBUG_FIREWALL_MODE =
        lib.mkIf config.networking.nftables.enable "nftables";

      networking.firewall.trustedInterfaces = [
        config.services.tailscale.interfaceName
        config.services.netbird.clients.default.interface
      ];
    };
}
