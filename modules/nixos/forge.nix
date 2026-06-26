_: {
  # forge — general / dev-utilities node. Bare-metal Lenovo P3 Tiny.
  # This round: attic (R2-backed nix cache) + AirPrint (added in later tasks).
  flake.nixosModules.forge =
    { config, ... }:
    let
      atticPort = 8080;
      # Same Cloudflare account as the restic R2 repo; dedicated cache bucket.
      r2Account = config.site.cloudflareAccountId;
      atticBucket = "attic";
    in
    {
      networking.hostName = "forge";
      sops.defaultSopsFile = ../../secrets/forge.yaml;

      # --- attic (R2-backed nix binary cache) ---
      # environmentFile carries ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64 +
      # AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY (R2 S3 token). SQLite metadata
      # lives in /var/lib/atticd (swept by the backup module's /var/lib).
      sops.secrets."attic/env" = { };
      services.atticd = {
        enable = true;
        environmentFile = config.sops.secrets."attic/env".path;
        settings = {
          listen = "127.0.0.1:${toString atticPort}";
          storage = {
            type = "s3";
            region = "auto";
            bucket = atticBucket;
            endpoint = "https://${r2Account}.r2.cloudflarestorage.com";
          };
        };
      };

      # --- Reverse proxy (caddy-lan: ACME DNS-01) ---
      # forge.lan.kclj.io resolves via UniFi's local domain automatically.
      # attic has no matching client hostname, so it needs a UniFi Local DNS
      # Record -> forge for the cache to be reachable by name through caddy.
      # caddy-lan is enabled by homelab-node; just declare the proxy.
      services.caddyLan.proxies.attic = "127.0.0.1:${toString atticPort}";

      # --- AirPrint (CUPS + avahi; network printer, not USB) ---
      services.airprint.enable = true;
    };
}
