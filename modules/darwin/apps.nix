_: {
  flake.darwinModules.apps = _: {
    homebrew = {
      casks = [
        "1password"
        "brave-browser"
        "discord"
        "dropbox"
        "firefox@developer-edition"
        "google-chrome"
        "google-drive"
        "keybase"
        "notion"
        "signal"
        "slack"
      ];
      masApps = { };
    };
  };
}
