_: {
  # Lenovo ThinkStation P3 Tiny — shared hardware + disko for the homelab
  # nodes (haven / forge / vault / atlas all run identical single-NVMe P3
  # Tiny boxes: 13th-gen Intel, TPM2, one SK Hynix NVMe). A node with a
  # second M.2 drive can extend disko.devices per-host.
  flake.nixosModules.hardware-p3-tiny =
    {
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [
        "nvme"
        "xhci_pci"
        "thunderbolt"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      # initrd systemd is required for the TPM2-auto-unlocked LUKS volume below.
      # Unlike the laptops (FIDO2 + a typed prompt), these headless boxes unlock
      # unattended from the on-board TPM on a trusted boot — no console needed.
      # Enroll once, post-install:
      #   sudo systemd-cryptenroll --tpm2-device=auto /dev/nvme0n1p2
      # (add --tpm2-pcrs=7 to also bind to Secure Boot state.)
      boot.initrd.systemd.enable = true;

      disko.devices = {
        disk.main = {
          device = "/dev/nvme0n1";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              esp = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              luks = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "cryptroot";
                  settings.allowDiscards = true;
                  settings.crypttabExtraOpts = [ "tpm2-device=auto" ];
                  content = {
                    type = "lvm_pv";
                    vg = "vg";
                  };
                };
              };
            };
          };
        };

        lvm_vg.vg = {
          type = "lvm_vg";
          lvs = {
            swap = {
              size = "8G";
              content.type = "swap";
            };
            root = {
              size = "100%FREE";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [ "errors=remount-ro" ];
              };
            };
          };
        };
      };

      hardware.cpu.intel.updateMicrocode = true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
