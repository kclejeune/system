_: {
  flake.homeModules.launchd =
    { lib, ... }:
    {
      options.launchd.agents = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            config.domain = lib.mkOverride 999 "gui";
          }
        );
      };
    };
}
