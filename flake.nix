{
  description = "darwin system config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-20.09";
    unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, unstable, darwin, home-manager, ... }: {
    darwinConfigurations."Randall" = darwin.lib.darwinSystem {
      modules =
        [ ./darwin-configuration.nix home-manager.darwinModules.home-manager ];
      specialArgs = { inherit inputs nixpkgs unstable; };
    };
    nixosConfigurations."Phil" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules =
        [ ./configuration.nix home-manager.nixosModules.home-manager ];
      specialArgs = { inherit inputs nixpkgs unstable; };
    };
  };
}
