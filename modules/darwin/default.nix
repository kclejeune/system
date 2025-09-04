{
  inputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    ../common.nix
    ./brew.nix
    ./preferences.nix
  ];

  system.primaryUser = config.user.name;

  nix.enable = false;
  nix.package = inputs.determinate.inputs.nix.packages.${pkgs.system}.default;
  determinate-nix.customSettings = {
    extra-trusted-users = ["${config.user.name}" "@admin" "@root" "@sudo" "@wheel"];
    keep-outputs = true;
    keep-derivations = true;
  };

  hm.nix.registry = {
    darwin.flake = inputs.darwin;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
