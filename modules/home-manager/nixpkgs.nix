{
  inputs,
  config,
  lib,
  ...
}: {
  nix = rec {
    gc = {
      automatic = true;
      options = "--delete-older-than 60d";
    };
    registry = {
      unstable.flake = inputs.unstable;
      stable.flake = inputs.stable;
      home-manager.flake = inputs.home-manager;
    };
    nixPath = lib.mapAttrsToList (name: value: "${name}=${registry.${name}.flake}") config.nix.registry;
  };
}
