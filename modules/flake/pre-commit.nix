{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      pre-commit = {
        settings.package = pkgs.prek;
        settings.hooks.treefmt = {
          enable = true;
          pass_filenames = false;
          settings.no-cache = false;
        };
      };
    };
}
