{...}: {
  programs.atuin = {
    daemon.enable = true;
    settings = {
      update_check = false;
      sync_frequency = "15m";
    };
    flags = [];
  };
  xdg.configFile = {
    opAgent = {
      recursive = true;
      target = "1Password/ssh/agent.toml";
      text = ''
        [[ssh-keys]]
        vault = "Private"
      '';
    };
  };
  programs.git = {
    userEmail = "kennan@case.edu";
    userName = "Kennan LeJeune";
  };
}
