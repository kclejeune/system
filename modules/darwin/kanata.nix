# kanata on macOS: Caps Lock is Ctrl when held and Escape when tapped alone,
# matching keyd's `overload(control, esc)` on NixOS (nixos/keyd.nix).
#
# kanata seizes keyboards through Karabiner's DriverKit VirtualHIDDevice. The
# driver version must match what kanata's karabiner-driverkit client speaks;
# nixpkgs pins it as `kanata.passthru.darwinDriver`, so upgrade them together.
#
# One-time manual steps after the first switch:
#   1. System Settings > General > Login Items & Extensions > Driver
#      Extensions: enable org.pqrs.Karabiner-DriverKit-VirtualHIDDevice.
#   2. Privacy & Security > Input Monitoring and Accessibility: allow the
#      kanata binary. TCC grants follow the binary, so re-grant after any
#      kanata update changes its store path.
# Logs: /var/log/kanata.log
_: {
  flake.darwinModules.kanata =
    { lib, pkgs, ... }:
    let
      inherit (pkgs) kanata;
      driver = kanata.passthru.darwinDriver;
      # DriverKit extensions activate only from an app inside /Applications,
      # and the app cannot be a symlink. Kept apart from the
      # services.karabiner-elements directory (/Applications/.Nix-Karabiner).
      appDir = "/Applications/.Nix-Kanata";
      manager = "${appDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager";
      vhidDaemon = "${driver}/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon";

      config = pkgs.writeText "kanata.kbd" ''
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
      environment.systemPackages = [ kanata ];

      # kanata needs raw Caps Lock, so the system-level Caps-to-Ctrl remap
      # stays off. enableKeyMapping stays on so activation applies an empty
      # mapping and clears a remap left by an earlier generation.
      system.keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = false;
      };

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

      # Run the store binary directly, not via a shell wrapper, so the Input
      # Monitoring grant attaches to kanata itself. KeepAlive retries until
      # the store is mounted and the driver daemon is up.
      launchd.daemons.kanata.serviceConfig = {
        Label = "org.nixos.kanata";
        ProgramArguments = [
          (lib.getExe kanata)
          "--cfg"
          "${config}"
          "--nodelay"
        ];
        ProcessType = "Interactive";
        KeepAlive = true;
        RunAtLoad = true;
        ThrottleInterval = 10;
        StandardOutPath = "/var/log/kanata.log";
        StandardErrorPath = "/var/log/kanata.log";
      };
    };
}
