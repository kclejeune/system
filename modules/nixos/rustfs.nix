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
      };

      config = lib.mkIf cfg.enable {
        sops.secrets."rustfs/access-key" = { };
        sops.secrets."rustfs/secret-key" = { };

        # systemd reads EnvironmentFile only at process start, so a rotated key
        # needs a restart, not a reload — same as caddy-lan's token.
        sops.templates."rustfs.env" = {
          content = ''
            RUSTFS_ACCESS_KEY=${config.sops.placeholder."rustfs/access-key"}
            RUSTFS_SECRET_KEY=${config.sops.placeholder."rustfs/secret-key"}
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
