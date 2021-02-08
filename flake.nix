{
  description = "nix system configurations";

  nixConfig = {
    experimental-settings = ["nix-command" "flakes"];
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
    mach-nix = {
      url = "github:DavHau/mach-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, darwin, home-manager, mach-nix, flake-utils, ... }:
    {
      darwinConfigurations = {
        randall = darwin.lib.darwinSystem {
          modules = [
            home-manager.darwinModules.home-manager
            ./machines/darwin
            ./modules/profiles/personal.nix
          ];
          specialArgs = { inherit inputs nixpkgs; };
        };
        work = darwin.lib.darwinSystem {
          modules = [
            home-manager.darwinModules.home-manager
            ./machines/darwin
            ./modules/profiles/work.nix
          ];
          specialArgs = { inherit inputs nixpkgs; };
        };
      };
      nixosConfigurations = {
        phil = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            ./machines/nixos/phil
            ./modules/profiles/personal.nix
          ];
          specialArgs = { inherit inputs nixpkgs; };
        };
      };
      homeManagerConfigurations = {
        # Build and activate with
        # `nix build .#server.activationPackage; ./result/activate`
        # courtesy of @malob - https://github.com/malob/nixpkgs/
        server = home-manager.lib.homeManagerConfiguration rec {
          system = "x86_64-linux";
          username = "kclejeune";
          homeDirectory = "/home/${username}";
          extraSpecialArgs = { inherit inputs nixpkgs; };
          configuration = {
            imports = [
              ./machines/home-manager
              ./modules/profiles/home-manager/personal.nix
            ];
          };
        };
        workServer = home-manager.lib.homeManagerConfiguration rec {
          system = "x86_64-linux";
          username = "lejeukc1";
          homeDirectory = "/home/${username}";
          extraSpecialArgs = { inherit inputs nixpkgs; };
          configuration = {
            imports = [
              ./machines/home-manager
              ./modules/profiles/home-manager/work.nix
            ];
          };
        };
      };
    } //
    # add a devShell to this flake
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShell = let
          pyEnv = (mach-nix.lib.${system}.mkPython {
            requirements = ''
              black
              pylint
              typer-cli
              typer
              colorama
              shellingham
              distro
            '';
          });
        in pkgs.mkShell {
          buildInputs = with pkgs; [
            nixFlakes
            rnix-lsp
            pyEnv
          ];
        };
      });
}
