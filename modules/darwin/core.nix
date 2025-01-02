{
  inputs,
  config,
  ...
}: let
  nixpkgs = inputs.nixpkgs;
  unstable = inputs.nixpkgs;
  stable = inputs.stable;
in {
  # environment setup
  environment = {
    etc = {
      darwin.source = "${inputs.darwin}";
      nixpkgs.source = "${nixpkgs}";
      unstable.source = "${unstable}";
      stable.source = "${stable}";
    };
  };

  # auto manage nixbld users with nix darwin
  nix = {
    configureBuildUsers = true;
    nixPath = [
      "darwin=/etc/${config.environment.etc.darwin.target}"
      "nixpkgs=/etc/${config.environment.etc.nixpkgs.target}"
      "stable=/etc/${config.environment.etc.stable.target}"
      "unstable=/etc/${config.environment.etc.nixpkgs.target}"
    ];
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
