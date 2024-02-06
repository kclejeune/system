{
  config,
  pkgs,
  lib,
  ...
}: {
  home.file = {
    hammerspoon = lib.mkIf pkgs.stdenvNoCC.isDarwin {
      source = ./hammerspoon;
      target = ".hammerspoon";
      recursive = true;
    };
    raycast = lib.mkIf pkgs.stdenvNoCC.isDarwin {
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
    # kitty = lib.mkIf pkgs.stdenvNoCC.isDarwin {
    #   source = ./kitty;
    #   recursive = true;
    # };
  };
}
