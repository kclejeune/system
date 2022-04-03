{ config, pkgs, lib, ... }: {
  home.file = {
    keras = {
      source = ./keras;
      target = ".keras";
      recursive = true;
    };
    hammerspoon = {
      source = ./hammerspoon;
      target = ".hammerspoon";
      recursive = true;
    };
    raycast = {
      source = ./raycast;
      target = ".local/bin/raycast";
      recursive = true;
    };
    zfunc = {
      source = ./zfunc;
      target = ".zfunc";
      recursive = true;
    };
    npmrc = {
      text = ''
        prefix = ${config.home.sessionVariables.NODE_PATH};
      '';
      target = ".npmrc";
    };
  };

  xdg.enable = true;
  xdg.configFile = {
    "nixpkgs/config.nix".source = ../../config.nix;
    # kitty = {
    #   source = ./kitty;
    #   recursive = true;
    # };
    yabai = {
      source = ./yabai;
      recursive = true;
    };
  };
}
