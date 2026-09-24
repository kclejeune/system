{ config, ... }:
let
  flakeCfg = config;
in
{
  # Personal-only apps live in `personal-apps` so a work machine can enroll
  # `desktop` without them.
  flake.nixosModules.desktop =
    { config, ... }:
    {
      imports = [
        flakeCfg.flake.nixosModules.desktop-base
        flakeCfg.flake.nixosModules.hyprland
        flakeCfg.flake.nixosModules.avahi
        flakeCfg.flake.nixosModules.airprint
        flakeCfg.flake.nixosModules.airplay
      ];

      services.airprint = {
        enable = true;
        ippUsb = true;
        # Laptops print locally; don't share printers on untrusted networks.
        openFirewall = false;
      };
      services.airplay.enable = true;

      users = {
        mutableUsers = false;
        users."${config.user.name}" = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "networkmanager"
            # Root-equivalent, bypassing the sudo/fingerprint/rssh gates;
            # accepted for dev convenience.
            "docker"
          ];
          # Password: profile-personal's sops hashedPasswordFile.
        };
      };

      system.stateVersion = "24.11";
    };
}
