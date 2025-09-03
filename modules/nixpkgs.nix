{
  inputs,
  lib,
  pkgs,
  self,
  ...
}: {
  nixpkgs = {
    config = import ./config.nix;
    overlays = [self.overlays.default];
  };

  home-manager.sharedModules = [
    {
      nix.enable = lib.mkForce true;
      home.packages = [inputs.determinate.packages.${pkgs.system}.default];
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
