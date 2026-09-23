_: {
  # Framework Laptop 13 Pro (Intel Core Ultra Series 3) hardware
  # configuration with disko. Pairs with nixos-hardware's
  # `framework-intel-core-ultra-series3`, which already owns fwupd,
  # fprintd, the iio sensor, the nvme.noacpi power tweak and the
  # minimum-kernel bump.
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

      # initrd-side systemd is required for the FIDO2-unlocked LUKS
      # prompt the disko config below relies on. Plymouth + quiet boot
      # / kernel params are owned by desktop-base.nix so the theme
      # stays in lockstep with the rest of the desktop visual.
      boot.initrd.systemd.enable = true;
      boot.initrd.systemd.fido2.enable = true;

      # ESP + LUKS(LVM{swap,root}). Unlike the precision-5570 there's no
      # separate ext4 /boot: systemd-boot (and lanzaboote) put every
      # kernel + initrd on the ESP, so a GRUB-style /boot partition is
      # dead space. Each generation costs ~70 MB there (larger per
      # specialisation), and the 5570's 512M ESP fills well below
      # configurationLimit — 2G leaves room for 10 generations plus
      # lanzaboote UKIs if secure-boot is enrolled later.
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

      # Power management: prefer power-profiles-daemon (GNOME-integrated,
      # adjusts CPU EPP + the EC platform profile). nixos-hardware's
      # common/pc/laptop enables TLP only when PPD is off, so enabling PPD
      # here flips TLP off.
      services.power-profiles-daemon.enable = true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
