{
  self,
  inputs,
  config,
  ...
}:
{
  flake.nixosConfigurations.wally = inputs.nixos-unstable.lib.nixosSystem {
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

      inputs.nixos-hardware.nixosModules.dell-precision-5570
      config.flake.nixosModules.hardware-precision-5570

      config.flake.nixosModules.desktop
      config.flake.nixosModules.profile-personal

      { networking.hostName = "wally"; }
    ];
  };
}
