# Sesión 2026-10-15 — E14b B24: el colchón después del video

Rama `v2i/e14b-b24`, base `74667860` (integración del relevo 58). Sin compilar (regla del dueño): el
controlador reproduce y verifica en el build único.

## El bug, explicado leyendo el código

El estado estaba bien (`mattressVideoWatched` → `payMattress` → `.onBoard` → el controlador crea el
nodo y lo hace caer). Lo que fallaba era lo que se veía y quién recibía el toque:

| Hipótesis | Veredicto | Evidencia (base `74667860`) |
|---|---|---|
| H1 tapado por la hilera de atrás | **Confirmada, causa principal** | `PickupController.update`: `mattress.zPosition = DepthOrder.z(forFeetY: layout.baselineY)`, la línea de atrás: el z más bajo de todo lo parado en el piso. En x fija (`PickupLayout.mattressX`, entre el visitante y el borde derecho), en la franja de las columnas de empleados. Y el toque: `BoardScene.touchesBegan` ordena por z (`touchOrder`), así que un empleado parado delante se lleva el toque (`grab`) y el colchón nunca lo recibe. |
| H2 la caída bajo el pop-up que se cierra | **Confirmada** | `mattressVideoWatched` pone `mattressPopup = nil` y en el mismo cuadro `syncMattress` arranca `drop` (0,55 s), mientras `GamePopupPresenter` anima la salida 0,24 s con el velo: casi la mitad de la caída ocurre debajo del pop-up y del HUD. |
| H3 la columna lo tapa | Descartada | La columna de sellos está a la izquierda (`SideRailLayout`); el colchón iba a la derecha con `edgeClearance`. Ahora usa la misma franja que las cajas, lejos de los dos bordes. |
| H4 premio después de `adDidDismiss` | No es la causa en el simulador; cubierta | `AdMobAdsProvider.showRewarded` ya espera 1 s de gracia (B29). Con el stub el flujo pagaba (`testTheMattressOpensWithAVideo` pasó en el build de `c6034332`). Se agregó un log `rewarded <placement> reward after dismiss: late …/none` para medirlo en el iPhone con una red mediada. |
| H5 delta grande en el primer cuadro | **Confirmada como riesgo** | `BoardScene.update` pasa el delta crudo a `pickups.update` (sólo `IncomeTicker` lo recorta): un tirón de 0,2–0,5 s se comía la caída entera. |

## Qué cambió

- **Lugar (B22, B19).** `TreasuresState` guarda `floor`, `x`, `y` del colchón del tablero
  (`needsPlacement`, `land`; se borran al abrirse o al llegar otro). `GameState.placeMattressIfNeeded`
  lo ubica en el piso que se mira con `PackagePlacer`, las mismas superficies que las cajas
  (referencia + SE), lejos de ellas y de la zona del visitante, y en la mitad de adelante
  (`mattressBackDepth`). Lo llaman `payMattress`, la llegada de regalo, el fixture y el tick (save
  viejo). Las cajas nuevas lo esquivan (`packageAreas` + `PackageFloorArea.keepingClear(of:)`).
  `PickupLayout` perdió `mattressX`/`mattressPosition` y la zona fija del colchón.
- **Dibujo.** El controlador lo pone en su lugar de su piso, con `floorShift` y el z de sus pies; fuera
  de la vista de la cámara no se dibuja; en otro piso no se toca.
- **Caída.** Entra cayendo el que llega mientras se juega (pagado o de regalo), pero espera
  `popupCloseSeconds` (0,35 s) con la pantalla libre (`dropHeld`: pop-up del colchón, UI apagada,
  escena fuera, otro piso), invisible. La caída avanza a lo sumo `maxFallStep` por cuadro.
- **Llamado.** `PickupNode.callsForTap`: salta cada 1,4 s, brillo amarillo que respira y «¡Tocame!»
  (clave nueva `mattress.board.tapme`, snapshot en `Tools/v2/claves-pendientes/e14b-b24.json`). Con
  Reduce Motion, quieto y brillando.
- **Premio.** `MattressReveal`: imagen, monto y nombre (`PrizeReveal.caption`); marca invisible
  `mattress.result.art` con la clave del arte. Los tres premios de `treasures.json` tienen arte
  aprobado (`rw_coins`, `rw_package_employee`, `ui_dolar_blue`): no faltó ninguna imagen.
- **Regalo (D4).** El mismo camino; el fixture `--uitest-mattress-board` ahora es de regalo
  (`gifted`), así su «Cobrar» dispara el paso 2 de B29.

## Los dos UI tests rojos del build de `c6034332`

- `testTheGiftedMattressOpensOnTheBoard` («mattress.collect: No matches» con `mattress.result` ya a la
  vista) y `testTheSavedExtraMattressPaysWithOnlyTheVideo` («el popup ofrece el video») **no son el
  bug del dueño**: los dos fallan con el pop-up del colchón ya abierto, buscando un botón de su pie.
  El camino del dueño (video → tablero → toque) es el de `testTheMattressOpensWithAVideo`, que pasó.
  Leyendo el código no encontré qué saca esos botones del árbol; la sospecha es otro pop-up modal
  (`PopupContainer` es `.isModal`) que entra encima al arrancar. Se endurecieron: esperan el botón
  (12 s el del video, que primero dice «Cargando…» con otro id) y adjuntan una captura si no está.

## Tests

- EK: `TreasurePlacementTests`, `PackageAreaClearanceTests` (verdes con `swift test`).
- Unit: `MattressBoardTests` (nuevo), `PickupControllerTests` (la caída espera el pop-up, el delta
  grande, el lugar adelante con el z de sus pies, el hit-test en su centro, las cajas lo esquivan),
  `DepthOrderTests` y `PickupLayoutTests` ajustados al lugar libre.
- UI: `PrizesUITests.testTheMattressAfterTheVideoLandsInSightAndOpens` (el de B24), y el de regalo
  ahora cierra el paso 2.

## Para el build único

Capturas en el SE y el Pro Max: el colchón quieto con «¡Tocame!» y el pop-up del premio (las adjunta
el UI test de B24: «B24 el colchón quieto en el piso», «B24 el pop-up del premio»). En el iPhone del
dueño con un video real: el log `reward after dismiss`.
