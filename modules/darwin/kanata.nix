# Caps Lock is Ctrl when held and Escape when tapped alone, matching keyd's
# `overload(control, esc)` on NixOS (nixos/keyd.nix).
#
# Default: Hammerspoon's caps2esc.lua, on top of the system Caps-to-Ctrl remap
# set here. `kanata.enable = true` switches to kanata instead.
#
# kanata seizes keyboards through Karabiner's DriverKit VirtualHIDDevice. The
# driver version must match what kanata's karabiner-driverkit client speaks;
# nixpkgs pins it as `kanata.passthru.darwinDriver`, so upgrade them together.
#
# One-time manual steps after enabling kanata:
#   1. System Settings > General > Login Items & Extensions > Driver
#      Extensions: enable org.pqrs.Karabiner-DriverKit-VirtualHIDDevice.
#   2. Privacy & Security > Input Monitoring and Accessibility: add the kanata
#      store binary. A root daemon cannot raise the prompt itself.
# The grants pin kanata's ad-hoc cdhash, which changes on every nixpkgs
# rebuild of kanata (every few weeks), so pin kanata's nixpkgs before relying
# on it. Logs: /var/log/kanata.log
_: {
  flake.darwinModules.kanata =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.kanata;
      inherit (pkgs) kanata;
      driver = kanata.passthru.darwinDriver;
      # DriverKit extensions activate only from an app inside /Applications,
      # and the app cannot be a symlink. Kept apart from the
      # services.karabiner-elements directory (/Applications/.Nix-Karabiner).
      appDir = "/Applications/.Nix-Kanata";
      manager = "${appDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager";
      vhidDaemon = "${driver}/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon";

      kbdFile = pkgs.writeText "kanata.kbd" ''
        (defcfg
          process-unmapped-keys yes
        )

        (defsrc caps)

        ;; Ctrl as soon as another key is pressed during the hold; Escape on a
        ;; solo release. A solo hold past 1 s resolves to Ctrl, not Escape.
        (defalias cap (tap-hold-press 0 1000 esc lctl))

        (deflayer base @cap)
      '';
    in
    {
      options.kanata.enable = lib.mkEnableOption "kanata for Caps Lock instead of Hammerspoon's caps2esc";

      config = lib.mkMerge [
        {
          # caps2esc.lua needs Caps Lock already remapped to Ctrl; kanata needs
          # it raw. enableKeyMapping stays on either way so activation replaces
          # the previous generation's mapping.
          system.keyboard = {
            enableKeyMapping = true;
            remapCapsLockToControl = !cfg.enable;
          };
        }

        (lib.mkIf cfg.enable {
          environment.systemPackages = [ kanata ];

          system.activationScripts.preActivation.text = ''
            rm -rf ${appDir}
            mkdir -p ${appDir}
            cp -R ${driver}/Applications/.Karabiner-VirtualHIDDevice-Manager.app ${appDir}
          '';

          system.activationScripts.postActivation.text = ''
            echo "activating Karabiner VirtualHIDDevice driver extension..." >&2
            ${manager} activate || echo "driver activation needs approval in System Settings" >&2
          '';

          launchd.daemons.karabiner-vhid-daemon.serviceConfig = {
            Label = "org.pqrs.Karabiner-VirtualHIDDevice-Daemon";
            ProgramArguments = [ vhidDaemon ];
            ProcessType = "Interactive";
            KeepAlive = true;
            RunAtLoad = true;
          };

          # Hammerspoon's init.lua skips caps2esc while this plist exists, so
          # the two never both send Escape. Run the store binary directly, not
          # via a shell wrapper, so the Input Monitoring grant attaches to
          # kanata itself. KeepAlive retries until the store is mounted and the
          # driver daemon is up.
          launchd.daemons.kanata.serviceConfig = {
            Label = "org.nixos.kanata";
            ProgramArguments = [
              (lib.getExe kanata)
              "--cfg"
              "${kbdFile}"
              "--nodelay"
            ];
            ProcessType = "Interactive";
            KeepAlive = true;
            RunAtLoad = true;
            ThrottleInterval = 10;
            StandardOutPath = "/var/log/kanata.log";
            StandardErrorPath = "/var/log/kanata.log";
          };
        })
      ];
    };
}
