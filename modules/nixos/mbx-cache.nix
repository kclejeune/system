_: {
  flake.nixosModules.mbx-cache =
    { config, ... }:
    let
      port = 8098;
    in
    {
      # The distroless image runs as uid 65532. PostgreSQL peer authentication
      # maps that uid to this host user through the mounted Unix socket.
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

      virtualisation.oci-containers.containers.mbx-cache = {
        image = "ghcr.io/jdx/mbx-cache:main@sha256:31eee649e9e2c489645382b2d2d72f177dd6ce882d6c92bfd8a462e537965035";
        environmentFiles = [ config.sops.templates."mbx-cache.env".path ];
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
        };
        volumes = [ "/run/postgresql:/run/postgresql" ];
        extraOptions = [
          "--network=host"
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges:true"
          "--read-only"
          "--tmpfs=/tmp:rw,noexec,nosuid"
        ];
      };
      systemd.services.podman-mbx-cache = {
        requires = [ "postgresql.service" ];
        after = [ "postgresql.service" ];
        restartTriggers = [ config.sops.templates."mbx-cache.env".content ];
      };
    };
}
