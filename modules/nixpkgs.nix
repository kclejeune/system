{
  lib,
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
      # assume this already exists in the environment...maybe
      # home.packages = [inputs.determinate.packages.${pkgs.system}.default];
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
