{ config, pkgs, ... }: {
  system.defaults = {
    trackpad = {
      # silent clicking = 0, default = 1
      ActuationStrength = 0;
      # enable tap to click
      Clicking = true;
      # firmness level, 0 = lightest, 2 = heaviest
      FirstClickThreshold = 1;
      # firmness level for force touch
      SecondClickThreshold = 2;
      # don't allow positional right click
      TrackpadRightClick = false;
      # three finger drag for space switching
      TrackpadThreeFingerDrag = true;
    };
    # firewall settings
    alf = {
      # 0 = disabled 1 = enabled 2 = blocks all connections except for essential services
      globalstate = 1;
      loggingenabled = 0;
      stealthenabled = 1;
    };

    dock = {
      # auto show and hide dock
      autohide = true;
      # remove delay for showing dock
      autohide-delay = "0.0";
      # how fast is the dock showing animation
      autohide-time-modifier = "1.0";
      tilesize = 50;
      static-only = false;
      showhidden = false;
      show-recents = false;
      show-process-indicators = true;
      orientation = "bottom";
      mru-spaces = false;
    };

    # NSGlobalDomain.com.apple.sound.beep = {
    #   feedback = 0;
    #   volume = 0.0;
    # };

    NSGlobalDomain = {
            # allow key repeat
      ApplePressAndHoldEnabled = false;
      # delay before repeating keystrokes
      InitialKeyRepeat = 15;
      # delay between repeated keystrokes upon holding a key
      KeyRepeat = 2;
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "Automatic";
    };

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
  };

}
