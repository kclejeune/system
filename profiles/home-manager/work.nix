{pkgs, ...}: {
  imports = [../../modules/home-manager/1password.nix];
  home.packages = with pkgs; [
    kubectl
    kubernetes-helm
    kustomize
  ];
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
