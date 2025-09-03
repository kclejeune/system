{
  inputs,
  lib,
  pkgs,
  self,
  ...
}: let
  settings = {
  };
in lib.mkMerge [
    {
      nixpkgs = {
        config = import ./config.nix;
        overlays = [self.overlays.default];
      };
    }
    (lib.mkIf (config.nix.enable) {
      nix.settings = settings;
    })
    (lib.mkIf (!config.nix.enable) {
      determinate-nix.customSettings = settings;
      nix.package = inputs.determinate.inputs.nix.packages.${pkgs.system}.default;
      home-manager.sharedModules = [{
        nix.enable = lib.mkForce true;
        home.packages = [inputs.determinate.packages.${pkgs.system}.default];
      }];
      environment.etc."determinate/config.json".text = ''
        {
          "authentication": {
            "additionalNetrcSources": [
              "/etc/determinate/netrc"
            ]
          }
        }
      '';
    })
  ]
