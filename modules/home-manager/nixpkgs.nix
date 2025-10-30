{
  inputs,
  config,
  lib,
  ...
}: {
  nix = {
    gc.automatic = false;
    registry = {
      home-manager.flake = inputs.home-manager;
      nixpkgs.flake = inputs.nixpkgs;
      stable.flake = inputs.stable;
      unstable.flake = inputs.unstable;
    };
    nixPath = lib.mapAttrsToList (name: value: "${name}=${value.flake}") config.nix.registry;
  };
}
