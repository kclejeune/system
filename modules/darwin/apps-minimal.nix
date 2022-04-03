{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "1password-beta"
      "bartender"
      "firefox-beta"
      "jetbrains-toolbox"
      "keepingyouawake"
      "kitty"
      "raycast"
      "rectangle"
      "stats"
      "visual-studio-code"
    ];
  };
}
