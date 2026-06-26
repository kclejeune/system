_: {
  # Host role: tailscale "server" node — the always-on hosts (Hetzner gateway +
  # the homelab P3 nodes haven/forge/vault/atlas) as opposed to laptops
  # (phil/wally). Layers the server-flavored tailscale config on top of the base
  # `tailscale` module: a LE cert for `tailscale serve` (permitCertUid), the
  # shared `tailscale set` flags (ssh, operator, exit-node, app-connector), and
  # opt-in serve. Enrolled alongside `subnet-router` (identical host set) but
  # kept separate: subnet-router owns kernel/NIC forwarding tuning, this owns the
  # tailscale daemon/serve surface.
  #
  # NOT enrolled on personal laptops — they keep the plain `tailscale` module
  # (client, no serve, no operator/ssh/exit-node advertisement).
  flake.nixosModules.tailscale-server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.tailscale.server;
      tailscale = lib.getExe config.services.tailscale.package;

      # Build the imperative `tailscale serve` invocation for one service +
      # endpoint. The endpoint key is "<proto>:<port>" (e.g. "tcp:443"); the
      # value is the local target (e.g. "http://127.0.0.1:8091").
      mkServeCmd =
        svcName: epKey: target:
        let
          port = lib.last (lib.splitString ":" epKey);
        in
        "${tailscale} serve --service=svc:${svcName} --https=${port} ${target}";

      serveCmds = lib.flatten (
        lib.mapAttrsToList (
          svcName: svcCfg: lib.mapAttrsToList (mkServeCmd svcName) svcCfg.endpoints
        ) config.services.tailscale.serve.services
      );
    in
    {
      options.services.tailscale.server = {
        acceptRoutes = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether this node accepts subnet routes advertised by other tailnet
            nodes (`--accept-routes`). A subnet router advertising a LAN it's
            already attached to (e.g. haven advertising 192.168.1.0/24) sets this
            false so it doesn't pull its own LAN back over the tunnel.
          '';
        };

        advertiseRoutes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "192.168.1.0/24" ];
          description = ''
            Subnet CIDRs this node advertises as a subnet router
            (`--advertise-routes`). Routes still need approval in the admin
            console; the kernel forwarding / rp_filter tuning that makes them
            work comes from the `subnet-router` role module.
          '';
        };

        advertiseExitNode = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Offer this node as a tailnet exit node (`--advertise-exit-node`).";
        };
      };

      config = lib.mkMerge [
        {
          services.tailscale = {
            # Provision a Let's Encrypt cert for `tailscale serve` and let the
            # primary user drive `tailscale` without sudo (TS_PERMIT_CERT_UID +
            # --operator). Both are server-role concerns, off on laptops.
            permitCertUid = config.user.name;

            # Enable Tailscale Serve wherever the host actually declares services
            # to expose. Upstream asserts serve.services is non-empty when serve
            # is enabled, so a host that declares none simply leaves serve off —
            # the cert above is still provisioned for ad-hoc `tailscale serve`.
            serve.enable = lib.mkDefault (config.services.tailscale.serve.services != { });

            extraSetFlags = [
              "--accept-dns"
              "--advertise-connector"
              "--ssh"
              "--operator=${config.user.name}"
              "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
            ]
            ++ lib.optional cfg.advertiseExitNode "--advertise-exit-node"
            ++ lib.optional (cfg.advertiseRoutes != [ ]) (
              "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
            );
          };
        }

        # Override the upstream tailscale-serve unit's ExecStart. Upstream runs
        # `tailscale serve set-config --all <json>`, but that path sets up the
        # "tcp:<port>" endpoints as raw TCP forwarders — it does NOT terminate
        # TLS — so an https:// client to the service VIP never completes. Drive
        # serve imperatively instead, one `tailscale serve --service=svc:<name>
        # --https=<port> <target>` per endpoint, which terminates TLS on <port>
        # (using the permitCertUid cert) and reverse-proxies to the local HTTP
        # target. `--bg` is implied once --service is set, and a service is
        # auto-advertised by `serve` (no separate `advertise` call needed).
        #
        # The command path is baked from the Nix-rendered service set, so any
        # change to serve.services changes ExecStart and systemd re-applies on
        # switch. NOTE: this is additive — dropping a service from Nix leaves its
        # serve config on the node until cleared with `tailscale serve clear
        # svc:<name>`.
        (lib.mkIf config.services.tailscale.serve.enable {
          systemd.services.tailscale-serve.serviceConfig.ExecStart = lib.mkForce (
            pkgs.writeShellScript "tailscale-serve-apply" ''
              set -euo pipefail
              ${lib.concatStringsSep "\n" serveCmds}
            ''
          );
        })
      ];
    };
}
