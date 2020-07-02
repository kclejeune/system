{ config, pkgs, ... }: {
  programs.git = {
    enable = true;
    package = pkgs.git;
    userEmail = "kennan@case.edu";
    userName = "Kennan LeJeune";
    signing = {
      key = "kennan@case.edu";
      signByDefault = false;
    };
  };
}
