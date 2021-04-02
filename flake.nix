{
  description = "nix system configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stable.url = "github:nixos/nixpkgs/nixos-20.09";
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    treefmt.url = "github:numtide/treefmt";

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

  outputs =
    inputs@{ self
    , nixpkgs
    , stable
    , darwin
    , home-manager
    , nixos-hardware
    , devshell
    , treefmt
    , flake-utils
    , ...
    }:
    let
      overlays = [ inputs.neovim-nightly-overlay.overlay ];

      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        { hostname
        , baseModules ? [
            home-manager.darwinModules.home-manager
            ./modules/darwin
          ]
        , extraModules ? [ ]
        }: {
          "${hostname}" = darwin.lib.darwinSystem {
            # system = "x86_64-darwin";
            modules = baseModules ++ extraModules
              ++ [{ nixpkgs.overlays = overlays; }];
            specialArgs = { inherit inputs nixpkgs; };
          };
        };

      # generate a base nixos configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkNixosConfig =
        { hostname
        , system ? "x86_64-linux"
        , baseModules ? [
            home-manager.nixosModules.home-manager
            ./modules/nixos
          ]
        , extraModules ? [ ]
        }: {
          "${hostname}" = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = baseModules ++ extraModules
              ++ [{ nixpkgs.overlays = overlays; }];
            specialArgs = { inherit inputs nixpkgs; };
          };
        };

      # generate a home-manager configuration usable on any unix system
      # with overlays and any extraModules applied
      mkHomeManagerConfig =
        { hostname
        , username
        , system ? "x86_64-linux"
        , baseModules ? [
            ./modules/home-manager/core.nix
            ./modules/home-manager/dotfiles
            ./modules/home-manager/home.nix
          ]
        , extraModules ? [ ]
        }: {
          "${hostname}" = home-manager.lib.homeManagerConfiguration rec {
            inherit system username;
            homeDirectory = "/home/${username}";
            extraSpecialArgs = { inherit inputs nixpkgs; };
            configuration = {
              imports = [ ./machines/home-manager ] ++ extraModules
                ++ [{ nixpkgs.overlays = overlays; }];
            };
          };
        };
    in
    {
      darwinConfigurations = mkDarwinConfig
        {
          hostname = "randall";
          extraModules = [ ./profiles/personal.nix ];
        } // mkDarwinConfig {
        hostname = "work";
        extraModules = [ ./profiles/work.nix ];
      };
      nixosConfigurations = mkNixosConfig {
        hostname = "phil";
        extraModules = [
          ./modules/hardware/phil.nix
          ./profiles/personal.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-t460s
        ];
      };
      # Build and activate with
      # `nix build .#server.activationPackage; ./result/activate`
      # courtesy of @malob - https://github.com/malob/nixpkgs/
      homeManagerConfigurations = mkHomeManagerConfig
        {
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
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
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
      fmt = pkgs.writeShellScriptBin "treefmt" ''
        ${treefmt.defaultPackage.${system}}/bin/treefmt -q $@
      '';
    in
    {
      devShell = pkgs.devshell.mkShell {
        packages = with pkgs; [ nixBin pyEnv sysdo ];
        commands = [
          {
            name = "sysdo";
            package = sysdo;
            category = "utilities";
            help = "perform actions on this repository";
          }
          {
            help = "Format the entire code tree";
            name = "treefmt";
            category = "utilities";
            package = fmt;
          }
        ];
      };
    });
}
