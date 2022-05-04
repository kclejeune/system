{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "alt-tab"
      "1password-beta"
      "bartender"
      "firefox-beta"
      "kitty"
      "raycast"
      "stats"
      "visual-studio-code"
    ];
  };
}
