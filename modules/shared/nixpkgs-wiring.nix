{ self, ... }:
let
  # System-side nixpkgs wiring: applies overlays and nixpkgs.config, and
  # makes home-manager share the system's nix package so `nix.package` is
  # consistent across the two evaluations.
  body =
    { config, lib, ... }:
    {
      nixpkgs = {
        config = {
          allowUnsupportedSystem = true;
          allowUnfree = true;
          allowBroken = false;
        };
        overlays = [ self.overlays.default ];
      };

      home-manager.sharedModules = [
        {
          nix.enable = lib.mkForce true;
          nix.package = lib.mkForce config.nix.package;
        }
      ];
    };
in
{
  flake.nixosModules.nixpkgs-wiring = body;
  flake.darwinModules.nixpkgs-wiring = body;
}
