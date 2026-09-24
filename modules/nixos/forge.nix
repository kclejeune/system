_: {
  # forge — general / dev-utilities node.
  flake.nixosModules.forge =
    { config, ... }:
    {
      networking.hostName = "forge";
      sops.defaultSopsFile = ../../secrets/forge.yaml;

      # cups needs a UniFi Local DNS Record -> forge.
      services.caddyLan.proxies = {
        # https upstream: CUPS refuses admin pages over plain http.
        cups = "https://127.0.0.1:631";
      };

      # https+insecure for the same reason as the caddy hop.
      services.tailscale.serve.services = {
        cups.endpoints."tcp:443" = "https+insecure://127.0.0.1:631";
      };

      services.airprint.enable = true;

      # CUPS rejects any Host that isn't localhost or a listed alias.
      services.printing.extraConf = "ServerAlias cups.${config.site.lanDomain} cups.${config.site.tailnetDomain}";
    };
}
