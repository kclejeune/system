{ config, ... }:
let
  flakeCfg = config;
in
{
  # Shared desktop. Composes the Hyprland session on top of desktop-base
  # and sets up the primary user account. Personal-only apps and services
  # (syncthing, discord, ...) live in `personal-apps`, enrolled per host,
  # so a future work machine can enroll `desktop` without them.
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
            # Root-equivalent (the daemon runs containers as root with host
            # mounts), so this sidesteps the sudo/fingerprint/rssh gates.
            # Accepted for dev convenience; rootless docker is the alternative.
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
