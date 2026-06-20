{ config, ... }:
{
  # Reusable LAN-facing Caddy: real Let's Encrypt certs for *.lan.kclj.io via
  # Cloudflare ACME DNS-01, plus optional UniFi dynamic-DNS self-registration.
  # The ACME propagation check is pinned to public resolvers (1.1.1.1/1.0.0.1)
  # because this LAN intercepts :53 and answers lan.kclj.io authoritatively
  # without the ACME TXT — querying public DNS directly lets the check run
  # normally instead of disabling it. Hosts set services.caddyLan.proxies.
  flake.nixosModules.caddy-lan =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.caddyLan;

      # Caddy + the five plugins (versions pinned in the plan's Global
      # Constraints). To bump: set hash = lib.fakeHash, rebuild, copy `got:`.
      caddyLan = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/caddy-dns/cloudflare@v0.2.4"
          "github.com/caddy-dns/unifi@v1.0.5"
          "github.com/mholt/caddy-dynamicdns@v0.0.0-20251231002810-1af4f8876598"
          "github.com/mholt/caddy-ratelimit@v0.1.0"
          "github.com/mholt/caddy-l4@v0.1.1"
        ];
        hash = "sha256-15NibrL5VXWrNj+PQH8md3ronxNo+B4v817LW/XdUy4=";
      };

      # Shared per-vhost TLS block: DNS-01 via Cloudflare. This LAN intercepts
      # outbound :53 and REFUSES queries to public resolvers (1.1.1.1/1.0.0.1
      # -> "connection refused"), and answers lan.kclj.io locally without the
      # ACME TXT — so Caddy's propagation self-check can never see the record.
      # Disable the self-check (propagation_timeout -1) and just wait a fixed
      # delay; Let's Encrypt then validates against real public DNS, which the
      # Cloudflare TXT does reach. (Do NOT use `resolvers` here — see git log.)
      tlsBlock = ''
        tls {
          dns cloudflare {env.CF_DNS_API_TOKEN}
          propagation_delay 60s
          propagation_timeout -1
        }
      '';
    in
    {
      options.services.caddyLan = {
        enable = lib.mkEnableOption "LAN Caddy (Cloudflare DNS-01 + UniFi dynamic DNS)";

        baseDomain = lib.mkOption {
          type = lib.types.str;
          default = "lan.kclj.io";
          description = "Zone every proxied subdomain hangs under.";
        };

        proxies = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = lib.literalExpression ''{ attic = "127.0.0.1:8080"; }'';
          description = ''
            subdomain -> upstream "host:port". Each becomes a
            <subdomain>.<baseDomain> vhost with DNS-01 TLS + reverse_proxy,
            and (when dynamicDns.enable) a UniFi DNS record.
          '';
        };

        dynamicDns = {
          enable = lib.mkEnableOption "self-register proxied subdomains into UniFi local DNS";
          interface = lib.mkOption {
            type = lib.types.str;
            example = "eno1";
            description = "LAN interface whose IPv4 to publish to UniFi.";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets = {
          "cloudflare/api-token" = { };
        }
        // lib.optionalAttrs cfg.dynamicDns.enable {
          "unifi/api-key" = { };
          "unifi/base-url" = { };
          "unifi/site-id" = { };
        };

        # EnvironmentFile assembled from sops so the token(s) never hit the
        # store. Cloudflare always; UniFi only when dynamic DNS is on.
        sops.templates."caddy-lan.env".content = ''
          CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare/api-token"}
        ''
        + lib.optionalString cfg.dynamicDns.enable ''
          UNIFI_API_KEY=${config.sops.placeholder."unifi/api-key"}
          UNIFI_BASE_URL=${config.sops.placeholder."unifi/base-url"}
          UNIFI_SITE_ID=${config.sops.placeholder."unifi/site-id"}
        '';

        services.caddy = {
          enable = true;
          package = caddyLan;
          email = "kc.lejeune@gmail.com";

          virtualHosts = lib.mapAttrs' (
            sub: upstream:
            lib.nameValuePair "${sub}.${cfg.baseDomain}" {
              extraConfig = ''
                ${tlsBlock}
                reverse_proxy ${upstream}
              '';
            }
          ) cfg.proxies;

          # Only emit dynamic_dns when there's at least one proxy to register —
          # an empty `domains` block risks managing the zone apex, and multiple
          # bare-infra hosts would then fight over it.
          globalConfig = lib.mkIf (cfg.dynamicDns.enable && cfg.proxies != { }) ''
            dynamic_dns {
              provider unifi {
                api_key {env.UNIFI_API_KEY}
                base_url {env.UNIFI_BASE_URL}
                site_id {env.UNIFI_SITE_ID}
              }
              domains {
                ${cfg.baseDomain} ${lib.concatStringsSep " " (lib.attrNames cfg.proxies)}
              }
              ip_source interface ${cfg.dynamicDns.interface}
              versions ipv4
              check_interval 5m
              ttl 300s
            }
          '';
        };

        systemd.services.caddy.serviceConfig.EnvironmentFile = config.sops.templates."caddy-lan.env".path;
      };
    };
}
