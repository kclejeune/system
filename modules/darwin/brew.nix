{ inputs, config, pkgs, ... }:
let
  checkBrew = "command -v brew > /dev/null";
  installBrew = ''
    ${pkgs.bash}/bin/bash -c "$(${pkgs.curl}/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"'';
in {
  environment = {
    extraInit = ''
      # install homebrew
      ${checkBrew} || ${installBrew}
    '';
  };

  homebrew = {
    enable = true;
    autoUpdate = true;
    # cleanup = "zap";
    global = {
      brewfile = true;
      noLock = true;
    };

    taps = [
      "beeftornado/rmtree"
      "homebrew/bundle"
      "homebrew/cask"
      "homebrew/cask-fonts"
      "homebrew/cask-versions"
      "homebrew/core"
      "homebrew/services"
      "koekeishiya/formulae"
    ];

    brews = [
      "dark-mode"
      "git"
      "mas"
      "beeftornado/rmtree/brew-rmtree"
    ];

    casks = [
      "1password"
      "adobe-acrobat-pro"
      "alfred"
      "appcleaner"
      "displaperture"
      "eul"
      "firefox"
      "fork"
      "google-chrome"
      "gpg-suite"
      "gswitch"
      "iina"
      "intellij-idea"
      "karabiner-elements"
      "keepingyouawake"
      "keybase"
      "kitty"
      "maccy"
      "skim"
      "visual-studio-code"
      "zoom"
    ];

    masApps = { "Unsplash Wallpapers" = 1284863847; };
  };
}
