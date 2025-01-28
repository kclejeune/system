{...}: {
  user.name = "klejeune";
  hm = {imports = [./home-manager/work.nix];};
  security.pki.installCACerts = false;
}
