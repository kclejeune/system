{ inputs, config, pkgs, ... }: {
  imports = [ ../../modules/core.nix ../../modules/dotfiles ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    # only need this if not managed by nix-darwin
    # username = builtins.getEnv "USER";
    # homeDirectory = builtins.getEnv "HOME";

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "20.09";
    sessionVariables = {
      DEFAULT_USER = "${config.home.username}";
      LANG = "en_US.UTF-8";
      GPG_TTY = "/dev/ttys000";
      EDITOR = "nvim";
      VISUAL = "nvim";
      CLICOLOR = 1;
      LSCOLORS = "ExFxBxDxCxegedabagacad";
      JAVA_HOME = "${pkgs.jdk11}";
      NIX_PATH =
        "nixpkgs=${inputs.nixpkgs}:home-manager=${inputs.home-manager}:$NIX_PATH";
    };
  };
}
