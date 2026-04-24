{ lib, ... }:
{
  # flake-parts declares flake.nixosModules (core) and flake.homeModules (via
  # home-manager flakeModule), but there's no upstream declaration for
  # flake.darwinModules. Declare it here so multiple wrapper files can each
  # contribute a named darwin module that merges into the attrset.
  options.flake.darwinModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
  };
}
