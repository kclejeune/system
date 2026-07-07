_: {
  # forge — general / dev-utilities node. Bare-metal Lenovo P3 Tiny.
  # The nix binary cache moved off this node: nimbus (Cloudflare worker)
  # replaced the local atticd service.
  flake.nixosModules.forge =
    { config, ... }:
    {
      networking.hostName = "forge";
      sops.defaultSopsFile = ../../secrets/forge.yaml;

      # --- Reverse proxy (caddy-lan: ACME DNS-01) ---
      # forge.lan.kclj.io resolves via UniFi's local domain automatically.
      # cups has no matching client hostname, so it needs a UniFi
      # Local DNS Record -> forge to be reachable by name through caddy.
      # caddy-lan is enabled by homelab-node; just declare the proxies.
      services.caddyLan.proxies = {
        # CUPS web UI (the localhost:631 admin page) fronted on the LAN.
        # Proxy over HTTPS (CUPS serves TLS on the same :631 port, self-signed):
        # CUPS forces admin pages onto an encrypted connection and refuses a
        # plain-http hop with "You must access this page using the URL https://".
        # The https:// upstream makes caddy-lan use a skip-verify TLS transport.
        cups = "https://127.0.0.1:631";
      };

      # Expose the CUPS web UI over the tailnet too (svc:cups VIP, auto-HTTPS).
      # tailscale-server (via homelab-node) drives `tailscale serve` from this
      # set; the VIP resolves as cups.${config.site.tailnetDomain}. Target the
      # backend over HTTPS too (https+insecure://, CUPS's self-signed :631) for
      # the same reason as the caddy hop — CUPS rejects admin over plain http.
      services.tailscale.serve.services = {
        cups.endpoints."tcp:443" = "https+insecure://127.0.0.1:631";
      };

      # --- AirPrint (CUPS + avahi; network printer, not USB) ---
      services.airprint.enable = true;

      # CUPS 1.6+ validates the Host header and 400s any name that isn't
      # localhost or a configured alias — so both the caddy-proxied
      # cups.lan.kclj.io and the tailscale-serve cups.<tailnet> would be
      # rejected without this. Whitelist both.
      services.printing.extraConf = "ServerAlias cups.lan.kclj.io cups.${config.site.tailnetDomain}";
    };
}
