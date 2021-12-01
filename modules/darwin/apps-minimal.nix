{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "1password-beta"
      "bartender"
      "firefox-beta"
      "jetbrains-toolbox"
      "karabiner-elements"
      "keepingyouawake"
      "kitty"
      "raycast"
      "stats"
      "visual-studio-code"
    ];
  };
}
