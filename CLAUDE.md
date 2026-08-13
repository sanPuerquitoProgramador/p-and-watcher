# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es

Dos scripts de bash sin dependencias (solo tmux) para monitorear sesiones tmux que corren Claude Code:

- `p.sh` — lista las sesiones con su estado; con argumento se conecta a una (por número o match parcial de nombre).
- `watch.sh` — watcher continuo: refresca la lista cada N segundos y suena la campana (`\a`) cuando una sesión pasa a estado "te espera".
- `Kobold.json` — perfil de iTerm2 (ventana flotante con hotkey global). Se importa manualmente en iTerm; ningún script lo lee.

## Comandos

No hay build, lint ni tests. Los scripts se prueban corriéndolos contra sesiones tmux reales con Claude Code adentro:

    ./p.sh            # listado de sesiones con estado
    ./p.sh 3          # conectarse a la sesión #3
    ./p.sh nombre     # conectarse por match parcial de nombre
    ./watch.sh        # watcher, refresco cada 15s
    ./watch.sh 30     # refresco cada 30s

Chequeo de sintaxis: `bash -n p.sh watch.sh`

**Restricción dura:** todo debe funcionar con bash 3.2 (el que trae macOS). Nada de arrays asociativos, `${var,,}` ni otras features de bash 4+.

La instalación de este usuario tiene `~/ops/p.sh` y `~/ops/watch.sh` como **symlinks** a este repo, con alias `p` y `w` en `~/.zshrc` (líneas 123 y 125). Editar el repo es editar lo que corre: no hace falta copiar nada, y el repo no puede moverse ni borrarse sin romper los aliases.

**Nunca uses `git checkout -- <archivo>` para deshacer una edición de prueba en este repo.** El trabajo en curso suele estar sin commitear, así que el checkout no revierte tu línea de prueba: restaura HEAD y borra todo lo no commiteado. Para quitar algo que acabas de agregar, edita el archivo.

## Arquitectura

### Detección de estados (el corazón de ambos scripts)

Ambos scripts contienen el mismo bloque de detección, **duplicado a propósito**: si ajustas los patrones en uno, replica el cambio en el otro.

El bloque recorre `tmux list-panes -a`, considera solo los panes cuyo `pane_current_command` parece número de versión (`[0-9]*.[0-9]*.[0-9]*` — así se llama el proceso de Claude Code; los panes con shell se ignoran), captura el texto visible con `tmux capture-pane -p` y clasifica por patrones de la TUI de Claude Code:

| Estado | Patrón |
|--------|--------|
| te espera (WAIT) | `❯ 1.` o `Esc to cancel` |
| trabajando (BUSY) | `↓ ` |
| terminó (DONE) | `✻ ... for ` |

Puntos no obvios:

- **La prioridad de estados (te espera > trabajando > terminó) se implementa por el orden de asignación**: el último `case` que asigna `st` gana, por eso DONE se evalúa primero y WAIT al final. No reordenar esos `case`.
- Los patrones están acoplados a la interfaz de Claude Code; si Claude Code cambia su TUI, se rompen. Para diagnosticar: `tmux capture-pane -p -t Sesion | tail -5` y ajustar los `case`.
- Las sesiones se listan siempre con `sort` alfabético para que los números sean estables entre corridas; `p.sh N` depende de ese mismo orden.

### watch.sh

Mantiene tres piezas de estado entre ciclos, todas en memoria (no hay archivos temporales):

- `PREV` — las sesiones que esperaban en el ciclo anterior. El bell suena solo en la *transición* a "te espera", no en cada refresco.
- `SINCE` — lista `nombre:epoch` con cuándo empezó a esperar cada sesión, para mostrar la antigüedad. Se usa `:` como separador porque tmux no lo permite en nombres de sesión. Como bash 3.2 no tiene arrays asociativos, la búsqueda es un `case` sobre la lista.
- `FIRST` — el primer ciclo es línea base y no suena: al arrancar el watcher ya estás viendo la pantalla.

El redibujado es en sitio (`\033[H` + `\033[K` por línea + `\033[J` al final), no `clear`, para que la ventana flotante no parpadee. El `sleep $INTERVAL` es un loop de `sleep 1` que reescribe solo la línea del contador; la detección sigue corriendo una vez por intervalo.

**Trampa con UTF-8 en bash 3.2:** al construir la guía de puntos, `${lead}` necesita llaves. Sin ellas, `"$lead·"` hace que bash absorba el primer byte del `·` (0xC2) dentro del nombre de la variable y falle con *unbound variable*. Por la misma razón la guía se arma sumando en un loop y no con `${var:0:n}`, que corta por bytes y partiría el carácter.

**Al probar en la terminal:** el shell interactivo del usuario es zsh, que no hace word splitting en `$VAR` sin comillas. Los scripts corren bajo bash y sí splitean, así que cualquier prueba suelta de esta lógica debe ejecutarse con `bash -c` o un heredoc a `bash`, o dará resultados falsos.

### p.sh

Al conectarse usa `tmux attach -d` (desconecta otros clientes; es intencional, evita que tmux encoja la ventana) o `switch-client` si ya se está dentro de tmux.

## Idioma

README, comentarios y strings de usuario están en español; mantenlo así.
