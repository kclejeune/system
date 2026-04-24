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
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      inputs.sops-nix.nixosModules.sops

      config.flake.nixosModules.default

      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
      config.flake.nixosModules.hardware-thinkpad-t460s

      config.flake.nixosModules.desktop
      config.flake.nixosModules.profile-personal

      { networking.hostName = "phil"; }
    ];
  };
}
