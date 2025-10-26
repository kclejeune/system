{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./bat.nix
    ./direnv.nix
    ./dotfiles
    ./fzf.nix
    ./git.nix
    ./nushell.nix
    ./nvim
    ./shell.nix
    ./ssh.nix
    ./tldr.nix
    ./tmux.nix
    ./gnome.nix
    ./nixpkgs.nix
  ];

  home = {
    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "25.05";

    # define package definitions for current user environment
    packages = with pkgs; ([
        # age
        alejandra
        argocd
        asciidoctor
        basedpyright
        cacert
        cachix
        cb
        cirrus-cli
        (comma.override (_: {nix = config.nix.package;}))
        coreutils-full
        curl
        d2
        diffutils
        dive
        dix
        dotenvx
        fd
        ffmpeg
        findutils
        flyctl
        gawk
        gdu
        git-absorb
        gnugrep
        gnupg
        gnused
        go-task
        grype
        helm-docs
        httpie
        hyperfine
        iperf
        jetbrains-mono
        jnv
        kotlin
        kubectl
        kubectx
        kubernetes-helm
        kustomize
        lazydocker
        lima
        luajit
        mise
        mmv
        mosh
        nil
        nix-output-monitor
        nixd
        nixfmt-rfc-style
        nixpacks
        nmap
        nodejs_20
        openldap
        parallel
        pre-commit
        procps
        pyright
        # python with default packages
        (python3.withPackages (
          ps:
            with ps; [
              duckdb
              httpx
              matplotlib
              networkx
              numpy
              polars
              scipy
            ]
        ))
        ranger
        rclone
        restic
        rsync
        ruff
        shellcheck
        skopeo
        sshpass
        stylua
        sysdo
        tree
        trivy
        usage
        uv
        yadm
        yq-go
        zoxide
      ]
      ++ lib.optionals config.nix.enable [config.nix.package]
      ++ lib.optionals pkgs.stdenvNoCC.isDarwin [iproute2mac]);
  };

  fonts.fontconfig = {
    enable = true;
  };

  programs = {
    home-manager = {
      enable = true;
    };
    difftastic.enable = true;
    difftastic.git.enable = true;
    dircolors.enable = true;
    eza = {
      enable = true;
      extraOptions = [
        "--group-directories-first"
        "--git"
      ];
    };
    fastfetch.enable = true;
    go.enable = true;
    gpg.enable = true;
    htop.enable = true;
    jq.enable = true;
    k9s.enable = true;
    lazygit = {
      enable = true;
      settings = {
        git.useExternalDiffGitConfig = true;
        git.overrideGpg = true;
      };
    };
    lazysql.enable = true;
    less.enable = true;
    man.enable = true;
    nix-your-shell = {
      enable = true;
      nix-output-monitor.enable = true;
    };
    nh = {
      enable = true;
      flake = "${config.home.homeDirectory}/.nixpkgs";
    };
    nix-index.enable = true;
    pandoc.enable = true;
    ripgrep.enable = true;
    starship.enable = true;
    yt-dlp.enable = true;
  };
}
