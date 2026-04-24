{
  self,
  inputs,
  config,
  ...
}:
{
  flake.nixosConfigurations.gateway = inputs.nixos-unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit self inputs;
      nixpkgs = inputs.nixos-unstable;
    };
    modules = [
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      inputs.sops-nix.nixosModules.sops

      config.flake.nixosModules.default

      config.flake.nixosModules.hetzner

      config.flake.nixosModules.gateway
      config.flake.nixosModules.profile-personal
    ];
  };
}
