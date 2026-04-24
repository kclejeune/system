{ ... }:
{
  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        packages =
          (builtins.attrValues {
            inherit (pkgs)
              bashInteractive
              fd
              ripgrep
              uv
              nh
              ;
          })
          ++ config.pre-commit.settings.enabledPackages
          ++ (lib.attrValues config.treefmt.build.programs)
          ++ (lib.mapAttrsToList (_name: value: value) config.packages);
        shellHook = config.pre-commit.installationScript;
      };
    };
}
