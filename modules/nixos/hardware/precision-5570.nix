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

      # Revert the Alder Lake-P iGPU (8086:46a6) from the experimental `xe`
      # KMD back to the mature `i915`. nixos-hardware's dell-precision-5570
      # module defaults `hardware.intelgpu.driver = "xe"` on kernels >= 6.8,
      # but `xe` is unstable on this Gen12 part: the render engine (rcs)
      # repeatedly hits GT0 job timeouts / GPU resets, which invalidate the
      # GL/EGL context and SIGABRT Hyprland in CHyprOpenGLImpl::begin()
      # (and crash noctalia/quickshell). Forcing i915 also drops the
      # `i915.force_probe=!46a6` / `xe.force_probe=46a6` kernelParams, which
      # nixos-hardware only adds when driver == "xe".
      hardware.intelgpu.driver = lib.mkForce "i915";

      # initrd-side systemd is required for the FIDO2-unlocked LUKS
      # prompt the disko config below relies on. Plymouth + quiet boot
      # / kernel params are owned by desktop-base.nix so the theme
      # stays in lockstep with the rest of the desktop visual.
      boot.initrd.systemd.enable = true;
      boot.initrd.systemd.fido2.enable = true;

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

      # Touchpad palm rejection lives in modules/home/hyprland.nix —
      # Hyprland reads its own libinput config and ignores
      # services.libinput.*, so setting it here only affects X11 / a
      # fallback display manager session. Left unset to avoid giving the
      # impression that changes here influence the running Wayland
      # session.

      # Suspend the NVIDIA dGPU when idle. PRIME render offload is already on via
      # nixos-hardware's dell-precision-5570 module; finegrained adds per-engine D3
      # suspend (Turing+, fine on the 5570's Ampere).
      hardware.nvidia.powerManagement.enable = true;
      hardware.nvidia.powerManagement.finegrained = true;

      # Offer a "battery-saver" grub entry that boots with the dGPU fully disabled.
      hardware.nvidia.primeBatterySaverSpecialisation = true;

      # nh reads /etc/specialisation to know which spec's activation script
      # to run on rebuild. Every specialisation must write its own name here
      # — the value must match the attr name exactly, or nh will fall back
      # to the default config.
      specialisation.battery-saver.configuration.environment.etc."specialisation".text = "battery-saver";

      # `dgpu` specialisation: boot entry that forces PRIME sync mode so the
      # NVIDIA GPU is always on and drives all rendering. Intended for docked
      # / AC-powered use: the 5570's HDMI + Thunderbolt outputs are wired to
      # the NVIDIA GPU, and sync mode is the only path that drives them
      # without render offload quirks. Trade-off: several watts of idle draw
      # — do not use on battery.
      #
      # `forceFullCompositionPipeline` eliminates tearing on external
      # displays at the cost of a small GPU overhead; worth it for the
      # presentation-quality path.
      specialisation.dgpu.configuration = {
        system.nixos.tags = [ "dgpu" ];
        environment.etc."specialisation".text = "dgpu";

        hardware.nvidia = {
          prime.sync.enable = lib.mkForce true;
          prime.offload.enable = lib.mkForce false;
          prime.offload.enableOffloadCmd = lib.mkForce false;

          # Finegrained suspend is mutually exclusive with sync mode; keep
          # the general suspend/resume hooks so resume-from-s2idle still
          # restores the framebuffer cleanly.
          powerManagement.finegrained = lib.mkForce false;

          forceFullCompositionPipeline = true;
        };
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
