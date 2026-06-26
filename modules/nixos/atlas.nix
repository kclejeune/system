_: {
  # atlas — infra / backup node. Bare-metal Lenovo P3 Tiny. Role scaffolding
  # only this round (monitoring / restic-repo orchestration land later).
  # The common P3 stack (user, caddy-lan, VPN, state version) comes from
  # flake.nixosModules.homelab-node; this file holds only atlas-specifics.
  flake.nixosModules.atlas = _: {
    networking.hostName = "atlas";
    sops.defaultSopsFile = ../../secrets/atlas.yaml;
    # No caddy-lan proxies yet (atlas has no web UIs); add to
    # services.caddyLan.proxies as services land (monitoring, etc.). backup
    # stays off in flake.nix until real restic/* creds exist.
  };
}
