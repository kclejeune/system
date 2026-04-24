# Declares `user` and `hm` options that alias to users.users.<name> and
# home-manager.users.<name>. Used by both nixos and darwin.
# (Pattern courtesy of @i077 — https://github.com/i077/system/)
_:
(import ../_lib.nix).mkAspect {
  name = "primary-user";
  os =
    { config, lib, options, ... }:
    let
      inherit (lib) mkAliasDefinitions mkOption types;
    in
    {
      options = {
        user = mkOption {
          description = "Primary user configuration";
          type = types.attrs;
          default = { };
        };
        hm = mkOption {
          type = types.attrs;
          default = { };
        };
      };

      config = {
        home-manager.users.${config.user.name} = mkAliasDefinitions options.hm;
        users.users.${config.user.name} = mkAliasDefinitions options.user;
      };
    };
}
