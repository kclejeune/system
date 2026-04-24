{ config, ... }:
let
  flakeCfg = config;

  osBody = _: {
    user.name = "klejeune";
    hm.imports = [ flakeCfg.flake.homeModules.profile-work ];
    security.pki.installCACerts = false;
  };
in
{
  flake.nixosModules.profile-work = osBody;
  flake.darwinModules.profile-work = osBody;

  flake.homeModules.profile-work =
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
