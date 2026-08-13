# p + w — monitor de sesiones tmux con Claude Code

Dos scripts para dejar de entrar sesión por sesión a ver cómo va cada agente.

- `p` — lista tus sesiones tmux y te dice cuál está trabajando, cuál terminó
  y cuál está esperando que apruebes algo. `p 3` te conecta a la número 3.
- `w` — watcher continuo: refresca la lista cada 15s y hace sonar la campana
  de la terminal cuando una sesión pasa a pedirte permiso. Atenúa lo que no te
  necesita, te dice hace cuánto lleva esperando cada sesión y cuánto falta para
  el siguiente refresco.

## Requisitos

- tmux
- Claude Code corriendo dentro de sesiones tmux
- bash (funciona con el 3.2 de macOS, no hace falta instalar nada)

## Instalación

1. Enlaza `p.sh` y `watch.sh` en `~/ops/`, desde donde clonaste el repo:

   mkdir -p ~/ops
   chmod +x p.sh watch.sh
   ln -sfn "$PWD/p.sh"     ~/ops/p.sh
   ln -sfn "$PWD/watch.sh" ~/ops/watch.sh

   Con symlinks, editar el repo es editar lo que corres. Si prefieres copias
   (`cp p.sh watch.sh ~/ops/`), cada cambio necesita volver a copiar, y es fácil
   que se te desincronicen sin darte cuenta. El repo no puede moverse ni
   borrarse mientras existan los symlinks.

2. Agrega los alias a tu shell (`~/.zshrc` o `~/.bashrc`):

   echo 'alias p="$HOME/ops/p.sh"' >> ~/.zshrc
   echo 'alias w="$HOME/ops/watch.sh"' >> ~/.zshrc

3. Recarga:

   source ~/.zshrc

## Uso

   p           # listado
   p 3         # conectarse a la sesión #3
   p luun      # conectarse por nombre (match parcial)
   w           # watcher, refresco cada 15s
   w 30        # watcher, refresco cada 30s

Las sesiones se listan en orden alfabético, así que los números no cambian
entre una corrida y otra.

Salida de `p`:

    1) Canonico         ⏸ TE ESPERA
    2) Dobre            ✓ terminó
    3) Findly           ↓ trabajando
    4) Luun

Salida de `w`:

    17:55:20

      Canonico ······· ⏸ TE ESPERA 4m
      Dobre ·········· ✓ terminó
      Findly ········· ↓ trabajando
      Luun

      refresh en  7s

Prioridad cuando una sesión tiene varios paneles: **te espera > trabajando >
terminó**. Siempre se muestra lo que te bloquea.

## Cómo leer el watcher

Los renglones que no te necesitan van atenuados, así que quien te espera es lo
único con contraste en pantalla: no lo buscas, te salta. La guía de puntos está
para cuando sí quieres leer un renglón tenue sin perder el hilo entre el nombre
y su estado.

El número junto a "TE ESPERA" es **hace cuánto lleva esperando** (`45s`, `4m`,
`2h`). Sirve para el caso molesto: atiendes una sesión, vuelves al watcher y la
pantalla todavía no se refresca. Si dice `4m` es la que acabas de atender; si
dice `8s`, es una nueva. Abajo, el contador te dice cuántos segundos faltan para
que la pantalla vuelva a ser confiable.

Al arrancar, las sesiones que ya estaban esperando empiezan en `0s`: el script
no puede saber desde cuándo llevaban ahí.

## Sonido del watcher

`w` manda un bell (`\a`) cuando una sesión *pasa* a estado "te espera" — solo en
la transición, no cada ciclo. El primer ciclo es línea base y no suena: al
arrancar el watcher ya estás viendo la pantalla, no hace falta que te avise de lo
que ya está ahí. Si trabajas por SSH, el bell viaja y suena en tu máquina local,
no en el servidor.

Si no suena, revisa en tu terminal local que el bell no esté silenciado
(en iTerm: Settings → Profiles → Terminal → "Silence bell" desactivado).

Si el watcher corre dentro de tmux, tmux se queda con el bell. Para que pase:

   tmux set -g visual-bell off
   tmux set -g bell-action any

## Cómo detecta los estados

Lee el panel visible de cada panel donde corre Claude Code y busca:

| Estado      | Patrón            |
|-------------|-------------------|
| te espera   | `❯ 1.` o `Esc to cancel` |
| trabajando  | `↓ `              |
| terminó     | `✻ ... for `      |

Solo escanea paneles cuyo comando activo sea la versión de Claude Code
(`2.1.220` y similares) — los paneles con shell se ignoran.

**Si Claude Code cambia su interfaz, estos patrones dejan de funcionar.** Para
diagnosticar:

   tmux capture-pane -p -t NombreSesion | tail -5

Y ajusta los `case` dentro de los scripts.

## Notas

- `p` usa `attach -d`, que desconecta otros clientes de esa sesión. Es
  intencional: evita que tmux encoja la ventana al tamaño del cliente más chico.
  No mata nada, la sesión sigue corriendo.
- Si ya estás dentro de tmux, `p` usa `switch-client` en vez de `attach`.
- Los patrones están duplicados en los dos archivos. Si ajustas uno, ajusta el
  otro.

## Ventana flotante (opcional, macOS + iTerm2)

`kobold.json` es un perfil de iTerm que abre una ventana flotante, visible en
todos los Spaces, con un atajo global (⌥Espacio por defecto).

Para instalarlo: iTerm → Settings → Profiles → Other Actions → Import JSON
Profiles.

Después edita el perfil y cambia el campo Command (General → Command) para que
apunte a tu host. Si ⌥Espacio ya lo usas para otra cosa, cámbialo en
Profiles → Keys → Hotkey.
