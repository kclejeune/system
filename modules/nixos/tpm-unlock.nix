_: {
  # TPM2 disk unlock + TPM-backed keyring unlock for fingerprint greeter logins.
  # Needs secure-boot enforced, then per host: `tpm-keyring-seal` as the user
  # (it sudo's into the tss group for that one run) and
  # `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7+15:sha256=<zeros>`.
  # Re-seal and re-enroll after Secure Boot key or dbx changes.
  flake.nixosModules.tpm-unlock =
    { config, ... }:
    {
      # PCR7 only means something once Secure Boot is actually enforcing.
      assertions = [
        {
          assertion = config.boot.lanzaboote.enable;
          message = "tpm-unlock requires Secure Boot (import nixosModules.secure-boot).";
        }
      ];

      services.tpm-keyring-unlock.enable = true;

      # TPM2 before FIDO2/passphrase. PCR15 measurement stops a token enrolled
      # at PCR15=0 unsealing after the first unlock. Each failed token spends a
      # try, so lift the limit.
      boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [
        "tpm2-device=auto"
        "tpm2-measure-pcr=yes"
        "tries=0"
      ];
    };
}
