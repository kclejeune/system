_: {
  # Dell Precision 5570 hardware configuration with disko.
  flake.nixosModules.hardware-precision-5570 =
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    let
      # Specialisations only change nvidia modprobe options (not loaded in the
      # initrd); share the base initrd so each generation stores one copy.
      # `config` is the base system's.
      sharedInitrd = {
        boot.initrd.systemd.contents."/etc/modprobe.d/nixos.conf".source =
          lib.mkForce
            config.environment.etc."modprobe.d/nixos.conf".source;
      };
    in
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

      # systemd initrd for the FIDO2 LUKS unlock.
      boot.initrd.systemd.enable = true;
      boot.initrd.systemd.fido2.enable = true;

      disko.devices = {
        disk.main = {
          device = "/dev/nvme0n1";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              # 2G matches framework-13-pro, but wally's disk has a 1536M ESP (old ESP
              # + /boot merged in place; LUKS follows, so growing needs a reinstall).
              # disko's size only applies at install.
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

      # Goodix reader (27c6:63ac) doesn't wake from USB autosuspend; keep it powered.
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", \
          ATTR{idVendor}=="27c6", ATTR{idProduct}=="63ac", \
          ATTR{power/control}="on"
      '';

      # Per-engine dGPU suspend; PRIME offload comes from nixos-hardware.
      hardware.nvidia.powerManagement.enable = true;
      hardware.nvidia.powerManagement.finegrained = true;

      # Boot entry with the dGPU disabled.
      hardware.nvidia.primeBatterySaverSpecialisation = true;

      # nh reads /etc/specialisation to pick the activation script.
      specialisation.battery-saver.configuration = {
        imports = [ sharedInitrd ];
        environment.etc."specialisation".text = "battery-saver";
      };

      # PRIME sync for docking: the external ports are wired to the dGPU. High idle draw.
      specialisation.dgpu.configuration = {
        imports = [ sharedInitrd ];
        system.nixos.tags = [ "dgpu" ];
        environment.etc."specialisation".text = "dgpu";

        hardware.nvidia = {
          prime.sync.enable = lib.mkForce true;
          prime.offload.enable = lib.mkForce false;
          prime.offload.enableOffloadCmd = lib.mkForce false;

          # Incompatible with sync mode.
          powerManagement.finegrained = lib.mkForce false;

          forceFullCompositionPipeline = true;
        };
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
