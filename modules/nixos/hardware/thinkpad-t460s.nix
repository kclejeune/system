_: {
  flake.nixosModules.hardware-thinkpad-t460s =
    { lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [
        "ahci"
        "xhci_pci"
        "usb_storage"
        "sd_mod"
        "rtsx_pci_sdmmc"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      # Otherwise simpledrm owns the panel at the firmware resolution until
      # userspace, so console and plymouth render letterboxed.
      boot.initrd.kernelModules = [ "i915" ];
      boot.kernelParams = [ "video=eDP-1:1920x1080@60" ];

      # systemd initrd for the FIDO2 LUKS unlock.
      boot.initrd.systemd.enable = true;
      boot.initrd.systemd.fido2.enable = true;

      disko.devices = {
        disk.main = {
          device = "/dev/sda";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              esp = {
                size = "512M";
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

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
