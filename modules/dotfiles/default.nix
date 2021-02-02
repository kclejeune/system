{ config, pkgs, ... }: {
  home.file = {
    brewfile = {
      source = ./Brewfile;
      target = "Brewfile";
    };
    keras = {
      source = ./keras;
      target = ".keras";
      recursive = true;
    };
  };

  xdg.configFile = {
    nix = {
      target = "nix.conf";
      text = ''
        substituters = https://kclejeune.cachix.org https://cache.nixos.org/ https://hydra.nixos.org
        trusted-substituters =
        trusted-public-keys = kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs=.
        require-sigs = true
        trusted-users = ${config.home.username} root @admin @wheel
        allowed-users = *
        keep-outputs = true
        keep-derivations = true
        experimental-features = nix-command flakes
      '';
    };
    karabiner = {
      source = ./karabiner;
      recursive = true;
    };
    skhd = {
      source = ./skhd;
      recursive = true;
    };
    yabai = {
      source = ./yabai;
      recursive = true;
    };
  };
}
