{
  self,
  pkgs,
  ...
}: {
  packages = [
    self.packages.${pkgs.system}.sysdo
    pkgs.nixd
    pkgs.uv
  ];

  pre-commit = {
    hooks = {
      black.enable = true;
      shellcheck.enable = true;
      alejandra.enable = true;
      shfmt.enable = false;
      stylua.enable = true;
      deadnix = {
        enable = true;
        settings = {
          edit = true;
          noLambdaArg = true;
        };
      };
    };
  };
}
