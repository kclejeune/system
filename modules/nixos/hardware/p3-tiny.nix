_: {
  # Lenovo ThinkStation P3 Tiny — shared hardware + disko for the homelab
  # nodes (haven / forge / vault / atlas all run identical single-NVMe P3
  # Tiny boxes: 13th-gen Intel, TPM2, one SK Hynix NVMe). A node with a
  # second M.2 drive can extend disko.devices per-host.
  flake.nixosModules.hardware-p3-tiny =
    {
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [
        "nvme"
        "xhci_pci"
        "thunderbolt"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      boot.kernelModules = [ "kvm-intel" ];

      # initrd systemd is required for the TPM2-auto-unlocked LUKS volume below.
      # Unlike the laptops (FIDO2 + a typed prompt), these headless boxes unlock
      # unattended from the on-board TPM on a trusted boot — no console needed.
      # Enroll once, post-install:
      #   sudo systemd-cryptenroll --tpm2-device=auto /dev/nvme0n1p2
      # (add --tpm2-pcrs=7 to also bind to Secure Boot state.)
      boot.initrd.systemd.enable = true;

      disko.devices = {
        disk.main = {
          device = "/dev/nvme0n1";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              esp = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              luks = {
                size = "100%";
                content = {
                  type = "luks";
                  name = "cryptroot";
                  settings.allowDiscards = true;
                  settings.crypttabExtraOpts = [ "tpm2-device=auto" ];
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

      hardware.cpu.intel.updateMicrocode = true;

      # e1000e TX unit hang workaround. The P3 Tiny's onboard Intel I219 LAN
      # (e1000e, PCI 00:1f.6 — the only wired NIC on these boxes) intermittently
      # wedges its hardware TX ring: the kernel logs "e1000e ... eno2: Detected
      # Hardware Unit Hang" and, on the firmware these units carry, the driver's
      # watchdog never successfully resets the adapter — so TX stays dead until a
      # power cycle. On 2026-07-06 haven's eno2 hung at 08:51 and spammed the hang
      # message every ~2s for 8.5h (15k times, zero "Reset adapter"); since eno2 is
      # the sole uplink (enslaved to br0), the node fell off the LAN entirely and
      # needed a forced reboot. Disabling TSO/GSO is the well-documented fix — it
      # keeps segmentation in software and off the buggy hardware TSO engine
      # (https://tailscale.com/s/ethtool-config-udp-gro-style ethtool -K tso/gso off).
      #
      # Delivered as a DROP-IN to systemd's shipped 99-default.link, for the same
      # reasons subnet-router.nix's GRO drop-in is (see its comment): only the
      # first matching .link applies, so a standalone .link would beat
      # 99-default.link and, lacking NamePolicy, revert the NIC to its kernel name
      # (eth0) — breaking the by-name br0 member match in haven.nix and taking the
      # node off the LAN, i.e. re-causing this very outage. A drop-in merges into
      # 99-default.link's [Link] section, preserving NamePolicy and coexisting with
      # the GRO drop-in. It nominally hits every NIC 99-default governs, but these
      # boxes have only the one physical NIC (wifi is down/unused, virtual devices
      # skip it), so this is effectively eno2-only. Drop-ins can't carry their own
      # [Match], so per-driver scoping isn't available without the standalone-file
      # trap above. udev applies it when the NIC appears; verify post-deploy with
      #   ethtool -k eno2 | grep -E 'tcp-segmentation|generic-seg'
      # and apply live without a reboot via `ethtool -K eno2 tso off gso off`.
      environment.etc."systemd/network/99-default.link.d/20-e1000e-tx-hang.conf".text = ''
        [Link]
        TCPSegmentationOffload=no
        GenericSegmentationOffload=no
      '';

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
