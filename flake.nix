{
  description = "nix system configurations";

  nixConfig = {
    extra-substituters = [
      # "https://cache.kclj.io/kclejeune"
      "https://kclejeune.cachix.org"
      "https://cache.garnix.io"
      "https://install.determinate.systems"
      "https://noctalia.cachix.org"
    ];
    extra-trusted-public-keys = [
      # "kclejeune:u0sa4anVXC4bKlzEsijdSlLyWVaEkApu6KWyDbbJMkk="
      "kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    stable.url = "github:nixos/nixpkgs/nixos-25.11";
    unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixpkgs.follows = "unstable";

    # NOTE: Don't override ANY inputs for attic - it requires specific versions
    # with compatible C++ bindings. nixpkgs-unstable has nix 2.31+ which has
    # breaking API changes (nix::openStore, nix::settings removed).
    attic.url = "github:kclejeune/attic?ref=kcl/worker-impl";

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

    # UEFI Secure Boot via signed unified kernel images. Replaces
    # systemd-boot on hosts that enroll modules/nixos/secure-boot.nix.
    lanzaboote.url = "github:nix-community/lanzaboote/v1.0.0";
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
      {
        imports = [
          inputs.home-manager.flakeModules.home-manager
          inputs.treefmt-nix.flakeModule
          inputs.flake-parts.flakeModules.easyOverlay
          inputs.git-hooks.flakeModule
          (inputs.import-tree ./modules)
          # flake-parts doesn't declare flake.darwinModules upstream; declare
          # it here so files under modules/darwin/ can each contribute a
          # named entry that merges into the attrset.
          {
            options.flake.darwinModules = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.unspecified;
              default = { };
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
              hm.imports = [ config.flake.homeModules.hyprland-host-phil ];
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
              hm.imports = [ config.flake.homeModules.displays-5570-home ];
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

            config.flake.nixosModules.tailscale
            config.flake.nixosModules.netbird
          ];
        };

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
                  pkgs = import inputs.nixpkgs {
                    inherit system;
                    config = {
                      allowUnsupportedSystem = true;
                      allowUnfree = true;
                      allowBroken = false;
                    };
                    overlays = [ self.overlays.default ];
                  };
                  extraSpecialArgs = {
                    inherit self inputs;
                    nixpkgs = inputs.nixpkgs;
                  };
                  modules = [
                    config.flake.homeModules.default
                    config.flake.homeModules.profile-personal
                    (
                      { pkgs, ... }:
                      {
                        nix.package = pkgs.nix;
                        home = { inherit username homeDirectory; };
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

        perSystem =
          {
            config,
            pkgs,
            system,
            ...
          }:
          let
            filterSystem = lib.filterAttrs (_: drv: drv.pkgs.system == system);
          in
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
            };

            legacyPackages = pkgs;

            overlayAttrs = {
              inherit (inputs.attic.packages.${system}) attic attic-client attic-server;

              cb = pkgs.callPackage ./pkgs/cb/package.nix { };
              fnox = pkgs.callPackage ./pkgs/fnox/package.nix { };
              weave = pkgs.callPackage ./pkgs/weave/package.nix { };
              stable = inputs.stable.legacyPackages.${system};
              determinate-nixd = inputs.determinate.packages.${system}.default;
              nix = inputs.determinate.inputs.nix.packages.${system}.default;
              nh = inputs.nh.packages.${system}.default;
            };

            devShells.default = pkgs.mkShell {
              packages =
                (builtins.attrValues {
                  inherit (pkgs)
                    bashInteractive
                    fd
                    ripgrep
                    uv
                    nh
                    ;
                })
                ++ config.pre-commit.settings.enabledPackages
                ++ (lib.attrValues config.treefmt.build.programs)
                ++ (lib.attrValues config.packages);
              shellHook = config.pre-commit.installationScript;
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

            checks =
              (lib.mapAttrs' (name: cfg: lib.nameValuePair "${name}_home" cfg.activationPackage) (
                filterSystem self.homeConfigurations
              ))
              // (lib.mapAttrs (_: cfg: cfg.config.system.build.toplevel) (
                filterSystem (self.darwinConfigurations // self.nixosConfigurations)
              ));
          };
      }
    );
}
