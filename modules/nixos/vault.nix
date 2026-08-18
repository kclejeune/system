_: {
  # vault — data / storage node. Bare-metal Lenovo P3 Tiny. Syncthing / DBs /
  # NFS land later. The common P3 stack (user, caddy-lan, VPN, state version)
  # comes from flake.nixosModules.homelab-node; this file holds only
  # vault-specifics.
  flake.nixosModules.vault = _: {
    networking.hostName = "vault";
    sops.defaultSopsFile = ../../secrets/vault.yaml;

    services.rustfsLan = {
      enable = true;
      buckets = [ "tfstate" ];

      # Key login stays enabled alongside this: auth.kclj.io is on gateway, so
      # OIDC-only would make the console unreachable whenever Hetzner or the
      # tunnel is down. The access/secret pair is the break-glass path.
      oidc = {
        enable = true;
        configUrl = "https://auth.kclj.io";
      };
    };

    # Also on the tailnet, so terraform works off-LAN without exposing the
    # bucket to the internet — and without the UniFi Local DNS Record the
    # caddy-lan vhost needs.
    # 9001 is the superset listener (S3 + STS + console UI), so one service
    # covers both. No caddy in this path, so the browser redirect the caddy-lan
    # vhost adds doesn't apply — over the tailnet the console is at
    # /rustfs/console/ explicitly, and a bare / hits the S3 handler and 403s.
    services.tailscale.serve.services = {
      s3.endpoints."tcp:443" = "http://127.0.0.1:9001";
    };

    # backup stays off in flake.nix until real restic/* creds exist; when it
    # lands, /var/lib/rustfs is the path that needs snapshotting.
  };
}
