_: {
  flake.nixosModules.gateway =
    {
      config,
      lib,
      ...
    }:
    let
      autheliaInstance = "main";
      autheliaUser = "authelia-${autheliaInstance}";
      autheliaStateDir = "/var/lib/authelia-${autheliaInstance}";
      autheliaLogFile = "${autheliaStateDir}/authelia.log";
      domain = "kclj.io";
      autheliaPort = 9091;
      lldapPort = 3890;
      lldapHttpPort = 17170;
      baseDN = "dc=kclj,dc=io";
      lokiPort = 3100;
      grafanaPort = 3000;
      prometheusPort = 9090;
      autheliaMetricsPort = 9959;
      authDomain = "auth.${domain}";
      netbirdDomain = "netbird.${domain}";
      netbirdProxyDomain = "kclj.dev";
      netbirdProxyPort = 8443;
      # netbird-server combined container (post-v0.65 architecture). Bumps
      # against https://github.com/netbirdio/netbird/releases /
      # https://github.com/netbirdio/dashboard/releases. The combined image
      # bundles management + signal + relay + STUN; auth is the embedded Dex
      # IdP on /oauth2 (Authelia is NOT used for netbird sign-in here —
      # upstream's combined image hardcodes aud=netbird-dashboard / netbird-cli
      # and never reads external-IdP fields from config.yaml).
      netbirdServerVersion = "0.70.4";
      netbirdDashboardVersion = "2.36.0";
      netbirdServerPort = 8081; # host loopback ↔ container :80 (HTTP/gRPC/relay)
      netbirdDashboardHttpPort = 8080; # host loopback ↔ dashboard container :80
      netbirdStunPort = 3478; # UDP, must be reachable from peers
      # Container-internal metrics port (default upstream value). Host
      # mapping uses netbirdMetricsHostPort to avoid collision with the
      # Prometheus server, which already owns 127.0.0.1:9090.
      netbirdMetricsContainerPort = 9090;
      netbirdMetricsHostPort = 9192;
      netbirdHealthPort = 9000; # container-internal only, not host-mapped
      netbirdServerStateDir = "/var/lib/netbird-server";
      netbirdServerConfigPath = "${netbirdServerStateDir}/config.yaml";
      nginxInternalSSLPort = 4443;

      netbirdServerConfig = {
        server = {
          listenAddress = ":80";
          exposedAddress = "https://${netbirdDomain}:443";
          stunPorts = [ netbirdStunPort ];
          metricsPort = netbirdMetricsContainerPort;
          healthcheckAddress = ":${toString netbirdHealthPort}";
          logLevel = "info";
          logFile = "console";
          authSecret = config.sops.placeholder."netbird/auth_secret";
          dataDir = "/var/lib/netbird";
          disableAnonymousMetrics = true;
          auth = {
            issuer = "https://${netbirdDomain}/oauth2";
            localAuthDisabled = false;
            signKeyRefreshEnabled = true;
            dashboardRedirectURIs = [
              "https://${netbirdDomain}/nb-auth"
              "https://${netbirdDomain}/nb-silent-auth"
            ];
            cliRedirectURIs = [ "http://localhost:53000/" ];
          };
          store = {
            engine = "sqlite";
            encryptionKey = config.sops.placeholder."netbird/datastore_encryption_key";
          };
          reverseProxy = {
            trustedHTTPProxiesCount = 1; # nginx in front
            trustedPeers = [ "0.0.0.0/0" ];
          };
        };
      };

      mkHttpsVhost = extra: {
        forceSSL = true;
        enableACME = true;
        extraConfig = extra;
      };

      mkScrapeConfig = job_name: target: {
        inherit job_name;
        static_configs = [ { targets = [ target ]; } ];
      };

      mkNginxJail = filter: maxretry: {
        settings = {
          inherit filter maxretry;
          backend = "auto";
          logpath = "/var/log/nginx/access.log";
          findtime = 600;
        };
      };
    in
    {
      networking.hostName = "gateway";

      # Hetzner volume mounted early in initrd so that /nix is available before
      # systemd starts — avoids a chicken-and-egg problem where systemd itself
      # lives in /nix/store.
      boot.initrd.availableKernelModules = [ "virtio_scsi" ];
      fileSystems."/nix" = {
        device = "/dev/disk/by-id/scsi-0HC_Volume_105289845";
        fsType = "ext4";
        options = [
          "discard"
          "defaults"
        ];
        neededForBoot = true;
      };

      # Open additional ports beyond the SSH default from hetzner.nix.
      # ICMPv4 echo-request rate-limiting comes from the base firewall's
      # pingLimit; the base nftables input chain also drops ct-invalid and
      # accepts the standard ICMPv6 types, so the only custom rules left
      # here are the TCP blackholes, SYN-flood guard, and ICMPv6 rate-limit
      # (pingLimit doesn't cover ICMPv6).
      networking.firewall = {
        allowedTCPPorts = [
          80 # HTTP
          443 # HTTPS
        ];
        # STUN: peers connect to the embedded STUN server in netbird-server
        # for NAT detection. UDP-only — cannot be proxied via nginx.
        allowedUDPPorts = [ netbirdStunPort ];
        # Defense-in-depth: the netbird-server / dashboard / metrics ports all
        # bind 127.0.0.1, so external traffic to them never reaches the
        # process. Drop rule documents intent and protects against accidental
        # 0.0.0.0 binds. nginxInternalSSLPort is the HTTPS-on-loopback that
        # the stream block fronts.
        extraInputRules = ''
          tcp dport { ${toString netbirdServerPort}, ${toString netbirdDashboardHttpPort}, ${toString netbirdMetricsHostPort}, ${toString nginxInternalSSLPort} } drop
          tcp flags syn / fin,syn,rst,ack limit rate over 200/second burst 500 packets drop
          ip6 nexthdr icmpv6 limit rate 10/second burst 20 packets accept
          ip6 nexthdr icmpv6 drop
        '';
      };

      # User account. SSH keys come from the identity module (set by
      # profile-personal); gateway opts into installing them on root too as
      # a rescue fallback since it's the only public-facing host.
      identity.enableRootSshKeys = true;

      users.users.${config.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };

      # sops-nix - decrypts using the SSH host key via ssh-to-age
      sops = {
        defaultSopsFile = ../../secrets/gateway.yaml;

        secrets = {
          "authelia/jwt_secret" = {
            owner = autheliaUser;
          };
          "authelia/session_secret" = {
            owner = autheliaUser;
          };
          "authelia/storage_encryption_key" = {
            owner = autheliaUser;
          };
          "authelia/ldap_password" = {
            owner = autheliaUser;
          };
          "authelia/oidc_hmac_secret" = {
            owner = autheliaUser;
          };
          "authelia/oidc_jwks_key" = {
            owner = autheliaUser;
          };
          "authelia/smtp_password" = {
            owner = autheliaUser;
          };
          "authelia/smtp_username" = {
            owner = autheliaUser;
          };
          "lldap/jwt_secret" = { };
          "lldap/ldap_user_pass" = {
            mode = "0444";
          };
          "cloudflared/tunnel-credentials" = { };
          "cloudflare/api-token" = { };
          "grafana/secret_key" = {
            owner = "grafana";
          };
          "netbird/datastore_encryption_key" = { };
          # Shared secret used by netbird-server's built-in relay to mint
          # client credentials. Generate with `openssl rand -base64 32` and
          # add to secrets/gateway.yaml under netbird/auth_secret before
          # deploying.
          "netbird/auth_secret" = { };
          "netbird/proxy_token" = { };
          "proxmox/oidc_client_secret" = { };
        };
      };

      # Authelia - authentication server
      services.authelia.instances.${autheliaInstance} = {
        enable = true;
        settings = {
          theme = "auto";
          server.address = "tcp://127.0.0.1:${toString autheliaPort}/";
          server.buffers.read = 16384;
          log.level = "info";
          log.file_path = autheliaLogFile;
          log.keep_stdout = true;
          default_2fa_method = "webauthn";

          authentication_backend = {
            password_reset.disable = true;
            ldap = {
              implementation = "lldap";
              address = "ldap://127.0.0.1:${toString lldapPort}";
              base_dn = baseDN;
              user = "uid=authelia,ou=people,${baseDN}";
            };
          };

          access_control = {
            default_policy = "deny";
            rules = [
              {
                domain = "*.kclj.io";
                policy = "two_factor";
              }
              {
                domain = "*.kclj.dev";
                policy = "two_factor";
              }
            ];
          };

          storage.local.path = "${autheliaStateDir}/db.sqlite3";

          session = {
            redis.host = config.services.redis.servers.authelia.unixSocket;
            cookies = [
              {
                inherit domain;
                authelia_url = "https://${authDomain}";
                inactivity = "1M";
                expiration = "3M";
                remember_me = "1y";
              }
            ];
          };

          notifier.smtp = {
            address = "submission://smtp.fastmail.com:587";
            sender = "Authelia <noreply+auth@kclj.io>";
            subject = "[Authelia] {title}";
            disable_require_tls = false;
            tls.minimum_version = "TLS1.2";
          };

          # Necessary for nginx integration
          # See https://www.authelia.com/integration/proxies/nginx/
          server.endpoints.authz.auth-request.implementation = "AuthRequest";
          telemetry.metrics.enabled = true;
          telemetry.metrics.address = "tcp://127.0.0.1:${toString autheliaMetricsPort}/";

          identity_providers.oidc = {
            cors = {
              endpoints = [
                "authorization"
                "token"
                "revocation"
                "introspection"
                "userinfo"
              ];
              allowed_origins_from_client_redirect_uris = true;
            };
            claims_policies.cloudflare.id_token = [
              "email"
              "email_verified"
              "name"
              "preferred_username"
            ];
            clients = [
              {
                client_id = "proxmox";
                client_name = "Proxmox";
                # pbkdf2 hash of the plaintext secret stored in sops at proxmox/oidc_client_secret
                client_secret = "$pbkdf2-sha512$310000$9fPLzfyYkz8dgfVewaw1yg$Z7Vj8UKPSqEou.1TMOElWKDB3zYWzNM0CJXXgOY71UZ/KVLG18Xb73L/Ra/1qGJvFnmtRtcdhX8IDpl4w5DgjA";
                authorization_policy = "two_factor";
                consent_mode = "implicit";
                redirect_uris = [
                  "https://pve-01.lan.kclj.io:8006"
                  "https://pve-02.lan.kclj.io:8006"
                  "https://pve-03.lan.kclj.io:8006"
                  "https://pbs.lan.kclj.io:8007"
                  "https://pve-01.lan.kclj.io"
                  "https://pve-02.lan.kclj.io"
                  "https://pve-03.lan.kclj.io"
                  "https://pbs.kclj.io"
                  "https://pve.kclj.io"
                ];
                scopes = [
                  "openid"
                  "profile"
                  "email"
                ];
                token_endpoint_auth_method = "client_secret_basic";
                require_pkce = true;
                pkce_challenge_method = "S256";
              }
              {
                client_id = "cloudflare-access";
                client_name = "Cloudflare Access";
                # pbkdf2 hash of the plaintext secret stored in sops at cloudflare/access_oidc_client_secret
                client_secret = "$pbkdf2-sha512$310000$xnyghfozygQnVb0ytelIyQ$jti2tS0TS.3bCAoLOqNSxhKRtnJM9T/oeaV0f1buy2GmS/NJunNY0npb6ptAcRx4IpecQfOL.1Z.uTRtUqAvoQ";
                authorization_policy = "one_factor";
                consent_mode = "implicit";
                claims_policy = "cloudflare";
                redirect_uris = [
                  "https://kclejeune.cloudflareaccess.com/cdn-cgi/access/callback"
                ];
                scopes = [
                  "openid"
                  "profile"
                  "email"
                ];
                token_endpoint_auth_method = "client_secret_basic";
                require_pkce = true;
                pkce_challenge_method = "S256";
              }
            ];
          };
        };
        environmentVariables = {
          AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = config.sops.secrets."authelia/smtp_password".path;
          AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE =
            config.sops.secrets."authelia/ldap_password".path;
        };

        secrets = {
          jwtSecretFile = config.sops.secrets."authelia/jwt_secret".path;
          sessionSecretFile = config.sops.secrets."authelia/session_secret".path;
          storageEncryptionKeyFile = config.sops.secrets."authelia/storage_encryption_key".path;
          oidcHmacSecretFile = config.sops.secrets."authelia/oidc_hmac_secret".path;
          oidcIssuerPrivateKeyFile = config.sops.secrets."authelia/oidc_jwks_key".path;
        };
      };

      # Username injected via sops template env file — authelia has no _FILE support for smtp username
      sops.templates."authelia-smtp.env" = {
        owner = autheliaUser;
        content = ''
          AUTHELIA_NOTIFIER_SMTP_USERNAME=${config.sops.placeholder."authelia/smtp_username"}
          AUTHELIA_NOTIFIER_SMTP_STARTUP_CHECK_ADDRESS=${config.sops.placeholder."authelia/smtp_username"}
        '';
      };
      systemd.services."authelia-${autheliaInstance}" = {
        after = [
          "redis-authelia.service"
          "lldap.service"
        ];
        wants = [
          "redis-authelia.service"
          "lldap.service"
        ];
        serviceConfig.EnvironmentFile = [
          config.sops.templates."authelia-smtp.env".path
        ];
      };

      # ACME / Let's Encrypt via Cloudflare DNS-01 challenge
      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "kc.lejeune@gmail.com";
          dnsProvider = "cloudflare";
          environmentFile = config.sops.secrets."cloudflare/api-token".path;
        };
      };

      # Ensure nginx can read its own log files for fail2ban
      services.nginx = {
        enable = true;
        defaultSSLListenPort = nginxInternalSSLPort;
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;
        recommendedBrotliSettings = true;
        recommendedProxySettings = true;

        commonHttpConfig = ''
          limit_req_zone $binary_remote_addr zone=general:10m rate=30r/s;
          limit_req_zone $binary_remote_addr zone=authelia_api:10m rate=10r/s;
          limit_conn_zone $binary_remote_addr zone=per_ip:10m;

          access_log /var/log/nginx/access.log;
          error_log /var/log/nginx/error.log;
        '';

        # Drop requests with unknown Host headers
        virtualHosts."_" = {
          default = true;
          rejectSSL = true;
          locations."/".return = "444";
        };

        virtualHosts."${authDomain}" =
          mkHttpsVhost ''
            # Larger buffers for OIDC flows (cookies + auth headers)
            large_client_header_buffers 4 32k;
            proxy_buffer_size 16k;
            proxy_buffers 4 16k;

            limit_conn per_ip 50;
            limit_conn_status 429;
          ''
          // {

            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString autheliaPort}";
              proxyWebsockets = true;
              extraConfig = ''
                limit_req zone=general burst=60 nodelay;
                limit_req_status 429;
              '';
            };

            locations."/api/" = {
              proxyPass = "http://127.0.0.1:${toString autheliaPort}";
              extraConfig = ''
                limit_req zone=authelia_api burst=20 nodelay;
                limit_req_status 429;
              '';
            };
          };
      };

      services.fail2ban.jails = {
        nginx-http-auth = mkNginxJail "nginx-http-auth" 5;
        nginx-botsearch = mkNginxJail "nginx-botsearch" 5;
        nginx-bad-request = mkNginxJail "nginx-bad-request" 10;
        authelia.settings = {
          filter = "authelia";
          backend = "auto";
          port = "http,https";
          logpath = autheliaLogFile;
          maxretry = 3;
          findtime = 300;
        };
      };

      # Authelia fail2ban filter (matches JSON log format written to file)
      environment.etc."fail2ban/filter.d/authelia.conf".text = ''
        [Definition]
        failregex = ^.*"remote_ip":"<HOST>".*"msg":"Unsuccessful .*authentication attempt.*$
        ignoreregex =
      '';

      # Cloudflare Tunnel — exposes services without opening inbound HTTP/S ports
      # To set up:
      #   1. Create a tunnel: cloudflared tunnel create gateway
      #   2. Copy the credentials JSON into sops: sops secrets/gateway.yaml
      #      (add under cloudflared.tunnel-credentials as a string)
      #   3. Configure DNS in Cloudflare dashboard: CNAME auth.kclj.io -> <tunnel-id>.cfargotunnel.com
      # Once active, ports 80/443 can be removed from the firewall and ACME disabled,
      # as Cloudflare terminates TLS at the edge.
      services.cloudflared = {
        enable = true;
        tunnels.gateway = {
          credentialsFile = config.sops.secrets."cloudflared/tunnel-credentials".path;
          default = "http_status:404";
        };
      };

      # LLDAP - lightweight LDAP server for user management
      services.lldap = {
        enable = true;
        settings = {
          ldap_host = "127.0.0.1";
          ldap_port = lldapPort;
          http_host = "127.0.0.1";
          http_port = lldapHttpPort;
          http_url = "https://lldap.${domain}";
          ldap_base_dn = baseDN;
          ldap_user_email = "admin@${domain}";
          force_ldap_user_pass_reset = "always";
        };
        environment.LLDAP_LDAP_USER_PASS_FILE = config.sops.secrets."lldap/ldap_user_pass".path;
        environmentFile = config.sops.templates."lldap.env".path;
      };

      sops.templates."lldap.env".content = ''
        LLDAP_JWT_SECRET=${config.sops.placeholder."lldap/jwt_secret"}
      '';

      # Redis for Authelia session storage
      services.redis.servers.authelia = {
        enable = true;
        port = 0; # Unix socket only
      };
      users.users.${autheliaUser}.extraGroups = [ "redis-authelia" ];

      # Loki - log aggregation
      services.loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
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
        extraFlags = [ "--stability.level=generally-available" ];
      };

      environment.etc."alloy/config.alloy".text = ''
        // Scrape journald logs (sshd, fail2ban, authelia, nginx, systemd)
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
        listenAddress = "127.0.0.1";
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
          (mkScrapeConfig "netbird-server" "127.0.0.1:${toString netbirdMetricsHostPort}")
        ];
      };

      # Grafana - dashboards and visualization
      services.grafana = {
        enable = true;
        settings = {
          server = {
            http_addr = "127.0.0.1";
            http_port = grafanaPort;
            inherit domain;
            root_url = "https://grafana.${domain}";
          };
          security = {
            admin_user = "admin";
            secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
          };
          "auth.proxy" = {
            enabled = true;
            header_name = "cf-access-authenticated-user-email";
            header_property = "email";
            auto_sign_up = true;
            enable_login_token = false;
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
                jsonData = { };
              }
              {
                name = "Prometheus";
                type = "prometheus";
                uid = "prometheus";
                access = "proxy";
                url = "http://127.0.0.1:${toString prometheusPort}";
                jsonData = { };
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

      # lldap web UI: not exposed via nginx — access via SSH tunnel (ssh -L 17170:127.0.0.1:17170)
      # or add to cloudflared tunnel with Cloudflare Access protection before exposing publicly.

      services.nginx.virtualHosts."grafana.${domain}" = mkHttpsVhost "" // {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString grafanaPort}";
          proxyWebsockets = true;
        };
      };

      # Gateway acts as a Tailscale subnet router / exit node, not just a client.
      services.tailscale.useRoutingFeatures = lib.mkForce "both";

      # Netbird control plane — combined-container architecture (post-v0.65).
      # The netbirdio/netbird-server image bundles management + signal + relay
      # + STUN; the netbirdio/dashboard image is the SPA. Auth uses the
      # embedded Dex IdP at /oauth2 (upstream's combined image hardcodes
      # aud=netbird-dashboard / netbird-cli, so external OIDC isn't supported
      # by the YAML schema). Bumping the image versions is now the
      # netbirdServerVersion / netbirdDashboardVersion let-bindings up top.

      # config.yaml — sops template substitutes encryptionKey + authSecret
      # placeholders at activation. The result is bind-mounted read-only
      # into the netbird-server container at /etc/netbird/config.yaml.
      sops.templates."netbird-server-config.yaml" = {
        path = netbirdServerConfigPath;
        mode = "0640";
        content = builtins.toJSON netbirdServerConfig;
      };

      systemd.tmpfiles.rules = [
        "d ${netbirdServerStateDir} 0750 root root -"
        "d ${netbirdServerStateDir}/data 0750 root root -"
      ];

      virtualisation.oci-containers.containers.netbird-server = {
        image = "netbirdio/netbird-server:${netbirdServerVersion}";
        cmd = [
          "--config"
          "/etc/netbird/config.yaml"
        ];
        volumes = [
          "${netbirdServerConfigPath}:/etc/netbird/config.yaml:ro"
          "${netbirdServerStateDir}/data:/var/lib/netbird"
        ];
        ports = [
          "127.0.0.1:${toString netbirdServerPort}:80"
          "127.0.0.1:${toString netbirdMetricsHostPort}:${toString netbirdMetricsContainerPort}"
          "0.0.0.0:${toString netbirdStunPort}:${toString netbirdStunPort}/udp"
        ];
        extraOptions = [ "--restart=unless-stopped" ];
      };

      virtualisation.oci-containers.containers.netbird-dashboard = {
        image = "netbirdio/dashboard:${netbirdDashboardVersion}";
        # The dashboard image's entrypoint templates these env vars into the
        # bundled nginx config + JS bundle at startup. AUTH_* points at the
        # embedded Dex (served by netbird-server at /oauth2). LETSENCRYPT_DOMAIN=none
        # keeps the bundled nginx HTTP-only; NixOS nginx terminates TLS upstream.
        environment = {
          NETBIRD_MGMT_API_ENDPOINT = "https://${netbirdDomain}";
          NETBIRD_MGMT_GRPC_API_ENDPOINT = "https://${netbirdDomain}";
          AUTH_AUDIENCE = "netbird-dashboard";
          AUTH_CLIENT_ID = "netbird-dashboard";
          AUTH_CLIENT_SECRET = "";
          AUTH_AUTHORITY = "https://${netbirdDomain}/oauth2";
          USE_AUTH0 = "false";
          AUTH_SUPPORTED_SCOPES = "openid profile email groups";
          AUTH_REDIRECT_URI = "/nb-auth";
          AUTH_SILENT_REDIRECT_URI = "/nb-silent-auth";
          NGINX_SSL_PORT = "443";
          LETSENCRYPT_DOMAIN = "none";
        };
        ports = [
          "127.0.0.1:${toString netbirdDashboardHttpPort}:80"
        ];
        extraOptions = [ "--restart=unless-stopped" ];
      };

      # netbird-server needs the sops-rendered config.yaml present before it
      # can start. The oci-containers backend creates units named
      # ${backend}-${name}.service.
      systemd.services."${config.virtualisation.oci-containers.backend}-netbird-server" = {
        after = [
          "sops-install-secrets.service"
          "systemd-resolved.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
        requires = [ "sops-install-secrets.service" ];
        startLimitIntervalSec = 60;
        startLimitBurst = 10;
        serviceConfig.RestartSec = "5s";
      };

      # netbird.${domain} — TLS termination + reverse-proxy to both containers.
      # Path layout per
      # https://docs.netbird.io/selfhosted/external-reverse-proxy:
      #   /signalexchange.SignalExchange/* → server (gRPC, h2c)
      #   /management.ManagementService/*  → server (gRPC, h2c)
      #   /management.ProxyService/*       → server (gRPC, h2c)
      #   /api/*, /oauth2/*                → server (HTTP)
      #   /relay, /ws-proxy/*              → server (WebSocket)
      #   /*                               → dashboard (HTTP catch-all)
      #
      # Rate-limiting on this vhost is unreliable when traffic arrives via
      # the *.kclj.dev SNI-passthrough flow (real client IP is lost in the
      # stream block); DDoS protection lives at the stream layer
      # (limit_conn stream_per_ip) + nftables (SYN rate limiting).
      services.nginx.virtualHosts.${netbirdDomain} =
        let
          grpcLocation = ''
            client_body_timeout 1d;
            grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            grpc_pass grpc://127.0.0.1:${toString netbirdServerPort};
            grpc_read_timeout 1d;
            grpc_send_timeout 1d;
            grpc_socket_keepalive on;
          '';
        in
        mkHttpsVhost "" // {
          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:${toString netbirdDashboardHttpPort}";
              proxyWebsockets = true;
            };
            "/api/".proxyPass = "http://127.0.0.1:${toString netbirdServerPort}";
            "/oauth2/".proxyPass = "http://127.0.0.1:${toString netbirdServerPort}";
            "/relay" = {
              proxyPass = "http://127.0.0.1:${toString netbirdServerPort}";
              proxyWebsockets = true;
            };
            "/ws-proxy/" = {
              proxyPass = "http://127.0.0.1:${toString netbirdServerPort}";
              proxyWebsockets = true;
            };
            "/management.ManagementService/".extraConfig = grpcLocation;
            "/management.ProxyService/".extraConfig = grpcLocation;
            "/signalexchange.SignalExchange/".extraConfig = grpcLocation;
          };
        };

      # Netbird reverse proxy — runs as OCI container, handles its own TLS
      virtualisation.oci-containers.containers.netbird-proxy = {
        image = "netbirdio/reverse-proxy:latest";
        environmentFiles = [ config.sops.templates."netbird-proxy.env".path ];
        volumes = [
          "netbird-proxy-certs:/certs"
        ];
        extraOptions = [
          "--network=host"
          "--cap-drop=ALL"
          "--cap-add=NET_BIND_SERVICE"
          "--read-only"
          "--tmpfs=/tmp:rw,noexec,nosuid,size=64m"
          "--security-opt=no-new-privileges:true"
        ];
      };

      sops.templates."netbird-proxy.env".content = ''
        NB_PROXY_TOKEN=${config.sops.placeholder."netbird/proxy_token"}
        NB_PROXY_DOMAIN=${netbirdProxyDomain}
        NB_PROXY_MANAGEMENT_ADDRESS=http://127.0.0.1:${toString netbirdServerPort}
        NB_PROXY_ADDRESS=127.0.0.1:${toString netbirdProxyPort}
        NB_PROXY_ACME_CERTIFICATES=true
        NB_PROXY_ACME_CHALLENGE_TYPE=tls-alpn-01
        NB_PROXY_ALLOW_INSECURE=true
      '';

      # Nginx stream block: SNI-based routing on port 443
      # *.kclj.dev → TLS passthrough to netbird-proxy (handles its own TLS)
      # everything else → normal nginx HTTP block (TLS termination)
      services.nginx.streamConfig = ''
        limit_conn_zone $remote_addr zone=stream_per_ip:10m;

        map $ssl_preread_server_name $backend {
          ~^[a-zA-Z0-9-]+\.kclj\.dev$  netbird_proxy;
          default                       nginx_https;
        }

        upstream netbird_proxy {
          server 127.0.0.1:${toString netbirdProxyPort};
        }

        upstream nginx_https {
          server 127.0.0.1:${toString nginxInternalSSLPort};
        }

        server {
          listen 443;
          listen [::]:443;
          ssl_preread on;
          limit_conn stream_per_ip 20;
          proxy_connect_timeout 10s;
          proxy_timeout 300s;
          proxy_pass $backend;
        }
      '';

      system.stateVersion = "25.11";
    };
}
