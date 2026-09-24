_: {
  # LAN Caddy with real Let's Encrypt certs for *.lan.kclj.io (Cloudflare
  # DNS-01). UniFi is authoritative for lan.kclj.io and refuses API records
  # under it, so proxied names without a matching DHCP client (cups, status)
  # need manual UniFi Local DNS Records.
  flake.nixosModules.caddy-lan =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.caddyLan;
      agent = config.services.traceway.agent or { enable = false; };

      # unifi + caddy-dynamicdns are unused (UniFi rejects records under its local
      # domain) but kept so re-enabling self-registration needs no rebuild.
      # Bump a plugin: hash = lib.fakeHash, rebuild, copy `got:`.
      caddyLan = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.2.4"
          "github.com/caddy-dns/unifi@v1.0.5"
          "github.com/mholt/caddy-dynamicdns@v0.0.0-20251231002810-1af4f8876598"
          "github.com/mholt/caddy-ratelimit@v0.1.0"
          "github.com/mholt/caddy-l4@v0.1.1"
        ];
        hash = "sha256-3YNjsWjbwtcj4qIHnZPHbmLtszPvX6ggvH28m+TieBo=";
      };

      # This LAN intercepts :53 (public resolvers are refused) and answers
      # lan.kclj.io without the ACME TXT, so the propagation check can never pass;
      # wait a fixed delay instead. Don't use `resolvers`.
      tlsBlock = ''
        tls {
          dns cloudflare {env.CF_DNS_API_TOKEN}
          propagation_delay 60s
          propagation_timeout -1
        }
      '';

      # An https:// upstream gets a skip-verify TLS transport, for backends with
      # self-signed loopback certs (e.g. Incus). Spans are named per vhost so each
      # LAN service groups separately in Traceway.
      mkTracing =
        sub:
        lib.optionalString agent.enable ''
          tracing {
            span ${sub}
            span_attributes {
              server.address {http.request.host}
            }
          }
        '';

      mkReverseProxy =
        upstream:
        if lib.hasPrefix "https://" upstream then
          ''
            reverse_proxy ${upstream} {
              transport http {
                tls_insecure_skip_verify
              }
              # Preserve the public Host to the backend. Proxying to an https://
              # upstream, Caddy otherwise sends the upstream's address as the
              # Host/:authority, so backends that build absolute URLs from the
              # request (e.g. Incus's OIDC redirect_uri) emit the loopback
              # address instead of <sub>.<baseDomain>. Force the original host.
              header_up Host {http.request.host}
            }
          ''
        else
          "reverse_proxy ${upstream}";
    in
    {
      options.services.caddyLan = {
        enable = lib.mkEnableOption "LAN Caddy (Cloudflare DNS-01 reverse proxy)";

        baseDomain = lib.mkOption {
          type = lib.types.str;
          default = config.site.lanDomain;
          defaultText = lib.literalExpression "config.site.lanDomain";
          description = "Zone every proxied subdomain hangs under.";
        };

        proxies = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = lib.literalExpression ''{ status = "127.0.0.1:8080"; incus = "https://127.0.0.1:8443"; }'';
          description = ''
            subdomain -> upstream "host:port". Each becomes a
            <subdomain>.<baseDomain> vhost with DNS-01 TLS + reverse_proxy.
            The name must resolve to this host: either it matches a UniFi DHCP
            client hostname, or add a UniFi Local DNS Record for it.

            Prefix the upstream with "https://" if the backend serves its own
            (self-signed) TLS — Caddy then proxies over TLS with verification
            skipped instead of plain http.
          '';
        };

        extraDirectives = lib.mkOption {
          type = lib.types.attrsOf lib.types.lines;
          default = { };
          example = lib.literalExpression ''{ s3 = "redir @browserRoot /rustfs/console/ 302"; }'';
          description = ''
            Extra Caddyfile directives for a proxied subdomain, emitted before
            its reverse_proxy. Keyed the same as `proxies`. For backends whose
            UI does not live at the site root.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # forge/vault/atlas don't trust their NIC, so open caddy's ports here.
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        # One DNS-01 token for all homelab nodes.
        sops.secrets."cloudflare/api-token".sopsFile = ../../secrets/homelab.yaml;

        # systemd reads EnvironmentFile only at start: restart, not reload, on
        # secret changes.
        sops.templates."caddy-lan.env" = {
          content = ''
            CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare/api-token"}
          '';
          restartUnits = [ "caddy.service" ];
        };

        services.caddy = {
          enable = true;
          package = caddyLan;
          email = "kc.lejeune@gmail.com";

          virtualHosts = lib.mapAttrs' (
            sub: upstream:
            lib.nameValuePair "${sub}.${cfg.baseDomain}" {
              extraConfig = ''
                ${tlsBlock}
                ${mkTracing sub}
                ${cfg.extraDirectives.${sub} or ""}
                ${mkReverseProxy upstream}
              '';
            }
          ) cfg.proxies;
        };

        systemd.services.caddy.serviceConfig.EnvironmentFile = config.sops.templates."caddy-lan.env".path;

        # Caddy's tracing reads OTEL_*; Traceway only speaks OTLP/HTTP.
        systemd.services.caddy.environment = lib.mkIf agent.enable {
          OTEL_SERVICE_NAME = "${config.networking.hostName}-caddy";
          OTEL_RESOURCE_ATTRIBUTES = "service.version=${caddyLan.version}";
          OTEL_EXPORTER_OTLP_ENDPOINT = agent.otlpEndpoint;
          OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
        };
      };
    };
}
