{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "1password"
      "adobe-acrobat-pro"
      "appcleaner"
      "displaperture"
      "eul"
      "firefox-beta"
      "fork"
      "gpg-suite"
      "gswitch"
      "iina"
      "intellij-idea"
      "karabiner-elements"
      "keepingyouawake"
      "keybase"
      "kitty"
      "maccy"
      "raycast"
      "skim"
      "syncthing"
      "visual-studio-code"
      "zoom"
    ];
    masApps = { "Unsplash Wallpapers" = 1284863847; };
  };
}
