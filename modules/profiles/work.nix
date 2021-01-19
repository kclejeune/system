{ config, lib, pkgs, ... }: {
  user.name = "lejeukc1";
  hm = {
    home.packages = [ pkgs.cacert ];
    programs.git = {
      enable = true;
      lfs.enable = true;
      package = pkgs.git;
      userEmail = "kennan.lejeune@jhuapl.edu";
      userName = "Kennan LeJeune";
      extraConfig = { http.sslVerify = true; };
    };
  };

  security.pki.certificateFiles = [
    "${config.user.home}/root-cert.cer"
    "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
  ];
}
