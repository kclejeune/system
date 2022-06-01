{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "alt-tab"
      "bartender"
      "firefox-beta"
      "kitty"
      "raycast"
      "stats"
      "visual-studio-code"
    ];
  };
}
