{self, ...}: {
  nixpkgs = {
    config = import ./config.nix;
    overlays = [self.overlays.default];
  };
}
