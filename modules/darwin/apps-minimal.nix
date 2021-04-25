{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "1password"
      "firefox"
      "karabiner-elements"
      "keepingyouawake"
      "kitty"
      "raycast"
      "visual-studio-code"
    ];
  };
}
