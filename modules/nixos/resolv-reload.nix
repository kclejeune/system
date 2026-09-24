# DNS fix-ups for VPNs that take over /etc/resolv.conf (Cloudflare WARP)
# under NetworkManager + systemd-resolved.
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
    in
    {
      options.services.resolv-reload = {
        enable = lib.mkEnableOption "DNS reconciliation for VPNs that hijack /etc/resolv.conf" // {
          # On when such a VPN, resolved and NetworkManager are all present.
          default =
            config.services.cloudflare-warp.enable
            && config.services.resolved.enable
            && config.networking.networkmanager.enable;
        };

        ignoreInterfaces = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Interface names (shell glob patterns, matched by the dispatcher's
            `case`) that must NOT trigger DNS reconciliation — loopback, container
            bridges, and VPN tunnels. The default is computed from which services
            are enabled (see the module); append here for host-specific interfaces.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # Interfaces the dispatcher ignores; mkDefault so hosts can extend.
        services.resolv-reload.ignoreInterfaces = lib.mkDefault (
          [
            "lo"
            "p2p-dev-*"
          ]
          ++ lib.optional config.services.cloudflare-warp.enable "CloudflareWARP"
          ++ lib.optional config.services.tailscale.enable config.services.tailscale.interfaceName
          ++ lib.optional config.services.netbird.enable config.services.netbird.clients.default.interface
          ++ lib.optionals config.virtualisation.docker.enable [
            "docker*"
            "veth*"
          ]
        );

        # On disconnect the VPN leaves its dead DoH proxy in resolved's Global scope
        # until a reload (SIGHUP); on connect the LAN links' +DefaultRoute races it
        # and the LAN resolver poisons internal names. Fire on resolv.conf changes
        # (the only reliable VPN up/down signal), at boot, and on LAN link changes.
        systemd.paths.resolv-reload = {
          wantedBy = [ "multi-user.target" ];
          pathConfig = {
            PathChanged = "/etc/resolv.conf";
            Unit = "resolv-reload.service";
          };
        };
        systemd.services.resolv-reload = {
          wantedBy = [ "multi-user.target" ];
          after = [ "NetworkManager.service" ];
          serviceConfig.Type = "oneshot";
          path = [
            pkgs.systemd
            pkgs.networkmanager
            pkgs.gawk
          ];
          script = ''
            # Managed ethernet/wifi links currently connected. nmcli -t is colon
            # separated (DEVICE:TYPE:STATE).
            lan_links=$(nmcli -t -f DEVICE,TYPE,STATE device status \
              | awk -F: '$3=="connected" && ($2=="ethernet" || $2=="wifi"){print $1}')

            if [ -L /etc/resolv.conf ]; then
              # VPN disconnected: give the LAN links the catch-all and reload
              # resolved so the stale VPN proxy drops from Global and resolution
              # falls through to DHCP DNS.
              for l in $lan_links; do resolvectl default-route "$l" yes || true; done
              systemctl reload systemd-resolved || true
            else
              # VPN connected: strip the LAN catch-all so the VPN's Global scope
              # wins uncontested and the LAN resolver can't poison internal names.
              for l in $lan_links; do resolvectl default-route "$l" no || true; done
            fi
            resolvectl flush-caches || true
          '';
        };

        # LAN links changing while the VPN stays up. Idempotent, so overlap with
        # the .path trigger is harmless.
        networking.networkmanager.dispatcherScripts = [
          {
            type = "basic";
            source = pkgs.writeShellScript "resolv-reload-lan-trigger" ''
              iface="$1"
              action="$2"
              case "$action" in
                up | down) ;;
                *) exit 0 ;;
              esac
              case "$iface" in
                ${lib.concatStringsSep " | " cfg.ignoreInterfaces}) exit 0 ;;
              esac
              ${pkgs.systemd}/bin/systemctl start resolv-reload.service || true
            '';
          }
        ];
      };
    };
}
