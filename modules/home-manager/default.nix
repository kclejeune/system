{ self, inputs, config, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
in
{
  imports = [
    ./1password.nix
    ./bat.nix
    ./direnv.nix
    ./dotfiles
    ./fzf.nix
    ./git.nix
    ./kitty.nix
    ./nvim
    ./shell.nix
    ./ssh.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
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
        cachix
        comma
        coreutils-full
        curl
        fd
        ffmpeg
        gawk
        gnugrep
        gnupg
        gnused
        google-cloud-sdk
        helmfile
        httpie
        kubectl
        kubernetes-helm
        luajit
        mmv
        neofetch
        nix
        nixfmt
        nixpkgs-fmt
        nodejs_latest
        pandoc
        parallel
        poetry
        pre-commit
        # python with default packages
        (python3.withPackages
          (ps: with ps; [
            numpy
            scipy
            networkx
          ]))
        ranger
        rclone
        ripgrep
        rsync
        (ruby.withPackages (ps: with ps; [ rufo solargraph ]))
        shellcheck
        stylua
        sysdo
        tealdeer
        terraform
        tree
        treefmt
        trivy
        vagrant
        yarn
        yq-go
      ];
    };

  programs = {
    home-manager = {
      enable = true;
      path = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager";
    };
    dircolors.enable = true;
    go.enable = true;
    gpg.enable = true;
    htop.enable = true;
    java.enable = true;
    jq.enable = true;
    less.enable = true;
    man.enable = true;
    nix-index.enable = true;
    starship.enable = true;
    yt-dlp.enable = true;
    zathura.enable = true;
    zoxide.enable = true;
  };

}
