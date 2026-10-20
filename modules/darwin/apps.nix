_: {
  flake.darwinModules.apps = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      chatgpt
      claude-desktop
    ];

    homebrew = {
      casks = [
        "1password"
        "brave-browser"
        "discord"
        "dropbox"
        "firefox"
        "google-chrome"
        "google-drive"
        "notion"
        "signal"
        "slack"
      ];
      masApps = { };
    };
  };
}
