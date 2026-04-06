{ pkgs, lib, ... }:
{
  imports = [ ../../../modules/home-manager/1password.nix ];

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
}
