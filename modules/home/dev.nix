_: {
  # Always-available developer toolkit. Lives in every home-manager
  # generation, including headless hosts (gateway) — so SSH sessions
  # have the everyday CLI surface (editors / search / VCS / k8s ops /
  # network probing / nix tooling) plus compilers, language servers,
  # build/profiling tooling, media, and big Python deps.
  flake.homeModules.dev =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home.packages =
        with pkgs;
        [
          age
          alejandra
          asciidoctor
          ast-grep
          basedpyright
          beads
          bento
          bfs
          cacert
          cachix
          cb
          cirrus-cli
          clang
          clang-tools
          claude-code
          cmake
          codespell
          codex
          coreutils-full
          curl
          curlie
          d2
          deadnix
          diffutils
          dive
          dnsutils
          doxx
          dust
          fd
          ffmpeg
          findutils
          flamegraph
          flamelens
          flawz
          flyctl
          fnox
          fx
          gawk
          gdu
          dix
          git-absorb
          gnugrep
          gnupg
          gnused
          golangci-lint
          goreleaser
          (lib.hiPrio gotools)
          go-task
          grype
          helm-docs
          httpie
          hyperfine
          iperf
          jetbrains-mono
          jnv
          kotlin
          krew
          kubectl
          kubectx
          kubernetes-helm
          kustomize
          lazydocker
          lazyworktree
          lfk
          luajit
          mawk
          mise
          mmv
          mosh
          nil
          nimbus
          nix-inspect
          nix-output-monitor
          nix-tree
          nixd
          nixfmt
          nixfmt-tree
          nixpacks
          nmap
          nodejs_22
          nurl
          openldap
          openssl
          ouch
          oxfmt
          oxlint
          parallel
          prek
          prettier
          process-compose
          procps
          pv
          pyright
          rclone
          restic
          rsync
          ruff
          rustscan
          rustup
          sd
          shellcheck
          sig
          skopeo
          sops
          src-cli
          ssh-to-age
          sshpass
          stylua
          tree
          trivy
          usage
          uv
          worktrunk
          yadm
          yq-go
          zoxide
          (python3.withPackages (
            ps: with ps; [
              httpx
              matplotlib
              networkx
              numpy
              polars
              scipy
            ]
          ))
        ]
        ++ lib.optionals (config.nix.package != null) [ config.nix.package ]
        ++ lib.optionals pkgs.stdenvNoCC.isDarwin [ iproute2mac ]
        ++ lib.optionals pkgs.stdenvNoCC.isLinux [
          systemctl-tui
          lazyjournal
        ];
    };
}
