_: {
  flake.darwinModules.preferences = _: {
    system.defaults = {
      loginwindow = {
        GuestEnabled = false;
        SHOWFULLNAME = false;
      };

      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        FXEnableExtensionChangeWarning = true;
        _FXShowPosixPathInTitle = true;
        _FXSortFoldersFirstOnDesktop = true;
      };

      trackpad = {
        # 0 = silent clicking, 1 = default
        ActuationStrength = 0;
        Clicking = true;
        # 0 = lightest, 2 = heaviest
        FirstClickThreshold = 1;
        SecondClickThreshold = 1;
        TrackpadRightClick = false;
      };

      spaces.spans-displays = true;

      dock = {
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 1.0;
        tilesize = 50;
        static-only = false;
        showhidden = false;
        show-recents = false;
        show-process-indicators = true;
        orientation = "bottom";
        mru-spaces = false;
        expose-group-apps = true;
      };

      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 10;
        KeyRepeat = 1;
        AppleShowAllExtensions = true;
        AppleShowScrollBars = "Automatic";
      };
    };

    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
  };
}
