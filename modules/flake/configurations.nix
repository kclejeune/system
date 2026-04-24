{
  self,
  inputs,
  lib,
  ...
}:
let
  defaultSystems =
    (lib.intersectLists lib.platforms.linux (lib.platforms.x86_64 ++ lib.platforms.aarch64))
    ++ (lib.intersectLists lib.platforms.aarch64 lib.platforms.darwin);
  darwinSystems = lib.intersectLists lib.platforms.aarch64 lib.platforms.darwin;

  homePrefix = system: if (lib.elem system darwinSystems) then "/Users" else "/home";

  mkDarwinConfig =
    {
      system ? "aarch64-darwin",
      nixpkgs ? inputs.nixpkgs,
      baseModules ? [
        inputs.determinate.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        ../darwin
      ],
      extraModules ? [ ],
    }:
    inputs.darwin.lib.darwinSystem {
      inherit system;
      modules = baseModules ++ extraModules;
      specialArgs = { inherit self inputs nixpkgs; };
    };

  mkNixosConfig =
    {
      system ? "x86_64-linux",
      nixpkgs ? inputs.nixos-unstable,
      hardwareModules,
      baseModules ? [
        inputs.determinate.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.disko.nixosModules.disko
        inputs.sops-nix.nixosModules.sops
        ../nixos
      ],
      extraModules ? [ ],
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = baseModules ++ hardwareModules ++ extraModules;
      specialArgs = { inherit self inputs nixpkgs; };
    };

  mkHomeConfig =
    {
      username,
      system ? "x86_64-linux",
      nixpkgs ? inputs.nixpkgs,
      baseModules ? [
        ../home-manager
        (
          { pkgs, ... }:
          {
            nix.package = pkgs.nix;
            home = {
              inherit username;
              homeDirectory = "${homePrefix system}/${username}";
            };
          }
        )
      ],
      extraModules ? [ ],
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        config = import ../config.nix;
        overlays = [ self.overlays.default ];
      };
      extraSpecialArgs = { inherit self inputs nixpkgs; };
      modules = baseModules ++ extraModules;
    };
in
{
  flake = {
    nixosModules = {
      default = ../nixos;
      gnome = ../nixos/gnome.nix;
      hyprland = ../nixos/hyprland.nix;
      desktop = ../nixos/desktop.nix;
      desktopBase = ../nixos/desktop-base.nix;
      hetzner = ../nixos/hetzner.nix;
      gateway = ../nixos/gateway.nix;
      keybase = ../nixos/keybase.nix;
    };

    darwinModules = {
      default = ../darwin;
      apps = ../darwin/apps.nix;
    };

    homeModules = {
      default = ../home-manager;
      onepassword = ../home-manager/1password.nix;
    };

    darwinConfigurations = lib.mergeAttrsList (
      lib.map (system: {
        "kclejeune@${system}" = mkDarwinConfig {
          inherit system;
          extraModules = [
            ../../profiles/personal
            ../darwin/apps.nix
          ];
        };
      }) darwinSystems
    );

    nixosConfigurations = {
      phil = mkNixosConfig {
        system = "x86_64-linux";
        hardwareModules = [
          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
          ../nixos/hardware/thinkpad-t460s.nix
        ];
        extraModules = [
          ../nixos/desktop.nix
          ../../profiles/personal
          { networking.hostName = "phil"; }
        ];
      };
      wally = mkNixosConfig {
        system = "x86_64-linux";
        hardwareModules = [
          inputs.nixos-hardware.nixosModules.dell-precision-5570
          ../nixos/hardware/precision-5570.nix
        ];
        extraModules = [
          ../nixos/desktop.nix
          ../../profiles/personal
          { networking.hostName = "wally"; }
        ];
      };
      gateway = mkNixosConfig {
        system = "x86_64-linux";
        hardwareModules = [
          ../nixos/hetzner.nix
        ];
        extraModules = [
          ../nixos/gateway.nix
          ../../profiles/personal
        ];
      };
    };

    homeConfigurations = lib.mergeAttrsList (
      lib.map (system: {
        "kclejeune@${system}" = mkHomeConfig {
          inherit system;
          username = "kclejeune";
          extraModules = [ ../../profiles/personal/home-manager ];
        };
      }) defaultSystems
    );
  };
}
