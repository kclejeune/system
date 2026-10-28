{ config, ... }:
let
  flakeCfg = config;
in
{
  # Kept out of `desktop` so a work machine can enroll that without these.
  flake.nixosModules.personal-apps =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [ flakeCfg.flake.nixosModules.codex-remote-control ];

      # User services run only while a login session is active.
      users.users.${config.user.name}.linger = false;

      environment.systemPackages = with pkgs; [
        chatgpt
        claude-desktop
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
