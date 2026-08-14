_: {
  # S3-compatible object storage, backing the Terraform remote state in
  # ../../terraform — state holds provider credentials in plaintext, so it
  # stays on hardware we own.
  #
  # One vhost, <subdomain>, serving both the S3 API and the admin console.
  # RUSTFS_CONSOLE_ADDRESS does NOT create a console-only listener: that port
  # answers the full S3 + STS surface too and merely adds the UI under
  # /rustfs/console/. Verified — GET / and POST / return byte-identical S3 and
  # STS responses on both ports. Splitting them across two names bought nothing
  # and cost a redirect that swallowed the console's STS login POST.
  #
  # <subdomain> has no matching DHCP client hostname, so it needs a UniFi *Local
  # DNS Record* -> this host before it resolves. Same caveat as forge's cups
  # vhost; see the caddy-lan module header.
  flake.nixosModules.rustfs =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.rustfsLan;
      s3Port = 9000;
      consolePort = 9001;

      # Backend route, not a console route — every path under /rustfs/console/
      # returns the SPA shell, so this cannot be discovered by probing. Must
      # match the redirect_uris registered for the Authelia client in
      # gateway.nix; the trailing segment is the OIDC provider name.
      callbackPath = "/rustfs/admin/v3/oidc/callback/default";
    in
    {
      options.services.rustfsLan = {
        enable = lib.mkEnableOption "RustFS object storage fronted by caddy-lan";

        subdomain = lib.mkOption {
          type = lib.types.str;
          default = "s3";
          description = "caddy-lan subdomain serving both the S3 API and the console.";
        };

        buckets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "tfstate" ];
          description = ''
            Buckets created on activation if absent. An existing bucket is left
            untouched — never recreated, never emptied.
          '';
        };

        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/rustfs";
          description = "Backing directory for object data.";
        };

        oidc = {
          enable = lib.mkEnableOption "OIDC login on the console, alongside key login";

          configUrl = lib.mkOption {
            type = lib.types.str;
            example = "https://auth.kclj.io";
            description = "Issuer base URL; RustFS appends the discovery path.";
          };

          clientId = lib.mkOption {
            type = lib.types.str;
            default = "rustfs";
            description = "Must match the Authelia client_id on gateway.";
          };

          displayName = lib.mkOption {
            type = lib.types.str;
            default = "Authelia";
            description = "Label on the console's OIDC login button.";
          };

          scopes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "openid"
              "profile"
              "email"
              "groups"
            ];
            description = "Requested scopes. Emitted comma-separated, not space-separated.";
          };

          rolePolicy = lib.mkOption {
            type = lib.types.str;
            default = "consoleAdmin";
            description = ''
              RustFS policy granted to everyone who authenticates. Flat, like
              the Incus client on haven — anyone Authelia lets through is an
              admin, so the access gate is the client's authorization_policy,
              not anything here. Switch to groupsClaim-driven mapping only
              after the matching policies exist inside RustFS.
            '';
          };

          secretKey = lib.mkOption {
            type = lib.types.str;
            default = "rustfs/oidc-client-secret";
            description = ''
              sops key holding the plaintext client secret. Authelia keeps only
              the pbkdf2 hash, so the two rotate in lockstep.
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets = {
          "rustfs/access-key" = { };
          "rustfs/secret-key" = { };
        }
        // lib.optionalAttrs cfg.oidc.enable { ${cfg.oidc.secretKey} = { }; };

        # systemd reads EnvironmentFile only at process start, so a rotated key
        # needs a restart, not a reload — same as caddy-lan's token.
        sops.templates."rustfs.env" = {
          content = ''
            RUSTFS_ACCESS_KEY=${config.sops.placeholder."rustfs/access-key"}
            RUSTFS_SECRET_KEY=${config.sops.placeholder."rustfs/secret-key"}
          ''
          + lib.optionalString cfg.oidc.enable ''
            RUSTFS_IDENTITY_OPENID_CLIENT_SECRET=${config.sops.placeholder.${cfg.oidc.secretKey}}
          '';
          restartUnits = [ "rustfs.service" ];
        };

        services.rustfs = {
          enable = true;
          environmentFile = config.sops.templates."rustfs.env".path;
          settings = {
            # Loopback-only: caddy-lan is the sole ingress. Binding 0.0.0.0
            # would put the admin console on an open LAN port.
            RUSTFS_ADDRESS = "127.0.0.1:${toString s3Port}";
            RUSTFS_CONSOLE_ENABLE = "true";
            RUSTFS_CONSOLE_ADDRESS = "127.0.0.1:${toString consolePort}";
            # Console redirects and OIDC callbacks are built from this, so it
            # must be the public name caddy serves, not the loopback listener.
            RUSTFS_BROWSER_REDIRECT_URL = "https://${cfg.subdomain}.${config.services.caddyLan.baseDomain}";
            RUSTFS_VOLUMES = cfg.dataDir;
            # Must match the region the s3 backend sends, or sigv4 fails.
            RUSTFS_REGION = "us-east-1";
          }
          // lib.optionalAttrs cfg.oidc.enable {
            # "on"/"off", not "true"/"false".
            RUSTFS_IDENTITY_OPENID_ENABLE = "on";
            RUSTFS_IDENTITY_OPENID_CONFIG_URL = cfg.oidc.configUrl;
            RUSTFS_IDENTITY_OPENID_CLIENT_ID = cfg.oidc.clientId;
            RUSTFS_IDENTITY_OPENID_DISPLAY_NAME = cfg.oidc.displayName;
            RUSTFS_IDENTITY_OPENID_SCOPES = lib.concatStringsSep "," cfg.oidc.scopes;
            RUSTFS_IDENTITY_OPENID_ROLE_POLICY = cfg.oidc.rolePolicy;

            # `default` is the provider name; suffixed vars
            # (…_CLIENT_ID_<name>) would give a second provider at
            # /callback/<name>. DYNAMIC=on derives the redirect from the
            # request host, which is what lets one client serve both the
            # lan.kclj.io and tailnet origins — Authelia's registered
            # redirect_uris stay the actual allowlist.
            RUSTFS_IDENTITY_OPENID_REDIRECT_URI = "https://${cfg.subdomain}.${config.services.caddyLan.baseDomain}${callbackPath}";
            RUSTFS_IDENTITY_OPENID_REDIRECT_URI_DYNAMIC = "on";

            RUSTFS_IDENTITY_OPENID_USERNAME_CLAIM = "preferred_username";
            RUSTFS_IDENTITY_OPENID_EMAIL_CLAIM = "email";
            RUSTFS_IDENTITY_OPENID_GROUPS_CLAIM = "groups";
          };
        };

        # consolePort, not s3Port: it is the superset listener (S3 + STS + UI).
        services.caddyLan.proxies.${cfg.subdomain} = "127.0.0.1:${toString consolePort}";

        # `/` is a live S3/STS endpoint on this vhost, so the convenience
        # redirect has to catch browsers only and let API traffic through:
        #   - GET only          — the console's own login is an STS POST to /
        #   - Accept: text/html — S3 SDKs never send it; browsers always do
        #   - no Authorization  — a signed ListBuckets must reach the handler
        # Drop any one of those and either the login form or `aws s3 ls` breaks.
        services.caddyLan.extraDirectives.${cfg.subdomain} = ''
          @browserRoot {
            method GET
            path /
            header Accept *text/html*
            not header Authorization *
          }
          redir @browserRoot /rustfs/console/ 302
        '';

        systemd.services.rustfs-buckets = lib.mkIf (cfg.buckets != [ ]) {
          description = "Create RustFS buckets";
          after = [ "rustfs.service" ];
          requires = [ "rustfs.service" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            EnvironmentFile = config.sops.templates."rustfs.env".path;
            DynamicUser = true;
          };

          script = ''
            export AWS_ACCESS_KEY_ID="$RUSTFS_ACCESS_KEY"
            export AWS_SECRET_ACCESS_KEY="$RUSTFS_SECRET_KEY"
            export AWS_DEFAULT_REGION=us-east-1
            endpoint="http://127.0.0.1:${toString s3Port}"

            # rustfs.service is Type=notify, but the S3 layer can still lag the
            # readiness ping.
            for _ in $(seq 1 30); do
              ${lib.getExe pkgs.awscli2} --endpoint-url "$endpoint" s3api list-buckets >/dev/null 2>&1 && break
              sleep 1
            done

            # create-bucket errors on an existing bucket, so probe first.
            ${lib.concatMapStringsSep "\n" (bucket: ''
              if ${lib.getExe pkgs.awscli2} --endpoint-url "$endpoint" \
                   s3api head-bucket --bucket ${lib.escapeShellArg bucket} >/dev/null 2>&1; then
                echo "bucket ${bucket} already exists"
              else
                echo "creating bucket ${bucket}"
                ${lib.getExe pkgs.awscli2} --endpoint-url "$endpoint" \
                  s3api create-bucket --bucket ${lib.escapeShellArg bucket}
              fi
            '') cfg.buckets}
          '';
        };
      };
    };
}
