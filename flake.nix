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
    devshell.url = "github:numtide/devshell";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-hardware.url = "github:nixos/nixos-hardware";

    stable.url = "github:nixos/nixpkgs/nixos-21.11";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    trunk.url = "github:nixos/nixpkgs/master";

    comma = {
      url = "github:nix-community/comma";
      flake = false;
    };
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
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, flake-utils, ... }:
    let
      inherit (darwin.lib) darwinSystem;
      inherit (nixpkgs.lib) nixosSystem;
      inherit (home-manager.lib) homeManagerConfiguration;
      inherit (flake-utils.lib) eachDefaultSystem eachSystem;
      inherit (builtins) listToAttrs map;

      mkLib = nixpkgs:
        nixpkgs.lib.extend
        (final: prev: (import ./lib final) // home-manager.lib);

      lib = (mkLib nixpkgs);

      isDarwin = system: (builtins.elem system lib.platforms.darwin);
      homePrefix = system: if isDarwin system then "/Users" else "/home";

      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig = { system, nixpkgs ? inputs.nixpkgs
        , stable ? inputs.stable, lib ? (mkLib nixpkgs), baseModules ? [
          home-manager.darwinModules.home-manager
          ./modules/darwin
        ], extraModules ? [ ] }:
        darwinSystem {
          inherit system;
          modules = baseModules ++ extraModules;
          specialArgs = { inherit inputs lib nixpkgs stable; };
        };

      # generate a base nixos configuration with the
      # specified overlays, hardware modules, and any extraModules applied
      mkNixosConfig = { system ? "x86_64-linux", nixpkgs ? inputs.nixos-unstable
        , stable ? inputs.nixos-stable, lib ? (mkLib nixpkgs), hardwareModules
        , baseModules ? [
          home-manager.nixosModules.home-manager
          ./modules/nixos
        ], extraModules ? [ ] }:
        nixosSystem {
          inherit system;
          modules = baseModules ++ hardwareModules ++ extraModules;
          specialArgs = { inherit inputs lib nixpkgs stable; };
        };

      # generate a home-manager configuration usable on any unix system
      # with overlays and any extraModules applied
      mkHomeConfig = { username, system ? "x86_64-linux"
        , nixpkgs ? inputs.nixpkgs, stable ? inputs.nixos-stable
        , lib ? (mkLib nixpkgs), baseModules ? [
          ./modules/home-manager
          {
            home.sessionVariables = {
              NIX_PATH =
                "nixpkgs=${nixpkgs}:stable=${stable}:trunk=${inputs.trunk}\${NIX_PATH:+:}$NIX_PATH";
            };
          }
        ], extraModules ? [ ] }:
        homeManagerConfiguration rec {
          inherit system username;
          homeDirectory = "${homePrefix system}/${username}";
          extraSpecialArgs = { inherit inputs lib nixpkgs stable; };
          configuration = {
            imports = baseModules ++ extraModules ++ [ ./modules/overlays.nix ];
          };
        };
    in {
      checks = listToAttrs (
        # darwin checks
        (map (system: {
          name = system;
          value = {
            darwin =
              self.darwinConfigurations.randall-intel.config.system.build.toplevel;
            darwinServer =
              self.homeConfigurations.darwinServer.activationPackage;
          };
        }) lib.platforms.darwin) ++
        # linux checks
        (map (system: {
          name = system;
          value = {
            nixos = self.nixosConfigurations.phil.config.system.build.toplevel;
            server = self.homeConfigurations.server.activationPackage;
          };
        }) lib.platforms.linux));

      darwinConfigurations = {
        randall = mkDarwinConfig {
          system = "aarch64-darwin";
          extraModules = [
            ./profiles/personal.nix
            ./modules/darwin/apps.nix
            { homebrew.brewPrefix = "/opt/homebrew/bin"; }
          ];
        };
        randall-intel = mkDarwinConfig {
          system = "x86_64-darwin";
          extraModules = [
            ./profiles/personal.nix
            ./modules/darwin/apps.nix
            { homebrew.brewPrefix = "/opt/homebrew/bin"; }
          ];
        };
        work = mkDarwinConfig {
          system = "x86_64-darwin";
          extraModules =
            [ ./profiles/work.nix ./modules/darwin/apps-minimal.nix ];
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
        vagrant = mkHomeConfig {
          username = "vagrant";
          extraModules = [ ./profiles/home-manager/personal.nix ];
        };
      };
    } //
    # add a devShell to this flake
    eachDefaultSystem (system:
      let
        pkgs = import inputs.stable {
          inherit system;
          overlays = [ inputs.devshell.overlay ];
        };
        pyEnv = (pkgs.python3.withPackages
          (ps: with ps; [ black pylint typer colorama shellingham ]));
        sysdo = pkgs.writeShellScriptBin "sysdo" ''
          cd $PRJ_ROOT && ${pyEnv}/bin/python3 bin/do.py $@
        '';
      in {
        devShell = pkgs.devshell.mkShell {
          packages = [ pyEnv pkgs.treefmt pkgs.nixfmt pkgs.stylua ];
          commands = [{
            name = "sysdo";
            package = sysdo;
            category = "utilities";
            help = "perform actions on this repository";
          }];
        };
      });
}
