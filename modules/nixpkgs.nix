{
  self,
  config,
  ...
}: {
  imports = [./home-manager/nixpkgs.nix];
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
  nixpkgs.overlays = [self.overlays.default];
}
