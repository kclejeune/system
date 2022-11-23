{
  config,
  lib,
  pkgs,
  ...
}: {
  user.name = "lejeukc1";
  hm = {imports = [./home-manager/work.nix];};

  security.pki.certificateFiles = ["${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" "/etc/certs.d/apl.pem"];
}
