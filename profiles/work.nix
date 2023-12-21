{pkgs, ...}: {
  user.name = "ldm";
  hm = {imports = [./home-manager/work.nix];};

  security.pki.certificateFiles = ["${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" "/etc/certs.d/apl.pem" "/etc/certs.d/dod-chain.pem"];
}
