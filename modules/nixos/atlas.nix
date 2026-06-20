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
      # backup (restic/*) stays off in flake.nix until real restic repo /
      # password / R2 creds exist; beszel-agent is on (token in sops).

      system.stateVersion = "25.11";
    };
}
