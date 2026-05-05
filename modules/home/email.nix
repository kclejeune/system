_: {
  # Desktop email clients: Thunderbird (home-manager managed) + Mailspring
  # (standalone package). Gated on `desktop.enable` so headless hosts that
  # import `homeModules.default` (e.g. gateway) evaluate to no-op.
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
            # Thunderbird's embedded OAuth window ships with WebAuthn off,
            # which breaks YubiKey prompts in the Microsoft/Outlook sign-in
            # flow. Flip the Gecko prefs that enable USB FIDO tokens.
            settings = {
              "security.webauth.webauthn" = true;
              "security.webauth.webauthn_enable_usbtoken" = true;
              "security.webauth.webauthn_enable_softtoken" = false;
              "security.webauth.u2f" = true;
              # Hand OAuth off to the system browser via a loopback redirect
              # so WebAuthn runs in a full browser context that Microsoft
              # accepts, instead of Thunderbird's embedded window.
              "mailnews.oauth.loopback.enabled" = true;
            };
          };
        };
      };
    };
}
