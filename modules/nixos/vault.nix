_: {
  # vault — data / storage node.
  flake.nixosModules.vault =
    { config, ... }:
    {
      networking.hostName = "vault";
      sops.defaultSopsFile = ../../secrets/vault.yaml;

      services.rustfsLan = {
        enable = true;
        buckets = [ "tfstate" ];

        # Key login stays as break-glass: OIDC depends on gateway being reachable.
        oidc = {
          enable = true;
          configUrl = "https://auth.${config.site.domain}";
        };
      };

      # Tailnet access for terraform off-LAN. 9001 serves S3 + STS + console;
      # without the caddy redirect the console is at /rustfs/console/.
      services.tailscale.serve.services = {
        s3.endpoints."tcp:443" = "http://127.0.0.1:9001";
      };

      # /var/lib/rustfs needs snapshotting once backup is enabled.
    };
}
