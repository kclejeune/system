{ lib, ... }:
let sources = import ../../../nix/sources.nix;
in {
  nix.nixPath = lib.mapAttrsToList (k: v: "${k}=${v}") {
    nixpkgs = sources.nixpkgs;
    darwin = sources.nix-darwin;
  };
}

