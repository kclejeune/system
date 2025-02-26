{
  self,
  config,
  ...
}: {
  nixpkgs = {
    config = {
      allowUnsupportedSystem = true;
      allowUnfree = true;
      allowBroken = false;
    };
    overlays = [
      self.overlays.default
    ];
  };
  nix = {
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
      trusted-users = ["${config.user.name}" "@admin" "@root" "@sudo" "@wheel"];
    };
  };
}
