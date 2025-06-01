{
  inputs,
  config,
  ...
}: {
  system.primaryUser = config.user.name;
  # auto manage nixbld users with nix darwin
  nix = {
    registry = {
      darwin.flake = inputs.darwin;
    };
    settings = {
      extra-platforms = ["x86_64-darwin" "aarch64-darwin"];
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
