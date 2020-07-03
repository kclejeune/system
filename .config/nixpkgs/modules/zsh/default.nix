{ config, pkgs, ... }:
let
  functions = builtins.readFile ./functions.sh;
  aliases = {
    brewup = "brew upgrade && brew cask upgrade && brew cleanup";
    ls = "exa";
    ll = "exa -l";
    la = "exa -la";
    lt = "exa --tree";
    lst = "exa --tree";
  };
in {
  home.packages = with pkgs; [ fzf exa tree ];

  programs.bash = {
    enable = true;
    shellAliases = aliases;
  };

  programs.zsh = {
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
      XDG_CONFIG_HOME = "${config.xdg.configHome}";
      XDG_DATA_HOME = "${config.xdg.dataHome}";
    };
    shellAliases = aliases;
    initExtra = ''
      ${functions}
    '';
    plugins = [
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-syntax-highlighting";
          rev = "0.7.1";
          sha256 = "03r6hpb5fy4yaakqm3lbf4xcvd408r44jgpv4lnzl9asp4sb9qc0";
        };
      }

      {
        name = "fz";
        src = pkgs.fetchFromGitHub {
          owner = "changyuheng";
          repo = "fz";
          rev = "ae0cd3ab0f0daebc80256f1236eda3a3283e4c1c";
          sha256 = "0x3w03gcqhyhfhjfxvbp5m1i96ihq9l3m52w4xnpbkchqfsyw737";
        };
      }
    ];
    oh-my-zsh = {
      enable = true;
      theme = "agnoster";
      plugins = [
        "git"
        "sudo"
        "command-not-found"
        "common-aliases"
        "fzf"
        "history-substring-search"
        "z"
        "virtualenv"
      ];
    };
  };
}
