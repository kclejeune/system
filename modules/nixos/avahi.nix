_: {
  flake.nixosModules.avahi =
    { ... }:
    {
      # mDNS / DNS-SD daemon. Required for AirPlay discovery (uxplay),
      # Chromecast/Cast discovery, network printers, generic *.local
      # hostname resolution, etc.
      #
      # `openFirewall = true` is load-bearing on NixOS specifically:
      # uxplay's README troubleshooting section calls out NixOS users
      # hitting `kDNSServiceErr_Unknown` from DNSServiceRegister until
      # this is set, because without it Avahi only services queries on
      # the loopback interface and clients on the LAN can't see anything
      # published. (Opens UDP 5353.)
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        nssmdns6 = true;
        openFirewall = true;
        publish = {
          enable = true;
          addresses = true;
          domain = true;
          userServices = true;
          workstation = true;
        };
      };
    };
}
