{
  config,
  pkgs,
  ...
}: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    nix-direnv.package = pkgs.nix-direnv.override (prev: prev // {nix = config.nix.package;});
    stdlib = ''
      # stolen from @i077; store .direnv in cache instead of project dir
      declare -A direnv_layout_dirs
      direnv_layout_dir() {
          echo "''${direnv_layout_dirs[$PWD]:=$(
              echo -n "${config.xdg.cacheHome}"/direnv/layouts/
              echo -n "$PWD" | shasum | cut -d ' ' -f 1
          )}"
      }

      layout_poetry() {
        if [[ ! -f pyproject.toml ]]; then
          log_error 'No pyproject.toml found. Use `poetry new` or `poetry init` to create one first.'
          exit 2
        fi

        # create venv if it doesn't exist
        poetry run true

        export VIRTUAL_ENV=$(poetry env info --path)
        export POETRY_ACTIVE=1
        PATH_add "$VIRTUAL_ENV/bin"
      }
    '';
  };
}
