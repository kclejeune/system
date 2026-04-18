{
  config,
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
  networking.domain = "";

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

  # Open additional ports beyond the SSH default from hetzner.nix
  networking.firewall = {
    allowedTCPPorts = [
      80 # HTTP
      443 # HTTPS
    ];
    allowedUDPPorts = [ ];
    extraInputRules = ''
      ct state invalid drop
      tcp dport { ${toString netbirdMgmtPort}, 33073, ${toString netbirdMgmtMetricsPort}, ${toString netbirdSignalMetricsPort}, ${toString nginxInternalSSLPort} } drop
      tcp flags syn / fin,syn,rst,ack limit rate over 200/second burst 500 packets drop
      ip protocol icmp limit rate 10/second burst 20 packets accept
      ip protocol icmp drop
      icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept
      ip6 nexthdr icmpv6 limit rate 10/second burst 20 packets accept
      ip6 nexthdr icmpv6 drop
    '';
  };

  # User account
  users.users = {
    root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM48VQYrCQErK9QdC/mZ61Yzjh/4xKpgZ2WU5G19FpBG"
    ];
    "${config.user.name}" = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM48VQYrCQErK9QdC/mZ61Yzjh/4xKpgZ2WU5G19FpBG"
      ];
    };
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
        claims_policies.netbird.id_token = [
          "email"
          "name"
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
            client_id = "netbird";
            client_name = "Netbird";
            public = true;
            authorization_policy = "one_factor";
            consent_mode = "implicit";
            audience = [ "netbird" ];
            claims_policy = "netbird";
            response_types = [ "code" ];
            redirect_uris = [
              "http://localhost:53000"
              "https://${netbirdDomain}/auth"
              "https://${netbirdDomain}/silent-auth"
            ];
            scopes = [
              "openid"
              "profile"
              "email"
              "groups"
            ];
            require_pkce = true;
            pkce_challenge_method = "S256";
            token_endpoint_auth_method = "none";
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
    loki.source.journal "journald" {
      forward_to = [loki.write.local.receiver]
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

    // Scrape authelia JSON log file
    local.file_match "authelia_log" {
      path_targets = [{"__path__" = "${autheliaLogFile}"}]
    }

    loki.source.file "authelia" {
      targets    = local.file_match.authelia_log.targets
      forward_to = [loki.process.authelia.receiver]
    }

    loki.process "authelia" {
      forward_to = [loki.write.local.receiver]

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
      (mkScrapeConfig "authelia" "127.0.0.1:${toString autheliaMetricsPort}")
      (mkScrapeConfig "node" "127.0.0.1:${toString config.services.prometheus.exporters.node.port}")
      (mkScrapeConfig "cloudflared" "127.0.0.1:2000")
      (mkScrapeConfig "netbird-management" "127.0.0.1:${toString netbirdMgmtMetricsPort}")
      (mkScrapeConfig "netbird-signal" "127.0.0.1:${toString netbirdSignalMetricsPort}")
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
          disableDeletion = true;
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

  # Passwordless sudo via SSH agent forwarding
  security.pam.rssh.enable = true;
  security.pam.services.sudo.rssh = true;

  # Netbird - mesh VPN client
  services.netbird.enable = true;

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
      oidcConfigEndpoint = "https://${authDomain}/.well-known/openid-configuration";
      metricsPort = netbirdMgmtMetricsPort;
      settings = {
        DataStoreEncryptionKey._secret = config.sops.secrets."netbird/datastore_encryption_key".path;
        TURNConfig.Secret._secret = config.sops.secrets."netbird/turn_password".path;
        AuthCallbackURL = "https://${netbirdDomain}/api/reverse-proxy/callback";
        PKCEAuthorizationFlow.ProviderConfig = {
          Audience = "netbird";
          ClientID = "netbird";
          AuthorizationEndpoint = "https://${authDomain}/api/oidc/authorization";
          TokenEndpoint = "https://${authDomain}/api/oidc/token";
          Scope = "openid profile email groups";
          RedirectURLs = [ "http://localhost:53000" ];
          UseIDToken = true;
        };
      };
    };

    signal.metricsPort = netbirdSignalMetricsPort;

    dashboard = {
      enableNginx = true;
      settings = {
        AUTH_AUTHORITY = "https://${authDomain}";
        AUTH_CLIENT_ID = "netbird";
        AUTH_AUDIENCE = "netbird";
        AUTH_SUPPORTED_SCOPES = "openid profile email groups";
        AUTH_REDIRECT_URI = "/auth";
        AUTH_SILENT_REDIRECT_URI = "/silent-auth";
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
    serviceConfig = {
      RestartSec = "5s";
      StartLimitIntervalSec = "60s";
      StartLimitBurst = 10;
    };
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
      user-quota=16
      total-quota=100
      max-bps=10000000
      max-allocate-timeout=300
    '';
  };

  # TLS/HTTP3 and OIDC callback fallbacks for the netbird dashboard SPA
  # Rate limiting on the HTTP layer is unreliable here because the stream
  # block proxies all traffic from 127.0.0.1 — the real client IP is lost.
  # DDoS protection is handled at the stream layer (limit_conn stream_per_ip)
  # and nftables (SYN rate limiting).
  services.nginx.virtualHosts.${netbirdDomain} = mkHttpsVhost "" // {
    locations."/auth" = {
      tryFiles = "$uri /index.html";
    };
    locations."/silent-auth" = {
      tryFiles = "$uri /index.html";
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
    NB_PROXY_MANAGEMENT_ADDRESS=http://127.0.0.1:${toString netbirdMgmtPort}
    NB_PROXY_ADDRESS=127.0.0.1:${toString netbirdProxyPort}
    NB_PROXY_ACME_CERTIFICATES=true
    NB_PROXY_ACME_CHALLENGE_TYPE=tls-alpn-01
    NB_PROXY_ALLOW_INSECURE=true
  '';

  # Nginx stream block: SNI-based routing on port 443
  # *.proxy.netbird.kclj.io → TLS passthrough to netbird-proxy (handles its own TLS)
  # everything else → normal nginx HTTP block (TLS termination)
  services.nginx.streamConfig = ''
    limit_conn_zone $remote_addr zone=stream_per_ip:10m;

    map $ssl_preread_server_name $backend {
      ~^[a-zA-Z0-9-]+\.proxy\.netbird\.kclj\.io$  netbird_proxy;
      default                                       nginx_https;
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
}
