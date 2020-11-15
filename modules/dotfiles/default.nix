{ config, pkgs, ... }: {
  home.file = {
    brewfile = {
      source = ./Brewfile;
      target = "Brewfile";
    };
    keras = {
      source = ./keras;
      target = ".keras";
      recursive = true;
    };
  };

  xdg.configFile = {
    nixpkgs = {
      source = ./../..;
      recursive = true;
    };
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
