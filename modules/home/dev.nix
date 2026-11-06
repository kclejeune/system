{ inputs, ... }:
{
  # Deliberately on every host, headless ones included, so SSH sessions have the
  # full toolkit.
  flake.homeModules.dev =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        inputs.sparkles.homeModules.default
        inputs.hex-dictation.homeManagerModules.default
      ];

      # Upstream's Nix module currently supports x86-64 Linux.
      programs.hex = {
        enable = config.desktop.enable && pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        package = pkgs.hex-dictation;
      };

      # Multiple PipeWire contexts in Hex can reduce RLIMIT_RTTIME to zero;
      # a subsequent realtime audio thread then kills the entire process.
      # Disable client realtime scheduling for Hex while retaining audio I/O.
      systemd.user.services.hex.Service.Environment = lib.mkIf config.programs.hex.enable [
        "PIPEWIRE_CONFIG_DIR=${
          pkgs.runCommand "hex-pipewire-config" { } ''
            mkdir -p "$out"
            cp ${pkgs.pipewire}/share/pipewire/client.conf "$out/client.conf"
            substituteInPlace "$out/client.conf" \
              --replace-fail 'module.rt = !false' 'module.rt = true'
          ''
        }"
      ];

      home.packages =
        with pkgs;
        [
          age
          asciidoctor
          ast-grep
          aube
          awscli2
          # azure-cli
          basedpyright
          beads
          bento
          bfs
          buf
          buffrs
          cacert
          cachix
          cargo-binstall
          cb
          ccusage
          circleci-cli
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
          dix
          dnsutils
          doxx
          dust
          eksctl
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
          git-absorb
          gnugrep
          gnupg
          gnused
          go-task
          gofumpt
          golangci-lint
          gomplate
          google-cloud-sdk
          goreleaser
          (lib.hiPrio gotools)
          grype
          helm-docs
          httpie
          hyperfine
          iperf
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
          mermaid-rs-renderer
          mise
          mmv
          mosh
          mvs
          namespace-cli
          nil
          nimbus
          nix-inspect
          nix-output-monitor
          nix-tree
          nix-update
          nixd
          nixfmt
          nixfmt-tree
          nixpacks
          nmap
          nodejs_22
          nurl
          opencode
          openldap
          openssl
          opentofu
          ouch
          oxfmt
          oxlint
          parallel
          pkl
          prek
          prettier
          process-compose
          procps
          protobuf
          pv
          pyinfra
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
          smolvm
          sops
          src-cli
          ssh-to-age
          sshpass
          stylua
          taplo
          terraform
          traceway-cli
          tree
          trivy
          ty
          usage
          uv
          worktrunk
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
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ iproute2mac ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          # On macOS this wrapper shadows /usr/bin/cc, and outside a Nix dev
          # shell its SDK lacks libiconv, so every Rust link fails with
          # `library not found for -liconv`. Use the Xcode toolchain there.
          clang
          systemctl-tui
          lazyjournal
        ]
        # GUI apps: nothing to run them on a headless host.
        ++ lib.optionals config.desktop.enable [
          llm-agents.gitbutler
        ]
        ++ lib.optionals (config.desktop.enable && pkgs.stdenv.hostPlatform.isLinux) [
          chromium
          playwright-test
        ];

      # Plain `cargo` goes through mbx; rustup still selects the toolchain.
      programs.mr-boxington = {
        enable = true;
        rustAnalyzer = true;
        settings.http.timeout = "1m";
        # Share one storage budget across worktrees on each host. Hosts with smaller
        # disks lower it, since a build's live target is not collected while it runs.
        settings.gc = {
          max_total_size = lib.mkDefault "200GiB";
          min_free_size = lib.mkDefault "50GiB";
        };
      };

      # The CLI. profile-personal points it at the home server and its memory dataset,
      # so a work machine that skips that profile gets no personal endpoint.
      programs.sparkles.enable = true;

      # mise defaults all_compile=true when it detects NixOS (/etc/NIXOS), assuming
      # prebuilt binaries won't run, and then compiles tools like node from source.
      # Every NixOS host enrolls nix-ld, so the prebuilt binaries work. A conf.d file
      # leaves config.toml writable for `mise use -g` and `mise settings`.
      xdg.configFile."mise/conf.d/00-nix.toml".text = ''
        [settings]
        all_compile = false
      '';

      # Playwright's downloaded browsers don't run on NixOS. This pins them to
      # the nixpkgs revision, so only a matching Playwright version finds them;
      # the `chrome` channel is covered by desktop-base's /opt/google symlink.
      home.sessionVariables = lib.mkIf (config.desktop.enable && pkgs.stdenv.hostPlatform.isLinux) {
        PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      };
    };
}
