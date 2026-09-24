_: {
  flake.nixosModules.avahi = _: {
    # openFirewall is load-bearing: without it Avahi answers only on loopback
    # (uxplay's kDNSServiceErr_Unknown on NixOS).
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
