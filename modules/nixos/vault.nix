_: {
  # vault — data / storage node. Bare-metal Lenovo P3 Tiny. Role scaffolding
  # only this round (syncthing / DBs / NFS land later).
  # The common P3 stack (user, caddy-lan, VPN, state version) comes from
  # flake.nixosModules.homelab-node; this file holds only vault-specifics.
  flake.nixosModules.vault = _: {
    networking.hostName = "vault";
    sops.defaultSopsFile = ../../secrets/vault.yaml;
    # No caddy-lan proxies yet (vault has no web UIs); add to
    # services.caddyLan.proxies as services land (syncthing, etc.). backup
    # stays off in flake.nix until real restic/* creds exist.
  };
}
