_: {
  flake.nixosModules.tailscale =
    { config, ... }:
    {
      services.tailscale = {
        enable = true;
        useRoutingFeatures = "client";
        openFirewall = true;
      };

      networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
    };
}
