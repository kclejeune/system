{
  description = "nix system configurations";

  nixConfig = {
    extra-substituters = [
      # "https://cache.kclj.io/kclejeune"
      "https://kclejeune.cachix.org"
      "https://install.determinate.systems"
    ];
    extra-trusted-public-keys = [
      # "kclejeune:u0sa4anVXC4bKlzEsijdSlLyWVaEkApu6KWyDbbJMkk="
      "kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    ];
  };

  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    legacy.url = "github:nixos/nixpkgs/nixos-25.05";
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

      defaultSystems = lib.intersectLists (lib.platforms.linux ++ lib.platforms.darwin) (
        lib.platforms.x86_64 ++ lib.platforms.aarch64
      );
      darwinSystems = lib.intersectLists defaultSystems lib.platforms.darwin;

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
                "klejeune@${system}" = mkDarwinConfig {
                  inherit system;
                  extraModules = [
                    ./profiles/work
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
                    ./modules/hardware/phil.nix
                    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
                  ];
                  extraModules = [ ./profiles/personal ];
                };
              }
            ];

          homeConfigurations =
            # generate home-manager configs for each supported platform
            lib.mergeAttrsList (
              (lib.map (system: {
                "kclejeune@${system}" = mkHomeConfig {
                  inherit system;
                  username = "kclejeune";
                  extraModules = [ ./profiles/personal/home-manager ];
                };
                "klejeune@${system}" = mkHomeConfig {
                  inherit system;
                  username = "klejeune";
                  extraModules = [
                    ./profiles/work/home-manager
                  ];
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
          let
            filterSystem = attrs: lib.filterAttrs (name: drv: drv.pkgs.system == system) attrs;
          in
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [
                self.overlays.default
              ];
            };
            overlayAttrs = {
              inherit (inputs.legacy.legacyPackages.${system}) teleport_16;
              inherit (inputs.attic.packages.${system}) attic attic-client attic-server;

              sysdo = pkgs.callPackage ./pkgs/sysdo/package.nix { };
              cb = pkgs.callPackage ./pkgs/cb/package.nix { };
              fnox = pkgs.callPackage ./pkgs/fnox/package.nix { };
              stable = inputs.stable.legacyPackages.${system};
              determinate-nixd = inputs.determinate.packages.${system}.default;
              nix = inputs.determinate.inputs.nix.packages.${system}.default;
              nh = inputs.nh.packages.${system}.default;
            };
            checks = lib.mergeAttrsList [
              # home-manager checks; add _home suffix to original config to avoid nixos coflict
              (lib.mapAttrs' (name: cfg: (lib.nameValuePair "${name}_home" cfg.activationPackage)) (
                filterSystem self.homeConfigurations
              ))

              # nixOS + nix-darwin checks
              (lib.mapAttrs (_: cfg: cfg.config.system.build.toplevel) (
                filterSystem (self.darwinConfigurations // self.nixosConfigurations)
              ))
            ];
            legacyPackages = pkgs;
            packages = {
              inherit (pkgs) cb sysdo;
            };
            treefmt = {
              programs = {
                deadnix = {
                  enable = true;
                  no-lambda-arg = true;
                  no-lambda-pattern-names = true;
                };
                nixfmt.enable = true;
                jsonfmt.enable = true;
                mdformat.enable = true;
                stylua.enable = true;
                ruff-check.enable = true;
                ruff-format.enable = true;
                shellcheck.enable = true;
                shfmt.enable = true;
              };

              settings.excludes = [
                ".envrc"
                ".env"
              ];
              settings.on-unmatched = "info";
              settings.formatter.ruff-check.options = [
                # sort imports
                "--extend-select"
                "I"
              ];
              settings.formatter.jsonfmt.excludes = [
                ".vscode/*.json"
                "**/Spoons/**/*.json"
                ".zed/*.json"
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
