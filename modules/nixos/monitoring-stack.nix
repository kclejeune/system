_: {
  # Observability stack lifted out of gateway.nix: Loki + Alloy (logs),
  # node-exporter + Prometheus + Alertmanager (metrics), Karma + Grafana (UIs).
  # A leaf — nothing else on the host references these — so it extracts cleanly.
  # Scrape-target ports for OTHER gateway services (authelia/netbird/crowdsec
  # metrics) are mirrored in the let below and must track those services' ports.
  flake.nixosModules.monitoring-stack =
    { config, ... }:
    let
      lokiPort = 3100;
      grafanaPort = 3000;
      prometheusPort = 9090;
      alertmanagerPort = 9093;
      karmaPort = 8082;
      netbirdProxyDomain = "kclj.dev";
      # Scrape targets owned by other gateway services — keep in sync with them:
      autheliaMetricsPort = 9959;
      netbirdMgmtMetricsPort = 9190;
      netbirdSignalMetricsPort = 9191;
      crowdsecMetricsPort = 9060;
      mkScrapeConfig = job_name: target: {
        inherit job_name;
        static_configs = [ { targets = [ target ]; } ];
      };
    in
    {
      # Grafana admin secret (moved with grafana out of gateway's sops block).
      sops.secrets."grafana/secret_key".owner = "grafana";

      # Loki - log aggregation
      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
          # Loki has no auth and ingests sensitive data (auth events, client
          # IPs). Only Grafana + Alloy consume it, both over loopback, so bind it
          # to 127.0.0.1 — never all interfaces — so the firewall isn't the sole
          # thing keeping it off the public NIC and the trusted overlay.
          server.http_listen_address = "127.0.0.1";
          server.http_listen_port = lokiPort;

          common = {
            path_prefix = "/var/lib/loki";
            replication_factor = 1;
            ring.kvstore.store = "inmemory";
          };

          schema_config.configs = [
            {
              from = "2024-01-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];

          storage_config.filesystem.directory = "/var/lib/loki/chunks";

          limits_config = {
            retention_period = "30d";
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
          };

          compactor = {
            working_directory = "/var/lib/loki/compactor";
            delete_request_store = "filesystem";
            retention_enabled = true;
          };
        };
      };

      # Grafana Alloy - collects logs and metrics, ships to Loki
      services.alloy = {
        enable = true;
        # UI stays on loopback (default 127.0.0.1:12345): the pipeline carries
        # raw logs (auth events, client IPs, request paths) and Alloy's
        # live-debugging UI can surface them, so it's not exposed to the overlay.
        # Reach it for debugging via `ssh -L 12345:127.0.0.1:12345`.
        extraFlags = [ "--stability.level=generally-available" ];
      };

      environment.etc."alloy/config.alloy".text = ''
        // Scrape journald logs (sshd, crowdsec, authelia, nginx, systemd)
        // Route authelia's JSON-on-stdout through a parser stage that extracts
        // level/remote_ip as labels and tags the stream with job="authelia".
        loki.source.journal "journald" {
          forward_to = [loki.process.journal.receiver]
          relabel_rules = loki.relabel.journal.rules
        }

        loki.relabel "journal" {
          forward_to = []

          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }
          rule {
            source_labels = ["__journal__hostname"]
            target_label  = "hostname"
          }
        }

        loki.process "journal" {
          forward_to = [loki.write.local.receiver]

          stage.match {
            selector = "{unit=\"authelia-main.service\"}"

            stage.json {
              expressions = {
                level      = "level",
                msg        = "msg",
                remote_ip  = "remote_ip",
                method     = "method",
                path       = "path",
              }
            }

            stage.labels {
              values = {
                level     = "",
                remote_ip = "",
              }
            }

            stage.static_labels {
              values = {
                job = "authelia",
              }
            }
          }
        }

        // Scrape nginx access log
        local.file_match "nginx_log" {
          path_targets = [
            {"__path__" = "/var/log/nginx/access.log"},
            {"__path__" = "/var/log/nginx/error.log"},
          ]
        }

        loki.source.file "nginx" {
          targets    = local.file_match.nginx_log.targets
          forward_to = [loki.write.local.receiver]
        }

        // Write logs to Loki
        loki.write "local" {
          endpoint {
            url = "http://127.0.0.1:${toString lokiPort}/loki/api/v1/push"
          }
        }
      '';

      # Node exporter - system metrics
      services.prometheus.exporters.node = {
        enable = true;
        listenAddress = "127.0.0.1";
        enabledCollectors = [
          "cpu"
          "diskstats"
          "filesystem"
          "loadavg"
          "meminfo"
          "netdev"
          "stat"
          "time"
          "uname"
          "systemd"
        ];
      };

      # Prometheus - metrics scraping
      services.prometheus = {
        enable = true;
        # No built-in auth; overlay-only (not opened publicly; see firewall comment).
        listenAddress = "0.0.0.0";
        port = prometheusPort;
        retentionTime = "30d";
        scrapeConfigs = [
          {
            job_name = "authelia";
            metrics_path = "/";
            static_configs = [ { targets = [ "127.0.0.1:${toString autheliaMetricsPort}" ]; } ];
          }
          (mkScrapeConfig "node" "127.0.0.1:${toString config.services.prometheus.exporters.node.port}")
          (mkScrapeConfig "cloudflared" "127.0.0.1:2000")
          (mkScrapeConfig "netbird-management" "127.0.0.1:${toString netbirdMgmtMetricsPort}")
          (mkScrapeConfig "netbird-signal" "127.0.0.1:${toString netbirdSignalMetricsPort}")
          (mkScrapeConfig "crowdsec" "127.0.0.1:${toString crowdsecMetricsPort}")
        ];
        alertmanagers = [
          { static_configs = [ { targets = [ "127.0.0.1:${toString alertmanagerPort}" ]; } ]; }
        ];
        # Starter alert rules so the stack has live alerts to view/silence across
        # Prometheus (/alerts), Alertmanager, Karma, and Grafana. Expand as needed
        # — Grafana-authored rules route to the same Alertmanager (see datasource).
        rules = [
          (builtins.toJSON {
            groups = [
              {
                name = "gateway-basics";
                rules = [
                  {
                    alert = "InstanceDown";
                    expr = "up == 0";
                    for = "5m";
                    labels.severity = "critical";
                    annotations.summary = "Scrape target {{ $labels.job }} ({{ $labels.instance }}) is down";
                  }
                  {
                    alert = "SystemdUnitFailed";
                    expr = ''node_systemd_unit_state{state="failed"} == 1'';
                    for = "5m";
                    labels.severity = "warning";
                    annotations.summary = "systemd unit {{ $labels.name }} is failed on {{ $labels.instance }}";
                  }
                  {
                    alert = "DiskSpaceLow";
                    expr = ''node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay"} / node_filesystem_size_bytes < 0.10'';
                    for = "15m";
                    labels.severity = "warning";
                    annotations.summary = "Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} has <10% free";
                  }
                ];
              }
            ];
          })
        ];
        # No built-in auth; overlay-only (not opened publicly; see firewall comment).
        alertmanager = {
          enable = true;
          listenAddress = "0.0.0.0";
          port = alertmanagerPort;
          webExternalUrl = "https://alerts.kclj.dev";
          configuration = {
            # Minimal no-op: alerts still show as active (so karma can display
            # them), but nothing is notified yet. Add receivers/routes for notifs.
            route.receiver = "null";
            receivers = [ { name = "null"; } ];
          };
        };
      };

      # Karma — dashboard over Alertmanager, no built-in auth. Overlay-only
      # (not opened publicly; see firewall comment).
      services.karma = {
        enable = true;
        settings = {
          listen = {
            address = "0.0.0.0";
            port = karmaPort;
          };
          alertmanager.servers = [
            {
              name = "gateway";
              uri = "http://127.0.0.1:${toString alertmanagerPort}";
            }
          ];
        };
      };

      # Grafana - dashboards and visualization
      services.grafana = {
        enable = true;
        settings = {
          server = {
            # Overlay-only (not opened publicly; see firewall comment); the
            # auth.proxy whitelist below pins header trust to the NetBird range.
            http_addr = "0.0.0.0";
            http_port = grafanaPort;
            domain = netbirdProxyDomain;
            root_url = "https://grafana.${netbirdProxyDomain}";
          };
          security = {
            admin_user = "admin";
            secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
          };
          # SSO via the NetBird proxy: it authenticates the user and stamps the
          # email into X-NetBird-User. whitelist pins header trust to the NetBird
          # CGNAT range (100.64.0.0/10) so only the proxy can assert an identity.
          "auth.proxy" = {
            enabled = true;
            header_name = "X-NetBird-User";
            header_property = "email";
            headers = "Groups:X-NetBird-Groups";
            auto_sign_up = true;
            enable_login_token = false;
            whitelist = "100.64.0.0/10";
          };
        };
        provision = {
          datasources.settings = {
            apiVersion = 1;
            datasources = [
              {
                name = "Loki";
                type = "loki";
                uid = "loki";
                access = "proxy";
                url = "http://127.0.0.1:${toString lokiPort}";
                isDefault = true;
                # Loki has no ruler configured (it's for logs/dashboards, not
                # alerting), so stop Grafana's Alerting tab from probing its ruler
                # API — that probe is what errors. Querying Loki in Explore /
                # dashboards is unaffected.
                jsonData.manageAlerts = false;
              }
              {
                name = "Prometheus";
                type = "prometheus";
                uid = "prometheus";
                access = "proxy";
                url = "http://127.0.0.1:${toString prometheusPort}";
                jsonData = { };
              }
              {
                # Lets Grafana's Alerting UI view + silence the same Alertmanager
                # that Prometheus fires to (and that Karma reads). With
                # handleGrafanaManagedAlerts, alert rules authored in Grafana also
                # route here, so every alert is visible/silenceable from Grafana,
                # Karma, and Alertmanager's own UI alike.
                name = "Alertmanager";
                type = "alertmanager";
                uid = "alertmanager";
                access = "proxy";
                url = "http://127.0.0.1:${toString alertmanagerPort}";
                jsonData = {
                  implementation = "prometheus";
                  handleGrafanaManagedAlerts = true;
                };
              }
            ];
            deleteDatasources = [
              {
                name = "Loki";
                orgId = 1;
              }
              {
                name = "Prometheus";
                orgId = 1;
              }
              {
                name = "Alertmanager";
                orgId = 1;
              }
            ];
          };
          dashboards.settings.providers = [
            {
              name = "default";
              options.path = ./grafana-dashboards;
              disableDeletion = false;
            }
          ];
        };
      };

      # Grafana is served only through the NetBird proxy (grafana.kclj.dev, SSO),
      # not a public nginx vhost. In the dashboard use target TYPE = Peer (the
      # gateway), not Host/IP — a same-peer Host/Subnet target 502s (no
      # self-targeted ACL).
    };
}
