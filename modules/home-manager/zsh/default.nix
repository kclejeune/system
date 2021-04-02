{ config, pkgs, lib, ... }:
let
  functions = builtins.readFile ./functions.sh;
  aliases = {
    ls = "${pkgs.exa}/bin/exa";
    la = "${pkgs.exa}/bin/exa -la";
    lt = "${pkgs.exa}/bin/exa --tree";
  };
in
{
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
    };
    shellAliases = aliases;
    initExtra = ''
      ${functions}
      unset RPS1
    '';
    plugins = [
      {
        name = "zsh-z";
        src = pkgs.fetchFromGitHub {
          owner = "agkozak";
          repo = "zsh-z";
          rev = "595c883abec4682929ffe05eb2d088dd18e97557";
          sha256 = "sha256-HnwUWqzwavh/Qox+siOe5lwTp7PBdiYx+9M0NMNFx00=";
        };
      }
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
      # theme = "agnoster";
      plugins = [ "git" "sudo" "common-aliases" "z" ];
    };
  };

  programs.starship = { enable = true; };
}
