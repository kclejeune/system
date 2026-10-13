# Hands Cloudflare WARP's DNS proxy to systemd-resolved.
#
# warp-svc is meant to register its proxy with resolved over D-Bus, but it
# fails to parse NixOS's bare systemd version ("could not find '-' in version
# slug: '261.3'") and falls back to rewriting /etc/resolv.conf. nss-resolve
# never reads that file, so lookups miss Gateway and WARP's own DNS check fails
# into a reconnect loop. Drop this once warp-svc stops logging that error.
_: {
  flake.nixosModules.resolv-reload =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.resolv-reload;
      device = "sys-subsystem-net-devices-CloudflareWARP.device";
    in
    {
      options.services.resolv-reload.enable =
        lib.mkEnableOption "routing systemd-resolved queries through the Cloudflare WARP DNS proxy"
        // {
          default = config.services.cloudflare-warp.enable && config.services.resolved.enable;
        };

      config = lib.mkIf cfg.enable {
        # WARP recreates the interface on every connect, and resolved drops a
        # link's DNS settings with it, so reapply each time it appears.
        systemd.services.resolv-reload = {
          wantedBy = [ device ];
          bindsTo = [ device ];
          after = [
            device
            "systemd-resolved.service"
          ];
          path = [ pkgs.systemd ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # resolved can see the link a moment after udev does.
            Restart = "on-failure";
            RestartSec = 1;
          };
          # "~." makes WARP win every name no other link claims; WARP's fallback
          # domains (home.arpa, local, …) still reach the LAN through its proxy.
          script = ''
            resolvectl dns CloudflareWARP 127.0.2.2 127.0.2.3
            resolvectl domain CloudflareWARP '~.'
            resolvectl flush-caches
          '';
        };
      };
    };
}
