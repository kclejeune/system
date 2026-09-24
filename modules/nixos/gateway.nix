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
      lldapSecretsGroup = "lldap-secrets";
      # Separate from the state dir so crowdsec can read the log without reaching db.sqlite3.
      autheliaLogDir = "/var/log/authelia-${autheliaInstance}";
      autheliaLogFile = "${autheliaLogDir}/authelia.log";
      inherit (config.site) domain;
      autheliaPort = 9091;
      lldapPort = 3890;
      lldapHttpPort = 17170;
      baseDN = "dc=kclj,dc=io";
      autheliaMetricsPort = 9959;
      authDomain = "auth.${domain}";
      netbirdDomain = "netbird.${domain}";
      netbirdProxyDomain = config.site.proxyDomain;
      netbirdProxyPort = 8443;
      # 51820 is the host's wt0 and 49152+ coturn's relay range. Fixed so the
      # firewall can admit direct peer→proxy connections instead of TURN relay.
      netbirdProxyWgPort = 51821;
      netbirdMgmtPort = 8011;
      netbirdMgmtMetricsPort = 9190;
      netbirdSignalMetricsPort = 9191;
      nginxInternalSSLPort = 4443;
      # crowdsec's 8080/6060 defaults collide with netbird-proxy and netbird-signal.
      crowdsecLapiPort = 8090;
      crowdsecMetricsPort = 9060;
      beszelPort = 8091; # 8090 default collides with crowdsecLapiPort
      tracewayPort = 8095;
      ntfyPort = lib.toInt (lib.removePrefix ":" config.services.ntfy-sh.settings.listen-http);
      tracewayDomain = "traceway.${domain}";

      mkHttpsVhost = extra: {
        forceSSL = true;
        enableACME = true;
        extraConfig = extra;
      };
    in
    {
      imports = [
        flakeCfg.flake.nixosModules.crowdsec
        flakeCfg.flake.nixosModules.monitoring-stack
        flakeCfg.flake.nixosModules.ntfy
        flakeCfg.flake.nixosModules.smtp
        flakeCfg.flake.nixosModules.traceway
        flakeCfg.flake.nixosModules.traceway-agent
      ];

      smtp.host = "smtp.fastmail.com";

      networking.hostName = "gateway";

      # /nix lives on this volume, so it must mount in initrd.
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

      networking.firewall = {
        allowedTCPPorts = [
          80
          443
        ];
        # Direct peer→proxy WireGuard instead of relaying through coturn.
        allowedUDPPorts = [ netbirdProxyWgPort ];

        # Internet-facing, so overlay peers only get the ports opened below;
        # tailscale serve/SSH are handled inside tailscaled. "lo" is restated
        # because mkForce drops the firewall module's own entry.
        trustedInterfaces = lib.mkForce [ "lo" ];

        # The NetBird proxy can only dial overlay-IP backends, so these arrive on wt0.
        interfaces.${config.services.netbird.clients.default.interface}.allowedTCPPorts = [
          config.services.grafana.settings.server.http_port
          config.services.prometheus.port
          config.services.prometheus.alertmanager.port
          config.services.karma.settings.listen.port
          lldapHttpPort
          ntfyPort
          beszelPort
        ];
      };

      # Own table ahead of nixos-fw so these fire before its port accepts.
      # Echo-request only: limiting all of ICMPv6 would throttle NDP.
      networking.nftables.tables.gateway-ratelimit = {
        family = "inet";
        content = ''
          chain input {
            type filter hook input priority filter - 5; policy accept;
            iifname "lo" accept
            tcp flags syn / fin,syn,rst,ack limit rate over 200/second burst 500 packets drop
            icmpv6 type echo-request limit rate over 10/second burst 20 packets drop
          }
        '';
      };

      # Root keys as a rescue path on the only public-facing host.
      identity.enableRootSshKeys = true;

      # Key-only, so the rescue keys above work.
      services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

      users.users.${config.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };

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
          # Authelia reads this by path (_FILE), so it must own it.
          "smtp/password".owner = autheliaUser;
          "lldap/jwt_secret" = { };
          "lldap/ldap_user_pass" = {
            group = lldapSecretsGroup;
            mode = "0440";
          };
          "cloudflare/api-token" = { };
          "netbird/datastore_encryption_key" = { };
          "netbird/turn_password" = {
            owner = "turnserver";
          };
          # Plaintext for Dex's Authelia connector; the pbkdf2 hash is in the
          # netbird client below — rotate together.
          "netbird/authelia_client_secret" = { };
          "netbird/proxy_token" = { };
          # Shared by the CrowdSec LAPI and netbird-proxy's bouncer.
          "crowdsec/bouncer_key" = { };
          # nimbus/oidc_client_secret also lives in gateway.yaml but is consumed by
          # the Cloudflare worker (`wrangler secret put`), not this host.
        };
      };

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
          webauthn = {
            enable_passkey_login = true;
            # A user-verifying passkey alone satisfies two_factor (no password step).
            # Experimental upstream; re-check after Authelia bumps.
            experimental_enable_passkey_uv_two_factors = true;
            # Required for the flag above; "preferred" lets non-UV passkeys fall back
            # to the password prompt.
            selection_criteria.user_verification = "required";
          };

          # Ban by IP, not account, so a third party can't lock out a known username.
          regulation = {
            modes = [ "ip" ];
            max_retries = 3;
            find_time = "2m";
            ban_time = "10m";
          };

          # Pinned to the current upstream defaults so a nixos-unstable bump can't
          # silently loosen them.
          server.endpoints.rate_limits = {
            reset_password_start.buckets = [
              {
                period = "10 minutes";
                requests = 5;
              }
              {
                period = "15 minutes";
                requests = 10;
              }
              {
                period = "30 minutes";
                requests = 15;
              }
            ];
            reset_password_finish.buckets = [
              {
                period = "1 minute";
                requests = 10;
              }
              {
                period = "2 minutes";
                requests = 15;
              }
            ];
            openid_connect_token.buckets = [
              {
                period = "1 minute";
                requests = 30;
              }
              {
                period = "2 minutes";
                requests = 40;
              }
              {
                period = "10 minutes";
                requests = 50;
              }
              {
                period = "1 hour";
                requests = 100;
              }
            ];
          };

          authentication_backend = {
            # Needs the lldap_password_manager group on the authelia service account.
            password_reset.disable = false;
            password_change.disable = false;
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
                # The cookie covers every *.kclj.io host, so keep a stolen or
                # forgotten session short-lived.
                inactivity = "1w";
                expiration = "1M";
                remember_me = "1M";
              }
            ];
          };

          notifier.smtp = {
            address = "submission://${config.smtp.host}:${toString config.smtp.port}";
            sender = "Authelia <noreply+auth@kclj.io>";
            subject = "[Authelia] {title}";
            disable_require_tls = false;
            tls.minimum_version = "TLS1.2";
          };

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
            # Dex rejects the upstream token without email_verified when the email
            # scope is requested.
            claims_policies.netbird.id_token = [
              "email"
              "email_verified"
              "name"
              "preferred_username"
              "groups"
            ];
            claims_policies.beszel.id_token = [
              "email"
              "email_verified"
              "name"
              "preferred_username"
            ];
            claims_policies.nimbus.id_token = [
              "email"
              "email_verified"
              "name"
              "preferred_username"
              "groups"
            ];
            # Traceway maps roles from the ID token's groups (goth ignores userinfo).
            claims_policies.traceway.id_token = [
              "email"
              "email_verified"
              "name"
              "preferred_username"
              "groups"
            ];
            # Without these the ID token has only `sub`. No groups: RustFS treats each
            # group as a policy name and fails the login on any unknown one.
            claims_policies.rustfs.id_token = [
              "email"
              "email_verified"
              "name"
              "preferred_username"
            ];
            # Traceway auto-provisions every OIDC login with write access, so
            # membership is enforced here. Tiers match services.traceway.oidc.roleMap.
            authorization_policies.traceway_users = {
              default_policy = "deny";
              rules = [
                {
                  policy = "two_factor";
                  subject = [
                    "group:lldap_admin"
                    "group:traceway_admin"
                    "group:traceway_user"
                  ];
                }
              ];
            };
            # Incus LTS has no per-user authz, so any OIDC login is admin.
            authorization_policies.incus_admins = {
              default_policy = "deny";
              rules = [
                {
                  policy = "two_factor";
                  subject = [ "group:lldap_admin" ];
                }
              ];
            };
            clients = [
              {
                # Plaintext secret (sops beszel/authelia_client_secret) is pasted into
                # Beszel's UI; PocketBase stores it itself.
                client_id = "beszel";
                client_name = "Beszel";
                client_secret = "$pbkdf2-sha512$310000$fMrobSxiOm/Y4AJfZZGiVA$hC9cyxI1.qN7/O09Jy0lcT1dc87lw12138OAUaC0G6ihI5iHBMkzU/zXfUIGD7Ezsrk6FfJa3GziuKqBgtOB2A";
                authorization_policy = "two_factor";
                consent_mode = "implicit";
                claims_policy = "beszel";
                redirect_uris = [
                  "https://beszel.kclj.dev/api/oauth2-redirect"
                  "https://beszel.${config.site.tailnetDomain}/api/oauth2-redirect"
                  # Beszel iOS companion app deep link (native PKCE flow).
                  "beszel-companion://redirect"
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
                client_id = "nimbus";
                client_name = "Nimbus";
                client_secret = "$pbkdf2-sha512$310000$wvfEcQQoFVxjnfA8Hch69A$VqUp/2iWKwIiyObavoOZxE0/T/juTtR7X4LZZ0Arm73435hrr7zdLs1g/5m78n9EbCOnxgN9mUBTZjEFJFlJGw";
                authorization_policy = "two_factor";
                consent_mode = "implicit";
                claims_policy = "nimbus";
                redirect_uris = [
                  "https://app.cache.kclj.io/api/auth/oauth2/callback/oidc"
                  # Local nimbus dev (`vite dev`).
                  "http://localhost:5173/api/auth/oauth2/callback/oidc"
                ];
                scopes = [
                  "openid"
                  "profile"
                  "email"
                  "groups"
                ];
                token_endpoint_auth_method = "client_secret_post";
                require_pkce = true;
                pkce_challenge_method = "S256";
              }
              {
                # No PKCE: Traceway's goth OIDC provider sends no code_challenge.
                client_id = "traceway";
                client_name = "Traceway";
                client_secret = "$pbkdf2-sha512$310000$gNo7ijU5nWrmnX3jGSLU2Q$sq7sQiPcOV7kt7VC/v/9xPKCNXcgU.sqv0..u7fk.WBbpITeN7dg4FmPJiICe0we.CP7IQWqLFuhmsB/cgoUdg";
                authorization_policy = "traceway_users";
                consent_mode = "implicit";
                claims_policy = "traceway";
                redirect_uris = [
                  "https://${tracewayDomain}/api/auth/callback/oidc"
                ];
                scopes = [
                  "openid"
                  "profile"
                  "email"
                  "groups"
                ];
                token_endpoint_auth_method = "client_secret_basic";
              }
              {
                # Dex's upstream connector. Dex uses one shared callback (issuer +
                # /callback), which must match StaticConnectors' redirectURI below.
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
                  "groups"
                ];
                token_endpoint_auth_method = "client_secret_basic";
                require_pkce = true;
                pkce_challenge_method = "S256";
              }
              {
                # Public client (Incus LTS has no client secret). RS256 access tokens are
                # required: incusd verifies them offline as JWTs, and opaque tokens make
                # every API call fail as untrusted.
                client_id = "incus";
                client_name = "Incus";
                public = true;
                authorization_policy = "incus_admins";
                consent_mode = "implicit";
                redirect_uris = [
                  "https://incus.${config.site.lanDomain}/oidc/callback"
                ];
                audience = [ "https://incus.${config.site.lanDomain}" ];
                scopes = [
                  "openid"
                  "offline_access"
                  "email"
                  "profile"
                ];
                response_types = [ "code" ];
                grant_types = [
                  "authorization_code"
                  "refresh_token"
                ];
                access_token_signed_response_alg = "RS256";
                userinfo_signed_response_alg = "none";
                token_endpoint_auth_method = "none";
                require_pkce = true;
                pkce_challenge_method = "S256";
              }
              {
                # RustFS derives the callback from the request host, so this list is the
                # real allowlist. The path must match modules/nixos/rustfs.nix.
                client_id = "rustfs";
                client_name = "RustFS";
                claims_policy = "rustfs";
                client_secret = "$pbkdf2-sha512$310000$F9PuuzoVd9k1.HhBtZng8g$NgOuUlxf5zHDJaqxyyXj1QeLEEU0NVPj7TFFOeJ9Ga1Py627V0OL0iYnVAmHjtZlffQNzcUVxnZgow7jdGhn5Q";
                authorization_policy = "two_factor";
                consent_mode = "implicit";
                redirect_uris = [
                  "https://s3.${config.site.lanDomain}/rustfs/admin/v3/oidc/callback/default"
                  "https://s3.${config.site.tailnetDomain}/rustfs/admin/v3/oidc/callback/default"
                ];
                scopes = [
                  "openid"
                  "profile"
                  "email"
                ];
                token_endpoint_auth_method = "client_secret_post";
                require_pkce = true;
                pkce_challenge_method = "S256";
              }
            ];
          };
        };
        environmentVariables = {
          AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = config.sops.secrets."smtp/password".path;
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

      # Authelia has no _FILE option for the SMTP username.
      sops.templates."authelia-smtp.env" = {
        owner = autheliaUser;
        content = ''
          AUTHELIA_NOTIFIER_SMTP_USERNAME=${config.sops.placeholder."smtp/username"}
          AUTHELIA_NOTIFIER_SMTP_STARTUP_CHECK_ADDRESS=${config.sops.placeholder."smtp/username"}
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
        # ProtectSystem=strict makes /var/log read-only.
        serviceConfig.ReadWritePaths = [ autheliaLogDir ];
      };

      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "kc.lejeune@gmail.com";
          dnsProvider = "cloudflare";
          environmentFile = config.sops.secrets."cloudflare/api-token".path;
        };
      };

      services.nginx = {
        enable = true;
        defaultSSLListenPort = nginxInternalSSLPort;
        # The 443 SNI stream re-proxies here over loopback with PROXY protocol to
        # carry the client IP. Port 80 (ACME + redirects) is direct and must not
        # expect it.
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

      services.lldap = {
        enable = true;
        settings = {
          # Web UI on 0.0.0.0: NetBird proxy backends can't be loopback (wt0 only).
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

      # lldap is DynamicUser; a static group keeps the secret away from every
      # other service account.
      users.groups.${lldapSecretsGroup} = { };
      systemd.services.lldap.serviceConfig.SupplementaryGroups = [ lldapSecretsGroup ];

      sops.templates."lldap.env".content = ''
        LLDAP_JWT_SECRET=${config.sops.placeholder."lldap/jwt_secret"}
      '';

      services.redis.servers.authelia = {
        enable = true;
        port = 0; # Unix socket only
      };
      users.users.${autheliaUser}.extraGroups = [ "redis-authelia" ];

      # Agents reach the hub via its Tailscale Serve VIP, humans via
      # beszel.kclj.dev on the NetBird proxy. The hub's own agent talks to it
      # directly instead of hairpinning through the tailnet.
      services.beszel.agent.environment.HUB_URL = "http://127.0.0.1:${toString beszelPort}";

      services.beszel.hub = {
        enable = true;
        host = "0.0.0.0";
        port = beszelPort;
        environment = {
          # Used for OIDC callbacks and the agent snippet the UI generates.
          APP_URL = "https://beszel.kclj.dev";
          # Create users on first OIDC login. Password auth stays on for the /_/
          # superuser console.
          USER_CREATION = "true";
        };
      };
      # On the DMZ box: ingest is an unauthenticated parser of SDK payloads from
      # the internet, so it sits behind nginx + CrowdSec rather than opening a path
      # into the LAN. The R2 bucket needs a lifecycle rule on recordings/ (the
      # retention worker is a no-op on S3).
      services.traceway = {
        domain = tracewayDomain;
        port = tracewayPort;
        s3 = {
          bucket = "traceway";
          endpoint = "https://${config.site.cloudflareAccountId}.r2.cloudflarestorage.com";
        };
        oidc = {
          discoveryUrl = "https://${authDomain}/.well-known/openid-configuration";
          displayName = "Authelia";
          # Mirrors the traceway_users policy; re-applied on every login.
          roleMap = {
            lldap_admin = "admin";
            traceway_admin = "admin";
            traceway_user = "user";
          };
          disablePasswordLogin = true;
        };
        # bare address: the app passes it verbatim to MAIL FROM
        smtpFrom = "noreply+traceway@${domain}";
      };
      # Dashboard gets the host's general per-IP limit; the module leaves the
      # ingest locations unthrottled on purpose (shared Cloudflare egress IPs).
      services.nginx.virtualHosts.${tracewayDomain} = {
        extraConfig = ''
          limit_conn per_ip 50;
          limit_conn_status 429;
        '';
        locations."/".extraConfig = ''
          limit_req zone=general burst=60 nodelay;
          limit_req_status 429;
        '';
      };

      # Full client: accepts tailnet routes, advertises no LAN.
      services.tailscale.server.acceptRoutes = true;

      # UIs that self-authenticate or rely on tailnet identity. Grafana isn't
      # here: its auth.proxy header only comes from the NetBird proxy. 127.0.0.1,
      # not localhost: localhost resolves ::1 first and these bind IPv4.
      services.tailscale.serve.services = {
        beszel.endpoints."tcp:443" = "http://127.0.0.1:${toString beszelPort}";
        lldap.endpoints."tcp:443" = "http://127.0.0.1:${toString lldapHttpPort}";
        prometheus.endpoints."tcp:443" = "http://127.0.0.1:${toString config.services.prometheus.port}";
        alertmanager.endpoints."tcp:443" =
          "http://127.0.0.1:${toString config.services.prometheus.alertmanager.port}";
        karma.endpoints."tcp:443" =
          "http://127.0.0.1:${toString config.services.karma.settings.listen.port}";
      };

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
          # Mandatory upstream option; unused with EmbeddedIdP.
          oidcConfigEndpoint = "https://${netbirdDomain}/oauth2/.well-known/openid-configuration";
          metricsPort = netbirdMgmtMetricsPort;
          settings = {
            DataStoreEncryptionKey._secret = config.sops.secrets."netbird/datastore_encryption_key".path;
            TURNConfig.Secret._secret = config.sops.secrets."netbird/turn_password".path;
            # Keys netbird-idp-migrate strips; null in management.json reads as absent.
            IdpManagerConfig = lib.mkForce null;
            PKCEAuthorizationFlow = lib.mkForce null;
            DeviceAuthorizationFlow = lib.mkForce null;
            # The connector id must match the one used with netbird-idp-migrate:
            # user IDs in store.db are bound to it.
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

      # OIDC discovery needs Authelia up.
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

      # Block TURN relaying into internal networks (SSRF).
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

      # The netbird module's vhost lacks Dex's /oauth2 and the dashboard's
      # post-migration auth callbacks.
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

      services.crowdsec.enable = true;
      services.crowdsec.settings.general = {
        api.server.listen_uri = "127.0.0.1:${toString crowdsecLapiPort}";
        prometheus.listen_port = crowdsecMetricsPort;
      };

      # nginx detection relies on the PROXY-protocol real IP; without it crowdsec
      # would ban loopback.
      services.crowdsec.hub.collections = [
        "crowdsecurity/linux"
        "crowdsecurity/nginx"
        # Community collection: authelia parser + auth brute-force scenarios.
        "LePresidente/authelia"
      ];

      # authelia from its file, not journald: the syslog prefix breaks the
      # LePresidente parser's JSON.
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

      # crowdsec can read only this log-only dir, never the state dir's auth DB.
      systemd.tmpfiles.rules = [
        "d ${autheliaLogDir} 0750 ${autheliaUser} ${autheliaUser} - -"
        "a+ ${autheliaLogDir} - - - - u:crowdsec:rx,d:u:crowdsec:r"
        "a+ ${autheliaLogFile} - - - - u:crowdsec:r"
      ];

      # Never ban an overlay peer.
      services.crowdsec.localConfig.parsers.s02Enrich = [
        {
          name = "gateway/trusted-overlay";
          description = "Never ban tailscale/netbird overlay sources";
          whitelist = {
            reason = "trusted overlay networks (tailscale / netbird)";
            cidr = [
              "100.64.0.0/10"
              "100.100.0.0/16"
              "10.64.0.0/16"
            ];
          };
        }
      ];

      # Escalating bans (4h, 8h, … capped at 48h); CrowdSec has no native increment.
      services.crowdsec.localConfig.profiles =
        let
          # Ternary, not min, keeps the result an integer for Sprintf '%dh'.
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

      systemd.services.crowdsec.serviceConfig.SupplementaryGroups = [
        "nginx"
        "systemd-journal"
      ];

      services.crowdsec-firewall-bouncer.enable = true;

      services.crowdsec.declarativeBouncers.netbird-proxy.keyFile =
        config.sops.secrets."crowdsec/bouncer_key".path;
      # Console enrollment is a one-time manual step:
      #   sudo cscli console enroll <token> --name gateway
      services.crowdsec.settings.console.configuration = {
        share_manual_decisions = true;
        share_tainted = true;
        share_context = true;
        share_custom = true;
        # Community and subscribed blocklists arrive over PAPI; without this none apply.
        console_management = true;
      };

      # Podman ships no unqualified-search registries.
      virtualisation.containers.registries.search = [ "docker.io" ];

      virtualisation.oci-containers.containers.netbird-proxy = {
        # Lockstep with the netbird server version.
        image = "netbirdio/reverse-proxy:${config.services.netbird.server.management.package.version}";
        environmentFiles = [ config.sops.templates."netbird-proxy.env".path ];
        volumes = [
          "netbird-proxy-certs:/certs"
          # Private mode needs a persistent WireGuard identity; the rootfs is read-only.
          "netbird-proxy-state:/var/lib/netbird"
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
        NB_PROXY_PROXY_PROTOCOL=true
        NB_PROXY_PRIVATE=true
        NB_PROXY_WG_PORT=${toString netbirdProxyWgPort}
        NB_PROXY_TRUSTED_PROXIES=127.0.0.1/32,::1/128
      ''
      + lib.optionalString config.services.crowdsec.enable ''
        NB_PROXY_CROWDSEC_API_URL=http://127.0.0.1:${toString crowdsecLapiPort}
        NB_PROXY_CROWDSEC_API_KEY=${config.sops.placeholder."crowdsec/bouncer_key"}
      '';

      systemd.services.podman-netbird-proxy = lib.mkMerge [
        {
          # oci-containers don't restart on env-file content changes.
          restartTriggers = [ config.sops.templates."netbird-proxy.env".content ];
        }
        # The bouncer key must be registered before the proxy starts.
        (lib.mkIf config.services.crowdsec.enable {
          after = [ "crowdsec-register-netbird-proxy.service" ];
          wants = [ "crowdsec-register-netbird-proxy.service" ];
        })
      ];

      # SNI routing: *.kclj.dev passes through to netbird-proxy (own TLS),
      # everything else to nginx.
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
