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
  lokiPort = 3100;
  grafanaPort = 3000;
  prometheusPort = 9090;

  mkNginxJail = filter: maxretry: {
    settings = {
      inherit filter maxretry;
      logpath = "/var/log/nginx/access.log";
      findtime = 600;
    };
  };
in
{
  networking.hostName = "gateway";
  networking.domain = "";

  # Open additional ports beyond the SSH default from hetzner.nix
  networking.firewall = {
    allowedTCPPorts = [
      80 # HTTP
      443 # HTTPS
    ];
    allowedUDPPorts = [
      443 # QUIC / HTTP/3
    ];
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
      "authelia/users" = {
        owner = autheliaUser;
      };
      "authelia/oidc_hmac_secret" = {
        owner = autheliaUser;
      };
      "authelia/oidc_jwks_key" = {
        owner = autheliaUser;
      };
      "cloudflared/tunnel-credentials" = { };
      "cloudflare/api-token" = { };
      "grafana/secret_key" = {
        owner = "grafana";
      };
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

      authentication_backend.file.path = config.sops.secrets."authelia/users".path;

      access_control = {
        default_policy = "deny";
        rules = [
          {
            domain = "*.${domain}";
            policy = "one_factor";
          }
        ];
      };

      storage.local.path = "${autheliaStateDir}/db.sqlite3";

      session = {
        redis.host = config.services.redis.servers.authelia.unixSocket;
        cookies = [
          {
            inherit domain;
            authelia_url = "https://auth.${domain}";
            inactivity = "1M";
            expiration = "3M";
            remember_me = "1y";
          }
        ];
      };

      notifier.filesystem.filename = "${autheliaStateDir}/notifications.txt";

      # Necessary for nginx integration
      # See https://www.authelia.com/integration/proxies/nginx/
      server.endpoints.authz.auth-request.implementation = "AuthRequest";
      telemetry.metrics.enabled = true;
      telemetry.metrics.address = "tcp://127.0.0.1:9959/";

      identity_providers.oidc = {
        claims_policies.cloudflare.id_token = [
          "email"
          "email_verified"
          "name"
          "preferred_username"
        ];
        clients = [
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
    secrets = {
      jwtSecretFile = config.sops.secrets."authelia/jwt_secret".path;
      sessionSecretFile = config.sops.secrets."authelia/session_secret".path;
      storageEncryptionKeyFile = config.sops.secrets."authelia/storage_encryption_key".path;
      oidcHmacSecretFile = config.sops.secrets."authelia/oidc_hmac_secret".path;
      oidcIssuerPrivateKeyFile = config.sops.secrets."authelia/oidc_jwks_key".path;
    };
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
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedBrotliSettings = true;
    recommendedProxySettings = true;

    commonHttpConfig = ''
      quic_retry on;

      limit_req_zone $binary_remote_addr zone=general:10m rate=30r/s;
      limit_req_zone $binary_remote_addr zone=authelia_api:10m rate=10r/s;
      limit_conn_zone $binary_remote_addr zone=per_ip:10m;

      access_log /var/log/nginx/access.log;
      error_log /var/log/nginx/error.log;
    '';

    virtualHosts."auth.${domain}" = {
      forceSSL = true;
      enableACME = true;
      http3 = true;
      quic = true;
      extraConfig = ''
        add_header Alt-Svc 'h3=":443"; ma=86400';

        # Larger buffers for OIDC flows (cookies + auth headers)
        large_client_header_buffers 4 32k;
        proxy_buffer_size 16k;
        proxy_buffers 4 16k;

        limit_conn per_ip 50;
        limit_conn_status 429;
      '';

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
  # Disabled until tunnel is created and credentials are stored in sops.
  # services.cloudflared = {
  #   enable = true;
  #   tunnels.gateway = {
  #     credentialsFile = config.sops.secrets."cloudflared/tunnel-credentials".path;
  #     default = "http_status:404";
  #     ingress = { };
  #   };
  # };

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

  # Prometheus - metrics scraping
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = prometheusPort;
    retentionTime = "30d";
    scrapeConfigs = [
      {
        job_name = "authelia";
        static_configs = [ { targets = [ "127.0.0.1:9959" ]; } ];
      }
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
    };
    provision = {
      datasources.settings.datasources = [
        {
          name = "Loki";
          type = "loki";
          url = "http://127.0.0.1:${toString lokiPort}";
          isDefault = true;
        }
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:${toString prometheusPort}";
        }
      ];
    };
  };

  # Expose Grafana via nginx
  services.nginx.virtualHosts."grafana.${domain}" = {
    forceSSL = true;
    enableACME = true;
    http3 = true;
    quic = true;
    extraConfig = ''
      add_header Alt-Svc 'h3=":443"; ma=86400';
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString grafanaPort}";
      proxyWebsockets = true;
    };
  };

  # Passwordless sudo via SSH agent forwarding
  security.pam.rssh.enable = true;
  security.pam.services.sudo.rssh = true;

  # Netbird - mesh VPN
  services.netbird.enable = true;

  system.stateVersion = "25.11";
}
