_: {
  flake.nixosModules.avahi = _: {
    # openFirewall is load-bearing: without it Avahi answers only on loopback
    # (uxplay's kDNSServiceErr_Unknown on NixOS).
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
      settings.publish = {
        disable-publishing = false;
        disable-user-service-publishing = false;
        publish-addresses = true;
        publish-domain = true;
        publish-workstation = true;
      };
    };
  };
}
