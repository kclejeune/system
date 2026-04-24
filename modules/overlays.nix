{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      overlayAttrs = {
        inherit (inputs.attic.packages.${system}) attic attic-client attic-server;

        cb = pkgs.callPackage ../pkgs/cb/package.nix { };
        fnox = pkgs.callPackage ../pkgs/fnox/package.nix { };
        weave = pkgs.callPackage ../pkgs/weave/package.nix { };
        stable = inputs.stable.legacyPackages.${system};
        determinate-nixd = inputs.determinate.packages.${system}.default;
        nix = inputs.determinate.inputs.nix.packages.${system}.default;
        nh = inputs.nh.packages.${system}.default;
      };
    };
}
