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
      # Log lives in a dedicated dir, NOT the state dir: the state dir holds
      # db.sqlite3 (TOTP/WebAuthn/session data, world-readable 0644), so granting
      # crowdsec traverse there to read the log would also expose the auth DB.
      # A log-only dir lets crowdsec read the log without reaching any secrets.
      autheliaLogDir = "/var/log/authelia-${autheliaInstance}";
      autheliaLogFile = "${autheliaLogDir}/authelia.log";
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
      alertmanagerPort = 9093;
      karmaPort = 8082; # karma's default 8080 collides with netbird-proxy
      ntfyPort = 2586; # ntfy's conventional port (default :80 collides with nginx)
      beszelPort = 8091; # beszel hub web UI / agent endpoint (its 8090 default collides with crowdsecLapiPort)

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
        # The internal web UIs (grafana, prometheus, alertmanager, karma, lldap,
        # ntfy, beszel) bind 0.0.0.0 so the NetBird proxy reaches them over the mesh, but
        # aren't opened here — so default-drop keeps them off the public NIC while
        # trustedInterfaces (wt0/tailscale0) admits the overlay. NetBird ACLs +
        # proxy SSO gate who on the overlay reaches them.
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

      # Base sets PermitRootLogin="no" (mkDefault), which would make the rescue
      # keys above inert. Allow key-only root login (never password).
      services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

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
          # World-readable (0444) on purpose: lldap runs as a DynamicUser, so a
          # static "lldap" group to chown this to collides with the dynamic one
          # (217/USER on start). Group-read would need a separately-named
          # SupplementaryGroup; without that, 0444 is the workable option.
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
          # reverse proxy (see declarativeBouncers.netbird-proxy below).
          # Generate with `openssl rand -hex 32`.
          "crowdsec/bouncer_key" = { };
          "proxmox/oidc_client_secret" = { };
          # ntfy secrets kept out of the world-readable /etc/ntfy/server.yml,
          # injected via the EnvironmentFile (sops template) below:
          #   web_push_private_key — VAPID private key (regenerate a real keypair)
          #   auth_users — bcrypt user list, e.g. admin:$2b$10$...:admin,kclejeune:$2b$10$...:admin
          "ntfy/web_push_private_key" = { };
          "ntfy/auth_users" = { };
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

          # Brute-force regulation. ip mode (Authelia's recommendation) over the
          # default user mode: bans the offending source IP rather than the
          # account, so a known username can't be locked out by a third party.
          # Authelia sees the real client IP via nginx X-Forwarded-For (real_ip
          # from PROXY protocol). This is the in-app first line; CrowdSec
          # (LePresidente/authelia) adds escalating nftables bans from the log.
          # The built-in server.endpoints.rate_limits are left at their defaults
          # (all enabled).
          regulation = {
            modes = [ "ip" ];
            max_retries = 3;
            find_time = "2m";
            ban_time = "10m";
          };

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
            claims_policies.beszel.id_token = [
              "email"
              "email_verified"
              "name"
              "preferred_username"
            ];
            clients = [
              {
                # Beszel hub (PocketBase) OIDC login. Beszel sits behind the
                # netbird-proxy at beszel.kclj.dev for transport SSO, AND uses
                # this client so its dashboard users are Authelia-backed. The
                # plaintext secret lives in sops at beszel/authelia_client_secret
                # — paste it into Beszel's UI when adding the OIDC provider
                # (PocketBase stores it in its own DB; Authelia keeps only the
                # pbkdf2 hash below). PocketBase's callback is /api/oauth2-redirect.
                client_id = "beszel";
                client_name = "Beszel";
                client_secret = "$pbkdf2-sha512$310000$fMrobSxiOm/Y4AJfZZGiVA$hC9cyxI1.qN7/O09Jy0lcT1dc87lw12138OAUaC0G6ihI5iHBMkzU/zXfUIGD7Ezsrk6FfJa3GziuKqBgtOB2A";
                authorization_policy = "two_factor";
                consent_mode = "implicit";
                claims_policy = "beszel";
                redirect_uris = [
                  "https://beszel.kclj.dev/api/oauth2-redirect"
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
                authorization_policy = "two_factor";
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
                authorization_policy = "two_factor";
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
        # ProtectSystem=strict makes /var/log read-only in the sandbox; re-open
        # the dedicated authelia log dir for writing (the log moved out of the
        # state dir so crowdsec can read it without reaching db.sqlite3).
        serviceConfig.ReadWritePaths = [ autheliaLogDir ];
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
        # listener therefore expects proxy_protocol and is bound to loopback —
        # only the stream (upstream nginx_https = 127.0.0.1:${port}) ever reaches
        # it, so there's no reason to expose it on all interfaces (the firewall
        # drops it externally too; loopback removes the reliance on that rule).
        # Port 80 is the public HTTP entrypoint (ACME + redirects) and stays
        # externally bound; it must NOT expect proxy_protocol. real_ip (below)
        # rewrites $remote_addr to the real client for logs, rate-limits, crowdsec.
        defaultListen =
          map
            (addr: {
              inherit addr;
              port = nginxInternalSSLPort;
              ssl = true;
              proxyProtocol = true;
            })
            [
              "127.0.0.1"
              "[::1]"
            ]
          ++
            map
              (addr: {
                inherit addr;
                port = 80;
                ssl = false;
              })
              [
                "0.0.0.0"
                "[::0]"
              ];
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;
        recommendedBrotliSettings = true;
        recommendedProxySettings = true;

        commonHttpConfig = ''
          # Take the real client IP from the loopback stream proxy's
          # PROXY-protocol header, rewriting $remote_addr before the
          # limit_req/limit_conn zones and access log evaluate it — so per-IP
          # rate-limiting, X-Forwarded-For, and crowdsec all see the real client.
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

      # fail2ban is disabled on the gateway for now — CrowdSec owns all
      # intrusion detection here (sshd, nginx, authelia), with its escalating ban
      # profile below standing in for fail2ban's bantime-increment. The authelia
      # jail + filter are kept dormant under the disabled service so fail2ban can
      # be flipped back on as an enforcement floor in one line.
      services.fail2ban.enable = lib.mkForce false;
      services.fail2ban.jails = {
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
          # Raw LDAP on loopback (authelia-only). Web UI on 0.0.0.0, overlay-only
          # (not opened publicly; see firewall comment).
          ldap_host = "127.0.0.1";
          ldap_port = lldapPort;
          http_host = "0.0.0.0";
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

      # ntfy-sh — self-hosted push notifications at https://ntfy.kclj.dev, fronted
      # by the NetBird proxy (overlay-only; see firewall comment). Non-secret
      # config is here (rendered to the
      # world-readable /etc/ntfy/server.yml); the VAPID private key, the bcrypt
      # auth-users, and the Fastmail SMTP creds are injected via the sops
      # EnvironmentFile, out of the store.
      services.ntfy-sh = {
        enable = true;
        settings = {
          base-url = "https://ntfy.kclj.dev";
          listen-http = ":${toString ntfyPort}";
          behind-proxy = true;
          upstream-base-url = "https://ntfy.sh";
          message-size-limit = "4096";
          keepalive-interval = "45s";

          # Login required, deny-all by default; only "up*" topics are writable
          # unauthenticated (the wildcard rule from server.yml).
          auth-default-access = "deny-all";
          enable-login = true;
          enable-signup = false;
          enable-reservations = true;
          require-login = true;
          auth-access = [ "*:up*:write-only" ];

          # Attachment blobs in the CacheDirectory; message cache in StateDirectory.
          attachment-cache-dir = "/var/cache/ntfy-sh";
          attachment-file-size-limit = "20M";
          attachment-total-size-limit = "10G";
          attachment-expiry-duration = "4h";
          cache-file = "/var/lib/ntfy-sh/cache.db";
          cache-duration = "24h";

          # Web push (public key is safe in the store; private key via env below).
          web-push-public-key = "BPdEZgJlsAC_xA7_ctmlQVcCJbC9y6eCIr2W48XKJTqEEQ1uMYnZOa84MwEzL-_lXDlyV1jYDSTd70eOQ1p5Igs";
          web-push-file = "/var/lib/ntfy-sh/webpush.db";
          web-push-email-address = "admin@kclj.io";

          # Outgoing email notifications via Fastmail — same submission host +
          # account as authelia; user/pass injected via the EnvironmentFile.
          smtp-sender-addr = "smtp.fastmail.com:587";
          smtp-sender-from = "noreply+ntfy@kclj.io";
        };
        environmentFile = config.sops.templates."ntfy.env".path;
      };
      # Attachment blobs live in a CacheDirectory the module doesn't declare.
      systemd.services.ntfy-sh.serviceConfig.CacheDirectory = "ntfy-sh";

      # Secrets for ntfy's EnvironmentFile, out of the world-readable store. SMTP
      # creds are shared with authelia's Fastmail account; the ntfy/* values must
      # be added to secrets/gateway.yaml.
      sops.templates."ntfy.env".content = ''
        NTFY_WEB_PUSH_PRIVATE_KEY=${config.sops.placeholder."ntfy/web_push_private_key"}
        NTFY_AUTH_USERS=${config.sops.placeholder."ntfy/auth_users"}
        NTFY_SMTP_SENDER_USER=${config.sops.placeholder."authelia/smtp_username"}
        NTFY_SMTP_SENDER_PASS=${config.sops.placeholder."authelia/smtp_password"}
      '';

      # --- Beszel hub (server monitoring) ---
      # Web UI + agent endpoint on 0.0.0.0:${toString beszelPort}. Like the other
      # internal UIs it binds all interfaces but isn't in allowedTCPPorts, so the
      # public NIC default-drops it while the trusted overlay (wt0/tailscale0)
      # admits it: agents connect in over the tailnet (WebSocket + per-host
      # token), and humans reach it via beszel.kclj.dev through the netbird-proxy
      # (register beszel.kclj.dev -> 127.0.0.1:${toString beszelPort} in the NetBird
      # dashboard, same as grafana.kclj.dev). State (PocketBase db) lives in
      # /var/lib/beszel-hub. Agents enroll via flake.nixosModules.beszel-agent.
      # Agent for the hub's own host (enrolled via flake.nixosModules.beszel-agent
      # in flake.nix). Talk to the local hub directly instead of hairpinning
      # through the tailnet; needs gateway's own beszel/token in secrets/gateway.yaml.
      services.beszel.agent.environment.HUB_URL = "http://127.0.0.1:${toString beszelPort}";

      services.beszel.hub = {
        enable = true;
        host = "0.0.0.0";
        port = beszelPort;
        environment = {
          # Public URL behind the netbird-proxy — used for OIDC redirect/callback,
          # links/notifications, and the agent-config snippet the UI generates.
          APP_URL = "https://beszel.kclj.dev";
          # Auto-create the Beszel user on first successful Authelia OIDC login.
          # The Authelia client (id `beszel`) is declared above; finish wiring by
          # adding the OIDC provider in Beszel's users-collection Options (secret
          # from sops beszel/authelia_client_secret). Password auth is left on so
          # the superuser console at /_/ keeps working; flip on DISABLE_PASSWORD_AUTH
          # once OIDC login is confirmed if you want OIDC-only dashboard users.
          USER_CREATION = "true";
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
          # IPv6: deny loopback, link-local (fe80::/10) and ULA (fc00::/7) so the
          # TURN relay can't be abused to reach internal v6 targets (SSRF). The
          # IPv4 ranges above don't cover these; coturn takes start-end ranges.
          denied-peer-ip=::1
          denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff
          denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
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

      # CrowdSec — local detection (sshd, nginx, authelia) plus the community/CAPI
      # blocklist, enforced at nftables by the firewall bouncer and surfaced to
      # the netbird proxy's embedded bouncer. LAPI/metrics are moved off their
      # 8080/6060 defaults (see the port bindings above).
      services.crowdsec.enable = true;
      services.crowdsec.settings.general = {
        api.server.listen_uri = "127.0.0.1:${toString crowdsecLapiPort}";
        prometheus.listen_port = crowdsecMetricsPort;
      };

      # crowdsecurity/linux brings the sshd parser + ssh-bf scenarios; nginx adds
      # HTTP probing/scanner/bad-bot detection. nginx detection depends on the
      # real client IP from PROXY protocol (set_real_ip_from above) — without it
      # nginx logs 127.0.0.1 and crowdsec would ban loopback. The whitelists
      # (crowdsec module + overlay below) are the belt-and-suspenders backstop.
      services.crowdsec.hub.collections = [
        "crowdsecurity/linux"
        "crowdsecurity/nginx"
        # Community collection: authelia parser + auth brute-force scenarios.
        "LePresidente/authelia"
      ];

      # Data sources: sshd via journald; nginx + authelia via their log files.
      # authelia is read from its file, not journald, on purpose: journald
      # prefixes each line with a syslog header that breaks the LePresidente
      # parser's JSON unmarshal. The 0600 log is made readable via the ACL below.
      services.crowdsec.localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
          labels.type = "syslog";
        }
        {
          source = "file";
          filenames = [ autheliaLogFile ];
          labels.type = "authelia";
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

      # Create the dedicated authelia log dir (tmpfiles, so it exists before the
      # ACL is applied and before authelia starts) and grant crowdsec read on it
      # — this dir holds only the log, no secrets. The default ACL covers the log
      # file when authelia (re)creates it. ProtectSystem=strict on authelia makes
      # /var/log read-only in its sandbox, so ReadWritePaths re-opens this dir for
      # writing. The old ACL on the state dir is removed; revoke any lingering
      # grant there with `setfacl -b ${autheliaStateDir}` (tmpfiles `a+` is
      # additive and won't retract it on its own).
      systemd.tmpfiles.rules = [
        "d ${autheliaLogDir} 0750 ${autheliaUser} ${autheliaUser} - -"
        "a+ ${autheliaLogDir} - - - - u:crowdsec:rx,d:u:crowdsec:r"
        "a+ ${autheliaLogFile} - - - - u:crowdsec:r"
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

      # Replicate fail2ban's escalating bantime (old: 1h base → 48h cap) on the
      # remediation profiles — CrowdSec has no native increment, so the ban
      # duration is computed per-decision by duration_expr from the offender's
      # prior decision count. Replaces the upstream flat-4h default profiles; the
      # whitelists above still pre-empt bans for trusted sources.
      services.crowdsec.localConfig.profiles =
        let
          # 1st offense → 4h, 2nd → 8h, … capped at 48h. Ternary (not min) keeps
          # the result an integer so Sprintf '%dh' is valid across expr versions.
          escalatingBan =
            "GetDecisionsCount(Alert.GetValue()) >= 11 ? '48h' "
            + ": Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 4)";
          mkProfile = name: scope: {
            inherit name;
            filters = [ "Alert.Remediation == true && Alert.GetScope() == '${scope}'" ];
            decisions = [
              {
                type = "ban";
                duration = "4h";
              }
            ];
            duration_expr = escalatingBan;
            on_success = "break";
          };
        in
        [
          (mkProfile "default_ip_remediation" "Ip")
          (mkProfile "default_range_remediation" "Range")
        ];

      # crowdsec reads the journal (sshd) via systemd-journal and the nginx logs
      # (nginx:nginx 0640 in a 0750 dir) via the nginx group.
      systemd.services.crowdsec.serviceConfig.SupplementaryGroups = [
        "nginx"
        "systemd-journal"
      ];

      # Firewall bouncer: enforces CrowdSec decisions (local + community
      # blocklist) at nftables. Auto-registers with the LAPI and self-configures.
      services.crowdsec-firewall-bouncer.enable = true;

      services.crowdsec.declarativeBouncers.netbird-proxy.keyFile =
        config.sops.secrets."crowdsec/bouncer_key".path;
      # CrowdSec Console enrollment is a one-time manual bootstrap (also needs
      # approving the machine in the web UI), so it isn't declared here. Enroll
      # once with a token from app.crowdsec.net (Security Engines → Enroll):
      #   sudo cscli console enroll <token> --name gateway
      # The sharing config below takes effect once enrolled; trim to keep local.
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
        NB_PROXY_PROXY_PRIVATE=true
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
