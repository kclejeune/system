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

      # The Goodix fingerprint reader (27c6:63ac) autosuspends after 2 s of
      # inactivity and doesn't reliably wake when fprintd tries to claim it,
      # causing auth failures after idle periods. Disabling USB runtime PM
      # keeps the device always powered; the power cost is negligible.
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", \
          ATTR{idVendor}=="27c6", ATTR{idProduct}=="63ac", \
          ATTR{power/control}="on"
      '';

      # Touchpad palm rejection.
      #   `clickMethod = "clickfinger"` — clicks are finger-count-based
      #     instead of zone-based, so palm-on-corner stops registering as
      #     a click. 1 finger = left, 2 = right, 3 = middle.
      #   `tapping = false` — no tap-to-click, anywhere. Approximates
      #     "click only in the bottom half" since the diving-board hinge
      #     is the only spot a palm can't physically depress. libinput
      #     does not expose tap zones, so this is the closest equivalent.
      # Hyprland's matching `clickfinger_behavior` / `tap-to-click` are
      # set in modules/home/hyprland.nix.
      services.libinput.touchpad.clickMethod = "clickfinger";
      # services.libinput.touchpad.tapping = false;

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
