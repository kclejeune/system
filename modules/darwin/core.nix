{inputs, ...}: {
  # auto manage nixbld users with nix darwin
  nix = {
    configureBuildUsers = true;
    registry = {
      darwin.flake = inputs.darwin;
    };
    extraOptions = ''
      extra-platforms = x86_64-darwin aarch64-darwin
    '';
  };

  security.pam.enableSudoTouchIdAuth = true;
  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
