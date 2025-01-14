{
  config,
  lib,
  pkgs,
  ...
}: let
  aliases = {
    neofetch = "fastfetch";
    ncdu = "gdu";
    cat = "bat -pp";
  };
  zshCustomPrefix = "oh-my-zsh";
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
  programs.atuin = {
    enable = true;
    package = pkgs.atuin;
    daemon = {
      enable = false;
      logLevel = "warn";
    };
    flags = [];
  };
  # configure zsh custom plugin directory
  xdg = let
    mkZshPlugin = {
      pkg,
      plugin ? pkg.pname,
    }: {
      "${zshCustomPrefix}/plugins/${plugin}" = {
        source = "${pkg.src}";
        recursive = true;
      };
    };
  in {
    enable = true;
    dataFile = lib.mkMerge [
      (mkZshPlugin {pkg = pkgs.zsh-autopair;})
      (mkZshPlugin {pkg = pkgs.zsh-completions;})
      (mkZshPlugin {pkg = pkgs.zsh-autosuggestions;})
      (mkZshPlugin {
        pkg = pkgs.zsh-fast-syntax-highlighting;
        plugin = "fast-syntax-highlighting";
      })
      (mkZshPlugin {pkg = pkgs.zsh-history-substring-search;})
    ];
  };
  programs.zsh = {
    enable = true;
    autocd = true;
    dotDir = ".config/zsh";
    sessionVariables =
      commonVariables
      // {
        ZSH_CUSTOM = "${config.xdg.dataHome}/${zshCustomPrefix}";
      };
    shellAliases = aliases;
    initExtra = ''
      unset RPS1
    '';
    profileExtra = ''
      ${lib.optionalString pkgs.stdenvNoCC.isLinux "[[ -f /etc/profile ]] && source /etc/profile"}
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [
        "1password"
        "argocd"
        "brew"
        "git"
        "kitty"
        "mise"
        "poetry"
        "starship"
        "sudo"
        "zoxide"

        # order matters for these ones, probably
        "zsh-autopair"
        "zsh-completions"
        "zsh-autosuggestions"
        "fast-syntax-highlighting"
        "zsh-history-substring-search"
      ];
    };
  };

  programs.bash = {
    enable = true;
    shellAliases = aliases;
    sessionVariables = commonVariables;
    initExtra = ''
      eval "$(mise activate bash)"
      eval "$(mise hook-env -s bash)"
    '';
  };
}
