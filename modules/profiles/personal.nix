{ config, ... }:
let
  flakeCfg = config;

  personalIdentity = rec {
    name = "kclejeune";
    displayName = "Kennan LeJeune";
    email = "kennan@case.edu";
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM48VQYrCQErK9QdC/mZ61Yzjh/4xKpgZ2WU5G19FpBG"
    ];
    sshSigningKey = builtins.head sshKeys;
  };
  osBody = _: {
    identity = personalIdentity // {
      enable = true;
    };
    hm.imports = [ flakeCfg.flake.homeModules.profile-personal ];
  };
in
(import ../_lib.nix).mkAspect {
  name = "profile-personal";
  # nix-darwin doesn't manage account passwords.
  darwin = osBody;
  # The password hash lives here, not in `desktop`, so a work machine that
  # skips this profile never gets it.
  nixos =
    { config, ... }:
    {
      imports = [ osBody ];
      sops.secrets."users/kclejeune/password-hash" = {
        sopsFile = ../../secrets/users.yaml;
        neededForUsers = true;
      };
      users.users.${config.user.name}.hashedPasswordFile =
        config.sops.secrets."users/kclejeune/password-hash".path;
    };
  # Standalone HM has no system identity module to forward from.
  home = _: {
    identity = {
      enable = true;
      inherit (personalIdentity) displayName email sshSigningKey;
    };
  };
}
