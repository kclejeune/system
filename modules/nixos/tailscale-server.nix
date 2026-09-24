_: {
  # Tailscale server role (gateway + homelab nodes): serve cert, operator, ssh,
  # exit-node and app-connector flags. Forwarding lives in subnet-router.
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
            # Server-only: a cert for serve, and operator so the user needs no sudo.
            permitCertUid = config.user.name;

            # Upstream asserts serve.services is non-empty when serve is on.
            serve.enable = lib.mkDefault (config.services.tailscale.serve.services != { });

            extraSetFlags = [
              "--accept-dns"
              "--advertise-connector"
              "--ssh"
              "--operator=${config.user.name}"
              "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
            ]
            ++ lib.optional cfg.advertiseExitNode "--advertise-exit-node"
            ++ lib.optional (
              cfg.advertiseRoutes != [ ]
            ) "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}";
          };
        }

        # Upstream's `serve set-config` makes tcp:<port> raw forwarders without TLS
        # termination, so run `tailscale serve --service --https` per endpoint.
        # Additive: removed services linger until `tailscale serve clear svc:<name>`.
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
