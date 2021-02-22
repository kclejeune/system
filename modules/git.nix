{ config, lib, pkgs, ... }: {
  home.packages = [ pkgs.github-cli ];
  programs.git = {
    userName = "Kennan LeJeune";
    extraConfig = {
      http.sslVerify = true;
      pull.rebase = false;
    };
  };
}
