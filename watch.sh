#!/usr/bin/env bash
# w — watcher de sesiones. Notifica solo en la transición a "te espera".
set -uo pipefail

INTERVAL="${1:-15}"
case "$INTERVAL" in
  ''|*[!0-9]*) echo "Uso: w [segundos]  (entero positivo)" >&2; exit 1 ;;
esac
[ "$INTERVAL" -lt 1 ] && { echo "Uso: w [segundos]  (entero positivo)" >&2; exit 1; }

trap 'printf "\033[?25h\n"; exit 0' INT TERM
trap 'printf "\033[?25h"' EXIT
printf "\033[?25l"
clear

PREV=""     # sesiones que esperaban en el ciclo anterior (para la campana)
SINCE=""    # "nombre:epoch" de cuándo empezó a esperar cada sesión
FIRST=1     # el primer ciclo es línea base: no suena

while true; do
  read -r NOW CLOCK <<< "$(date '+%s %H:%M:%S')"
  SESS=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | sort)

  BUSY=""; WAIT=""; DONE=""
  while read -r s pane cmd; do
    case "$cmd" in [0-9]*.[0-9]*.[0-9]*) ;; *) continue ;; esac
    txt=$(tmux capture-pane -p -t "$pane" 2>/dev/null)
    case "$txt" in *"✻ "*" for "*) DONE="$DONE $s" ;; esac
    case "$txt" in *"↓ "*) BUSY="$BUSY $s" ;; esac
    case "$txt" in *"❯ 1."*|*"Esc to cancel"*) WAIT="$WAIT $s" ;; esac
  done < <(tmux list-panes -a -F '#{session_name} #{pane_id} #{pane_current_command}' 2>/dev/null)

  # Conserva el timestamp de las que ya esperaban; estrena el de las nuevas.
  NEW_SINCE=""
  for s in $WAIT; do
    since=""
    for e in $SINCE; do
      case "$e" in "$s":*) since="${e#*:}" ;; esac
    done
    [ -z "$since" ] && since=$NOW
    NEW_SINCE="$NEW_SINCE $s:$since"
  done
  SINCE="$NEW_SINCE"

  if [ -z "$FIRST" ]; then
    for s in $WAIT; do
      case " $PREV " in
        *" $s "*) ;;   # ya estaba esperando, no repetir
        *) printf "\a" ;;
      esac
    done
  fi
  PREV="$WAIT"

  # Ancho de la guía de puntos, según el nombre más largo.
  WIDTH=8
  while read -r s; do
    [ ${#s} -gt $WIDTH ] && WIDTH=${#s}
  done <<< "$SESS"

  printf "\033[H\033[2m%s\033[0m\033[K\n\033[K\n" "$CLOCK"

  if [ -z "$SESS" ]; then
    printf "  \033[2mNo hay sesiones.\033[0m\033[K\n"
  else
    while read -r s; do
      st=""; stc=""; hot=""
      case " $DONE " in *" $s "*) st="✓ terminó";    stc="32" ;; esac
      case " $BUSY " in *" $s "*) st="↓ trabajando"; stc="36" ;; esac
      case " $WAIT " in
        *" $s "*)
          since=$NOW
          for e in $SINCE; do
            case "$e" in "$s":*) since="${e#*:}" ;; esac
          done
          age=$((NOW - since))
          if   [ $age -lt 60 ];   then a="${age}s"
          elif [ $age -lt 3600 ]; then a="$((age / 60))m"
          else                         a="$((age / 3600))h"
          fi
          st="⏸ TE ESPERA $a"; stc="1;33"; hot=1
          ;;
      esac

      if [ -z "$st" ]; then
        # Sin status no hay a dónde guiar: nombre tenue y ya.
        printf "  \033[2m%s\033[0m\033[K\n" "$s"
        continue
      fi

      # El punto medio es multibyte: bash 3.2 corta ${var:0:n} por bytes, así
      # que la guía se arma sumando. Las llaves de ${lead} son obligatorias —
      # sin ellas el primer byte del · se pega al nombre de la variable.
      n=$((WIDTH - ${#s} + 2))
      [ $n -lt 2 ] && n=2
      lead=""; i=0
      while [ $i -lt $n ]; do lead="${lead}·"; i=$((i + 1)); done

      if [ -n "$hot" ]; then
        printf "  %s \033[2m%s\033[0m \033[%sm%s\033[0m\033[K\n" "$s" "$lead" "$stc" "$st"
      else
        printf "  \033[2m%s %s \033[%sm%s\033[0m\033[K\n" "$s" "$lead" "$stc" "$st"
      fi
    done <<< "$SESS"
  fi

  printf "\033[K\n\033[J"

  r=$INTERVAL
  while [ $r -gt 0 ]; do
    printf "\r  \033[2mrefresh en %2ds\033[0m\033[K" "$r"
    sleep 1
    r=$((r - 1))
  done

  FIRST=""
done
