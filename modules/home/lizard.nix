_: {
  flake.homeModules.lizard =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.lizard-cli ];
    };
}
