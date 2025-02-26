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

  xdg = {
    enable = true;
    configFile = {
      aerospace = lib.mkIf pkgs.stdenvNoCC.isDarwin {
        source = ./aerospace;
        recursive = true;
      };
      ghostty = {
        source = ./ghostty;
        recursive = true;
      };
      "ghostty/macos.conf" = lib.mkIf pkgs.stdenvNoCC.isDarwin {
        text = ''
          font-size = 14
        '';
      };
      kitty = {
        source = ./kitty;
        recursive = true;
      };
      fd = {
        source = ./fd;
        recursive = true;
      };
    };
  };
}
