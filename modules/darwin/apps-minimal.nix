{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "1password-beta"
      "bartender"
      "firefox-beta"
      "kitty"
      "raycast"
      "rectangle"
      "stats"
      "visual-studio-code"
    ];
  };
}
