{
  self,
  lib,
  config,
  ...
}:
{
  nixpkgs = {
    config = import ./config.nix;
    overlays = [ self.overlays.default ];
  };

  home-manager.sharedModules = [
    {
      nix.enable = lib.mkForce true;
      nix.package = lib.mkForce config.nix.package;
    }
  ];
}
