{...}: {
  homebrew = {
    enable = true;
    global = {brewfile = true;};
    brews = [
      "jnv"
      "kscript"
      {
        name = "ollama";
        start_service = true;
        restart_service = "changed";
      }
    ];

    taps = [
      "1password/tap"
      "beeftornado/rmtree"
      "cirruslabs/cli"
      "coder/coder"
      "earthly/earthly"
      "hcavarsan/kftray"
      "homebrew/bundle"
      "homebrew/services"
      "koekeishiya/formulae"
      "kscripting/tap"
    ];
    casks = [
      "1password"
      "1password-cli"
      "aerospace"
      "devpod"
      "firefox@developer-edition"
      "ghostty"
      "google-chrome"
      "hammerspoon"
      "httpie"
      "iina"
      "jetbrains-toolbox"
      "jordanbaird-ice"
      "kftray"
      "kitty"
      "obsidian"
      "orbstack"
      "raycast"
      "stats"
      "utm"
      "visual-studio-code"
      "vscodium"
      "zed@preview"
      "zotero"
    ];
  };
}
