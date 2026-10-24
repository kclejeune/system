{ config, ... }:
let
  flakeCfg = config;
in
{
  # Personal-only apps live in `personal-apps` so a work machine can enroll
  # `desktop` without them.
  flake.nixosModules.desktop =
    { config, ... }:
    let
      trustedSsids = [
        "Rorschach"
        "BernardsHome"
        "DEKK"
      ];
    in
    {
      imports = [
        flakeCfg.flake.nixosModules.desktop-base
        flakeCfg.flake.nixosModules.hyprland
        flakeCfg.flake.nixosModules.avahi
        flakeCfg.flake.nixosModules.airprint
        flakeCfg.flake.nixosModules.airplay
        flakeCfg.flake.nixosModules.trusted-network-firewall
      ];

      services.openssh.openFirewall = false;
      services.airprint = {
        enable = true;
        ippUsb = true;
        # Laptops print locally; don't share printers on untrusted networks.
        openFirewall = false;
      };
      services.airplay.enable = true;

      networking.firewall.trustedNetwork.rules = {
        ssh = {
          ssids = trustedSsids;
          # Wired networks cannot be authenticated without extra identity
          # information. SSH is hardened enough for this deliberate fallback.
          trustedEthernet = true;
          allowedTCPPorts = [ 22 ];
        };
        cups = {
          ssids = trustedSsids;
          allowedTCPPorts = [ 631 ];
        };
      };

      users = {
        mutableUsers = false;
        users."${config.user.name}" = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "networkmanager"
            "systemd-journal"
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
