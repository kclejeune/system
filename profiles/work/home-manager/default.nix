{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [../../../modules/home-manager/1password.nix];

  nix.package = lib.mkDefault pkgs.nix;
  home.packages = with pkgs;
    [
      awscli2
      amazon-ecr-credential-helper
      helmfile
      kubectl
      kubernetes-helm
      teleport_16
      (lib.hiPrio config.nix.package)
    ]
    ++ (
      if (pkgs.stdenvNoCC.isLinux)
      then [
        xclip
        xsel
        wl-clipboard-rs
      ]
      else []
    );
}
