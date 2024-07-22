{...}: {
  homebrew = {
    enable = true;
    global = {
      brewfile = true;
    };
    brews = [
      "earthly"
      {
        name = "ollama";
        start_service = true;
        restart_service = "changed";
      }
    ];

    taps = [
      "1password/tap"
      "beeftornado/rmtree"
      "cloudflare/cloudflare"
      "earthly/earthly"
      "homebrew/bundle"
      "homebrew/services"
      "koekeishiya/formulae"
      "teamookla/speedtest"
    ];
    casks = [
      "1password"
      "1password-cli"
      "alt-tab"
      "appcleaner"
      "bartender"
      "docker"
      "firefox@developer-edition"
      "fork"
      "google-chrome"
      "gpg-suite"
      "hammerspoon"
      "hot"
      "iina"
      "jetbrains-toolbox"
      "kitty"
      "obsidian"
      "raycast"
      # "rancher"
      "stats"
      "utm"
      "visual-studio-code"
      "zotero"
    ];
  };
}
