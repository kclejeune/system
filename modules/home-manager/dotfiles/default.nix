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
      "nixpkgs/config.nix".source = ../../config.nix;
      aerospace = lib.mkIf pkgs.stdenvNoCC.isDarwin {
        source = ./aerospace;
        recursive = true;
      };
      ghostty = {
        source = ./ghostty;
        recursive = true;
      };
      "ghostty/os.conf" = lib.mkMerge [
        (lib.mkIf pkgs.stdenvNoCC.isDarwin {
          source = ./ghostty/macos.conf;
        })
        (lib.mkIf pkgs.stdenvNoCC.isLinux {
          source = ./ghostty/linux.conf;
        })
      ];
      kitty = {
        source = ./kitty;
        recursive = true;
      };
    };
  };
}
