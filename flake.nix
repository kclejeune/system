{
  description = "nix system configurations";

  nixConfig = {
    substituters = [
      "https://kclejeune.cachix.org"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stable.url = "github:nixos/nixpkgs/nixos-20.09";
    flake-utils.url = "github:numtide/flake-utils/master";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    darwin = {
      url = "github:kclejeune/nix-darwin/brew-bundle";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, darwin, home-manager, mach-nix, flake-utils, ... }:
    let
      overlays = [ inputs.neovim-nightly-overlay.overlay ];
      mkDarwinConfig = { hostname, baseModules ? [
        home-manager.darwinModules.home-manager
        ./machines/darwin
      ], extraModules ? [ ] }: {
        "${hostname}" = darwin.lib.darwinSystem {
          # system = "x86_64-darwin";
          modules = baseModules ++ extraModules
            ++ [{ nixpkgs.overlays = overlays; }];
          specialArgs = { inherit inputs nixpkgs; };
        };
      };
      mkNixosConfig = { hostname, system ? "x86_64-linux", baseModules ? [
        home-manager.nixosModules.home-manager
        ./machines/nixos
      ], extraModules ? [ ] }: {
        "${hostname}" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = baseModules ++ extraModules
            ++ [{ nixpkgs.overlays = overlays; }];
          specialArgs = { inherit inputs nixpkgs; };
        };
      };
      mkHomeManagerConfig =
        { hostname, username, system ? "x86_64-linux", extraModules ? [ ] }: {
          "${hostname}" = home-manager.lib.homeManagerConfiguration rec {
            inherit system username;
            homeDirectory = "/home/${username}";
            extraSpecialArgs = { inherit inputs nixpkgs; };
            configuration = {
              nixpkgs.overlays = overlays;
              imports = [ ./machines/home-manager ] ++ extraModules;
            };
          };
        };
    in {
      darwinConfigurations = mkDarwinConfig {
        hostname = "randall";
        extraModules = [ ./modules/profiles/personal.nix ];
      } // mkDarwinConfig {
        hostname = "work";
        extraModules = [ ./modules/profiles/work.nix ];
      };
      nixosConfigurations = mkNixosConfig {
        hostname = "phil";
        extraModules =
          [ ./machines/nixos/phil ./modules/profiles/personal.nix ];
      };
      # Build and activate with
      # `nix build .#server.activationPackage; ./result/activate`
      # courtesy of @malob - https://github.com/malob/nixpkgs/
      homeManagerConfigurations = mkHomeManagerConfig {
        hostname = "server";
        username = "kclejeune";
        extraModules = [ ./modules/profiles/home-manager/personal.nix ];
      } // mkHomeManagerConfig {
        hostname = "workServer";
        username = "lejeukc1";
        extraModules = [ ./modules/profiles/home-manager/work.nix ];
      } // mkHomeManagerConfig {
        hostname = "multipass";
        username = "ubuntu";
        extraModules = [ ./modules/profiles/home-manager/personal.nix ];
      };
    } //
    # add a devShell to this flake
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python3;
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixFlakes
            rnix-lsp
            (python.withPackages
              (ps: with ps; [ black pylint typer colorama shellingham ]))
          ];
        };
      });
}
