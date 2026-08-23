_: {
  # Declarative mise bootstrap (https://mise.jdx.dev/bootstrap.html).
  #
  # `mise bootstrap` converges the imperative "day-0" surface nix doesn't
  # reach from a home-manager config — OS packages on foreign distros
  # (apt/brew/dnf/pacman), git repo checkouts, login shell, macOS defaults —
  # from `[bootstrap.*]` tables in mise's global config. This module renders
  # those tables declaratively through `programs.mise.globalConfig` (so they
  # land in ~/.config/mise/config.toml alongside any other mise settings)
  # and, optionally, runs `mise bootstrap --yes` as a home-manager
  # activation step so a `home-manager switch` also converges the
  # non-nix layer.
  #
  # Example:
  #   mise.bootstrap = {
  #     enable = true;
  #     packages."apt:build-essential" = "latest";
  #     repos."~/src/dotfiles" = { url = "git@github.com:me/dotfiles.git"; ref = "main"; };
  #     user.login_shell = "/bin/zsh";
  #     hooks."post-packages".run = "echo packages done";
  #   };
  #
  # The activation step is deliberately non-fatal by default: bootstrap
  # needs the network (package indexes, git remotes), and a `home-manager
  # switch` on a plane shouldn't fail because apt couldn't resolve.
  flake.homeModules.mise =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mise.bootstrap;
      tomlFormat = pkgs.formats.toml { };

      # mise expects `[bootstrap.hooks.<phase>] run = "…"`; accept a bare
      # string as shorthand for the common single-command case.
      normalizedHooks = lib.mapAttrs (
        _: hook: if lib.isString hook then { run = hook; } else hook
      ) cfg.hooks;

      # Only render sections that carry values — an empty `[bootstrap.repos]`
      # table is noise in the generated config.toml.
      nonEmpty = lib.filterAttrs (_: v: v != { } && v != null);

      bootstrapConfig =
        nonEmpty {
          packages = cfg.packages;
          repos = cfg.repos;
          mise_shell_activate = cfg.shellActivate;
          hooks = normalizedHooks;
          user = cfg.user;
          macos = nonEmpty { defaults = cfg.macos.defaults; } // cfg.macos.extraConfig;
          linux =
            lib.optionalAttrs (cfg.linux.systemdUnits != { }) { systemd.units = cfg.linux.systemdUnits; }
            // cfg.linux.extraConfig;
        }
        // cfg.extraConfig;

      misePackage =
        if config.programs.mise.package != null then config.programs.mise.package else pkgs.mise;

      bootstrapFlags = [
        "--yes"
      ]
      ++ lib.optional cfg.run.forceDotfiles "--force-dotfiles"
      ++ lib.optional cfg.run.updatePackageIndexes "--update"
      ++ lib.optionals (cfg.run.only != [ ]) [
        "--only"
        (lib.concatStringsSep "," cfg.run.only)
      ]
      ++ lib.optionals (cfg.run.skip != [ ]) [
        "--skip"
        (lib.concatStringsSep "," cfg.run.skip)
      ];
    in
    {
      options.mise.bootstrap = {
        enable = lib.mkEnableOption "declarative mise bootstrap configuration";

        packages = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            "apt:build-essential" = "latest";
            "brew:postgresql@17" = "latest";
          };
          description = ''
            OS packages for `[bootstrap.packages]`, keyed as
            `<manager>:<package>` (managers: apk, apt, dnf, pacman, brew).
            This is the escape hatch for hosts where nix does NOT own the
            OS package set — don't use it on NixOS, where the same package
            belongs in the system/home config instead.
          '';
        };

        repos = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              freeformType = tomlFormat.type;
              options = {
                url = lib.mkOption {
                  type = lib.types.str;
                  description = "Git URL to clone from.";
                };
                ref = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Branch/tag/rev to check out (repo default when null).";
                };
              };
            }
          );
          default = { };
          example = {
            "~/src/dotfiles" = {
              url = "git@github.com:jdx/dotfiles.git";
              ref = "main";
            };
          };
          description = "Git checkouts for `[bootstrap.repos]`, keyed by destination path.";
          apply = lib.mapAttrs (_: repo: lib.filterAttrs (_: v: v != null) repo);
        };

        shellActivate = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            zprofile = "shims";
            zshrc = "activate";
          };
          description = ''
            `[bootstrap.mise_shell_activate]` — which rc files mise should
            manage activation lines in. Usually unnecessary here: this
            flake's shell modules already wire `mise activate` into the
            home-manager-generated rc files.
          '';
        };

        hooks = lib.mkOption {
          type = lib.types.attrsOf (lib.types.either lib.types.str tomlFormat.type);
          default = { };
          example = {
            "pre-packages" = "softwareupdate --install-rosetta --agree-to-license";
            "post-defaults".run = "killall Dock || true";
          };
          description = ''
            `[bootstrap.hooks.<phase>]` commands. Phases: pre-/post- each of
            packages, repos, dotfiles, defaults, user, tools — plus `final`.
            A bare string is shorthand for `{ run = "…"; }`.
          '';
        };

        user = lib.mkOption {
          type = tomlFormat.type;
          default = { };
          example = {
            login_shell = "/bin/zsh";
          };
          description = "`[bootstrap.user]` settings (e.g. login_shell).";
        };

        macos = {
          defaults = lib.mkOption {
            type = lib.types.attrsOf tomlFormat.type;
            default = { };
            example = {
              "com.apple.finder".AppleShowAllFiles = true;
            };
            description = ''
              `[bootstrap.macos.defaults]`, keyed by defaults domain. On
              nix-darwin hosts prefer `system.defaults`; this is for
              standalone home-manager on a Mac nix-darwin doesn't manage.
            '';
          };
          extraConfig = lib.mkOption {
            type = tomlFormat.type;
            default = { };
            description = "Extra tables merged into `[bootstrap.macos]` (e.g. launchd agents).";
          };
        };

        linux = {
          systemdUnits = lib.mkOption {
            type = lib.types.attrsOf tomlFormat.type;
            default = { };
            example = {
              my-sync = {
                description = "sync files";
                exec_start = "~/.local/bin/my-sync --watch";
                restart = "on-failure";
              };
            };
            description = ''
              `[bootstrap.linux.systemd.units]` user services. Prefer
              `systemd.user.services` where home-manager manages them; this
              covers foreign distros where mise should own the unit files.
            '';
          };
          extraConfig = lib.mkOption {
            type = tomlFormat.type;
            default = { };
            description = "Extra tables merged into `[bootstrap.linux]`.";
          };
        };

        extraConfig = lib.mkOption {
          type = tomlFormat.type;
          default = { };
          description = ''
            Escape hatch merged verbatim into the `[bootstrap]` table for
            mise features this module doesn't type yet.
          '';
        };

        run = {
          onActivation = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Run `mise bootstrap --yes` as a home-manager activation step
              (after files are written, so mise reads the fresh config).
              Disable to only render the config and run bootstrap manually.
            '';
          };
          failOnError = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether a failing `mise bootstrap` aborts activation.
              Off by default: bootstrap needs the network, and an offline
              `home-manager switch` should still succeed.
            '';
          };
          only = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [
              "repos"
              "user"
            ];
            description = "Restrict the activation run to these bootstrap parts (`--only`).";
          };
          skip = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "packages" ];
            description = "Bootstrap parts to skip during the activation run (`--skip`).";
          };
          forceDotfiles = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Pass `--force-dotfiles` (overwrite conflicting dotfile targets).";
          };
          updatePackageIndexes = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Pass `--update` (refresh package-manager metadata first).";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # Route the rendered tables through programs.mise so they merge into
        # the same ~/.config/mise/config.toml as any other global settings.
        programs.mise.enable = lib.mkDefault true;
        # Shell activation is already wired by this flake's shell modules
        # (oh-my-zsh `mise` plugin, bash initExtra) — don't double-activate.
        programs.mise.enableBashIntegration = lib.mkDefault false;
        programs.mise.enableZshIntegration = lib.mkDefault false;
        programs.mise.enableFishIntegration = lib.mkDefault false;
        programs.mise.enableNushellIntegration = lib.mkDefault false;

        programs.mise.globalConfig = lib.mkIf (bootstrapConfig != { }) {
          bootstrap = bootstrapConfig;
        };

        home.activation.miseBootstrap = lib.mkIf cfg.run.onActivation (
          # After writeBoundary so the generation's config.toml is live;
          # after installPackages (when it exists — standalone HM) so the
          # mise binary itself is in place on first-ever activation.
          lib.hm.dag.entryAfter [ "writeBoundary" "installPackages" ] ''
            verboseEcho "Converging mise bootstrap"
            run ${lib.escapeShellArg (lib.getExe misePackage)} bootstrap ${lib.escapeShellArgs bootstrapFlags}${
              lib.optionalString (
                !cfg.run.failOnError
              ) " || verboseEcho 'warning: mise bootstrap failed (network?); continuing activation'"
            }
          ''
        );
      };
    };
}
