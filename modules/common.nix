{ config, pkgs, ... }: {

  fonts = {
    enableFontDir = true;
    fonts = with pkgs; [ jetbrains-mono iosevka ];
  };

  # environment setup
  environment = {
    systemPackages = with pkgs; [
      # editors
      neovim

      # standard toolset
      coreutils
      curl
      wget
      git

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
    package = pkgs.nix;
    trustedUsers = [ "kclejeune" "root" "@admin" "@wheel" ];
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };
    buildCores = 8;
    maxJobs = 8;
    readOnlyStore = true;
  };
}
