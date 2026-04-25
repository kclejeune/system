{ config, ... }:
let
  flakeCfg = config;
in
{
  # Shared desktop. Composes the Hyprland session on top of desktop-base
  # and sets up the primary user account. Identity-specific things
  # (keybase, syncthing, personal-only apps) live in profile-personal so
  # a future work machine can opt out by enrolling `desktop` without
  # `profile-personal`.
  # Per-machine hardware (disko, boot, hostname) lives in hardware.nix.
  flake.nixosModules.desktop =
    { config, ... }:
    {
      imports = [
        flakeCfg.flake.nixosModules.desktop-base
        flakeCfg.flake.nixosModules.hyprland
      ];

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
    };
}
