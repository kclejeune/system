{
  config,
  pkgs,
  lib,
  ...
}: let
  dotfilesPath = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager/dotfiles";
in {
  home.sessionVariables = {
    K9S_SKIN = "one-dark";
  };
  home.file = {
    hammerspoon = lib.mkIf pkgs.stdenvNoCC.isDarwin {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/hammerspoon";
      target = ".hammerspoon";
    };
    raycast = lib.mkIf pkgs.stdenvNoCC.isDarwin {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/raycast";
      target = ".local/bin/raycast";
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
        # source = ./aerospace;
        recursive = true;
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/aerospace";
      };
      ghostty = {
        source = ./ghostty;
        recursive = true;
      };
      k9s = {
        source = "${pkgs.k9s}/share/k9s";
        recursive = true;
      };
      "ghostty/macos.conf" = lib.mkIf pkgs.stdenvNoCC.isDarwin {
        text = ''
          font-size = 14
        '';
      };
      kitty = {
        # source = ./kitty;
        # recursive = true;
        source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/kitty";
      };
      fd = {
        source = ./fd;
        recursive = true;
      };
    };
  };
}
