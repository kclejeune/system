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

        # 0.8.0 introduced the Tempo module (clock + weather + calendar);
        # nixpkgs-unstable still has 0.7.0 at this rev. Pin until upstream
        # bumps and this whole entry can be deleted. cargoDeps is passed
        # in directly because buildRustPackage uses extendMkDerivation,
        # which locks cargoDeps before overrideAttrs runs — overriding
        # cargoHash alone wouldn't take effect.
        ashell =
          let
            version = "0.8.0";
            src = pkgs.fetchFromGitHub {
              owner = "MalpenZibo";
              repo = "ashell";
              tag = version;
              hash = "sha256-X9TU866PAzaf52qKsCpeJvwE0suu1lJndHNQdPg51HM=";
            };
          in
          pkgs.ashell.overrideAttrs (prev: {
            inherit version src;
            cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
              inherit src;
              name = "ashell-${version}-vendor";
              hash = "sha256-nhYbehlgB8pzMoj39G0BHRca9mIT+0QjUaebCx+DDE0=";
            };
            # Tempo's Open-Meteo URL and °C labels are hardcoded; the
            # TempoModuleConfig has no temperature_unit option upstream.
            patches = (prev.patches or [ ]) ++ [ ../pkgs/ashell/fahrenheit.patch ];
          });
      };
    };
}
