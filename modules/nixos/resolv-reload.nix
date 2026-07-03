# DNS reconciliation for VPNs that hijack /etc/resolv.conf under
# NetworkManager + systemd-resolved. Cloudflare WARP is the concrete case this
# was built and verified against, but the mechanism is VPN-agnostic: it applies
# to any client that takes over /etc/resolv.conf as a foreign file (rather than
# feeding resolved per-link DNS over D-Bus, as tailscale/netbird do). Gated to
# self-enable only when such a VPN, resolved, and NetworkManager are all present.
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
          # Auto-detect: on when a resolv.conf-hijacking VPN (WARP), resolved,
          # and NetworkManager are all present. A host can force it off by
          # setting this false, or on elsewhere if another such VPN is added.
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
        # Interfaces the dispatcher ignores, computed from enabled services so
        # each contributes only when present. Read real interface names from
        # each service's own options where they exist; loopback and NM's
        # wifi-p2p control device are always ignored. mkDefault so a host can
        # override or append.
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

        # The VPN owns /etc/resolv.conf directly (NM runs rc-manager=unmanaged for
        # the externally-managed VPN tun). Two failure modes have to be corrected
        # on every VPN transition:
        #
        #   1. Disconnect. The VPN restores resolved's stub symlink
        #      (/etc/resolv.conf -> /etc/static/resolv.conf) but leaves its now-dead
        #      DoH proxy (e.g. WARP's 127.0.2.2/.3) in resolved's Global scope, so
        #      the stub resolves nothing. resolved only drops the stale Global
        #      servers when it re-reads /etc/resolv.conf via SIGHUP — the D-Bus API
        #      has no re-read method and flush-caches alone does not clear them, so
        #      `systemctl reload` is required. The LAN links must also carry the ~.
        #      default route so the catch-all falls through to their DHCP DNS.
        #
        #   2. Connect. The VPN writes a regular resolv.conf pointing at its proxy,
        #      which resolved ingests as Global DNS. But the LAN links come up
        #      +DefaultRoute (NM pushes DHCP servers at neutral priority), so
        #      resolved queries the VPN's Global *and* the LAN default-route scope
        #      in parallel and returns whichever answers first. The LAN resolver
        #      poisons internal names with A 0.0.0.0 and often wins the race — the
        #      spurious failures. Fix: strip the LAN default route while connected
        #      so the VPN's Global owns the catch-all uncontested; internal and
        #      external names both resolve via the VPN, no race.
        #
        # Triggers. The corrective service is fired from three sources, because no
        # single one covers every case:
        #   - .path on /etc/resolv.conf: the VPN owns that file and flips it between
        #     a regular file (connected) and the resolved stub symlink
        #     (disconnected) on every transition. This is the reliable up/down
        #     signal — NM emits no device-state events for the external VPN link, so
        #     a dispatcher CONNECTION_ID guard never fires.
        #   - service wantedBy multi-user.target: run once at boot (the .path unit
        #     only fires on *changes* after it starts, not the state already present
        #     at boot).
        #   - NM dispatcher on managed eth/wifi up/down: covers a new LAN link
        #     appearing while the VPN stays connected (dock, NIC hotplug, wifi
        #     switch) — resolv.conf does not change then, so the .path unit would
        #     miss it. The new link comes up +DefaultRoute and would poison until
        #     the next VPN toggle. Managed links (unlike the external VPN tun) do
        #     dispatch.
        # LAN links are discovered dynamically (resolvectl takes device names) so
        # reboots / hardware changes don't need index edits.
        systemd.paths.resolv-reload = {
          wantedBy = [ "multi-user.target" ];
          pathConfig = {
            PathChanged = "/etc/resolv.conf";
            Unit = "resolv-reload.service";
          };
        };
        systemd.services.resolv-reload = {
          # wantedBy: the boot-time run described in the trigger notes above.
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

        # Re-run the reconciliation when a managed eth/wifi link goes up or down
        # while the VPN is unchanged (the .path unit only sees VPN transitions).
        # Skip every other action type and the VPN/virtual devices to avoid
        # needless churn. Runs as root, so `systemctl start` can trigger the
        # oneshot. The reconciliation is idempotent, so overlap with the .path
        # trigger (a single event firing both) is harmless — no debounce needed.
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
