{...}: {
  imports = [../../modules/home-manager/1password.nix];
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
