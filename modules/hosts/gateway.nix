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
      config.flake.nixosModules.host-baseline
      config.flake.nixosModules.default

      config.flake.nixosModules.hetzner

      config.flake.nixosModules.gateway
      config.flake.nixosModules.profile-personal
    ];
  };
}
