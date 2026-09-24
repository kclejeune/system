_: {
  # restic -> Cloudflare R2. Hosts supply restic/* in sops; the `system` job
  # snapshots the stateful dirs daily (the OS itself is reproducible).
  flake.nixosModules.backup =
    { config, ... }:
    {
      sops.secrets = {
        "restic/password" = { };
        # Full repo URL, e.g. s3:https://<accountid>.r2.cloudflarestorage.com/<bucket>/haven
        "restic/repository" = { };
        # EnvironmentFile: AWS_ACCESS_KEY_ID=… and AWS_SECRET_ACCESS_KEY=…
        "restic/r2-credentials" = { };
      };

      services.restic.backups.system = {
        passwordFile = config.sops.secrets."restic/password".path;
        repositoryFile = config.sops.secrets."restic/repository".path;
        environmentFile = config.sops.secrets."restic/r2-credentials".path;
        initialize = true;

        paths = [
          "/var/lib"
          "/home"
          "/root"
        ];

        # Reproducible, huge, or live-inconsistent data; those use their own backups.
        exclude = [
          "/var/lib/incus"
          "/var/lib/containers"
          "/var/lib/docker"
          "/var/lib/private/*/cache"
          "**/.cache"
        ];

        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];

        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      };
    };
}
