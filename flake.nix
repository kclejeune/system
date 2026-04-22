{
  description = "nix system configurations";

  nixConfig = {
    extra-substituters = [
      # "https://cache.kclj.io/kclejeune"
      "https://kclejeune.cachix.org"
      "https://cache.garnix.io"
      "https://install.determinate.systems"
    ];
    extra-trusted-public-keys = [
      # "kclejeune:u0sa4anVXC4bKlzEsijdSlLyWVaEkApu6KWyDbbJMkk="
      "kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
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
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.inputs.flake-compat.follows = "flake-compat";

    nixGL.url = "github:nix-community/nixGL";
    nixGL.inputs.nixpkgs.follows = "nixpkgs";

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
  };

  outputs =
    {
      self,
      darwin,
      home-manager,
      determinate,
      flake-parts,
      ...
    }@inputs:
    let
      inherit (inputs.nixpkgs) lib;

      defaultSystems =
        (lib.intersectLists lib.platforms.linux (lib.platforms.x86_64 ++ lib.platforms.aarch64))
        ++ (lib.intersectLists lib.platforms.aarch64 lib.platforms.darwin);
      darwinSystems = lib.intersectLists lib.platforms.aarch64 lib.platforms.darwin;

      homePrefix = system: if (lib.elem system darwinSystems) then "/Users" else "/home";

      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        {
          system ? "aarch64-darwin",
          nixpkgs ? inputs.nixpkgs,
          baseModules ? [
            determinate.darwinModules.default
            home-manager.darwinModules.home-manager
            ./modules/darwin
          ],
          extraModules ? [ ],
        }:
        darwin.lib.darwinSystem {
          inherit system;
          modules = baseModules ++ extraModules;
          specialArgs = { inherit self inputs nixpkgs; };
        };

      # generate a base nixos configuration with the
      # specified overlays, hardware modules, and any extraModules applied
      mkNixosConfig =
        {
          system ? "x86_64-linux",
          nixpkgs ? inputs.nixos-unstable,
          hardwareModules,
          baseModules ? [
            determinate.nixosModules.default
            home-manager.nixosModules.home-manager
            inputs.disko.nixosModules.disko
            inputs.sops-nix.nixosModules.sops
            ./modules/nixos
          ],
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = baseModules ++ hardwareModules ++ extraModules;
          specialArgs = { inherit self inputs nixpkgs; };
        };

      # generate a home-manager configuration usable on any unix system
      # with overlays and any extraModules applied
      mkHomeConfig =
        {
          username,
          system ? "x86_64-linux",
          nixpkgs ? inputs.nixpkgs,
          baseModules ? [
            ./modules/home-manager
            (
              { pkgs, ... }:
              {
                nix.package = pkgs.nix;
                home = {
                  inherit username;
                  homeDirectory = "${homePrefix system}/${username}";
                };
              }
            )
          ],
          extraModules ? [ ],
        }:
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config = import ./modules/config.nix;
            overlays = [ self.overlays.default ];
          };
          extraSpecialArgs = { inherit self inputs nixpkgs; };
          modules = baseModules ++ extraModules;
        };
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        config,
        withSystem,
        moduleWithSystem,
        ...
      }:
      {
        debug = true;
        imports = [
          inputs.home-manager.flakeModules.home-manager
          inputs.treefmt-nix.flakeModule
          inputs.flake-parts.flakeModules.easyOverlay
          inputs.git-hooks.flakeModule
        ];
        systems = lib.intersectLists (lib.platforms.linux ++ lib.platforms.darwin) (
          lib.platforms.x86_64 ++ lib.platforms.aarch64
        );
        flake = {
          nixosModules = {
            default = ./modules/nixos;
            gnome = ./modules/nixos/gnome.nix;
            hyprland = ./modules/nixos/hyprland.nix;
            desktop = ./modules/nixos/desktop.nix;
            desktopBase = ./modules/nixos/desktop-base.nix;
            hetzner = ./modules/nixos/hetzner.nix;
            gateway = ./modules/nixos/gateway.nix;
            keybase = ./modules/nixos/keybase.nix;
          };

          darwinModules = {
            default = ./modules/darwin;
            apps = ./modules/darwin/apps.nix;
          };

          homeModules = {
            default = ./modules/home-manager;
            onepassword = ./modules/home-manager/1password.nix;
          };

          darwinConfigurations =
            # generate darwin configs for each supported platform
            lib.mergeAttrsList (
              # arch-independent configs that can operate on both x86_64-darwin and aarch64-darwin
              (lib.map (system: {
                "kclejeune@${system}" = mkDarwinConfig {
                  inherit system;
                  extraModules = [
                    ./profiles/personal
                    ./modules/darwin/apps.nix
                  ];
                };
              }) darwinSystems)
              # and "custom" ones that aren't universal
              ++ [ ]
            );

          nixosConfigurations =
            # generate nixos configs, if these are ever applicable
            lib.mergeAttrsList [
              {
                "kclejeune@x86_64-linux" = mkNixosConfig {
                  system = "x86_64-linux";
                  hardwareModules = [
                    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
                  ];
                  extraModules = [
                    ./modules/nixos/desktop.nix
                    ./profiles/personal
                  ];
                };
                gateway = mkNixosConfig {
                  system = "x86_64-linux";
                  hardwareModules = [
                    ./modules/nixos/hetzner.nix
                  ];
                  extraModules = [
                    ./modules/nixos/gateway.nix
                    ./profiles/personal
                  ];
                };
              }
            ];

          deploy.nodes.gateway = {
            hostname = "gateway.kclj.io";
            sshUser = "kclejeune";
            user = "root";
            profiles.system.path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.gateway;
          };

          homeConfigurations =
            # generate home-manager configs for each supported platform
            lib.mergeAttrsList (
              (lib.map (system: {
                "kclejeune@${system}" = mkHomeConfig {
                  inherit system;
                  username = "kclejeune";
                  extraModules = [ ./profiles/personal/home-manager ];
                };
              }) defaultSystems)
              # and "custom" ones that aren't universal
              ++ [ ]
            );
        };

        perSystem =
          {
            config,
            pkgs,
            system,
            lib,
            ...
          }:
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [
                self.overlays.default
              ];
            };
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
            legacyPackages = pkgs;
            packages.deploy-rs = inputs.deploy-rs.packages.${system}.default;
            checks = inputs.deploy-rs.lib.${system}.deployChecks self.deploy;
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
            devShells = {
              default = pkgs.mkShell {
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
                  ++ (lib.mapAttrsToList (name: value: value) config.packages);
                shellHook = config.pre-commit.installationScript;
              };
            };
          };
      }
    );
}
