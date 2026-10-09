# SESION 2026-10-09 — v2, relevo 18: la cadena de Fusionar todo en el plan, el turno y el remate; el piso ???, la moneda y el pack de las 43

Relevo 18 de la ejecución autónoma de la 2.0, despertado a las 08:03 del 9 de octubre por la rutina `fisu-v2-relevo-a`
con el `LOCK` libre (lo había liberado el relevo 17 a las 07:35). Controlador opus; implementadores sonnet en worktrees
manuales (`worktrees.nosync/v2i-<tarea>`) con briefs de `brief.py`; revisor opus para E8c T1 y E8c T5. Todo pasó por la
rama de integración **`v2i/integ-r18`** (BASE `version-2` en `16bb3c5`). Cierre a ~239k de contexto en el último despacho:
desde ahí sólo se esperó a lo que estaba en vuelo.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`1776145`**: el `rapido` sobre `4638ef1` dio VERDE y avanzó por fast-forward con E8c T1, T2, T3 (de r17), T5, E13 T8, T11 y T12 |
| `v2i/integ-r18` | **`8b35414`** = lo anterior más E8c T6 y E8c T4 (🟢) + los docs del cierre |
| `rapido` | sobre `d4d8c2f`: VERDE (EK 624 · unit 997 + 1 declarado `theOwnersTargetsAreMet` · Release 0) → `version-2` a `a9ab381`. Sobre `4638ef1`: VERDE (EK 624 · unit 1007 + 1 declarado · Release 0) → `version-2` a `1776145`. Final sobre `8b35414`: RAPIDO_PENDIENTE |
| Progreso | **116 de 254 en `version-2` (45,7 %); 118 de 254 (46,5 %)** si el `rapido` de `integ-r18` da VERDE (`tasks.md` §2) |

El paso 1 del handoff anterior (el fast-forward de `integ-r17`) ya lo había hecho el relevo 17: `version-2` estaba en
`16bb3c5` al llegar. `relevo-b` no existe; `v2/e12-plan` sólo está en `origin` y ya estaba integrada.

## Lo que se integró

| Tarea | Commits | Oráculo y revisión |
|---|---|---|
| **E8c T1** el eslabón en el plan | `cbb97f3` | revisión opus: Approved |
| **E8c T2** el reloj del turno se renueva | `6550e6b` | diff leído por el controlador |
| **E13 T8** pisos cerrados con "Piso ???" | `545521f` | `FloorMapUITests` 2/2 en SE; captura vista |
| **E13 T11** la moneda sobre quien genera plata | `17b29fb` | tests nuevos verificados por nombre en `unit.log`; `BoardGestureUITests` 1/1 |
| **E13 T12** el Diamante dice "Pack de las 43" | `221f9b6` + `ff3b1ef` | devuelto una vez (clave `%lld`); sin captura SE |
| **E8c T5** el turno de la cadena en `GameState` | `ae952bf` + `de11f12` | revisión opus: Approved con arreglos, hechos |
| **E8c T6** el contador "×N" | `0c15d3d` | 🟢 en `integ-r18`; sin revisión |
| **E8c T4** el plin que sube de tono y el remate | `db94359` | 🟢 en `integ-r18`; sin revisión; sonido sin escuchar |

### E8c T1 — la cadena en el plan

`BoardChange.Chain` (`id`, `index`, `count`, `isLast`); `planMergeAll` sella cada eslabón y `replanned` conserva la
cadena. **Revisión opus: Approved** — la igualdad que compara `confirmBoardChange` quedó intacta, `BoardChange` no es
`Codable` y los tests muerden. Opcionales a carry: un helper `linked(_:)` en vez de rearmar el struct, y
`singleChangesHaveNoChain` sólo cubre `planAutoMerge`.

### E8c T2 — `CelebrationQueue.renew(_:)`

El reloj del turno vuelve a 0 si `current == kind`. Chica; la leyó el controlador.

### E13 T8 — "Piso ???"

`FloorMapView`: el piso cerrado muestra "Piso ???" y una silueta, sin nombre ni miniatura (`FloorThumbnail` ya no
decodifica los cerrados). `TowerNaming.displayName(for:isUnlocked:)` y el AX de `ElevatorKeypad`. **Diferencia con el
plan:** `ElevatorPanel` ya no existe (lo borró E13b T8), así que no hay `ledText` ni `TowerNavigation.isUnlocked`; el
brief del controlador lo corrigió antes de despachar. Catálogo +1 (`tower.floor.unknown`).

### E13 T11 — la moneda

La moneda es hija del `CharacterNode` (no del sprite), sin `SKAction` ni toques; `RenderedUnit.earnsPassive`,
`renderPlacements` y `unlockPassive` termina en `bumpBoard()`. **Sin captura del piso con pasivos:** queda la duda de si la
moneda tapa la cara del personaje de atrás (carry a E13 T14 / dueño).

### E13 T12 — "Pack de las 43"

`SkinCatalogRow.packSize` cuenta de `skins.json` sólo los `.purchasable` con más de una skin; leyenda bajo el precio y
`axValue`. **Se devolvió una vez:** la clave salía `%@` con `String(Int)`; la convención del catálogo es `%lld`. Catálogo +1
(`skins.pack.caption`). Sin captura en el SE.

### E8c T5 — el turno de la cadena

`beginNextChainLink(after:)`, `hurryChainLink() -> DropResolution?`, `renewBoardTurnForNextLink()` y
`debugSeedMergeAll(homeless:)`. **Revisión opus: Approved con arreglos**, hechos en `de11f12`:
`beginNextBoardChange(while:)` es privado (no arranca lo que viene detrás de la cadena; `nil` sin renovar), un test con dos
cadenas, un test del turno soltado y una sola publicación de la bandera. **Notas para E6/E7b:** un video que compense en
`discardBoardChange` compensaría por eslabón; **T7 decide el tempo por `next.chain`**.

### E8c T6 — el contador

`MergeAllComboNode`, sin montar (lo montan T7/T8). Clave `merge_all.chain.done %lld` (catálogo +1).

### E8c T4 — el plin y el remate

`SFX.mergeAllDone` (`.caf` a -20 dB, **sin escuchar: G7 del dueño**), `play(_:rate:)` acotado a 0,5–2,
`HapticsManager.Pattern.mergeAllFinale` y, en `GameState+Services`, `playBoardMergeFeedback(chainIndex:evolved:)` y
`playMergeAllFinale()`, sin llamadores hasta T7/T8. **Carry a T7:** el háptico `.merge` de `presentResolution` pasa a
`playBoardMergeFeedback`; no duplicarlo.

## Decisiones de este relevo

- **Briefs con `brief.py`** y reglas comunes; worktrees manuales desde la BASE.
- **Tope de 2 compilando con carga > 200** (osciló 80–690) y 3 con carga ~100. El `rapido` cuenta como uno.
- **No se mergea con un `rapido` corriendo:** E13 T12 y E8c T6 esperaron en su rama.
- **Último despacho a 239k** (E8c T4 y T6, sin revisión); desde ahí sólo se esperó.
- **El controlador verifica por nombre en `unit.log`** que los tests nuevos corrieron cuando el agente no puede.
- **La lista de palabras de E12 no se tocó:** sigue sin confirmación del dueño en el chat. La mediación espera al dueño.

## Trampas nuevas

- **`pgrep -f "oraculo.sh tarea X"` dentro de un `while` lanzado con `zsh -c` se encuentra a sí mismo** (el patrón está en
  la línea de comando del propio shell), así que el bucle no termina nunca. El agente de E8c T4 dejó cinco colgados; se
  cortaron por PID tras leer sus comandos. Esperar por PID (`$!`) o por la última línea del log, no por `pgrep -f`.
- **El rango `d4d8c2f..ae952bf` no era el diff de E8c T5** (su rama salía de `43e4f4f`): para revisar, `git show <sha>` o el
  merge-base, no la punta de `integ`.
- **El log de `tarea` no siempre nombra las clases** (XCTest vs Swift Testing): grep por el título del `@Test`.
- **Un plan puede nombrar archivos que otra tarea ya borró** (`ElevatorPanel` en E13 T8): el brief del controlador lo
  corrige antes de despachar.

## Carries por tarea

- **E13 T11:** captura del piso con pasivos (¿la moneda tapa la cara del de atrás?) → E13 T14 / dueño.
- **E13 T12:** captura SE y la receta R de `CustomizationUITests`.
- **E13 T8:** `FisuJobsView:442`, `CharacterSheetView:291` y `+Store:196` todavía nombran pisos cerrados (para el dueño o E13 T10).
- **E8c T1:** los dos opcionales (helper `linked(_:)`; `singleChangesHaveNoChain`).
- **E8c T4/T5 → T7/T8:** el háptico `.merge` de `presentResolution`; el tempo por `next.chain`; la compensación por eslabón
  de un video en `discardBoardChange`; el sonido sin escuchar (G7).
- **Siguen vigentes** los de los relevos 14 a 17: `--uitest-ranking-*` fuera de `#if DEBUG`, ODR sin probar en device (G5),
  HEVC con alfa a ×5 en un iPhone real (E13b T11 / E8d G3), `setVisible(false)` de E8d T4 a T8/T9, `resolveAcrossReset`.

## Para el dueño

- **La lista de palabras de E12 sigue sin activar:** confirmarla en el chat y el próximo relevo la activa.
- **Oír el remate de Fusionar todo** (`SFX.mergeAllDone`, G7).
- **Mirar el piso con pasivos:** ¿la moneda tapa la cara del de atrás?
- **Tres lugares todavía nombran pisos cerrados** (`FisuJobsView`, `CharacterSheetView`, `+Store`).
- Siguen abiertos: `installId` y CloudKit, el botón Entrar con `.disabled`, la placa de 10 pisos sobre Reencarnar,
  capturas de las 3 ofertas de ASC, Meta, mediación por SPM, cuentas de redes, TestFlight, HEVC-alfa en device (G3).

## Oráculo

- `rapido` sobre `integ-r18` `d4d8c2f`: VERDE (EK 624 · unit 997 + 1 declarado `theOwnersTargetsAreMet` · Release 0) →
  `version-2` a `a9ab381` (114 de 254).
- `rapido` sobre `4638ef1`: VERDE (EK 624 · unit 1007 + 1 declarado · Release 0) → `version-2` a `1776145` (116 de 254, 45,7 %).
- `rapido` final sobre `integ-r18` (`8b35414`, con E8c T6 y T4): RAPIDO_PENDIENTE
- Tareas: `FloorMapUITests` 2/2 (SE) · `BoardGestureUITests` 1/1 · tests de E8c T5 con dos cadenas y turno soltado.
- No se corrió un `completo` nuevo; el de referencia sigue siendo el `--limpio` de `c94f75f`.

## Lo descartado

- Revisión de E8c T6 y T4: nodo sin montar y funciones sin llamadores; el controlador leyó el diff.
- Reabrir al implementador por los opcionales de E8c T1 (no muerden): quedan en el carry.
- Reintentar la activación de la lista de palabras de E12.

## Cierre

- Subagentes en vuelo: **0**. `LOCK`: lo libera el controlador.
- Worktrees borrados al integrar cada tarea. Quedan `v2i-docs-r18` y `v2i-integ-r18` para el barrido final
  (`limpiar-worktrees.sh`), más `v2i-docs-r17`/`v2i-integ-r17` si no se barrieron.
- Cuota: 5 h 1 % al llegar, semanal 49 %.
