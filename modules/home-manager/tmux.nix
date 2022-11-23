{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.tmux = {
    enable = true;
  };
}
