{ config, inputs, ... }:
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
      sops.secrets."mbx-cache/client-token" = {
        sopsFile = ../../secrets/users.yaml;
        key = "mbx-cache/token";
        owner = config.user.name;
      };
      users.users.${config.user.name}.hashedPasswordFile =
        config.sops.secrets."users/kclejeune/password-hash".path;
    };
  # Standalone HM has no system identity module to forward from.
  home =
    {
      config,
      lib,
      pkgs,
      osConfig ? null,
      ...
    }:
    let
      onNixos = osConfig != null && pkgs.stdenv.hostPlatform.isLinux;
      tokenPath =
        if onNixos then
          "/run/secrets/mbx-cache/client-token"
        else
          config.sops.secrets."mbx-cache/token".path;
    in
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];
      identity = {
        enable = true;
        inherit (personalIdentity) displayName email sshSigningKey;
      };
      sops = lib.mkIf (!onNixos) {
        age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
        secrets."mbx-cache/token".sopsFile = ../../secrets/users.yaml;
      };
      programs.mr-boxington.settings.remote = {
        url = "https://mbx.kclj.dev";
        namespace = "kclejeune/dev";
        mode = "read-write";
        token_file = tokenPath;
      };
    };
}
