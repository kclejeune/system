{pkgs, ...}: {
  imports = [../../modules/home-manager/1password.nix];
  home.packages = with pkgs; [
    awscli2
    helmfile
    kubectl
    kubernetes-helm
    teleport
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
