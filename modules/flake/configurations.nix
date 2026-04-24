{
  self,
  inputs,
  config,
  lib,
  ...
}:
let
  fp = config;

  defaultSystems =
    (lib.intersectLists lib.platforms.linux (lib.platforms.x86_64 ++ lib.platforms.aarch64))
    ++ (lib.intersectLists lib.platforms.aarch64 lib.platforms.darwin);
  darwinSystems = lib.intersectLists lib.platforms.aarch64 lib.platforms.darwin;

  homePrefix = system: if (lib.elem system darwinSystems) then "/Users" else "/home";

  mkDarwinConfig =
    {
      system ? "aarch64-darwin",
      nixpkgs ? inputs.nixpkgs,
      extraModules ? [ ],
    }:
    inputs.darwin.lib.darwinSystem {
      inherit system;
      modules = [
        inputs.determinate.darwinModules.default
        inputs.home-manager.darwinModules.home-manager
        fp.flake.darwinModules.default
      ] ++ extraModules;
      specialArgs = { inherit self inputs nixpkgs; };
    };

  mkNixosConfig =
    {
      system ? "x86_64-linux",
      nixpkgs ? inputs.nixos-unstable,
      hardwareModules,
      extraModules ? [ ],
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        inputs.determinate.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.disko.nixosModules.disko
        inputs.sops-nix.nixosModules.sops
        fp.flake.nixosModules.default
      ]
      ++ hardwareModules
      ++ extraModules;
      specialArgs = { inherit self inputs nixpkgs; };
    };

  mkHomeConfig =
    {
      username,
      system ? "x86_64-linux",
      nixpkgs ? inputs.nixpkgs,
      extraModules ? [ ],
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnsupportedSystem = true;
          allowUnfree = true;
          allowBroken = false;
        };
        overlays = [ self.overlays.default ];
      };
      extraSpecialArgs = { inherit self inputs nixpkgs; };
      modules = [
        fp.flake.homeModules.default
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
      ]
      ++ extraModules;
    };
in
{
  flake = {
    darwinConfigurations = lib.mergeAttrsList (
      lib.map (system: {
        "kclejeune@${system}" = mkDarwinConfig {
          inherit system;
          extraModules = [
            fp.flake.darwinModules.profile-personal
            fp.flake.darwinModules.apps
          ];
        };
      }) darwinSystems
    );

    nixosConfigurations = {
      phil = mkNixosConfig {
        system = "x86_64-linux";
        hardwareModules = [
          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
          fp.flake.nixosModules.hardware-thinkpad-t460s
        ];
        extraModules = [
          fp.flake.nixosModules.desktop
          fp.flake.nixosModules.profile-personal
          { networking.hostName = "phil"; }
        ];
      };
      wally = mkNixosConfig {
        system = "x86_64-linux";
        hardwareModules = [
          inputs.nixos-hardware.nixosModules.dell-precision-5570
          fp.flake.nixosModules.hardware-precision-5570
        ];
        extraModules = [
          fp.flake.nixosModules.desktop
          fp.flake.nixosModules.profile-personal
          { networking.hostName = "wally"; }
        ];
      };
      gateway = mkNixosConfig {
        system = "x86_64-linux";
        hardwareModules = [
          fp.flake.nixosModules.hetzner
        ];
        extraModules = [
          fp.flake.nixosModules.gateway
          fp.flake.nixosModules.profile-personal
        ];
      };
    };

    homeConfigurations = lib.mergeAttrsList (
      lib.map (system: {
        "kclejeune@${system}" = mkHomeConfig {
          inherit system;
          username = "kclejeune";
          extraModules = [ fp.flake.homeModules.profile-personal ];
        };
      }) defaultSystems
    );
  };
}
