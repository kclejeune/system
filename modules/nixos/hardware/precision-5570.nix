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

      # Pin the iGPU to i915. nixos-hardware's dell-precision-5570 defaults
      # to the experimental `xe` KMD on kernels ≥ 6.8, which on this box
      # produces "Tile0: GT0: Timedout job" GPU resets that kill the
      # WlSessionLock client (quickshell), leaving Hyprland's fallback
      # "lockscreen process has crashed" screen on resume. Mesa itself
      # prints `Support for this platform is experimental with Xe KMD`.
      # Reverting to i915 also drops the matching `*.force_probe=` params
      # the upstream module gates on `intelgpu.driver == "xe"`.
      # hardware.intelgpu.driver = lib.mkForce "i915";

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
        # xe KMD diagnostics for the reproducible GT0 Timedout job reset
        # triggered by lock-before-sleep. Logging only — no behavior
        # change. Remove once the reset trigger is identified.
        "xe.guc_log_level=4"
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

      # Disable LID0 as an ACPI wakeup source. The 5570's lid switch is flagged
      # by the kernel as "not compliant to SW_LID" and fires a spurious "lid
      # opened" event the instant the system enters s2idle, immediately waking
      # it back up — so closing the lid suspends for ~3 s and then resumes.
      # Logind still sees the close (it watches the input device, not the
      # ACPI wake source) and triggers suspend; we just don't want the same
      # device to *also* be the wake reason. Trade-off: opening the lid no
      # longer auto-wakes; press the power button or any key.
      systemd.services.disable-lid-wakeup = {
        description = "Disable LID0 ACPI wakeup (Precision 5570 quirk)";
        wantedBy = [ "multi-user.target" ];
        after = [ "sysinit.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "disable-lid-wakeup" ''
            if ${pkgs.gnugrep}/bin/grep -q '^LID0.*\*enabled' /proc/acpi/wakeup; then
              echo LID0 > /proc/acpi/wakeup
            fi
          '';
        };
      };

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
      services.libinput.touchpad.tapping = false;

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
