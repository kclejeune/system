{
  inputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    inputs.nix-index-database.homeModules.nix-index
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
    packages = with pkgs;
      [
        age
        alejandra
        argocd
        asciidoctor
        basedpyright
        bfs
        btop
        cacert
        cachix
        cb
        cirrus-cli
        coreutils-full
        dust
        curl
        curlie
        d2
        diffutils
        dive
        dix
        dotenvx
        doxx
        fd
        ffmpeg
        findutils
        flamegraph
        flamelens
        flawz
        flyctl
        fx
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
        luajit
        mawk
        mise
        mmv
        mosh
        nil
        nix-inspect
        nix-output-monitor
        nix-tree
        nixd
        nixfmt-rfc-style
        nixpacks
        nmap
        nodejs_20
        openldap
        parallel
        pre-commit
        process-compose
        procps
        pv
        pyright
        ranger
        rclone
        restic
        rsync
        ruff
        rustscan
        sd
        shellcheck
        sig
        skopeo
        sshpass
        stylua
        sysdo
        tre
        tree
        trivy
        usage
        uv
        yadm
        yazi
        yq-go
        zoxide
        # python with default packages
        (python3.withPackages (
          ps:
            with ps; [
              httpx
              matplotlib
              networkx
              numpy
              polars
              scipy
            ]
        ))
      ]
      ++ lib.optionals config.nix.enable [config.nix.package]
      ++ lib.optionals pkgs.stdenvNoCC.isDarwin [iproute2mac]
      ++ lib.optionals pkgs.stdenvNoCC.isLinux [systemctl-tui lazyjournal];
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
    btop.enable = true;
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
    nix-index-database.comma.enable = true;
    pandoc.enable = true;
    ripgrep.enable = true;
    starship.enable = true;
    yt-dlp.enable = true;
  };
}
