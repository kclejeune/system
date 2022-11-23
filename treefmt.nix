{
  projectRootFile = "flake.nix";
  programs = {
    alejandra.enable = true;
    black.enable = true;
    gofmt.enable = true;
    prettier.enable = true;
    rufo.enable = true;
    shellcheck.enable = false;
    shfmt.enable = true;
  };
}
