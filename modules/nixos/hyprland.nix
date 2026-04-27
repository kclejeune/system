{ config, ... }:
let
  flakeCfg = config;
in
{
  flake.nixosModules.hyprland =
    {
      lib,
      pkgs,
      config,
      inputs,
      ...
    }:
    let
      noctaliaBin = lib.getExe inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      # noctalia-shell ipc with the default config-path discovery hits a
      # quickshell upstream bug: even when the registered config path is an
      # exact match, lookup returns "No running instances". --pid form works.
      # The wrapper unconditionally `setenv(QS_CONFIG_PATH, ..., 0)` (no-overwrite),
      # so we pass `QS_CONFIG_PATH=` (empty, defined) to neutralize it before
      # invoking with --pid.
      noctaliaIpc = pkgs.writeShellScript "noctalia-ipc" ''
        uid=$(${pkgs.coreutils}/bin/id -u)
        export XDG_RUNTIME_DIR="/run/user/$uid"
        # The nixpkgs wrapper chain renames the running binary to
        # `.quickshell-wrapped`, so /proc/<pid>/comm truncates to
        # `.quickshell-wra` and `pgrep -x quickshell` finds nothing. Match
        # cmdline endings against `*/bin/quickshell` instead — noctalia's
        # exec-once invokes the wrapper with no arguments, so the cmdline
        # is exactly the resolved binary path.
        pid=$(${pkgs.procps}/bin/pgrep -U "$uid" -fxo '.*/bin/quickshell' 2>/dev/null || true)
        if [ -z "$pid" ]; then
          echo "noctalia-ipc: no running quickshell for uid $uid" >&2
          exit 0
        fi
        QS_CONFIG_PATH= exec ${noctaliaBin} ipc --pid "$pid" "$@"
      '';
    in
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };

      services.xserver.enable = true;
      services.xserver.xkb.layout = "us";
      services.displayManager.gdm.enable = true;

      programs.gnupg.agent.pinentryPackage = pkgs.pinentry-gnome3;

      xdg.portal = {
        enable = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
      };

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        wireplumber.enable = true;
      };

      hardware.graphics.enable = true;

      security.polkit.enable = true;

      hardware.bluetooth.enable = true;

      services.gnome.gnome-keyring.enable = true;

      # Dedicated PAM service for noctalia's lock screen. Selected via the
      # `NOCTALIA_PAM_SERVICE` env var on the home side; without this,
      # noctalia falls back to /etc/pam.d/login, which has no fprintAuth
      # and so password is the only path. Mirrors the pattern hyprlock used.
      security.pam.services.noctalia = {
        fprintAuth = true;
        enableGnomeKeyring = true;
      };

      services.upower.enable = true;
      services.power-profiles-daemon.enable = lib.mkDefault true;

      # Pre/post system-sleep hooks for noctalia. Replaces the old hypridle
      # `before_sleep_cmd` / `after_sleep_cmd` pair, since noctalia has no
      # logind PrepareForSleep subscriber of its own and its lockOnSuspend
      # setting only fires for noctalia's own idle-driven suspend path.
      #
      # Pattern: Before=sleep.target with RemainAfterExit + StopWhenUnneeded
      # — same shape NixOS uses for its own sleep-actions.service. Runs as
      # a system unit (not user) because the user manager's sleep.target
      # isn't propagated from system suspends; `User=` + the noctaliaIpc
      # helper give the IPC call the right session socket.
      systemd.services.lock-before-sleep = {
        description = "Lock noctalia before sleep, restart auth on resume";
        wantedBy = [ "sleep.target" ];
        before = [ "sleep.target" ];
        unitConfig.StopWhenUnneeded = true;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = config.user.name;
          ExecStart = pkgs.writeShellScript "lock-before-sleep" ''
            ${noctaliaIpc} call lockScreen lock || true
          '';
          # Restart PAM auth after resume: pam_fprintd's Verify session is
          # bound to the pre-suspend Goodix USB handle, which is invalidated
          # when the device re-enumerates. Without this, finger scans go
          # nowhere until the user types something to kick the auth flow.
          # Requires the `lockScreen.restartAuth` IPC handler added in our
          # noctalia fork (flake.nix pin).
          ExecStop = pkgs.writeShellScript "auth-restart-after-resume" ''
            ${noctaliaIpc} call lockScreen restartAuth || true
          '';
        };
      };

      hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
    };
}
