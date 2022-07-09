{ config, lib, pkgs, ... }: {
  homebrew = {
    casks = [
      "discord"
      "dropbox"
      "google-drive"
      "keybase"
      "messenger"
      "notion"
      "signal"
      "slack"
    ];
    masApps = { };
  };
}
