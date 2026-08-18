_: {
  flake.homeModules.atuin =
    { pkgs, ... }:
    {
      programs.atuin = {
        enable = true;
        package = pkgs.atuin;
        daemon.enable = true;
        flags = [ ];
        settings = {
          auto_sync = true;
          sync_frequency = "1m";
        };
      };
    };
}
