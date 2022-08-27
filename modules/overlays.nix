{ self, ... }: {
  nixpkgs.overlays = builtins.attrValues self.overlays;
}
