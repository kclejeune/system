_: {
  # Dell Precision 5570 hardware configuration with disko.
  flake.nixosModules.hardware-precision-5570 =
    {
      lib,
      pkgs,
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
        "rtsx_pci_sdmmc"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      boot.loader.grub.enableCryptodisk = true;

      # Boot splash screen (themed LUKS prompt + boot animation)
      boot.plymouth.enable = true;
      boot.plymouth.theme = "nixos-bgrt";
      boot.plymouth.themePackages = [ pkgs.nixos-bgrt-plymouth ];
      boot.initrd.systemd.enable = true;
      boot.initrd.systemd.fido2.enable = true;
      boot.consoleLogLevel = 0;
      boot.kernelParams = [
        "quiet"
        "splash"
      ];

      disko.devices = {
        disk.main = {
          device = "/dev/nvme0n1";
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
              boot = {
                size = "1G";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/boot";
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

      # Power management: prefer power-profiles-daemon (GNOME-integrated, adjusts
      # CPU EPP + Dell's firmware platform profile). nixos-hardware's common/pc/laptop
      # enables TLP only when PPD is off, so enabling PPD here flips TLP off.
      services.power-profiles-daemon.enable = true;

      # Suspend the NVIDIA dGPU when idle. PRIME render offload is already on via
      # nixos-hardware's dell-precision-5570 module; finegrained adds per-engine D3
      # suspend (Turing+, fine on the 5570's Ampere).
      hardware.nvidia.powerManagement.enable = true;
      hardware.nvidia.powerManagement.finegrained = true;

      # Offer a "battery-saver" grub entry that boots with the dGPU fully disabled.
      hardware.nvidia.primeBatterySaverSpecialisation = true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
