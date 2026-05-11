{ config, ... }:
let
  flakeCfg = config;
in
{
  flake.nixosModules.hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Theme constants — see modules/shared/theme.nix. mkTheme is a
      # function (not a static attrset) because base16.nix's YAML
      # loader needs `pkgs`.
      theme = flakeCfg.flake.lib.mkTheme pkgs;

      # Greeter session command. Wrapped as a writeShellScript so we
      # can do real shell logic without nested-quoting nightmares in
      # the greetd settings.command string.
      #
      # Three jobs:
      #   1. `exec 2> >(systemd-cat …)` redirects this script's stderr
      #      (and cage/wlroots/mesa's, which inherit) to journald.
      #      greetd assigns the session command's stdio to the
      #      controlling VT (tty1), so without this redirect every
      #      mesa "renderer.c: …" / xe driver init / "/var/empty/.cache"
      #      warning / libseat probe error paints onto tty1 in the
      #      window between plymouth quit and the greeter's first
      #      frame. Going through systemd-cat keeps the messages in
      #      journal with a recognizable identifier for debug.
      #   2. `[ -w /dev/tty1 ]` guards each setterm. /dev/tty1 is
      #      mode 0600 (not 0660 — the `tty` group gets nothing), so
      #      greeter membership in `tty` doesn't actually help; we
      #      depend on logind transferring ownership at PAM session
      #      open, which races the very first setterm in the wrapper.
      #      The guard skips the redirect when greeter doesn't own
      #      tty1 yet, avoiding bash's "Permission denied" diagnostic
      #      (which would itself land on tty1 via the inherited
      #      stderr — defeating the point).
      #   3. The setterm-on-EXIT trap is preserved so the fbcon
      #      scrollback flash on cage→hyprland handoff is still
      #      hidden when cage SIGSEGVs on output destroy. See block
      #      comment further down for the cage-crash rationale.
      # Build-time blurred fallback wallpaper for the regreet
      # background — used as the *seed* for /var/lib/regreet/
      # background.png on first boot (via tmpfiles `C`). After that,
      # noctalia's `wallpaperChange` hook and HM's
      # `seedGreeterBackground` activation keep the runtime file in
      # sync with the user's actual current wallpaper (see
      # modules/home/hyprland.nix). The asset committed in the repo
      # is just the first-ever fallback.
      greeterBackground =
        pkgs.runCommandLocal "regreet-background.png"
          {
            nativeBuildInputs = [ pkgs.imagemagick ];
          }
          ''
            magick ${./assets/regreet-background.png} -blur 0x16 $out
          '';

      greeterCommand = pkgs.writeShellScript "greeter-session" ''
        exec 2> >(${pkgs.systemd}/bin/systemd-cat -t greeter-session)

        clear_tty1() {
          if [ -w /dev/tty1 ]; then
            ${pkgs.util-linux}/bin/setterm --clear all --cursor off >/dev/tty1
          fi
        }
        clear_tty1
        trap clear_tty1 EXIT

        # NOT `exec` — we need bash to outlive dbus-run-session so the
        # EXIT trap fires after cage returns. Without it the framebuffer
        # is left in whatever state cage left, and the kernel fbcon
        # redraws plymouth's retained splash (from `plymouth quit
        # --retain-splash`) into the cage→hyprland gap.
        ${pkgs.dbus}/bin/dbus-run-session \
          ${lib.getExe pkgs.cage} -s -m last -- ${lib.getExe pkgs.regreet}
      '';
    in
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
        # Adds pkgs.uwsm to PATH (so `uwsm`, `uwsm-app`, `uuctl`, etc.
        # are reachable as bare commands). The HM hyprland module uses
        # `uwsm-app -- <cmd>` in exec-once and keybinds to put apps in
        # app.slice as transient scopes instead of compositor children.
        # This is NOT enough to run a UWSM session — the
        # template units (wayland-session-bindpid@.service,
        # wayland-wm@.service, wayland-wm-env@.service) ship in
        # `share/systemd/user/` of pkgs.uwsm, and NixOS only aggregates
        # `lib/systemd/user/`, so the user systemd manager never sees
        # them. Without `programs.uwsm.enable` below, `uwsm start` fails
        # at `systemctl --user start wayland-session-bindpid@<pid>` with
        # exit code 5 (unit not found) and the user is bounced back to
        # the greeter.
        withUWSM = true;
      };

      # Wires up UWSM properly: adds pkgs.uwsm to `systemd.packages` so
      # the template units land in the user manager's search path, and
      # adds `share/wayland-sessions` + `share/uwsm` to
      # `environment.pathsToLink`. We deliberately leave
      # `waylandCompositors` empty — that option auto-generates a
      # `<name>-uwsm.desktop` session file, which would collide with the
      # `hyprland-uwsm.desktop` already bundled by pkgs.hyprland.
      # (Side effect: forces `services.dbus.implementation = "broker"`,
      # which is already what this host runs.)
      programs.uwsm.enable = true;

      # greetd + ReGreet. ReGreet is a GTK4 layer-shell greeter and
      # needs a Wayland host, so we wrap it in `cage` (a single-app
      # Wayland kiosk). dbus-run-session gives ReGreet its own session
      # bus so AT-SPI / GTK portal lookups don't hit the system bus.
      #
      # gnome-keyring unlock: the upstream greetd nixos module
      # auto-sets `security.pam.services.greetd.enableGnomeKeyring`
      # from `services.gnome.gnome-keyring.enable` (set below), so the
      # greeter's PAM stack already includes pam_gnome_keyring.
      services.greetd = {
        enable = true;
        # Don't wait for plymouth to exit before starting the greeter.
        # Combined with the `plymouth-quit.unitConfig.After = greetd`
        # override below, this flips the order: cage takes the
        # framebuffer first, *then* plymouth quits with
        # `--retain-splash`. Without this, plymouth releases the fb
        # at multi-user.target → kernel fbcon flashes whatever was in
        # its scrollback → cage starts → greeter appears.
        greeterManagesPlymouth = true;
        settings.default_session = {
          # Wraps cage to (a) blank tty1 before AND after each greeter
          # cycle and (b) route cage/wlroots/mesa stderr to journald.
          # cage 0.2.1 reliably SIGSEGVs in `wl_display_destroy → ...
          # → handle_output_destroy` when wlroots 0.19 tears down its
          # DRM backend (upstream race; the cage process is dying
          # anyway, so the crash is post-handoff cosmetic). The bigger
          # UX symptom is that the segfault leaves the framebuffer in
          # an undefined state, so on the cage→hyprland and
          # hyprland→cage handoffs fbcon briefly redraws whatever
          # scrollback / kernel-trap text was last there. Pre-clearing
          # tty1 before cage runs and post-clearing on exit (trap
          # survives a SIGSEGV in the child) hides the leak. See
          # `greeterCommand` in the let-block above for the wrapper.
          command = "${greeterCommand}";
          user = "greeter";
        };
      };

      # Move the greeter's HOME off /var/empty (where pam_systemd
      # plants it from the system-user default) onto the regreet
      # state directory we already own. Without this, mesa /
      # gtk / wlroots / cage all try `$HOME/.cache` →
      # `/var/empty/.cache`, which is unwritable (root-owned, mode
      # 0555), and they emit one warning each during cage init —
      # the "Unable to create /var/empty/.cache" flash. Pointing
      # HOME at /var/lib/regreet (created with greeter:greeter
      # ownership by the tmpfile rules below) lets every cache
      # land in /var/lib/regreet/.cache without further fuss.
      # The greetd module already runs ReGreet with this as HOME
      # via systemd.services.greetd.environment.HOME, but
      # pam_systemd overrides that from the passwd entry on
      # session open — fixing it at the passwd entry is the only
      # path that survives the PAM step.
      users.users.greeter.home = "/var/lib/regreet";

      # tty group membership is still useful as a fallback (mode 0660
      # configurations elsewhere benefit), but on this system
      # /dev/tty1 is mode 0600 so group access doesn't actually
      # grant anything — the greeterCommand wrapper does the
      # writability check itself before each setterm.
      users.users.greeter.extraGroups = [ "tty" ];

      # cage SIGSEGVs every greeter cycle (see command wrapper above).
      # Setting RLIMIT_CORE=0 on greetd propagates to its children, so the
      # kernel never asks systemd-coredump to record the dump. Net effect:
      # the journal stops getting flooded with "Module libseat.so.1
      # without build-id" backtrace listings (cage links libseat for
      # logind seat management; the libseat frame shows up because cage's
      # crash happens during wlroots' DRM teardown). Cage still dies with
      # SIGSEGV — we just don't ceremonially preserve the body.
      #
      # The directive must be `LimitCORE` (uppercase rlimit name);
      # `LimitCore` is silently ignored with `Unknown key 'LimitCore' in
      # section [Service]` in the journal, leaving RLIMIT_CORE at its
      # inherited value and the coredump flood intact.
      systemd.services.greetd.serviceConfig.LimitCORE = "0";

      # The kernel `loglevel`, `quiet`, and PID-1's `systemd.show_status`
      # only silence the *system* manager. greetd.service and
      # user@.service default to `StandardError=inherit`, which chains up
      # to PID 1's stderr → /dev/console → tty1, so the user-systemd
      # manager's "Started …" / "Reached target …" lines paint over the
      # framebuffer in the cage→Hyprland handoff window. Redirect both
      # services' stdout+stderr to the journal so nothing from that chain
      # hits the console, and clamp the user manager's log level + target
      # at `err` / `journal` so info-level status chatter is filtered at
      # the source even if some child re-attaches stderr to a terminal.
      systemd.services.greetd.serviceConfig.StandardError = "journal";
      systemd.services.greetd.serviceConfig.StandardOutput = "journal";
      systemd.services."user@".serviceConfig = {
        StandardError = "journal";
        StandardOutput = "journal";
        Environment = [
          "SYSTEMD_LOG_LEVEL=err"
          "SYSTEMD_LOG_TARGET=journal"
        ];
      };

      # libseat probes its `seatd` backend first and prints
      #   [libseat] backend/seatd.c:64: Could not connect to socket
      #   /run/seatd.sock: No such file or directory
      # before transparently falling back to logind. The fallback works
      # — the error is cosmetic — but cage's stderr ends up on tty1
      # (greetd assigns the session a controlling VT, so child stderr
      # routes there rather than to greetd.service's journal stream),
      # which paints the line on screen between plymouth quit and the
      # greeter's first frame. We don't run seatd (logind already does
      # seat management system-wide), so pinning the backend to logind
      # skips the failing probe entirely. Same env covers Hyprland's
      # wlroots later, so the user session never re-emits it either.
      environment.variables.LIBSEAT_BACKEND = "logind";

      # Pair to `greeterManagesPlymouth = true`: defer
      # `plymouth-quit.service` until greetd is up. Once greetd is
      # active, cage has the framebuffer; plymouth's quit is then
      # purely cosmetic (no fb release → no fbcon flash window).
      systemd.services.plymouth-quit.unitConfig.After = [ "greetd.service" ];

      # Silence the user systemd manager. Status messages ("Started
      # wayland-wm@hyprland.service", "Reached target Wayland Session")
      # are governed by ShowStatus on the user manager, not by
      # `systemd.show_status=` on the kernel cmdline (that one only
      # affects PID 1). LogLevel/LogTarget similarly only filter what
      # the user manager itself emits, not its unit-status lines.
      # Together: no status, no info chatter, journal-only routing.
      systemd.user.extraConfig = ''
        LogLevel=err
        LogTarget=journal
        ShowStatus=no
      '';

      # uwsm logs its own startup chatter at INFO level
      # ("Selected compositor ID: hyprland.desktop", "Created dir
      # /run/user/1000/systemd/user/", "Forked systemctl, PID …",
      # "Starting hyprland.desktop and waiting …"). These don't go
      # through PID 1, so the kernel cmdline silencing doesn't touch
      # them, and cage's controlling VT is still tty1 at greetd→
      # user-session handoff, so uwsm's stderr paints onto the screen.
      # uwsm has no `-q` flag — the documented switch is the
      # `UWSM_SILENT_START=1` env var, which sets uwsm's internal
      # `NoStdOutFlag.nostdout` and suppresses every print_normal()
      # call. Lands in `/etc/set-environment`, which PAM sources for
      # both the greeter session and the user session, so it's in
      # uwsm's env at exec time without needing a parallel
      # `.desktop` entry.
      environment.variables.UWSM_SILENT_START = "1";

      # Greeter UX: password only. fprintd's PAM hook would otherwise
      # stack `pam_fprintd.so sufficient` ahead of pam_unix and the
      # user sees a fingerprint scan request alongside the password
      # field. Sudo / TTY login still inherit fprintAuth — only the
      # ReGreet PAM service is opted out.
      security.pam.services.greetd.fprintAuth = false;

      # ReGreet bakes these paths in at compile time and crashes if
      # they don't exist. Owned by the `greeter` system user that the
      # greetd module creates.
      #
      # The seeded `state.toml` pre-selects `kclejeune` + the
      # UWSM-managed Hyprland session so the greeter just shows a
      # password field on first boot — no need to click through
      # user/session pickers. The session name matches the `Name=` field
      # of `share/wayland-sessions/hyprland-uwsm.desktop` shipped by the
      # hyprland package (the bare `Hyprland` entry remains as a UWSM
      # fallback). `C` means "copy if missing": ReGreet's runtime writes
      # (last user / last session bookkeeping) take over after first
      # login.
      systemd.tmpfiles.rules =
        let
          initialState = pkgs.writeText "regreet-initial-state.toml" ''
            last_user = "${config.user.name}"
            [user_to_last_sess]
            ${config.user.name} = "Hyprland (uwsm-managed)"
          '';
          # GTK4 settings read at gtk_init() — before any window is
          # mapped — so the dark Catppuccin theme is active for
          # regreet's very first frame. regreet.toml's [GTK] block
          # sets the same values, but programmatically *after* init,
          # which leaves one frame painted with GTK4's built-in
          # Adwaita (light → "white flash"). GTK_THEME on
          # greetd.service.environment doesn't reach regreet because
          # greetd builds a fresh PAM-derived env for the session and
          # /etc/pam.d/greetd's pam_env has readenv=0. A settings.ini
          # in the greeter's $HOME/.config is the path GTK4 actually
          # reads at init.
          gtk4Settings = pkgs.writeText "regreet-gtk4-settings.ini" ''
            [Settings]
            gtk-theme-name=${theme.gtk.themeName}
            gtk-icon-theme-name=${theme.gtk.iconThemeName}
            gtk-cursor-theme-name=${theme.gtk.cursorName}
            gtk-font-name=${theme.gtk.fontName} 15
            gtk-application-prefer-dark-theme=true
          '';
        in
        [
          "d /var/lib/regreet 0755 greeter greeter - -"
          "d /var/log/regreet 0755 greeter greeter - -"
          "C /var/lib/regreet/state.toml 0644 greeter greeter - ${initialState}"
          # /var/lib/regreet/background.png — see comment near
          # `greeterBackground` for the why. `C` creates the file
          # once from the build-time fallback if absent; on
          # subsequent activations the file exists and the rule
          # is a no-op. Owned by ${config.user.name} so noctalia's
          # wallpaperChange hook (running as the user) and HM's
          # `seedGreeterBackground` activation can overwrite it
          # without permission gymnastics. Mode 0644 keeps it
          # world-readable so the greeter user can pick it up.
          "C /var/lib/regreet/background.png 0644 ${config.user.name} users - ${greeterBackground}"
          # GTK4 settings.ini in the greeter's config dir (HOME is
          # /var/lib/regreet). `L+` recreates the symlink on every
          # boot so it always points at the current build's settings.
          "d /var/lib/regreet/.config 0755 greeter greeter - -"
          "d /var/lib/regreet/.config/gtk-4.0 0755 greeter greeter - -"
          "L+ /var/lib/regreet/.config/gtk-4.0/settings.ini - - - - ${gtk4Settings}"
        ];

      # The greeter runs as the `greeter` system user with no $HOME
      # and a near-empty environment. We need:
      #   - HOME so GTK4 has somewhere to cache (/var/lib/regreet is
      #     already greeter-owned, no extra tmpfile needed),
      #   - XDG_DATA_DIRS so GTK can find the Catppuccin theme and
      #     cursor / icon themes installed via systemPackages below,
      #   - GTK_THEME pinned to the Catppuccin theme so the GTK app
      #     (regreet) renders dark from its very first frame. ReGreet
      #     also sets `theme_name` via GtkSettings in regreet.toml,
      #     but that's applied after the toolkit has already drawn at
      #     least once with the default (light Adwaita) — which is the
      #     "GTK white flash" seen before regreet's UI paints. The env
      #     var is read at GTK init, before any window is mapped, so
      #     there's no light frame to flash.
      systemd.services.greetd.environment = {
        HOME = "/var/lib/regreet";
        XDG_DATA_DIRS = "/run/current-system/sw/share";
        GTK_THEME = theme.gtk.themeName;
      };

      # Themes / cursors / icons that the greeter looks up by name in
      # /etc/greetd/regreet.toml. Catppuccin Mocha + Papirus + Open
      # Sans match the user's HM session, so the greeter blends with
      # noctalia's lock surface instead of falling back to Adwaita.
      environment.systemPackages = [
        (pkgs.catppuccin-gtk.override {
          accents = [ theme.gtk.accent ];
          variant = theme.gtk.variant;
        })
        pkgs.catppuccin-cursors.mochaDark
        pkgs.papirus-icon-theme
      ];

      fonts.packages = [ pkgs.open-sans ];

      # ReGreet config. Mirrors the user's HM gtk theme so the greeter
      # carries the same Catppuccin Mocha / Open Sans / Papirus look as
      # the noctalia lock screen the user sees mid-session. Theme name
      # constants come from `flake.theme.gtk` (modules/shared/theme.nix)
      # so the greeter and home session can never drift.
      environment.etc."greetd/regreet.toml".text = ''
        [GTK]
        application_prefer_dark_theme = true
        cursor_theme_name = "${theme.gtk.cursorName}"
        cursor_blink = true
        # Greeter runs full-screen with proportionally larger UI than
        # a desktop window, so it gets a slightly larger font than the
        # shared `theme.gtk.fontSize` (13) the desktop apps use — the
        # family still tracks the theme constant.
        font_name = "${theme.gtk.fontName} 15"
        icon_theme_name = "${theme.gtk.iconThemeName}"
        theme_name = "${theme.gtk.themeName}"

        [commands]
        reboot = ["systemctl", "reboot"]
        poweroff = ["systemctl", "poweroff"]

        # Blurred wallpaper as the greeter backdrop. The path is a
        # tmpfile-managed slot (/var/lib/regreet/background.png)
        # rather than a /nix/store derivation so noctalia's
        # `wallpaperChange` hook can mutate it at runtime as the user
        # rotates wallpapers. Seeded from the build-time
        # `greeterBackground` fallback on first boot via tmpfiles `C`.
        # `Cover` fills the screen and preserves aspect, matching how
        # noctalia paints its lockscreen wallpaper.
        [background]
        path = "/var/lib/regreet/background.png"
        fit = "Cover"

        [appearance]
        greeting_msg = "Welcome back"

        [widget.clock]
        format = "%A, %B %-d  ·  %H:%M"
        resolution = "1s"
        timezone = "America/Toronto"
        label_width = 360
      '';

      # Custom CSS overlays the Catppuccin GTK theme to push the
      # greeter closer to noctalia's lock surface (see IMG_6239.JPG):
      # heavily translucent surface0 cards floating over the blurred
      # wallpaper, pill-shaped password entry, pill session buttons
      # with a red-tinted destructive variant. Window background is
      # transparent so the [background] image from regreet.toml shows
      # through. Widget IDs come from ReGreet's relm4 templates
      # (src/gui/templates.rs).
      environment.etc."greetd/regreet.css".text =
        let
          p = theme.palettes.dark;
        in
        ''
          @define-color base #${p.base};
          @define-color mantle #${p.mantle};
          @define-color crust #${p.crust};
          @define-color surface0 #${p.surface0};
          @define-color surface1 #${p.surface1};
          @define-color overlay0 #${p.overlay0};
          @define-color text #${p.text};
          @define-color subtext1 #${p.subtext1};
          @define-color blue #${p.blue};
          @define-color lavender #${p.lavender};
          @define-color yellow #${p.yellow};
          @define-color red #${p.red};

          /* System font (Open Sans) across the whole greeter.
             regreet.toml's [GTK] font_name already sets gtk-font-name
             to "${theme.gtk.fontName} 15", but an explicit
             font-family here makes it unambiguous and survives any
             GTK default-font fallback. Per-widget font-size rules
             (the clock card, the hidden frame label) override the
             size; this rule only touches the family. */
          window, window * {
            font-family: "${theme.gtk.fontName}", sans-serif;
          }

          /* Opaque Catppuccin base behind everything. ReGreet draws
             the [background] wallpaper as a Gtk.Picture *child* of
             the window, on top of window.background — so this color
             is invisible once the wallpaper renders, but covers the
             one-frame gap during regreet's startup where the
             Picture hasn't loaded yet (otherwise the transparent
             window would show whatever cage/kernel-fb has, which
             reads as a brief light flash on logout transitions).
             We don't try to push the clock card down with
             padding-top here: it just moves the whole layout (clock
             still glued to its parent's top edge), so the visual
             relationship of "clock-at-screen-top" doesn't change. */
          window.background,
          #background {
            background-color: @base;
            color: @text;
          }

          /* GtkFrame renders its `label` widget as a title outside
             the styled box border (defaults to "regreet" — the app
             name). ReGreet doesn't expose a config knob for it, so
             we zero it out in CSS. `font-size: 0` collapses the
             glyph metrics; min-height: 0 + padding/margin zero
             reclaims the line of vertical space it was occupying. */
          #clock_frame > label {
            font-size: 0;
            min-height: 0;
            padding: 0;
            margin: 0;
          }

          /* Centered login frame — dark card floating over the
             blurred wallpaper. `@mantle` is one step darker than
             `@base` in Catppuccin Mocha, so the card reads as the
             deepest surface in the stack (wallpaper → window/base
             → card/mantle → entries/base). High alpha (0.9) keeps
             a hint of wallpaper bleed for the floating feel without
             the "frosted glass" weakness. */
          frame.background {
            background-color: alpha(@mantle, 0.9);
            border: 1px solid alpha(@overlay0, 0.4);
            border-radius: 24px;
            box-shadow: 0 12px 40px alpha(@crust, 0.6);
            padding: 16px 20px;
          }

          /* Welcome card at the top — noctalia uses a wider rounded
             pill containing greeting + date + time, floating with
             clear space above and rounded on all four corners.
             ReGreet's #clock_frame is the closest equivalent, but
             its relm4 template applies an inline_css that flattens
             the top two corners and zeroes the top margin to dock
             the card to the screen edge. `!important` beats inline
             styles, so we use it on the two properties ReGreet
             actually sets — border-radius and margin-top — and let
             the rest cascade normally. The toml-side clock format
             (`%A, %B %-d  ·  %H:%M`) is the date+time content,
             paired with `greeting_msg = "Welcome back"` above it. */
          #clock_frame {
            background-color: alpha(@mantle, 0.9);
            border: 1px solid alpha(@overlay0, 0.4);
            border-radius: 28px !important;
            box-shadow: 0 8px 32px alpha(@crust, 0.55);
            padding: 22px 48px;
            margin: 56px 0 0 0 !important;
            font-size: 22px;
            font-weight: 500;
            letter-spacing: 0.3px;
            color: @text;
          }

          /* Password / username inputs — pill shape, ~28px radius.
             Fully opaque so the input reads as a solid affordance
             rather than a frosted-glass overlay. The container
             frame is the only translucent surface at this layer. */
          entry,
          #secret_entry,
          #visible_entry,
          #username_entry,
          #session_entry {
            background-color: @base;
            border: 1px solid alpha(@overlay0, 0.5);
            border-radius: 28px;
            padding: 10px 20px;
            color: @text;
            caret-color: @lavender;
          }

          entry:focus,
          #secret_entry:focus,
          #visible_entry:focus {
            border-color: @lavender;
            box-shadow: 0 0 0 2px alpha(@lavender, 0.35);
          }

          /* All three buttons share the same surface as the cards —
             alpha(@mantle, 0.9), matching #clock_frame and
             frame.background — so the whole composition reads as one
             material. Only the outline + label color encodes the
             action semantics. Hover lifts the fill one shade lighter
             (alpha(@surface0, 0.9), same alpha) and saturates the
             outline, so the button reads as "pressed" without the
             fill ever picking up an accent tint. Matches noctalia's
             lock-screen pill row: identical neutral pills, only the
             border/text distinguishes the destructive action. */

          /* Login — primary action, lavender accent. */
          #login_button,
          button.suggested-action {
            background-image: none;
            background-color: alpha(@mantle, 0.9);
            border: 1px solid alpha(@lavender, 0.7);
            color: @lavender;
            border-radius: 24px;
            padding: 9px 28px;
            font-weight: 600;
          }

          #login_button:hover,
          button.suggested-action:hover {
            background-color: alpha(@surface0, 0.9);
            border-color: @lavender;
            color: @lavender;
          }

          /* Reboot — neutral action, blue accent. */
          #reboot_button {
            background-image: none;
            background-color: alpha(@mantle, 0.9);
            border: 1px solid alpha(@blue, 0.55);
            border-radius: 24px;
            color: @subtext1;
            padding: 9px 24px;
          }

          #reboot_button:hover {
            background-color: alpha(@surface0, 0.9);
            border-color: @blue;
            color: @text;
          }

          /* Power Off — destructive, red accent. Selectors split
             from #reboot_button so destructive never bleeds onto
             Reboot. */
          #poweroff_button,
          button.destructive-action {
            background-image: none;
            background-color: alpha(@mantle, 0.9);
            border: 1px solid alpha(@red, 0.6);
            border-radius: 24px;
            color: @subtext1;
            padding: 9px 24px;
          }

          #poweroff_button:hover,
          button.destructive-action:hover {
            background-color: alpha(@surface0, 0.9);
            border-color: @red;
            color: @text;
          }

          /* Error info bar — uses Catppuccin red, less alarming than
             Adwaita's default error styling. */
          #error_info {
            background-color: alpha(@red, 0.22);
            color: @red;
            border-radius: 20px;
            padding: 10px 18px;
          }

          /* Combo boxes (user / session pickers) get the same pill
             treatment as inputs — fully opaque to match. */
          combobox > button.combo {
            background-image: none;
            background-color: @base;
            border: 1px solid alpha(@overlay0, 0.5);
            border-radius: 24px;
            padding: 6px 16px;
            color: @text;
          }
        '';

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

      security.polkit.enable = true;

      hardware.bluetooth.enable = true;

      services.gnome.gnome-keyring.enable = true;

      # Force-stop fprintd before s2idle so its in-flight Verify session
      # (bound to the pre-suspend Goodix USB handle) is torn down cleanly.
      # Without this, the kernel re-enumerates the device on resume but
      # fprintd keeps the stale handle, and noctalia's next Claim returns
      # "Device was already claimed". fprintd is dbus-activated, so the
      # first call after resume auto-launches a fresh instance.
      systemd.services.fprintd.unitConfig = {
        Conflicts = [ "sleep.target" ];
        Before = [ "sleep.target" ];
      };

      services.upower.enable = true;
      services.power-profiles-daemon.enable = lib.mkDefault true;

      # Lid/power-key handling comes from `desktop-base`. Noctalia's
      # built-in idle/lockOnSuspend is disabled in settings.json so
      # hypridle (configured in the home module) is the sole coordinator
      # for idle timeouts and logind PrepareForSleep hooks.

      hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
    };
}
