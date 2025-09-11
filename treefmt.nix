{...}: {
  projectRootFile = "flake.nix";

  programs = {
    deadnix = {
      enable = true;
      no-lambda-arg = true;
      no-lambda-pattern-names = true;
    };
    alejandra.enable = true;
    jsonfmt.enable = true;
    mdformat.enable = true;
    stylua.enable = true;
    ruff-check.enable = true;
    ruff-format.enable = true;
    shellcheck.enable = true;
    shfmt.enable = true;
  };

  settings.excludes = [
    ".envrc"
    ".env"
  ];
  settings.on-unmatched = "info";
  settings.formatter.ruff-check.options = [
    # sort imports
    "--extend-select"
    "I"
  ];
  settings.formatter.jsonfmt.excludes = [
    ".vscode/*.json"
    "**/Spoons/**/*.json"
    ".zed/*.json"
  ];
}
