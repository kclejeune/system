_: {
  flake.homeModules.nixpkgs =
    {
      inputs,
      nixpkgs,
      config,
      lib,
      ...
    }:
    {
      nix = {
        gc.automatic = false;
        registry = {
          home-manager.flake = inputs.home-manager;
          nixpkgs.flake = nixpkgs;
          multiverse.flake = inputs.multiverse;
          unstable.flake = inputs.unstable;
        };
        nixPath = lib.mapAttrsToList (name: value: "${name}=${value.flake}") config.nix.registry;
      };
    };
}
