{...}: {
  user.name = "lejeukc1";
  hm = {imports = [./home-manager/work.nix];};
  security.pki.installCACerts = false;
}
