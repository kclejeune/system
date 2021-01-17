{ inputs, config, lib, pkgs, ... }:
let
  defaultUser = "kclejeune";
  homePrefix = if pkgs.stdenvNoCC.isDarwin then "/Users" else "/home";
  userShell = "zsh";
in {
  users.users = {
    "${defaultUser}" = {
      description = "Kennan LeJeune";
      home = "${homePrefix}/${defaultUser}";
      shell = pkgs.${userShell};
    };
  };

  # bootstrap home manager using system config
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.${defaultUser} = { pkgs, ... }: {
      imports = [ ../modules/home.nix ];
    };
  };

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
    trustedUsers = [ "${defaultUser}" "root" "@admin" "@wheel" ];
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
  };

  fonts = {
    enableFontDir = true;
    fonts = with pkgs; [ jetbrains-mono iosevka ];
  };
}
