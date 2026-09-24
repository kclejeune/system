{ config, ... }:
let
  flakeCfg = config;
in
{
  # Common stack for the P3 Tiny homelab nodes. The gateway doesn't use it:
  # it accepts routes, advertises none, and has no server-base.
  flake.nixosModules.homelab-node =
    { config, lib, ... }:
    {
      imports = [
        flakeCfg.flake.nixosModules.hardware-p3-tiny
        flakeCfg.flake.nixosModules.server-base
        flakeCfg.flake.nixosModules.nix-ld
        flakeCfg.flake.nixosModules.caddy-lan
        flakeCfg.flake.nixosModules.profile-personal
        flakeCfg.flake.nixosModules.tailscale
        flakeCfg.flake.nixosModules.netbird
        flakeCfg.flake.nixosModules.subnet-router
        flakeCfg.flake.nixosModules.tailscale-server
        flakeCfg.flake.nixosModules.beszel-agent
        flakeCfg.flake.nixosModules.comin
        flakeCfg.flake.nixosModules.traceway-agent
      ];

      # One ingest token shared by all four nodes.
      sops.secrets.${config.services.traceway.agent.tokenSecret}.sopsFile = ../../secrets/homelab.yaml;

      # users.users, not the `user` alias, so haven's extraGroups append merges.
      users.users.${config.user.name} = {
        isNormalUser = true;
        extraGroups = lib.mkDefault [ "wheel" ];
      };
      # The password is rewritten from sops on every activation. If decryption
      # fails, recover via SSH key + pam_rssh sudo or the console; root SSH is off.
      users.mutableUsers = lib.mkDefault false;
      system.stateVersion = lib.mkDefault "25.11";

      services.caddyLan.enable = lib.mkDefault true;

      # Advertise the LAN but don't accept it back: the node is already on it.
      services.tailscale.server = {
        acceptRoutes = lib.mkDefault false;
        advertiseRoutes = lib.mkDefault [ config.site.lanCidr ];
      };

      # UniFi console over the tailnet.
      services.tailscale.serve.services.ui.endpoints."tcp:443" =
        "https+insecure://${config.site.unifiAddr}";
    };
}
