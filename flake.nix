{
  description = "nix system configurations";

  nixConfig = {
    substituters =
      [ "https://kclejeune.cachix.org" "https://nix-community.cachix.org/" ];

    trusted-public-keys = [
      "kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    darwin-stable.url = "github:nixos/nixpkgs/nixpkgs-21.05-darwin";
    devshell.url = "github:numtide/devshell";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixos-stable.url = "github:nixos/nixpkgs/nixos-21.05";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    treefmt.url = "github:numtide/treefmt";
    comma = {
      url = "github:Shopify/comma";
      flake = false;
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    darwin = {
      url = "github:kclejeune/nix-darwin/backup-etc";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    inputs@{ self
    , nixpkgs-unstable
    , nixos-unstable
    , nixos-stable
    , darwin-stable
    , darwin
    , home-manager
    , nixos-hardware
    , devshell
    , treefmt
    , flake-utils
    , ...
    }:
    let
      inherit (darwin.lib) darwinSystem;
      inherit (nixpkgs-unstable.lib) nixosSystem;
      inherit (home-manager.lib) homeManagerConfiguration;
      inherit (flake-utils.lib) eachDefaultSystem eachSystem;
      inherit (builtins) listToAttrs map;

      mkLib = nixpkgs:
        nixpkgs.lib.extend
          (final: prev: (import ./lib final) // home-manager.lib);

      lib = (mkLib nixos-stable);

      isDarwin = system: (builtins.elem system lib.platforms.darwin);
      homePrefix = system: if isDarwin system then "/Users" else "/home";
      supportedSystems = [ "x86_64-darwin" "x86_64-linux" ];

      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        { system ? "x86_64-darwin"
        , nixpkgs ? nixpkgs-unstable
        , stable ? darwin-stable
        , lib ? (mkLib nixpkgs)
        , baseModules ? [
            home-manager.darwinModules.home-manager
            ./modules/darwin
          ]
        , extraModules ? [ ]
        }:
        darwinSystem {
          inherit system;
          modules = baseModules ++ extraModules;
          specialArgs = { inherit inputs lib nixpkgs stable; };
        };

      # generate a base nixos configuration with the
      # specified overlays, hardware modules, and any extraModules applied
      mkNixosConfig =
        { system ? "x86_64-linux"
        , nixpkgs ? nixos-unstable
        , stable ? nixos-stable
        , lib ? (mkLib nixpkgs)
        , hardwareModules
        , baseModules ? [
            home-manager.nixosModules.home-manager
            ./modules/nixos
          ]
        , extraModules ? [ ]
        }:
        nixosSystem {
          inherit system;
          modules = baseModules ++ hardwareModules ++ extraModules;
          specialArgs = { inherit inputs lib nixpkgs stable; };
        };

      # generate a home-manager configuration usable on any unix system
      # with overlays and any extraModules applied
      mkHomeConfig =
        { username
        , system ? "x86_64-linux"
        , nixpkgs ? nixpkgs-unstable
        , stable ? nixos-stable
        , lib ? (mkLib nixpkgs)
        , baseModules ? [ ./modules/home-manager ]
        , extraModules ? [ ]
        }:
        homeManagerConfiguration
          rec {
            inherit system username;
            homeDirectory = "${homePrefix system}/${username}";
            extraSpecialArgs = { inherit inputs lib nixpkgs stable; };
            configuration = {
              imports = baseModules ++ extraModules ++ [
                (import ./modules/overlays.nix {
                  inherit inputs nixpkgs stable;
                })
              ];
            };
          };
    in
    {
      checks = listToAttrs (
        # darwin checks
        (map
          (system: {
            name = system;
            value = {
              darwin =
                self.darwinConfigurations.randall.config.system.build.toplevel;
              darwinServer = self.homeConfigurations.darwinServer.activationPackage;
            };
          })
          lib.platforms.darwin) ++
        # linux checks
        (map
          (system: {
            name = system;
            value = {
              nixos = self.nixosConfigurations.phil.config.system.build.toplevel;
              server = self.homeConfigurations.server.activationPackage;
            };
          })
          lib.platforms.linux)
      );

      darwinConfigurations = {
        randall = mkDarwinConfig {
          extraModules = [ ./profiles/personal.nix ./modules/darwin/apps.nix ];
        };
        work = mkDarwinConfig {
          extraModules =
            [ ./profiles/work.nix ./modules/darwin/apps-minimal.nix ];
        };
      };

      nixosConfigurations = {
        phil = mkNixosConfig {
          hardwareModules = [
            ./modules/hardware/phil.nix
            nixos-hardware.nixosModules.lenovo-thinkpad-t460s
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
        workServer = mkHomeConfig {
          username = "lejeukc1";
          extraModules = [ ./profiles/home-manager/work.nix ];
        };
        multipass = mkHomeConfig {
          username = "ubuntu";
          extraModules = [ ./profiles/home-manager/personal.nix ];
        };
      };
    } //
    # add a devShell to this flake
    eachSystem supportedSystems (system:
    let
      pkgs = import nixos-stable {
        inherit system;
        overlays = [ devshell.overlay ];
      };
      pyEnv = (pkgs.python3.withPackages
        (ps: with ps; [ black pylint typer colorama shellingham ]));
      nixBin = pkgs.writeShellScriptBin "nix" ''
        ${pkgs.nixFlakes}/bin/nix --option experimental-features "nix-command flakes" "$@"
      '';
      sysdo = pkgs.writeShellScriptBin "sysdo" ''
        cd $DEVSHELL_ROOT && ${pyEnv}/bin/python3 bin/do.py $@
      '';
      fmt = treefmt.defaultPackage.${system};
    in
    {
      devShell = pkgs.devshell.mkShell {
        packages = with pkgs; [ nixBin pyEnv fmt ];
        commands = [
          {
            name = "sysdo";
            package = sysdo;
            category = "utilities";
            help = "perform actions on this repository";
          }
          {
            help = "Format the entire code tree";
            name = "fmt";
            command = "treefmt -q";
            category = "utilities";
          }
        ];
      };
    });
}
