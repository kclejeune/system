{ config, ... }:
let
  flakeCfg = config;
in
{
  # Compositor-agnostic desktop configuration shared by GNOME and Hyprland.
  flake.nixosModules.desktop-base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        flakeCfg.flake.nixosModules.fonts
        flakeCfg.flake.nixosModules.keyd
        flakeCfg.flake.nixosModules.nix-ld
      ];

      hm.desktop.enable = true;

      services.libinput.enable = true;
      services.printing.enable = true;
      services.netbird.clients.default.autoStart = false;

      # -- Timezone --
      # automatic-timezoned + GeoClue flaps because beacondb doesn't know
      # our Wi-Fi APs and falls back to IP geolocation, which maps our
      # Cloudflare WARP IP to Lisbon.  tzupdate uses a different IP geo
      # service that resolves correctly through WARP.
      services.tzupdate = {
        enable = true;
        timer.interval = "*:0/15";
      };

      networking.networkmanager.dispatcherScripts = [
        {
          source = pkgs.writeText "tzupdate-on-connectivity" ''
            #!/bin/sh
            [ "$2" = "connectivity-change" ] && systemctl start tzupdate.service || true
          '';
        }
      ];

      systemd.services.timezone-seed = {
        description = "Seed default timezone before tzupdate";
        before = [ "tzupdate.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/timedatectl set-timezone America/Toronto";
        };
      };

      boot.kernel.sysctl."net.core.rmem_max" = 2097152;
      boot.kernel.sysctl."net.core.rmem_default" = 1048576;

      # ARP flux fix for when wired + wifi are both up on the same subnet
      # (docked: enp8s0 + wlp0s20f3 both lease 192.168.1.0/24). Default
      # `arp_ignore=0` lets either NIC answer ARP for the other's IP, so the
      # switch learns an IP's MAC on the wrong port and return traffic lands
      # on the idle interface — long-lived connections (Slack, SSH, the WARP
      # underlay) stall until the ARP table re-settles. arp_ignore=1 only
      # answers for the receiving NIC's own IP; arp_announce=2 sources
      # announcements from the outgoing interface's address. Wifi stays up
      # as a fallback.
      boot.kernel.sysctl."net.ipv4.conf.all.arp_ignore" = 1;
      boot.kernel.sysctl."net.ipv4.conf.all.arp_announce" = 2;

      # Propagate log level + target as env vars to PID 1 so they
      # survive into `systemd-shutdown`. The `systemd.log_level=` /
      # `systemd.log_target=` kernel cmdline directives apply to PID 1
      # at init, but PID 1 doesn't pass them through as environment
      # variables when it exec()s `/lib/systemd/systemd-shutdown` at
      # the end of teardown. systemd-shutdown then runs this on entry
      # (src/shutdown/shutdown.c):
      #
      #   log_set_target(LOG_TARGET_CONSOLE);
      #   log_set_prohibit_ipc(true);
      #   log_parse_environment();
      #
      # — i.e. it hard-resets its log target to CONSOLE (writing
      # directly to /dev/tty1) and only respects an env override via
      # log_parse_environment(). That's why we see ERR-level messages
      # like "Could not detach DM /dev/dm-2: Device or resource busy"
      # and "Unable to finalize remaining …" on screen during phase 1
      # of shutdown, despite the cmdline settings.
      #
      # `systemd.managerEnvironment` in NixOS compiles to
      # `systemd.setenv=KEY=VAL` on the kernel cmdline, which PID 1
      # reads into its own environment, which is then inherited by
      # systemd-shutdown when PID 1 exec()s it. Target=kmsg routes
      # systemd-shutdown's output to /dev/kmsg instead of /dev/tty1
      # — kmsg is already filtered for console display by
      # `consoleLogLevel=0`, so nothing paints. Messages are still in
      # the kernel ring buffer for `dmesg` post-mortem.
      systemd.managerEnvironment = {
        SYSTEMD_LOG_LEVEL = "err";
        SYSTEMD_LOG_TARGET = "kmsg";
      };

      # Plymouth + quiet boot. Covers the gap between bootloader and
      # greeter so the user doesn't watch kernel/systemd unit logs
      # scroll past on every boot. Mocha theme keeps the visual
      # consistent with the rest of the session (greeter + noctalia
      # lock + GTK theme are all Catppuccin Mocha).
      boot.plymouth = {
        enable = true;
        theme = "catppuccin-mocha";
        themePackages = [ (pkgs.catppuccin-plymouth.override { variant = "mocha"; }) ];
      };

      # `quiet`            — kernel-level message suppression
      # `splash`           — tells initrd to start plymouth
      # `loglevel=3`       — only KERN_ERR and worse
      # `rd.systemd.*` / `rd.udev.*` — same, but inside the initrd
      # `udev.log_priority=3` — quiet udev once we're past initrd
      # `vt.global_cursor_default=0` — no blinking VT cursor peeking
      #                       through plymouth or between greeter/
      #                       compositor handoffs
      # `systemd.log_level=err` — silences PID 1's INFO/NOTICE/WARNING
      #                       chatter. `show_status=false` already hides
      #                       "Started X" unit-status lines, but systemd-
      #                       shutdown still logs WARNING-level "Could
      #                       not finalize remaining DM/LUKS devices,
      #                       ignoring" / detach-busy messages once
      #                       journald has stopped (the root LV is still
      #                       in use, so the teardown can never succeed).
      #                       PID 1 also emits info-level PAM session /
      #                       scope-creation messages during greetd→
      #                       Hyprland handoff. Both land directly on
      #                       /dev/console (tty1) and paint the screen
      #                       during the shutdown splash and the cage→
      #                       compositor gap. `err` keeps actual failures
      #                       (oom-killer, panic precursors) visible.
      # `systemd.log_target=journal-or-kmsg` — routes PID 1's own logs to
      #                       journal (or kmsg fallback before journald
      #                       starts / after it stops). Avoids the
      #                       default `auto` target's secondary write to
      #                       /dev/console, which is the path that paints
      #                       over the framebuffer between cage exit and
      #                       Hyprland claiming the GPU. kmsg fallback is
      #                       fine — kernel console output is already
      #                       muted by `loglevel=3` / `consoleLogLevel=0`.
      # `rd.systemd.*` — same for the initrd's PID 1 (covers the post-
      #                       LUKS-unlock window where libseat error from
      #                       cage / compositor probes would otherwise
      #                       flash on tty1).
      boot.kernelParams = [
        "quiet"
        "splash"
        "loglevel=3"
        "systemd.show_status=false"
        "rd.systemd.show_status=false"
        "systemd.log_level=err"
        "rd.systemd.log_level=err"
        "systemd.log_target=journal-or-kmsg"
        "rd.systemd.log_target=journal-or-kmsg"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
        "vt.global_cursor_default=0"
      ];
      boot.consoleLogLevel = 0;
      boot.initrd.verbose = false;

      # Smooth plymouth → greeter handoff. The upstream
      # `plymouth-quit.service` calls `plymouth quit` (no
      # `--retain-splash`), so plymouth releases the framebuffer
      # immediately and the kernel fbcon flashes underneath for the
      # split second before cage grabs the framebuffer for the greeter.
      # `--retain-splash` keeps the splash image painted until
      # something else draws over it — cage's first frame.
      # Leading `-` (matches the upstream unit) makes systemd treat a
      # non-zero exit as success — necessary because the service has
      # `RemainAfterExit=yes`, so a config switch restarts it after
      # plymouth has long since exited and the second `plymouth quit`
      # would otherwise fail activation.
      systemd.services.plymouth-quit.serviceConfig.ExecStart =
        lib.mkForce "-${lib.getExe' pkgs.plymouth "plymouth"} quit --retain-splash";

      # systemd-boot. Kernel + initrd land on the ESP (vfat, 512M);
      # the separate /boot ext4 partition that GRUB used is left
      # untouched and effectively unused — not worth reformatting.
      # `configurationLimit` caps generations so the ESP doesn't fill
      # (each generation is ~80–130 MB of kernel + initrd).
      # `editor = false` blocks kernel-cmdline editing at the boot
      # menu, which would otherwise be a way to bypass disk encryption.
      # mkDefault on `timeout` so the ISO installer image can override.
      boot.loader.timeout = lib.mkDefault 0;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.loader.efi.efiSysMountPoint = "/boot/efi";
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false;
      };

      hardware.enableAllFirmware = true;

      # Mesa + Vulkan ICDs for Intel/AMD; Nvidia hosts layer `hardware.nvidia.*`
      # on top which adds the proprietary ICD. 32-bit is needed for Steam,
      # Wine, and a handful of Electron apps that load 32-bit GL libs.
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      networking.networkmanager.enable = true;
      # Route DNS through systemd-resolved instead of openresolv.
      # Default NixOS wiring is `dns=default` + `rc-manager=resolvconf`,
      # which lets tailscaled register its MagicDNS server (100.100.100.100)
      # in resolvconf's `exclusive` mode and clobber every other resolver.
      # Net effect: until tailscaled is fully up post-boot (or post-resume),
      # every lookup — `api.anthropic.com`, `*.tailf0779.ts.net`, the lot —
      # fails outright, manifesting as "unable to connect to socket"
      # errors. The wifi-toggle workaround kicks tailscaled into rebuilding
      # its DNS routes.
      #
      # systemd-resolved sits between clients and upstreams: it accepts
      # per-interface DNS routes from NM (DHCP-supplied LAN servers) and
      # from tailscaled (MagicDNS for *.ts.net), and resolves each
      # query against the right backend by suffix. If Tailscale is down,
      # public lookups still flow through the LAN-supplied resolver.
      services.resolved.enable = true;
      networking.networkmanager.dns = "systemd-resolved";
      # `NetworkManager-wait-online.service` blocks `multi-user.target`
      # (and therefore `graphical.target`) waiting up to 30s for the
      # network to be online at boot. UWSM checks `graphical.target` is
      # active before starting a Wayland session, so this delay
      # manifests as "graphical.target is queued for start, waiting for
      # 60s..." in greetd→UWSM login attempts, often well past the user
      # picking the session. Server-oriented service; desktop users
      # connect to networks after the desktop is up.
      systemd.services.NetworkManager-wait-online.enable = false;

      services.pcscd.enable = true;

      services.fprintd.enable = true;
      # `fprintAuth` defaults to `services.fprintd.enable` for every PAM
      # service, so sudo / su / polkit / login / etc. inherit it for free.
      # GDM used to force-disable it on `login` (we kept an mkForce to win
      # over that override so noctalia's PAM auth against /etc/pam.d/login
      # would work); SDDM doesn't, so the default is correct as-is.

      # Firmware updates via LVFS (Dell BIOS/EC, Thunderbolt controllers, etc.)
      services.fwupd.enable = true;

      # Thunderbolt device authorization daemon.
      services.hardware.bolt.enable = true;

      # Intel thermal daemon — improves sustained perf/thermals on Alder Lake
      # and later. No-op on non-Intel hardware.
      services.thermald.enable = true;

      # fprintd's default polkit policy is allow_active=yes, but after a
      # suspend/lock cycle polkit doesn't reliably treat the relocked session
      # as active. Grant the owner the fprint actions unconditionally.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id.indexOf("net.reactivated.fprint.") == 0 &&
              subject.user == "${config.user.name}") {
            return polkit.Result.YES;
          }
        });
      '';

      services.logind.settings.Login = {
        HandlePowerKey = "suspend";
        HandlePowerKeyLongPress = "poweroff";
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "ignore";
      };

      security.sudo.extraConfig = ''
        Defaults timestamp_timeout=30
        Defaults timestamp_type=tty
      '';

      virtualisation.docker.enable = true;
      virtualisation.docker.daemon.settings.features.containerd-snapshotter = true;

      programs._1password.enable = true;
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = [ config.user.name ];
      };

      # The localsend module installs the package and opens UDP/TCP 53317
      # in the firewall (default), which is required for device discovery
      # and receiving files. Plain `pkgs.localsend` in systemPackages
      # would install the binary but leave the firewall blocking inbound
      # discovery beacons.
      programs.localsend.enable = true;

      # GUI libraries layered on top of the base nix-ld set (from the nix-ld
      # module imported above) for running unpatched dynamic desktop binaries
      # (VS Code, Zed, Brave extensions). The base set already provides
      # stdenv.cc.cc.lib, zlib, openssl, icu, curl, glib.
      programs.nix-ld.libraries = with pkgs; [
        nss
        nspr
        libx11
        libxcomposite
        libxdamage
        libxrandr
        mesa
        libGL
        alsa-lib
        at-spi2-atk
        cups
        dbus
        expat
        gtk3
      ];

      environment.etc."determinate/config.json".text = builtins.toJSON {
        authentication.additionalNetrcSources = [ "/etc/nix/netrc" ];
      };

      # Extend the built-in iso-installer with install-image + disko tooling.
      # Build: nh os build-image --image-variant=iso-installer -H "<hostname>"
      image.modules.iso-installer =
        let
          # The target system closure — the non-installer config.
          targetToplevel = config.system.build.toplevel;
          installScript = pkgs.writeShellApplication {
            name = "install-image";
            runtimeInputs = with pkgs; [
              util-linux
              cryptsetup
              lvm2
            ];
            text = ''
              # Live ISOs mount / as tmpfs and expose the source medium at /iso.
              # Refuse to run anywhere else so we don't clobber an installed system.
              if ! mountpoint -q /iso; then
                echo "ERROR: install-image should only be run from a live ISO environment."
                echo "       Refusing to run on an installed system to prevent data loss."
                exit 1
              fi

              echo "NixOS Offline Installer"
              echo "======================="
              echo "System closure: ${targetToplevel}"
              echo ""
              echo "WARNING: This will format disks according to the disko configuration."
              read -rp "Type YES to continue: " confirm
              [ "$confirm" = "YES" ] || { echo "Aborted."; exit 1; }

              echo ""
              echo "=== Step 1: Partitioning and formatting with disko ==="
              ${config.system.build.diskoScript}

              echo ""
              echo "=== Step 2: Installing NixOS (offline) ==="
              nixos-install \
                --system ${targetToplevel} \
                --no-root-passwd \
                --no-channel-copy \
                --option substituters ""

              echo ""
              echo "=== Done — reboot into your new system ==="
            '';
          };
        in
        {
          environment.systemPackages = [
            installScript
            pkgs.parted
          ];
        };

      environment.systemPackages = [
        pkgs.brave
        pkgs.dmidecode
        pkgs.firefox
        pkgs.google-chrome
        pkgs.kitty
        pkgs.obsidian
        pkgs.pulseaudio
        pkgs.signal-desktop
        pkgs.slack
        pkgs.vscode
        pkgs.vulkan-tools
        pkgs.yubikey-manager
        pkgs.yubioath-flutter
        pkgs.zed-editor
        pkgs.zoom-us

        # Standalone GNOME apps — usable without gnome-shell. Picked to
        # complement noctalia, which already provides bar / notifications /
        # launcher / lock / OSD / wallpaper / night-light.
        pkgs.gnome-disk-utility
        pkgs.nautilus
        pkgs.baobab
        pkgs.file-roller
        pkgs.loupe
        pkgs.evince
        pkgs.gnome-calculator
        pkgs.mission-center
        pkgs.snapshot

        # Per-app audio routing UI; not GNOME, but the standard companion
        # for pipewire/pulse on a non-GNOME session.
        pkgs.pavucontrol
      ];

      # Backing services for nautilus + gnome-disk-utility on a non-GNOME
      # session. gvfs powers trash, mounted volumes, and network shares;
      # tumbler renders thumbnails; udisks2 backs gnome-disks.
      services.gvfs.enable = true;
      services.tumbler.enable = true;
      services.udisks2.enable = true;
      programs.dconf.enable = true;

      # ReGreet calls `org.freedesktop.Accounts` at startup to enumerate
      # human users for the picker; without accountsservice on the bus it
      # panics in src/gui/model.rs ("MethodError … ServiceUnknown: The
      # name is not activatable") and falls back to a default GTK form
      # with none of our regreet.toml / regreet.css applied — visually
      # identical to a fresh ReGreet install. GNOME pulls accountsservice
      # in transitively, so the bug only shows up on Hyprland hosts.
      services.accounts-daemon.enable = true;

      hm.imports = [ flakeCfg.flake.homeModules.onepassword ];
    };
}
