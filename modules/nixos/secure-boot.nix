{ inputs, ... }:
{
  # One-time setup per host:
  #   sudo nix run nixpkgs#sbctl -- create-keys; switch; sudo sbctl verify
  #   firmware: Secure Boot → Setup Mode
  #   sudo sbctl enroll-keys --microsoft   (keeps OEM OptionROM sigs, e.g. dGPU vBIOS)
  #   firmware: re-enable Secure Boot; `bootctl status` shows "enabled (user)"
  flake.nixosModules.secure-boot =
    { lib, pkgs, ... }:
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      # lanzaboote replaces systemd-boot, which desktop-base enables.
      boot.loader.systemd-boot.enable = lib.mkForce false;

      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };

      security.tpm2 = {
        enable = true;
        pkcs11.enable = true;
        tctiEnvironment.enable = true;
      };

      # The initrd needs the TPM for tpm2-device=auto LUKS unlock.
      boot.initrd.availableKernelModules = [
        "tpm_tis"
        "tpm_crb"
      ];

      environment.systemPackages = [ pkgs.sbctl ];
    };
}
