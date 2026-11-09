_: {
  flake.darwinModules.brew = _: {
    homebrew = {
      enable = true;
      global.brewfile = true;
      # Homebrew 6 requires trusting third-party taps, but activation runs
      # `brew bundle` under sudo with a clean env, so an interactive `brew trust`
      # can't be relied on.
      onActivation.extraEnv.HOMEBREW_NO_REQUIRE_TAP_TRUST = "1";
      brews = [
        "ca-certificates"
        "openssl@3"
      ];

      taps = [
        "1password/tap"
        "anomalyco/tap"
        "beeftornado/rmtree"
        "nikitabobko/tap"
        "sheprd-labs/tap"
        "stablyai/orca"
      ];
      casks = [
        "1password-cli"
        "aerospace"
        "anomalyco/tap/hex"
        "bartender"
        "ghostty"
        "hammerspoon"
        "herdr-app"
        "sheprd"
        "httpie-desktop"
        "jetbrains-toolbox"
        "kitty"
        "obsidian"
        "orbstack"
        "raycast"
        "stats"
        "utm"
        "visual-studio-code"
        "zed"
        "zotero"
      ];
    };
  };
}
