_: {
  # Lenovo ThinkPad T460s hardware configuration with disko.
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

      # Without this, simpledrm grabs card0 from EFI-GOP and drives the FHD
      # panel at the (often non-native) firmware framebuffer resolution;
      # i915 only takes over from userspace, so the installer console /
      # TTY / plymouth all render letterboxed (and i915 ends up as card1
      # instead of replacing card0). Loading i915 in the initrd makes it
      # own the panel from the first frame. The `video=` param pins the
      # native mode in case EDID negotiation picks something smaller.
      boot.initrd.kernelModules = [ "i915" ];
      boot.kernelParams = [ "video=eDP-1:1920x1080@60" ];

      # initrd-side systemd is required for the FIDO2-unlocked LUKS
      # prompt the disko config below relies on. Plymouth + quiet boot
      # / kernel params are owned by desktop-base.nix so the theme
      # stays in lockstep with the rest of the desktop visual.
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
