{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "alt-tab"
      "bartender"
      "firefox-beta"
      "kitty"
      "rancher"
      "raycast"
      "stats"
      "visual-studio-code"
    ];
  };
}
