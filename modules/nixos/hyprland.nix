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
      # ExecStart (pre-sleep): send the lockScreen IPC and wait 1 s for
      # the WlSessionLock surface to render before logind cuts power.
      #
      # ExecStop (post-resume): dispatch `monitors on` (= hyprctl dispatch
      # dpms on) so eDP/external panels don't go through the natural DRM
      # wake flicker while the lock surface is the first frame visible.
      #
      # Pattern: Before=sleep.target with RemainAfterExit + StopWhenUnneeded
      # — same shape NixOS uses for its own sleep-actions.service. Runs as
      # a system unit (not user) because the user manager's sleep.target
      # isn't propagated from system suspends; `User=` + XDG_RUNTIME_DIR
      # gives the IPC call the right session socket.
      systemd.services.lock-before-sleep = {
        description = "Lock noctalia before sleep, restore monitors on resume";
        wantedBy = [ "sleep.target" ];
        before = [ "sleep.target" ];
        unitConfig.StopWhenUnneeded = true;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = config.user.name;
          ExecStart = pkgs.writeShellScript "lock-before-sleep" ''
            export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
            ${noctaliaBin} ipc call lockScreen lock || true
            sleep 1
          '';
          ExecStop = pkgs.writeShellScript "monitors-on-after-resume" ''
            export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
            ${noctaliaBin} ipc call monitors on || true
          '';
        };
      };

      hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
    };
}
