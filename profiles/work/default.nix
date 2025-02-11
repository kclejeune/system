{
  self,
  pkgs,
  ...
}: {
  user.name = "klejeune";
  hm = {imports = [./home-manager];};
  security.pki.installCACerts = false;
  nix.package = pkgs.nix_2_18;
  nixpkgs.overlays = [
    self.overlays.default
    self.overlays.work
  ];
}
