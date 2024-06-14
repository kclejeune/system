{
  self,
  pkgs,
  ...
}: {
  packages = [
    pkgs.nixd
    self.packages.${pkgs.system}.pyEnv
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
