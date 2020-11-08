{ config, pkgs, ... }: {
  home.packages = [ pkgs.cacert ];
  programs.git = {
    enable = true;
    package = pkgs.git;
    userEmail = "kennan.lejeune@jhuapl.edu";
    userName = "Kennan LeJeune";
    extraConfig = { http.sslVerify = true; };
  };
}
