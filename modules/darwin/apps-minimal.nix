{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "alt-tab"
      "bartender"
      "firefox-developer-edition"
      "kitty"
      "raycast"
      "stats"
      "visual-studio-code"
    ];
  };
}
