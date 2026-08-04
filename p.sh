#!/usr/bin/env bash
set -uo pipefail

SESS=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | sort)
[ -z "$SESS" ] && { echo "No hay sesiones."; exit 0; }

if [ $# -ge 1 ]; then
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    t=$(echo "$SESS" | sed -n "$1p")
  else
    t=$(echo "$SESS" | grep -i -m1 "$1")
  fi
  [ -z "$t" ] && { echo "No la encontré."; exit 1; }
  if [ -n "${TMUX:-}" ]; then exec tmux switch-client -t "=$t"
  else exec tmux attach -d -t "=$t"; fi
fi

BUSY=""; WAIT=""; DONE=""
while read -r s pid cmd; do
  case "$cmd" in [0-9]*.[0-9]*.[0-9]*) ;; *) continue ;; esac
  txt=$(tmux capture-pane -p -t "$pid" 2>/dev/null)
  case "$txt" in *"✻ "*" for "*) DONE="$DONE $s" ;; esac
  case "$txt" in *"↓ "*) BUSY="$BUSY $s" ;; esac
  case "$txt" in *"❯ 1."*|*"Esc to cancel"*)       WAIT="$WAIT $s" ;; esac
done < <(tmux list-panes -a -F '#{session_name} #{pane_id} #{pane_current_command}')

i=1
echo "$SESS" | while read -r s; do
  st=""
  case " $DONE " in *" $s "*) st="✓" ;; esac
  case " $BUSY " in *" $s "*) st="⏳" ;; esac
  case " $WAIT " in *" $s "*) st="⏸ TE ESPERA" ;; esac
  printf "%2d) %-16s %s\n" "$i" "$s" "$st"
  i=$((i+1))
done
