{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.git = {
    userEmail = "kennan@case.edu";
    userName = "Kennan LeJeune";
    signing = {
      key = "kennan@case.edu";
      signByDefault = true;
    };
  };
}
