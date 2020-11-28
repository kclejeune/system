{ config, pkgs, ... }: {
  home.packages = [ pkgs.cacert ];
  programs.git = {
    enable = true;
    userEmail = "kennan.lejeune@jhuapl.edu";
    userName = "Kennan LeJeune";
    extraConfig = { http.sslVerify = true; };
  };
}
