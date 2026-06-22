_: {
  flake.nixosModules.netbird =
    { config, lib, ... }:
    {
      services.netbird.enable = true;
      services.netbird.useRoutingFeatures = "both";
      services.netbird.ui.enable = true;
    };
}
