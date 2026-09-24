_: {
  # Gated on desktop.enable so headless hosts get nothing.
  flake.homeModules.email =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      config = lib.mkIf config.desktop.enable {
        programs.thunderbird = {
          enable = true;
          profiles.default = {
            isDefault = true;
            # Thunderbird's embedded OAuth window has WebAuthn off, which breaks YubiKey
            # sign-in to Microsoft.
            settings = {
              "security.webauth.webauthn" = true;
              "security.webauth.webauthn_enable_usbtoken" = true;
              "security.webauth.webauthn_enable_softtoken" = false;
              "security.webauth.u2f" = true;
              # Do OAuth in the system browser, where Microsoft accepts WebAuthn.
              "mailnews.oauth.loopback.enabled" = true;
            };
          };
        };
      };
    };
}
