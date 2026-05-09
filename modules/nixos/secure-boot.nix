{ inputs, ... }:
{
  # UEFI Secure Boot via lanzaboote. Replaces systemd-boot with signed
  # unified kernel images verified against keys enrolled in firmware.
  #
  # One-time host-side setup (per host that enrolls this module):
  #   1. sudo nix run nixpkgs#sbctl -- create-keys
  #      → writes Platform Key + KEK + db to /var/lib/sbctl
  #   2. nixos-rebuild switch  (signs current generation)
  #   3. sudo sbctl verify     (every .efi under /boot/efi should be ✓
  #                             except files starting with kernel-)
  #   4. Reboot into firmware, put Secure Boot into "Setup Mode"
  #      (clears the OEM PK so we can enroll our own).
  #   5. sudo sbctl enroll-keys --microsoft   (--microsoft retains OEM
  #                             OptionROM signatures, e.g. dGPU vBIOS.)
  #   6. Re-enable Secure Boot in firmware → bootctl status should show
  #      "Secure Boot: enabled (user)" and "TPM2 Support: yes".
  flake.nixosModules.secure-boot =
    { lib, pkgs, ... }:
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      # desktop-base.nix unconditionally enables systemd-boot; lanzaboote
      # is a drop-in replacement for it so we have to force it off here.
      boot.loader.systemd-boot.enable = lib.mkForce false;

      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };

      # TPM2 userspace: tpm2-tools, tpm2-tss, abrmd resource manager,
      # and TCTI env vars so `tpm2_*` commands talk to /dev/tpmrm0
      # without per-invocation flags. pkcs11 exposes the TPM as a
      # PKCS#11 token (useful for SSH keys backed by the TPM).
      security.tpm2 = {
        enable = true;
        pkcs11.enable = true;
        tctiEnvironment.enable = true;
      };

      # Load the TPM driver early so systemd in the initrd can talk to
      # it (required for any future tpm2-device=auto LUKS unlock).
      # tpm_tis covers most discrete + fTPM implementations; tpm_crb
      # is the CRB interface used by AMD fTPM and newer Intel PTT.
      boot.initrd.availableKernelModules = [
        "tpm_tis"
        "tpm_crb"
      ];

      environment.systemPackages = [ pkgs.sbctl ];
    };
}
