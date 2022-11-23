{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.ssh = {
    enable = true;
    includes = ["config.d/*"];
    forwardAgent = true;
  };
}
