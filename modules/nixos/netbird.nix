_: {
  flake.nixosModules.netbird =
    { config, lib, ... }:
    {
      services.netbird.enable = true;

      # "client", matching tailscale.nix. useRoutingFeatures only toggles
      # host-global knobs: the "client"/"both" branch sets networking.firewall
      # .checkReversePath = "loose" (wanted everywhere — clients may use exit
      # nodes), while "server"/"both" additionally sets the IP-forwarding sysctls.
      # Forwarding is a router capability owned solely by the subnet-router role
      # module, not the VPN daemons — so neither tailscale nor netbird enables it,
      # which also avoids the two of them redefining net.ipv{4,6}.conf.all
      # .forwarding at the same priority (that value type rejects a duplicate
      # definition even when both are `true`).
      services.netbird.useRoutingFeatures = "client";
      services.netbird.ui.enable = true;
    };
}
