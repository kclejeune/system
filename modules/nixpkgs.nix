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
  environment.etc."determinate/config.json".text = builtins.toJSON {
    authentication.additionalNetrcSources = [ "/etc/determinate/netrc" ];
    garbageCollector.strategy = "automatic";
    builder = {
      state = "enabled";
      memoryBytes = 8589934592;
      cpuCount = 1;
    };
  };
}
