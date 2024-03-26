{
  self,
  pkgs,
  ...
}: {
  packages = [
    pkgs.rnix-lsp
    self.packages.${pkgs.system}.pyEnv
  ];

  pre-commit = {
    hooks = {
      black.enable = true;
      shellcheck.enable = true;
      alejandra.enable = true;
      deadnix.enable = true;
      shfmt.enable = false;
      stylua.enable = true;
    };

    settings = {
      deadnix.edit = true;
      deadnix.noLambdaArg = true;
    };
  };
}
