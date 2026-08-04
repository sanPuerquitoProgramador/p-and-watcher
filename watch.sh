#!/usr/bin/env bash
# w — watcher de sesiones. Notifica solo en la transición a "te espera".
set -uo pipefail
STATEFILE="/tmp/.p-watch-state"
INTERVAL="${1:-15}"

while true; do
  BUSY=""; WAIT=""; DONE=""
  while read -r s pid cmd; do
    case "$cmd" in [0-9]*.[0-9]*.[0-9]*) ;; *) continue ;; esac
    txt=$(tmux capture-pane -p -t "$pid" 2>/dev/null)
    case "$txt" in *"✻ "*" for "*) DONE="$DONE $s" ;; esac
    case "$txt" in *"↓ "*) BUSY="$BUSY $s" ;; esac
    case "$txt" in *"❯ 1."*|*"Esc to cancel"*) WAIT="$WAIT $s" ;; esac
  done < <(tmux list-panes -a -F '#{session_name} #{pane_id} #{pane_current_command}' 2>/dev/null)

  PREV=$(cat "$STATEFILE" 2>/dev/null || echo "")
  for s in $WAIT; do
    case " $PREV " in
      *" $s "*) ;;   # ya estaba esperando, no repetir
      *) printf "\a" ;;
    esac
  done
  echo "$WAIT" > "$STATEFILE"

  clear
  printf "\033[2m%s\033[0m\n\n" "$(date '+%H:%M:%S')"
  tmux list-sessions -F '#{session_name}' 2>/dev/null | sort | while read -r s; do
    st=""
    case " $DONE " in *" $s "*) st="\033[2m✓ terminó\033[0m" ;; esac
    case " $BUSY " in *" $s "*) st="\033[2m↓ trabajando\033[0m" ;; esac
    case " $WAIT " in *" $s "*) st="\033[1;33m⏸ TE ESPERA\033[0m" ;; esac
    printf "  %-16s $st\n" "$s"
  done
  sleep "$INTERVAL"
done
