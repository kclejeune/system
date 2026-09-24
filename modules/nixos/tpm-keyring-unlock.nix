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
        # Secure Boot is also required (PCR7 policy) but can't be checked at eval time.
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

        # The sealed blob has no auth value, only a PCR7 policy that holds for the
        # whole boot, so standing `tss` membership would let any process running
        # as the user unseal the login password. Instead `tpm-keyring-seal` gets
        # /dev/tpmrm0 only for the duration of one sudo-authenticated run
        # (upstream's `sg tss` path, minus the group membership). Unsealing at
        # login goes through the root-only wrapper below.
        #
        # (Re-)seal after changing the password or re-enrolling Secure Boot keys:
        #   tpm-keyring-seal
        environment.systemPackages = [
          (pkgs.writeShellApplication {
            name = "tpm-keyring-seal";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              exec /run/wrappers/bin/sudo -u "$(id -un)" -g tss -- \
                env TPM2TOOLS_TCTI=device:/dev/tpmrm0 \
                ${lib.getExe cfg.package} "$@"
            '';
          })
        ];

        # Root-only, non-setuid. `permissions` must be symbolic: the wrapper
        # service prepends `u-s,g-s,` and chmod rejects a mixed octal mode.
        security.wrappers.tpm-keyring-unseal = {
          source = "${cfg.package}/libexec/tpm-keyring-unlock/tpm-keyring-unseal";
          owner = "root";
          group = "root";
          permissions = "u=rx,g=,o=";
        };

        # Password first; an empty or wrong password falls through to fingerprint,
        # which injects the TPM-unsealed password for pam_gnome_keyring. Inline, not
        # a substack, so the password arm can use `done`/`ignore` (a numeric skip
        # would record the failure). mkForce drops greetd's `substack login`.
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
