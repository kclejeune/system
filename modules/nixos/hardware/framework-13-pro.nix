_: {
  # Framework Laptop 13 Pro (Intel Core Ultra Series 3). nixos-hardware's
  # module covers fwupd, fprintd, sensors and kernel tweaks.
  flake.nixosModules.hardware-framework-13-pro =
    {
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [
        "thunderbolt"
        "nvme"
        "xhci_pci"
        "usb_storage"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      # systemd initrd for the FIDO2 LUKS unlock.
      boot.initrd.systemd.enable = true;
      boot.initrd.systemd.fido2.enable = true;

      # No separate /boot: every kernel + initrd lives on the ESP.
      disko.devices = {
        disk.main = {
          device = "/dev/nvme0n1";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              esp = {
                size = "2G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot/efi";
                  mountOptions = [ "umask=0077" ];
                };
              };
              luks = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "cryptroot";
                  settings.allowDiscards = true;
                  settings.crypttabExtraOpts = [ "fido2-device=auto" ];
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

      # PPD instead of TLP (nixos-hardware enables TLP only when PPD is off).
      services.power-profiles-daemon.enable = true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
