{ self, inputs, config, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
in
{
  imports = [
    ./nvim
    ./cli
    ./kitty
    ./dotfiles
    ./git.nix
    ./1password
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  programs.home-manager = {
    enable = true;
    path = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager";
  };

  home =
    let NODE_GLOBAL = "${config.home.homeDirectory}/.node-packages";
    in
    {
      # This value determines the Home Manager release that your
      # configuration is compatible with. This helps avoid breakage
      # when a new Home Manager release introduces backwards
      # incompatible changes.
      #
      # You can update Home Manager without changing this value. See
      # the Home Manager release notes for a list of state version
      # changes in each release.
      stateVersion = "22.05";
      sessionVariables = {
        GPG_TTY = "/dev/ttys000";
        EDITOR = "nvim";
        VISUAL = "nvim";
        CLICOLOR = 1;
        LSCOLORS = "ExFxBxDxCxegedabagacad";
        KAGGLE_CONFIG_DIR = "${config.xdg.configHome}/kaggle";
        JAVA_HOME = "${pkgs.openjdk11.home}";
        NODE_PATH = "${NODE_GLOBAL}/lib";
        # HOMEBREW_NO_AUTO_UPDATE = 1;
      };
      sessionPath = [
        "${NODE_GLOBAL}/bin"
        "${config.home.homeDirectory}/.rd/bin"
      ];

      # define package definitions for current user environment
      packages = with pkgs; [
        age
        # python with default packages
        (pkgs.python3.withPackages
          (ps: with ps; [
            numpy
            scipy
            networkx
          ]))
        cachix
        comma
        curl
        fd
        ffmpeg
        gawk
        ghc
        git
        gnugrep
        gnupg
        gnused
        google-cloud-sdk
        helmfile
        htop
        httpie
        jq
        kubectl
        kubernetes-helm
        luajit
        mmv
        nix
        nixfmt
        nixpkgs-fmt
        nodejs_latest
        openjdk11
        openssh
        pandoc
        parallel
        pkgs.coreutils-full
        poetry
        pre-commit
        neofetch
        ranger
        rclone
        (pkgs.ruby.withPackages (ps: with ps; [ rufo solargraph ]))
        ripgrep
        rsync
        shellcheck
        stylua
        sysdo
        tealdeer
        terraform
        treefmt
        trivy
        vagrant
        yarn
        yq-go
      ];
    };

}
