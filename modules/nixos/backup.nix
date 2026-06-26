_: {
  # Reusable restic → Cloudflare R2 backups. A host enrolls this module plus a
  # sops file carrying the three restic/* secrets below; the default `system`
  # job then snapshots the stateful dirs daily. Per-service jobs (tighter
  # retention, pre/post hooks for DB dumps, etc.) can be added by the host via
  # additional services.restic.backups.<name> entries.
  #
  # On NixOS the OS itself is reproducible from this flake, so "whole machine"
  # backup means the stateful directories — not a block-level image.
  flake.nixosModules.backup =
    { config, ... }:
    {
      sops.secrets = {
        # restic repository password (the encryption passphrase).
        "restic/password" = { };
        # Full repo URL incl. per-host path, kept out of the store, e.g.
        #   s3:https://<accountid>.r2.cloudflarestorage.com/<bucket>/haven
        "restic/repository" = { };
        # EnvironmentFile with the R2 S3 token:
        #   AWS_ACCESS_KEY_ID=...
        #   AWS_SECRET_ACCESS_KEY=...
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

        # Skip things that are reproducible, huge, or inconsistent if copied
        # while live — back those up via their own mechanisms (HAOS native
        # backups, DB dumps into a backed-up path), not raw file copies.
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
