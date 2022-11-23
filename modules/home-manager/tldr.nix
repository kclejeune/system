{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.tealdeer = {
    enable = true;
    settings = {
      display = {
        compact = false;
        use_pager = true;
      };
      updates = {auto_update = true;};
    };
  };
}
