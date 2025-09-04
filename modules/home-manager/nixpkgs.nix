{
  inputs,
  config,
  lib,
  ...
}: {
  nix = {
    gc.automatic = false;
    registry = {
      unstable.flake = inputs.unstable;
      stable.flake = inputs.stable;
      home-manager.flake = inputs.home-manager;
    };
    nixPath = lib.mapAttrsToList (name: value: "${name}=${value.flake}") config.nix.registry;
  };
}
