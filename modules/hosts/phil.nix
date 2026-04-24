{
  self,
  inputs,
  config,
  ...
}:
{
  flake.nixosConfigurations.phil = inputs.nixos-unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit self inputs;
      nixpkgs = inputs.nixos-unstable;
    };
    modules = [
      config.flake.nixosModules.host-baseline
      config.flake.nixosModules.default

      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
      config.flake.nixosModules.hardware-thinkpad-t460s

      config.flake.nixosModules.desktop
      config.flake.nixosModules.profile-personal

      { networking.hostName = "phil"; }
    ];
  };
}
