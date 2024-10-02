{
  config,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
in {
  imports = [
    ./bat.nix
    ./direnv.nix
    ./dotfiles
    ./fzf.nix
    ./git.nix
    ./kitty.nix
    ./nushell.nix
    ./nvim
    ./shell.nix
    ./ssh.nix
    ./tldr.nix
    ./tmux.nix
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  home = let
    nodePath = "${homeDir}/.node";
  in {
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
      NODE_PATH = nodePath;
    };
    sessionPath = [
      # "${homeDir}/.local/bin"
      "${homeDir}/.rye/shims"
      "${homeDir}/.rd/bin"
      "${homeDir}/.docker/bin"
      "${nodePath}/bin"
    ];

    # define package definitions for current user environment
    packages = with pkgs; [
      # age
      asciidoctor
      alejandra
      cachix
      cb
      cirrus-cli
      comma
      coreutils-full
      curl
      d2
      diffutils
      dive
      dotenvx
      duckdb
      fd
      ffmpeg
      findutils
      gawk
      gdu
      git-absorb
      gnugrep
      gnupg
      gnused
      grype
      helm-docs
      httpie
      hurl
      hyperfine
      kotlin
      kubectl
      kubectx
      kubernetes-helm
      kustomize
      lazydocker
      luajit
      mise
      mmv
      neofetch
      nix
      nixd
      nixfmt-rfc-style
      nixpacks
      nmap
      nodejs_20
      parallel
      poetry
      pre-commit
      # python with default packages
      (python3.withPackages
        (ps:
          with ps; [
            duckdb
            httpx
            matplotlib
            networkx
            numpy
            polars
            scipy
          ]))
      ranger
      rclone
      restic
      ruff
      rsync
      shellcheck
      stylua
      sysdo
      tree
      trivy
      yq-go
    ];
  };

  programs = {
    home-manager = {
      enable = true;
    };
    dircolors.enable = true;
    go.enable = true;
    gpg.enable = true;
    htop.enable = true;
    jq.enable = true;
    java = {
      enable = true;
      package = pkgs.jdk21;
    };
    k9s.enable = true;
    lazygit.enable = true;
    less.enable = true;
    man.enable = true;
    nix-index.enable = true;
    pandoc.enable = true;
    ripgrep.enable = true;
    starship.enable = true;
    yt-dlp.enable = true;
    zoxide = {
      enable = true;
      options = [
        "--hook pwd"
      ];
    };
  };
}
