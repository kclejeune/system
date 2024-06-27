{
  config,
  lib,
  pkgs,
  ...
}: let
  functions = builtins.readFile ./functions.sh;
  aliases =
    rec {
      ls = "${pkgs.coreutils}/bin/ls --color=auto -h";
      la = "${ls} -a";
      ll = "${ls} -la";
      lt = "${ls} -lat";
    }
    // lib.optionalAttrs pkgs.stdenvNoCC.isDarwin {
      # darwin specific aliases
      ibrew = "arch -x86_64 brew";
      abrew = "arch -arm64 brew";
    };
  initExtraCommon = {shell ? "bash"}:
    lib.concatStringsSep "\n" [
      functions
      ''
        eval "$(${pkgs.mise}/bin/mise activate ${shell})"
      ''
    ];
in {
  programs.zsh = let
    mkZshPlugin = {
      pkg,
      file ? "${pkg.pname}.plugin.zsh",
    }: {
      name = pkg.pname;
      src = pkg.src;
      inherit file;
    };
  in {
    enable = true;
    autocd = true;
    dotDir = ".config/zsh";
    localVariables = {
      LANG = "en_US.UTF-8";
      GPG_TTY = "/dev/ttys000";
      DEFAULT_USER = "${config.home.username}";
      CLICOLOR = 1;
      LS_COLORS = "ExFxBxDxCxegedabagacad";
      TERM = "xterm-256color";
    };
    shellAliases = aliases;
    initExtraBeforeCompInit = ''
      fpath+=~/.zfunc
    '';
    initExtra = ''
      ${(initExtraCommon {shell = "zsh";})}
      unset RPS1
    '';
    profileExtra = ''
      ${lib.optionalString pkgs.stdenvNoCC.isLinux "[[ -e /etc/profile ]] && source /etc/profile"}
    '';
    plugins = [
      (mkZshPlugin {pkg = pkgs.zsh-autopair;})
      (mkZshPlugin {pkg = pkgs.zsh-completions;})
      (mkZshPlugin {pkg = pkgs.zsh-autosuggestions;})
      (mkZshPlugin {
        pkg = pkgs.zsh-fast-syntax-highlighting;
        file = "fast-syntax-highlighting.plugin.zsh";
      })
      (mkZshPlugin {pkg = pkgs.zsh-history-substring-search;})
    ];
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "brew"
        "asdf"
        "1password"
      ];
    };
  };

  programs.bash = {
    enable = true;
    shellAliases = aliases;
    initExtra = initExtraCommon {shell = "bash";};
  };
}
