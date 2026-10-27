_: {
  flake.nixosModules.mbx-cache =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      port = 8098;
    in
    {
      # Retain the former container uid so the native migration does not change
      # the service identity. PostgreSQL peer authentication maps this account
      # to the database role below.
      users.users.mbx-cache = {
        isSystemUser = true;
        uid = 65532;
        group = "mbx-cache";
      };
      users.groups.mbx-cache = { };

      services.postgresql = {
        enable = true;
        ensureDatabases = [ "mbx_cache" ];
        # The server runs migrations at startup and needs to own its database.
        ensureUsers = [
          {
            name = "mbx_cache";
            ensureDBOwnership = true;
          }
        ];
        authentication = ''
          local mbx_cache mbx_cache peer map=mbx-cache
        '';
        identMap = ''
          mbx-cache mbx-cache mbx_cache
        '';
      };

      sops.secrets."mbx-cache/token" = { };
      # TODO: replace these with an R2 credential scoped only to mbx-cache.
      # Currently shared with Traceway and the R2 backup credential.
      sops.secrets."mbx-cache/s3_access_key" = { };
      sops.secrets."mbx-cache/s3_secret_key" = { };
      sops.templates."mbx-cache.env".content = ''
        MBX_CACHE_TOKENS_JSON=[{"token":"${
          config.sops.placeholder."mbx-cache/token"
        }","read":["kclejeune/*"],"write":["kclejeune/*"]}]
        AWS_ACCESS_KEY_ID=${config.sops.placeholder."mbx-cache/s3_access_key"}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."mbx-cache/s3_secret_key"}
      '';

      systemd.services.mbx-cache = {
        description = "Mr Boxington remote build cache";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        requires = [ "postgresql.service" ];
        after = [
          "network-online.target"
          "postgresql.service"
        ];
        conflicts = [ "podman-mbx-cache.service" ];
        restartTriggers = [ config.sops.templates."mbx-cache.env".content ];
        environment = {
          MBX_CACHE_LISTEN = "0.0.0.0:${toString port}";
          MBX_CACHE_DATABASE_URL = "postgres://mbx_cache@localhost/mbx_cache?host=/run/postgresql";
          MBX_CACHE_STORAGE = "s3";
          MBX_CACHE_S3_BUCKET = "mbx-cache";
          MBX_CACHE_S3_PREFIX = "mbx-cache/v1";
          MBX_CACHE_S3_ENDPOINT = "https://${config.site.cloudflareAccountId}.r2.cloudflarestorage.com";
          MBX_CACHE_S3_REGION = "auto";
          MBX_CACHE_S3_PATH_STYLE = "true";
          MBX_CACHE_OIDC_PROVIDERS_JSON = builtins.toJSON [
            {
              issuer = "https://token.actions.githubusercontent.com";
              audiences = [ "https://mbx.kclj.dev" ];
              rules = [
                {
                  claims = {
                    repository = "kclejeune/sparkles";
                    repository_owner_id = "11745400";
                    repository_id = "1396834489";
                  };
                  read = [ "kclejeune/sparkles" ];
                  write = [ ];
                }
                {
                  # GitHub does not include the PR's source repository in its
                  # OIDC claims. Keep fork PR write tokens disabled in GitHub;
                  # the workflow also selects this cache only for same-repo PRs.
                  claims = {
                    repository = "kclejeune/sparkles";
                    repository_owner_id = "11745400";
                    repository_id = "1396834489";
                    event_name = "pull_request";
                  };
                  read = [ "kclejeune/sparkles" ];
                  write = [ "kclejeune/sparkles" ];
                }
                {
                  # Claim values match exactly; the server cannot restrict
                  # this grant to the workflow's release-tag prefixes.
                  claims = {
                    repository = "kclejeune/sparkles";
                    repository_owner_id = "11745400";
                    repository_id = "1396834489";
                    event_name = "push";
                    ref_type = "tag";
                  };
                  read = [ "kclejeune/sparkles" ];
                  write = [ "kclejeune/sparkles" ];
                }
                {
                  claims = {
                    repository = "kclejeune/sparkles";
                    repository_owner_id = "11745400";
                    repository_id = "1396834489";
                    event_name = "push";
                    ref_type = "branch";
                    ref = "refs/heads/main";
                  };
                  read = [ "kclejeune/sparkles" ];
                  write = [ "kclejeune/sparkles" ];
                }
              ];
            }
          ];
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        };
        serviceConfig = {
          ExecStart = lib.getExe pkgs.mbx-cache;
          EnvironmentFile = config.sops.templates."mbx-cache.env".path;
          User = "mbx-cache";
          Group = "mbx-cache";
          Restart = "always";
          RestartSec = "5s";
          TimeoutStopSec = "30s";

          # Match the former read-only, capability-free container and further
          # isolate the native process from host devices and kernel state.
          NoNewPrivileges = true;
          PrivateDevices = true;
          # tmpfs defaults to root-owned 0755. Uploads are staged in /tmp by
          # the unprivileged service before their digests are checked and sent to R2.
          TemporaryFileSystem = [
            "/tmp:rw,nosuid,nodev,noexec,mode=1777,size=6G"
            "/var/tmp:rw,nosuid,nodev,noexec,mode=1777,size=64M"
          ];
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
          ProtectProc = "invisible";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          SystemCallFilter = [ "@system-service" ];
          SystemCallArchitectures = "native";
          UMask = "0077";
        };
      };
    };
}
