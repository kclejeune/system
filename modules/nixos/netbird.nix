_: {
  flake.nixosModules.netbird =
    { config, lib, ... }:
    {
      services.netbird.enable = true;

      networking.firewall.trustedInterfaces = lib.mapAttrsToList (
        _: client: client.interface
      ) config.services.netbird.clients;
    };
}
