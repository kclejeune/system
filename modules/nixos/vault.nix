_: {
  # vault — data / storage node.
  flake.nixosModules.vault =
    { config, ... }:
    {
      networking.hostName = "vault";
      sops.defaultSopsFile = ../../secrets/vault.yaml;

      services.rustfsLan = {
        enable = true;
        buckets = [ "tfstate" ];

        # Key login stays as break-glass: OIDC depends on gateway being reachable.
        oidc = {
          enable = true;
          configUrl = "https://auth.${config.site.domain}";
        };
      };

      # Tailnet access for terraform off-LAN. 9001 serves S3 + STS + console;
      # without the caddy redirect the console is at /rustfs/console/.
      services.tailscale.serve.services = {
        s3.endpoints."tcp:443" = "http://127.0.0.1:9001";
      };

      services.sparklesLan.enable = true;

      # slurp is created through the UI; declared settings apply once it exists,
      # and changes made in the UI override them until reset.
      services.sparkles.settings.datasets.slurp.assistant = {
        enabled = true;
        ingest = true;
        send = "documents";
      };
      # Agent memory is named under https://kclj.io/sparkles/memory/, independent of
      # the host that serves it. The urn: pattern keeps any graphs imported before
      # the base moved. Consolidation proposes the facts that two sessions agree on
      # as a branch to review, and retention then drops session graphs whose facts
      # are all consolidated.
      services.sparkles.settings.datasets.slurp.memory = {
        imports.base = "https://kclj.io/sparkles/memory/import/";
        agentGraphs = [
          "https://kclj.io/sparkles/memory/import/*"
          "urn:x-sparkles:import/*"
        ];
        consolidatedGraph = "https://kclj.io/sparkles/memory/consolidated";
        consolidation.every = "1d";
        retention.after = "365d";
      };

      # /var/lib/rustfs and /var/lib/sparkles need snapshotting once backup is enabled.
    };
}
