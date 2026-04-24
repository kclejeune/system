{ inputs, ... }:
{
  imports = [
    inputs.home-manager.flakeModules.home-manager
    inputs.treefmt-nix.flakeModule
    inputs.flake-parts.flakeModules.easyOverlay
    inputs.git-hooks.flakeModule
  ];
}
