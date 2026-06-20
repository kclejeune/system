_: {
  # vault — data / storage node. Bare-metal Lenovo P3 Tiny. Role scaffolding
  # only this round (syncthing / DBs / NFS land later).
  flake.nixosModules.vault =
    { config, ... }:
    {
      networking.hostName = "vault";

      users.users.${config.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
      identity.enableRootSshKeys = true;

      sops.defaultSopsFile = ../../secrets/vault.yaml;
      # backup (restic/*) stays off in flake.nix until real restic repo /
      # password / R2 creds exist; beszel-agent is on (token in sops).

      system.stateVersion = "25.11";
    };
}
