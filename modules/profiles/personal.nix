{ config, lib, pkgs, ... }: {
  user.name = "kclejeune";
  hm = {
    programs.git = {
      userEmail = "kennan@case.edu";
      userName = "Kennan LeJeune";
      signing = {
        key = "kennan@case.edu";
        signByDefault = true;
      };
    };
  };
}
