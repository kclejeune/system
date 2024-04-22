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
    // lib.optionalAttrs pkgs.stdenvNoCC.isDarwin rec {
      # darwin specific aliases
      ibrew = "arch -x86_64 brew";
      abrew = "arch -arm64 brew";
    };
  initExtraCommon = ''
    ${functions}
    ${lib.optionalString pkgs.stdenvNoCC.isDarwin ''
      if [[ -d /opt/homebrew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
    ''}
    if [[ -d "${config.home.homeDirectory}/.asdf/" ]]; then
      . "${config.home.homeDirectory}/.asdf/asdf.sh"
      . "${config.home.homeDirectory}/.asdf/completions/asdf.bash"
    fi
    eval "$(${pkgs.devbox}/bin/devbox global shellenv)"
  '';
in {
  programs.zsh = let
    mkZshPlugin = {
      pkg,
      file ? "${pkg.pname}.plugin.zsh",
    }: rec {
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
      ${initExtraCommon}
      unset RPS1
    '';
    profileExtra = ''
      ${lib.optionalString pkgs.stdenvNoCC.isLinux "[[ -e /etc/profile ]] && source /etc/profile"}
    '';
    plugins = with pkgs; [
      (mkZshPlugin {pkg = zsh-autopair;})
      (mkZshPlugin {pkg = zsh-completions;})
      (mkZshPlugin {pkg = zsh-autosuggestions;})
      (mkZshPlugin {
        pkg = zsh-fast-syntax-highlighting;
        file = "fast-syntax-highlighting.plugin.zsh";
      })
      (mkZshPlugin {pkg = zsh-history-substring-search;})
    ];
    oh-my-zsh = {
      enable = true;
      plugins = ["git" "sudo" "asdf"];
    };
  };

  programs.bash = {
    enable = true;
    shellAliases = aliases;
    initExtra = ''
      ${initExtraCommon}
    '';
  };
}
