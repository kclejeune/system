{ config, ... }:
let
  flakeCfg = config;
in
(import ../_lib.nix).mkAspect {
  name = "profile-work";
  os = _: {
    user.name = "klejeune";
    hm.imports = [ flakeCfg.flake.homeModules.profile-work ];
    security.pki.installCACerts = false;
  };
  home =
    { pkgs, lib, ... }:
    {
      imports = [ flakeCfg.flake.homeModules.onepassword ];

      home.packages = lib.attrValues (
        lib.mergeAttrsList [
          {
            inherit (pkgs)
              awscli2
              amazon-ecr-credential-helper
              helmfile
              kubectl
              kubernetes-helm
              ;
          }
          (lib.optionalAttrs pkgs.stdenvNoCC.isLinux {
            inherit (pkgs)
              xclip
              xsel
              wl-clipboard-rs
              ;
          })
        ]
      );
    };
}
