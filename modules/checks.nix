{ self, lib, ... }:
{
  perSystem =
    { system, ... }:
    let
      filterSystem = lib.filterAttrs (_: drv: drv.pkgs.system == system);
    in
    {
      checks = lib.mergeAttrsList [
        (lib.mapAttrs' (name: cfg: lib.nameValuePair "${name}_home" cfg.activationPackage) (
          filterSystem self.homeConfigurations
        ))
        (lib.mapAttrs (_: cfg: cfg.config.system.build.toplevel) (
          filterSystem (self.darwinConfigurations // self.nixosConfigurations)
        ))
      ];
    };
}
