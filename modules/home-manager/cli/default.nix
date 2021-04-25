{ config, pkgs, lib, ... }:
let
  functions = builtins.readFile ./functions.sh;
  useSkim = true;
  useFzf = !useSkim;
  fuzzyCommands = {
    changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d";
    fileWidgetCommand = "${pkgs.fd}/bin/fd --type f";
  };
  aliases = {
    cat = "bat";
  };
in
{
  home.packages = with pkgs; [ tree bat ];
  programs = {
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
    skim = {
      enable = true;
      enableBashIntegration = useSkim;
      enableZshIntegration = useSkim;
      enableFishIntegration = useSkim;
    } // fuzzyCommands;
    fzf = {
      enable = true;
      enableBashIntegration = useFzf;
      enableZshIntegration = useFzf;
      enableFishIntegration = useFzf;
      changeDirWidgetOptions = [ "--preview 'tree -C {} | head -200'" ];
      defaultOptions = [ "--height 40%" "--border" ];
      fileWidgetOptions = [ "--preview '${pkgs.bat}/bin/bat --color=always --plain {}'" ];
    } // fuzzyCommands;
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
    go.enable = true;
    exa = {
      enable = true;
      enableAliases = true;
    };
    bash = {
      enable = true;
      shellAliases = aliases;
      initExtra = ''
        ${functions}
        unset RPS1
      '';
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      enableAutosuggestions = true;
      autocd = true;
      dotDir = ".config/zsh";
      localVariables = {
        LANG = "en_US.UTF-8";
        GPG_TTY = "/dev/ttys000";
        DEFAULT_USER = "${config.home.username}";
        CLICOLOR = 1;
        LS_COLORS = "ExFxBxDxCxegedabagacad";
      };
      shellAliases = aliases;
      initExtra = ''
        ${functions}
        unset RPS1
      '';
      plugins = [
        {
          name = "zsh-syntax-highlighting";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-syntax-highlighting";
            rev = "0.7.1";
            sha256 = "sha256-gOG0NLlaJfotJfs+SUhGgLTNOnGLjoqnUp54V9aFJg8=";
          };
        }
        {
          name = "zsh-history-substring-search";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-history-substring-search";
            rev = "v1.0.2";
            sha256 = "sha256-Ptxik1r6anlP7QTqsN1S2Tli5lyRibkgGlVlwWZRG3k=";
          };
        }
      ];
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "sudo" "common-aliases" ];
      };
    };
    zoxide.enable = true;
    starship.enable = true;
  };
}
