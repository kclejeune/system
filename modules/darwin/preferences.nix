_: {
  flake.darwinModules.preferences = _: {
    system.defaults = {
      # login window settings
      loginwindow = {
        # disable guest account
        GuestEnabled = false;
        # show name instead of username
        SHOWFULLNAME = false;
      };

      # file viewer settings
      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        FXEnableExtensionChangeWarning = true;
        _FXShowPosixPathInTitle = true;
        _FXSortFoldersFirstOnDesktop = true;
      };

      # trackpad settings
      trackpad = {
        # silent clicking = 0, default = 1
        ActuationStrength = 0;
        # enable tap to click
        Clicking = true;
        # firmness level, 0 = lightest, 2 = heaviest
        FirstClickThreshold = 1;
        # firmness level for force touch
        SecondClickThreshold = 1;
        # don't allow positional right click
        TrackpadRightClick = false;
      };

      spaces.spans-displays = true;

      # dock settings
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
