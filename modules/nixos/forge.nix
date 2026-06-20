_: {
  # forge — general / dev-utilities node. Bare-metal Lenovo P3 Tiny.
  # This round: attic (R2-backed nix cache) + AirPrint (added in later tasks).
  flake.nixosModules.forge =
    { config, ... }:
    let
      atticPort = 8080;
      # Same Cloudflare account as the restic R2 repo; dedicated cache bucket.
      r2Account = "14613cda02f216f5620eca979a286eaf";
      atticBucket = "attic";
    in
    {
      networking.hostName = "forge";

      users.users.${config.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
      identity.enableRootSshKeys = true;

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

      # --- Reverse proxy (caddy-lan) + UniFi self-registration ---
      services.caddyLan = {
        enable = true;
        proxies.attic = "127.0.0.1:${toString atticPort}";
        dynamicDns = {
          # unifi/* are set in secrets/forge.yaml, so publish attic.lan.kclj.io
          # into UniFi local DNS (otherwise the proxied cache isn't reachable
          # by name).
          enable = true;
          interface = "eno2"; # P3 Tiny on-board NIC (verified on forge)
        };
      };

      # --- AirPrint (CUPS + avahi; network printer, not USB) ---
      services.airprint.enable = true;

      system.stateVersion = "25.11";
    };
}
