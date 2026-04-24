# System-side nixpkgs wiring: applies overlays and nixpkgs.config, and
# makes home-manager share the system's nix package so `nix.package` is
# consistent across the two evaluations.
{ self, ... }:
let
  inherit (import ../_lib.nix) mkAspect mkNixpkgsArgs;
in
mkAspect {
  name = "nixpkgs-wiring";
  os =
    { config, lib, ... }:
    {
      nixpkgs = mkNixpkgsArgs { inherit self; };

      home-manager.sharedModules = [
        {
          nix.enable = lib.mkForce true;
          nix.package = lib.mkForce config.nix.package;
        }
      ];
    };
}
