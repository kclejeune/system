{ config, pkgs, ... }: {
  imports = [ ./modules/core.nix ./modules/personal-settings.nix ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    # only need this if not managed by nix-darwin
    # username = "kclejeune";
    # homeDirectory = "/Users/kclejeune";

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
      GPG_TTY = "/dev/ttys000";
      DEFAULT_USER = "${config.home.username}";
      EDITOR = "nvim";
      VISUAL = "nvim";
      CLICOLOR = 1;
      LSCOLORS = "ExFxBxDxCxegedabagacad";
      # ASDF_CONFIG_FILE = "${config.xdg.configHome}/asdf/asdfrc";
      # ASDF_DEFAULT_TOOL_VERSIONS_FILENAME =
      # "${config.xdg.configHome}/asdf/tool-versions";
      # ASDF_DATA_DIR = "${config.xdg.dataHome}/asdf";
      KAGGLE_CONFIG_DIR = "${config.xdg.configHome}/kaggle";
      # NIX_PATH = "$HOME/.nix-defexpr/channels\${NIX_PATH:+:}$NIX_PATH";
    };

    # define package definitions for current user environment
    packages = with pkgs; [
      # scripting
      (python3.withPackages
        (ps: with ps; [ bpython black numpy scipy pandas networkx ]))
      ruby
      openjdk11

      # dev garbage
      yarn
      nodejs
      pre-commit

      # command line utilities
      yadm
      ranger
      rsync
      httpie
      pandoc
      ripgrep-all

      # other useful stuff
      youtube-dl
      speedtest-cli
      wireshark-cli
      termshark

      # dotfile management
      yadm

      # encryption and signing utilities
      gnupg

      # nix stuff
      nixfmt

      # typesetting
      (texlive.combine { inherit (texlive) scheme-basic latexindent latexmk; })
      tectonic
    ];
  };

  nixpkgs.config.allowUnfree = true;

  programs = {
    home-manager = {
      enable = true;
      path = "${config.xdg.configHome}/nixpkgs/home.nix";
    };
    direnv = {
      enable = true;
      enableNixDirenvIntegration = true;
    };
    gpg.enable = true;
  };
}
