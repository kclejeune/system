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

  mkPath = path: ''
    case ":$PATH:" in
      *:"${path}":*)
        ;;
      *)
        export PATH="${path}:$PATH"
        ;;
    esac
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
    sessionVariables = commonVariables;
    shellAliases = aliases;
    initExtraBeforeCompInit = ''
      ${mkPath "~/.local/bin"}
      fpath+=~/.zfunc
    '';
    initExtra = ''
      unset RPS1
    '';
    profileExtra = ''
      ${lib.optionalString pkgs.stdenvNoCC.isLinux "[[ -f /etc/profile ]] && source /etc/profile"}
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
        "1password"
        "brew"
        "git"
        "mise"
        "sudo"
      ];
    };
  };

  programs.bash = {
    enable = true;
    shellAliases = aliases;
    sessionVariables = commonVariables;
    initExtra = ''
      ${mkPath "~/.local/bin"}
      eval "$(mise activate bash)"
      eval "$(mise hook-env -s bash)"
    '';
  };
}
