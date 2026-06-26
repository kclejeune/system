{ config, ... }:
let
  flakeCfg = config;
in
{
  # Role aggregator for the bare-metal P3 Tiny homelab nodes (haven / forge /
  # vault / atlas). Bundles the full common stack + the cross-node defaults that
  # used to be copy-pasted into every host block in flake.nix and every host
  # module. A host enrolls this plus its own host module; flake.nix host blocks
  # collapse to `host-baseline + default + homelab-node + <host>`.
  #
  # The Hetzner gateway deliberately does NOT use this — it's the inverse role
  # (accepts routes, advertises none, no server-base) and enrolls the VPN
  # modules directly.
  flake.nixosModules.homelab-node =
    { config, lib, ... }:
    {
      imports = [
        flakeCfg.flake.nixosModules.hardware-p3-tiny
        flakeCfg.flake.nixosModules.server-base
        flakeCfg.flake.nixosModules.caddy-lan
        flakeCfg.flake.nixosModules.profile-personal
        flakeCfg.flake.nixosModules.tailscale
        flakeCfg.flake.nixosModules.netbird
        flakeCfg.flake.nixosModules.subnet-router
        flakeCfg.flake.nixosModules.tailscale-server
        flakeCfg.flake.nixosModules.beszel-agent
      ];

      # Primary user + rescue root keys + pinned state version — identical on
      # every P3 node. Set via the users.users submodule (not the `user`
      # types.attrs alias) so mkDefault/list-merge behave: haven overrides
      # extraGroups to append incus-admin and its normal-priority def wins.
      users.users.${config.user.name} = {
        isNormalUser = true;
        extraGroups = lib.mkDefault [ "wheel" ];
      };
      identity.enableRootSshKeys = lib.mkDefault true;
      system.stateVersion = lib.mkDefault "25.11";

      # Web UIs are fronted by caddy-lan (LE certs via Cloudflare DNS-01);
      # enabled here so hosts only declare `services.caddyLan.proxies`.
      services.caddyLan.enable = lib.mkDefault true;

      # Homelab LAN subnet-router posture (lifted off the now-generic
      # server-base): advertise the LAN, refuse tailnet routes for it (the node
      # is already attached, so accepting it back would pull the LAN over the
      # tunnel). The kernel forwarding that makes this work comes from
      # subnet-router; the option declarations from tailscale-server.
      services.tailscale.server = {
        acceptRoutes = lib.mkDefault false;
        advertiseRoutes = lib.mkDefault [ config.site.lanCidr ];
      };

      # expose local unifi console to tailnet
      services.tailscale.serve.services.ui.endpoints."tcp:443" = "https+insecure://192.168.1.1";
    };
}
