{...}: {
  system.defaults = {
    #
    # `man configuration.nix` on mac is useful in seeing available options
    # `defaults read -g` on mac is useful to see current settings
    LaunchServices = {
      # quarantine downloads until approved
      LSQuarantine = true;
    };
    # login window settings
    loginwindow = {
      # disable guest account
      GuestEnabled = false;
      # show name instead of username
      SHOWFULLNAME = false;
      # Disables the ability for a user to access the console by typing “>console” for a username at the login window.
      DisableConsoleAccess = true;
    };

    # file viewer settings
    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      QuitMenuItem = true;
      _FXShowPosixPathInTitle = true;
      # Use list view in all Finder windows by default
      FXPreferredViewStyle = "Nlsv";
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    # trackpad settings
    trackpad = {
      # silent clicking = 0, default = 1
      ActuationStrength = 0;
      # enable tap to click
      Clicking = true;
      Dragging = true; # tap and a half to drag
      # three finger click and drag
      TrackpadThreeFingerDrag = true;
    };

    # firewall settings
    alf = {
      # 0 = disabled 1 = enabled 2 = blocks all connections except for essential services
      globalstate = 1;
      loggingenabled = 0;
      stealthenabled = 1;
    };

    spaces.spans-displays = false; # separate spaces on each display

    # dock settings
    dock = {
      # auto show and hide dock
      autohide = true;
      # remove delay for showing dock
      autohide-delay = 0.0;
      # how fast is the dock showing animation
      autohide-time-modifier = 0.2;
      expose-animation-duration = 0.2;
      tilesize = 48;
      launchanim = false;
      static-only = false;
      showhidden = true;
      show-recents = false;
      show-process-indicators = true;
      orientation = "bottom";
      mru-spaces = false;
      # mouse in top right corner will (5) start screensaver
      wvous-tr-corner = 5;
    };

    # universalaccess = {
    # get rid of extra transparency in menu bar and elsewhere
    # reduceTransparency = false;
    # };

    NSGlobalDomain = {
      # 2 = heavy font smoothing; if text looks blurry, back this down to 1
      AppleFontSmoothing = 2;
      AppleShowAllExtensions = true;
      # Dark mode
      AppleInterfaceStyle = "Dark";
      # auto switch between light/dark mode
      AppleInterfaceStyleSwitchesAutomatically = false;
      "com.apple.sound.beep.feedback" = 1;
      "com.apple.sound.beep.volume" = 0.606531; # 50%
      "com.apple.mouse.tapBehavior" = 1; # tap to click
      "com.apple.swipescrolldirection" = true; # "natural" scrolling
      "com.apple.keyboard.fnState" = true;
      "com.apple.springing.enabled" = false;
      "com.apple.trackpad.scaling" = 3.0; # fast
      "com.apple.trackpad.enableSecondaryClick" = true;
      # enable full keyboard control
      # (e.g. enable Tab in modal dialogs)
      AppleKeyboardUIMode = 3;
      AppleTemperatureUnit = "Fahrenheit";
      AppleMeasurementUnits = "Inches";
      # no popup menus when holding down letters
      ApplePressAndHoldEnabled = false;
      # delay before repeating keystrokes
      InitialKeyRepeat = 10;
      # delay between repeated keystrokes upon holding a key
      KeyRepeat = 1;
      AppleShowScrollBars = "Automatic";
      NSScrollAnimationEnabled = true; # smooth scrolling
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      # no automatic smart quotes
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      # speed up animation on open/save boxes (default:0.2)
      NSWindowResizeTime = 0.001;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
    };
    CustomSystemPreferences = {};
    CustomUserPreferences = {
      NSGlobalDomain = {
        # Add a context menu item for showing the Web Inspector in web views
        WebKitDeveloperExtras = true;
      };
      "com.apple.finder" = {
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = true;
        ShowMountedServersOnDesktop = true;
        ShowRemovableMediaOnDesktop = true;
        _FXSortFoldersFirst = true;
        # When performing a search, search the current folder by default
        FXDefaultSearchScope = "SCcf";
      };
      "com.apple.desktopservices" = {
        # Avoid creating .DS_Store files on network or USB volumes
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.screensaver" = {
        # Require password immediately after sleep or screen saver begins
        askForPassword = 1;
        askForPasswordDelay = 0;
      };
      "com.apple.screencapture" = {
        location = "~/Desktop";
        type = "png";
      };
      "com.apple.Safari" = {
        # Privacy: don’t send search queries to Apple
        UniversalSearchEnabled = false;
        SuppressSearchSuggestions = true;
        # Press Tab to highlight each item on a web page
        WebKitTabToLinksPreferenceKey = true;
        ShowFullURLInSmartSearchField = true;
        # Prevent Safari from opening ‘safe’ files automatically after downloading
        AutoOpenSafeDownloads = false;
        ShowFavoritesBar = false;
        IncludeInternalDebugMenu = true;
        IncludeDevelopMenu = true;
        WebKitDeveloperExtrasEnabledPreferenceKey = true;
        WebContinuousSpellCheckingEnabled = true;
        WebAutomaticSpellingCorrectionEnabled = false;
        AutoFillFromAddressBook = false;
        AutoFillCreditCardData = false;
        AutoFillMiscellaneousForms = false;
        WarnAboutFraudulentWebsites = true;
        WebKitJavaEnabled = false;
        WebKitJavaScriptCanOpenWindowsAutomatically = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks" = true;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically" = false;
      };
      "com.apple.mail" = {
        # Disable inline attachments (just show the icons)
        DisableInlineAttachmentViewing = true;
      };
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
      };
      "com.apple.print.PrintingPrefs" = {
        # Automatically quit printer app once the print jobs complete
        "Quit When Finished" = true;
      };
      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        # Check for software updates daily, not just once per week
        ScheduleFrequency = 1;
        # Download newly available updates in background
        AutomaticDownload = 1;
        # Install System data files & security updates
        CriticalUpdateInstall = 1;
      };
      "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
      # Prevent Photos from opening automatically when devices are plugged in
      "com.apple.ImageCapture".disableHotPlug = true;
      # Turn on app auto-update
      "com.apple.commerce".AutoUpdate = true;
      "mo.com.sleeplessmind.Wooshy" = {
        "KeyboardShortcuts_toggleWith" = "{\"carbonModifiers\":768,\"carbonKeyCode\":49}";
        SUEnableAutomaticChecks = 0;
        SUUpdateGroupIdentifier = 3425398139;
        allowCyclingThroughTargets = 1;
        "com_apple_SwiftUI_Settings_selectedTabIndex" = 4;
        fuzzyMatchingFlavor = "wooshyClassic";
        hazeOverWindowStyle = "fadeOutExceptDockMenuBarAndFrontmostApp";
        inputPosition = "aboveWindow";
        inputPreset = "custom";
        inputTextSize = 20;
        searchIncludesTrafficLightButtons = 1;
      };
      "mo.com.sleeplessmind.kindaVim" = {
        "KeyboardShortcuts_enterNormalMode" = "{\"carbonModifiers\":4096,\"carbonKeyCode\":53}";
        "NSStatusItem Preferred Position Item-0" = 6009;
        SUEnableAutomaticChecks = 0;
        SUUpdateGroupIdentifier = 790660886;
        appsForWhichToEnforceElectron = "[\"com.superhuman.electron\"]";
        appsForWhichToEnforceKeyboardStrategy = "[\"mo.com.sleeplessmind.Wooshy\"]";
        appsForWhichToUseHybridMode = "[\"com.apple.Safari\"]";
        appsToAdviseFor = "[\"com.apple.mail\"]";
        appsToIgnore = "[\"io.alacritty\",\"com.microsoft.VSCode\",\"org.qt-project.Qt.QtWebEngineCore\"]";
        charactersWindowContent = "move";
        "com_apple_SwiftUI_Settings_selectedTabIndex" = 0;
        enableCommandPassthrough = 1;
        enableOptionPassthrough = 1;
        enterNormalModeWith = "customShortcut";
        hazeOverWindowNonFullScreenOpacity = "0.5173477564102564";
        sendEscapeToMacOSWith = "commandEscape";
        showCharactersWindow = 0;
      };
      "mo.com.sleeplessmind.Scrolla" = {
        "KeyboardShortcuts_toggleWith" = "{\"carbonModifiers\":4352,\"carbonKeyCode\":49}";
        "NSStatusItem Preferred Position Item-0" = 6276;
        SUEnableAutomaticChecks = 0;
        SUUpdateGroupIdentifier = 3756402529;
        "com_apple_SwiftUI_Settings_selectedTabIndex" = 0;
        ignoreAreasWithoutScrollBars = 0;
      };
      "com.raycast.macos" = {
        NSNavLastRootDirectory = "~/src/scripts/raycast";
        "NSStatusItem Visible raycastIcon" = 0;
        commandsPreferencesExpandedItemIds = [
          "extension_noteplan-3__00cda425-a991-4e4e-8031-e5973b8b24f6"
          "builtin_package_navigation"
          "builtin_package_scriptCommands"
          "builtin_package_floatingNotes"
        ];
        "emojiPicker_skinTone" = "mediumLight";
        initialSpotlightHotkey = "Command-49";
        navigationCommandStyleIdentifierKey = "legacy";
        "onboarding_canShowActionPanelHint" = 0;
        "onboarding_canShowBackNavigationHint" = 0;
        "onboarding_completedTaskIdentifiers" = [
          "startWalkthrough"
          "calendar"
          "setHotkeyAndAlias"
          "snippets"
          "quicklinks"
          "installFirstExtension"
          "floatingNotes"
          "windowManagement"
          "calculator"
          "raycastShortcuts"
          "openActionPanel"
        ];
        organizationsPreferencesTabVisited = 1;
        popToRootTimeout = 60;
        raycastAPIOptions = 8;
        raycastGlobalHotkey = "Command-49";
        raycastPreferredWindowMode = "default";
        raycastShouldFollowSystemAppearance = 1;
        raycastWindowPresentationMode = 1;
        showGettingStartedLink = 0;
        "store_termsAccepted" = 1;
        suggestedPreferredGoogleBrowser = 1;
      };
      "com.stclairsoft.DefaultFolderX5" = {
        SUEnableAutomaticChecks = 0;
        askedToLaunchAtLogin = 1;
        askedToRemoveV4 = 1;
        currentSet = "Default Set";
        finderClickDesktop = 1;
        openInFrontFinderWindow = 0;
        showDrawer = 0;
        showDrawerButton = 1;
        showMenuButton = 1;
        showStatusItem = 0;
        toolbarShowAttributesOnOpen = 1;
        toolbarShowAttributesOnSave = 1;
        transferredOldUsageData = 1;
        welcomeShown = 1;
      };
    };
  };
}
