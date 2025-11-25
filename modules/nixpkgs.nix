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
  environment.etc."determinate/config.json".text = builtins.toJSON {
    authentication.additionalNetrcSources = ["/etc/determinate/netrc"];
    garbageCollector.strategy = "automatic";
    builder = {
      state = "enabled";
      memoryBytes = 8589934592;
      cpuCount = 1;
    };
  };
}
