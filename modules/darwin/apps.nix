{ config, lib, pkgs, ... }: {
  imports = [ ./apps-minimal.nix ];
  homebrew = {
    casks = [
      "fork"
      "gpg-suite"
      "iina"
      "jetbrains-toolbox"
      "keybase"
      "skim"
      "syncthing"
      "zoom"
    ];
    masApps = { };
  };
}
