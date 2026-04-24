{ config, ... }:
let
  flakeCfg = config;
in
(import ../_lib.nix).mkAspect {
  name = "profile-personal";
  os = _: {
    user.name = "kclejeune";
    hm.imports = [ flakeCfg.flake.homeModules.profile-personal ];
  };
  home = _: {
    programs.git = {
      settings.user.email = "kennan@case.edu";
      settings.user.name = "Kennan LeJeune";
      signing.key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM48VQYrCQErK9QdC/mZ61Yzjh/4xKpgZ2WU5G19FpBG";
    };
  };
}
