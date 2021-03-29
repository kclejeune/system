{
  description = "nix system configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stable.url = "github:nixos/nixpkgs/nixos-20.09";
    flake-utils.url = "github:numtide/flake-utils";
    dev-shell.url = "github:numtide/devshell";
    nixos-hardware.url = "github:nixos/nixos-hardware";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    darwin = {
      url = "github:kclejeune/nix-darwin/fix-broken-cmd";
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

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, nixos-hardware
    , dev-shell, ... }:
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
        extraModules = [ ./profiles/personal.nix ];
      } // mkDarwinConfig {
        hostname = "work";
        extraModules = [ ./profiles/work.nix ];
      };
      nixosConfigurations = mkNixosConfig {
        hostname = "phil";
        extraModules = [
          ./machines/nixos/phil
          ./profiles/personal.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-t460s
        ];
      };
      # Build and activate with
      # `nix build .#server.activationPackage; ./result/activate`
      # courtesy of @malob - https://github.com/malob/nixpkgs/
      homeManagerConfigurations = mkHomeManagerConfig {
        hostname = "server";
        username = "kclejeune";
        extraModules = [ ./profiles/home-manager/personal.nix ];
      } // mkHomeManagerConfig {
        hostname = "workServer";
        username = "lejeukc1";
        extraModules = [ ./profiles/home-manager/work.nix ];
      } // mkHomeManagerConfig {
        hostname = "multipass";
        username = "ubuntu";
        extraModules = [ ./profiles/home-manager/personal.nix ];
      };
    } //
    # add a devShell to this flake
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pyEnv = (pkgs.python3.withPackages
          (ps: with ps; [ black pylint typer colorama shellingham ]));
        nixBin = pkgs.writeShellScriptBin "nix" ''
          ${pkgs.nixFlakes}/bin/nix --option experimental-features "nix-command flakes" "$@"
        '';
        sysdo = pkgs.writeShellScriptBin "sysdo" ''
          cd $DEVSHELL_ROOT && ${pyEnv}/bin/python3 bin/do.py $@
        '';
      in {
        devShell = dev-shell.legacyPackages.${system}.mkShell {
          packages = with pkgs; [ nixBin pyEnv sysdo ];
          commands = [{
            name = "sysdo";
            package = sysdo;
            help = "perform actions on this repository";
          }];
        };
      });
}
