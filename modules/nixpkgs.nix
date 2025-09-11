{
  self,
  lib,
  ...
}: {
  nixpkgs = {
    config = import ./config.nix;
    overlays = [self.overlays.default];
  };

  home-manager.sharedModules = [
    {
      nix.enable = lib.mkForce true;
    }
  ];
  environment.etc."determinate/config.json".text = ''
    {
      "authentication": {
        "additionalNetrcSources": [
          "/etc/determinate/netrc"
        ]
      }
    }
  '';
}
