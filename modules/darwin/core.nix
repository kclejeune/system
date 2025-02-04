{
  inputs,
  config,
  ...
}: {
  # environment setup
  environment = {
    etc = {
      darwin.source = "${inputs.darwin}";
    };
  };

  # auto manage nixbld users with nix darwin
  nix = {
    configureBuildUsers = true;
    nixPath = [
      "darwin=/etc/${config.environment.etc.darwin.target}"
    ];
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
