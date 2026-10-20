_: {
  flake.homeModules.mr-boxington =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.programs.mr-boxington;
      toml = pkgs.formats.toml { };
      shim = "${cfg.package}/libexec/mbx/cargo";
      # mbx resolves both files through `dirs::config_dir`, which ignores XDG on macOS.
      configDir = if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support" else ".config";
    in
    {
      options.programs.mr-boxington = {
        enable = lib.mkEnableOption "mbx (Mr Boxington), a shared build cache for Cargo";

        package = lib.mkPackageOption pkgs "mbx" { };

        cargoShim = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Put the package's Cargo shim ahead of every other `cargo` on PATH, so
            plain `cargo` runs through mbx. The shim delegates to the next `cargo`
            on PATH (rustup's proxy), so rustup still picks the toolchain. This
            replaces `mbx setup` and mise's `mr_boxington` option.
          '';
        };

        enableDirenvIntegration = lib.mkOption {
          type = lib.types.bool;
          default = config.programs.direnv.enable;
          defaultText = lib.literalExpression "config.programs.direnv.enable";
          description = ''
            Move the Cargo shim back in front of PATH after direnv's `use flake` or
            `use nix` loads a dev shell, so plain `cargo` there runs through mbx and
            delegates to the shell's own toolchain. A bare `nix develop` still puts
            its `cargo` first; use `mbx build` there.
          '';
        };

        rustAnalyzer = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Write the user-level `rust-analyzer.toml` that `mbx setup` would, sending
            rust-analyzer's check through the shim into `target/rust-analyzer`.
            rust-analyzer flags the key as invalid on load but still applies it.
          '';
        };

        settings = lib.mkOption {
          inherit (toml) type;
          default = { };
          example = {
            gc.max_total_size = "50GiB";
            scheduler.reserve_cpus = 2;
            target.evict_first = [ ".claude/worktrees" ];
          };
          description = ''
            mbx's global `config.toml`. A non-empty value makes the file read-only,
            so `mbx settings set` stops working; `MBX_*` variables still override it.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ cfg.package ];

        # sessionPath prepends, and mkBefore keeps the shim ahead of ~/.cargo/bin.
        home.sessionPath = lib.mkIf cfg.cargoShim (lib.mkBefore [ (dirOf shim) ]);

        # direnv sources lib/*.sh in glob order, so this wraps nix-direnv's
        # `use_flake` from hm-nix-direnv.sh before any .envrc runs.
        xdg.configFile."direnv/lib/mbx.sh" = lib.mkIf (cfg.cargoShim && cfg.enableDirenvIntegration) {
          text = ''
            for __mbx_use in use_flake use_nix; do
              if declare -f "$__mbx_use" >/dev/null; then
                eval "__mbx_orig_$(declare -f "$__mbx_use")"
                eval "$__mbx_use() { __mbx_orig_$__mbx_use \"\$@\" && PATH_add ${dirOf shim}; }"
              fi
            done
            unset __mbx_use
          '';
        };

        home.file = {
          "${configDir}/mbx/config.toml" = lib.mkIf (cfg.settings != { }) {
            source = toml.generate "mbx-config.toml" cfg.settings;
          };
          "${configDir}/rust-analyzer/rust-analyzer.toml" = lib.mkIf cfg.rustAnalyzer {
            source = toml.generate "rust-analyzer.toml" {
              check.overrideCommand = [
                shim
                "check"
                "--workspace"
                "--all-targets"
                "--target-dir"
                "target/rust-analyzer"
                "--message-format=json"
              ];
            };
          };
        };
      };
    };
}
