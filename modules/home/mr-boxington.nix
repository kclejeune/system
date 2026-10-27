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
      # mbx resolves both files through `dirs::config_dir`, which ignores XDG on macOS.
      configDir = if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support" else ".config";
      # `mbx doctor` only recognizes the shim where `mbx setup` installs it, under
      # `dirs::data_local_dir`, not the package's libexec wrapper.
      shimDir = "${
        if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support" else ".local/share"
      }/mbx/bin";
      shim = "${config.home.homeDirectory}/${shimDir}/cargo";
      # Let the packaged mbx write its own launcher and `mbx-target`, so the bytes
      # match what doctor compares against across upgrades. Outside a mise shell,
      # setup installs only the shim and edits no mise config.
      setupShim = pkgs.runCommand "mbx-cargo-shim" { nativeBuildInputs = [ cfg.package ]; } ''
        export HOME=$TMPDIR
        unset XDG_DATA_HOME XDG_CONFIG_HOME MISE_CONFIG_FILE
        mbx setup --yes >/dev/null
        cp -r "$HOME/${shimDir}" $out
      '';
      frontShim = ''
        __mbx_shim=${lib.escapeShellArg (dirOf shim)}
        PATH="$__mbx_shim''${PATH:+:}''${PATH//"$__mbx_shim:"/}"
        unset __mbx_shim
      '';
    in
    {
      options.programs.mr-boxington = {
        enable = lib.mkEnableOption "mbx (Mr Boxington), a shared build cache for Cargo";

        package = lib.mkPackageOption pkgs "mbx" { };

        cargoShim = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Install the Cargo shim where `mbx setup` would and put it ahead of
            every other `cargo` on PATH, so plain `cargo` runs through mbx. The
            shim delegates to the next `cargo` on PATH (rustup's proxy), so rustup
            still picks the toolchain. This replaces `mbx setup` and mise's
            `mr_boxington` option.
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

        # sessionPath only runs once per environment, from .zshenv or .profile, and
        # the system rc files run after it: off NixOS, /etc/zsh/zshrc sources
        # nix-daemon.sh, which puts ~/.nix-profile/bin and rustup's cargo back in
        # front. Move the shim forward again once interactive init is done.
        programs.zsh.initContent = lib.mkIf cfg.cargoShim (lib.mkAfter frontShim);
        programs.bash.initExtra = lib.mkIf cfg.cargoShim (lib.mkAfter frontShim);

        # direnv sources lib/*.sh in glob order, so this wraps nix-direnv's
        # `use_flake` from hm-nix-direnv.sh before any .envrc runs.
        xdg.configFile."direnv/lib/mbx.sh" = lib.mkIf (cfg.cargoShim && cfg.enableDirenvIntegration) {
          text = ''
            for __mbx_use in use_flake use_nix; do
              if declare -f "$__mbx_use" >/dev/null; then
                eval "__mbx_orig_$(declare -f "$__mbx_use")"
                eval "$__mbx_use() { __mbx_orig_$__mbx_use \"\$@\" && PATH_add \"${dirOf shim}\"; }"
              fi
            done
            unset __mbx_use
          '';
        };

        home.file = {
          "${shimDir}/cargo" = lib.mkIf cfg.cargoShim { source = "${setupShim}/cargo"; };
          "${shimDir}/mbx-target" = lib.mkIf cfg.cargoShim { source = "${setupShim}/mbx-target"; };
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
