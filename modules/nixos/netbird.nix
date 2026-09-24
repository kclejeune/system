_: {
  flake.nixosModules.netbird =
    { config, lib, ... }:
    {
      services.netbird.enable = true;

      # "client": forwarding belongs to subnet-router (see tailscale.nix).
      services.netbird.useRoutingFeatures = "client";
      # Tray UI only where there's a graphical session to show it in.
      services.netbird.ui.enable = config.services.graphical-desktop.enable;
    };
}
