{
  description = "nix system configurations";

  nixConfig = {
    extra-substituters = [
      "https://cache.kclj.io/kclejeune"
      # "https://kclejeune.cachix.org"
      "https://install.determinate.systems"
      "https://noctalia.cachix.org"
    ];
    extra-trusted-public-keys = [
      "kclejeune:u0sa4anVXC4bKlzEsijdSlLyWVaEkApu6KWyDbbJMkk="
      # "kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    stable.url = "github:nixos/nixpkgs/nixos-26.05";
    unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixpkgs.follows = "unstable";

    # Nix binary cache CLI; the server side is the nimbus Cloudflare worker.
    nimbus.url = "github:kclejeune/nimbus";
    nimbus.inputs.nixpkgs.follows = "unstable";

    nh.url = "github:nix-community/nh";
    nh.inputs.nixpkgs.follows = "unstable";

    flake-compat.url = "github:nix-community/flake-compat";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.inputs.flake-compat.follows = "flake-compat";

    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Remote activation for the headless NixOS hosts (gateway + the homelab
    # nodes). Wired into flake.deploy.nodes below; `deploy` is in the devShell.
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    # UEFI Secure Boot via signed unified kernel images. Replaces
    # systemd-boot on hosts that enroll modules/nixos/secure-boot.nix.
    lanzaboote.url = "github:nix-community/lanzaboote/v1.1.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    # Noctalia Wayland desktop shell (bar, notifications, launcher, lock,
    # idle, OSD, wallpaper, night-light). Tracks nixos-unstable since it
    # depends on the latest Quickshell.
    #
    # Pinned to our fork's `kcl/restart-auth-support` branch for the
    # `lockScreen.restartAuth` IPC handler used by `lock-before-sleep`'s
    # ExecStop in modules/nixos/hyprland.nix — required so pam_fprintd's
    # stale Verify session (post-USB-resume) gets restarted and fingerprint
    # scanning works on the first try after suspend. Revert to upstream
    # once the change is merged.
    noctalia.url = "github:kclejeune/noctalia-shell/kcl/restart-auth-support";
    noctalia.inputs.nixpkgs.follows = "nixos-unstable";

    # Tinted-theming color scheme catalog (230+ schemes) and the
    # base16.nix YAML loader. Consumed by modules/shared/theme.nix
    # via `flake.lib.mkTheme`.
    base16.url = "github:SenchoPens/base16.nix";
    tinted-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} (
      {
        self,
        config,
        lib,
        ...
      }: {
        imports = [
          inputs.home-manager.flakeModules.home-manager
          inputs.treefmt-nix.flakeModule
          inputs.git-hooks.flakeModule
          (inputs.import-tree ./modules)
          # `cacheable` is the CI build set (host toplevels, HM activation
          # packages, devShells) transposed to `flake.cacheable.<system>` so
          # nix-fast-build can target it without dragging it into `checks`.
          (inputs.flake-parts.lib.mkTransposedPerSystemModule {
            name = "cacheable";
            option = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.package;
              default = {};
            };
            file = ./flake.nix;
          })
          # flake-parts doesn't declare flake.darwinModules upstream; declare
          # it here so files under modules/darwin/ can each contribute a
          # named entry that merges into the attrset. Same for flake.lib, which
          # multiple shared modules contribute helpers to (mkTheme, mkAspect).
          {
            options.flake.darwinModules = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.unspecified;
              default = {};
            };
            options.flake.lib = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.unspecified;
              default = {};
            };
          }
        ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ];

        flake.nixosConfigurations.phil = inputs.nixos-unstable.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit self inputs;
            nixpkgs = inputs.nixos-unstable;
          };
          modules = [
            config.flake.nixosModules.host-baseline
            config.flake.nixosModules.default

            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
            config.flake.nixosModules.hardware-thinkpad-t460s

            config.flake.nixosModules.desktop
            config.flake.nixosModules.personal-apps
            config.flake.nixosModules.profile-personal

            config.flake.nixosModules.tailscale
            config.flake.nixosModules.netbird

            {
              networking.hostName = "phil";
              # Host-level: pin phil's Hyprland panel/kanshi overlay. The
              # hardware module stays generic so any T460s could reuse it.
              hm.imports = [config.flake.homeModules.hyprland-host-phil];
            }
          ];
        };

        flake.nixosConfigurations.wally = inputs.nixos-unstable.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit self inputs;
            nixpkgs = inputs.nixos-unstable;
          };
          modules = [
            config.flake.nixosModules.host-baseline
            config.flake.nixosModules.default

            inputs.nixos-hardware.nixosModules.dell-precision-5570
            config.flake.nixosModules.hardware-precision-5570

            config.flake.nixosModules.desktop
            config.flake.nixosModules.personal-apps
            config.flake.nixosModules.profile-personal

            # disable pending disko partition update
            # config.flake.nixosModules.secure-boot

            config.flake.nixosModules.tailscale
            config.flake.nixosModules.netbird

            {
              networking.hostName = "wally";
              # Host-level: pin the precision-5570 + home Dell U2718Q panel
              # / kanshi / workspace overlay. Hardware module stays generic.
              hm.imports = [config.flake.homeModules.displays-5570-home];
            }
          ];
        };

        flake.nixosConfigurations.gateway = inputs.nixos-unstable.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit self inputs;
            nixpkgs = inputs.nixos-unstable;
          };
          modules = [
            config.flake.nixosModules.host-baseline
            config.flake.nixosModules.default

            config.flake.nixosModules.hetzner

            config.flake.nixosModules.gateway
            config.flake.nixosModules.profile-personal

            config.flake.nixosModules.nix-ld

            config.flake.nixosModules.tailscale
            config.flake.nixosModules.netbird
            config.flake.nixosModules.subnet-router
            config.flake.nixosModules.tailscale-server
            config.flake.nixosModules.beszel-agent
          ];
        };

        # Homelab home-automation node — bare-metal Lenovo P3 Tiny replacing
        # the Proxmox cluster. Runs homebridge + uptime-kuma natively and
        # Home Assistant OS as an Incus VM. First of four planned nodes
        # (haven / forge / vault / atlas).
        flake.nixosConfigurations.haven = inputs.nixos-unstable.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit self inputs;
            nixpkgs = inputs.nixos-unstable;
          };
          modules = [
            config.flake.nixosModules.host-baseline
            config.flake.nixosModules.default

            config.flake.nixosModules.homelab-node

            config.flake.nixosModules.haven
          ];
        };

        # forge — general / dev-utilities node (P3 Tiny).
        flake.nixosConfigurations.forge = inputs.nixos-unstable.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit self inputs;
            nixpkgs = inputs.nixos-unstable;
          };
          modules = [
            config.flake.nixosModules.host-baseline
            config.flake.nixosModules.default

            config.flake.nixosModules.homelab-node

            config.flake.nixosModules.forge
            config.flake.nixosModules.avahi
            config.flake.nixosModules.airprint
            config.flake.nixosModules.backup
          ];
        };

        # vault — data / storage node (P3 Tiny). Scaffolding only this round.
        flake.nixosConfigurations.vault = inputs.nixos-unstable.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit self inputs;
            nixpkgs = inputs.nixos-unstable;
          };
          modules = [
            config.flake.nixosModules.host-baseline
            config.flake.nixosModules.default

            config.flake.nixosModules.homelab-node

            config.flake.nixosModules.vault
            # backup needs real restic/* in secrets/vault.yaml; enable once set.
            # config.flake.nixosModules.backup
          ];
        };

        # atlas — infra / backup node (P3 Tiny). Scaffolding only this round.
        flake.nixosConfigurations.atlas = inputs.nixos-unstable.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit self inputs;
            nixpkgs = inputs.nixos-unstable;
          };
          modules = [
            config.flake.nixosModules.host-baseline
            config.flake.nixosModules.default

            config.flake.nixosModules.homelab-node

            config.flake.nixosModules.atlas
            # backup needs real restic/* in secrets/atlas.yaml; enable once set.
            # config.flake.nixosModules.backup
          ];
        };

        # deploy-rs targets — the headless hosts only (phil/wally are laptops,
        # rebuilt locally). Root SSH is disabled on these, so log in as the
        # kclejeune user and let deploy-rs activate as root via passwordless
        # sudo. All five are x86_64-linux. Deploy with `deploy '.#<host>'`, or
        # `deploy '.#haven' --hostname <ip>` to override the address.
        flake.deploy.nodes = let
          # hostname == attr name; bare names resolve via tailscale MagicDNS /
          # the LAN search domain. Override per deploy with `--hostname`.
          mkNode = subdomain: host: {
            hostname = "${host}.${subdomain}";
            sshUser = "kclejeune";
            user = "root";
            sshOpts = [
              "-o"
              "StrictHostKeyChecking=accept-new"
            ];
            profiles.system.path =
              inputs.deploy-rs.lib.x86_64-linux.activate.nixos
              config.flake.nixosConfigurations.${host};
          };
        in
          lib.genAttrs [
            "gateway"
            "haven"
            "forge"
            "vault"
            "atlas"
          ] (mkNode "tailf0779.ts.net");

        flake.darwinConfigurations = lib.mergeAttrsList (
          lib.map (system: {
            "kclejeune@${system}" = inputs.darwin.lib.darwinSystem {
              inherit system;
              specialArgs = {
                inherit self inputs;
                nixpkgs = inputs.nixpkgs;
              };
              modules = [
                inputs.determinate.darwinModules.default
                inputs.home-manager.darwinModules.home-manager

                config.flake.darwinModules.default

                config.flake.darwinModules.profile-personal
                config.flake.darwinModules.apps
              ];
            };
          }) ["aarch64-darwin"]
        );

        flake.homeConfigurations = lib.mergeAttrsList (
          lib.map
          (
            system: let
              isDarwin = lib.hasSuffix "darwin" system;
              username = "kclejeune";
              homeDirectory = "${
                if isDarwin
                then "/Users"
                else "/home"
              }/${username}";
            in {
              "kclejeune@${system}" = inputs.home-manager.lib.homeManagerConfiguration {
                pkgs = import inputs.nixpkgs {
                  inherit system;
                  config = {
                    allowUnsupportedSystem = true;
                    allowUnfree = true;
                    allowBroken = false;
                  };
                  overlays = [self.overlays.default];
                };
                extraSpecialArgs = {
                  inherit self inputs;
                  nixpkgs = inputs.nixpkgs;
                };
                modules = [
                  config.flake.homeModules.default
                  config.flake.homeModules.profile-personal
                  (
                    {pkgs, ...}: {
                      nix.package = pkgs.nix;
                      home = {inherit username homeDirectory;};
                    }
                  )
                ];
              };
            }
          )
          [
            "x86_64-linux"
            "aarch64-linux"
            "aarch64-darwin"
          ]
        );

        # Self-contained: custom packages resolve through the overlay's own
        # `final` fixpoint. Referencing self.packages here instead would loop
        # through perSystem's pkgs (which applies this overlay) and recurse.
        flake.overlays = {
          default = final: prev: {
            determinate-nixd = inputs.determinate.packages.${prev.system}.default;
            nix = inputs.determinate.inputs.nix.packages.${prev.system}.default;
            stable = inputs.stable.legacyPackages.${prev.system};

            cb = final.callPackage ./pkgs/cb/package.nix {};
            fnox = final.callPackage ./pkgs/fnox/package.nix {};
            sem-cli = final.callPackage ./pkgs/sem-cli/package.nix {};
            weave = final.callPackage ./pkgs/weave/package.nix {};
            nimbus = inputs.nimbus.packages.${prev.system}.nimbus;
          };
        };

        perSystem = {
          config,
          pkgs,
          system,
          self',
          ...
        }: let
          filterSystem = lib.filterAttrs (_: drv: drv.pkgs.stdenv.hostPlatform.system == system);
        in {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.deploy-rs.overlays.default
              self.overlays.default
            ];
          };

          packages = {
            inherit
              (pkgs)
              cb
              fnox
              sem-cli
              weave
              nimbus
              ;
          };

          legacyPackages = pkgs;

          devShells.default = pkgs.mkShell {
            packages =
              (builtins.attrValues {
                inherit
                  (pkgs)
                  bashInteractive
                  fd
                  ripgrep
                  uv
                  nh
                  nix-fast-build
                  nimbus
                  ;
                inherit (pkgs.deploy-rs) deploy-rs;
              })
              ++ config.pre-commit.settings.enabledPackages
              ++ (lib.attrValues config.treefmt.build.programs)
              ++ (lib.attrValues config.packages);
            shellHook = config.pre-commit.installationScript;
          };

          # `nix run .#deploy` with no args deploys every node; pass targets
          # to scope it, e.g. `nix run .#deploy -- '.#forge'`.
          apps.deploy = {
            type = "app";
            program = lib.getExe (
              pkgs.writeShellApplication {
                name = "deploy";
                runtimeInputs = [pkgs.deploy-rs.deploy-rs];
                text = ''
                  # deploy-rs's built-in pre-check runs a full `nix flake check`
                  # over the ENTIRE flake (every system + host) on each deploy
                  # — slow, unscoped, and it hides deploy progress until it
                  # finishes. Skip it here (deploy-rs still builds each node's
                  # profile, so what's deployed is validated); run `nix flake
                  # check`, or plain `deploy` from `nix develop`, for the full
                  # gate.
                  # Default to all nodes in this flake when no target is given.
                  if [ "$#" -eq 0 ]; then set -- "."; fi
                  exec deploy --skip-checks "$@"
                '';
              }
            );
          };

          treefmt = {
            programs = {
              deadnix = {
                enable = true;
                no-lambda-arg = true;
                no-lambda-pattern-names = true;
              };
              nixfmt.enable = true;
              oxfmt.enable = true;
              ruff-check.enable = true;
              ruff-format.enable = true;
              shellcheck.enable = true;
              shfmt.enable = true;
              stylua.enable = true;
            };

            settings.excludes = [
              ".envrc"
              ".env"
              ".vscode/*.json"
              "**/Spoons/**/*.json"
              "**/zed/**/*.json"
            ];
            settings.on-unmatched = "info";
            settings.formatter.ruff-check.options = [
              # sort imports
              "--extend-select"
              "I"
            ];
          };

          pre-commit = {
            settings.package = pkgs.prek;
            settings.hooks.treefmt = {
              enable = true;
              pass_filenames = false;
              settings.no-cache = false;
            };
          };

          cacheable =
            (lib.mapAttrs' (name: cfg: lib.nameValuePair "${name}_home" cfg.activationPackage) (
              filterSystem self.homeConfigurations
            ))
            // (lib.mapAttrs (_: cfg: cfg.config.system.build.toplevel) (
              filterSystem (self.darwinConfigurations // self.nixosConfigurations)
            ))
            // self'.devShells;
          # deploy-rs schema + activation checks; only wired on x86_64-linux
          # since every deploy node is x86_64-linux and the activation check
          # depends on building their toplevels.
          checks = lib.optionalAttrs (system == "x86_64-linux") (pkgs.deploy-rs.lib.deployChecks self.deploy);
        };
      }
    );
}
