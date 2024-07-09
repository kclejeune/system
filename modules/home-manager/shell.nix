{
  config,
  lib,
  pkgs,
  ...
}: let
  aliases = rec {
    ls = "${pkgs.coreutils}/bin/ls --color=auto -h";
    la = "${ls} -a";
    ll = "${ls} -la";
    lt = "${ls} -lat";
  };
  localBin = ''
    export PATH=${config.home.homeDirectory}/.local/bin:$PATH
  '';
  miseActivate = ''
    eval "$(mise activate $MISE_SHELL)"
    eval "$(mise hook-env -s $MISE_SHELL)"
  '';
  commonVariables = {
    LANG = "en_US.UTF-8";
    GPG_TTY = "/dev/ttys000";
    DEFAULT_USER = "${config.home.username}";
    CLICOLOR = 1;
    LS_COLORS = "ExFxBxDxCxegedabagacad";
    TERM = "xterm-256color";
    MISE_ENV_FILE = ".env";
  };
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
    sessionVariables =
      commonVariables
      // {
        MISE_SHELL = "zsh";
      };
    shellAliases = aliases;
    # initExtraBeforeCompInit = ''
    #   fpath+=~/.zfunc
    # '';
    initExtra = ''
      ${localBin}
      ${miseActivate}
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
        "1password"
      ];
    };
  };

  programs.bash = {
    enable = true;
    shellAliases = aliases;
    sessionVariables =
      commonVariables
      // {
        MISE_SHELL = "bash";
      };
    initExtra = ''
      ${localBin}
      ${miseActivate}
    '';
  };
}
