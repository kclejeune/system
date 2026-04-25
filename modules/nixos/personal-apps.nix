{ config, ... }:
let
  flakeCfg = config;
in
{
  # Personal-only apps and services that should NOT live in the shared
  # `desktop` module, so a future work machine can opt out by enrolling
  # `desktop` without `profile-personal`.
  flake.nixosModules.personal-apps =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [ flakeCfg.flake.nixosModules.keybase ];

      environment.systemPackages = with pkgs; [
        anytype
        discord
        notion-app
      ];

      services.syncthing = {
        enable = true;
        user = config.user.name;
        group = "users";
        openDefaultPorts = true;
        dataDir = config.user.home;
      };
    };
}
