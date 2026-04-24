{ ... }:
{
  perSystem = _: {
    treefmt = {
      programs = {
        deadnix = {
          enable = true;
          no-lambda-arg = true;
          no-lambda-pattern-names = true;
        };
        nixfmt.enable = true;
        oxfmt.enable = true;
        ruff-check.enable = true;
        ruff-format.enable = true;
        shellcheck.enable = true;
        shfmt.enable = true;
        stylua.enable = true;
      };

      settings.excludes = [
        ".envrc"
        ".env"
        ".vscode/*.json"
        "**/Spoons/**/*.json"
        "**/zed/**/*.json"
      ];
      settings.on-unmatched = "info";
      settings.formatter.ruff-check.options = [
        # sort imports
        "--extend-select"
        "I"
      ];
    };
  };
}
