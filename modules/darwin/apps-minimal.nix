{ config, lib, pkgs, ... }: {
  programs.homebrew = {
    casks = [
      "1password"
      "appcleaner"
      "firefox"
      "fork"
      "gpg-suite"
      "karabiner-elements"
      "keepingyouawake"
      "keybase"
      "kitty"
      "raycast"
      "visual-studio-code"
    ];
  };
}
