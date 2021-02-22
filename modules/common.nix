{ inputs, config, lib, pkgs, ... }: {
  imports = [ ../modules/primary.nix ];

  programs.zsh.enable = true;

  user = {
    description = "Kennan LeJeune";
    home = "${
        if pkgs.stdenvNoCC.isDarwin then "/Users" else "/home"
      }/${config.user.name}";
    shell = pkgs.zsh;
  };

  # bootstrap home manager using system config
  hm = import ./home.nix;

  # let nix manage home-manager profiles and use global nixpkgs
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
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
      jq

      # helpful shell stuff
      bat
      fzf
      ripgrep
      zsh

      # languages
      python3
      ruby
    ];
    etc = {
      home-manager.source = "${inputs.home-manager}";
      nixpkgs.source = "${inputs.nixpkgs}";
    };
    # list of acceptable shells in /etc/shells
    shells = with pkgs; [ bash zsh fish ];
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      ${lib.optionalString (config.nix.package == pkgs.nixFlakes)
      "experimental-features = nix-command flakes"}
    '';
    trustedUsers = [ "${config.user.name}" "root" "@admin" "@wheel" ];
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

    binaryCaches = [ "https://kclejeune.cachix.org" ];
    binaryCachePublicKeys =
      [ "kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko=" ];

    registry.nixpkgs = {
      from = {
        id = "nixpkgs";
        type = "indirect";
      };
      flake = inputs.nixpkgs;
    };
  };

  fonts = {
    enableFontDir = true;
    fonts = with pkgs; [ jetbrains-mono iosevka ];
  };
}
