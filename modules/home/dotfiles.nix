_: {
  flake.homeModules.dotfiles =
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
        default = "${config.home.homeDirectory}/.nixpkgs/modules/home/assets/dotfiles";
        description = "Path to the dotfiles directory in the checked-out repository";
      };

      config = {
        home.sessionVariables.K9S_SKIN = "one-dark";
        home.file = {
          hammerspoon = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
            source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/hammerspoon";
            target = ".hammerspoon";
          };
        };

        xdg = {
          enable = true;
          configFile = {
            k9s = {
              source = "${pkgs.k9s}/share/k9s";
              recursive = true;
            };
            fd = {
              source = ./assets/dotfiles/fd;
              recursive = true;
            };

            aerospace = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
              recursive = true;
              source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/aerospace";
            };

            ghostty = lib.mkIf config.desktop.enable {
              source = ./assets/dotfiles/ghostty;
              recursive = true;
            };
            "ghostty/macos.conf" = lib.mkIf (config.desktop.enable && pkgs.stdenv.hostPlatform.isDarwin) {
              text = ''
                font-size = 14
              '';
            };
            kitty = lib.mkIf config.desktop.enable {
              source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/kitty";
            };
            "zed/keymap.json" = lib.mkIf config.desktop.enable {
              source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/zed/keymap.json";
            };
            vicinae = lib.mkIf (config.desktop.enable && pkgs.stdenv.hostPlatform.isLinux) {
              source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/vicinae";
            };
          };
        };
      };
    };
}
