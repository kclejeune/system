{
  description = "darwin system config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-20.09";
    stable.url = "github:nixos/nixpkgs/nixos-20.09";
    flake-utils.url = "github:numtide/flake-utils";
    darwin = {
      url = "github:kclejeune/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in { devShell = import ./shell.nix { inherit pkgs; }; }) // {
        darwinConfigurations = {
          Randall = darwin.lib.darwinSystem {
            modules = [
              ./darwin-configuration.nix
              home-manager.darwinModules.home-manager
            ];
            specialArgs = { inherit inputs nixpkgs; };
          };
        };
        nixosConfigurations = {
          Phil = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules =
              [ ./configuration.nix home-manager.nixosModules.home-manager ];
            specialArgs = { inherit inputs nixpkgs; };
          };
        };
      };
}
