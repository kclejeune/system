# home-manager shares the system's nix package so the two evaluations agree.
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
