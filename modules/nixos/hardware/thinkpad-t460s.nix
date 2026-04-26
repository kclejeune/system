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
      # panel at the (often non-native) GRUB framebuffer resolution; i915
      # only takes over from userspace, so the installer console / TTY /
      # plymouth all render letterboxed (and i915 ends up as card1 instead
      # of replacing card0). Loading i915 in the initrd makes it own the
      # panel from the first frame. The `video=` param pins the native
      # mode in case EDID negotiation picks something smaller.
      boot.initrd.kernelModules = [ "i915" ];
      boot.kernelParams = [ "video=eDP-1:1920x1080@60" ];

      # Match the kernel mode at the GRUB stage so EFI-GOP doesn't hand
      # the kernel a smaller framebuffer to start from.
      boot.loader.grub.gfxmodeEfi = "1920x1080";

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
              swap = {
                size = "4G";
                content.type = "swap";
              };
              root = {
                size = "100%";
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
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
