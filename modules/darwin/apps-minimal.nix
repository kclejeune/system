{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "1password-beta"
      "firefox-beta"
      "karabiner-elements"
      "keepingyouawake"
      "kitty"
      "raycast"
      "visual-studio-code"
    ];
  };
}
