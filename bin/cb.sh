#!/usr/bin/env bash
# universal clipboard, stephen@niedzielski.com
is_exec() { case "$0" in */cb) : ;; esac; }

if is_exec; then set -eu; fi

case "${OSTYPE:-}$(uname)" in
 [lL]inux*) ;;
 [dD]arwin*) mac_os=1 ;;
  [cC]ygwin) win_os=1 ;;
          *) echo "Unknown operating system \"${OSTYPE:-}$(uname)\"." >&2; false ;;
esac

is_wayland() { [ "$XDG_SESSION_TYPE" = 'wayland' ]; }
is_mac() { [ "${mac_os-0}" -ne 0 ]; }
is_win() { [ "${win_os-0}" -ne 0 ]; }

if is_mac; then
  alias cbcopy=pbcopy
  alias cbpaste=pbpaste
elif is_win; then
  alias cbcopy=putclip
  alias cbpaste=getclip
else
  if is_wayland; then
    alias cbcopy=wl-copy
    alias cbpaste=wl-paste
  else
    alias cbcopy='xclip -selection clipboard'
    alias cbpaste='xclip -selection clipboard -out'
  fi
fi

cb() {
  if [ -t 0 ]; then
    # stdin is connected to a terminal.
    cbpaste "$@"
  else
    cbcopy "$@"
  fi
}

if is_exec; then cb "$@"; fi

