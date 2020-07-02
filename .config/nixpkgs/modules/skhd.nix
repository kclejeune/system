{ config, lib, pkgs, ... }: {
  services.skhd = {
    enable = true;
    package = pkgs.skhd;
    skhdConfig = builtins.readFile ../../skhd/skhdrc;
  };
}
