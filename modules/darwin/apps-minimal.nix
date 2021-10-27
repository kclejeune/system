{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "1password-beta"
      "bartender"
      "firefox-beta"
      "karabiner-elements"
      "keepingyouawake"
      "kitty"
      "raycast"
      "visual-studio-code"
    ];
  };
}
