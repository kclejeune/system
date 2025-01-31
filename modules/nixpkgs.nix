{
  inputs,
  config,
  pkgs,
  ...
}: {
  nixpkgs = {config = import ./config.nix;};

  environment = {
    etc = {
      nixpkgs.source = "${inputs.nixpkgs}";
      home-manager.source = "${inputs.home-manager}";
    };
  };

  nix = {
    package = pkgs.nix;
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      experimental-features = nix-command flakes
    '';
    optimise = {
      automatic = true;
    };
    settings = {
      max-jobs = 8;
      trusted-users = ["${config.user.name}" "root" "@admin" "@sudo" "@wheel"];
      trusted-substituters = [
        "https://cache.nixos.org"
        "https://kclejeune.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko="
      ];
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };

    nixPath =
      builtins.map
      (source: "${source}=/etc/${config.environment.etc.${source}.target}") [
        "home-manager"
        "nixpkgs"
      ];
    registry = {
      nixpkgs.flake = inputs.nixpkgs;
      home-manager.flake = inputs.home-manager;
    };
  };
}
