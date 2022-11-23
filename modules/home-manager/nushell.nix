{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nushell = {
    enable = true;
  };
}
