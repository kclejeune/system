{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      color = "always";
    };
  };
}
