{
  description = "nix system configurations";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://kclejeune.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko="
    ];
  };

  inputs = {
    # package repos
    stable.url = "github:nixos/nixpkgs/nixos-22.05";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    small.url = "github:nixos/nixpkgs/nixos-unstable-small";

    # system management
    nixos-hardware.url = "github:nixos/nixos-hardware";
    darwin = {
      url = "github:kclejeune/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # shell stuff
    flake-utils.url = "github:numtide/flake-utils";
    devshell = {
      url = "github:numtide/devshell";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, flake-utils, ... }:
    let
      inherit (flake-utils.lib) eachSystemMap;

      isDarwin = system: (builtins.elem system nixpkgs.lib.platforms.darwin);
      homePrefix = system: if isDarwin system then "/Users" else "/home";
      defaultSystems = [ "aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux" ];

      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        { system ? "aarch64-darwin"
        , nixpkgs ? inputs.nixpkgs
        , stable ? inputs.stable
        , baseModules ? [
            home-manager.darwinModules.home-manager
            ./modules/darwin
          ]
        , extraModules ? [ ]
        }:
        darwin.lib.darwinSystem {
          inherit system;
          modules = baseModules ++ extraModules;
          specialArgs = { inherit self inputs nixpkgs stable; };
        };

      # generate a base nixos configuration with the
      # specified overlays, hardware modules, and any extraModules applied
      mkNixosConfig =
        { system ? "x86_64-linux"
        , nixpkgs ? inputs.nixos-unstable
        , stable ? inputs.stable
        , hardwareModules
        , baseModules ? [
            home-manager.nixosModules.home-manager
            ./modules/nixos
          ]
        , extraModules ? [ ]
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = baseModules ++ hardwareModules ++ extraModules;
          specialArgs = { inherit self inputs nixpkgs stable; };
        };

      # generate a home-manager configuration usable on any unix system
      # with overlays and any extraModules applied
      mkHomeConfig =
        { username
        , system ? "x86_64-linux"
        , nixpkgs ? inputs.nixpkgs
        , stable ? inputs.stable
        , baseModules ? [
            ./modules/home-manager
            {
              home = {
                inherit username;
                homeDirectory = "${homePrefix system}/${username}";
                sessionVariables = {
                  NIX_PATH =
                    "nixpkgs=${nixpkgs}:stable=${stable}\${NIX_PATH:+:}$NIX_PATH";
                };
              };
            }
          ]
        , extraModules ? [ ]
        }:
        home-manager.lib.homeManagerConfiguration rec {
          pkgs = import nixpkgs { inherit system; };
          extraSpecialArgs = { inherit self inputs nixpkgs stable; };
          modules = baseModules ++ extraModules ++ [ ./modules/overlays.nix ];
        };
    in
    {
      checks = builtins.listToAttrs (
        # darwin checks
        (builtins.map
          (system: {
            name = system;
            value = {
              darwin =
                self.darwinConfigurations.randall-intel.config.system.build.toplevel;
              darwinServer =
                self.homeConfigurations.darwinServer.activationPackage;
            };
          })
          nixpkgs.lib.platforms.darwin) ++
        # linux checks
        (builtins.map
          (system: {
            name = system;
            value = {
              nixos = self.nixosConfigurations.phil.config.system.build.toplevel;
              server = self.homeConfigurations.server.activationPackage;
            };
          })
          nixpkgs.lib.platforms.linux)
      );

      darwinConfigurations = {
        randall = mkDarwinConfig {
          extraModules = [ ./profiles/personal.nix ./modules/darwin/apps.nix ];
        };
        work = mkDarwinConfig { extraModules = [ ./profiles/work.nix ]; };
        randall-intel = mkDarwinConfig {
          system = "x86_64-darwin";
          extraModules = [ ./profiles/personal.nix ./modules/darwin/apps.nix ];
        };
        work-intel = mkDarwinConfig {
          system = "x86_64-darwin";
          extraModules = [ ./profiles/work.nix ];
        };
      };

      nixosConfigurations = {
        phil = mkNixosConfig {
          hardwareModules = [
            ./modules/hardware/phil.nix
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
          ];
          extraModules = [ ./profiles/personal.nix ];
        };
      };

      homeConfigurations = {
        server = mkHomeConfig {
          username = "kclejeune";
          extraModules = [ ./profiles/home-manager/personal.nix ];
        };
        darwinServer = mkHomeConfig {
          username = "kclejeune";
          system = "x86_64-darwin";
          extraModules = [ ./profiles/home-manager/personal.nix ];
        };
        darwinServerM1 = mkHomeConfig {
          username = "kclejeune";
          system = "aarch64-darwin";
          extraModules = [ ./profiles/home-manager/personal.nix ];
        };
        workServer = mkHomeConfig {
          username = "lejeukc1";
          extraModules = [ ./profiles/home-manager/work.nix ];
        };
      };

      devShells = eachSystemMap defaultSystems (system:
        let
          pkgs = import inputs.stable {
            inherit system;
            overlays = builtins.attrValues self.overlays;
          };
        in
        {
          default = pkgs.devshell.mkShell {
            packages = with pkgs; [
              nixfmt
              pre-commit
              rnix-lsp
              self.packages.${system}.pyEnv
              stylua
              treefmt
            ];
            commands = [{
              name = "sysdo";
              package = self.packages.${system}.sysdo;
              category = "utilities";
              help = "perform actions on this repository";
            }];
          };
        });

      packages = eachSystemMap defaultSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = builtins.attrValues self.overlays;
          };
        in
        rec {
          pyEnv = pkgs.python3.withPackages
            (ps: with ps; [ black typer colorama shellingham ]);
          sysdo = pkgs.writeScriptBin "sysdo" ''
            #! ${pyEnv}/bin/python3
            ${builtins.readFile ./bin/do.py}
          '';
        });

      overlays = {
        channels = final: prev: {
          # expose other channels via overlays
          stable = import inputs.stable { system = prev.system; };
          small = import inputs.small { system = prev.system; };
        };
        python =
          let
            overrides = (pfinal: pprev: {
              pyopenssl = pprev.pyopenssl.overrideAttrs
                (old: { meta = old.meta // { broken = false; }; });
            });
          in
          final: prev: {
            python3 = prev.python3.override {
              packageOverrides = overrides;
            };
            python39 = prev.python39.override {
              packageOverrides = overrides;
            };
            python310 = prev.python310.override {
              packageOverrides = overrides;
            };
          };
        extraPackages = final: prev: {
            sysdo = self.packages.${prev.system}.sysdo;
            pyEnv = self.packages.${prev.system}.pyEnv;
        };
        devshell = inputs.devshell.overlay;
      };
    };
}
