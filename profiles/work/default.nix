{pkgs, ...}: {
  user.name = "klejeune";
  hm = {
    imports = [./home-manager];
  };
  security.pki.installCACerts = false;
  nix.package = pkgs.nix_2_18;
}
