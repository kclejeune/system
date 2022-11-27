{
  description = "nix system configurations";

  nixConfig = {
    substituters = ["https://cache.nixos.org" "https://kclejeune.cachix.org"];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = inputs @ {
    self,
    darwin,
    home-manager,
    flake-utils,
    treefmt-nix,
    ...
  }: let
    inherit (flake-utils.lib) eachSystemMap;

    isDarwin = system: (builtins.elem system inputs.nixpkgs.lib.platforms.darwin);
    homePrefix = system:
      if isDarwin system
      then "/Users"
      else "/home";
    defaultSystems = ["aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux"];

    # generate a base darwin configuration with the
    # specified hostname, overlays, and any extraModules applied
    mkDarwinConfig = {
      system ? "aarch64-darwin",
      nixpkgs ? inputs.nixpkgs,
      stable ? inputs.stable,
      baseModules ? [
        home-manager.darwinModules.home-manager
        ./modules/darwin
      ],
      extraModules ? [],
    }:
      inputs.darwin.lib.darwinSystem {
        inherit system;
        modules = baseModules ++ extraModules;
        specialArgs = {inherit self inputs nixpkgs;};
      };

    # generate a base nixos configuration with the
    # specified overlays, hardware modules, and any extraModules applied
    mkNixosConfig = {
      system ? "x86_64-linux",
      nixpkgs ? inputs.nixos-unstable,
      stable ? inputs.stable,
      hardwareModules,
      baseModules ? [
        home-manager.nixosModules.home-manager
        ./modules/nixos
      ],
      extraModules ? [],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = baseModules ++ hardwareModules ++ extraModules;
        specialArgs = {inherit self inputs nixpkgs;};
      };

    # generate a home-manager configuration usable on any unix system
    # with overlays and any extraModules applied
    mkHomeConfig = {
      username,
      system ? "x86_64-linux",
      nixpkgs ? inputs.nixpkgs,
      stable ? inputs.stable,
      baseModules ? [
        ./modules/home-manager
        {
          home = {
            inherit username;
            homeDirectory = "${homePrefix system}/${username}";
            sessionVariables = {
              NIX_PATH = "nixpkgs=${nixpkgs}:stable=${stable}\${NIX_PATH:+:}$NIX_PATH";
            };
          };
        }
      ],
      extraModules ? [],
    }:
      inputs.home-manager.lib.homeManagerConfiguration rec {
        pkgs = import nixpkgs {
          inherit system;
          overlays = builtins.attrValues self.overlays;
        };
        extraSpecialArgs = {inherit self inputs nixpkgs;};
        modules = baseModules ++ extraModules;
      };

    mkChecks = {
      arch,
      os,
      username ? "kclejeune",
    }: {
      "${arch}-${os}" = {
        "${username}_${os}" =
          (
            if os == "darwin"
            then self.darwinConfigurations
            else self.nixosConfigurations
          )
          ."${username}@${arch}-${os}"
          .config
          .system
          .build
          .toplevel;
        "${username}_home" =
          self.homeConfigurations."${username}@${arch}-${os}".activationPackage;
        devShell = self.devShells."${arch}-${os}".default;
      };
    };
  in {
    checks =
      {}
      // (mkChecks {
        arch = "aarch64";
        os = "darwin";
      })
      // (mkChecks {
        arch = "x86_64";
        os = "darwin";
      })
      // (mkChecks {
        arch = "aarch64";
        os = "linux";
      })
      // (mkChecks {
        arch = "x86_64";
        os = "linux";
      });

    darwinConfigurations = {
      "kclejeune@aarch64-darwin" = mkDarwinConfig {
        system = "aarch64-darwin";
        extraModules = [./profiles/personal.nix ./modules/darwin/apps.nix];
      };
      "kclejeune@x86_64-darwin" = mkDarwinConfig {
        system = "x86_64-darwin";
        extraModules = [./profiles/personal.nix ./modules/darwin/apps.nix];
      };
      "lejeukc1@aarch64-darwin" = mkDarwinConfig {
        system = "aarch64-darwin";
        extraModules = [./profiles/work.nix];
      };
      "lejeukc1@x86_64-darwin" = mkDarwinConfig {
        system = "aarch64-darwin";
        extraModules = [./profiles/work.nix];
      };
    };

    nixosConfigurations = {
      "kclejeune@x86_64-linux" = mkNixosConfig {
        system = "x86_64-linux";
        hardwareModules = [
          ./modules/hardware/phil.nix
          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
        ];
        extraModules = [./profiles/personal.nix];
      };
      "kclejeune@aarch64-linux" = mkNixosConfig {
        system = "aarch64-linux";
        hardwareModules = [./modules/hardware/phil.nix];
        extraModules = [./profiles/personal.nix];
      };
    };

    homeConfigurations = {
      "kclejeune@x86_64-linux" = mkHomeConfig {
        username = "kclejeune";
        system = "x86_64-linux";
        extraModules = [./profiles/home-manager/personal.nix];
      };
      "kclejeune@aarch64-linux" = mkHomeConfig {
        username = "kclejeune";
        system = "aarch64-linux";
        extraModules = [./profiles/home-manager/personal.nix];
      };
      "kclejeune@x86_64-darwin" = mkHomeConfig {
        username = "kclejeune";
        system = "x86_64-darwin";
        extraModules = [./profiles/home-manager/personal.nix];
      };
      "kclejeune@aarch64-darwin" = mkHomeConfig {
        username = "kclejeune";
        system = "aarch64-darwin";
        extraModules = [./profiles/home-manager/personal.nix];
      };
      "lejeukc1@x86_64-linux" = mkHomeConfig {
        username = "lejeukc1";
        system = "x86_64-linux";
        extraModules = [./profiles/home-manager/work.nix];
      };
    };

    devShells = eachSystemMap defaultSystems (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = builtins.attrValues self.overlays;
      };
    in {
      default = pkgs.devshell.mkShell {
        packages = [
          pkgs.nixfmt
          pkgs.pre-commit
          pkgs.rnix-lsp
          self.packages.${system}.pyEnv
          (treefmt-nix.lib.mkWrapper pkgs (import ./treefmt.nix))
        ];
        commands = [
          {
            name = "sysdo";
            package = self.packages.${system}.sysdo;
            category = "utilities";
            help = "perform actions on this repository";
          }
        ];
      };
    });

    packages = eachSystemMap defaultSystems (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = builtins.attrValues self.overlays;
      };
    in rec {
      pyEnv =
        pkgs.python3.withPackages
        (ps: with ps; [black typer colorama shellingham]);
      sysdo = pkgs.writeScriptBin "sysdo" ''
        #! ${pyEnv}/bin/python3
        ${builtins.readFile ./bin/do.py}
      '';
    });

    apps = eachSystemMap defaultSystems (system: rec {
      sysdo = {
        type = "app";
        program = "${self.packages.${system}.sysdo}/bin/sysdo";
      };
      default = sysdo;
    });

    overlays = {
      channels = final: prev: {
        # expose other channels via overlays
        stable = import inputs.stable {system = prev.system;};
        small = import inputs.small {system = prev.system;};
      };
      extraPackages = final: prev: {
        sysdo = self.packages.${prev.system}.sysdo;
        pyEnv = self.packages.${prev.system}.pyEnv;
      };
      devshell = inputs.devshell.overlay;
    };
  };
}
