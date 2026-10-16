# Sesión 2026-10-15 — E14b B32: la caja sin el corte de los rayos

Rama `v2i/e14b-b32`, base `5e625057` (integración del relevo 59). Sin compilar (regla del dueño).
Mockup aprobado: opción A (difuminado corto, 15 %).

## Qué se midió (cuadro por cuadro, con AVFoundation)

`obj_paquete_abre.mov` (512×512, HEVC `hvc1` con alfa, 73 cuadros a 24 fps): hasta el cuadro 43 lo más
alto que llega algo es el 5,9–8,4 % (el salto de las tapas); del **cuadro 44** hasta el final los rayos
tocan la fila 0 (29 cuadros). Esa transición es el «cuadro en que aparecen los rayos».

## Qué cambió

- `Tools/asset-pipeline/scripts/borde_difuminado.py` + `leer_cuadros_alfa.swift`: script reproducible.
  `ffmpeg` no lee el alfa de estos `.mov`, así que un lector chico de AVFoundation vuelca los cuadros a
  BGRA crudo (se compila solo, a `state/`); Python multiplica el alfa por un degradé vertical (0 en la
  fila de arriba, 1 al `--pct` % de la altura) **sólo desde el cuadro en que algo toca el borde**, y
  reescribe con el mismo camino del pipeline (`hevc_videotoolbox`, `hvc1`, mismas calidades).
  Subcomandos: `medir`, `hornear`, `tira`. Verifica que códec, tag, tamaño, fps y cuadros no cambien.
- Respaldo del original en `Tools/asset-pipeline/state/respaldos-b32/` (ignorado por git como todo
  `state/`; el original sigue en la historia en `5e625057`). `hornear` parte siempre de ese respaldo, así
  que repetirlo no aplica el degradé dos veces.
- Test nuevo `tests/test_borde_difuminado.py` (aritmética del degradé + los tres clips ya no tocan el
  borde, conservan formato, y las tapas del paquete quedan intactas). Todo el pipeline: 107 tests OK.

## Barrido (los 29 `Loops/` + las cinemáticas)

| Clip | Toca el borde de arriba | Qué se hizo |
|---|---|---|
| `obj_paquete_abre` | 29 cuadros (desde el 44), los rayos | degradé 15 % desde el cuadro 44 (peso 177 → 156 KB) |
| `obj_cofre_abre` | 23 cuadros (desde el 39), rayos y brillo | degradé **7 %** desde el 39 (164 → 143 KB) |
| `obj_colchon_abre` | 40 cuadros (desde el 32), billetes y monedas que caen | degradé 15 % desde el 32 (608 → 555 KB) |
| `obj_paquete_espera`, `_sacude`, `obj_cofre_espera/sacude`, `obj_colchon_espera/sacude`, `obj_ruleta_espera` | no | nada |
| `obj_ruleta_premio` | 14 cuadros (desde el 16): chispitas y confeti sueltos | **no tocado** (no está en la lista del spec; no hay rayos cortados, sólo partículas) |
| `loop_npc_sindicalista`, `loop_npc_vecina` | todos | **no tocados**: son bustos recortados a propósito (la cabeza llena el cuadro) |
| cabina y `cine_*` | todos | opacos por diseño, no aplican |

Por qué el cofre lleva 7 % y no 15 %: la tapa abierta del cofre llega al 7,6 % de arriba (la de la caja,
al 17 %). Con 15 % la tapa quedaría translúcida, así que el degradé termina donde empieza la tapa. Los
rayos anchos del cofre quedan suavizados pero más cortos de difuminado que los de la caja: es la parte a
mirar en el build.

## Tira de cuadros antes / después (fila de arriba = antes, de abajo = después)

Paquete (cuadros 40, 44, 50, 58, 66): `Docs/capturas/b32/tira-paquete-antes-despues.png`
Cofre (30, 39, 45, 55, 65): `Docs/capturas/b32/tira-cofre-antes-despues.png`
Colchón (25, 32, 40, 50, 65): `Docs/capturas/b32/tira-colchon-antes-despues.png`

## Pendiente del controlador (no se compila ni se corre simulador)

Capturas en el SE y el Pro Max de la caja abriéndose en el tablero (comparar con la opción A del
mockup), y mirar a ojo el cofre (7 %) y el colchón en el tablero.
