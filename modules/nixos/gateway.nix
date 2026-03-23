{
  config,
  ...
}:
let
  autheliaInstance = "main";
  autheliaUser = "authelia-${autheliaInstance}";
  domain = "kclj.io";
  autheliaPort = 9091;
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
    };
  };

  # Authelia - authentication server
  services.authelia.instances.${autheliaInstance} = {
    enable = true;
    settings = {
      theme = "auto";
      server.address = "tcp://127.0.0.1:${toString autheliaPort}/";
      log.level = "info";

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

      storage.local.path = "/var/lib/authelia-${autheliaInstance}/db.sqlite3";

      session.cookies = [
        {
          inherit domain;
          authelia_url = "https://auth.${domain}";
          inactivity = "1M";
          expiration = "3M";
          remember_me = "1y";
        }
      ];

      notifier.filesystem.filename = "/var/lib/authelia-${autheliaInstance}/notifications.txt";

      # Necessary for nginx integration
      # See https://www.authelia.com/integration/proxies/nginx/
      server.endpoints.authz.auth-request.implementation = "AuthRequest";
    };
    secrets = {
      jwtSecretFile = config.sops.secrets."authelia/jwt_secret".path;
      sessionSecretFile = config.sops.secrets."authelia/session_secret".path;
      storageEncryptionKeyFile = config.sops.secrets."authelia/storage_encryption_key".path;
    };
  };

  # ACME / Let's Encrypt
  security.acme = {
    acceptTerms = true;
    defaults.email = "kc.lejeune@gmail.com";
  };

  # Nginx - reverse proxy
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedBrotliSettings = true;
    recommendedProxySettings = true;

    commonHttpConfig = ''
      # HTTP/3 / QUIC
      quic_retry on;

      # Rate limiting for auth endpoints: 10 req/s per IP with burst of 20
      limit_req_zone $binary_remote_addr zone=authelia:10m rate=10r/s;
    '';

    virtualHosts."auth.${domain}" = {
      forceSSL = true;
      enableACME = true;
      http3 = true;
      quic = true;
      extraConfig = ''
        add_header Alt-Svc 'h3=":443"; ma=86400';
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString autheliaPort}";
        proxyWebsockets = true;
      };

      # Stricter rate limit on login/auth API endpoints
      locations."/api/" = {
        proxyPass = "http://127.0.0.1:${toString autheliaPort}";
        extraConfig = ''
          limit_req zone=authelia burst=20 nodelay;
          limit_req_status 429;
        '';
      };
    };
  };

  # Passwordless sudo via SSH agent forwarding
  security.pam.rssh.enable = true;
  security.pam.services.sudo.rssh = true;

  # Netbird - mesh VPN
  services.netbird.enable = true;

  system.stateVersion = "25.11";
}
