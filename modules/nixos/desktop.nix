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
        flakeCfg.flake.nixosModules.avahi
        flakeCfg.flake.nixosModules.airprint
        flakeCfg.flake.nixosModules.airplay
      ];

      services.airprint = {
        enable = true;
        ippUsb = true;
      };
      services.airplay.enable = true;

      users = {
        mutableUsers = false;
        users."${config.user.name}" = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "networkmanager"
            "docker"
          ];
          # Password comes from profile-personal's sops-backed
          # hashedPasswordFile (secrets/users.yaml), shared across every
          # personal-identity host. With mutableUsers = false the shadow entry
          # is rewritten from that file on each activation.
        };
      };

      system.stateVersion = "24.11";
    };
}
