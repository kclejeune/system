_: {
  # ntfy push notifications; shares the host's SMTP account.
  flake.nixosModules.ntfy =
    { config, ... }:
    let
      ntfyPort = 2586; # ntfy's conventional port (default :80 collides with nginx)
    in
    {
      # Injected via EnvironmentFile to stay out of the store.
      sops.secrets."ntfy/web_push_private_key" = { };
      sops.secrets."ntfy/auth_users" = { };

      # Served at ntfy.kclj.dev via the NetBird proxy (wt0 only).
      services.ntfy-sh = {
        enable = true;
        settings = {
          base-url = "https://ntfy.${config.site.proxyDomain}";
          # The NetBird proxy dials the overlay IP; opened only on wt0.
          listen-http = ":${toString ntfyPort}";
          behind-proxy = true;
          upstream-base-url = "https://ntfy.sh";
          message-size-limit = "4096";
          keepalive-interval = "45s";

          # Login required, deny-all by default; only "up*" topics are writable
          # unauthenticated (the wildcard rule from server.yml).
          auth-default-access = "deny-all";
          enable-login = true;
          enable-signup = false;
          enable-reservations = true;
          require-login = true;
          auth-access = [ "*:up*:write-only" ];

          attachment-cache-dir = "/var/cache/ntfy-sh";
          attachment-file-size-limit = "20M";
          attachment-total-size-limit = "10G";
          attachment-expiry-duration = "4h";
          cache-file = "/var/lib/ntfy-sh/cache.db";
          cache-duration = "24h";

          # Public key only; the private key comes from the env file.
          web-push-public-key = "BPdEZgJlsAC_xA7_ctmlQVcCJbC9y6eCIr2W48XKJTqEEQ1uMYnZOa84MwEzL-_lXDlyV1jYDSTd70eOQ1p5Igs";
          web-push-file = "/var/lib/ntfy-sh/webpush.db";
          web-push-email-address = "admin@${config.site.domain}";

          smtp-sender-addr = "${config.smtp.host}:${toString config.smtp.port}";
          smtp-sender-from = "noreply+ntfy@${config.site.domain}";
        };
        environmentFile = config.sops.templates."ntfy.env".path;
      };
      # Attachment blobs live in a CacheDirectory the module doesn't declare.
      systemd.services.ntfy-sh.serviceConfig.CacheDirectory = "ntfy-sh";

      # The ntfy/* values must be in the host's sops file.
      sops.templates."ntfy.env".content = ''
        NTFY_WEB_PUSH_PRIVATE_KEY=${config.sops.placeholder."ntfy/web_push_private_key"}
        NTFY_AUTH_USERS=${config.sops.placeholder."ntfy/auth_users"}
        NTFY_SMTP_SENDER_USER=${config.sops.placeholder."smtp/username"}
        NTFY_SMTP_SENDER_PASS=${config.sops.placeholder."smtp/password"}
      '';
    };
}
