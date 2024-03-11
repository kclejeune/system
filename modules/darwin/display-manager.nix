{...}: {
  homebrew.brews = [
    "yabai"
  ];
  system.activationScripts.yabai = {
    enable = true;
    text = ''
      yabai --install-service && yabai --start-service
    '';
  };
}
