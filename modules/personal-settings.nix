{ config, pkgs, ... }: {
  home-manager.users.kclejeune = {
    home.packages = [ pkgs.cacert ];
    programs.git = {
      enable = true;
      lfs.enable = true;
      userEmail = "kennan@case.edu";
      userName = "Kennan LeJeune";
      signing = {
        key = "kennan@case.edu";
        signByDefault = true;
      };
      aliases = {
        ignore = "!gi() { curl -sL https://www.toptal.com/developers/gitignore/api/$@ ;}; gi";
      };
    };
  };
}
