{ config, ... }:
let
  flakeCfg = config;
in
{
  # Opted into by the personal laptop builder, not the reusable desktop stack.
  flake.nixosModules.personal-monitoring =
    { config, ... }:
    {
      imports = [
        flakeCfg.flake.nixosModules.traceway-agent
        flakeCfg.flake.nixosModules.beszel-agent
      ];

      # Reuse the homelab's Traceway project without exposing its other secrets.
      sops.secrets.${config.services.traceway.agent.tokenSecret}.sopsFile = ../../secrets/laptops.yaml;

      # The universal token must be active for each host's first registration.
      sops.secrets."beszel/token" = {
        sopsFile = ../../secrets/laptops.yaml;
        restartUnits = [ "beszel-agent.service" ];
      };
      # Roaming laptops connect out to the hub; don't run Beszel's SSH listener.
      services.beszel.agent.environment.DISABLE_SSH = "true";
    };
}
