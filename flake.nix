{
  description = "nix system configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stable.url = "github:nixos/nixpkgs/nixos-20.09";
    flake-utils.url = "github:numtide/flake-utils/master";
    nixos-hardware.url = "github:nixos/nixos-hardware";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    darwin = {
      url = "github:kclejeune/nix-darwin/backup-etc";
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

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, nixos-hardware, ... }:
    let
      overlays = [ inputs.neovim-nightly-overlay.overlay ];
      mkDarwinConfig = { hostname, baseModules ? [
        inputs.home-manager.darwinModules.home-manager
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
        inputs.home-manager.nixosModules.home-manager
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
          "${hostname}" = inputs.home-manager.lib.homeManagerConfiguration rec {
            inherit system username;
            homeDirectory = "/home/${username}";
            extraSpecialArgs = { inherit inputs nixpkgs; };
            configuration = {
              imports = [ ./machines/home-manager ] ++ extraModules
                ++ [{ nixpkgs.overlays = overlays; }];
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
        extraModules = [
          ./machines/nixos/phil
          ./modules/profiles/personal.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-t460s
        ];
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
    inputs.flake-utils.lib.eachDefaultSystem (system:
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
