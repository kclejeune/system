_: {
  flake.homeModules.direnv =
    { config, lib, ... }:
    let
      cfg = config.programs.direnv.pathGuard;
      # mise's hook rebuilds PATH after direnv, burying the .envrc's entries
      # (e.g. a dev shell) behind mise's tools and the base PATH. Move them back
      # ahead of those, leaving later additions like a virtualenv in front.
      # Possible extension: also keep `pathGuard.prepend` first outside an .envrc,
      # where mise's tools still go ahead of it; that would replace
      # mr-boxington's frontShim.
      zshGuard = /* zsh */ ''
        _direnv_path_guard() {
          [[ -n ''${DIRENV_PATH_PREFIX-} ]] || return 0
          local -a front=(''${(s.:.)DIRENV_PATH_PREFIX}) out=()
          local -A isfront isbase
          local entry placed=0
          for entry in $front; do isfront[$entry]=1; done
          for entry in ''${(s.:.)DIRENV_PATH_BASE-}; do isbase[$entry]=1; done
          for entry in $path; do
            [[ -n $entry ]] || continue
            if (( ! placed )) && [[ -n ''${isfront[$entry]-} || -n ''${isbase[$entry]-} || $entry == */mise/(installs|shims)* ]]; then
              out+=($front)
              placed=1
            fi
            [[ -n ''${isfront[$entry]-} ]] || out+=($entry)
          done
          (( placed )) || out+=($front)
          [[ ''${(j.:.)out} == "$PATH" ]] || path=($out)
        }
        # chpwd too: `cd repo && cmd` runs no precmd before `cmd`.
        precmd_functions+=(_direnv_path_guard)
        chpwd_functions+=(_direnv_path_guard)
      '';
      bashGuard = /* bash */ ''
        _direnv_path_guard() {
          [[ -n ''${DIRENV_PATH_PREFIX-} ]] || return 0
          local -A isfront=() isbase=()
          local -a front base current out=()
          local entry placed=
          IFS=: read -ra front <<<"$DIRENV_PATH_PREFIX"
          IFS=: read -ra base <<<"''${DIRENV_PATH_BASE-}"
          IFS=: read -ra current <<<"$PATH"
          for entry in "''${front[@]}"; do [[ -n $entry ]] && isfront[$entry]=1; done
          for entry in "''${base[@]}"; do [[ -n $entry ]] && isbase[$entry]=1; done
          for entry in "''${current[@]}"; do
            [[ -n $entry ]] || continue
            if [[ -z $placed && ( -n ''${isfront[$entry]-} || -n ''${isbase[$entry]-} || $entry == */mise/installs/* || $entry == */mise/shims ) ]]; then
              out+=("''${front[@]}")
              placed=1
            fi
            [[ -n ''${isfront[$entry]-} ]] || out+=("$entry")
          done
          [[ -n $placed ]] || out+=("''${front[@]}")
          local IFS=:
          [[ "''${out[*]}" == "$PATH" ]] || PATH="''${out[*]}"
        }
        # Associative arrays need bash 4; macOS's /bin/bash is 3.2.
        if (( BASH_VERSINFO[0] < 4 )); then
          :
        elif [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a"* ]]; then
          PROMPT_COMMAND+=(_direnv_path_guard)
        else
          PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND;}_direnv_path_guard"
        fi
      '';
    in
    {
      options.programs.direnv.pathGuard.prepend = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Directories to put first on PATH, in order, after any .envrc that
          changes PATH, so they also lead what the shell guards restore.
        '';
      };

      config.programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
        stdlib = /* bash */ ''
          # stolen from @i077; store .direnv in cache instead of project dir
          declare -A direnv_layout_dirs
          direnv_layout_dir() {
              echo "''${direnv_layout_dirs[$PWD]:=$(
                  echo -n "${config.xdg.cacheHome}/direnv/layouts/"
                  echo -n "$PWD" | shasum | cut -d ' ' -f 1
              )}"
          }

          # direnv runs every .envrc, nested ones included, through source_env.
          # When the outermost call returns, record what it prepended to PATH
          # and the PATH it started from, for the shell guards.
          eval "__path_guard_orig_$(declare -f source_env)"
          __path_guard_depth=0
          source_env() {
            local before=$PATH status=0
            __path_guard_depth=$((__path_guard_depth + 1))
            __path_guard_orig_source_env "$@" || status=$?
            __path_guard_depth=$((__path_guard_depth - 1))
            if [[ $__path_guard_depth == 0 ]]; then
              ${lib.optionalString (
                cfg.prepend != [ ]
              ) ''[[ $PATH == "$before" ]] || PATH_add ${lib.escapeShellArgs cfg.prepend}''}
              __path_guard_record "$before"
            fi
            return "$status"
          }
          __path_guard_record() {
            local before=$1 entry seen=: added=
            local -a entries recorded=()
            if [[ $PATH == *":$before" ]]; then
              added=''${PATH%":$before"}
            else
              IFS=: read -ra entries <<<"$PATH"
              for entry in "''${entries[@]}"; do
                [[ ":$before:" == *":$entry:"* ]] || added+="''${added:+:}$entry"
              done
            fi
            IFS=: read -ra entries <<<"$added"
            for entry in "''${entries[@]}"; do
              [[ -n $entry && $seen != *":$entry:"* ]] || continue
              seen+="$entry:"
              recorded+=("$entry")
            done
            (( ''${#recorded[@]} )) || return 0
            local IFS=:
            export DIRENV_PATH_PREFIX="''${recorded[*]}" DIRENV_PATH_BASE="$before"
          }
        '';
      };

      config.programs.zsh.initContent = lib.mkAfter zshGuard;
      config.programs.bash.initExtra = lib.mkAfter bashGuard;
    };
}
