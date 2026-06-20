_: {
  # forge — general / dev-utilities node. Bare-metal Lenovo P3 Tiny.
  # This round: attic (R2-backed nix cache) + AirPrint (added in later tasks).
  flake.nixosModules.forge =
    { config, ... }:
    {
      networking.hostName = "forge";

      users.users.${config.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
      identity.enableRootSshKeys = true;

      sops.defaultSopsFile = ../../secrets/forge.yaml;

      system.stateVersion = "25.11";
    };
}
