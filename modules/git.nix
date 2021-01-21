{ config, lib, pkgs, ... }: {
  programs.git = {
    userName = "Kennan LeJeune";
    extraConfig = {
      http.sslVerify = true;
      pull.rebase = false;
    };
  };
}
