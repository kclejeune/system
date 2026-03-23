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
        path = "/var/lib/authelia-${autheliaInstance}/users.yaml";
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

      # Necessary for Caddy integration
      # See https://www.authelia.com/integration/proxies/caddy/#implementation
      server.endpoints.authz.forward-auth.implementation = "ForwardAuth";
    };
    secrets = {
      jwtSecretFile = config.sops.secrets."authelia/jwt_secret".path;
      sessionSecretFile = config.sops.secrets."authelia/session_secret".path;
      storageEncryptionKeyFile = config.sops.secrets."authelia/storage_encryption_key".path;
    };
  };

  # Caddy - reverse proxy
  services.caddy = {
    enable = true;
    virtualHosts."auth.${domain}".extraConfig = ''
      reverse_proxy localhost:${toString autheliaPort}
    '';
    # Snippet for protecting other services with Authelia
    # Import with: import auth
    extraConfig = ''
      (auth) {
        forward_auth localhost:${toString autheliaPort} {
          uri /api/authz/forward-auth
          copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
        }
      }
    '';
  };

  # Passwordless sudo via SSH agent forwarding
  security.pam.rssh.enable = true;
  security.pam.services.sudo.rssh = true;

  # Netbird - mesh VPN
  services.netbird.enable = true;

  system.stateVersion = "25.11";
}
