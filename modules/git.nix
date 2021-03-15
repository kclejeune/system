{ config, lib, pkgs, ... }: {
  home.packages = [ pkgs.github-cli ];
  programs.git = {
    userName = "Kennan LeJeune";
    extraConfig = {
      http.sslVerify = true;
      pull.rebase = false;
    };
    aliases = {
      fix = "commit --amend --no-edit";
      oops = "reset HEAD~1";
    };
    delta.enable = true;
  };
}
