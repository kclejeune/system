_: {
  flake.darwinModules.brew = _: {
    homebrew = {
      enable = true;
      global.brewfile = true;
      # Homebrew 6.0 requires explicit trust for non-official taps. Activation
      # runs `brew bundle` under sudo with a sanitized env, so an interactive
      # `brew trust` (and tap redirects that re-invalidate it) can't be relied
      # on. Allow our declared taps by opting out of the trust requirement here.
      onActivation.extraEnv.HOMEBREW_NO_REQUIRE_TAP_TRUST = "1";
      brews = [
        "ca-certificates"
        "openssl@3"
      ];

      taps = [
        "1password/tap"
        "beeftornado/rmtree"
        "koekeishiya/formulae"
        "nikitabobko/tap"
      ];
      casks = [
        "1password-cli"
        "aerospace"
        "bartender"
        "ghostty"
        "hammerspoon"
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
