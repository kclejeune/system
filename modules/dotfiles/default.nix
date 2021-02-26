{ config, pkgs, ... }: {
  home.file = {
    keras = {
      source = ./keras;
      target = ".keras";
      recursive = true;
    };
  };

  xdg.enable = true;
  xdg.configFile = {
    "nixpkgs/config.nix".source = ../config.nix;
    karabiner = {
      source = ./karabiner;
      recursive = true;
    };
    skhd = {
      source = ./skhd;
      recursive = true;
    };
    yabai = {
      source = ./yabai;
      recursive = true;
    };
  };
}
