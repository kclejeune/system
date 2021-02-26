{ config, lib, pkgs, ... }: {
  user.name = "lejeukc1";
  hm = { imports = [ ./home-manager/work.nix ]; };
  homebrew.enable = true;

  security.pki.certificateFiles = [
    "${config.user.home}/root-cert.cer"
    "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
  ];
}
