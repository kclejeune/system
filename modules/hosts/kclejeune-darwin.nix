{
  self,
  inputs,
  config,
  lib,
  ...
}:
let
  darwinSystems = lib.intersectLists lib.platforms.aarch64 lib.platforms.darwin;
in
{
  flake.darwinConfigurations = lib.mergeAttrsList (
    lib.map (system: {
      "kclejeune@${system}" = inputs.darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {
          inherit self inputs;
          nixpkgs = inputs.nixpkgs;
        };
        modules = [
          inputs.determinate.darwinModules.default
          inputs.home-manager.darwinModules.home-manager

          config.flake.darwinModules.default

          config.flake.darwinModules.profile-personal
          config.flake.darwinModules.apps
        ];
      };
    }) darwinSystems
  );
}
