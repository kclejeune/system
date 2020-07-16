{ pkgs, ... }:
let sources = import ../../nix/sources.nix;
in {
  imports = [
    "${sources.home-manager}/nix-darwin"
    ./lorri.nix
    ./yabai.nix
    ./preferences.nix
    ../nix-path/darwin
  ];
}
