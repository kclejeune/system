_: {
  # atlas — infra / backup node. Bare-metal Lenovo P3 Tiny. Role scaffolding
  # only this round (monitoring / restic-repo orchestration land later).
  flake.nixosModules.atlas =
    { config, ... }:
    {
      networking.hostName = "atlas";

      users.users.${config.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
      identity.enableRootSshKeys = true;

      sops.defaultSopsFile = ../../secrets/atlas.yaml;

      system.stateVersion = "25.11";
    };
}
