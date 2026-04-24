{ inputs, ... }:
{
  # Aggregator for the third-party flake modules every NixOS host in this
  # repo pulls in: Determinate Nix, home-manager, disko, sops-nix. Hosts
  # then layer on their own hardware + profile + feature modules.
  flake.nixosModules.host-baseline = _: {
    imports = [
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      inputs.sops-nix.nixosModules.sops
    ];
  };
}
