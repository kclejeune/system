{ config, ... }:
let
  flakeCfg = config;
in
{
  flake.homeModules.hyprland =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      # Mocha drives the Hyprland borders; darkModeChange swaps them to Latte.
      # Noctalia themes everything else itself.
      theme = flakeCfg.flake.lib.mkTheme pkgs;
      dark = theme.palettes.dark;
      light = theme.palettes.light;
      c = dark;

      hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";

      # `hyprctl reload` doesn't re-init plugins, and hypr-dynamic-cursors sometimes
      # gets stuck sluggish; bounce it. Its store path comes from the live process.
      hyprReload = pkgs.writeShellScript "hypr-reload" ''
        ${hyprctl} reload
        plug=$(${pkgs.gawk}/bin/awk '/libhypr-dynamic-cursors\.so/ {print $NF; exit}' \
          /proc/$(${pkgs.procps}/bin/pgrep -x Hyprland)/maps 2>/dev/null) || true
        if [ -n "$plug" ]; then
          ${hyprctl} plugin unload "$plug" || true
          ${hyprctl} plugin load "$plug" || true
        fi
      '';

      # quickshell's config-path discovery is broken, so pass --pid. The wrapper's
      # QS_CONFIG_PATH conflicts with --pid, and the wrapped binary is renamed, so
      # match on the cmdline.
      noctaliaIpc = pkgs.writeShellScript "noctalia-ipc" ''
        export QS_CONFIG_PATH=
        exec noctalia-shell ipc --pid "$(pgrep -fxo '.*/bin/quickshell')" "$@"
      '';

      # After resume: DPMS on first so the lock screen is visible, then wait for the
      # Goodix reader (the kernel re-enumerates it 3-8s after PrepareForSleep), then
      # re-arm fingerprint auth. Best-effort so a failure can't strand the lock.
      afterSleepHook = pkgs.writeShellScript "noctalia-after-sleep" ''
        ${hyprctl} dispatch dpms on || true

        # 30 × 0.3s = 9s budget — covers observed 3–8s post-resume
        # Goodix USB re-enumeration window with margin.
        for _ in {1..30}; do
          out=$(${pkgs.systemd}/bin/busctl --system call \
            net.reactivated.Fprint \
            /net/reactivated/Fprint/Manager \
            net.reactivated.Fprint.Manager \
            GetDevices 2>/dev/null) || out=""
          case "$out" in
            *Device*) break ;;
          esac
          sleep 0.3
        done

        ${noctaliaIpc} call lockScreen restartAuth || true
      '';

      # Shared by the static config and the darkModeChange hook so they can't drift.
      hyprThemeCmds = palette: ''
        ${hyprctl} keyword general:col.active_border "rgba(${palette.lavender}ff) rgba(${palette.blue}ff) 45deg"
        ${hyprctl} keyword general:col.inactive_border "rgba(${palette.overlay0}aa)"
        ${hyprctl} keyword decoration:shadow:color "rgba(${palette.crust}ee)"
      '';

      # Letters mirror aerospace; c/h/j/k/l/w belong to other binds.
      wsLetters = lib.stringToCharacters "abdefgimnopqrstuvxyz";
      wsBinds = builtins.concatLists (
        map (k: [
          "$mod, ${k}, workspace, name:${lib.toUpper k}"
          "$mod SHIFT, ${k}, movetoworkspace, name:${lib.toUpper k}"
        ]) wsLetters
      );
      # $mod SHIFT 4/5 are the macOS-style screenshot binds.
      numBinds = builtins.concatLists (
        map (
          n:
          [ "$mod, ${toString n}, workspace, ${toString n}" ]
          ++ lib.optional (n != 4 && n != 5) "$mod SHIFT, ${toString n}, movetoworkspace, ${toString n}"
        ) (lib.range 1 9)
      );

      # Re-seeded from the asset on every activation; runtime changes last until the
      # next switch. Persist them with `noctalia-settings-apply` into the asset.
      noctaliaSettings =
        let
          asset = builtins.fromJSON (builtins.readFile ./assets/noctalia/settings.json);
        in
        (pkgs.formats.json { }).generate "noctalia-settings.json" (
          asset
          // {
            # Merge per field so other hooks in the asset survive.
            hooks = (asset.hooks or { }) // {
              enabled = true;
              # `$1` is substituted before `sh -lc`, so this must be a command, not a path.
              darkModeChange = ''
                if [ "$1" = "true" ]; then
                  ${hyprThemeCmds dark}
                else
                  ${hyprThemeCmds light}
                fi
              '';
              # Feed the greeter a blurred copy; it picks it up on its next start.
              wallpaperChange = ''
                ${pkgs.imagemagick}/bin/magick "$1" -blur 0x16 \
                  /var/lib/regreet/background.png 2>/dev/null || true
              '';
            };
            # noctalia reads these via QML FileView, which doesn't expand `~`.
            wallpaper = (asset.wallpaper or { }) // {
              directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
            };
            general =
              let
                g = asset.general or { };
                expandTilde =
                  v: if lib.hasPrefix "~/" v then "${config.home.homeDirectory}/${lib.removePrefix "~/" v}" else v;
              in
              g // lib.optionalAttrs (g ? avatarImage) { avatarImage = expandTilde g.avatarImage; };
          }
        );

      # Same re-seed-on-activation semantics as settings.json.
      noctaliaPlugins = (pkgs.formats.json { }).generate "noctalia-plugins.json" (
        builtins.fromJSON (builtins.readFile ./assets/noctalia/plugins.json)
      );

      # ipcFilter also unwraps the `state all` envelope.
      stripFilter = "del(.hooks.darkModeChange) | del(.settingsVersion)";
      ipcFilter = ".settings | ${stripFilter}";

    in
    {
      imports = [ inputs.noctalia.homeModules.default ];

      # UWSM owns the session and scopes graphical-session.target to it.
      wayland.systemd.target = "graphical-session.target";

      wayland.windowManager.hyprland = {
        enable = true;
        xwayland.enable = true;
        # Must be false under UWSM; HM's session target conflicts with it.
        systemd.enable = false;
        # HM now defaults to Lua, which Hyprland 0.54 silently ignores.
        configType = "hyprlang";

        # hyprbars, hyprgrass and hypr-dynamic-cursors don't build against nixpkgs'
        # Hyprland 0.55; re-enable once the packaged plugins catch up.
        plugins = with pkgs.hyprlandPlugins; [
          # hypr-dynamic-cursors
        ];

        settings = {
          # Per-host rules prepend via mkBefore (displays-* modules); this catch-all stays last.
          monitor = lib.mkAfter [
            ", preferred, auto, 1.25"
          ];

          general = {
            # noctalia's recommended values; blurred panels look cramped otherwise.
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
            "col.active_border" = "rgba(${c.lavender}ff) rgba(${c.blue}ff) 45deg";
            "col.inactive_border" = "rgba(${c.overlay0}aa)";
            layout = "dwindle";
            allow_tearing = false;
          };

          decoration = {
            rounding = 20;
            rounding_power = 2;
            blur = {
              enabled = true;
              size = 3;
              passes = 2;
              vibrancy = 0.1696;
              new_optimizations = true;
            };
            shadow = {
              enabled = true;
              range = 4;
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
              # Finger-count clicks so a resting palm can't right/middle-click.
              clickfinger_behavior = true;
              # Palm rejection without giving up tap-to-click.
              "tap-and-drag" = false;
              drag_lock = false;
              middle_button_emulation = false;
            };
          };

          gesture = [
            "3, horizontal, workspace"
          ];

          misc = {
            force_default_wallpaper = 0;
            disable_hyprland_logo = true;
            focus_on_activate = true;
            # noctalia's power buttons kill the lock client before Hyprland exits; a long
            # delay keeps the "lockdead" screen from flashing during logout/reboot.
            lockdead_screen_delay = 5000;
            # Let a relaunched lock client reattach after a crash instead of hard-locking.
            allow_session_lock_restore = true;
          };

          ecosystem = {
            no_update_news = true;
          };

          # Apps go through uwsm-app so each gets its own scope in app.slice
          # (https://wiki.hypr.land/Useful-Utilities/Systemd-start/).
          exec-once = [
            # Upstream deprecated noctalia's systemd startup.
            "uwsm-app -- noctalia-shell"

            "uwsm-app -- 1password --silent"
          ];

          # External-monitor pins live in the displays-* modules.
          workspace = [
            "name:T, monitor:eDP-1"
            "name:S, monitor:eDP-1"
            "name:Z, monitor:eDP-1"
            "name:D"
            "name:N"
            "name:O"
            "name:G"
            "name:M"
          ];

          "$mod" = "ALT";
          "$ipc" = "${noctaliaIpc} call";

          bind = [
            "$mod, h, movefocus, l"
            "$mod, j, movefocus, d"
            "$mod, k, movefocus, u"
            "$mod, l, movefocus, r"

            "$mod SHIFT, h, movewindow, l"
            "$mod SHIFT, j, movewindow, d"
            "$mod SHIFT, k, movewindow, u"
            "$mod SHIFT, l, movewindow, r"

            # Hyprland 0.54 removed the `togglesplit` dispatcher.
            "$mod, slash, layoutmsg, togglesplit"
            "$mod, comma, exec, hyprctl keyword general:layout $(hyprctl getoption general:layout -j | jq -r 'if .str == \"dwindle\" then \"master\" else \"dwindle\" end')"

            "$mod, Tab, workspace, previous"
            "$mod SHIFT, Tab, movecurrentworkspacetomonitor, +1"

            # Alt+Space stays on vicinae for its dmenu mode.
            "$mod, Return, exec, uwsm-app -- kitty"
            "SUPER, Space, exec, $ipc launcher toggle"
            "$mod, Space, exec, vicinae toggle"

            "SUPER, d, exec, $ipc darkMode toggle"

            "SUPER, r, exec, ${hyprReload}"

            "$mod CTRL, q, exec, $ipc lockScreen lock"
            "SUPER, l, exec, $ipc lockScreen lock"

            ", Print, exec, $ipc plugin:screen-shot-and-record screenshot"
            "SHIFT, Print, exec, $ipc plugin:screen-shot-and-record ocr"

            # Mirrors macOS Cmd+Shift+4/5; CTRL copies to the clipboard.
            "$mod SHIFT, 4, exec, screenshot region file"
            "$mod SHIFT CTRL, 4, exec, screenshot region clipboard"
            "$mod SHIFT, 5, exec, screenshot screen file"
            "$mod SHIFT CTRL, 5, exec, screenshot screen clipboard"

            "$mod SHIFT, e, exec, $ipc sessionMenu toggle"
            "$mod, c, exec, $ipc launcher clipboard"

            # alt-c is the clipboard.
            "$mod, w, killactive"

            "$mod SHIFT, semicolon, submap, service"
            "$mod SHIFT, slash, submap, join"

            "$mod, 0, workspace, name:0"
            "$mod SHIFT, 0, movetoworkspace, name:0"
          ]
          ++ wsBinds
          ++ numBinds;

          # bindl also fires while locked.
          bindl = [
            ", XF86AudioMute, exec, $ipc volume muteOutput"
            ", XF86AudioMicMute, exec, $ipc volume muteInput"
          ];

          # On release, so chords like Super+L don't also open the launcher.
          bindr = [
            "SUPER, SUPER_L, exec, $ipc launcher toggle"
          ];

          binde = [
            "$mod SHIFT, minus, resizeactive, -50 0"
            "$mod SHIFT, equal, resizeactive, 50 0"
            ", XF86AudioRaiseVolume, exec, $ipc volume increase"
            ", XF86AudioLowerVolume, exec, $ipc volume decrease"
            ", XF86MonBrightnessUp, exec, $ipc brightness increase"
            ", XF86MonBrightnessDown, exec, $ipc brightness decrease"
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
          # kept for an easy switch back to firefox-devedition
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

          # -- Noctalia layer rules --
          # Blur the bar/panel/launcher backgrounds. Block syntax — fields
          # use underscores (per the Layer Rules table in the Hyprland wiki)
          # and `match:namespace` selects the noctalia surfaces.
          layerrule {
            name = noctalia
            match:namespace = noctalia-background-.*$
            ignore_alpha = 0.5
            blur = true
            blur_popups = true
          }

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

      # Started from exec-once; upstream deprecated its systemd unit.
      programs.noctalia-shell.enable = true;

      home.activation.noctaliaSettingsBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="$HOME/.config/noctalia/settings.json"
        $DRY_RUN_CMD mkdir -p "$(dirname "$cfg")"
        # Always replace — settings.json is treated as ephemeral.
        # Asset is the source of truth; runtime mutations live until
        # the next nixos-rebuild switch or reboot. To persist a
        # runtime change, capture it via `noctalia-settings-dump`,
        # edit the asset, commit, rebuild.
        $DRY_RUN_CMD rm -f "$cfg"
        $DRY_RUN_CMD install -m 644 ${noctaliaSettings} "$cfg"
      '';

      home.activation.noctaliaPluginsBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="$HOME/.config/noctalia/plugins.json"
        $DRY_RUN_CMD mkdir -p "$(dirname "$cfg")"
        $DRY_RUN_CMD rm -f "$cfg"
        $DRY_RUN_CMD install -m 644 ${noctaliaPlugins} "$cfg"
      '';

      # So the wallpaper picker doesn't report a missing directory on fresh installs.
      home.activation.makeWallpapersDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p $HOME/Pictures/Wallpapers
      '';

      # Keep the greeter background current on first boot (before noctalia's hook has
      # fired) and when the wallpaper changes outside noctalia.
      home.activation.seedGreeterBackground = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        src="$HOME/Pictures/Wallpapers/wallpaper-dark.png"
        dst="/var/lib/regreet/background.png"
        if [ -f "$src" ] && [ -w "$dst" ]; then
          $DRY_RUN_CMD ${pkgs.imagemagick}/bin/magick "$src" -blur 0x16 "$dst" 2>/dev/null || true
        fi
      '';

      programs.ghostty.enable = true;

      # Kept for its dmenu mode; noctalia is the primary launcher.
      programs.vicinae = {
        enable = true;
        useLayerShell = true;
        systemd.enable = true;
        systemd.target = "graphical-session.target";
      };

      # No hyprpolkitagent: noctalia's polkit-agent plugin (plugins.json) handles auth.

      # Profiles come from the per-host displays-* modules.
      services.kanshi = {
        enable = true;
        systemdTarget = "graphical-session.target";
      };

      # hypridle owns idle + sleep (noctalia's are off) for its sleep inhibitor:
      # locking mid-s2idle triggers an xe GT0 timeout that breaks rendering on resume.
      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "${noctaliaIpc} call lockScreen lock";
            before_sleep_cmd = "${noctaliaIpc} call lockScreen lock";
            after_sleep_cmd = "${afterSleepHook}";
            inhibit_sleep = 3;
          };
          listener = [
            {
              timeout = 300;
              on-timeout = "${noctaliaIpc} call lockScreen lock";
            }
            {
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

      # The GTK theme stays Mocha; light/dark flips via the dconf color-scheme,
      # which noctalia keeps in sync.
      gtk = {
        enable = true;
        theme = {
          name = theme.gtk.themeName;
          package = pkgs.catppuccin-gtk.override {
            accents = [ theme.gtk.accent ];
            variant = theme.gtk.variant;
          };
        };
        iconTheme = {
          name = theme.gtk.iconThemeName;
          package = pkgs.papirus-icon-theme;
        };
        font = {
          name = theme.gtk.fontName;
          size = theme.gtk.fontSize;
          package = pkgs.open-sans;
        };
        gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
        gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
      };

      qt = {
        enable = true;
        platformTheme.name = "gtk3";
        style.name = "adwaita-dark";
      };

      home.pointerCursor = {
        enable = true;
        gtk.enable = true;
        name = theme.gtk.cursorName;
        package = pkgs.catppuccin-cursors.mochaDark;
        size = 24;
      };

      home.packages = with pkgs; [
        # Latte for manual use; the dark-mode hook doesn't swap GTK themes.
        (catppuccin-gtk.override {
          accents = [ theme.gtk.accent ];
          variant = "latte";
        })

        # Tools noctalia's screen-shot-and-record plugin shells out to.
        grim
        slurp
        swappy
        tesseract
        wf-recorder

        # notify-send for noctalia plugin toasts.
        libnotify

        # Opened from noctalia's control-center panels.
        pwvucontrol
        overskride

        # Manual use only: the session menu uses a bare `hyprctl dispatch exit`
        # because hyprshutdown hangs when an app ignores the close event.
        hyprshutdown

        # `diff` compares the store copy (not ~/.config, which noctalia rewrites) with
        # live state; `dump`/`apply` print live state to paste into the asset.
        (writeShellScriptBin "noctalia-settings-dump" ''
          set -eu
          # `-S` sorts keys so successive dumps produce diff-stable
          # output regardless of noctalia's internal emission order.
          ${noctaliaIpc} call state all | ${pkgs.jq}/bin/jq -S '${ipcFilter}'
        '')
        # Like dump, but rewrites absolute paths back to the asset's `~/` form.
        (writeShellScriptBin "noctalia-settings-apply" ''
          set -eu
          ${noctaliaIpc} call state all \
            | ${pkgs.jq}/bin/jq -S '${ipcFilter}
                | .wallpaper.directory |= sub("^"+env.HOME+"/"; "~/")
                | if .general.avatarImage? then
                    .general.avatarImage |= sub("^"+env.HOME+"/"; "~/")
                  else . end'
        '')
        (writeShellScriptBin "noctalia-settings-diff" ''
          set -eu
          # Compare the Nix-store derivation (asset + Nix-side overlays)
          # against the live IPC state — NOT $HOME/.config/noctalia/settings.json,
          # which noctalia mutates at runtime and would always match IPC.
          ${pkgs.diffutils}/bin/diff -u --label declarative --label runtime \
            <(${pkgs.jq}/bin/jq -S '${stripFilter}' "${noctaliaSettings}") \
            <(${noctaliaIpc} call state all | ${pkgs.jq}/bin/jq -S '${ipcFilter}') \
            || true
        '')

        # plugins.json has no IPC accessor; the file itself is the runtime state.
        (writeShellScriptBin "noctalia-plugins-dump" ''
          set -eu
          ${pkgs.jq}/bin/jq -S '.' "$HOME/.config/noctalia/plugins.json"
        '')
        (writeShellScriptBin "noctalia-plugins-diff" ''
          set -eu
          ${pkgs.diffutils}/bin/diff -u --label asset --label runtime \
            <(${pkgs.jq}/bin/jq -S '.' "${./assets/noctalia/plugins.json}") \
            <(${pkgs.jq}/bin/jq -S '.' "$HOME/.config/noctalia/plugins.json") \
            || true
        '')

        # `screen` captures only the focused output; bare grim stitches every output.
        (writeShellScriptBin "screenshot" ''
          set -eu
          mode=''${1:-region}
          target=''${2:-clipboard}

          case "$mode" in
            region)
              geom=$(${pkgs.slurp}/bin/slurp) || exit 0
              args=(-g "$geom")
              ;;
            screen)
              output=$(${config.wayland.windowManager.hyprland.package}/bin/hyprctl monitors -j \
                | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')
              args=(-o "$output")
              ;;
            *) echo "usage: screenshot {region|screen} {file|clipboard}" >&2; exit 2 ;;
          esac

          case "$target" in
            clipboard)
              ${pkgs.grim}/bin/grim "''${args[@]}" - \
                | ${pkgs.wl-clipboard-rs}/bin/wl-copy --type image/png
              ${pkgs.libnotify}/bin/notify-send -a Screenshot \
                "Screenshot copied" "$mode → clipboard"
              ;;
            file)
              dir="$HOME/Pictures/Screenshots"
              mkdir -p "$dir"
              dest="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
              ${pkgs.grim}/bin/grim "''${args[@]}" "$dest"
              ${pkgs.libnotify}/bin/notify-send -a Screenshot \
                "Screenshot saved" "$dest"
              ;;
            *) echo "usage: screenshot {region|screen} {file|clipboard}" >&2; exit 2 ;;
          esac
        '')

        # For VPN/802.1x, which noctalia's panel doesn't cover.
        networkmanagerapplet
        wdisplays
      ];

      # argv.json is owned by VS Code and conflicts with HM.
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
        mimeType = [
          "x-scheme-handler/sgnl"
          "x-scheme-handler/signalcaptcha"
        ];
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
        mimeType = [ "x-scheme-handler/slack" ];
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

      home.sessionVariables = {
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        NIXOS_OZONE_WL = "1";
        QT_QPA_PLATFORM = "wayland;xcb";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        GDK_BACKEND = "wayland,x11";
        CLUTTER_BACKEND = "wayland";
        SDL_VIDEODRIVER = "wayland";
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_DESKTOP = "Hyprland";
      };

      # greetd execs UWSM without a login shell, so HM's session vars never load;
      # UWSM sources this before starting the compositor.
      xdg.configFile."uwsm/env".text = ''
        source ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh
      '';

      xdg.mime.enable = true;

      # HM's hyprland module pins NIX_XDG_DESKTOP_PORTAL_DIR to the user profile,
      # which then lacks the gtk portal that provides Settings (color-scheme).
      xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

      # Must be named hyprland-portals.conf: the system copy would otherwise shadow
      # a generic portals.conf and drop the Settings backend.
      xdg.configFile."xdg-desktop-portal/hyprland-portals.conf".text = ''
        [preferred]
        default=gtk
        org.freedesktop.impl.portal.Settings=gtk
        org.freedesktop.impl.portal.Screenshot=hyprland
        org.freedesktop.impl.portal.ScreenCast=hyprland
        org.freedesktop.impl.portal.GlobalShortcuts=hyprland
      '';

      # Initial value; noctalia keeps it in sync at runtime.
      dconf.settings."org/freedesktop/appearance" = {
        color-scheme = 1; # 0=default, 1=dark, 2=light
      };
    };
}
