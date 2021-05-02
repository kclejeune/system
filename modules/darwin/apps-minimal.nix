{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "1password"
      "firefox-beta"
      "karabiner-elements"
      "keepingyouawake"
      "kitty"
      "raycast"
      "visual-studio-code"
    ];
  };
}
