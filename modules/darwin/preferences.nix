{...}: {
  system.defaults = {
    universalaccess = {
      reduceMotion = true;
    };

    # login window settings
    loginwindow = {
      # disable guest account
      GuestEnabled = false;
      # show name instead of username
      SHOWFULLNAME = false;
    };

    # file viewer settings
    finder = {
      ShowPathbar = true;
      ShowStatusBar = true;
      DisableAllAnimations = true;
      AppleShowAllFiles = true;
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = true;
      FXPreferredViewStyle = "Nlsv";
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      WarnOnEmptyTrash = false;
    };

    desktopservices = {
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
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
    };

    # firewall settings
    alf = {
      # 0 = disabled 1 = enabled 2 = blocks all connections except for essential services
      globalstate = 1;
      loggingenabled = 0;
      stealthenabled = 1;
    };

    LaunchServices = {
      LSQuarantine = false;
    };

    # dock settings
    dock = {
      # auto show and hide dock
      autohide = true;
      # remove delay for showing dock
      autohide-delay = 0.0;
      # how fast is the dock showing animation
      autohide-time-modifier = 1.0;
      tilesize = 50;
      static-only = false;
      showhidden = false;
      show-recents = false;
      show-process-indicators = true;
      orientation = "bottom";
      mru-spaces = false;
    };

    NSGlobalDomain = {
      # allow key repeat
      ApplePressAndHoldEnabled = false;
      # delay before repeating keystrokes
      InitialKeyRepeat = 10;
      # delay between repeated keystrokes upon holding a key
      KeyRepeat = 1;
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "Automatic";
      # disable auto correct
      NSAutomaticSpellingCorrectionEnabled = false;
      AppleMeasurementUnits = "centimeters";
      # Enable full keyboard access for all controls
      # (e.g. enable Tab in modal dialogs)
      AppleKeyboardUIMode = 3;
      # disable OTT animated focus ring
      NSUseAnimatedFocusRing = false;
    };
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };
}
