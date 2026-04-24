{
  self,
  inputs,
  config,
  lib,
  ...
}:
let
  darwinSystems = lib.intersectLists lib.platforms.aarch64 lib.platforms.darwin;
  defaultSystems =
    (lib.intersectLists lib.platforms.linux (lib.platforms.x86_64 ++ lib.platforms.aarch64))
    ++ darwinSystems;

  homePrefix = system: if (lib.elem system darwinSystems) then "/Users" else "/home";
  username = "kclejeune";
in
{
  flake.homeConfigurations = lib.mergeAttrsList (
    lib.map (system: {
      "kclejeune@${system}" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnsupportedSystem = true;
            allowUnfree = true;
            allowBroken = false;
          };
          overlays = [ self.overlays.default ];
        };
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
