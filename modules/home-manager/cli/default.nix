{ config, pkgs, lib, ... }:
let
  functions = builtins.readFile ./functions.sh;
  useSkim = false;
  useFzf = !useSkim;
  fuzz =
    let fd = "${pkgs.fd}/bin/fd";
    in
    rec {
      defaultCommand = "${fd} -H --type f";
      defaultOptions = [ "--height 50%" "--border" ];
      fileWidgetCommand = "${defaultCommand}";
      fileWidgetOptions = [
        "--preview '${pkgs.bat}/bin/bat --color=always --plain --line-range=:200 {}'"
      ];
      changeDirWidgetCommand = "${fd} --type d";
      changeDirWidgetOptions =
        [ "--preview '${pkgs.tree}/bin/tree -C {} | head -200'" ];
    };
  aliases = { cat = "bat"; };
in
{
  home.packages = with pkgs; [ tree ];
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
    } // fuzz;
    fzf = {
      enable = true;
      enableBashIntegration = useFzf;
      enableZshIntegration = useFzf;
      enableFishIntegration = useFzf;
    } // fuzz;
    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
        color = "always";
      };
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
    };
    zsh =
      let
        mkZshPlugin = { pkg, file ? "${pkg.pname}.plugin.zsh" }: rec {
          name = pkg.pname;
          src = pkg.src;
          inherit file;
        };
      in
      {
        enable = true;
        enableCompletion = true;
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
        plugins = with pkgs; [
          (mkZshPlugin { pkg = zsh-autopair; })
          (mkZshPlugin {
            pkg = zsh-fzf-tab;
            file = "fzf-tab.plugin.zsh";
          })
          (mkZshPlugin {
            pkg = zsh-fast-syntax-highlighting;
            file = "fast-syntax-highlighting.plugin.zsh";
          })
          (mkZshPlugin { pkg = zsh-history-substring-search; })
        ];
        oh-my-zsh = {
          enable = true;
          plugins = [ "git" "sudo" ];
        };
      };
    zoxide.enable = true;
    starship.enable = true;
  };
}
