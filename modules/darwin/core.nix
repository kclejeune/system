{
  inputs,
  config,
  pkgs,
  ...
}: {
  # environment setup
  environment = {
    loginShell = pkgs.zsh;
    etc = {darwin.source = "${inputs.darwin}";};
  };

  # auto manage nixbld users with nix darwin
  nix = {
    configureBuildUsers = false;
    nixPath = ["darwin=/etc/${config.environment.etc.darwin.target}"];
    extraOptions = ''
      extra-platforms = x86_64-darwin aarch64-darwin
    '';
  };

  security.pam.enableSudoTouchIdAuth = true;
  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
