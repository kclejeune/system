_: {
  # Beszel monitoring agent. Connects OUT to the hub on gateway over the
  # tailnet (Tailscale MagicDNS name `gateway`) using a WebSocket + token —
  # nothing listens on this host and no firewall port is opened. The hub's
  # public key (KEY) is shared across all agents and is not secret; the
  # per-host TOKEN is. Mint both from the hub's "add system" dialog after the
  # hub is first deployed (see the Beszel hub block in modules/nixos/gateway.nix),
  # store TOKEN=<token> in the host's sops file under `beszel/token`, and paste
  # the hub key into KEY below.
  flake.nixosModules.beszel-agent =
    { config, lib, ... }:
    {
      services.beszel.agent = {
        enable = true;
        environment = {
          # Remote hosts reach the hub over the tailnet via its `tailscale serve`
          # service VIP (svc:beszel -> auto-HTTPS). The hub's own host overrides
          # this to http://127.0.0.1:8091 so it doesn't hairpin through the
          # overlay to monitor itself.
          HUB_URL = lib.mkDefault "https://beszel.${config.site.tailnetDomain}";
          # Hub's ed25519 public key — public and stable across all agents
          # (from the hub UI / GET /api/beszel/getkey).
          KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHuyt8ZnZRxhok4vQJ4nSFZKshbtG1wTbzpPI4cD72Eb";
        };
        # Supplies TOKEN=<per-host token> from sops, kept out of the store.
        environmentFile = config.sops.secrets."beszel/token".path;
      };

      # Per-host agent token. The enrolling host must provide `beszel/token`
      # (value: `TOKEN=<token>`) in its sops file; sops resolves it via the
      # host's sops.defaultSopsFile.
      sops.secrets."beszel/token" = { };
    };
}
