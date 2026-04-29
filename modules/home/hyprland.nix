_: {
  flake.homeModules.hyprland =
    # Hyprland home-manager configuration — compositor settings, keybindings,
    # kanshi for monitor management, and noctalia-shell for the desktop shell
    # (bar, notifications, launcher, lock, idle, OSD, wallpaper, night-light).
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      # Catppuccin Mocha (dark) — used for hyprland borders + shadow.
      # Noctalia handles the rest of the theme via its built-in Catppuccin
      # color scheme (predefinedScheme = "Catppuccin"), which already covers
      # the bar, panels, lock screen, OSD, and notifications. dconf + GTK
      # theme name are still tracked in lockstep via the noctalia darkMode
      # hook below so Mocha (dark) ↔ Latte (light) swaps stay in sync.
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
      c = dark;

      noctaliaBin = lib.getExe inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";

      # noctalia-shell IPC invocation. The default config-path discovery
      # hits a quickshell upstream bug (returns "No running instances"
      # even on exact match), so we pass `--pid` explicitly. Two quirks
      # to work around:
      #
      #   1. The nixpkgs wrapper sets `QS_CONFIG_PATH` by default, which
      #      noctalia-shell's ipc CLI picks up as an implicit
      #      `--config-path` and then rejects because `--pid` and
      #      `--config-path` are mutually exclusive. Exporting the var
      #      as empty (but defined) suppresses the wrapper's set-default.
      #
      #   2. The nixpkgs wrapper chain renames the running binary to
      #      `.quickshell-wrapped`, so `pgrep -x quickshell` finds
      #      nothing — match cmdline endings against `*/bin/quickshell`.
      #
      # Invoked by hypridle (which execs commands directly, no shell);
      # the writeShellScript gives us the shell context needed for both
      # the env override and the pid lookup.
      noctaliaIpc = pkgs.writeShellScript "noctalia-ipc" ''
        export QS_CONFIG_PATH=
        exec noctalia-shell ipc --pid "$(pgrep -fxo '.*/bin/quickshell')" "$@"
      '';

      # Catppuccin border / shadow values per palette. Used by the static
      # `general/decoration` blocks below and by the `darkModeChange` hook
      # so a runtime toggle swaps the same fields the eval-time defaults
      # set, with no drift between them.
      hyprThemeCmds = palette: ''
        ${hyprctl} keyword general:col.active_border "rgba(${palette.lavender}ff) rgba(${palette.blue}ff) 45deg"
        ${hyprctl} keyword general:col.inactive_border "rgba(${palette.overlay0}aa)"
        ${hyprctl} keyword decoration:shadow:color "rgba(${palette.crust}ee)"
      '';

      # Letters bound to named workspaces (matching aerospace 1:1). Skipped:
      # c (reserved for clipboard), h/j/k/l (movefocus), w (killactive).
      wsLetters = lib.stringToCharacters "abdefgimnopqrstuvxyz";
      wsBinds = builtins.concatLists (
        map (k: [
          "$mod, ${k}, workspace, name:${lib.toUpper k}"
          "$mod SHIFT, ${k}, movetoworkspace, name:${lib.toUpper k}"
        ]) wsLetters
      );
      # 4 and 5 skip the SHIFT variant — those are reclaimed by the
      # macOS-style screenshot bindings below ($mod SHIFT 4 = region,
      # $mod SHIFT 5 = full).
      numBinds = builtins.concatLists (
        map (
          n:
          [ "$mod, ${toString n}, workspace, ${toString n}" ]
          ++ lib.optional (n != 4 && n != 5) "$mod SHIFT, ${toString n}, movetoworkspace, ${toString n}"
        ) (lib.range 1 9)
      );

      # Bootstrap template for ~/.config/noctalia/settings.json. Source of
      # truth is `./assets/noctalia/settings.json` — refresh it from the
      # running shell with `jq 'del(.hooks.darkModeChange) | del(.settingsVersion)'
      # ~/.config/noctalia/settings.json > modules/home/assets/noctalia/settings.json`.
      # We re-inject `hooks.darkModeChange` here so the rendered hook tracks
      # current store paths.
      #
      # Why a writable copy and not `programs.noctalia-shell.settings`: the
      # latter symlinks to /nix/store, which causes runtime toggles like
      # darkMode to flash and revert — noctalia writes a fresh colors.json on
      # toggle, the parent-dir watcher in Commons/Settings.qml fires, and the
      # next reload restores the symlinked settings.json over the in-memory
      # toggle. Nix updates apply on fresh installs only; to refresh after
      # rebuilds, `rm ~/.config/noctalia/settings.json && home-manager switch`.
      #
      # OS dark/light propagation: `colorSchemes.syncGsettings = true` runs
      # `gtk-refresh.py --appearance-only` which `gsettings set`s
      # org.gnome.desktop.interface/color-scheme. xdg-desktop-portal-gtk
      # watches that and emits the freedesktop appearance SettingChanged
      # signal that kitty / Zed / Electron subscribe to. The hook only owns
      # hyprland border colors (no portal involvement).
      noctaliaSettings = (pkgs.formats.json { }).generate "noctalia-settings.json" (
        (builtins.fromJSON (builtins.readFile ./assets/noctalia/settings.json))
        // {
          hooks = {
            enabled = true;
            # `$1` is text-substituted with "true"/"false" before `sh -lc`
            # — must be a shell command string, not a script path.
            darkModeChange = ''
              if [ "$1" = "true" ]; then
                ${hyprThemeCmds dark}
              else
                ${hyprThemeCmds light}
              fi
            '';
          };
        }
      );

    in
    {
      imports = [ inputs.noctalia.homeModules.default ];

      # Scope HM Wayland services (kanshi, ...) to hyprland-session.target so
      # they only start under Hyprland. Default binds to graphical-session.target,
      # which any Wayland session satisfies.
      wayland.systemd.target = "hyprland-session.target";

      wayland.windowManager.hyprland = {
        enable = true;
        xwayland.enable = true;
        systemd.enable = true;

        # hyprbars and hyprgrass are intentionally NOT here: nixpkgs's
        # hyprland-plugins lag the bundled hyprland API, so both fail to
        # compile (SCallbackInfo / m_lastMonitor mismatches). The proper
        # fix is to switch hyprland to the upstream flake input where
        # plugins ship in lockstep with the compositor.
        plugins = with pkgs.hyprlandPlugins; [
          hypr-dynamic-cursors
        ];

        settings = {
          # -- Monitors --
          # Per-host eDP-1 + external rules live in separate overlay
          # modules (hyprland-host-<name> or displays-<hardware>-<loc>)
          # and prepend via `lib.mkBefore`. This catch-all is the
          # fallback for any monitor not covered by such a rule and
          # always sorts last via `lib.mkAfter`.
          monitor = lib.mkAfter [
            ", preferred, auto, 1.5"
          ];

          general = {
            # noctalia's recommended values — wider gaps + larger rounding
            # make blurred panels look intentional rather than cramped.
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
              # Finger-count clicks instead of zone clicks — palm-on-corner
              # stops triggering left/middle/right. 1 finger = left, 2 =
              # right, 3 = middle.
              clickfinger_behavior = true;
              # Palm-rejection without disabling tap-to-click: stray palm
              # taps can't initiate a drag, drags don't latch after the
              # finger lifts, and simultaneous palm+finger contact no
              # longer fabricates a middle-click.
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
          };

          ecosystem = {
            no_update_news = true;
          };

          # -- Startup --
          exec-once = [
            "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
            # 1Password tray-only; kitty lands on workspace T via the
            # match:class kitty rule.
            "1password --silent"
            "kitty"
            "noctalia-shell"
          ];

          # -- Named workspaces with monitor pinning --
          # Workspaces pinned to specific external monitors live in the
          # overlay module for that hardware+location (e.g.
          # displays-5570-home); this list keeps only eDP-1 pins (every
          # host has a laptop panel) and the unpinned workspaces.
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

          # -- Keybindings --
          "$mod" = "ALT";
          "$ipc" = "${noctaliaBin} ipc call";

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

            # Launch — Super+Space mirrors GNOME; Alt+Space stays on
            # vicinae (kept for its dmenu mode used by ad-hoc scripts).
            "$mod, Return, exec, kitty"
            "SUPER, Space, exec, $ipc launcher toggle"
            "$mod, Space, exec, vicinae toggle"

            # Dark/light mode toggle — fires the darkModeChange hook.
            "SUPER, d, exec, $ipc darkMode toggle"

            # Lock screen
            "$mod CTRL, q, exec, $ipc lockScreen lock"
            "SUPER, l, exec, $ipc lockScreen lock"

            # Screenshots via noctalia screen-shot-and-record plugin: opens
            # an overlay where you pick area / window / screen and copy /
            # save / edit. SHIFT+Print swaps to OCR (image → text).
            ", Print, exec, $ipc plugin:screen-shot-and-record screenshot"
            "SHIFT, Print, exec, $ipc plugin:screen-shot-and-record ocr"

            # macOS-style direct capture (no overlay UI). $mod is ALT, so
            # alt-shift-4 / alt-shift-5 mirror Cmd+Shift+4 / Cmd+Shift+5 with
            # CTRL toggling clipboard mode (matches macOS Cmd+Shift+Ctrl+4).
            "$mod SHIFT, 4, exec, screenshot region file"
            "$mod SHIFT CTRL, 4, exec, screenshot region clipboard"
            "$mod SHIFT, 5, exec, screenshot screen file"
            "$mod SHIFT CTRL, 5, exec, screenshot screen clipboard"

            # Power / clipboard menus
            "$mod SHIFT, e, exec, $ipc sessionMenu toggle"
            "$mod, c, exec, $ipc launcher clipboard"

            # Kill active window (alt-w; alt-c reserved for clipboard).
            "$mod, w, killactive"

            # Submaps (alt-shift-semicolon = service, alt-shift-slash = join)
            "$mod SHIFT, semicolon, submap, service"
            "$mod SHIFT, slash, submap, join"

            # Workspace 0 is named "0"; 1–9 use Hyprland's numeric id.
            "$mod, 0, workspace, name:0"
            "$mod SHIFT, 0, movetoworkspace, name:0"
          ]
          # Named-letter workspaces (alt-{letter}, alt-shift-{letter}).
          ++ wsBinds
          # Numeric workspaces 1–9 (alt-{n}, alt-shift-{n}).
          ++ numBinds;

          # Audio and media via noctalia IPC. bindl = work while locked,
          # bindel = repeat on hold.
          bindl = [
            ", XF86AudioMute, exec, $ipc volume muteOutput"
            ", XF86AudioMicMute, exec, $ipc volume muteInput"
          ];

          # Tap-Super-alone opens the launcher, GNOME-style. bindr fires
          # on key release so chords like Super+L (lock) don't also pop
          # the launcher when the chord ends.
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

      # -- Noctalia shell --
      # Launched via hyprland's exec-once above; upstream deprecated systemd
      # startup over IPC / start-order issues. See `noctaliaSettings` (let
      # block) for why settings.json is bootstrapped instead of symlinked.
      programs.noctalia-shell.enable = true;

      home.activation.noctaliaSettingsBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="$HOME/.config/noctalia/settings.json"
        $DRY_RUN_CMD mkdir -p "$(dirname "$cfg")"
        # Replace if missing, or if it's still a read-only symlink from a
        # previous build that used `programs.noctalia-shell.settings`.
        # Do not overwrite an existing regular file — that's where noctalia
        # persists runtime mutations (darkMode toggles, wallpaper picks).
        if [ ! -e "$cfg" ] || [ -L "$cfg" ]; then
          $DRY_RUN_CMD rm -f "$cfg"
          $DRY_RUN_CMD install -m 644 ${noctaliaSettings} "$cfg"
        fi
      '';

      programs.ghostty.enable = true;

      # Vicinae kept alongside noctalia for its dmenu mode (used by ad-hoc
      # scripts) and as a fallback launcher. noctalia handles the primary
      # launcher / clipboard / session-menu keybinds.
      programs.vicinae = {
        enable = true;
        useLayerShell = true;
        systemd.enable = true;
        systemd.target = "hyprland-session.target";
      };

      # -- Kanshi (monitor management, wlroots protocol) --
      # Outside noctalia's scope (compositor-level). Profiles (eDP-1
      # mode + external monitors) are declared in the overlay module
      # enrolled by each host (hyprland-host-<name> or
      # displays-<hardware>-<loc>).
      services.kanshi = {
        enable = true;
        systemdTarget = "hyprland-session.target";
      };

      # -- Hypridle: single coordinator for idle + sleep hooks --
      # Noctalia's built-in idle watcher (`idle.enabled`) and
      # `lockOnSuspend` are disabled in settings.json; hypridle owns
      # both paths here for consistency and — more importantly — gives
      # us a logind sleep-inhibitor (`inhibit_sleep = 3`) that delays
      # `sleep.target` until `before_sleep_cmd` returns. Without the
      # inhibitor the lock-screen quickshell is mid-draw when the GPU
      # starts quiescing for s2idle, which reproduces an xe KMD GT0
      # Timedout job that leaves the compositor with a broken render
      # state on resume.
      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "${noctaliaIpc} call lockScreen lock";
            before_sleep_cmd = "${noctaliaIpc} call lockScreen lock";
            # Re-arm noctalia's PAM session after resume. fprintd is
            # stopped before s2idle by the system-level Conflicts=sleep.target
            # rule (modules/nixos/hyprland.nix), so this restartAuth runs
            # pam.start() against a freshly auto-launched fprintd.
            after_sleep_cmd = "${noctaliaIpc} call lockScreen restartAuth";
            inhibit_sleep = 3;
          };
          # Idle thresholds ported verbatim from the old noctalia
          # `idle` settings: lock at 5m, screen off at 5m10s, suspend
          # at 15m.
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

      # -- GTK/Qt theming (Catppuccin Mocha) --
      # Theme-name swap is driven by the noctalia darkModeChange hook
      # above (Mocha ↔ Latte). dconf color-scheme is handled by
      # noctalia's `colorSchemes.syncGsettings`.
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
          name = "Open Sans";
          size = 13;
          package = pkgs.open-sans;
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
        # Catppuccin Latte GTK theme used by the darkModeChange hook when
        # switching to light mode.
        (catppuccin-gtk.override {
          accents = [ "blue" ];
          variant = "latte";
        })

        # Screenshot capture / OCR / record tooling. The noctalia
        # screen-shot-and-record plugin shells out to `grim` + `slurp` for
        # capture, `wl-copy` for clipboard, `swappy` as the optional editor,
        # `tesseract` for OCR mode, `wf-recorder` for screen recording, and
        # `notify-send` for toast feedback.
        grim
        slurp
        swappy
        tesseract
        wf-recorder

        # Wayland clipboard tools used by noctalia's built-in clipboard
        # watcher (`appLauncher.clipboardWatchTextCommand`) and ad-hoc
        # scripts. libnotify gives notify-send for the screenshot/recording
        # toasts emitted by the plugin.
        wl-clipboard-rs
        libnotify

        # Audio / Bluetooth GUIs that noctalia surfaces via the bar's
        # "more" buttons (controlCenter audio + bluetooth panels open
        # these). Optional — noctalia's built-in panels are usually enough.
        pwvucontrol
        overskride

        # Direct (no-overlay) screenshot wrapper for the macOS-style
        # alt-shift-4 / alt-shift-5 keybinds. Mode = region|screen,
        # target = file|clipboard. "screen" captures the focused monitor
        # only (vanilla `grim` would concatenate every output, which on
        # multi-monitor setups produces an unusable wide image).
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

        (writeShellScriptBin "sync-wallpaper" ''
          # Sync GNOME wallpaper to noctalia's directory, converting SVG if needed.
          # noctalia picks them up via `wallpaper.directory` + the
          # linkLightAndDarkWallpapers pairing on basename match.
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
          ${noctaliaBin} ipc call wallpaper refresh || true
        '')

        # nm-connection-editor (advanced VPN/Wi-Fi config — noctalia opens
        # the bar's Wi-Fi panel, but for VPN/802.1x you still want this).
        networkmanagerapplet
        # wdisplays for ad-hoc monitor positioning (kanshi profiles cover
        # the routine docked/undocked layouts).
        wdisplays
      ];

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
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_DESKTOP = "Hyprland";
      };

      xdg.mime.enable = true;

      # The HM hyprland module auto-enables `xdg.portal` with only
      # `xdg-desktop-portal-hyprland` in extraPortals, and emits an
      # `~/.config/environment.d/10-home-manager.conf` line that pins
      # `NIX_XDG_DESKTOP_PORTAL_DIR` to the user-profile portal dir. That
      # value wins over the system-level one set by `/etc/set-environment`,
      # so the portal frontend never finds `gtk.portal` even though the
      # NixOS xdg.portal module installs it system-wide. Without the gtk
      # backend, `org.freedesktop.portal.Settings` is missing entirely and
      # noctalia's color-scheme dconf writes never reach kitty / libadwaita
      # subscribers. Re-add gtk here so the user profile aggregates both
      # portals and the env-var-pinned dir contains what the routing
      # config below expects.
      xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

      # Portal routing: gtk portal handles Settings (color-scheme for kitty,
      # Zed, Electron); hyprland portal handles screencasting/screenshots.
      #
      # Filename matters. xdg-desktop-portal-hyprland and the hyprland package
      # both ship `hyprland-portals.conf` system-wide containing only
      # `default=hyprland;gtk`, with no Settings entry. Per portals.conf(5), a
      # desktop-specific file (matched against XDG_CURRENT_DESKTOP) overrides
      # the generic `portals.conf` ENTIRELY — so our old `portals.conf` was
      # silently shadowed, leaving the portal frontend with no Settings
      # backend at all (`Settings.Read` errors with "No such interface"). Use
      # the desktop-specific name so the user-level file takes priority over
      # the system one.
      xdg.configFile."xdg-desktop-portal/hyprland-portals.conf".text = ''
        [preferred]
        default=gtk
        org.freedesktop.impl.portal.Settings=gtk
        org.freedesktop.impl.portal.Screenshot=hyprland
        org.freedesktop.impl.portal.ScreenCast=hyprland
        org.freedesktop.impl.portal.GlobalShortcuts=hyprland
      '';

      # Initial dark color scheme for portal-Settings consumers (Zed,
      # Electron, etc.). noctalia keeps this in sync at runtime via
      # `colorSchemes.syncGsettings = true`.
      dconf.settings."org/freedesktop/appearance" = {
        color-scheme = 1; # 0=default, 1=dark, 2=light
      };
    };
}
