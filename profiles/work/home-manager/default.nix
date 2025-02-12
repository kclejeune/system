{pkgs, ...}: {
  imports = [../../../modules/home-manager/1password.nix];

  nix.package = pkgs.stable.nixVersions.nix_2_18;
  home.packages = with pkgs;
    [
      awscli2
      helmfile
      kubectl
      kubernetes-helm
      stable.cachix
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
