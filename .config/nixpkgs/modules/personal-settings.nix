{ config, pkgs, ... }: {
  programs.git = {
    enable = true;
    userEmail = "kennan@case.edu";
    userName = "Kennan LeJeune";
    signing = {
      key = "kennan@case.edu";
      signByDefault = true;
    };
  };
  programs.gh = {
    enable = true;
    gitProtocol = "ssh";
  };
}
