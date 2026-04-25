_: {
  # Always-available developer toolkit. Lives in every home-manager
  # generation, including headless hosts (gateway) — so SSH sessions
  # have the everyday CLI surface (editors / search / VCS / k8s ops /
  # network probing / nix tooling) without dragging in heavy compilers,
  # language servers, or media tooling.
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
          bfs
          cacert
          cachix
          cb
          codespell
          coreutils-full
          curl
          curlie
          d2
          diffutils
          doxx
          dust
          fd
          findutils
          fnox
          fx
          gawk
          gdu
          git-absorb
          gnugrep
          gnupg
          gnused
          helm-docs
          httpie
          hyperfine
          iperf
          jnv
          krew
          kubectl
          kubectx
          kubernetes-helm
          kustomize
          lazydocker
          lazyworktree
          mawk
          mise
          mmv
          mosh
          nil
          nix-inspect
          nix-output-monitor
          nix-tree
          nixd
          nixfmt
          nixfmt-tree
          nmap
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
          rclone
          restic
          rsync
          ruff
          rustscan
          sd
          shellcheck
          sig
          skopeo
          sops
          ssh-to-age
          sshpass
          stylua
          tree
          usage
          worktrunk
          yadm
          yq-go
          zoxide
        ]
        ++ lib.optionals (config.nix.package != null) [ config.nix.package ]
        ++ lib.optionals pkgs.stdenvNoCC.isDarwin [ iproute2mac ]
        ++ lib.optionals pkgs.stdenvNoCC.isLinux [
          systemctl-tui
          lazyjournal
        ];
    };
}
