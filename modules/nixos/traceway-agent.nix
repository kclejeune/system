_: {
  # OpenTelemetry Collector shipping journald logs, host metrics and local
  # apps' OTLP to Traceway. The contrib collector rather than Traceway's
  # install.sh agent so it stays under Nix. Only secret: `traceway/ingest_token`
  # from the host's sops file.
  flake.nixosModules.traceway-agent =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.traceway.agent;
      envTemplate = "traceway-agent.env";
    in
    {
      options.services.traceway.agent = {
        enable = lib.mkEnableOption "the Traceway OpenTelemetry host agent" // {
          default = true;
        };

        url = lib.mkOption {
          type = lib.types.str;
          default = "https://traceway.kclj.io";
          description = "Traceway instance; the exporter appends /api/otel/v1/*.";
        };

        serviceName = lib.mkOption {
          type = lib.types.str;
          default = config.networking.hostName;
          defaultText = lib.literalExpression "config.networking.hostName";
          description = ''
            service.name stamped on the journal and host-metric streams. Traceway
            shows it as the Server Name and keys host metrics on it, so it must
            be unique per host.
          '';
        };

        tokenSecret = lib.mkOption {
          type = lib.types.str;
          default = "traceway/ingest_token";
          description = "sops key holding the project ingest token.";
        };

        otlpPort = lib.mkOption {
          type = lib.types.port;
          default = 4318;
          description = "Loopback OTLP/HTTP receiver port for local apps.";
        };

        otlpEndpoint = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:${toString cfg.otlpPort}";
          readOnly = true;
          description = "Base URL local apps export to (no signal suffix).";
        };

        journal = {
          priority = lib.mkOption {
            type = lib.types.str;
            default = "info";
            description = "Lowest journal priority shipped (journalctl -p).";
          };

          excludeUnits = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "rustfs.service" ];
            description = ''
              Units dropped from the journal pipeline. For apps that export
              their own logs over OTLP, so the same line isn't shipped twice.
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets.${cfg.tokenSecret} = { };

        sops.templates.${envTemplate} = {
          content = ''
            TRACEWAY_TOKEN=${config.sops.placeholder.${cfg.tokenSecret}}
          '';
          restartUnits = [ "opentelemetry-collector.service" ];
        };

        # The collector always drops its own unit: its export-failure logs
        # would otherwise be shipped by the pipeline that failed.
        services.traceway.agent.journal.excludeUnits = [ "opentelemetry-collector.service" ];

        services.opentelemetry-collector = {
          enable = true;
          package = pkgs.opentelemetry-collector-contrib;
          settings = {
            receivers = {
              journald = {
                priority = cfg.journal.priority;
                start_at = "end";
                # Non-UTF-8 MESSAGE fields arrive as byte arrays otherwise.
                convert_message_bytes = true;
              };

              hostmetrics = {
                collection_interval = "60s";
                scrapers = {
                  # utilization gauges are opt-in; the dashboard template
                  # charts them rather than the raw time counters.
                  cpu.metrics."system.cpu.utilization".enabled = true;
                  memory.metrics."system.memory.utilization".enabled = true;
                  load = { };
                  disk = { };
                  filesystem = { };
                  network = { };
                };
              };

              otlp.protocols.http.endpoint = "127.0.0.1:${toString cfg.otlpPort}";
            };

            processors = {
              batch = {
                send_batch_size = 1024;
                # Traceway reads at most 10 MB per request; keep batches well
                # under it even with long journal lines.
                send_batch_max_size = 2048;
                timeout = "5s";
              };

              # The journald receiver puts the whole journal entry in the body
              # as a map and sets no severity. Lift the fields worth filtering
              # on into attributes, map syslog PRIORITY onto OTel severity
              # (Traceway reads severity_text), and leave MESSAGE as the body.
              "transform/journal".log_statements = [
                {
                  context = "log";
                  statements =
                    let
                      sev = prio: level: [
                        ''set(severity_number, SEVERITY_NUMBER_${level}) where body["PRIORITY"] == "${prio}"''
                        ''set(severity_text, "${level}") where body["PRIORITY"] == "${prio}"''
                      ];
                    in
                    [
                      ''set(attributes["systemd.unit"], body["_SYSTEMD_UNIT"]) where body["_SYSTEMD_UNIT"] != nil''
                      ''set(attributes["syslog.identifier"], body["SYSLOG_IDENTIFIER"]) where body["SYSLOG_IDENTIFIER"] != nil''
                      ''set(attributes["process.pid"], body["_PID"]) where body["_PID"] != nil''
                    ]
                    ++ sev "0" "FATAL"
                    ++ sev "1" "FATAL"
                    ++ sev "2" "FATAL"
                    ++ sev "3" "ERROR"
                    ++ sev "4" "WARN"
                    ++ sev "5" "INFO"
                    ++ sev "6" "INFO"
                    ++ sev "7" "DEBUG"
                    ++ [ ''set(body, body["MESSAGE"]) where body["MESSAGE"] != nil'' ];
                }
              ];

              "filter/journal".logs.log_record = map (
                unit: ''attributes["systemd.unit"] == "${unit}"''
              ) cfg.journal.excludeUnits;

              "resource/host".attributes = [
                {
                  key = "service.name";
                  value = cfg.serviceName;
                  action = "upsert";
                }
                {
                  key = "host.name";
                  value = config.networking.hostName;
                  action = "upsert";
                }
              ];
            };

            exporters."otlphttp/traceway" = {
              endpoint = "${cfg.url}/api/otel";
              # Expanded by the collector from the sops-rendered EnvironmentFile.
              headers.Authorization = "Bearer \${env:TRACEWAY_TOKEN}";
              compression = "gzip";
            };

            # Local OTLP apps set their own service.name, so they bypass the
            # host resource processor and the journal transform.
            service.pipelines = {
              "logs/journal" = {
                receivers = [ "journald" ];
                processors = [
                  "transform/journal"
                  "filter/journal"
                  "resource/host"
                  "batch"
                ];
                exporters = [ "otlphttp/traceway" ];
              };
              "metrics/host" = {
                receivers = [ "hostmetrics" ];
                processors = [
                  "resource/host"
                  "batch"
                ];
                exporters = [ "otlphttp/traceway" ];
              };
              "logs/otlp" = {
                receivers = [ "otlp" ];
                processors = [ "batch" ];
                exporters = [ "otlphttp/traceway" ];
              };
              "metrics/otlp" = {
                receivers = [ "otlp" ];
                processors = [ "batch" ];
                exporters = [ "otlphttp/traceway" ];
              };
              traces = {
                receivers = [ "otlp" ];
                processors = [ "batch" ];
                exporters = [ "otlphttp/traceway" ];
              };
            };
          };
        };

        systemd.services.opentelemetry-collector = {
          # The journald receiver shells out to journalctl.
          path = [ pkgs.systemd ];
          serviceConfig = {
            EnvironmentFile = config.sops.templates.${envTemplate}.path;
            MemoryMax = "512M";
          };
        };
      };
    };
}
