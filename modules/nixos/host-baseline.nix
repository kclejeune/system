{ inputs, ... }:
{
  # Cross-host third-party modules go here rather than in each host.
  flake.nixosModules.host-baseline = _: {
    imports = [
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.disko.nixosModules.disko
      inputs.sops-nix.nixosModules.sops
    ];
  };
}
