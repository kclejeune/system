{
  config,
  pkgs,
  lib,
  ...
}:
let
  dotfilesPath = config.dotfiles.path;
in
{
  options.dotfiles.path = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager/dotfiles";
    description = "Path to the dotfiles directory in the checked-out repository";
  };

  config = {
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
    };

    xdg = {
      enable = true;
      configFile = {
        aerospace = lib.mkIf pkgs.stdenvNoCC.isDarwin {
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
          source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/kitty";
        };
        fd = {
          source = ./fd;
          recursive = true;
        };
        "zed/keymap.json" = {
          source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/zed/keymap.json";
        };
        vicinae = lib.mkIf pkgs.stdenvNoCC.isLinux {
          source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/vicinae";
        };
      };
    };
  };
}
