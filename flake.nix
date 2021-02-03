{
  description = "nix system configurations";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes"];
    substituters = ["https://cache.nixos.org" "https://kclejeune.cachix.org"];
    trusted-public-keys = ["cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko="];
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
          nixBuild = "${pkgs.nixFlakes}/bin/nix build";
          buildScriptFlags = ''
            -v --experimental-features "flakes nix-command" --show-trace
          '';
          mkBuildScript = { platform, buildAttr, ... }:
            pkgs.writeShellScriptBin "${platform}Build" ''
              ${nixBuild} ${buildAttr} ${buildScriptFlags}
            '';
          darwinBuild = mkBuildScript {
            platform = "darwin";
            buildAttr =
              ".#darwinConfigurations.$1.config.system.build.toplevel";
          };
          nixosBuild = mkBuildScript {
            platform = "nixos";
            buildAttr = ".#nixosConfigurations.$1.config.system.build.toplevel";
          };
          homeManagerBuild = mkBuildScript {
            platform = "homeManager";
            buildAttr = ".#homeManagerConfigurations.$1.activationPackage";
          };
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
            darwinBuild
            nixosBuild
            homeManagerBuild
          ];
        };
      });
}
