{pkgs, ...}: {
  user.name = "klejeune";
  hm = {
    imports = [./home-manager];
  };
  security.pki.installCACerts = false;
  nix.package = pkgs.nixVersions.nix_2_18;
}
