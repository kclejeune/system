{
  self,
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (import ../_lib.nix) mkNixpkgsArgs;

  darwinSystems = lib.intersectLists lib.platforms.aarch64 lib.platforms.darwin;
  defaultSystems =
    (lib.intersectLists lib.platforms.linux (lib.platforms.x86_64 ++ lib.platforms.aarch64))
    ++ darwinSystems;

  homePrefix = system: if (lib.elem system darwinSystems) then "/Users" else "/home";
  username = "kclejeune";

  nixpkgsArgs = mkNixpkgsArgs { inherit self; };
in
{
  flake.homeConfigurations = lib.mergeAttrsList (
    lib.map (system: {
      "kclejeune@${system}" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = import inputs.nixpkgs (nixpkgsArgs // { inherit system; });
        extraSpecialArgs = {
          inherit self inputs;
          nixpkgs = inputs.nixpkgs;
        };
        modules = [
          config.flake.homeModules.default
          config.flake.homeModules.profile-personal
          (
            { pkgs, ... }:
            {
              nix.package = pkgs.nix;
              home = {
                inherit username;
                homeDirectory = "${homePrefix system}/${username}";
              };
            }
          )
        ];
      };
    }) defaultSystems
  );
}
