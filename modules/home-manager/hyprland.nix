# Hyprland home-manager configuration — compositor settings, keybindings,
# companion tools (waybar, swaync, vicinae, hyprlock, hypridle, kanshi),
# and Catppuccin Mocha theming.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Catppuccin Mocha (dark)
  dark = {
    base = "1e1e2e";
    mantle = "181825";
    crust = "11111b";
    surface0 = "313244";
    overlay0 = "6c7086";
    text = "cdd6f4";
    subtext1 = "bac2de";
    blue = "89b4fa";
    lavender = "b4befe";
    green = "a6e3a1";
    yellow = "f9e2af";
    peach = "fab387";
    red = "f38ba8";
    mauve = "cba6f7";
  };
  # Catppuccin Latte (light)
  light = {
    base = "eff1f5";
    mantle = "e6e9ef";
    crust = "dce0e8";
    surface0 = "ccd0da";
    overlay0 = "9ca0b0";
    text = "4c4f69";
    subtext1 = "5c5f77";
    blue = "1e66f5";
    lavender = "7287fd";
    green = "40a02b";
    yellow = "df8e1d";
    peach = "fe640b";
    red = "d20f39";
    mauve = "8839ef";
  };
  # Default to dark
  c = dark;

in
{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd.enable = true;

    settings = {
      # -- Monitors (fallback; kanshi handles runtime) --
      # Monitor positions are managed by kanshi at runtime.
      # These fallbacks ensure a usable layout before kanshi applies a profile.
      # Keep the eDP-1 mode identical to kanshi's undocked profile (59.95 Hz,
      # scale 1.0) so wake doesn't force a second modeset after kanshi fires.
      monitor = [
        "eDP-1, 1920x1200@59.95Hz, 0x0, 1"
        ", preferred, auto, 1.5"
      ];

      general = {
        gaps_in = 4;
        gaps_out = 4;
        border_size = 2;
        "col.active_border" = "rgba(${c.lavender}ff) rgba(${c.blue}ff) 45deg";
        "col.inactive_border" = "rgba(${c.overlay0}aa)";
        layout = "dwindle";
        allow_tearing = false;
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 6;
          passes = 2;
          new_optimizations = true;
        };
        shadow = {
          enabled = true;
          range = 10;
          render_power = 3;
          color = "rgba(${c.crust}ee)";
        };
        active_opacity = 1.0;
        inactive_opacity = 0.98;
      };

      animations = {
        enabled = true;
        bezier = [
          "easeOutQuint, 0.23, 1, 0.32, 1"
          "easeInOutCubic, 0.65, 0.05, 0.35, 0.95"
          "linear, 0, 0, 1, 1"
          "almostLinear, 0.5, 0.5, 0.75, 1.0"
          "quick, 0.15, 0, 0.1, 1"
        ];
        animation = [
          "global, 1, 10, default"
          "border, 1, 5.39, easeOutQuint"
          "windows, 1, 4.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, linear, popin 87%"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"
          "fade, 1, 3.03, quick"
          "layers, 1, 3.81, easeOutQuint"
          "workspaces, 1, 1.94, almostLinear, fade"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0;
        accel_profile = "adaptive";
        repeat_delay = 304;
        repeat_rate = 77;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
        };
      };

      gesture = [
        "3, horizontal, workspace"
      ];

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
        focus_on_activate = true;
      };

      ecosystem = {
        no_update_news = true;
      };

      # -- Startup --
      # waybar, mako, hypridle, hyprpaper, kanshi are started via their
      # respective HM systemd services — only list things without a service here.
      exec-once = [
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      ];

      # -- Named workspaces with monitor pinning --
      workspace = [
        "name:B, monitor:desc:Dell Inc. DELL U2718Q 4K8X779B03VL, default:true"
        "name:V, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
        "name:I, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
        "name:T, monitor:eDP-1"
        "name:S, monitor:eDP-1"
        "name:Z, monitor:eDP-1"
        "name:D"
        "name:N"
        "name:O"
        "name:G"
        "name:M"
      ];

      # Window rules use block syntax in Hyprland 0.54+

      # -- Keybindings --
      "$mod" = "ALT";

      bind = [
        # Focus (alt-hjkl)
        "$mod, h, movefocus, l"
        "$mod, j, movefocus, d"
        "$mod, k, movefocus, u"
        "$mod, l, movefocus, r"

        # Move window (alt-shift-hjkl)
        "$mod SHIFT, h, movewindow, l"
        "$mod SHIFT, j, movewindow, d"
        "$mod SHIFT, k, movewindow, u"
        "$mod SHIFT, l, movewindow, r"

        # Layout (alt-slash = toggle split, alt-comma = toggle layout)
        "$mod, slash, togglesplit"
        "$mod, comma, exec, hyprctl keyword general:layout $(hyprctl getoption general:layout -j | jq -r 'if .str == \"dwindle\" then \"master\" else \"dwindle\" end')"

        # Workspace navigation
        "$mod, Tab, workspace, previous"
        "$mod SHIFT, Tab, movecurrentworkspacetomonitor, +1"

        # Launch
        "$mod, Return, exec, kitty"
        "$mod, Space, exec, vicinae toggle"

        # Dark/light mode toggle
        "SUPER, d, exec, darkman toggle"

        # Lock screen
        "$mod CTRL, q, exec, pidof hyprlock || hyprlock"
        "SUPER, l, exec, pidof hyprlock || hyprlock"

        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim - | wl-copy"

        # Power menu
        "$mod SHIFT, e, exec, power-menu"

        # Clipboard history
        "$mod, c, exec, cliphist list | vicinae dmenu | cliphist decode | wl-copy"

        # Named workspaces (alt-{letter}, matching aerospace 1:1)
        "$mod, a, workspace, name:A"
        "$mod, b, workspace, name:B"
        # alt-c reserved
        "$mod, d, workspace, name:D"
        "$mod, e, workspace, name:E"
        "$mod, f, workspace, name:F"
        "$mod, g, workspace, name:G"
        "$mod, i, workspace, name:I"
        "$mod, m, workspace, name:M"
        "$mod, n, workspace, name:N"
        "$mod, o, workspace, name:O"
        "$mod, p, workspace, name:P"
        "$mod, q, workspace, name:Q"
        "$mod, r, workspace, name:R"
        "$mod, s, workspace, name:S"
        "$mod, t, workspace, name:T"
        "$mod, u, workspace, name:U"
        "$mod, v, workspace, name:V"
        "$mod, w, killactive"
        "$mod, x, workspace, name:X"
        "$mod, y, workspace, name:Y"
        "$mod, z, workspace, name:Z"

        # Move window to named workspace (alt-shift-{letter})
        "$mod SHIFT, a, movetoworkspace, name:A"
        "$mod SHIFT, b, movetoworkspace, name:B"
        # alt-shift-c reserved
        "$mod SHIFT, d, movetoworkspace, name:D"
        "$mod SHIFT, e, movetoworkspace, name:E"
        "$mod SHIFT, f, movetoworkspace, name:F"
        "$mod SHIFT, g, movetoworkspace, name:G"
        "$mod SHIFT, i, movetoworkspace, name:I"
        "$mod SHIFT, m, movetoworkspace, name:M"
        "$mod SHIFT, n, movetoworkspace, name:N"
        "$mod SHIFT, o, movetoworkspace, name:O"
        "$mod SHIFT, p, movetoworkspace, name:P"
        "$mod SHIFT, q, movetoworkspace, name:Q"
        "$mod SHIFT, r, movetoworkspace, name:R"
        "$mod SHIFT, s, movetoworkspace, name:S"
        "$mod SHIFT, t, movetoworkspace, name:T"
        "$mod SHIFT, u, movetoworkspace, name:U"
        "$mod SHIFT, v, movetoworkspace, name:V"
        # alt-shift-w unbound (alt-w = killactive)"
        "$mod SHIFT, x, movetoworkspace, name:X"
        "$mod SHIFT, y, movetoworkspace, name:Y"
        "$mod SHIFT, z, movetoworkspace, name:Z"

        # Numeric workspaces
        "$mod, 0, workspace, name:0"
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"

        "$mod SHIFT, 0, movetoworkspace, name:0"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"

        # Submaps (alt-shift-semicolon = service, alt-shift-slash = join)
        "$mod SHIFT, semicolon, submap, service"
        "$mod SHIFT, slash, submap, join"
      ];

      # Resize (repeatable)
      binde = [
        "$mod SHIFT, minus, resizeactive, -50 0"
        "$mod SHIFT, equal, resizeactive, 50 0"
      ];
    };

    extraConfig = ''
      # -- Window rules (inline syntax, Hyprland 0.54+) --

      # T — Terminals
      windowrule = match:class kitty, workspace name:T
      windowrule = match:class org.alacritty, workspace name:T
      windowrule = match:class ghostty, workspace name:T
      windowrule = match:class com.mitchellh.ghostty, workspace name:T

      # B — Browsers
      windowrule = match:class brave-browser, workspace name:B
      windowrule = match:class firefox, workspace name:B
      windowrule = match:class firefox-devedition, workspace name:B
      windowrule = match:class chromium-browser, workspace name:B

      # V — Editors
      windowrule = match:class code, workspace name:V
      windowrule = match:class code-url-handler, workspace name:V
      windowrule = match:class dev.zed.Zed, workspace name:V

      # I — IDEs
      windowrule = match:class jetbrains-idea, workspace name:I
      windowrule = match:class jetbrains-pycharm, workspace name:I
      windowrule = match:class jetbrains-datagrip, workspace name:I

      # S — Social / messaging
      windowrule = match:class Slack, workspace name:S
      windowrule = match:class signal, workspace name:S
      windowrule = match:class discord, workspace name:S

      # Z — Zoom / video calls
      windowrule = match:class zoom, workspace name:Z

      # N — Notes
      windowrule = match:class obsidian, workspace name:N

      # O — Email / calendar
      windowrule = match:class thunderbird, workspace name:O

      # F — Files
      windowrule = match:class org.gnome.Nautilus, workspace name:F

      # D — Docker
      windowrule = match:class docker-desktop, workspace name:D

      # Float transient windows
      windowrule = match:class 1Password match:title Quick.Access, float true
      windowrule = match:class nm-connection-editor, float true
      windowrule = match:class com.saivert.pwvucontrol, float true, size 800 600
      windowrule = match:class io.github.kaii_lb.Overskride, float true, size 600 500
      windowrule = match:title Picture-in-Picture, float true

      # -- Service submap (alt-shift-semicolon) --
      submap = service
      bind = ALT, r, exec, hyprctl dispatch workspaceopt allfloat
      bind = ALT, f, togglefloating,
      bind = , backspace, exec, hyprctl dispatch closewindow address:!active
      bind = , escape, exec, hyprctl reload
      bind = , escape, submap, reset
      submap = reset

      # -- Join submap (alt-shift-slash) --
      # Hyprland doesn't have aerospace's join-with, but we can move
      # windows into groups. Use alt-hjkl to move the active window
      # in a direction (same as alt-shift-ctrl-hjkl in aerospace).
      submap = join
      bind = ALT, h, movewindow, l
      bind = ALT, j, movewindow, d
      bind = ALT, k, movewindow, u
      bind = ALT, l, movewindow, r
      bind = , escape, submap, reset
      submap = reset
    '';
  };

  # -- Waybar --
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = [
      {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;

        modules-left = [
          "hyprland/workspaces"
          "hyprland/submap"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "tray"
          "custom/darkman"
          "pulseaudio"
          "bluetooth"
          "network"
          "battery"
          "custom/notification"
          "custom/power"
        ];

        "custom/notification" = {
          tooltip = false;
          format = "{icon}";
          format-icons = {
            notification = "󰂚";
            none = "󰂜";
            dnd-notification = "󰂛";
            dnd-none = "󰪑";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          escape = true;
        };

        "custom/darkman" = {
          exec = ''sh -c 'while true; do if [ "$(darkman get)" = "dark" ]; then echo "󰖔"; else echo "󰖙"; fi; sleep 1; done' '';
          on-click = "darkman toggle";
          tooltip-format = "Toggle dark/light mode";
          return-type = "";
        };

        "custom/power" = {
          format = "⏻";
          tooltip-format = "Power menu";
          on-click = "power-menu";
        };

        "hyprland/workspaces" = {
          format = "{name}";
          on-click = "activate";
          sort-by-name = true;
          persistent-workspaces = {
            "B" = [ ];
            "T" = [ ];
            "V" = [ ];
            "S" = [ ];
          };
        };

        clock = {
          format = "{:%a %b %d  %I:%M %p}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon}  {capacity}%";
          format-icons = [
            "󰁺"
            "󰁼"
            "󰁾"
            "󰂀"
            "󰁹"
          ];
          format-charging = "󰂄  {capacity}%";
          format-plugged = "󰚥  {capacity}%";
          tooltip-format = "{timeTo} ({power:.1f}W)";
        };

        network = {
          format-wifi = "󰖩  {essid}";
          format-ethernet = "󰈀  {ifname}";
          format-disconnected = "󰖪  disconnected";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}\n{signalStrength}% signal";
          on-click = "nm-connection-editor";
        };

        bluetooth = {
          format = "󰂯";
          format-connected = "󰂱  {device_alias}";
          format-disabled = "󰂲";
          tooltip-format = "{controller_alias}\n{num_connections} connected";
          on-click = "overskride";
        };

        pulseaudio = {
          format = "{icon}  {volume}%";
          format-muted = "󰝟  muted";
          format-icons.default = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
          on-click = "pwvucontrol";
          on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          tooltip-format = "{desc}: {volume}%";
        };

        tray.spacing = 10;
      }
    ];

    style = ''
      * {
        font-family: JetBrains Mono Nerd Font, JetBrains Mono, sans-serif;
        font-size: 12px;
        min-height: 0;
      }
      window#waybar {
        background-color: alpha(@theme_base_color, 0.92);
        color: @theme_text_color;
        border-bottom: 1px solid alpha(@borders, 0.4);
      }
      #workspaces button {
        padding: 0 8px;
        background-color: transparent;
        color: @theme_unfocused_text_color;
        border-bottom: 2px solid transparent;
      }
      #workspaces button.active {
        color: @theme_text_color;
        border-bottom: 2px solid @theme_selected_bg_color;
      }
      #workspaces button.urgent {
        color: @error_color;
      }
      #clock, #battery, #network, #pulseaudio, #bluetooth, #tray {
        padding: 0 12px;
        color: @theme_text_color;
      }
      #battery.warning { color: @warning_color; }
      #battery.critical { color: @error_color; }
      #custom-darkman {
        padding: 0 8px;
        color: @theme_unfocused_text_color;
      }
      #custom-power {
        padding: 0 16px 0 8px;
        color: @theme_unfocused_text_color;
      }
      #custom-power:hover {
        color: @error_color;
      }
      #custom-notification {
        padding: 0 8px;
        color: @theme_unfocused_text_color;
      }
    '';
  };

  # -- SwayNC (notification center with history panel) --
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      control-center-margin-right = 8;
      control-center-margin-top = 8;
      control-center-margin-bottom = 8;
      control-center-width = 420;
      notification-window-width = 420;
      notification-icon-size = 48;
      notification-body-image-height = 100;
      timeout = 5;
      timeout-low = 3;
      timeout-critical = 0;
      fit-to-screen = true;
      keyboard-shortcuts = true;
      hide-on-action = true;
      notification-spacing = 0;
    };
    style = ''
      * {
        font-family: JetBrains Mono Nerd Font, JetBrains Mono, sans-serif;
        font-size: 13px;
        color: @theme_text_color;
      }

      /* Popup notifications */
      .floating-notifications {
        padding-top: 4px;
      }
      .floating-notifications .notification-row,
      .floating-notifications .notification-row .notification-background .notification-content,
      .floating-notifications .notification-row .notification-background .notification-default-action,
      .notification-row {
        margin: 0;
        padding: 0;
        background: transparent;
        border: none;
      }
      .floating-notifications .notification-row .notification-background {
        margin: 0 8px 0 0;
        padding: 0;
        background: transparent;
        border: none;
      }
      .notification {
        background: alpha(shade(@theme_base_color, 0.92), 0.95);
        border: 1px solid alpha(@borders, 0.6);
        border-radius: 8px;
        margin: 4px 8px;
        padding: 8px;
        box-shadow: none;
        transition: border 200ms ease;
      }
      .notification:hover {
        border: 1px solid @theme_selected_bg_color;
      }
      .notification .body,
      .notification .time {
        color: @theme_unfocused_text_color;
      }

      /* Sidebar panel */
      .control-center {
        background: alpha(shade(@theme_base_color, 0.9), 0.98);
        border: 1px solid @theme_selected_bg_color;
        border-radius: 8px;
        box-shadow: none;
        padding: 6px;
      }

      /* Reset all wrapper elements inside the panel */
      .control-center .notification-row,
      .control-center .notification-row:hover,
      .control-center .notification-row:focus,
      .control-center .notification-row:active,
      .control-center .notification-background,
      .control-center .notification-background:hover,
      .control-center .notification-background:focus,
      .control-center .notification-background:active,
      .control-center .notification-content,
      .control-center .notification-content:hover,
      .control-center .notification-content:focus,
      .control-center .notification-content:active,
      .control-center .notification-default-action,
      .control-center .notification-default-action:hover,
      .control-center .notification-default-action:focus,
      .control-center .notification-action {
        background: transparent;
        border: none;
        box-shadow: none;
        margin: 0;
        padding: 0;
        min-height: 0;
        min-width: 0;
      }
      .close-button {
        background: alpha(@borders, 0.2);
        border: none;
        box-shadow: none;
        min-height: 24px;
        min-width: 24px;
        margin: 4px;
        padding: 2px;
        border-radius: 50%;
      }
      .close-button:hover {
        background: alpha(@borders, 0.4);
      }
      .floating-notifications .close-button {
        opacity: 0;
        min-height: 0;
        min-width: 0;
      }
      .control-center .close-button {
        margin: 8px 4px 0 0;
      }

      /* Cards inside the panel */
      .control-center .notification {
        background: alpha(@theme_base_color, 0.9);
        border: 1px solid alpha(@borders, 0.4);
        border-radius: 8px;
        margin: 3px 0;
        padding: 8px;
        box-shadow: none;
        transition: border 200ms ease;
      }
      .control-center .notification:hover {
        border: 1px solid @theme_selected_bg_color;
      }

      /* Grouped notifications */
      .control-center .notification-group,
      .control-center .notification-group-headers {
        background: transparent;
      }
      .control-center .notification-group-header {
        background: alpha(@theme_bg_color, 0.3);
        border: 1px solid alpha(@borders, 0.3);
        border-radius: 8px;
        margin: 3px 0;
        padding: 6px 8px;
      }

      .control-center-list {
        margin: 0;
        padding: 0;
      }

      /* Header widgets -- 12px horizontal margin to align with cards */
      .widget-title {
        font-weight: bold;
        color: @theme_unfocused_text_color;
        margin: 4px 12px 2px 12px;
      }
      .widget-title button {
        background: alpha(@theme_base_color, 0.9);
        border: 1px solid alpha(@borders, 0.4);
        border-radius: 6px;
        padding: 4px 10px;
      }
      .widget-dnd {
        margin: 0 12px 4px 12px;
      }
      .widget-dnd slider:checked {
        background: @theme_selected_bg_color;
        border-radius: 10px;
      }
      .control-center-list-placeholder {
        color: @theme_unfocused_text_color;
      }
    '';
  };

  # -- Vicinae (app launcher) --
  # -- Darkman (dark/light mode toggle, no automatic transitions) --
  services.darkman = {
    enable = true;
    settings = {
      usegeoclue = false;
    };
    darkModeScripts = {
      gtk-theme = ''
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/gtk-theme "'catppuccin-mocha-blue-standard'"
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/icon-theme "'Papirus-Dark'"
        ${pkgs.dconf}/bin/dconf write /org/freedesktop/appearance/color-scheme "1"
      '';
      hyprland = ''
        hyprctl keyword general:col.active_border "rgba(${dark.lavender}ff) rgba(${dark.blue}ff) 45deg"
        hyprctl keyword general:col.inactive_border "rgba(${dark.overlay0}aa)"
        hyprctl keyword decoration:col.shadow "rgba(${dark.crust}ee)"
      '';
      waybar = ''
        pkill -SIGUSR2 waybar || true
      '';
      swaync = ''
        swaync-client --reload-css || true
      '';
      wallpaper = ''
        ln -sf ${config.home.homeDirectory}/.config/hypr/wallpaper-dark.png ${config.home.homeDirectory}/.config/hypr/wallpaper.png
        systemctl --user restart hyprpaper.service
      '';
      hyprlock = ''
        ln -sf ${config.home.homeDirectory}/.config/hypr/hyprlock-colors-dark.conf ${config.home.homeDirectory}/.config/hypr/hyprlock-colors.conf
      '';
    };
    lightModeScripts = {
      gtk-theme = ''
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/gtk-theme "'catppuccin-latte-blue-standard'"
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/icon-theme "'Papirus-Light'"
        ${pkgs.dconf}/bin/dconf write /org/freedesktop/appearance/color-scheme "2"
      '';
      hyprland = ''
        hyprctl keyword general:col.active_border "rgba(${light.lavender}ff) rgba(${light.blue}ff) 45deg"
        hyprctl keyword general:col.inactive_border "rgba(${light.overlay0}aa)"
        hyprctl keyword decoration:col.shadow "rgba(${light.crust}ee)"
      '';
      waybar = ''
        pkill -SIGUSR2 waybar || true
      '';
      swaync = ''
        swaync-client --reload-css || true
      '';
      wallpaper = ''
        ln -sf ${config.home.homeDirectory}/.config/hypr/wallpaper-light.png ${config.home.homeDirectory}/.config/hypr/wallpaper.png
        systemctl --user restart hyprpaper.service
      '';
      hyprlock = ''
        ln -sf ${config.home.homeDirectory}/.config/hypr/hyprlock-colors-light.conf ${config.home.homeDirectory}/.config/hypr/hyprlock-colors.conf
      '';
    };
  };

  programs.ghostty.enable = true;

  # Settings managed in dotfiles/vicinae/settings.json via mkOutOfStoreSymlink
  programs.vicinae = {
    enable = true;
    useLayerShell = true;
    systemd.enable = true;
  };

  # -- Hyprlock (screen locker) --
  # Colors are sourced from a file that darkman swaps for light/dark mode
  xdg.configFile."hypr/hyprlock-colors-dark.conf".text = ''
    $text = rgba(${dark.text}ff)
    $subtext = rgba(${dark.subtext1}cc)
    $mantle = rgba(${dark.mantle}66)
    $overlay = rgba(${dark.overlay0}88)
    $green = rgb(${dark.green})
    $red = rgb(${dark.red})
  '';
  xdg.configFile."hypr/hyprlock-colors-light.conf".text = ''
    $text = rgba(${light.text}ff)
    $subtext = rgba(${light.subtext1}cc)
    $mantle = rgba(${light.mantle}66)
    $overlay = rgba(${light.overlay0}88)
    $green = rgb(${light.green})
    $red = rgb(${light.red})
  '';

  programs.hyprlock = {
    enable = true;
    importantPrefixes = [ "source" ];
    settings = {
      source = "${config.home.homeDirectory}/.config/hypr/hyprlock-colors.conf";
      auth = {
        fingerprint = {
          enabled = true;
          ready_message = "Scan fingerprint to unlock";
          present_message = "Scanning...";
          retry_delay = 250;
        };
        pam = {
          enabled = true;
          module = "hyprlock";
        };
      };
      background = [
        {
          path = "${config.home.homeDirectory}/.config/hypr/wallpaper.png";
          blur_passes = 3;
          blur_size = 8;
        }
      ];
      input-field = [
        {
          size = "250, 45";
          position = "0, -30";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "$text";
          inner_color = "$mantle";
          outer_color = "$overlay";
          check_color = "$green";
          fail_color = "$red";
          outline_thickness = 1;
          placeholder_text = "Password";
          placeholder_color = "$overlay";
          rounding = 12;
        }
      ];
      # Layout (top to bottom, centered): clock → name → password → hint
      # Matches GNOME lock screen style: avatar → name → password
      label = [
        # Status bar (top-right): battery + wifi
        {
          monitor = "";
          text = ''cmd[update:5000] bat=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0); status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Unknown); if [ "$status" = "Charging" ]; then icon="󰂄"; elif [ "$bat" -ge 80 ]; then icon="󰁹"; elif [ "$bat" -ge 60 ]; then icon="󰂀"; elif [ "$bat" -ge 40 ]; then icon="󰁾"; elif [ "$bat" -ge 20 ]; then icon="󰁼"; else icon="󰁺"; fi; printf "%s %s%%" "$icon" "$bat"'';
          color = "$subtext";
          font_size = 12;
          font_family = "JetBrains Mono Nerd Font";
          position = "-20, -15";
          halign = "right";
          valign = "top";
        }
        {
          monitor = "";
          text = ''cmd[update:1000] echo "$(date +"%I:%M:%S %p")"'';
          color = "$text";
          font_size = 64;
          font_family = "JetBrains Mono";
          position = "0, 160";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "cmd[update:3600000] getent passwd $USER | cut -d: -f5 | cut -d, -f1";
          color = "$text";
          font_size = 20;
          font_family = "JetBrains Mono";
          position = "0, 30";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "<i>Scan fingerprint or type password to unlock</i>";
          color = "$subtext";
          font_size = 10;
          font_family = "JetBrains Mono";
          position = "0, -70";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  # -- Hypridle (idle management) --
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        lock_cmd = "pidof hyprlock || hyprlock";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "pidof hyprlock || hyprlock";
        }
        {
          # Turn off screens 10s after lock
          timeout = 310;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 900;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  # -- Hyprpaper (wallpaper) --
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      wallpaper = [
        {
          monitor = "";
          path = "${config.home.homeDirectory}/.config/hypr/wallpaper.png";
          fit_mode = "cover";
        }
      ];
    };
  };

  # -- Kanshi (monitor management, wlroots protocol) --
  services.kanshi = {
    enable = true;
    systemdTarget = "hyprland-session.target";
    settings = [
      {
        profile.name = "home";
        profile.outputs = [
          {
            criteria = "Dell Inc. DELL U2718Q 4K8X779B03VL";
            mode = "3840x2160@60Hz";
            scale = 1.5;
            position = "0,0";
          }
          {
            criteria = "Dell Inc. DELL U2718Q 4K8X77950L3L";
            mode = "3840x2160@60Hz";
            scale = 1.5;
            position = "2560,0";
          }
          {
            criteria = "eDP-1";
            mode = "1920x1200@59.95Hz";
            scale = 1.0;
            position = "1600,1440";
          }
        ];
      }
      {
        profile.name = "home-clamshell";
        profile.outputs = [
          {
            criteria = "Dell Inc. DELL U2718Q 4K8X779B03VL";
            mode = "3840x2160@60Hz";
            scale = 1.5;
            position = "0,0";
          }
          {
            criteria = "Dell Inc. DELL U2718Q 4K8X77950L3L";
            mode = "3840x2160@60Hz";
            scale = 1.5;
            position = "2560,0";
          }
        ];
      }
      {
        profile.name = "undocked";
        profile.outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1200@59.95Hz";
            scale = 1.0;
          }
        ];
      }
    ];
  };

  # -- GTK/Qt theming (Catppuccin Mocha) --
  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-blue-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "blue" ];
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Inter";
      size = 13;
      package = pkgs.inter;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  home.pointerCursor = {
    gtk.enable = true;
    name = "catppuccin-mocha-dark-cursors";
    package = pkgs.catppuccin-cursors.mochaDark;
    size = 24;
  };

  # -- Packages --
  home.packages = with pkgs; [
    (writeShellScriptBin "power-menu" ''
      choice=$(printf "Lock\nLogout\nSuspend\nReboot\nShutdown" | vicinae dmenu)
      case "$choice" in
        Lock) pidof hyprlock || hyprlock ;;
        Logout) hyprctl dispatch exit ;;
        Suspend) systemctl suspend ;;
        Reboot) systemctl reboot ;;
        Shutdown) systemctl poweroff ;;
      esac
    '')
    xdg-desktop-portal-gtk
    cliphist
    (catppuccin-gtk.override {
      accents = [ "blue" ];
      variant = "latte";
    })
    grim
    slurp
    grimblast
    pwvucontrol
    overskride
    gnome-bluetooth
    (writeShellScriptBin "gnome-settings" ''
      export XDG_CURRENT_DESKTOP=GNOME
      exec gnome-control-center "$@"
    '')
    (writeShellScriptBin "sync-wallpaper" ''
      # Sync GNOME wallpaper to hyprpaper location, converting SVG if needed
      for variant in dark light; do
        if [ "$variant" = "dark" ]; then
          uri=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/background/picture-uri-dark | tr -d "'")
        else
          uri=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/background/picture-uri | tr -d "'")
        fi
        src=''${uri#file://}
        dest="$HOME/.config/hypr/wallpaper-$variant.png"
        if [ -z "$src" ] || [ ! -f "$src" ]; then continue; fi
        case "$src" in
          *.svg)
            ${pkgs.librsvg}/bin/rsvg-convert -w 3840 "$src" -o "$dest"
            ;;
          *.png|*.jpg|*.jpeg)
            cp "$src" "$dest"
            ;;
        esac
      done
      ln -sf "$HOME/.config/hypr/wallpaper-dark.png" "$HOME/.config/hypr/wallpaper.png"
      systemctl --user restart hyprpaper.service 2>/dev/null || true
    '')
    gnome-control-center
    networkmanagerapplet
    wdisplays
  ];

  # Hide the original GNOME Settings entry; our gnome-settings wrapper works under Hyprland
  # VS Code: use desktop entry override instead of argv.json
  # (argv.json is managed by VS Code itself and conflicts with HM)
  xdg.desktopEntries.code = {
    name = "Visual Studio Code";
    exec = "code --password-store=gnome-libsecret %F";
    icon = "vscode";
    comment = "Code Editor";
    categories = [
      "Development"
      "IDE"
    ];
  };

  xdg.desktopEntries.obsidian = {
    name = "Obsidian";
    exec = "obsidian --password-store=gnome-libsecret %u";
    icon = "obsidian";
    comment = "Knowledge base";
    categories = [ "Office" ];
  };

  xdg.desktopEntries.signal = {
    name = "Signal";
    exec = "signal-desktop --password-store=gnome-libsecret %U";
    icon = "signal-desktop";
    comment = "Signal Private Messenger";
    categories = [
      "Network"
      "Chat"
    ];
  };

  xdg.desktopEntries.slack = {
    name = "Slack";
    exec = "slack --password-store=gnome-libsecret -s %U";
    icon = "slack";
    comment = "Slack Client";
    categories = [
      "Network"
      "Chat"
    ];
  };

  xdg.desktopEntries.brave-browser = {
    name = "Brave Web Browser";
    exec = "brave --password-store=gnome-libsecret %U";
    icon = "brave-browser";
    comment = "Web Browser";
    categories = [
      "Network"
      "WebBrowser"
    ];
  };

  xdg.desktopEntries."org.gnome.Settings" = {
    name = "Settings";
    exec = "gnome-settings";
    icon = "org.gnome.Settings";
    comment = "System Settings";
    categories = [ "Settings" ];
  };

  # -- Wayland environment variables --
  home.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GDK_BACKEND = "wayland,x11";
    CLUTTER_BACKEND = "wayland";
    SDL_VIDEODRIVER = "wayland";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland:GNOME";
    XDG_SESSION_DESKTOP = "Hyprland";
  };

  xdg.mime.enable = true;

  # Portal routing: gtk portal handles Settings (color-scheme for Zed, Electron),
  # hyprland portal handles screencasting/screenshots.
  xdg.configFile."xdg-desktop-portal/portals.conf".text = ''
    [preferred]
    default=gtk
    org.freedesktop.impl.portal.Settings=gtk
    org.freedesktop.impl.portal.Screenshot=hyprland
    org.freedesktop.impl.portal.ScreenCast=hyprland
    org.freedesktop.impl.portal.GlobalShortcuts=hyprland
  '';

  # Set dark color scheme via dconf (read by xdg-desktop-portal-gtk)
  dconf.settings."org/freedesktop/appearance" = {
    color-scheme = 1; # 0=default, 1=dark, 2=light
  };
}
