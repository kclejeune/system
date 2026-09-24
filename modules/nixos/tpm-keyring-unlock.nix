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
        # Secure Boot is required too (PCR7 policy); tpm-unlock asserts it.
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

        # The sealed blob has no auth value and PCR7 holds all boot, so standing
        # `tss` membership would let any user process unseal the login password.
        # Sealing borrows the group for one sudo run instead. Re-seal after a
        # password or Secure Boot key change.
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

        # Symbolic mode: the wrapper service prepends `u-s,g-s,` and chmod
        # rejects mixing that with octal.
        security.wrappers.tpm-keyring-unseal = {
          source = "${cfg.package}/libexec/tpm-keyring-unlock/tpm-keyring-unseal";
          owner = "root";
          group = "root";
          permissions = "u=rx,g=,o=";
        };

        # A wrong/empty password falls through to fingerprint, which feeds the
        # TPM-unsealed password to pam_gnome_keyring. Inline rather than a
        # substack so the password arm can `done`/`ignore` without recording
        # a failure.
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
