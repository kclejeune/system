{pkgs, ...}: let
  SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
in {
  home.packages = with pkgs; [
    cacert
    kubectl
    kubernetes-helm
    kustomize
    vault-bin
  ];
  home.sessionVariables = {
    inherit SSL_CERT_FILE;
    NIX_SSL_CERT_FILE = SSL_CERT_FILE;
    REQUESTS_CA_BUNDLE = SSL_CERT_FILE;
    PIP_CERT = SSL_CERT_FILE;
    GIT_SSL_CAINFO = SSL_CERT_FILE;
    NODE_EXTRA_CA_CERTS = SSL_CERT_FILE;
  };
  programs.git = {
    enable = true;
    lfs.enable = true;
    userEmail = "kennan.lejeune@jhuapl.edu";
    userName = "Kennan LeJeune";
    extraConfig = {
      http.sslVerify = true;
      http.sslCAInfo = SSL_CERT_FILE;
    };
  };
}
