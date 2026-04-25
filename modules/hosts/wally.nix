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
      config.flake.nixosModules.host-baseline
      config.flake.nixosModules.default

      inputs.nixos-hardware.nixosModules.dell-precision-5570
      config.flake.nixosModules.hardware-precision-5570

      config.flake.nixosModules.desktop
      config.flake.nixosModules.personal-apps
      config.flake.nixosModules.profile-personal

      { networking.hostName = "wally"; }
    ];
  };
}
