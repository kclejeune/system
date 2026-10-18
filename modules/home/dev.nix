{ config, inputs, ... }:
let
  sparklesServer = "https://sparkles.${config.flake.lib.site.lanDomain}";
in
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
      imports = [ inputs.sparkles.homeModules.default ];

      home.packages =
        with pkgs;
        [
          age
          asciidoctor
          ast-grep
          aube
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
          dix
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
          mise
          mmv
          mosh
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
          traceway-cli
          tree
          trivy
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
          systemctl-tui
          lazyjournal
        ]
        # GUI apps: nothing to run them on a headless host.
        ++ lib.optionals config.desktop.enable [ gitbutler ]
        ++ lib.optionals (config.desktop.enable && pkgs.stdenv.hostPlatform.isLinux) [
          chatgpt
          chromium
          playwright-test
        ];

      # The CLI, with `sparkles memory` pointed at the shared memory dataset created
      # through the Sparkles UI. Credentials stay in the CLI's separate auth-login store.
      programs.sparkles = {
        enable = true;
        server = sparklesServer;
        memory.dataset = "slurp";
      };

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
