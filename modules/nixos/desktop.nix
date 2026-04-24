# Personal desktop shared across machines. Composes the GNOME + Hyprland
# sessions on top of desktop-base and sets up the primary user account.
# Per-machine hardware (disko, boot, hostname) lives in the corresponding
# module under ./hardware/.
{
  config,
  ...
}:
{
  imports = [
    ./keybase.nix
    ./gnome.nix
    ./hyprland.nix
  ];

  services.syncthing = {
    enable = true;
    user = config.user.name;
    group = "users";
    openDefaultPorts = true;
    dataDir = config.user.home;
  };

  users = {
    mutableUsers = false;
    users."${config.user.name}" = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "docker"
      ];
      hashedPassword = "$6$1kR9R2U/NA0.$thN8N2sTo7odYaoLhipeuu5Ic4CS7hKDt1Q6ClP9y0I3eVMaFmo.dZNpPfdwNitkElkaLwDVsGpDuM2SO2GqP/";
    };
  };

  system.stateVersion = "24.11";
}
