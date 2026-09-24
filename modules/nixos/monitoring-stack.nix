_: {
  # Loki/Alloy (logs), Prometheus/Alertmanager (metrics), Karma/Grafana (UIs).
  # Scrapes other gateway services, so it assumes the gateway.
  flake.nixosModules.monitoring-stack =
    { config, lib, ... }:
    let
      lokiPort = 3100;
      grafanaPort = 3000;
      prometheusPort = 9090;
      alertmanagerPort = 9093;
      karmaPort = 8082; # karma's default 8080 collides with netbird-proxy
      netbirdProxyDomain = config.site.proxyDomain;
      # Overlay IP of the netbird-proxy container's embedded NetBird peer — the
      # only source Grafana accepts the X-NetBird-User header from.
      netbirdProxyPeerIp = "10.64.244.130";
      autheliaMetricsAddr = lib.removeSuffix "/" (
        lib.removePrefix "tcp://" config.services.authelia.instances.main.settings.telemetry.metrics.address
      );
      netbirdMgmtMetricsPort = config.services.netbird.server.management.metricsPort;
      netbirdSignalMetricsPort = config.services.netbird.server.signal.metricsPort;
      crowdsecMetricsPort = config.services.crowdsec.settings.general.prometheus.listen_port;
      mkScrapeConfig = job_name: target: {
        inherit job_name;
        static_configs = [ { targets = [ target ]; } ];
      };
    in
    {
      sops.secrets."grafana/secret_key".owner = "grafana";

      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
          # No auth and ingests sensitive data; only loopback consumers.
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

      services.alloy = {
        enable = true;
        # Loopback: live debugging can surface raw logs. Use
        # `ssh -L 12345:127.0.0.1:12345`.
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

      services.prometheus = {
        enable = true;
        # No auth; opened only on wt0 for the NetBird proxy.
        listenAddress = "0.0.0.0";
        port = prometheusPort;
        retentionTime = "30d";
        scrapeConfigs = [
          {
            job_name = "authelia";
            metrics_path = "/";
            static_configs = [ { targets = [ autheliaMetricsAddr ]; } ];
          }
          (mkScrapeConfig "node" "127.0.0.1:${toString config.services.prometheus.exporters.node.port}")
          (mkScrapeConfig "netbird-management" "127.0.0.1:${toString netbirdMgmtMetricsPort}")
          (mkScrapeConfig "netbird-signal" "127.0.0.1:${toString netbirdSignalMetricsPort}")
          (mkScrapeConfig "crowdsec" "127.0.0.1:${toString crowdsecMetricsPort}")
        ];
        alertmanagers = [
          { static_configs = [ { targets = [ "127.0.0.1:${toString alertmanagerPort}" ]; } ]; }
        ];
        # Starter rules; Grafana-authored rules route to the same Alertmanager.
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
        # No auth; opened only on wt0 for the NetBird proxy.
        alertmanager = {
          enable = true;
          listenAddress = "0.0.0.0";
          port = alertmanagerPort;
          # Single instance: HA gossip would otherwise listen on 0.0.0.0:9094.
          extraFlags = [ "--cluster.listen-address=" ];
          webExternalUrl = "https://alerts.${netbirdProxyDomain}";
          configuration = {
            # No receivers yet: alerts show in Karma but notify nobody.
            route.receiver = "null";
            receivers = [ { name = "null"; } ];
          };
        };
      };

      # No auth; opened only on wt0 for the NetBird proxy.
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

      services.grafana = {
        enable = true;
        settings = {
          server = {
            # The NetBird proxy dials this on gateway's wt0 IP (backends can't be loopback).
            http_addr = "0.0.0.0";
            http_port = grafanaPort;
            domain = netbirdProxyDomain;
            root_url = "https://grafana.${netbirdProxyDomain}";
          };
          security = {
            admin_user = "admin";
            secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
          };
          # Anyone who can send X-NetBird-User from a whitelisted source IS that user,
          # so trust only the proxy's peer. If it re-registers with a new IP, logins
          # fail closed; update netbirdProxyPeerIp from `netbird status -d`.
          "auth.proxy" = {
            enabled = true;
            header_name = "X-NetBird-User";
            header_property = "email";
            headers = "Groups:X-NetBird-Groups";
            auto_sign_up = true;
            enable_login_token = false;
            whitelist = "${netbirdProxyPeerIp}/32, 127.0.0.1/32";
          };
          # auth.proxy is the only way in; the built-in admin would otherwise have
          # the default password from the store config.
          auth.disable_login_form = true;
          "auth.basic".enabled = false;
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
                # Loki has no ruler; stop Grafana's Alerting tab from probing it.
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
                # Grafana-authored alerts route here too, so every alert shows in Grafana,
                # Karma and Alertmanager.
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

      # Served only via the NetBird proxy. Use target type Peer (the gateway): a
      # same-peer Host/Subnet target 502s.
    };
}
