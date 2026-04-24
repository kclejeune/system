_: {
  flake.homeModules.gnome =
    { lib, pkgs, ... }:
    let
      leftSerial = "4K8X779B03VL";
      rightSerial = "4K8X77950L3L";
      mkDellMonitor = connector: serial: ''
        <monitor>
          <monitorspec>
            <connector>${connector}</connector>
            <vendor>DEL</vendor>
            <product>DELL U2718Q</product>
            <serial>${serial}</serial>
          </monitorspec>
          <mode>
            <width>3840</width>
            <height>2160</height>
            <rate>59.997</rate>
          </mode>
        </monitor>'';
      laptop = connector: ''
        <monitor>
          <monitorspec>
            <connector>${connector}</connector>
            <vendor>LGD</vendor>
            <product>0x06b3</product>
            <serial>0x00000000</serial>
          </monitorspec>
          <mode>
            <width>1920</width>
            <height>1200</height>
            <rate>59.950</rate>
          </mode>
        </monitor>'';
      mkDockedConfig = leftDP: rightDP: ''
        <configuration>
          <layoutmode>logical</layoutmode>
          <logicalmonitor>
            <x>0</x>
            <y>0</y>
            <scale>1.5</scale>
            ${mkDellMonitor leftDP leftSerial}
          </logicalmonitor>
          <logicalmonitor>
            <x>2560</x>
            <y>0</y>
            <scale>1.5</scale>
            ${mkDellMonitor rightDP rightSerial}
          </logicalmonitor>
          <logicalmonitor>
            <x>1798</x>
            <y>1440</y>
            <scale>1.25</scale>
            <primary>yes</primary>
            ${laptop "eDP-1"}
          </logicalmonitor>
        </configuration>'';
      monitorsXml = pkgs.writeText "monitors.xml" ''
        <monitors version="2">
          ${mkDockedConfig "DP-1" "DP-2"}
          ${mkDockedConfig "DP-1" "DP-3"}
          ${mkDockedConfig "DP-2" "DP-1"}
          ${mkDockedConfig "DP-2" "DP-3"}
          ${mkDockedConfig "DP-3" "DP-1"}
          ${mkDockedConfig "DP-3" "DP-2"}
        </monitors>
      '';
    in
    {
      xdg.mime.enable = pkgs.stdenvNoCC.isLinux;

      # GTK theming is set in hyprland.nix HM (Catppuccin Mocha) which works
      # well under both GNOME and Hyprland. Avoid setting it here to prevent
      # conflicts when both modules are imported.

      dconf.settings = lib.mkIf pkgs.stdenvNoCC.isLinux {
        "org/gnome/desktop/datetime" = {
          # Handled by tzupdate; GNOME's auto-tz uses GeoClue which gets
          # bad fixes through Cloudflare WARP.
          automatic-timezone = false;
        };
        "org/gnome/desktop/peripherals/keyboard" = {
          delay = "uint32 304";
          repeat-interval = "uint32 13";
        };
        "org/gnome/desktop/interface".monospace-font-name = "JetBrains Mono";
        "org/gnome/mutter".experimental-features = [ "scale-monitor-framebuffer" ];
        "org/gnome/desktop/peripherals/touchpad" = {
          two-finger-scrolling-enabled = true;
          accel-profile = "adaptive";
        };
        "org/gnome/desktop/wm/keybindings".close = [ "<Alt>w" ];
        "org/gnome/shell".favorite-apps = [
          "brave-browser.desktop"
          "firefox-devedition.desktop"
          "kitty.desktop"
          "code.desktop"
          "dev.zed.Zed.desktop"
          "slack.desktop"
          "signal-desktop.desktop"
          "1password.desktop"
          "org.gnome.Nautilus.desktop"
        ];
      };

      # Mutter silently ignores read-only nix store symlinks for monitors.xml.
      # Use systemd tmpfiles to copy a writable version into ~/.config/.
      # C+ = copy only if the destination doesn't already exist (preserves
      # user changes made via Settings > Displays until the next activation).
      systemd.user.tmpfiles.rules = lib.mkIf pkgs.stdenvNoCC.isLinux [
        "C+ %h/.config/monitors.xml - - - - ${monitorsXml}"
      ];
    };
}
