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

        # Password first, fingerprint second. PAM (and greetd's strictly
        # request/response IPC) can only wait on one input at a time, so the
        # greeter opens on a password field: a correct password ends the
        # stack, and submitting it empty (or wrong) falls through to
        # pam_fprintd. A fingerprint match then has the TPM-unsealed password
        # injected as PAM_AUTHTOK so pam_gnome_keyring can unlock the login
        # keyring. The package patches the authtok module to overwrite the
        # failed password the first arm left behind; nothing after it checks a
        # password, so the injected token can't authenticate a login.
        #
        # Inline rather than a substack: `substack` occupies libpam's control
        # field, leaving nowhere for the "success → done, else → fall through"
        # jump. Failures use `ignore`, never a numeric skip — a skip acts like
        # `ok` and would record the failed password in the stack's result,
        # which a later fingerprint success can't override.
        #
        # unix-early prompts and sets PAM_AUTHTOK so pam_gnome_keyring can
        # stash it before the deciding pam_unix runs; that mirrors NixOS's
        # default stack, whose `done` would otherwise skip the stash.
        #
        # greetd's own service is `useDefaultRules = false` with a single
        # `substack login`, so mkForce is the only way to drop that entry.
        security.pam.services.greetd.rules.auth =
          let
            pamLib = "${pkgs.pam}/lib/security";
            gnomeKeyring = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
          in
          lib.mkForce {
            unix-early = {
              order = 100;
              control = "optional";
              modulePath = "${pamLib}/pam_unix.so";
              settings.likeauth = true;
            };
            password-keyring = {
              order = 200;
              control = "optional";
              modulePath = gnomeKeyring;
            };
            unix = {
              order = 300;
              control = "[success=done new_authtok_reqd=done default=ignore]";
              modulePath = "${pamLib}/pam_unix.so";
              settings = {
                likeauth = true;
                try_first_pass = true;
              };
            };
            fprintd = {
              order = 400;
              control = "[success=ok default=die]";
              modulePath = "${config.services.fprintd.package}/lib/security/pam_fprintd.so";
            };
            tpm-keyring-authtok = {
              order = 500;
              control = "optional";
              modulePath = "${cfg.package}/lib/security/pam_tpm_keyring_authtok.so";
            };
            fingerprint-keyring = {
              order = 600;
              control = "optional";
              modulePath = gnomeKeyring;
            };
          };
      };
    };
}
