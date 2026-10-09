# SESION 2026-10-09 — v2, relevo 20: la escalada por bandas, la cadena entera en el simulador, el fondo vivo del piso, la revelación en movimiento, el menú que se desliza y «Opciones de privacidad»

Relevo 20 de la ejecución autónoma de la 2.0, arrancado a las 12:03 del 9 de octubre (lo despertó el disparo horario de la rutina
`fisu-v2-relevo-a`; `LOCK` libre desde las 11:15). Controlador opus; implementadores sonnet en worktrees manuales
(`worktrees.nosync/v2i-<tarea>`) con briefs de `Tools/v2/brief.py` y reglas comunes; revisor opus para E8d T8 y E8d T9.
Todo pasó por la rama de integración **`v2i/integ-r20`** (BASE `version-2` en `8350806`). Cuota al llegar: 5 h 7 %, semanal 50 %.
Carga de la máquina: 1,8 → 204 → 367 → 36 → 602, con tope de 2 compilando cuando pasaba de 200.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`7a5395b`**: el `rapido` sobre `b8a3c1e` dio VERDE y avanzó por fast-forward con E2b T1, E8c T9, E8d T8, E3a T11 y E7b-a T5 |
| `v2i/integ-r20` | **`2e43db0`** = lo anterior más E8d T9 y E3b T4 (🟢) + los docs del cierre |
| `rapido` | sobre `f2308e7` (E2b T1 + E8c T9): VERDE (EK 636 · unit 1039 + 1 declarado · Release 0). Sobre `b8a3c1e` (+ E8d T8, E3a T11, E7b-a T5): VERDE (EK 636 · unit 1047 + 1 declarado · Release 0). Final sobre la punta de `integ-r20`: VERDE sobre `2e43db0` (EK 636 · unit 1055 + 1 declarado `theOwnersTargetsAreMet` · Release 0) |
| Progreso | **131 de 254 en `version-2` (51,6 %); 133 de 254 (52,4 %)** si el `rapido` final de `integ-r20` da VERDE (`tasks.md` §2) |

## Lo que se integró (7 tareas)

| Tarea | Commits | Oráculo y revisión |
|---|---|---|
| **E2b T1** bandas de escalada y curva por piso | `42b2e8c` | tarea VERDE (EK 636 · unit 34); revisión ninguna, diff leído |
| **E8c T9** la cadena entera en el simulador | `fd9623d` + `ea019c1` | tarea VERDE (unit 9); Receta R en un 16 Pro 3/0; techo 20 → 30 s del controlador |
| **E8d T8** el fondo del piso visible, animado | `2260105` + `0b0ecd0` | tarea VERDE (unit 63); revisión opus: Approved con arreglos, hechos |
| **E3a T11** el chrome de la raíz en la columna | `558b6cf` | tarea VERDE (unit 4); Receta R iPad Pro 13 `IPadLayoutUITests` 4/0; diff leído |
| **E7b-a T5** «Opciones de privacidad» en Ajustes | `86e6413` (+3 claves) | tarea VERDE (unit 11); Receta R `SettingsPrivacyUITests` 2/2; diff leído |
| **E8d T9** la revelación con el cuerpo entero | `1970662` + `9acbf04` | 🟢; tarea VERDE (unit 54); revisión opus: Approved con arreglos, hechos |
| **E3b T4** el menú deslizable, montado | `62e4315` (+ `49aecc0` del controlador) | 🟢; `MenuPagerUITests` 2/2, `BottomMenuUITests` 4/4, `CustomizationUITests` 5/5; diff leído |

### E2b T1 — la escalada por bandas

`EscalationBand` y `escalation(atFrontier:)` como única fórmula, usada por `hireCost` y `PriceCushion.jump`;
`costGrowthStepPerFloor` desde un piso; validación al decodificar; knobs. **Apagadas:** con el umbral 7 el resultado es el de la v1
(`[{8:1,6}]`, leído en el diff).

### E8c T9 — la cadena en el simulador

`--uitest-merge-all` en +Bootstrap y `MergeAllChainUITests` (2 tests); `BoardChangeUITests` verde en un 16 Pro. La cadena mide
19,9 s sola y 28,5 s con toques, con ids reales iguales al plan; no se traba con 20 toques. **El techo del UI test pasó de 20 a 30 s**
(commit del controlador `ea019c1`: el test midió 19,9 contra 20).

### E8d T8 — el fondo vivo del piso

`FloorNode` cuelga un `LoopingVideoNode` `.background` sobre la misma textura si hay entrada `.floor(clave)` en el manifest;
`BoardScene` suspende `.scrolling` en el arrastre y el viaje de cámara. **No es inerte:** los 10 `bgloop_*` ya están en `floors`
sin `odrTag`, así que **el fondo animado de los pisos ya está activo en producción**. `applyBackgroundAnimation` sólo en el piso visible
asentado; póster en viaje, arrastre > 12 pt o salida de vista; prefetch ODR del piso de arriba; `forcedStill` bajo `--uitest`/XCTest.
**Revisión opus (Approved con arreglos):** el test de scroll llamaba `scrollBegan()` a mano y tapaba el cableado real; `willMove(from:)`
dejaba tomada la suspensión si la escena se desmontaba en pleno salto. Arreglos en `0b0ecd0` (más `releasePrefetchedPack` con
`!allowsLoops`, `animatedFloorOrdinal` bajo `#if DEBUG`, test de `willMove` en pleno viaje).

### E3a T11 — la raíz en la columna

`playColumn` en `ActiveBonusBar`, `EventBannerView` y la fila atajo/prestigio; las seis hojas pasan por `fisuSheet(item:)` (que ya
aplica el fondo), sin `.presentationBackground(.clear)`; guardia de `pending` vacío; `RootView` a `systemSheets` por `ShareCardSheet`
y el debug. Destraba a E12 T13.

### E7b-a T5 — «Opciones de privacidad»

`AdsConsent.privacyRowVisible` (con `--uitest-privacy-options` sólo en DEBUG) y `privacySection` tras `purchasesSection`. +3 claves.
El plan estaba desactualizado: el tab se llama `hud.settings`, no `hud.menu`.

### E8d T9 — la revelación en movimiento

Ruta A (el alfa se respeta en el simulador, T4): el reveal monta un `LoopingVideoNode` `.popup` en `cameraOverlay` sobre la foto, con
póster 1×1 transparente; se suelta en `closeReveal`, `cutRunningCelebration`, al montar otro y en `willMove`. 53 `characters` reales con
`odrTag`. **Revisión opus (Approved con arreglos):** `fadeOut` iba sobre `videoNode` (nil si nace tarde por la suspensión de T8 o por el
ODR); el whoosh era condicional; sin precarga el video no aparecía nunca (el reveal dura ~2 s). Arreglos en `9acbf04`: fundido del
contenedor al tiempo de la foto, whoosh sin condición y `prefetchNextRevealPack` (el `odrTag` del primer tipo de `maxTierReached + 1`
al asentarse, con release compensado).

### E3b T4 — el menú deslizable

`menuSession` en `RootView`: una sola hoja que se recorre sin volver a abrirse. **Sólo la página quieta queda montada** (pierde su
`NavigationStack` al deslizar; la X vive en la nav bar UIKit). La Tienda (+) es una sesión de una sola página y sin chrome; cinco
páginas (E13b). El comentario de la hoja lo corrigió el controlador (`49aecc0`).

## Decisiones de este relevo

- **Briefs con `brief.py`** y reglas comunes; worktrees manuales desde la BASE.
- **Tope de 2 compilando con carga > 200;** el `rapido` cuenta como uno.
- **Revisión opus por riesgo:** E8d T8 y T9 (`BoardScene`, frame loop). El resto las leyó el controlador.
- **Cierre por contexto:** a las 13:54 el controlador tenía 246k (umbral 250k) y no despachó tareas nuevas; esperó a E3b T4, la
  revisión de E8d T9 y el `rapido`.
- **La lista de palabras de E12 no se tocó:** sigue sin confirmación del dueño en el chat.

## Trampas nuevas

- **Lanzar el `rapido` con la carga > 200 y dos agentes compilando excede el tope:** a las 13:18 el controlador lo lanzó con carga
  602 (E8d T9 + E3b T4 compilando) y lo cortó en el acto por el árbol de PIDs propio; se relanzó cuando entregó uno.
- **El plan puede nombrar el tab equivocado:** el de Ajustes es `hud.settings`, no `hud.menu` (E7b-a T5).

## Carries por tarea

- **E8d T8/T9 → T15 y el dueño (G1/G2/G3):** el fondo animado de los pisos **ya está activo en producción** (10 `bgloop_*` sin `odrTag`);
  mirar en device el ablande al fundir el `bgloop` de 1024² sobre el póster de 2048², el `SKVideoNode` dentro de un `SKCropNode` y el
  tirón del HUD al suspender en cada swipe en el SE. Los overlays de SwiftUI no suspenden el fondo. `simulateSwipeDrag` es DEBUG.
- **La revelación con video depende de ODR:** 53 `characters` con `odrTag`; se precarga el del próximo tier al asentarse. **Sin test
  ODR con un `ArtPackSource` falso;** `closeReveal` sin identidad; la imagen doble foto/loop se mira en G3.
- **E3a T11 → su cierre (T12):** no corrió `BottomMenuUITests`, `BonusHUDUITests` ni `HUDRedesignUITests` en iPhone (E3b T4 cubrió en
  parte los dos primeros) → `completo` de cierre de E3a. Los toasts de logros y el aviso de torre no usan `playColumn`.
- **E3b T4:** sólo la página quieta queda montada (pierde el `NavigationStack` al deslizar); Tienda en sesión de una sola página; cinco
  páginas. **`BonusHUDUITests.testElCofreSeGanaSeVeYSeAbreDesdeRegalos` está rojo también en la base** (sospecha de E2a T14, ya anotada).
- **E7b-a T5:** sin prueba en región UE con el SDK real (que la fila abra el formulario).
- **E8c T9 → T10:** el fixture de cadena no cubre ascenso ni piso nuevo (`runAscentAnimation` y `runFloorUnlockCelebration` sin paso de test);
  sigue sin captura ni grabación (SE + Reduce Motion); posición del contador provisoria; el comentario viejo de
  `CelebrationQueue.swift:68` lo corrige T10.
- **Siguen vigentes** los de los relevos 14 a 19.

## Para el dueño

- **En device:** el fondo animado de los pisos (ya activo): ablande 1024² → 2048², tirón al soltar un swipe en el SE, fps y memoria
  (G1/G2/G3); la revelación con video con ODR real (G5); `SKVideoNode` dentro de `SKCropNode`.
- **Privacidad:** probar en una región UE con el SDK real que la fila «Opciones de privacidad» abre el formulario.
- **Escuchar** el whoosh del reveal, que ahora suena siempre (con o sin video).
- Siguen: la lista de palabras de E12 sin activar (falta la confirmación en el chat), mediación por SPM, capturas de ASC de las
  ofertas, el back-fill de los cofres de piso de la v1, el arte repetido de E8 T7, oír los `sfx_ev_*`. Todo también en `DUENO.md`.

## Oráculo

- `rapido` sobre `f2308e7` (E2b T1, E8c T9): VERDE (EK 636 · unit 1039 + 1 declarado · Release 0).
- `rapido` sobre `b8a3c1e` (+ E8d T8, E3a T11, E7b-a T5): VERDE (EK 636 · unit 1047 + 1 declarado · Release 0) → `version-2` a `7a5395b`.
- `rapido` final sobre la punta de `integ-r20` (con E8d T9 y E3b T4): VERDE sobre `2e43db0` (EK 636 · unit 1055 + 1 declarado `theOwnersTargetsAreMet` · Release 0)
- Tareas: E2b T1 EK 636 · unit 34; E8c T9 unit 9; E8d T8 unit 63; E3a T11 unit 4; E7b-a T5 unit 11; E8d T9 unit 54; E3b T4 sus UI tests.
- No se corrió un `completo` nuevo; el de referencia sigue siendo el `--limpio` de `c94f75f`.

## Lo descartado

- Revisión de E2b T1, E8c T9, E3a T11, E7b-a T5 y E3b T4: mecánicas o acotadas; el controlador leyó el diff.
- Los opcionales de la revisión de E8d T9 (identidad en `closeReveal`, test de ODR tardío): quedaron como carries.
- Reintentar la activación de la lista de palabras de E12.

## Cierre

- Subagentes en vuelo: los marca el controlador. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla. Quedan `v2i-docs-r20` y `v2i-integ-r20` para el barrido final
  (`limpiar-worktrees.sh`), más los de r19 si no se barrieron.
