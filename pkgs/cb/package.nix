{
  pkgs,
  lib,
  ...
}:
pkgs.writeShellScriptBin "cb" ''
  #! ${lib.getExe pkgs.bash}
  # universal clipboard, stephen@niedzielski.com

  shopt -s expand_aliases

  # ------------------------------------------------------------------------------
  # os utils

  case "$OSTYPE$(uname)" in
    [lL]inux*) TUX_OS=1 ;;
   [dD]arwin*) MAC_OS=1 ;;
    [cC]ygwin) WIN_OS=1 ;;
            *) echo "unknown os=\"$OSTYPE$(uname)\"" >&2 ;;
  esac

  is_tux() { [ ''${TUX_OS-0} -ne 0 ]; }
  is_mac() { [ ''${MAC_OS-0} -ne 0 ]; }
  is_win() { [ ''${WIN_OS-0} -ne 0 ]; }
  is_wayland() { [ "$XDG_SESSION_TYPE" = 'wayland' ]; }

  # ------------------------------------------------------------------------------
  # copy and paste

  if is_mac; then
    alias cbcopy=pbcopy
    alias cbpaste=pbpaste
  elif is_win; then
    alias cbcopy=putclip
    alias cbpaste=getclip
  elif is_tux && is_wayland; then
    alias cbcopy='${pkgs.wl-clipboard-rs}/bin/wl-copy'
    alias cbpaste='${pkgs.wl-clipboard-rs}/bin/wl-paste'
  else
    alias cbcopy='${pkgs.xclip}/bin/xclip -selection clipboard'
    alias cbpaste='${pkgs.xclip}/bin/xclip -selection clipboard -out'
  fi

  # ------------------------------------------------------------------------------
  cb() {
    if [ ! -t 0 ] && [ $# -eq 0 ]; then
      # no stdin and no call for --help, blow away the current clipboard and copy
      cbcopy
    else
      cbpaste ''${@:+"$@"}
    fi
  }

  # ------------------------------------------------------------------------------
  if ! return 2>/dev/null; then
    cb ''${@:+"$@"}
  fi
''
