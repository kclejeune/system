_: {
  # Traceway (APM / error tracking / session replay) as a pinned podman
  # container. Upstream ships no server binary release and isn't in nixpkgs —
  # only cosign-signed ghcr images cut several times a day — so a container
  # beats packaging the SvelteKit+Go+CGO/DuckDB build.
  #
  # Storage flavour is fixed by the image tag: `-duckdb` = SQLite main DB +
  # DuckDB telemetry DB, both under /data. Switching to `-sqlite` later keeps
  # the main DB (users/orgs/projects) but drops telemetry, so it's a decision
  # made up front. Blobs (source maps, session recordings, AI traces) go to an
  # S3 bucket (R2), so nothing but the two DB files lives on the host.
  flake.nixosModules.traceway =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.traceway;
      stateDir = "/var/lib/traceway";
      envTemplate = "traceway.env";
    in
    {
      options.services.traceway = {
        domain = lib.mkOption {
          type = lib.types.str;
          description = "Public hostname for the dashboard and ingest endpoints (nginx vhost + APP_BASE_URL).";
        };
        version = lib.mkOption {
          type = lib.types.str;
          description = "Upstream release (backend/v<version> tag). Image is ghcr.io/tracewayapp/traceway:v<version>-duckdb (amd64 only).";
        };
        port = lib.mkOption {
          type = lib.types.port;
          description = "Loopback port the container's :80 is published on for nginx.";
        };
        memoryLimit = lib.mkOption {
          type = lib.types.str;
          default = "2g";
          description = "podman --memory cap for the container.";
        };
        duckdbMemoryLimit = lib.mkOption {
          type = lib.types.str;
          default = "1GB";
          description = ''
            DUCKDB_MEMORY_LIMIT. DuckDB sizes its budget from host RAM, not the
            cgroup, so this must be set explicitly (~half of memoryLimit) or
            the backend is OOM-killed under ingest.
          '';
        };
        duckdbThreads = lib.mkOption {
          type = lib.types.ints.positive;
          default = 2;
        };
        retentionDays = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 30;
          description = "Telemetry row retention (SQLite + DuckDB). 0 disables pruning.";
        };
        s3 = {
          bucket = lib.mkOption { type = lib.types.str; };
          endpoint = lib.mkOption {
            type = lib.types.str;
            description = "S3 endpoint URL; setting it flips the client to path-style (R2/MinIO).";
          };
          region = lib.mkOption {
            type = lib.types.str;
            default = "auto";
          };
        };
        oidc = {
          discoveryUrl = lib.mkOption { type = lib.types.str; };
          clientId = lib.mkOption {
            type = lib.types.str;
            default = "traceway";
          };
          displayName = lib.mkOption {
            type = lib.types.str;
            default = "SSO";
          };
          roleClaim = lib.mkOption {
            type = lib.types.str;
            default = "groups";
          };
          roleMap = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.enum [
                "admin"
                "user"
                "readonly"
              ]
            );
            default = { };
            description = "Claim value -> Traceway role. Applied on every login; owner is never assigned automatically.";
          };
          disablePasswordLogin = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Hide the password form and block /api/login + /api/register. Enable once OIDC login is verified.";
          };
        };
        smtpFrom = lib.mkOption {
          type = lib.types.str;
          description = ''
            Bare sender address (no display name) — used verbatim as the SMTP
            envelope sender. Server + credentials come from the host's shared
            `smtp` module (config.smtp.*, sops smtp/{username,password}).
          '';
        };
      };

      config = {
        # jwt_secret: `openssl rand -hex 32`. s3_*: an R2 API token scoped to
        # Object Read & Write on the bucket. oidc_client_secret: plaintext of
        # the confidential client whose pbkdf2 hash lives in the Authelia
        # config (`authelia crypto hash generate pbkdf2 --variant sha512`).
        sops.secrets = {
          "traceway/jwt_secret" = { };
          # Unset, this derives from JWT_SECRET, so a JWT rotation would
          # break in-flight SSO logins.
          "traceway/oauth_session_secret" = { };
          "traceway/s3_access_key" = { };
          "traceway/s3_secret_key" = { };
          "traceway/oidc_client_secret" = { };
        };

        # Rendered out of the world-readable store; consumed only by the
        # container's EnvironmentFile. Non-secret knobs live here too so one
        # restartTrigger covers every config change.
        sops.templates.${envTemplate}.content = ''
          JWT_SECRET=${config.sops.placeholder."traceway/jwt_secret"}
          OAUTH_SESSION_SECRET=${config.sops.placeholder."traceway/oauth_session_secret"}
          APP_BASE_URL=https://${cfg.domain}

          # Unset means allow in self-hosted mode.
          SYNTHETICS_ALLOW_PRIVATE_TARGETS=false

          DUCKDB_MEMORY_LIMIT=${cfg.duckdbMemoryLimit}
          DUCKDB_THREADS=${toString cfg.duckdbThreads}
          SQLITE_RETENTION_DAYS=${toString cfg.retentionDays}
          DUCKDB_RETENTION_DAYS=${toString cfg.retentionDays}

          STORAGE_TYPE=s3
          S3_BUCKET=${cfg.s3.bucket}
          S3_REGION=${cfg.s3.region}
          S3_ENDPOINT=${cfg.s3.endpoint}
          S3_ACCESS_KEY=${config.sops.placeholder."traceway/s3_access_key"}
          S3_SECRET_KEY=${config.sops.placeholder."traceway/s3_secret_key"}

          OIDC_CLIENT_ID=${cfg.oidc.clientId}
          OIDC_CLIENT_SECRET=${config.sops.placeholder."traceway/oidc_client_secret"}
          OIDC_DISCOVERY_URL=${cfg.oidc.discoveryUrl}
          OIDC_DISPLAY_NAME=${cfg.oidc.displayName}
          OIDC_AUTO_CREATE_USERS=true
          OIDC_EXTRA_SCOPES=${cfg.oidc.roleClaim}
          OIDC_ROLE_CLAIM=${cfg.oidc.roleClaim}
          OIDC_ROLE_MAP=${builtins.toJSON cfg.oidc.roleMap}
          DISABLE_PASSWORD_LOGIN=${lib.boolToString cfg.oidc.disablePasswordLogin}

          SMTP_ENABLED=true
          SMTP_HOST=${config.smtp.host}
          SMTP_PORT=${toString config.smtp.port}
          SMTP_FROM=${cfg.smtpFrom}
          SMTP_USERNAME=${config.sops.placeholder."smtp/username"}
          SMTP_PASSWORD=${config.sops.placeholder."smtp/password"}
        '';

        # The image runs as root and only writes under /data (SQLite + DuckDB
        # files, WAL, DuckDB spill). A bind mount rather than a named volume
        # so the DBs sit at a fixed path for backup (`sqlite3 .backup`).
        systemd.tmpfiles.rules = [ "d ${stateDir} 0700 root root - -" ];

        virtualisation.oci-containers.containers.traceway = {
          image = "ghcr.io/tracewayapp/traceway:v${cfg.version}-duckdb";
          environmentFiles = [ config.sops.templates.${envTemplate}.path ];
          # Loopback-only publish; nginx is the sole ingress. Bridge networking
          # (not --network=host) keeps the app off the host's overlay
          # interfaces — its synthetic monitors and notification webhooks
          # can't reach the mesh, and it can't bind anything else on the host.
          ports = [ "127.0.0.1:${toString cfg.port}:80" ];
          volumes = [ "${stateDir}:/data" ];
          extraOptions = [
            "--memory=${cfg.memoryLimit}"
            "--cap-drop=ALL"
            "--cap-add=NET_BIND_SERVICE" # the image listens on :80 inside its netns
            "--read-only"
            # Go's os.TempDir and the source-map cache default to /tmp.
            "--tmpfs=/tmp:rw,noexec,nosuid,size=256m"
            "--security-opt=no-new-privileges:true"
          ];
        };

        # oci-containers only restarts on unit/image changes, not env-file
        # *content* changes — without this a sops/config edit is silently
        # inert until a manual restart.
        systemd.services.podman-traceway.restartTriggers = [
          config.sops.templates.${envTemplate}.content
        ];

        # Upstream's webhook sender is an unguarded http.Client with an
        # attacker-chosen URL, so drop routed container egress to private/
        # CGNAT/link-local ranges (Hetzner metadata was reachable without
        # this). Container→host traffic hits the input chain, not this hook,
        # and is already default-dropped there.
        networking.nftables.tables.traceway-egress = {
          family = "inet";
          content = ''
            chain forward {
              type filter hook forward priority filter - 10; policy accept;
              iifname "podman*" ip daddr { 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16 } drop
              iifname "podman*" ip6 daddr { ::1, fc00::/7, fe80::/10 } drop
            }
          '';
        };

        # Ingress. Ingest endpoints (project-token authed) are hit by SDKs
        # running at Cloudflare's edge and in end-user browsers, so they must
        # stay genuinely public and unthrottled per-IP — nimbus egresses from
        # shared Cloudflare IPs, and a per-IP limit_req would 429 bursty
        # ingest. The host is expected to add its own limit_req/limit_conn to
        # the dashboard location ("/") if it wants one.
        services.nginx.virtualHosts.${cfg.domain} =
          let
            upstream = "http://127.0.0.1:${toString cfg.port}";
            # The app trusts every X-Forwarded-For hop (no SetTrustedProxies),
            # so send only the real client address instead of nginx's
            # appending default. A location-level proxy_set_header cancels the
            # inherited recommendedProxySettings set, so restate it wholesale.
            proxyHeaders = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $remote_addr;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Forwarded-Host $host;
              proxy_set_header X-Forwarded-Server $hostname;
            '';
            proxyLoc = extra: {
              proxyPass = upstream;
              recommendedProxySettings = false;
              extraConfig = proxyHeaders + extra;
            };
            ingest = proxyLoc ''
              # Keep upstream keepalive despite the cancelled include.
              proxy_set_header Connection "";
              # OTLP/report batches and session-recording chunks can be large
              # and gzip'd; don't buffer them through nginx's temp files.
              proxy_request_buffering off;
            '';
          in
          {
            forceSSL = true;
            enableACME = true;
            # Source-map uploads and recording chunks exceed nginx's 1m default.
            #
            # The app sets no security headers itself and keeps its JWT in
            # localStorage. script-src needs 'unsafe-inline' (SvelteKit inline
            # bootstrap); connect-src 'self' still blocks exfil. An add_header
            # in any location below would stop these inheriting.
            extraConfig = ''
              client_max_body_size 64m;

              add_header Strict-Transport-Security "max-age=63072000" always;
              add_header X-Content-Type-Options "nosniff" always;
              add_header X-Frame-Options "DENY" always;
              add_header Referrer-Policy "no-referrer" always;
              add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; media-src 'self' blob:; worker-src 'self' blob:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'" always;
            '';
            locations = {
              "/" = proxyLoc "" // {
                proxyWebsockets = true;
              };
              "/api/report" = ingest;
              "/api/otel/" = ingest;
              "/api/profiles/ingest" = ingest;
            };
          };
      };
    };
}
