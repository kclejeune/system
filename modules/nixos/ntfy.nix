_: {
  # ntfy-sh push-notification server, lifted out of gateway.nix. Self-contained
  # apart from sharing authelia's Fastmail SMTP creds (referenced as sops
  # placeholders that the host also declares).
  flake.nixosModules.ntfy =
    { config, ... }:
    let
      ntfyPort = 2586; # ntfy's conventional port (default :80 collides with nginx)
    in
    {
      # ntfy's own secrets, injected via the EnvironmentFile below (out of the
      # world-readable store): web_push_private_key (VAPID) + auth_users (bcrypt).
      sops.secrets."ntfy/web_push_private_key" = { };
      sops.secrets."ntfy/auth_users" = { };

      # ntfy-sh — self-hosted push notifications at https://ntfy.kclj.dev, fronted
      # by the NetBird proxy (overlay-only; see firewall comment). Non-secret
      # config is here (rendered to the
      # world-readable /etc/ntfy/server.yml); the VAPID private key, the bcrypt
      # auth-users, and the Fastmail SMTP creds are injected via the sops
      # EnvironmentFile, out of the store.
      services.ntfy-sh = {
        enable = true;
        settings = {
          base-url = "https://ntfy.kclj.dev";
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

          # Attachment blobs in the CacheDirectory; message cache in StateDirectory.
          attachment-cache-dir = "/var/cache/ntfy-sh";
          attachment-file-size-limit = "20M";
          attachment-total-size-limit = "10G";
          attachment-expiry-duration = "4h";
          cache-file = "/var/lib/ntfy-sh/cache.db";
          cache-duration = "24h";

          # Web push (public key is safe in the store; private key via env below).
          web-push-public-key = "BPdEZgJlsAC_xA7_ctmlQVcCJbC9y6eCIr2W48XKJTqEEQ1uMYnZOa84MwEzL-_lXDlyV1jYDSTd70eOQ1p5Igs";
          web-push-file = "/var/lib/ntfy-sh/webpush.db";
          web-push-email-address = "admin@kclj.io";

          # Outgoing email notifications via Fastmail — same submission host +
          # account as authelia; user/pass injected via the EnvironmentFile.
          smtp-sender-addr = "smtp.fastmail.com:587";
          smtp-sender-from = "noreply+ntfy@kclj.io";
        };
        environmentFile = config.sops.templates."ntfy.env".path;
      };
      # Attachment blobs live in a CacheDirectory the module doesn't declare.
      systemd.services.ntfy-sh.serviceConfig.CacheDirectory = "ntfy-sh";

      # Secrets for ntfy's EnvironmentFile, out of the world-readable store. SMTP
      # creds are shared with authelia's Fastmail account; the ntfy/* values must
      # be added to secrets/gateway.yaml.
      sops.templates."ntfy.env".content = ''
        NTFY_WEB_PUSH_PRIVATE_KEY=${config.sops.placeholder."ntfy/web_push_private_key"}
        NTFY_AUTH_USERS=${config.sops.placeholder."ntfy/auth_users"}
        NTFY_SMTP_SENDER_USER=${config.sops.placeholder."authelia/smtp_username"}
        NTFY_SMTP_SENDER_PASS=${config.sops.placeholder."authelia/smtp_password"}
      '';
    };
}
