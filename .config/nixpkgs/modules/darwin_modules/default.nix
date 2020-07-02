{ pkgs, ... }:
let sources = import ../../nix/sources.nix;
in {
  imports = [
    "${sources.home-manager}/nix-darwin"
    ./lorri.nix
    ./yabai.nix
    ../nix-path/darwin
  ];
}
