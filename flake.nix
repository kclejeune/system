{
  description = "nix system configurations";

  nixConfig = {
    extra-substituters = [
      "https://cache.kclj.io"
    ];
    extra-trusted-public-keys = [
      "cache.kclj.io-1:StGAmbogIZLS5IAQD2IQCbbmIjv3Sq8rl/AVEw4Sy7s="
      "kclejeune:u0sa4anVXC4bKlzEsijdSlLyWVaEkApu6KWyDbbJMkk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixos-unstable";

    # Only here as a `follows` target so transitive `systems` inputs dedupe.
    systems.url = "github:nix-systems/default";

    # Every nixpkgs revision, lazily: `pkgs.multiverse.tip.<pkg>`, `.at "26.05"`, `.version "<pkg>" "<ver>"`.
    multiverse.url = "github:fzakaria/nixpkgs-multiverse";

    nimbus.url = "github:kclejeune/nimbus";
    nimbus.inputs.nixpkgs.follows = "nixpkgs";

    # Fork: fixes --target-host ssh-ng MaxSessions flooding.
    nh.url = "github:kclejeune/nh/fix/remote-diff-ssh-ng-protocol-mismatch";
    nh.inputs.nixpkgs.follows = "nixpkgs";

    # Only a `follows` target for inputs that still declare it.
    flake-compat.url = "github:nix-community/flake-compat";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    terranix.url = "github:terranix/terranix";
    terranix.inputs.nixpkgs.follows = "nixpkgs";
    terranix.inputs.systems.follows = "systems";
    terranix.inputs.flake-parts.follows = "flake-parts";
    terranix.inputs.import-tree.follows = "import-tree";

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

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.flake-compat.follows = "flake-compat";
    deploy-rs.inputs.utils.inputs.systems.follows = "systems";

    # `follows` is lockfile hygiene only; modules/nixos/comin.nix builds comin from the host's nixpkgs.
    comin.url = "github:nlewo/comin";
    comin.inputs.nixpkgs.follows = "nixpkgs";
    comin.inputs.treefmt-nix.follows = "treefmt-nix";
    comin.inputs.flake-compat.follows = "flake-compat";

    lanzaboote.url = "github:nix-community/lanzaboote/v1.1.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.inputs.pre-commit.follows = "git-hooks";

    # Fork for the `lockScreen.restartAuth` IPC used by hyprland.nix's
    # lock-before-sleep (fingerprint after resume). Revert once merged upstream.
    noctalia.url = "github:kclejeune/noctalia-shell/kcl/restart-auth-support";
    noctalia.inputs.nixpkgs.follows = "nixos-unstable";
    noctalia.inputs.noctalia-qs.inputs.treefmt-nix.follows = "treefmt-nix";

    base16.url = "github:SenchoPens/base16.nix";
    tinted-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      {
        self,
        config,
        lib,
        ...
      }:
      let
        # Every NixOS host: same nixpkgs, specialArgs, and baseline modules.
        mkNixos =
          modules:
          inputs.nixos-unstable.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {
              inherit self inputs;
              nixpkgs = inputs.nixos-unstable;
            };
            modules = [
              config.flake.nixosModules.host-baseline
              config.flake.nixosModules.default
            ]
            ++ modules;
          };

        # Personal laptops. `extra` lands between the desktop stack and the
        # overlay networks so module order (and thus drvPaths) stays stable.
        mkDesktop =
          {
            hardware,
            host,
            extra ? [ ],
          }:
          mkNixos (
            hardware
            ++ [
              config.flake.nixosModules.desktop
              config.flake.nixosModules.personal-apps
              config.flake.nixosModules.profile-personal
            ]
            ++ extra
            ++ [
              config.flake.nixosModules.tailscale
              config.flake.nixosModules.netbird
              host
            ]
          );

        # LAN homelab boxes; homelab-node pulls in the p3-tiny hardware + server stack.
        mkHomelab = modules: mkNixos ([ config.flake.nixosModules.homelab-node ] ++ modules);

        inherit (import ./modules/_lib.nix) mkNixpkgsArgs;
      in
      {
        imports = [
          inputs.home-manager.flakeModules.home-manager
          inputs.treefmt-nix.flakeModule
          inputs.git-hooks.flakeModule
          inputs.terranix.flakeModule
          (inputs.import-tree ./modules)
          # CI build set, kept out of `checks` so nix-fast-build can target it alone.
          (inputs.flake-parts.lib.mkTransposedPerSystemModule {
            name = "cacheable";
            option = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.package;
              default = { };
            };
            file = ./flake.nix;
          })
          # flake-parts doesn't declare these; without it modules/darwin/ entries collide.
          {
            options.flake.darwinModules = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.unspecified;
              default = { };
            };
            options.flake.lib = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.unspecified;
              default = { };
            };
          }
        ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        flake.nixosConfigurations = {
          phil = mkDesktop {
            hardware = [
              inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
              config.flake.nixosModules.hardware-thinkpad-t460s
            ];
            host = {
              networking.hostName = "phil";
              hm.imports = [ config.flake.homeModules.hyprland-host-phil ];
            };
          };

          wally = mkDesktop {
            hardware = [
              inputs.nixos-hardware.nixosModules.dell-precision-5570
              config.flake.nixosModules.hardware-precision-5570
            ];
            extra = [
              config.flake.nixosModules.secure-boot
              config.flake.nixosModules.tpm-unlock
            ];
            host = {
              networking.hostName = "wally";
              hm.imports = [ config.flake.homeModules.displays-5570-home ];
            };
          };

          stanley = mkDesktop {
            hardware = [
              inputs.nixos-hardware.nixosModules.framework-intel-core-ultra-series3
              config.flake.nixosModules.hardware-framework-13-pro
            ];
            extra = [
              config.flake.nixosModules.secure-boot
              config.flake.nixosModules.tpm-unlock
            ];
            host = {
              networking.hostName = "stanley";
              # cage starts at 1x; match the session's eDP-1 scale.
              services.greeter.outputScales.eDP-1 = 2;
              hm.imports = [ config.flake.homeModules.displays-framework-13-home ];
            };
          };

          # gateway doesn't use homelab-node.
          gateway = mkNixos [
            config.flake.nixosModules.hetzner

            config.flake.nixosModules.gateway
            config.flake.nixosModules.profile-personal

            config.flake.nixosModules.nix-ld

            config.flake.nixosModules.tailscale
            config.flake.nixosModules.netbird
            config.flake.nixosModules.subnet-router
            config.flake.nixosModules.tailscale-server
            config.flake.nixosModules.beszel-agent

            config.flake.nixosModules.comin
          ];

          # haven: home automation (homebridge, uptime-kuma, HAOS in Incus).
          haven = mkHomelab [ config.flake.nixosModules.haven ];

          # forge: general / dev utilities.
          forge = mkHomelab [
            config.flake.nixosModules.forge
            config.flake.nixosModules.avahi
            config.flake.nixosModules.airprint
            config.flake.nixosModules.backup
          ];

          # vault: data / storage.
          vault = mkHomelab [
            config.flake.nixosModules.vault
            config.flake.nixosModules.rustfs
            # backup needs real restic/* in secrets/vault.yaml; enable once set.
            # config.flake.nixosModules.backup
          ];

          # atlas: infra / backup.
          atlas = mkHomelab [
            config.flake.nixosModules.atlas
            # backup needs real restic/* in secrets/atlas.yaml; enable once set.
            # config.flake.nixosModules.backup
          ];
        };

        # Headless hosts only; root SSH is off, so deploy as the user with sudo.
        flake.deploy.nodes =
          let
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
          ] (mkNode config.flake.lib.site.tailnetDomain);

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
          }) [ "aarch64-darwin" ]
        );

        flake.homeConfigurations = lib.mergeAttrsList (
          lib.map
            (
              system:
              let
                isDarwin = lib.hasSuffix "darwin" system;
                username = "kclejeune";
                homeDirectory = "${if isDarwin then "/Users" else "/home"}/${username}";
              in
              {
                "kclejeune@${system}" = inputs.home-manager.lib.homeManagerConfiguration {
                  pkgs = import inputs.nixpkgs ({ inherit system; } // mkNixpkgsArgs { inherit self; });
                  extraSpecialArgs = {
                    inherit self inputs;
                    nixpkgs = inputs.nixpkgs;
                  };
                  modules = [
                    config.flake.homeModules.default
                    config.flake.homeModules.profile-personal
                    ({ pkgs, ... }: {
                      nix.package = pkgs.nix;
                      home = { inherit username homeDirectory; };
                    })
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

        # Resolve through `final`: self.packages would recurse via perSystem's pkgs.
        flake.overlays = {
          default = final: prev: {
            determinate-nixd = inputs.determinate.packages.${prev.stdenv.hostPlatform.system}.default;
            nix = inputs.determinate.inputs.nix.packages.${prev.stdenv.hostPlatform.system}.default;
            multiverse = inputs.multiverse.lib.mkMultiverse {
              system = prev.stdenv.hostPlatform.system;
              config = {
                inherit (prev.config) allowUnfree allowBroken allowUnsupportedSystem;
              };
            };

            cb = final.callPackage ./pkgs/cb/package.nix { };
            sem-cli = final.callPackage ./pkgs/sem-cli/package.nix { };
            tpm-keyring-unlock = final.callPackage ./pkgs/tpm-keyring-unlock/package.nix { };
            traceway = final.callPackage ./pkgs/traceway/package.nix { };
            traceway-cli = final.traceway.cli;
            nimbus = inputs.nimbus.packages.${prev.stdenv.hostPlatform.system}.nimbus;
            nh = inputs.nh.packages.${prev.stdenv.hostPlatform.system}.default;

            # tmux 3.7c needs jemalloc chosen explicitly on Darwin; drop once nixpkgs has the fix.
            tmux = prev.tmux.overrideAttrs (old: {
              buildInputs =
                (old.buildInputs or [ ])
                ++ final.lib.optionals final.stdenv.hostPlatform.isDarwin [ final.jemalloc ];
              configureFlags =
                (old.configureFlags or [ ])
                ++ final.lib.optionals final.stdenv.hostPlatform.isDarwin [ "--enable-jemalloc" ];
            });

            # Tests read the host process table, hidden by the sandbox. Drop once upstream gates them.
            worktrunk = prev.worktrunk.overrideAttrs (old: {
              checkFlags = (old.checkFlags or [ ]) ++ [
                "--skip=shell::utils::tests::test_process_name_and_ppid_self"
                "--skip=shell::utils::tests::test_probe_reports_invoked_name_for_sh"
              ];
            });

            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              # Upstream re-tagged v0.16.0; drop once nixos-unstable passes nixpkgs 1e544d5.
              (_: pyprev: {
                nanoemoji = pyprev.nanoemoji.overrideAttrs (old: {
                  src = old.src.overrideAttrs (_: {
                    outputHash = "sha256-FysyKC01XBnRiur5RR9fcsTxQqE8x0JJHSoe3q6JtKc=";
                  });
                });
              })

              # catppuccin's matplotlib extra breaks on matplotlib 3.11; only the palette is used.
              (_: pyprev: {
                catppuccin = pyprev.catppuccin.overridePythonAttrs (old: {
                  postPatch = (old.postPatch or "") + ''
                    substituteInPlace catppuccin/__init__.py \
                      --replace-fail 'if importlib.util.find_spec("matplotlib") is not None:' 'if False:'
                  '';
                  disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [ "tests/test_matplotlib.py" ];
                });
              })
            ];

            # catppuccin-gtk's build.py breaks on Python 3.14's argparse.
            catppuccin-gtk = prev.catppuccin-gtk.override { python3 = final.python313; };
          };
        };

        perSystem =
          {
            config,
            pkgs,
            system,
            self',
            ...
          }:
          let
            filterSystem = lib.filterAttrs (_: drv: drv.pkgs.stdenv.hostPlatform.system == system);
          in
          {
            _module.args.pkgs =
              let
                args = mkNixpkgsArgs { inherit self; };
              in
              import inputs.nixpkgs {
                inherit system;
                inherit (args) config;
                overlays = [ inputs.deploy-rs.overlays.default ] ++ args.overlays;
              };

            packages = {
              inherit (pkgs)
                cb
                sem-cli
                nimbus
                ;
            };

            legacyPackages = pkgs;

            devShells.default = pkgs.mkShell {
              packages =
                (builtins.attrValues {
                  inherit (pkgs)
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

            # No args deploys every node; scope with `nix run .#deploy -- '.#forge'`.
            apps.deploy = {
              type = "app";
              program = lib.getExe (
                pkgs.writeShellApplication {
                  name = "deploy";
                  runtimeInputs = [ pkgs.deploy-rs.deploy-rs ];
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
            # Every deploy node is x86_64-linux.
            checks = lib.optionalAttrs (system == "x86_64-linux") (pkgs.deploy-rs.lib.deployChecks self.deploy);
          };
      }
    );
}
