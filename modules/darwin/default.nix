{
  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../common.nix
    ./brew.nix
    ./preferences.nix
  ];

  system.primaryUser = config.user.name;

  nix.enable = false;
  nix.package = pkgs.nix;
  determinateNix = {
    enable = true;
    customSettings = {
      extra-trusted-users = [
        "${config.user.name}"
        "@admin"
        "@root"
        "@sudo"
        "@wheel"
        "@staff"
      ];
      keep-outputs = true;
      keep-derivations = true;
      extra-experimental-features = "external-builders nix-command flakes";
    };
    determinateNixd = {
      authentication.additionalNetrcSources = [ "/etc/nix/netrc" ];
      garbageCollector.strategy = "automatic";
      builder.state = "enabled";
    };
  };

  hm.nix.registry = {
    darwin.flake = inputs.darwin;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
