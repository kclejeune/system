{ config, pkgs, ... }: {
  imports = [ ./vim ./zsh ./kitty ./dotfiles ./git.nix ];

  # install extra common packages
  home.packages = with pkgs; [
     ];

  programs = {
    home-manager = {
      enable = true;
      path = "../machines/home.nix";
    };
    direnv = {
      enable = true;
      enableNixDirenvIntegration = true;
      stdlib = ''
        # stolen from @i077; store .direnv in cache instead of project dir
        declare -A direnv_layout_dirs
        direnv_layout_dir() {
            echo "''${direnv_layout_dirs[$PWD]:=$(
                echo -n "${config.xdg.cacheHome}"/direnv/layouts/
                echo -n "$PWD" | shasum | cut -d ' ' -f 1
            )}"
        }
      '';
    };
    fzf = {
      enable = true;
      defaultOptions = [ "--height 40%" "--border" ];
      changeDirWidgetCommand = "fd --type d";
      changeDirWidgetOptions = [ "--preview 'tree -C {} | head -200'" ];
      fileWidgetCommand = "fd --type f";
      fileWidgetOptions = [ "--preview 'bat --color=always --plain {}'" ];
    };
    bat = {
      enable = true;
      config = { theme = "TwoDark"; };
    };
    jq.enable = true;
    htop.enable = true;
    gpg.enable = true;
    git = {
      enable = true;
      lfs.enable = true;
      aliases = {
        ignore =
          "!gi() { curl -sL https://www.toptal.com/developers/gitignore/api/$@ ;}; gi";
      };
    };
  };
}
