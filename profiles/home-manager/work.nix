{ config, lib, pkgs, ... }: {
  home.packages = [ pkgs.cacert pkgs.vault-bin ];
  home.sessionVariables = rec {
    NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    SSL_CERT_FILE = NIX_SSL_CERT_FILE;
    REQUESTS_CA_BUNDLE = NIX_SSL_CERT_FILE;
    PIP_CERT = NIX_SSL_CERT_FILE;
    GIT_SSL_CAINFO = NIX_SSL_CERT_FILE;
    NODE_EXTRA_CA_CERTS = NIX_SSL_CERT_FILE;
  };
  programs.git = {
    enable = true;
    lfs.enable = true;
    package = pkgs.git;
    userEmail = "kennan.lejeune@jhuapl.edu";
    userName = "Kennan LeJeune";
    extraConfig = {
      http.sslVerify = true;
      http.sslCAInfo = "/etc/ssl/certs/ca-certificates.crt";
    };
  };
}
