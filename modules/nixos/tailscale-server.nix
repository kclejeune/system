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
    { config, lib, ... }:
    let
      cfg = config.services.tailscale.server;
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

      config = {
        services.tailscale = {
          # Provision a Let's Encrypt cert for `tailscale serve` and let the
          # primary user drive `tailscale` without sudo (TS_PERMIT_CERT_UID +
          # --operator). Both are server-role concerns, off on laptops.
          permitCertUid = config.user.name;

          # Enable Tailscale Serve wherever the host actually declares services
          # to expose. Upstream asserts serve.services is non-empty when serve is
          # enabled, so a host that declares none simply leaves serve off — the
          # cert above is still provisioned for ad-hoc `tailscale serve`.
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
      };
    };
}
