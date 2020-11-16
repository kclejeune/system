{ inputs, config, pkgs, ... }:
let sources = import ../nix/sources.nix { };
in {
  # environment setup
  environment = {
    systemPackages = with pkgs; [
      # editors
      vim
      neovim

      # standard toolset
      coreutils
      curl
      wget
      git
      jq

      # helpful shell stuff
      bat
      fzf
      ripgrep
      zsh

      # nix stuff
      nixfmt

      # languages
      python3
      ruby
    ];
    etc = {
      home-manager = {
        source = "${inputs.home-manager}";
        target = "sources/home-manager";
      };
      nixpkgs = {
        source = "${inputs.nixpkgs}";
        target = "sources/nixpkgs";
      };
    };
    # list of acceptable shells in /etc/shells
    shells = with pkgs; [ bash zsh fish ];
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
    trustedUsers = [ "kclejeune" "root" "@admin" "@wheel" ];
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };
    buildCores = 8;
    maxJobs = 8;
    readOnlyStore = true;
    nixPath = [
      "nixpkgs=/etc/${config.environment.etc.nixpkgs.target}"
      "home-manager=/etc/${config.environment.etc.home-manager.target}"
    ];
  };

  fonts = {
    enableFontDir = true;
    fonts = with pkgs; [ jetbrains-mono iosevka ];
  };
}
