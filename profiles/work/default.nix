{...}: {
  user.name = "klejeune";
  hm = {
    imports = [./home-manager];
  };
  security.pki.installCACerts = false;
}
