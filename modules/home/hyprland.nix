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

      hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
      toLua = lib.generators.toLua { multiline = false; };

      # Under the Lua config, `hyprctl dispatch X` evaluates `hl.dispatch(X)`.
      hyprDispatch = expr: "${hyprctl} dispatch ${lib.escapeShellArg expr}";
      dpms = action: hyprDispatch ''hl.dsp.dpms({ action = "${action}" })'';

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

      # Before sleep: DPMS on so the panel suspends lit. Idle-suspending with DPMS
      # already off (lock 300s, dpms off 310s, suspend 900s) resumes to a black
      # screen that `dpms on` can't recover; lid suspends with it on are fine.
      beforeSleepHook = pkgs.writeShellScript "noctalia-before-sleep" ''
        ${dpms "on"} || true
        exec ${noctaliaIpc} call lockScreen lock
      '';

      # After resume: DPMS on first so the lock screen is visible, then wait for the
      # Goodix reader (the kernel re-enumerates it 3-8s after PrepareForSleep), then
      # re-arm fingerprint auth. Best-effort so a failure can't strand the lock.
      afterSleepHook = pkgs.writeShellScript "noctalia-after-sleep" ''
        ${dpms "on"} || true

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
      hyprTheme = palette: {
        general.col = {
          active_border = {
            colors = [
              "rgba(${palette.lavender}ff)"
              "rgba(${palette.blue}ff)"
            ];
            angle = 45;
          };
          inactive_border = "rgba(${palette.overlay0}aa)";
        };
        decoration.shadow.color = "rgba(${palette.crust}ee)";
      };
      # `hyprctl keyword` is gone under the Lua config; eval an hl.config call instead.
      hyprThemeCmd = palette: ''
        ${hyprctl} eval ${lib.escapeShellArg "hl.config(${toLua (hyprTheme palette)})"}
      '';

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
              darkModeChange = /* bash */ ''
                if [ "$1" = "true" ]; then
                  ${hyprThemeCmd dark}
                else
                  ${hyprThemeCmd light}
                fi
              '';
              # Feed the greeter a blurred copy; it picks it up on its next start.
              wallpaperChange = /* bash */ ''
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

        # hyprbars, hyprgrass and hypr-dynamic-cursors don't build against nixpkgs'
        # Hyprland 0.55; re-enable once the packaged plugins catch up.
        plugins = with pkgs.hyprlandPlugins; [
          # hypr-dynamic-cursors
        ];

        # Each attribute renders as `hl.<name>(...)`; lists render one call per element.
        settings = {
          # Per-host rules prepend via mkBefore (displays-* modules); this catch-all stays last.
          monitor = lib.mkAfter [
            {
              output = "";
              mode = "preferred";
              position = "auto";
              scale = 1.25;
            }
          ];

          config = lib.recursiveUpdate (hyprTheme dark) {
            general = {
              # noctalia's recommended values; blurred panels look cramped otherwise.
              gaps_in = 5;
              gaps_out = 10;
              border_size = 2;
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
              };
              active_opacity = 1.0;
              inactive_opacity = 0.98;
            };

            animations.enabled = true;

            dwindle.preserve_split = true;

            master.new_status = "master";

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
                tap_and_drag = false;
                drag_lock = false;
                middle_button_emulation = false;
              };
            };

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

            ecosystem.no_update_news = true;
          };

          # HM renders `curve` ahead of `animation` (importantPrefixes).
          curve =
            let
              bezier = name: x1: y1: x2: y2: {
                _args = [
                  name
                  {
                    type = "bezier";
                    points = [
                      [
                        x1
                        y1
                      ]
                      [
                        x2
                        y2
                      ]
                    ];
                  }
                ];
              };
            in
            [
              (bezier "easeOutQuint" 0.23 1 0.32 1)
              (bezier "easeInOutCubic" 0.65 0.05 0.35 0.95)
              (bezier "linear" 0 0 1 1)
              (bezier "almostLinear" 0.5 0.5 0.75 1.0)
              (bezier "quick" 0.15 0 0.1 1)
            ];

          animation = map (a: a // { enabled = true; }) [
            {
              leaf = "global";
              speed = 10;
              bezier = "default";
            }
            {
              leaf = "border";
              speed = 5.39;
              bezier = "easeOutQuint";
            }
            {
              leaf = "windows";
              speed = 4.79;
              bezier = "easeOutQuint";
            }
            {
              leaf = "windowsIn";
              speed = 4.1;
              bezier = "easeOutQuint";
              style = "popin 87%";
            }
            {
              leaf = "windowsOut";
              speed = 1.49;
              bezier = "linear";
              style = "popin 87%";
            }
            {
              leaf = "fadeIn";
              speed = 1.73;
              bezier = "almostLinear";
            }
            {
              leaf = "fadeOut";
              speed = 1.46;
              bezier = "almostLinear";
            }
            {
              leaf = "fade";
              speed = 3.03;
              bezier = "quick";
            }
            {
              leaf = "layers";
              speed = 3.81;
              bezier = "easeOutQuint";
            }
            {
              leaf = "workspaces";
              speed = 1.94;
              bezier = "almostLinear";
              style = "fade";
            }
          ];

          gesture = {
            fingers = 3;
            direction = "horizontal";
            action = "workspace";
          };

          # External-monitor pins live in the displays-* modules.
          workspace_rule = [
            {
              workspace = "name:T";
              monitor = "eDP-1";
            }
            {
              workspace = "name:S";
              monitor = "eDP-1";
            }
            {
              workspace = "name:Z";
              monitor = "eDP-1";
            }
            { workspace = "name:D"; }
            { workspace = "name:N"; }
            { workspace = "name:O"; }
            { workspace = "name:G"; }
            { workspace = "name:M"; }
          ];

          window_rule =
            lib.concatLists (
              lib.mapAttrsToList
                (
                  ws: classes:
                  map (class: {
                    match.class = class;
                    workspace = "name:${ws}";
                  }) classes
                )
                {
                  # Terminals
                  T = [
                    "kitty"
                    "org.alacritty"
                    "ghostty"
                    "com.mitchellh.ghostty"
                  ];
                  # Browsers; firefox-devedition kept for an easy switch back.
                  B = [
                    "brave-browser"
                    "firefox"
                    "firefox-devedition"
                    "chromium-browser"
                  ];
                  # Editors
                  V = [
                    "code"
                    "code-url-handler"
                    "dev.zed.Zed"
                  ];
                  # IDEs
                  I = [
                    "jetbrains-idea"
                    "jetbrains-pycharm"
                    "jetbrains-datagrip"
                  ];
                  # Social / messaging
                  S = [
                    "Slack"
                    "signal"
                    "discord"
                  ];
                  # Video calls
                  Z = [ "zoom" ];
                  # Notes
                  N = [ "obsidian" ];
                  # Email / calendar
                  O = [ "thunderbird" ];
                  # Files
                  F = [ "org.gnome.Nautilus" ];
                  D = [ "docker-desktop" ];
                }
            )
            # Float transient windows.
            ++ [
              {
                match = {
                  class = "1Password";
                  title = "Quick.Access";
                };
                float = true;
              }
              {
                match.class = "nm-connection-editor";
                float = true;
              }
              {
                match.class = "com.saivert.pwvucontrol";
                float = true;
                size = "800 600";
              }
              {
                match.class = "io.github.kaii_lb.Overskride";
                float = true;
                size = "600 500";
              }
              {
                match.title = "Picture-in-Picture";
                float = true;
              }
            ];

          # Blur the noctalia bar/panel/launcher backgrounds.
          layer_rule = {
            name = "noctalia";
            match.namespace = "noctalia-background-.*$";
            ignore_alpha = 0.5;
            blur = true;
            blur_popups = true;
          };
        };

        extraConfig = /* lua */ ''
          local mod = "ALT"
          local ipc = ${toLua "${noctaliaIpc} call"}
          local hypr_reload = ${toLua "${hyprReload}"}

          local exec = hl.dsp.exec_cmd
          local dirs = { left = "h", down = "j", up = "k", right = "l" }

          local function noctalia(args)
            return exec(ipc .. " " .. args)
          end

          -- Windows on the focused workspace.
          local function workspace_windows()
            local ws = hl.get_active_workspace()
            if not ws then
              return {}
            end
            return hl.get_workspace_windows(ws)
          end

          -- Replaces the removed `workspaceopt allfloat`: float everything, or
          -- tile everything if it's all floating already.
          local function toggle_workspace_float()
            local wins = workspace_windows()
            local action = "disable"
            for _, w in ipairs(wins) do
              if not w.floating then
                action = "enable"
                break
              end
            end
            for _, w in ipairs(wins) do
              hl.dispatch(hl.dsp.window.float({ action = action, window = w }))
            end
          end

          -- aerospace's close-all-windows-but-current.
          local function close_other_windows()
            for _, w in ipairs(workspace_windows()) do
              if not w.active then
                hl.dispatch(hl.dsp.window.close({ window = w }))
              end
            end
          end

          for dir, key in pairs(dirs) do
            hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
            hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
          end

          hl.bind(mod .. " + slash", hl.dsp.layout("togglesplit"))
          hl.bind(mod .. " + comma", function()
            local layout = hl.get_config("general.layout")
            hl.config({ general = { layout = layout == "dwindle" and "master" or "dwindle" } })
          end)

          hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))
          hl.bind(mod .. " + SHIFT + Tab", hl.dsp.workspace.move({ monitor = "+1" }))

          -- Alt+Space stays on vicinae for its dmenu mode.
          hl.bind(mod .. " + Return", exec("uwsm-app -- kitty"))
          hl.bind("SUPER + Space", noctalia("launcher toggle"))
          hl.bind(mod .. " + Space", exec("vicinae toggle"))

          ${lib.optionalString (lib.attrByPath [ "programs" "hex" "enable" ] false config) ''
            -- Hyprland requires explicit bindings for Hex's portal shortcuts.
            -- The IDs include the shortcuts saved in Hex's settings.
            hl.bind("CTRL + Space", hl.dsp.global("anomaly.hex:dictation-CTRL-space"))
            hl.bind("F9", hl.dsp.global("anomaly.hex:capture-F9"))
          ''}

          hl.bind("SUPER + d", noctalia("darkMode toggle"))
          hl.bind("SUPER + r", exec(hypr_reload))

          hl.bind(mod .. " + CTRL + q", noctalia("lockScreen lock"))
          hl.bind("SUPER + l", noctalia("lockScreen lock"))

          hl.bind("Print", noctalia("plugin:screen-shot-and-record screenshot"))
          hl.bind("SHIFT + Print", noctalia("plugin:screen-shot-and-record ocr"))

          -- Mirrors macOS Cmd+Shift+4/5; CTRL copies to the clipboard.
          hl.bind(mod .. " + SHIFT + 4", exec("screenshot region file"))
          hl.bind(mod .. " + SHIFT + CTRL + 4", exec("screenshot region clipboard"))
          hl.bind(mod .. " + SHIFT + 5", exec("screenshot screen file"))
          hl.bind(mod .. " + SHIFT + CTRL + 5", exec("screenshot screen clipboard"))

          hl.bind(mod .. " + SHIFT + e", noctalia("sessionMenu toggle"))
          -- alt-c is the clipboard, so close lives on alt-w.
          hl.bind(mod .. " + c", noctalia("launcher clipboard"))
          hl.bind(mod .. " + w", hl.dsp.window.close())

          hl.bind(mod .. " + SHIFT + semicolon", hl.dsp.submap("service"))
          hl.bind(mod .. " + SHIFT + slash", hl.dsp.submap("join"))

          -- Letters mirror aerospace; c/h/j/k/l/w belong to other binds.
          for key in ("abdefgimnopqrstuvxyz"):gmatch(".") do
            local ws = "name:" .. key:upper()
            hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = ws }))
            hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws }))
          end

          -- $mod SHIFT 4/5 are the screenshot binds above.
          for i = 1, 9 do
            hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
            if i ~= 4 and i ~= 5 then
              hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
            end
          end
          hl.bind(mod .. " + 0", hl.dsp.focus({ workspace = "name:0" }))
          hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "name:0" }))

          -- locked: also fires on the lock screen.
          hl.bind("XF86AudioMute", noctalia("volume muteOutput"), { locked = true })
          hl.bind("XF86AudioMicMute", noctalia("volume muteInput"), { locked = true })

          -- On release, so chords like Super+L don't also open the launcher.
          hl.bind("SUPER + SUPER_L", noctalia("launcher toggle"), { release = true })

          hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
          hl.bind(mod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
          hl.bind("XF86AudioRaiseVolume", noctalia("volume increase"), { repeating = true })
          hl.bind("XF86AudioLowerVolume", noctalia("volume decrease"), { repeating = true })
          hl.bind("XF86MonBrightnessUp", noctalia("brightness increase"), { repeating = true })
          hl.bind("XF86MonBrightnessDown", noctalia("brightness decrease"), { repeating = true })

          -- alt-shift-semicolon
          hl.define_submap("service", function()
            hl.bind("ALT + r", toggle_workspace_float)
            hl.bind("ALT + f", hl.dsp.window.float({ action = "toggle" }))
            hl.bind("backspace", close_other_windows)
            hl.bind("escape", function()
              hl.dispatch(hl.dsp.submap("reset"))
              hl.exec_cmd(hypr_reload)
            end)
          end)

          -- alt-shift-slash. Hyprland has no aerospace join-with; moving the window
          -- in a direction is the closest equivalent.
          hl.define_submap("join", function()
            for dir, key in pairs(dirs) do
              hl.bind("ALT + " .. key, hl.dsp.window.move({ direction = dir }))
            end
            hl.bind("escape", hl.dsp.submap("reset"))
          end)

          -- Apps go through uwsm-app so each gets its own scope in app.slice
          -- (https://wiki.hypr.land/Useful-Utilities/Systemd-start/).
          hl.on("hyprland.start", function()
            -- Upstream deprecated noctalia's systemd startup.
            hl.exec_cmd("uwsm-app -- noctalia-shell")
            hl.exec_cmd("uwsm-app -- 1password --silent")
          end)
        '';
      };

      # Started from exec-once; upstream deprecated its systemd unit.
      programs.noctalia-shell.enable = true;

      home.activation.noctaliaSettingsBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] /* bash */ ''
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

      home.activation.noctaliaPluginsBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] /* bash */ ''
        cfg="$HOME/.config/noctalia/plugins.json"
        $DRY_RUN_CMD mkdir -p "$(dirname "$cfg")"
        $DRY_RUN_CMD rm -f "$cfg"
        $DRY_RUN_CMD install -m 644 ${noctaliaPlugins} "$cfg"
      '';

      # So the wallpaper picker doesn't report a missing directory on fresh installs.
      home.activation.makeWallpapersDir = lib.hm.dag.entryAfter [ "writeBoundary" ] /* bash */ ''
        $DRY_RUN_CMD mkdir -p $HOME/Pictures/Wallpapers
      '';

      # Keep the greeter background current on first boot (before noctalia's hook has
      # fired) and when the wallpaper changes outside noctalia.
      home.activation.seedGreeterBackground = lib.hm.dag.entryAfter [ "writeBoundary" ] /* bash */ ''
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
            before_sleep_cmd = "${beforeSleepHook}";
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
              on-timeout = dpms "off";
              on-resume = dpms "on";
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

        # Manual use only: the noctalia/vicinae logout entries call hypr-exit
        # because hyprshutdown hangs when an app ignores the close event.
        hyprshutdown
        (writeShellScriptBin "hypr-exit" ''
          exec ${hyprDispatch "hl.dsp.exit()"}
        '')

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
      xdg.configFile."uwsm/env".text = /* bash */ ''
        source ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh
      '';

      # rtkit re-promotes Hyprland to SCHED_RR on every resume, even after its
      # SIGXCPU handler dropped RT; the kernel has by then raised the soft
      # RLIMIT_RTTIME past the 200ms hard limit, so the next long frame is a
      # silent SIGKILL and start-hyprland falls back to safe mode.
      xdg.configFile."uwsm/env-hyprland".text = ''
        export HYPRLAND_NO_RT=1
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
