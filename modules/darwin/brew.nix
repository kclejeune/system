{...}: {
  homebrew = {
    enable = true;
    global = {brewfile = true;};
    brews = [
      {
        name = "ollama";
        start_service = true;
        restart_service = "changed";
      }
    ];

    taps = [
      "1password/tap"
      "beeftornado/brew-rmtree"
      "cirruslabs/cli"
      "earthly/earthly"
      "hcavarsan/kftray"
      "homebrew/bundle"
      "homebrew/services"
      "koekeishiya/formulae"
      "yqna/tap"
    ];
    casks = [
      "1password"
      "1password-cli"
      "aerospace"
      "firefox@developer-edition"
      "google-chrome"
      "hammerspoon"
      "httpie"
      "iina"
      "jetbrains-toolbox"
      "jnv"
      "jordanbaird-ice"
      "kftray"
      "kitty"
      "kscript"
      "obsidian"
      "orbstack"
      "raycast"
      "stats"
      "utm"
      "visual-studio-code"
      "zed@preview"
      "zotero"
    ];
  };
}
