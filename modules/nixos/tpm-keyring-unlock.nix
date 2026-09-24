_: {
  flake.nixosModules.tpm-keyring-unlock =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.tpm-keyring-unlock;
    in
    {
      options.services.tpm-keyring-unlock = {
        enable = lib.mkEnableOption "TPM-backed GNOME Keyring unlock for fingerprint greetd logins";

        package = lib.mkPackageOption pkgs "tpm-keyring-unlock" { };
      };

      config = lib.mkIf cfg.enable {
        # Secure Boot is a hard prerequisite too, but can't be asserted: the
        # policy is PCR7-only, and PCR7 state lives in firmware, not in
        # anything evaluation can read.
        assertions = [
          {
            assertion = config.services.greetd.enable;
            message = "services.tpm-keyring-unlock requires services.greetd.enable.";
          }
          {
            assertion = config.services.fprintd.enable;
            message = "services.tpm-keyring-unlock requires services.fprintd.enable.";
          }
          {
            assertion = config.services.gnome.gnome-keyring.enable;
            message = "services.tpm-keyring-unlock requires services.gnome.gnome-keyring.enable.";
          }
        ];

        security.tpm2 = {
          enable = true;
          tctiEnvironment.enable = true;
        };

        # Sealing and unsealing both need /dev/tpmrm0.
        users.users.${config.user.name}.extraGroups = [ "tss" ];
        environment.systemPackages = [ cfg.package ];

        # The store cannot preserve upstream's root-only helper mode. Route PAM
        # through a root-only wrapper while keeping the module non-setuid.
        # `permissions` must be symbolic: the wrapper service prepends
        # `u-s,g-s,` and chmod rejects an octal mode mixed into that list.
        security.wrappers.tpm-keyring-unseal = {
          source = "${cfg.package}/libexec/tpm-keyring-unlock/tpm-keyring-unseal";
          owner = "root";
          group = "root";
          permissions = "u=rx,g=,o=";
        };

        # The password arm is a substack so its pam_unix rule can't consume the
        # TPM-provided PAM_AUTHTOK that the fingerprint arm injects as an
        # account password. It keeps upstream's default rules (so fprintAuth /
        # enableGnomeKeyring apply here) with fingerprint switched off — that
        # phase already ran above.
        security.pam.services.greetd-password = {
          fprintAuth = false;
          enableGnomeKeyring = true;
        };

        # Fingerprint arm inline, password arm substacked. The fingerprint arm
        # can't itself be a substack: `substack` occupies libpam's control
        # field exclusively, leaving nowhere to hang the "succeeded → end the
        # stack, otherwise → fall through to password" jump. Hence the
        # bracketed control here, plus pam_permit to end the stack on success.
        #
        # greetd's own service is `useDefaultRules = false` with a single
        # `substack login`, so mkForce is the only way to drop that entry.
        #
        # `default=3` skips exactly the three rules between fprintd and the
        # password substack — keep it in sync with them. Untested; verify in a
        # VM before enabling.
        security.pam.services.greetd.rules.auth = lib.mkForce {
          fprintd = {
            order = 100;
            control = "[success=ok default=3]";
            modulePath = "${config.services.fprintd.package}/lib/security/pam_fprintd.so";
          };
          tpm-keyring-authtok = {
            order = 200;
            control = "optional";
            modulePath = "${cfg.package}/lib/security/pam_tpm_keyring_authtok.so";
          };
          gnome-keyring = {
            order = 300;
            control = "optional";
            modulePath = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
          };
          fingerprint-done = {
            order = 400;
            control = "sufficient";
            modulePath = "${pkgs.pam}/lib/security/pam_permit.so";
          };
          password = {
            order = 500;
            control = "substack";
            modulePath = "greetd-password";
          };
        };
      };
    };
}
