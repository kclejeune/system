{
  inputs,
  pkgs,
  ...
}: {
  user.name = "klejeune";
  hm = {imports = [./home-manager/work.nix];};
  security.pki.installCACerts = false;
  nix.package = pkgs.nix_2_18;
  nixpkgs.overlays = [
    (final: prev: let
      pkgs-2405 = import inputs.nixpkgs-2405 {inherit (prev) system;};
    in {
      nix_2_18 = pkgs-2405.nixVersions.nix_2_18;
      cachix = pkgs-2405.cachix;
    })
  ];
}
