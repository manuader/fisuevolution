# Sesión 2026-10-06 (noche) — E0: el oráculo del run de la 2.0

Primera sesión de ejecución de `Docs/PLAN-v2.md`. La despertó el dueño ("empezá con la
implementación"), no el cron del relevo. La E0 era una sola cosa: un comando que diga verde o
rojo, para que cada épica tenga contra qué aterrizar.

## Qué se hizo

- **`Tools/v2/oraculo.sh rapido|completo [--limpio]`**: la receta de HANDOFF §6 hecha comando.
  - `rapido`: EconomyKit + `xcodegen` + build-for-testing + unit en iOS 26.5.
  - `completo`: además, Store en 18.6 (unit y UI), UI en 26.5, el pipeline de arte, el
    `pacing-sim` (reporte) y el Release para dispositivo sin warnings del compilador.
  - Crea sus propios simuladores por UDID y los borra al salir, con un DerivedData propio del
    worktree (`build/DD-oraculo`).
  - Deja los logs, los `.xcresult` y un `resumen.txt` en `build/oraculo/<fecha>-<modo>/`.
- **`Tools/v2/rojos.py`**: juzga cada suite contra **`Tools/v2/rojos-declarados.txt`**.
  - Un rojo que no está en la lista pone el oráculo en rojo.
  - Uno de la lista que deja de fallar se avisa.
  - **Cero tests corridos también es rojo**: un `-only-testing` mal escrito corre cero tests y
    Xcode lo da por bueno.
- **`Docs/biblia-visitantes.md`** (preparación de E8, por un subagente): los 8 visitantes nuevos,
  los 10 especiales y las 3 familias. Los 222 prompts quedaron en
  `~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2/`, **sin commitear**:
  ese repo tiene cambios ajenos sin commitear.
- **El plan de implementación de E1**: `Docs/superpowers/plans/2026-10-06-v2-e1-correcciones-criticas.md`.
  Son 16 tareas en olas, con una sección final de dudas para el dueño.

## Línea de base (oráculo `completo`, `0442022` + el oráculo, 2026-10-06 20:25)

| Suite | Resultado |
|---|---|
| EconomyKit | 267 verdes |
| unit (26.5) | 473 verdes + 1 rojo declarado (`theOwnersTargetsAreMet`) |
| Store unit (18.6) | 12 verdes |
| UI (26.5) | 57 verdes |
| `StoreUITests` (18.6) | 2 verdes |
| pipeline | 24 verdes + 1 rojo declarado (arte calado) |
| `pacing-sim` | Dios en 30,73 h activas · 13 reencarnaciones (bot ×1,0) |
| Release | compila; 0 warnings del compilador |

Los tiempos de esa corrida: build en frío 106 s, unit 411 s, Store 197 s, UI 1.515 s, StoreUI
114 s. Un `completo` entero tarda **~45 min**.

## Trampas nuevas

- **El bash de macOS es 3.2.** Con `set -u`, un array vacío cuenta como variable sin definir y
  aborta el script. Y una función que agrega a un array global adentro de `$(…)` corre en un
  subshell: el simulador nunca llegaba a la lista de limpieza y quedaba huérfano.
- **TextureAtlas avisa con `warning:`** cada vez que parte un atlas grande en varias hojas
  (`earth.atlas` ×4/×6, `ui.atlas` ×2, `cosmic.atlas` ×2/×4). No son warnings del compilador:
  el oráculo los descuenta.
- **Los subagentes de una sesión aislada en un worktree no pueden usar git en otro worktree.**
  El guard de la sesión los fija al worktree desde el que se los lanzó. Rechaza cualquier Bash con
  cwd en otro worktree (hasta un `echo`), y también `git -C` hacia allá. Pueden leer y escribir
  archivos con rutas absolutas, y correr comandos sin git desde el cwd fijado.
  - Consecuencia: **los subagentes en paralelo dejan su trabajo sin commitear**, junto con un
    plan de commits, y el orquestador commitea entrando con `EnterWorktree(path:)` a cada
    worktree.
  - El oráculo se corre con su ruta absoluta.

## Qué queda

- Integrar los cinco frentes en paralelo (E8 pipeline, E8 audio, E7a infraestructura, E3 i18n y
  E10 docs) y arrancar E1 según su plan.
- Gates del dueño: el piloto de 5 imágenes y el batch con la app de Claude cerrada.

## Para el HANDOFF general

- **§4**: "2026-10-06 (noche) — E0 de la 2.0: el oráculo `Tools/v2/oraculo.sh` y la línea de
  base (ver tabla de esta sesión)".
- **§6**: el oráculo reemplaza la receta a mano: `Tools/v2/oraculo.sh rapido` mientras se itera, y
  `completo` para cerrar una épica.
- **§7**: las tres trampas de arriba (bash 3.2, avisos de TextureAtlas y git de los subagentes).
- **§9**: este doc, el plan de E1 y `Docs/biblia-visitantes.md`.
