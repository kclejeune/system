_: {
  # Upstream's OCI image includes Node, the frontend and Kitinerary. Keep its
  # release/digest pinned; a native package would duplicate that build pipeline.
  flake.nixosModules.trek =
    { config, ... }:
    let
      domain = "trek.${config.site.lanDomain}";
      aliasDomain = "trek.${config.site.proxyDomain}";
      tailnetDomain = "trek.${config.site.tailnetDomain}";
      port = 8096;
      servePort = 8097;
      stateDir = "/var/lib/trek";
    in
    {
      sops.secrets."trek/oidc_client_secret" = { };
      sops.templates."trek.env".content = ''
        OIDC_CLIENT_SECRET=${config.sops.placeholder."trek/oidc_client_secret"}
        SMTP_USER=${config.sops.placeholder."smtp/username"}
        SMTP_PASS=${config.sops.placeholder."smtp/password"}
      '';

      # The entrypoint fixes volume ownership and then drops to the node user.
      # Keep the parent private; data/ also holds the generated JWT/encryption
      # keys, which must be preserved alongside the database and uploads.
      systemd.tmpfiles.rules = [
        "d ${stateDir} 0700 root root - -"
        "d ${stateDir}/data 0700 root root - -"
        "d ${stateDir}/uploads 0700 root root - -"
      ];

      virtualisation.oci-containers.containers.trek = {
        image = "docker.io/mauriceboe/trek:5.0.0@sha256:0c0a8f5b488fc2967248695e04bb000bb177d0b63d3385089d33dca6fde4daf9";
        ports = [ "127.0.0.1:${toString port}:3000" ];
        volumes = [
          "${stateDir}/data:/app/data"
          "${stateDir}/uploads:/app/uploads"
        ];
        environmentFiles = [ config.sops.templates."trek.env".path ];
        environment = {
          NODE_ENV = "production";
          NODE_OPTIONS = "--max-old-space-size=320";
          PORT = "3000";
          TZ = "America/New_York";
          APP_URL = "https://${domain}";
          ALLOWED_ORIGINS = "https://${domain},https://${aliasDomain},https://${tailnetDomain}";
          FORCE_HTTPS = "true";
          TRUST_PROXY = "1";
          SMTP_HOST = config.smtp.host;
          SMTP_PORT = toString config.smtp.port;
          SMTP_FROM = "TREK <noreply+trek@${config.site.domain}>";
          OIDC_ISSUER = "https://auth.${config.site.domain}";
          OIDC_CLIENT_ID = "trek";
          OIDC_DISPLAY_NAME = "Authelia";
          OIDC_ONLY = "true";
          OIDC_SCOPE = "openid email profile groups";
          OIDC_ADMIN_CLAIM = "groups";
          OIDC_ADMIN_VALUE = "lldap_admin";
        };
        extraOptions = [
          "--memory=512m"
          "--memory-swap=512m"
          "--cpus=0.5"
          "--cap-drop=ALL"
          "--cap-add=CHOWN"
          "--cap-add=SETUID"
          "--cap-add=SETGID"
          "--read-only"
          "--tmpfs=/tmp:rw,noexec,nosuid,size=128m"
          "--security-opt=no-new-privileges:true"
          # Podman does not see the Docker healthcheck in this OCI image.
          "--health-cmd=wget -qO- http://127.0.0.1:3000/api/health"
          "--health-interval=30s"
          "--health-timeout=10s"
          "--health-retries=3"
          "--health-start-period=30s"
          "--health-on-failure=kill"
        ];
      };
      systemd.services.podman-trek.restartTriggers = [ config.sops.templates."trek.env".content ];

      services.caddyLan.proxies.trek = "127.0.0.1:${toString port}";
      services.tailscale.serve.services.trek.endpoints."tcp:443" =
        "http://127.0.0.1:${toString servePort}";

      # Tailscale terminates HTTPS for ts.net; Caddy keeps the same request
      # protections as the LAN route without trying to issue a ts.net cert.
      services.caddy.virtualHosts."http://${tailnetDomain}:${toString servePort}" = {
        listenAddresses = [ "127.0.0.1" ];
        extraConfig = ''
          ${config.services.caddyLan.extraDirectives.trek}
          reverse_proxy 127.0.0.1:${toString port} {
            header_up X-Forwarded-Proto https
          }
        '';
      };
      services.caddyLan.extraDirectives.trek = ''
        # Even if another interface becomes reachable, this app is private.
        # remote_ip uses the connection address, not a spoofable client header.
        @trekOutside not remote_ip 127.0.0.0/8 ::1 ${config.site.lanCidr} ${builtins.concatStringsSep " " config.site.overlayCidrs} fd7a:115c:a1e0::/48

        # Apply these before the generated reverse_proxy.
        route {
          respond @trekOutside 403

          request_body {
            max_size 500MB
          }
        }
      '';
    };
}
