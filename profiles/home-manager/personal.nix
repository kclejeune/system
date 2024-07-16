{...}: {
  xdg.configFile = {
    opAgent = {
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
    signing = {
      key = "kennan@case.edu";
      signByDefault = true;
    };
  };
}
