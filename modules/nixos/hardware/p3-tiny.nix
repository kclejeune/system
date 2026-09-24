_: {
  # Lenovo P3 Tiny hardware + disko shared by the homelab nodes.
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

      # systemd initrd for unattended TPM2 LUKS unlock. Enroll once with
      # `sudo systemd-cryptenroll --tpm2-device=auto /dev/nvme0n1p2`
      # (--tpm2-pcrs=7 also binds Secure Boot state).
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

      # e1000e (I219) TX hang: the watchdog never recovers it and the node drops
      # off the LAN until power-cycled (haven, 2026-07-06). Disabling TSO/GSO is
      # the known fix. Drop-in rather than a standalone .link for the same
      # NamePolicy reason as subnet-router's. Verify with
      # `ethtool -k eno2 | grep -E 'tcp-segmentation|generic-seg'`.
      environment.etc."systemd/network/99-default.link.d/20-e1000e-tx-hang.conf".text = ''
        [Link]
        TCPSegmentationOffload=no
        GenericSegmentationOffload=no
      '';

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
