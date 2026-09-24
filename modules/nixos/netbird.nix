_: {
  flake.nixosModules.netbird =
    { config, lib, ... }:
    {
      services.netbird.enable = true;

      # "client" — see tailscale.nix for the full rationale: forwarding is owned
      # by the subnet-router role module, not the VPN daemons, so neither enables
      # it (which also avoids both redefining the forwarding sysctls and colliding).
      services.netbird.useRoutingFeatures = "client";
      # Tray UI only where there's a graphical session to show it in.
      services.netbird.ui.enable = config.services.graphical-desktop.enable;
    };
}
