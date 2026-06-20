_: {
  # atlas — infra / backup node. Bare-metal Lenovo P3 Tiny. Role scaffolding
  # only this round (monitoring / restic-repo orchestration land later).
  flake.nixosModules.atlas =
    { config, ... }:
    {
      networking.hostName = "atlas";

      users.users.${config.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
      identity.enableRootSshKeys = true;

      sops.defaultSopsFile = ../../secrets/atlas.yaml;
      # backup (restic/*) stays off in flake.nix until real restic repo /
      # password / R2 creds exist; beszel-agent is on (token in sops).

      # caddy-lan: ACME DNS-01 reverse proxy. No proxies yet (atlas has no web
      # UIs); add entries to `proxies` as services land (monitoring, etc.) and
      # each gets a LE cert. atlas.lan.kclj.io already resolves via UniFi's
      # local domain; proxied subdomains may need a UniFi Local DNS Record.
      services.caddyLan = {
        enable = true;
        proxies = { };
      };

      system.stateVersion = "25.11";
    };
}
