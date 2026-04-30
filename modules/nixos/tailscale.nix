_: {
  flake.nixosModules.tailscale = _: {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      openFirewall = true;
    };
  };
}
