{ config, ... }:
let
  flakeCfg = config;
in
{
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
      netbirdMgmtPort = 8011;
      netbirdMgmtMetricsPort = 9190;
      netbirdSignalMetricsPort = 9191;
      nginxInternalSSLPort = 4443;
      # 8080/6060 (crowdsec defaults) collide with netbird-proxy and
      # netbird-signal respectively on this host, so move both.
      crowdsecLapiPort = 8090;
      crowdsecMetricsPort = 9060;

      mkHttpsVhost = extra: {
        forceSSL = true;
        enableACME = true;
        extraConfig = extra;
      };

      mkScrapeConfig = job_name: target: {
        inherit job_name;
        static_configs = [ { targets = [ target ]; } ];
      };
    in
    {
      imports = [ flakeCfg.flake.nixosModules.crowdsec ];

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
        extraInputRules = ''
          tcp dport { ${toString netbirdMgmtPort}, 33073, ${toString netbirdMgmtMetricsPort}, ${toString netbirdSignalMetricsPort}, ${toString nginxInternalSSLPort} } drop
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
          "netbird/turn_password" = {
            owner = "turnserver";
          };
          # Plaintext OIDC client secret used by the embedded Dex IdP to
          # authenticate against Authelia as a confidential upstream
          # connector. The matching pbkdf2 hash lives in the Authelia
          # netbird OIDC client config below; rotate them in lockstep
          # (`authelia crypto hash generate pbkdf2 --variant sha512`).
          # Substituted into management.json's
          # EmbeddedIdP.StaticConnectors[].config.clientSecret via the
          # netbird module's _secret/jq mechanism.
          "netbird/authelia_client_secret" = { };
          "netbird/proxy_token" = { };
          # Bouncer API key shared between the CrowdSec LAPI and the netbird
          # reverse proxy. Generate with `openssl rand -hex 32`. Wired via
          # services.crowdsec.declarativeBouncers.netbird-proxy, whose
          # crowdsec-register-netbird-proxy oneshot registers the bouncer with
          # this key; the proxy authenticates to LAPI with it.
          "crowdsec/bouncer_key" = { };
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
            # email_verified is required: netbird's embedded Dex rejects the
            # upstream Authelia ID token when the email scope is requested but
            # the token lacks email_verified (Dex errors "email not verified"
            # unless insecureSkipEmailVerified is set). Authelia emits
            # email_verified=true for LDAP users.
            claims_policies.netbird.id_token = [
              "email"
              "email_verified"
              "name"
              "preferred_username"
              "groups"
            ];
            claims_policies.proxmox.id_token = [
              "email"
              "email_verified"
              "preferred_username"
              "groups"
            ];
            clients = [
              {
                client_id = "proxmox";
                client_name = "Proxmox";
                # pbkdf2 hash of the plaintext secret stored in sops at proxmox/oidc_client_secret
                client_secret = "$pbkdf2-sha512$310000$9fPLzfyYkz8dgfVewaw1yg$Z7Vj8UKPSqEou.1TMOElWKDB3zYWzNM0CJXXgOY71UZ/KVLG18Xb73L/Ra/1qGJvFnmtRtcdhX8IDpl4w5DgjA";
                authorization_policy = "two_factor";
                consent_mode = "implicit";
                claims_policy = "proxmox";
                redirect_uris = [
                  "https://pve-01.lan.kclj.io:8006"
                  "https://pve-02.lan.kclj.io:8006"
                  "https://pve-03.lan.kclj.io:8006"
                  "https://pbs.lan.kclj.io:8007"
                  "https://pve-01.lan.kclj.io"
                  "https://pve-02.lan.kclj.io"
                  "https://pve-03.lan.kclj.io"
                  "https://pbs.lan.kclj.io"
                  "https://pve-01.kclj.dev"
                  "https://pve-02.kclj.dev"
                  "https://pve-03.kclj.dev"
                  "https://pbs.kclj.dev"
                ];
                scopes = [
                  "openid"
                  "profile"
                  "email"
                  "groups"
                ];
                token_endpoint_auth_method = "client_secret_basic";
                require_pkce = true;
                pkce_challenge_method = "S256";
              }
              {
                # Upstream OIDC connector consumed by netbird's embedded
                # Dex IdP. Confidential client — Dex uses
                # netbird/authelia_client_secret (plaintext, sops) to
                # exchange auth codes; Authelia stores only the pbkdf2
                # hash below. Rotate them in lockstep
                # (`authelia crypto hash generate pbkdf2 --variant sha512`).
                # Dex uses a single shared callback for all connectors —
                # issuer + "/callback" (verified in netbird idp/dex
                # connector.go GetRedirectURI) — NOT a per-connector path.
                # This must exactly match the connector's config.redirectURI
                # in management.json's EmbeddedIdP.StaticConnectors below.
                client_id = "netbird";
                client_name = "Netbird";
                client_secret = "$pbkdf2-sha512$310000$eR/0.KCdrZkDNlG4UxJHZA$RnhRovxssPf8MHatxmR2mAd8hLhMX0MZ0ZtwDsvoEr/auAdTMBHNuXo3avAnwB6sP4YsE0FWTJL.zot0YyLhTA";
                authorization_policy = "one_factor";
                consent_mode = "implicit";
                claims_policy = "netbird";
                response_types = [ "code" ];
                redirect_uris = [
                  "https://${netbirdDomain}/oauth2/callback"
                ];
                scopes = [
                  "openid"
                  "profile"
                  "email"
                  "groups"
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
        # The SNI stream block (below) terminates the client TCP connection and
        # re-proxies to the internal SSL port from 127.0.0.1, so it sends a
        # PROXY-protocol header to carry the real client IP. The internal SSL
        # listeners must therefore expect proxy_protocol; port 80 (direct, not
        # behind the stream) must NOT. real_ip (below) then rewrites $remote_addr
        # to the real client for logs, rate-limits, and crowdsec.
        defaultListen = [
          {
            addr = "0.0.0.0";
            port = nginxInternalSSLPort;
            ssl = true;
            proxyProtocol = true;
          }
          {
            addr = "[::0]";
            port = nginxInternalSSLPort;
            ssl = true;
            proxyProtocol = true;
          }
          {
            addr = "0.0.0.0";
            port = 80;
            ssl = false;
          }
          {
            addr = "[::0]";
            port = 80;
            ssl = false;
          }
        ];
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;
        recommendedBrotliSettings = true;
        recommendedProxySettings = true;

        commonHttpConfig = ''
          # Trust the loopback stream proxy and take the real client IP from its
          # PROXY-protocol header. This rewrites $remote_addr before the
          # limit_req/limit_conn zones and the access log evaluate it, so per-IP
          # rate-limiting, X-Forwarded-For to backends (authelia), and crowdsec
          # nginx log parsing all see the real client instead of 127.0.0.1.
          set_real_ip_from 127.0.0.1;
          set_real_ip_from ::1;
          real_ip_header proxy_protocol;

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

      # fail2ban is trimmed to authelia only: CrowdSec owns nginx + sshd
      # detection (crowdsecurity/nginx + crowdsecurity/sshd scenarios), so the
      # nginx jails are dropped and the default sshd jail is disabled to avoid
      # double-banning. Authelia stays on fail2ban because CrowdSec has no
      # standard parser for its JSON auth log.
      services.fail2ban.jails = {
        # hetzner.nix enables the sshd jail via `settings.enabled = true`, and
        # the rendered jail takes `enabled` from settings, so the top-level
        # `enabled` option can't turn it off — force it in settings instead.
        sshd.settings.enabled = lib.mkForce false;
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
          (mkScrapeConfig "netbird-management" "127.0.0.1:${toString netbirdMgmtMetricsPort}")
          (mkScrapeConfig "netbird-signal" "127.0.0.1:${toString netbirdSignalMetricsPort}")
          (mkScrapeConfig "crowdsec" "127.0.0.1:${toString crowdsecMetricsPort}")
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

      # Netbird - self-hosted control server (management + signal + dashboard + TURN)
      services.netbird.server = {
        enable = true;
        domain = netbirdDomain;
        enableNginx = true;

        coturn = {
          enable = true;
          useAcmeCertificates = true;
          passwordFile = config.sops.secrets."netbird/turn_password".path;
        };

        management = {
          # Required by the upstream module — used to populate
          # HttpConfig.OIDCConfigEndpoint. With EmbeddedIdP enabled the
          # binary doesn't actually consult HttpConfig for auth, but the
          # NixOS option is mandatory, so we point it at the embedded
          # Dex's discovery URL for consistency.
          oidcConfigEndpoint = "https://${netbirdDomain}/oauth2/.well-known/openid-configuration";
          metricsPort = netbirdMgmtMetricsPort;
          settings = {
            DataStoreEncryptionKey._secret = config.sops.secrets."netbird/datastore_encryption_key".path;
            TURNConfig.Secret._secret = config.sops.secrets."netbird/turn_password".path;
            # Wipe the keys netbird-idp-migrate strips. The upstream
            # module's defaultSettings includes IdpManagerConfig,
            # PKCEAuthorizationFlow, and DeviceAuthorizationFlow; setting
            # them to null here, with mkForce to override the defaults,
            # produces "key": null in management.json which the binary
            # treats as absent (Go decodes JSON null → nil pointer).
            IdpManagerConfig = lib.mkForce null;
            PKCEAuthorizationFlow = lib.mkForce null;
            DeviceAuthorizationFlow = lib.mkForce null;
            # Embedded Dex IdP. Authelia is wired in as an upstream OIDC
            # connector; users signing in are redirected to Authelia, then
            # back to Dex, which mints netbird-flavored tokens (aud =
            # netbird-dashboard / netbird-cli). The connector id MUST
            # match the value used when running netbird-idp-migrate
            # (--idp-seed-info) — re-encoded user IDs in store.db are
            # bound to that id.
            EmbeddedIdP = {
              Enabled = true;
              Issuer = "https://${netbirdDomain}/oauth2";
              DashboardRedirectURIs = [
                "https://${netbirdDomain}/nb-auth"
                "https://${netbirdDomain}/nb-silent-auth"
              ];
              StaticConnectors = [
                {
                  type = "oidc";
                  id = "authelia";
                  name = "Authelia";
                  config = {
                    issuer = "https://${authDomain}";
                    clientID = "netbird";
                    clientSecret._secret = config.sops.secrets."netbird/authelia_client_secret".path;
                    redirectURI = "https://${netbirdDomain}/oauth2/callback";
                    scopes = [
                      "openid"
                      "profile"
                      "email"
                      "groups"
                    ];
                  };
                }
              ];
            };
          };
        };

        signal.metricsPort = netbirdSignalMetricsPort;

        dashboard = {
          enableNginx = true;
          settings = {
            AUTH_AUTHORITY = "https://${netbirdDomain}/oauth2";
            AUTH_CLIENT_ID = "netbird-dashboard";
            AUTH_AUDIENCE = "netbird-dashboard";
            AUTH_SUPPORTED_SCOPES = "openid profile email groups";
            AUTH_REDIRECT_URI = "/nb-auth";
            AUTH_SILENT_REDIRECT_URI = "/nb-silent-auth";
            USE_AUTH0 = "";
          };
        };
      };

      # Ensure netbird-management starts after authelia (OIDC discovery dependency)
      systemd.services.netbird-management = {
        after = [
          "authelia-${autheliaInstance}.service"
          "systemd-resolved.service"
          "network-online.target"
        ];
        wants = [
          "authelia-${autheliaInstance}.service"
          "network-online.target"
        ];
        startLimitIntervalSec = 60;
        startLimitBurst = 10;
        serviceConfig.RestartSec = "5s";
      };

      # Restrict coturn relay port range and block SSRF to internal networks
      services.coturn = {
        min-port = 49152;
        max-port = 49263;
        extraConfig = ''
          denied-peer-ip=0.0.0.0-0.255.255.255
          denied-peer-ip=10.0.0.0-10.255.255.255
          denied-peer-ip=127.0.0.0-127.255.255.255
          denied-peer-ip=169.254.0.0-169.254.255.255
          denied-peer-ip=172.16.0.0-172.31.255.255
          denied-peer-ip=192.168.0.0-192.168.255.255
          no-loopback-peers
          no-multicast-peers
          stale-nonce=600
          user-quota=100
          total-quota=500
          max-bps=50000000
          max-allocate-timeout=300
        '';
      };

      # Embedded Dex IdP routes + dashboard SPA fallbacks. The netbird
      # module's auto-generated vhost only knows about /api and the gRPC
      # paths; we add /oauth2 (Dex's OIDC endpoints — discovery, JWKS,
      # token, /oauth2/callback/<connector-id>) and the SPA tryFiles for
      # /nb-auth + /nb-silent-auth (the dashboard's auth callback paths
      # post-IdP-migration).
      #
      # Rate limiting on the HTTP layer is unreliable here because the
      # stream block proxies all traffic from 127.0.0.1 — the real client
      # IP is lost. DDoS protection is handled at the stream layer
      # (limit_conn stream_per_ip) and nftables (SYN rate limiting).
      services.nginx.virtualHosts.${netbirdDomain} = mkHttpsVhost "" // {
        locations."/oauth2/" = {
          proxyPass = "http://127.0.0.1:${toString netbirdMgmtPort}";
        };
        locations."/nb-auth" = {
          tryFiles = "$uri /index.html";
        };
        locations."/nb-silent-auth" = {
          tryFiles = "$uri /index.html";
        };
      };

      # CrowdSec — local detection (nginx + sshd) plus the community/CAPI
      # blocklist, enforced at nftables by the firewall bouncer and surfaced to
      # the netbird reverse proxy's embedded bouncer. The reusable crowdsec
      # module (imported above) runs it as a native service; LAPI and metrics
      # are moved off their defaults (8080/6060) to dodge netbird-proxy and
      # netbird-signal.
      services.crowdsec.enable = true;
      services.crowdsec.settings.general.api.server.listen_uri = "127.0.0.1:${toString crowdsecLapiPort}";
      services.crowdsec.settings.general.prometheus.listen_port = crowdsecMetricsPort;

      # crowdsecurity/linux brings the sshd parser + ssh-bf scenarios; nginx adds
      # HTTP probing/scanner/bad-bot detection. nginx detection is only safe
      # because the stream block now forwards the real client IP via PROXY
      # protocol (set_real_ip_from above) — previously nginx logged 127.0.0.1 for
      # all HTTPS, so crowdsec would ban loopback and the firewall bouncer would
      # drop everything proxied over it. The loopback/RFC1918 whitelist (crowdsec
      # module) + overlay whitelist (below) are belt-and-suspenders.
      services.crowdsec.hub.collections = [
        "crowdsecurity/linux"
        "crowdsecurity/nginx"
      ];

      # Data sources: sshd via journald, nginx via its log files (now carrying
      # real client IPs). Without an acquisition the agent refuses to start.
      services.crowdsec.localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
        {
          source = "file";
          filenames = [
            "/var/log/nginx/access.log"
            "/var/log/nginx/error.log"
          ];
          labels.type = "nginx";
        }
      ];

      # Whitelist the overlay ranges (on top of the loopback/RFC1918 baseline in
      # the crowdsec module) so a tailscale/netbird peer can never be banned.
      services.crowdsec.localConfig.parsers.s02Enrich = [
        {
          name = "gateway/trusted-overlay";
          description = "Never ban tailscale/netbird overlay sources";
          whitelist = {
            reason = "trusted overlay networks (tailscale / netbird)";
            cidr = [
              "100.64.0.0/10"
              "100.100.0.0/16"
            ];
          };
        }
      ];

      # crowdsec reads the journal (sshd) via systemd-journal and the nginx logs
      # (nginx:nginx 0640 in a 0750 dir) via the nginx group.
      systemd.services.crowdsec.serviceConfig.SupplementaryGroups = [
        "nginx"
        "systemd-journal"
      ];

      # Firewall bouncer: drops CrowdSec decisions (local + community blocklist)
      # at nftables. Turnkey — it auto-registers with the LAPI, picks the
      # nftables backend (networking.nftables.enable = true), creates its own
      # drop-sets, and reads api_url from the LAPI listen_uri above.
      services.crowdsec-firewall-bouncer.enable = true;

      services.crowdsec.declarativeBouncers.netbird-proxy.keyFile =
        config.sops.secrets."crowdsec/bouncer_key".path;
      # CrowdSec Console: enrollment is a one-time imperative bootstrap that
      # also requires approving the machine in the Console web UI, so it is NOT
      # encoded here. Enroll once on the host with a token from
      # app.crowdsec.net (Security Engines → Enroll engine):
      #   sudo cscli console enroll <token> --name gateway
      # The sharing config below is declarative (it's a real config file) and
      # takes effect once enrolled; dial it back to keep data local.
      services.crowdsec.settings.console.configuration = {
        share_manual_decisions = true;
        share_tainted = true;
        share_context = true;
        share_custom = true;
        # Receive console-managed decisions and blocklists over PAPI. CrowdSec
        # delivers the community blocklist (and any you subscribe to in the
        # console) via this channel, so without it the engine enrols but applies
        # no console blocklists. Requires the machine to be enrolled.
        console_management = true;
      };

      # Netbird reverse proxy — runs as OCI container, handles its own TLS
      virtualisation.oci-containers.containers.netbird-proxy = {
        # Tag tracks the netbird management package version from nixpkgs so
        # the proxy stays in lockstep with the server components.
        image = "netbirdio/reverse-proxy:${config.services.netbird.server.management.package.version}";
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

      # CrowdSec env vars are appended only when crowdsec is enabled, so the
      # proxy cleanly loses its bouncer wiring (and the secret reference) if the
      # module is dropped.
      sops.templates."netbird-proxy.env".content = ''
        NB_PROXY_TOKEN=${config.sops.placeholder."netbird/proxy_token"}
        NB_PROXY_DOMAIN=${netbirdProxyDomain}
        NB_PROXY_MANAGEMENT_ADDRESS=http://127.0.0.1:${toString netbirdMgmtPort}
        NB_PROXY_ADDRESS=127.0.0.1:${toString netbirdProxyPort}
        NB_PROXY_ACME_CERTIFICATES=true
        NB_PROXY_ACME_CHALLENGE_TYPE=tls-alpn-01
        NB_PROXY_ALLOW_INSECURE=true
        NB_PROXY_PROXY_PROTOCOL=true
        NB_PROXY_TRUSTED_PROXIES=127.0.0.1/32,::1/128
      ''
      + lib.optionalString config.services.crowdsec.enable ''
        NB_PROXY_CROWDSEC_API_URL=http://127.0.0.1:${toString crowdsecLapiPort}
        NB_PROXY_CROWDSEC_API_KEY=${config.sops.placeholder."crowdsec/bouncer_key"}
      '';

      systemd.services.podman-netbird-proxy = lib.mkMerge [
        {
          # Restart the container when its env (sops template) changes. NixOS
          # oci-containers only restart on unit/image changes, not env-file
          # *content* changes — so without this, an env edit (e.g. enabling
          # PROXY protocol) silently doesn't take effect until a manual restart.
          restartTriggers = [ config.sops.templates."netbird-proxy.env".content ];
        }
        # Start the proxy only after its bouncer is registered with LAPI, so the
        # CrowdSec API key is valid the moment the proxy comes up.
        (lib.mkIf config.services.crowdsec.enable {
          after = [ "crowdsec-register-netbird-proxy.service" ];
          wants = [ "crowdsec-register-netbird-proxy.service" ];
        })
      ];

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
          # Emit a PROXY-protocol header to the chosen backend so the real
          # client IP survives the loopback re-proxy. Both backends must accept
          # it: nginx_https via defaultListen proxyProtocol, netbird-proxy via
          # NB_PROXY_PROXY_PROTOCOL. ssl_preread reads SNI before this.
          proxy_protocol on;
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
