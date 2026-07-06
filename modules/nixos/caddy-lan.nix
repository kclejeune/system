_: {
  # Reusable LAN-facing Caddy: real Let's Encrypt certs for *.lan.kclj.io via
  # Cloudflare ACME DNS-01, reverse-proxying LAN services by name.
  #
  # Name resolution is NOT done here. lan.kclj.io is the UniFi network's local
  # domain (Default LAN `domain_name = lan.kclj.io`), so UniFi is authoritative
  # for it (split-horizon) and auto-resolves every DHCP client's <hostname>.
  # That covers the host names (haven.lan.kclj.io etc.) for free. UniFi's DNS
  # policy API refuses to create ANY record under its own local domain
  # (`api.dns.policy.validation.overlap-with-local-dns`), so caddy cannot
  # self-register — proxied subdomains that have no matching client hostname
  # (e.g. cups, status) must be added as UniFi *Local DNS Records* pointing at
  # the caddy host. Hosts here just set services.caddyLan.proxies.
  #
  # The ACME propagation check is pinned to public resolvers (1.1.1.1/1.0.0.1)
  # because this LAN intercepts :53 and answers lan.kclj.io authoritatively
  # without the ACME TXT — querying public DNS directly lets the check run
  # normally instead of disabling it.
  flake.nixosModules.caddy-lan =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.caddyLan;

      # Caddy + plugins. cloudflare is the ACME DNS-01 provider; ratelimit/l4
      # are kept for planned use. unifi + caddy-dynamicdns are retained but
      # currently UNUSED: lan.kclj.io is UniFi's local domain, so its DNS API
      # rejects any record caddy tries to write under it (see module header) —
      # they're kept so re-enabling self-registration later (e.g. if the local
      # domain moves off lan.kclj.io) needs no caddy rebuild. To bump a plugin:
      # set hash = lib.fakeHash, rebuild, copy `got:`.
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

      # Upstreams are plain "host:port" (proxied over http). An upstream written
      # as "https://host:port" instead gets a TLS transport with verification
      # skipped — for backends that serve their own self-signed cert on a
      # loopback listener (e.g. Incus's API/UI on 127.0.0.1:8443) that we still
      # want to front with a real lan.kclj.io cert. Caddy terminates the browser
      # TLS here; the Caddy->backend hop is the self-signed leg.
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
          default = "lan.kclj.io";
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
      };

      config = lib.mkIf cfg.enable {
        # Make caddy reachable on the LAN. haven happens to expose these via
        # `firewall.trustedInterfaces = [ "br0" ]`, but forge/vault/atlas don't
        # trust their NIC, so without this their :443 is blocked and proxied
        # vhosts time out. Open the ports centrally so every caddy-lan host is
        # reachable regardless of per-host firewall posture.
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        sops.secrets."cloudflare/api-token" = { };

        # EnvironmentFile assembled from sops so the token never hits the store.
        # systemd only reads EnvironmentFile at process start, so caddy must be
        # restarted (not just reloaded) when the secret changes — otherwise a
        # deploy re-renders the env but caddy keeps running the old values.
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
                ${mkReverseProxy upstream}
              '';
            }
          ) cfg.proxies;
        };

        systemd.services.caddy.serviceConfig.EnvironmentFile = config.sops.templates."caddy-lan.env".path;
      };
    };
}
