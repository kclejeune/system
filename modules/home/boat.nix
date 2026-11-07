_: {
  flake.homeModules.boat =
    { pkgs, lib, ... }:
    let
      # The installer's shell function makes `current` and prompt continuation
      # local to each shell. Keep credentials/config writable for `boat login`.
      shellIntegration = /* bash */ ''
        boat() {
          local current_file convo_file current_id current_convo boat_status=0
          current_file="$(${lib.getExe' pkgs.coreutils "mktemp"})" || return
          convo_file="$(${lib.getExe' pkgs.coreutils "mktemp"})" || {
            ${lib.getExe' pkgs.coreutils "rm"} -f "$current_file"
            return 1
          }
          BOAT_CURRENT_ID_FILE="$current_file" BOAT_CURRENT_CONVO_FILE="$convo_file" \
            command boat "$@" || boat_status=$?
          if [ "$boat_status" -eq 0 ]; then
            case "''${1:-}" in
              new|start|fork)
                current_id="$(${lib.getExe' pkgs.coreutils "tr"} -d '[:space:]' < "$current_file")"
                if [ -n "$current_id" ]; then export BOAT_CURRENT_ID="$current_id"; fi
                ;;
              prompt)
                IFS= read -r current_convo < "$convo_file" || true
                if [ -n "$current_convo" ]; then export BOAT_CURRENT_CONVO="$current_convo"; fi
                ;;
            esac
          fi
          ${lib.getExe' pkgs.coreutils "rm"} -f "$current_file" "$convo_file"
          return "$boat_status"
        }
      '';
    in
    {
      home.packages = [ pkgs.boat ];
      programs.bash.initExtra = shellIntegration;
      programs.zsh.initContent = shellIntegration;
    };
}
