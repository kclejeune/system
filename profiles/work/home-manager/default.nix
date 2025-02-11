{
  self,
  pkgs,
  ...
}: {
  imports = [../../../modules/home-manager/1password.nix];

  nixpkgs.overlays = [self.overlays.default self.overlays.work];
  home.packages = with pkgs;
    [
      awscli2
      helmfile
      kubectl
      kubernetes-helm
      teleport
      nix_2_18
      cachix
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
  xdg.configFile = {
    opAgent = {
      recursive = true;
      target = "1Password/ssh/agent.toml";
      text = ''
        [[ssh-keys]]
        vault = "Employee"
      '';
    };
  };
}
