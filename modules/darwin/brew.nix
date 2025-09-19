{...}: {
  homebrew = {
    enable = true;
    global = {
      brewfile = true;
    };
    brews = [];

    taps = [
      "1password/tap"
      "beeftornado/rmtree"
      "cirruslabs/cli"
      "coder/coder"
      "earthly/earthly"
      "hcavarsan/kftray"
      "koekeishiya/formulae"
      "kscripting/tap"
      "nikitabobko/tap"
    ];
    casks = [
      "1password-cli"
      "aerospace"
      "devpod"
      "ghostty"
      "hammerspoon"
      "httpie-desktop"
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
