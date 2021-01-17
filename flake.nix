{
  description = "darwin system config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    stable.url = "github:nixos/nixpkgs/nixos-20.09";
    flake-utils.url = "github:numtide/flake-utils";
    darwin = {
      url = "github:kclejeune/nix-darwin/brew-bundle";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, flake-utils, ... }:
    {
      darwinConfigurations = {
        randall = darwin.lib.darwinSystem {
          modules = [
            home-manager.darwinModules.home-manager
            ./devices/darwin/randall
          ];
          specialArgs = { inherit inputs nixpkgs; };
        };
        work = darwin.lib.darwinSystem {
          modules =
            [ home-manager.darwinModules.home-manager ./devices/darwin/work ];
          specialArgs = { inherit inputs nixpkgs; };
        };
      };
      nixosConfigurations = {
        phil = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules =
            [ ./devices/nixos/phil home-manager.nixosModules.home-manager ];
          specialArgs = { inherit inputs nixpkgs; };
        };
      };
    } //
    # add a devShell to this flake
    (flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in { devShell = import ./shell.nix { inherit pkgs; }; }));
}
