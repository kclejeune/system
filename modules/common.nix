{ config, pkgs, ... }: {
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
      yadm

      # nix stuff
      nixfmt
      niv

      # languages
      python3
      ruby
    ];

    # list of acceptable shells in /etc/shells
    shells = with pkgs; [ bash zsh fish ];
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
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
      { nixpkgs = "/etc/sources/nixpkgs"; }
      { home-manager = "/etc/sources/home-manager"; }
    ];
  };

  fonts = {
    enableFontDir = true;
    fonts = with pkgs; [ jetbrains-mono iosevka ];
  };
}
