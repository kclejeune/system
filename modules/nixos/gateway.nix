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

  # Passwordless sudo via SSH agent forwarding
  security.pam.rssh.enable = true;
  security.pam.services.sudo.rssh = true;

  # Netbird - mesh VPN
  services.netbird.enable = true;

  system.stateVersion = "25.11";
}
