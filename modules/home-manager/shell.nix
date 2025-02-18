{
  config,
  lib,
  pkgs,
  ...
}: let
  zshCustomPrefix = "oh-my-zsh";
  homeDir = config.home.homeDirectory;
in {
  home = {
    preferXdgDirectories = true;
    sessionVariables = {
      GPG_TTY = "/dev/ttys000";
      EDITOR = "nvim";
      VISUAL = "nvim";
      CLICOLOR = 1;
      LSCOLORS = "ExFxBxDxCxegedabagacad";
      NODE_PATH = "${homeDir}/.node";
      LANG = "en_US.UTF-8";
      DEFAULT_USER = "${config.home.username}";
      LS_COLORS = "ExFxBxDxCxegedabagacad";
      TERM = "xterm-256color";
      MISE_ENV_FILE = ".env";
    };
    sessionPath = [
      "${homeDir}/.local/bin"
      "${homeDir}/.node/bin"
    ];
    shellAliases = {
      neofetch = "fastfetch";
      ncdu = "gdu";
      cat = "bat -pp";
    };
  };

  programs.atuin = {
    enable = true;
    package = pkgs.atuin;
    daemon.enable = true;
    settings = {
      update_check = false;
      sync_frequency = "15m";
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
      config.home.sessionVariables
      // {
        ZSH_CUSTOM = "${config.xdg.dataHome}/${zshCustomPrefix}";
      };
    initExtra = ''
      unset RPS1
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
    sessionVariables = config.home.sessionVariables // {};
    initExtra = ''
      eval "$(mise activate bash)"
    '';
  };
}
