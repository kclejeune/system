{ config, ... }:
let
  flakeCfg = config;
in
{
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
      # Theme palettes + GTK name constants come from `flake.lib.mkTheme`
      # (modules/shared/theme.nix). The mkTheme function loads
      # base24 scheme YAML from tinted-theming/schemes via
      # base16.nix, so swapping schemes is a one-line edit there.
      # Catppuccin Mocha is the dark baseline used for hyprland borders
      # + shadow; Latte is the light variant the darkModeChange hook
      # swaps to. Noctalia owns the broader theme (bar, panels, lock,
      # OSD, notifications) via its built-in Catppuccin color scheme.
      theme = flakeCfg.flake.lib.mkTheme pkgs;
      dark = theme.palettes.dark;
      light = theme.palettes.light;
      c = dark;

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

      # hypridle's after_sleep_cmd handler. Three-stage to fix flaky
      # fingerprint behaviour on the lock screen after resume:
      #
      #   1. DPMS-on fires unconditionally and first. Independent of
      #      fprintd state — the lock screen is visible the instant
      #      logind says PrepareForSleep=false, so the user's first
      #      keypress isn't into a black void.
      #
      #   2. Poll fprintd's Manager.GetDevices over D-Bus until at
      #      least one device is returned. The kernel asynchronously
      #      resets USB 3-9 (Goodix 27c6:63ac) 3-8 s AFTER logind's
      #      PrepareForSleep returns; without this wait, noctalia's
      #      restartAuth lands in that gap and the lock-screen
      #      fingerprint widget intermittently fails to show. Polling
      #      GetDevices both dbus-activates fprintd and forces a
      #      device rescan on each call, so as soon as the kernel
      #      re-enumerates the Goodix the next poll picks it up.
      #
      #   3. Re-arm noctalia's PAM stack against the now-ready fprintd.
      #
      # All three stages are best-effort (`|| true`) so a single
      # failure doesn't strand the user in a broken auth state.
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

      # Settings.json is re-seeded from the asset on every HM
      # activation, which fires on `nixos-rebuild switch` and at
      # system boot (NOT on interactive login — that's a separate
      # user@$UID.service start). The file is writable during a
      # session: noctalia's `darkModeChange` hook owns SUPER+d
      # toggles, in-memory state changes flow through to Hyprland
      # borders via hyprctl, and runtime mutations live until the
      # next switch or reboot. To make a change permanent: capture
      # via `noctalia-settings-dump`, edit
      # `./assets/noctalia/settings.json`, commit, rebuild.
      #
      # OS dark/light propagation: `colorSchemes.syncGsettings = true`
      # runs `gtk-refresh.py --appearance-only` which `gsettings set`s
      # org.gnome.desktop.interface/color-scheme. xdg-desktop-portal-gtk
      # watches that and emits the freedesktop appearance SettingChanged
      # signal that kitty / Zed / Electron subscribe to.
      noctaliaSettings =
        let
          asset = builtins.fromJSON (builtins.readFile ./assets/noctalia/settings.json);
        in
        (pkgs.formats.json { }).generate "noctalia-settings.json" (
          asset
          // {
            # Field-level merge so future non-empty hook entries in
            # the asset (colorGeneration, screenLock, ...) aren't
            # silently dropped by a wholesale replace.
            hooks = (asset.hooks or { }) // {
              enabled = true;
              # `$1` is text-substituted with "true"/"false" before
              # `sh -lc` — must be a shell command string, not a
              # script path.
              darkModeChange = ''
                if [ "$1" = "true" ]; then
                  ${hyprThemeCmds dark}
                else
                  ${hyprThemeCmds light}
                fi
              '';
              # Mirror noctalia's active wallpaper into the regreet
              # background slot. `$1` is the path noctalia just
              # switched to. We blur it (sigma 16 — same as the
              # build-time fallback) and write to
              # /var/lib/regreet/background.png, which is tmpfile-
              # created as kclejeune-owned + world-readable so this
              # write from the user session and ReGreet's read from
              # the greeter user both work. ReGreet picks up the new
              # file on its next startup (no live reload — but the
              # greeter is short-lived, so the next reboot / logout
              # cycle shows the latest wallpaper).
              wallpaperChange = ''
                ${pkgs.imagemagick}/bin/magick "$1" -blur 0x16 \
                  /var/lib/regreet/background.png 2>/dev/null || true
              '';
            };
            # noctalia reads `wallpaper.directory` directly via QML's
            # FileView (no shell), so a leading `~` is taken literally.
            # Interpolate `home.homeDirectory` at eval time to land an
            # absolute path in the rendered settings.json.
            wallpaper = (asset.wallpaper or { }) // {
              directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
            };
          }
        );

      # Plugins.json — pure data, no Nix-side overlay needed. Same
      # writable-with-re-seed semantics as settings.json: asset is
      # the source of truth for which noctalia plugins are enabled
      # and where to fetch them; runtime mutations (toggling a
      # plugin via the GUI) live until the next switch/reboot. To
      # persist a change, edit the asset.
      noctaliaPlugins = (pkgs.formats.json { }).generate "noctalia-plugins.json" (
        builtins.fromJSON (builtins.readFile ./assets/noctalia/plugins.json)
      );

      # Shared jq filters for the noctalia-settings-* helpers.
      # `stripFilter` operates on a settings object directly (used on the
      # nix-store derivation, which is already a settings object).
      # `ipcFilter` strips the `state.all` IPC envelope first.
      stripFilter = "del(.hooks.darkModeChange) | del(.settingsVersion)";
      ipcFilter = ".settings | ${stripFilter}";

    in
    {
      imports = [ inputs.noctalia.homeModules.default ];

      # UWSM owns the session targets (it activates graphical-session.target
      # via wayland-session@hyprland.target). Without UWSM we used
      # hyprland-session.target to scope HM Wayland services to Hyprland;
      # with UWSM that target no longer exists, so we bind to
      # graphical-session.target — which UWSM sets up specifically for the
      # active wayland session, so the "any wayland session" leak doesn't
      # apply here.
      wayland.systemd.target = "graphical-session.target";

      wayland.windowManager.hyprland = {
        enable = true;
        xwayland.enable = true;
        # MUST be false under UWSM — HM's systemd integration creates its own
        # hyprland-session.target and env-export wiring that conflicts with
        # UWSM's session management. https://wiki.nixos.org/wiki/Hyprland
        systemd.enable = false;

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
            # When an ext-session-lock-v1 client (noctalia's lock
            # surface) disconnects without sending unlock_and_destroy,
            # the protocol obliges the compositor to keep the screen
            # secured — Hyprland shows its red "lockdead" / "your lock
            # screen died" fallback (share/hypr/lockdead*.png). The
            # noctalia lock screen's Logout / Reboot / Shutdown buttons
            # run `uwsm stop` / `systemctl reboot` / `systemctl
            # poweroff` directly without releasing the WlSessionLock
            # first, so the quickshell process is killed by the
            # teardown a beat before Hyprland exits — and that beat is
            # long enough to flash the lockdead screen with the default
            # 1000 ms delay. Stretch the delay well past how long a
            # logout/reboot/poweroff takes to tear the session down, so
            # the system is already gone before Hyprland would paint
            # it. (Only affects the lock-client-died path; a normal
            # password unlock sends unlock_and_destroy and is
            # unaffected.)
            lockdead_screen_delay = 5000;
            # Safety net for a *genuine* lock-client crash (noctalia
            # dies mid-session, not during a planned shutdown): keep
            # the screen secured but let a freshly launched lock
            # client re-attach to the existing lock instead of leaving
            # the user hard-locked-out. Recovery is then just
            # re-running noctalia-shell (or `hyprlock`) from a TTY.
            allow_session_lock_restore = true;
          };

          ecosystem = {
            no_update_news = true;
          };

          # -- Startup --
          # Per https://wiki.hypr.land/Useful-Utilities/Systemd-start/:
          # "Running applications as child processes inside compositor's
          # unit is discouraged." Apps go through `uwsm-app --` so they
          # land in app.slice as their own transient scopes; services
          # (hyprpolkitagent) are declared as systemd user units below
          # and pulled in via WantedBy=graphical-session.target instead
          # of exec-once.
          #
          # `uwsm-app` (not `uwsm app`) is the fast shell client that
          # talks to wayland-wm-app-daemon.service via FIFOs in
          # $XDG_RUNTIME_DIR; subsequent calls bypass Python startup.
          # On the FIRST invocation after login the script auto-restarts
          # the daemon and polls for pipes with `sleep 1` (≤2s stall on
          # the first exec-once entry only) — fine in practice because it
          # happens before the first frame is composited.
          #
          # `uwsm-app` is on PATH because `programs.hyprland.withUWSM = true`
          # (modules/nixos/hyprland.nix) adds pkgs.uwsm to systemPackages.
          exec-once = [
            # noctalia-shell stays exec-once: upstream deprecated systemd
            # startup over IPC / start-order issues. The uwsm-app wrapper
            # is still worthwhile — gets it into app.slice so a
            # compositor crash doesn't orphan it.
            "uwsm-app -- noctalia-shell"

            # 1Password tray-only; kitty lands on workspace T via the
            # match:class kitty rule (windowrules still match — the
            # uwsm-app wrapper doesn't change app_id/class).
            "uwsm-app -- 1password --silent"
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
          "$ipc" = "${noctaliaIpc} call";

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
            # `uwsm-app --` for the same reason as exec-once above.
            "$mod, Return, exec, uwsm-app -- kitty"
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
      # Launched via hyprland's exec-once above; upstream deprecated
      # systemd startup over IPC / start-order issues. Settings.json
      # is seeded by the activation script below — see the
      # noctaliaSettings let-block for the "writable, re-seeded on
      # switch" rationale.
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

      # Make sure noctalia's wallpaper directory exists so the picker
      # doesn't show "no directory" on a fresh install. The path tracks
      # `wallpaper.directory` in assets/noctalia/settings.json.
      home.activation.makeWallpapersDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p $HOME/Pictures/Wallpapers
      '';

      # Re-blur the user's current dark-mode wallpaper into the regreet
      # background slot on every HM activation. Two reasons:
      #   1. First boot — noctalia's wallpaperChange hook hasn't fired
      #      yet, so /var/lib/regreet/background.png is whatever the
      #      build-time tmpfile fallback was. Without this seeder, the
      #      greeter shows that frozen fallback until the user actually
      #      switches wallpapers in noctalia.
      #   2. Subsequent rebuilds — if the user updates the raw
      #      wallpaper-dark.png on disk (without rotating through
      #      noctalia), we still want the greeter to track it.
      #
      # Destination is tmpfile-created as kclejeune-owned + world-
      # readable (see modules/nixos/hyprland.nix), so this write from
      # the user session and ReGreet's read from the greeter user both
      # work without ACL gymnastics. The `-w` check is the safety net
      # for the very first activation where the tmpfile rule might not
      # have landed yet.
      home.activation.seedGreeterBackground = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        src="$HOME/Pictures/Wallpapers/wallpaper-dark.png"
        dst="/var/lib/regreet/background.png"
        if [ -f "$src" ] && [ -w "$dst" ]; then
          $DRY_RUN_CMD ${pkgs.imagemagick}/bin/magick "$src" -blur 0x16 "$dst" 2>/dev/null || true
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
        systemd.target = "graphical-session.target";
      };

      # -- Polkit auth agent --
      # Handled by noctalia's `polkit-agent` plugin (in plugins.json),
      # not a separate hyprpolkitagent process. The plugin uses
      # Quickshell.Services.Polkit + WlrLayershell.Overlay for a native
      # Wayland overlay that matches noctalia's theme/animations and
      # shares the same auth surface language as the lock screen.
      # Trade-off: the agent dies if noctalia crashes — fine here
      # because noctalia is the shell, so a crash means the bar /
      # launcher / notifications are gone too, and a polkit prompt is
      # the least of the worries.

      # -- Kanshi (monitor management, wlroots protocol) --
      # Outside noctalia's scope (compositor-level). Profiles (eDP-1
      # mode + external monitors) are declared in the overlay module
      # enrolled by each host (hyprland-host-<name> or
      # displays-<hardware>-<loc>).
      services.kanshi = {
        enable = true;
        systemdTarget = "graphical-session.target";
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
            # DPMS-on + wait-for-fprintd + restartAuth — see the
            # afterSleepHook let-binding above for the rationale on
            # each stage. The fprintd wait is the load-bearing piece:
            # the kernel's post-resume Goodix USB re-enumeration lags
            # PrepareForSleep by several seconds, which used to make
            # the lock-screen fingerprint widget appear flakily.
            after_sleep_cmd = "${afterSleepHook}";
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
      # Static theme — the GTK theme NAME stays Mocha across runtime
      # toggles. The darkModeChange hook only updates Hyprland border
      # colors via hyprctl; it does not swap GTK themes. Dark/light
      # propagation to libadwaita / Electron happens via dconf
      # color-scheme, which noctalia's `colorSchemes.syncGsettings`
      # keeps in sync — apps that subscribe to the freedesktop
      # appearance signal flip between dark/light renderings, but
      # the underlying GTK theme remains Mocha. Latte is installed
      # below as a fallback package, not auto-applied.
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
        platformTheme.name = "gtk";
        style.name = "adwaita-dark";
      };

      home.pointerCursor = {
        gtk.enable = true;
        name = theme.gtk.cursorName;
        package = pkgs.catppuccin-cursors.mochaDark;
        size = 24;
      };

      # -- Packages --
      home.packages = with pkgs; [
        # Catppuccin Latte GTK theme used by the darkModeChange hook when
        # switching to light mode. Variant is hardcoded to "latte" (the
        # light counterpart); accent tracks the centralized choice.
        (catppuccin-gtk.override {
          accents = [ theme.gtk.accent ];
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

        # libnotify gives notify-send for the screenshot/recording toasts
        # emitted by noctalia's plugins. Clipboard tools come from
        # homeModules.clipboard.
        libnotify

        # Audio / Bluetooth GUIs that noctalia surfaces via the bar's
        # "more" buttons (controlCenter audio + bluetooth panels open
        # these). Optional — noctalia's built-in panels are usually enough.
        pwvucontrol
        overskride

        # Graceful logout helper: sends xdg-toplevel close events to
        # running apps (so they can prompt for unsaved work / flush
        # state) before exiting Hyprland via `hyprctl dispatch exit`;
        # UWSM's bindpid watcher then cascades the
        # wayland-session@hyprland.target teardown. Kept available for
        # manual use, but NOT wired to the noctalia session-menu /
        # lock-screen Logout button — that runs a bare
        # `hyprctl dispatch exit` (see sessionMenu.powerOptions in
        # assets/noctalia/settings.json) because `hyprshutdown` was
        # observed to hang indefinitely when an app ignores the close
        # event, with no way out but a TTY. Exiting Hyprland directly
        # also closes the lock surface in the same instant as every
        # other client, so there's no window for Hyprland's "lockdead"
        # screen (which `uwsm stop`'s slower, ordered teardown left
        # open).
        hyprshutdown

        # Helpers for the declarative settings workflow. The activation
        # installs settings.json as a writable copy (mode 0644), and
        # noctalia writes runtime state back to it — so comparing the
        # live file against IPC is meaningless (both reflect runtime).
        # `noctalia-settings-diff` therefore compares the /nix/store
        # derivation (asset + Nix-side overlays) against IPC state. To
        # persist a runtime change, capture via `noctalia-settings-dump`
        # and update `modules/home/assets/noctalia/settings.json`.
        #
        #   noctalia-settings-diff
        #       Show a unified diff between the declarative file and
        #       the running noctalia state. Useful for finding what
        #       you've toggled in the current session that doesn't yet
        #       live in the Nix asset.
        #
        #   noctalia-settings-dump
        #       Print the running noctalia state, stripped of the
        #       fields that should not be tracked (the `darkModeChange`
        #       hook is generated with /nix/store paths every build,
        #       and `settingsVersion` bumps on schema changes). Pipe
        #       this into the asset file:
        #
        #         noctalia-settings-dump > \
        #           ~/.nixpkgs/modules/home/assets/noctalia/settings.json
        #
        #       Then `git diff` the asset, sanity-check, and rebuild.
        (writeShellScriptBin "noctalia-settings-dump" ''
          set -eu
          # `-S` sorts keys so successive dumps produce diff-stable
          # output regardless of noctalia's internal emission order.
          ${noctaliaIpc} call state all | ${pkgs.jq}/bin/jq -S '${ipcFilter}'
        '')
        # Asset-shaped dump: same as `noctalia-settings-dump`, but rewrites
        # `wallpaper.directory` back to the `~/Pictures/Wallpapers` tilde
        # form that the asset uses (the Nix overlay expands `~` at eval
        # time, so the runtime always shows the absolute path). Redirect
        # straight onto the asset to capture runtime drift:
        #
        #   noctalia-settings-apply \
        #     > ~/.nixpkgs/modules/home/assets/noctalia/settings.json
        (writeShellScriptBin "noctalia-settings-apply" ''
          set -eu
          ${noctaliaIpc} call state all \
            | ${pkgs.jq}/bin/jq -S '${ipcFilter} | .wallpaper.directory |= sub("^"+env.HOME+"/"; "~/")'
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

        # plugins.json equivalents. plugins.json doesn't have an IPC
        # accessor — the file itself is the runtime state, written by
        # noctalia when plugins are toggled in the GUI. dump prints
        # the current file (sorted); diff compares against the
        # checked-in asset.
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

      # Bridge `home.sessionVariables` into the UWSM session env. UWSM
      # is exec'd directly by greetd (no shell login between the two),
      # so the standard HM env path — sourcing `hm-session-vars.sh`
      # from `~/.profile` — never runs for the wayland session.
      # `~/.config/uwsm/env` is the documented UWSM hook: it's sourced
      # by `wayland-wm-env@hyprland.desktop.service` before the
      # compositor starts and the resulting env is exported to the
      # whole `wayland-session@hyprland.target` graph. Without this,
      # vars like NIXOS_OZONE_WL / QT_QPA_PLATFORM only land in shells
      # spawned from kitty (which inherits via systemd-user), not in
      # apps started directly by the compositor.
      xdg.configFile."uwsm/env".text = ''
        source ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh
      '';

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
