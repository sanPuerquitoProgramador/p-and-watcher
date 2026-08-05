# p + w — monitor de sesiones tmux con Claude Code

Dos scripts para dejar de entrar sesión por sesión a ver cómo va cada agente.

- `p` — lista tus sesiones tmux y te dice cuál está trabajando, cuál terminó
  y cuál está esperando que apruebes algo. `p 3` te conecta a la número 3.
- `w` — watcher continuo: refresca la lista cada 15s y hace sonar la campana
  de la terminal cuando una sesión pasa a pedirte permiso.

## Requisitos

- tmux
- Claude Code corriendo dentro de sesiones tmux
- bash (funciona con el 3.2 de macOS, no hace falta instalar nada)

## Instalación

1. Copia `p.sh` y `watch.sh` a `~/ops/`:

   mkdir -p ~/ops
   cp p.sh watch.sh ~/ops/
   chmod +x ~/ops/*.sh

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

Salida:

    1) Canonico         ⏸ TE ESPERA
    2) Dobre            ✓ terminó
    3) Findly           ↓ trabajando
    4) Luun

Prioridad cuando una sesión tiene varios paneles: **te espera > trabajando >
terminó**. Siempre se muestra lo que te bloquea.

## Sonido del watcher

`w` manda un bell (`\a`) cuando una sesión *pasa* a estado "te espera" — solo en
la transición, no cada ciclo. Si trabajas por SSH, el bell viaja y suena en tu
máquina local, no en el servidor.

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
