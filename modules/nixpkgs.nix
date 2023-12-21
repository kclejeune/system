{
  inputs,
  config,
  pkgs,
  ...
}: {
  nixpkgs = {config = import ./config.nix;};

  nix = {
    package = pkgs.nix;
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      experimental-features = nix-command flakes
    '';
    settings = {
      max-jobs = 8;
      trusted-users = ["${config.user.name}" "root" "@admin" "@wheel"];
      trusted-substituters = [
        "https://cache.nixos.org"
        "https://ldmsh.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "ldmsh.cachix.org-1:LpH9hFBWLQ6JJEjTkApsezg8MXC9miyjOPeTzjgNT8c="
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
        "stable"
      ];
    registry = {
      nixpkgs = {
        from = {
          id = "nixpkgs";
          type = "indirect";
        };
        flake = inputs.nixpkgs;
      };
      stable = {
        from = {
          id = "stable";
          type = "indirect";
        };
        flake = inputs.stable;
      };
    };
  };
}
