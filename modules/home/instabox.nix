_: {
  flake.homeModules.instabox =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.instabox ];
    };
}
