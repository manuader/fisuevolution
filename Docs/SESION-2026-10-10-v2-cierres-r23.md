# Sesión 2026-10-10 — Relevo 23: los cierres de E8 (T10), E13b (T11) y E13 (T14)

Una sola corrida de `Tools/v2/oraculo.sh completo --limpio` sobre `bab8a9c` cerró tres épicas. Rama `v2i/cierres-r23`, worktree
`.claude/worktrees.nosync/v2i-cierres-r23`. Log: `build/cierres-r23-completo.log`; salidas en `build/oraculo/20261010-005254-completo/`.

## 1. El `completo`

| Suite | Resultado |
|---|---|
| EconomyKit | 796 tests, verde |
| unit (iOS 26.5) | 1162 verdes · 0 rojos · 0 salteados |
| UI (16 Pro, 26.5) | 107 verdes · **3 rojos** · 4 salteados → los 3 eran reales y están arreglados (abajo) |
| store-unit (18.6) | 15 verdes · **1 rojo** (`StoreManagerTests/loadsTheCatalogProducts`) → de carga, pasa aislado (16 verdes) |
| store-ui (18.6) | 2 verdes |
| iPad UI | 4 verdes |
| SE UI | 2 verdes |
| pipeline | 89 verdes |
| pacing-sim | Dios en 31,34 h activas (561 h de pared) · maxTier 37 · 13 reencarnaciones del bot |
| Release | 0 avisos del compilador |

Las clases pedidas por los planes (`ElevatorRideTests`, `ElevatorKeypadModelTests`, `ElevatorCabinTests`, `ElevatorRideUITests`, `ElevatorPanelUITests`,
`LuckyTouchTests`, `GiftsBadgeTests`, `CharacterSheetFromMenuTests`, `JobGroupsTests`) están dentro de las 1162 unit y las UI verdes.
El rojo declarado `theOwnersTargetsAreMet` **no falló**: el oráculo avisa que se saca de `rojos-declarados.txt`.

### Los tres rojos de UI: un bug de debug de E4a T9

`CharacterSheetUITests/testDespedirPideLaTarjetaDeLaCasaYNoUnaAlerta` y `QuickHireUITests/testConElPisoLlenoElAtajoSigueYAvisa` y
`testMantenerPresionadoAbreElSelectorYFija` fallaban con "el panel de debug no ofrece `debug.floor.fill` / `debug.quickhire.many`". Reproducidos aislados
(3/3). Causa: `a0c4e67` (E4a T9) puso el menú "Disparar un evento" en la sección Offline del `DebugPanelView`, arriba de las puertas de los tests; la `List` es
perezosa y las filas bajo el pliegue no existen para XCUITest (la trampa que el propio comentario del panel advierte). Un `tarea` no corre UI, por eso no se vio.

Arreglo (`534fd51`): el menú de eventos pasa a su propia sección "Eventos" antes de "Peligro" y las Cinemáticas bajan antes de "Rendimiento". Con eso
`CharacterSheetUITests`, `QuickHireUITests` y `BonusHUDUITests` (la otra consumidora de las puertas) dan 9/9 verdes. Sólo cambia código `#if DEBUG`.

### El rojo de store-unit

`loadsTheCatalogProducts` tardó 280 s y devolvió `loadState == .failed`: StoreKit Testing sobre un 18.6 recién creado con la máquina cargada. Corrido solo en
un simulador 18.6 nuevo: `StoreManagerTests` + `StoreProductsTests`, 16 tests verdes en 78 s. Es flaky de carga, no código.

## 2. E8 T10 — peso y memoria

Release (`-configuration Release -destination generic/platform=iOS`, `du -sk` del `.app`):

| | `.app` |
|---|---|
| v1.0.0 (build 4), construido aparte desde `git archive v1.0.0-build4` | 171.572 KB (167,6 MB) |
| La punta (`bab8a9c` + el fix) | 211.768 KB (206,8 MB) |
| **Diferencia** | **+40.196 KB = +39,3 MB** (estimado +29 MB; gate 60 MB) |

**No hay 🔒 de ODR ni de PNG cuantizado.** Por dónde se fue (sólo lo que mueve más de 0,6 MB): `fam_pijama` 16,3 MB, `fam_dinosaurio` 16,3 MB,
`fam_gaucho` 15,5 MB, `npcs.atlasc` 13,5 MB (las tres familias y los 52 visitantes), el binario +5,0 MB, las cuatro cinemáticas (≈ 6,4 MB) y los siete `bgloop_*.mov`
(≈ 5,3 MB), `cabina_*.png` 2,2 MB, y los temas por piso (un `music_<piso>_loop.caf` cada uno en lugar de los dos de la v1). Lo que resta: los fondos de la v1
(`bg_*@2x/@3x.png`, ≈ 38 MB) por los JPEG de 2048 (`bg_*.jpg`, ≈ 9 MB). Los atlas más grandes (`earth` 42,1 MB y `cosmic` 25,4 MB)
no cambian de tamaño con respecto a la v1.

**Memoria** (`footprint` de la app Debug en el iPhone SE 3, iOS 26.5, `--uitest-unlock-tower-all`, muestreo cada 1 s mientras corrían
`ElevatorRideUITests` + `ElevatorPanelUITests`, 8 tests con viajes): inicia en 19 MB; **pico 117 MB**. El plan temía ≈ 168 MB con fondos de 2048 (16 MB cada
textura decodificada). **Sólo se midió el lado nuevo**: la base con fondos de 1024/1536 no se compiló aparte (la v1 no tiene el ascensor, el vuelo no es
comparable), así que el "antes" queda sin medir; el pico absoluto de 117 MB en el SE no inquieta. Un viaje 1 → 10 a mano en un SE real sigue siendo del dueño.

Los "sospechosos de recorte" de la T9 no entraron en este cierre (T9 es 🔒 del dueño y no se ejecutó).

## 3. E13b T11 — el ascensor y la barra, a mano

El simulador de mano (taps con el MCP del simulador) no estaba disponible en esta sesión, así que las grabaciones son **los UI tests corriendo** sobre
simuladores propios con `simctl io recordVideo`: recorren exactamente los gestos del Step 2 (mantener apretado, placa, viaje por la placa y por el mapa,
saltear, scrollear sin viaje, la barra y la tienda por el "+"). Los viajes de los tests de ritmo normal duran 2–3 s reales (`--uitest-elevator-ride`); el de
saltear va a ×5.

| Archivo (en `build/grabaciones/` del worktree, gitignoreado) | Qué hay |
|---|---|
| `16pro-ascensor-barra-movimiento-normal.mp4` (8 MB) | 16 Pro, Reduce Motion apagado: `ElevatorRideUITests`, `ElevatorPanelUITests`, `BottomMenuUITests`, `StoreUITests` (14 tests verdes) |
| `16pro-ascensor-reduce-motion.mp4` (3 MB) | 16 Pro, Reduce Motion prendido: `ElevatorRideUITests` + `ElevatorPanelUITests` (8 tests, **2 rojos**, abajo) |
| `se-ascensor-barra.mp4` (7 MB) | iPhone SE 3, Reduce Motion apagado: `ElevatorRideUITests`, `ElevatorPanelUITests`, `BottomMenuUITests` (12 tests verdes; incluye `testLaPlacaConLaTorreEnteraCabeEnPantalla`, los diez pisos) |

**Con Reduce Motion prendido** `ElevatorRideUITests/testElViajeTerminaSoloEnElDestino` y `ElevatorPanelUITests/testElBotonDeLaPlacaViajaEnCabina` fallan
("la cabina no abrió"): con Reduce Motion el viaje dura 0,9 s de fundidos y el sondeo de XCUITest no alcanza a verla. Es del test (el oráculo siempre corre con
Reduce Motion apagado); la grabación es la prueba a mirar. No se tocó nada.

## 4. E13 T14 — el cierre del feedback de la v1

`HANDOFF.md` ya traía la mayoría de las ediciones de E13 en las sesiones de las olas; este cierre las junta y corrige:

- §4: la entrada de esta sesión.
- §5: cuatro decisiones nuevas (11 a 14): cofres de piso una vez por cuenta, maxear son las **seis** mejoras (192 ORO con `baseCost` 1; 348 con `baseCost` 2 en E2b T14),
  la Startup y el regalo a frontera − n, y el ascensor de placa colgante con la barra de cinco. "Las siete" de §5 y de la lista de cambios del plan maestro pasan a "seis".
- §7: las trampas nuevas (puertas de debug al final de la `List`; el rojo de carga del store; Reduce Motion; cómo medir el peso).
- §9: este documento.
- Los dos pines que el plan pedía ya estaban: `GameContentValidationTests` pinea 192 (comentario con los 348) y `fixedOroAchievementsFundAFifthOfTheRun` no cambió de cuenta.
- **La frase "los cofres de torre se vuelven a cobrar al reencarnar"** (relevo 19 la dejó para corregir): no existe en `HANDOFF.md`, `PLAN-v2.md` ni el código; sólo en
  `tasks.md:272` (nota) y en la sesión del relevo 19. La corrección es la decisión 11 de §5. Lo de `tasks.md` queda para el controlador.
- Las trampas "`catalogo.py` no pisa textos: cambiar uno es `quitar` + `aplicar`" y "`PlayerState`/`MetaState` migran en el decodificador" que pedía el plan ya estaban
  asentadas en las sesiones de E13 T3; no se duplican.

Las pruebas a mano de E13 (videos de Regalos, reencarnar y volver a subir dos pisos, la ficha desde Personajes, las seis filas con un save v1 de Pegarla 10 y Toque de
oro 4) las cubren los tests (`LuckyTouchTests`, `GiftsBadgeTests`, `CharacterSheetFromMenuTests`, `JobGroupsTests`, las UI de Regalos) pero **no se filmaron**.

## 5. Lo que queda al dueño (en device)

- Mirar las tres grabaciones y, si se puede, un viaje 1 → 10 y otro 10 → 3 con el dedo en un iPhone real (vibración, "ding", sentido de los fondos por la ventana).
- Con Reduce Motion prendido en un iPhone: que el viaje sea el fundido de 0,9 s y no se vea raro.
- La memoria del vuelo en un SE real (pico del simulador: 117 MB).
- Los videos de Regalos con proveedor real, el regalo a frontera − 3 y la Startup (E13).

## 6. Carries y cambios para el controlador

- `Tools/v2/rojos-declarados.txt`: **sacar `unit theOwnersTargetsAreMet`** (el oráculo avisa que ya no falla). No se agregó ningún rojo nuevo.
- `tasks.md`: E8 T10 ✅ y las filas "El batch de imágenes" y "Fondos regenerados a 2048 px" ✅ (peso +39,3 MB, sin 🔒; memoria medida sólo del lado nuevo: 117 MB en el SE);
  E13b T11 ✅; E13 T14 ✅ (nota de `tasks.md:272` sobre la frase de los cofres: resuelta en §5.11); E6b T9 de 🔒 a ⛔ según el plan de E8 (le queda T5).
  La "Peso de las familias" de §6 queda ✅ (las tres familias ≈ 49 MB).
- `fix(debug)` `534fd51`: E4a T9 debería haber corrido `CharacterSheetUITests` y `QuickHireUITests`; el procedimiento de las tareas que tocan `DebugPanelView` suma esas dos clases.
- Carry de test: los dos UI tests del ascensor con Reduce Motion prendido (arriba) esperan un viaje de ≥ 3 s; si el dueño quiere que el oráculo cubra Reduce Motion, hay que alargar
  el viaje bajo `--uitest-elevator-ride` también en ese modo.
- Carry de balance (sin acción): el bot del pacing-sim reencarna 13 veces (ellos median ≤ 9 con otra política en `PacingTests`); no se compara con el `completo` anterior porque
  el reporte de referencia no está en este árbol.
