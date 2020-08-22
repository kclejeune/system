{ lib, ... }:
let sources = import ../../nix/sources.nix { };
in {
  nix.nixPath = (lib.mkForce (lib.mapAttrsToList (k: v: "${k}=${v}") {
    nixpkgs = sources.nixpkgs;
    darwin = sources.nix-darwin;
    home-manager = sources.home-manager;
    darwin-config = ~/.config/nixpkgs/darwin/configuration.nix;
  }));
}

