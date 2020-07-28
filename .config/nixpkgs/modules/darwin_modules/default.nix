{ pkgs, ... }:
let sources = import ../../nix/sources.nix;
in {
  imports = [
    "${sources.home-manager}/nix-darwin"
    ./lorri.nix
    ./display-manager.nix
    ./preferences.nix
    ../nix-path/darwin.nix
  ];

  fonts = {
    enableFontDir = true;
    fonts = [ pkgs.jetbrains-mono ];
  };
}
