{ config, lib, pkgs, ... }: {
  imports = [ ./apps-minimal.nix ];
  homebrew = {
    casks = [
      "displaperture"
      "fork"
      "gpg-suite"
      "iina"
      "jetbrains-toolbox"
      "keybase"
      "rectangle"
      "skim"
      "syncthing"
      "zoom"
    ];
    masApps = { };
  };
}
