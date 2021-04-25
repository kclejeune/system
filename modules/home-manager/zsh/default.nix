{ config, pkgs, lib, ... }:
let
  functions = builtins.readFile ./functions.sh;
  aliases = {
    ls = "exa";
    la = "exa -la";
    lt = "exa --tree";
  };
in
{
  home.packages = with pkgs; [ fzf exa tree zoxide ];

  programs.bash = {
    enable = true;
    shellAliases = aliases;
    initExtra = ''
      ${functions}
      eval "$(zoxide init bash)"
      unset RPS1
    '';
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
    };
    shellAliases = aliases;
    initExtra = ''
      ${functions}
      eval "$(zoxide init zsh)"
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

  programs.starship = { enable = true; };
}
