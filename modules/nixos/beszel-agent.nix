_: {
  # Connects out to the gateway hub over the tailnet, so nothing listens here.
  # KEY is the hub's public key; the per-host TOKEN comes from sops
  # `beszel/token` (value `TOKEN=<token>`).
  flake.nixosModules.beszel-agent =
    { config, lib, ... }:
    {
      services.beszel.agent = {
        enable = true;
        environment = {
          # The hub's own host overrides this to avoid hairpinning.
          HUB_URL = lib.mkDefault "https://beszel.${config.site.tailnetDomain}";
          # GET /api/beszel/getkey on the hub.
          KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHuyt8ZnZRxhok4vQJ4nSFZKshbtG1wTbzpPI4cD72Eb";
        };
        environmentFile = config.sops.secrets."beszel/token".path;
      };

      sops.secrets."beszel/token" = { };
    };
}
