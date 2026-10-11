# SESION 2026-10-10 — v2, relevo 31: la escena de los premios, la columna y las ofertas se ven; el spike del tablero animado fija sus parámetros

La ola AC. El relevo 31 arrancó a las 20:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 30 lo soltó a las 19:45), la cuota en 5 h 3 % y semanal 65 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`) y un opus para el spike de E8e T10a. Dos revisiones opus de código (E7b-b T1 y E6a T12: las dos llevan plata o turno de tablero).
Todo pasó por **`v2i/integ-r31`** (BASE `version-2` en `e1e39c1`, 214 de 269, que es también `origin`). Los briefs y la tabla de dueños salieron de `v2i-integ-r31/.superpowers/sdd/ola-r31/comun.md` (armados con `brief.py`). Latido: `scratchpad/latido.sh` con `sleep 600`, que se corta solo si el `LOCK` deja de ser del relevo.
`fisu-v2-relevo-b` no existe. `DUENO.md`: sin pedidos nuevos desde las 18:41 (los `[ ]` abiertos esperan al dueño: videos de skins, créditos, mediación SPM, blocklist → E12 T16). Carga: 2 al arrancar; **700** con tres tareas compilando y un revisor (por eso no se despachó nada más hasta que bajó); 244 con el spike y los arreglos; 105 después; 7 con el `completo` corriendo solo.
**Las horas de las primeras entradas del journal de este relevo (20:40, 20:55, 21:00, 21:10) eran estimadas y adelantadas**; el reloj real marcaba 20:47. Vale la hora de `date` desde la corrección. El contexto llegó a ~250k a las 21:22: desde ahí no se despachó nada nuevo.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **sin cambios: `e1e39c1`** (214 de 269). Esta ola no avanzó `version-2`: el oráculo de la ola es un `completo` y sigue corriendo |
| `v2i/integ-r31` | `45bc9bf` (suma E5b T3, E7b-b T1, E8d T15 Step 1 y E6a T12, todas 🟢) + los docs del cierre (`v2i/docs-r31`) |
| Progreso | 214 al llegar → **217 de 269 (80,7 %)** si el `completo` da VERDE: E5b T3, E7b-b T1 y E6a T12 entran como ✅ COMPLETO_PENDIENTE. E8d T15 sigue 🔄 (su Step 2 es ese mismo `completo`) |
| `completo` | **COMPLETO_PENDIENTE** — sobre `45bc9bf`, lanzado SOLO (nada compilando, carga 7): `build/relevo31-completo.log`, PID 25594. Cubre E5b T3, E7b-b T1, E6a T12 y E8d T15 Step 2 |
| Bloqueadas | ninguna nueva. E5b T3 destraba E8e T6 y E6b T5 (E5b T7 espera además a T5); E7b-b T1, a T2; E6a T12, a E6a T13, E6b T7 y E9a T1 |
| Rama desechable | `v2i/e8e-t10a-spike` (`c087421`, pusheada, **no se integra**) |

## Lo que se integró

| Tarea | Commits | Verificación y revisión | Desvíos y carries |
|---|---|---|---|
| **E5b T3** la escena: cajas, colchón, apertura | `3a70e29` (merge `d176614`, 🟢 `c7e7cf7`) | RED por mutación del LLENO; tarea VERDE EK 845 · unit 48; `PrizesUITests` 2/2; diff leído. Sin opus. **No corrió** `BoardChangeUITests` ni `BoardGestureUITests` → al `completo` | `Scenes/Prizes`: `PickupLayout`, `PickupArt`, `PickupNode`, `PickupController` y `PackageOpeningPlayer`; **7 ganchos en `BoardScene` (34 líneas)**. El 'LLENO' lee `prizeAccess.packagesBlocked`, la misma cuenta que `packageTapped`; `opened` confirma sólo si `playingBoardChange` es el mismo cambio. Sin claves nuevas. Worktree borrado (1730 MB) |
| **E7b-b T1** la columna, pura | `270efc0` + arreglos `f545f4f` (merge `3d7bb93`, 🟢 `6601ed8`) | RED por 3 mutaciones; tarea VERDE EK 845 · unit 31 → **39** con los arreglos; diff leído. **Revisión opus: Approved con arreglos** (abajo) | `SideRail.swift` + `GameState+SideRail`; `rewardedMergeAll` ya existía en EK, así que no tocó `BoardChange` ni `+BoardChanges` en el primer tramo. `refreshSideRail` va en `refreshProjections`; los enfriamientos propios son `siderail.*`. Worktree borrado (1792 MB) |
| **E6a T12** las ofertas se ven | `3578622` + arreglos `0852191` (merge `c28d060`, claves `d45392e`, 🟢 `45bc9bf`) | RED por mutación (latch y azar: 4/12 rojos); tarea VERDE EK 846 → **847** · unit 36 → **49**; `OffersUITests` 1/1, `PrizesUITests` 2/2; diff leído. **Revisión opus: Changes requested** (abajo) | `CelebrationKind.offer` (prioridad 6); `GameState+Offers` con `PurchaseLatch`; `LootBoxGate.startWatchingStorefront` desde `StoreManager.start`; `gregorianCalendar` compartido; `OfferChip`, `OfferSheet`, `OfferSheets` (un `ViewModifier`); 4 claves (`e6a-t12.json`). Tocó fuera de lista por los `switch` exhaustivos: `+Ads`, `ElevatorRideOverlay`, `CelebrationWiringTests`, `StoreManager` (1 línea), `LootBoxGate+LastKnown`. `BonusHUDUITests.testTwoBonuses...` rojo en conjunto, **verde solo** (el orden de siempre) |
| **E8d T15 Step 1** `AnimatedPlacesTests` | `950d6f8` (merge `4b2131f`) | RED por mutación de `EventPopupView`; tarea VERDE EK 845 · unit 18; diff leído. Sin opus | 10 secciones del manifest; 9 cableadas, **`shopIcons` en `pendingPlaces`** (lo saca E8e T4 o lo pasa E6b T7); un segundo test obliga a limpiar `pendingPlaces` al cerrar E8e. Worktree borrado (1707 MB) |
| **E8e T10a** spike del tablero animado | `c087421` en `v2i/e8e-t10a-spike` (rama desechable, pusheada) | opus; reporte `.superpowers/sdd/e8e/task-10a-report.md` (forzado en la rama) + GIFs, capturas y `metrics.json` en `.superpowers/sdd/e8e/t10a/` | DONE_WITH_CONCERNS. Parámetros y mediciones abajo. **No se integra: 🔒 gate del dueño en su SE** |

El controlador leyó cada diff antes de mergear, y no se tocó el árbol de `integ` mientras algo corría.

## Las revisiones opus

### E7b-b T1 — Approved con arreglos (hechos en `f545f4f`)

- **Obligatorio #1, un agujero viejo de Regalos.** El video `merge_all` de `+Bonus` no miraba `mergeAllIsQueued`: con una cadena de ORO o de columna encolada se veía el video, se gastaba el enfriamiento y los eslabones se descartaban sin compensar. Arreglo: guard en `+Bonus` y el test `rewardedMergeAllWithQueuedChainCompensates`, con RED por mutación visto.
- Menores hechos: `mergeAllIsQueued = chain != nil` y movido a `+BoardChanges` (compartido por la columna y por `oroShopContext`; el cambio en `oroShopContext` es un refactor puro porque `planMergeAll` siempre pone `chain`); el test de decode sin `sideRail` (`missingSectionUsesDefault`); el tope del enfriamiento (`backwardsClockIsCapped`).
- **Carries → T2:** dos enfriamientos del mismo premio (`merge_all` y `siderail.mergeAll`; recomendación (a) compartirlos o (b) sacarlo de Regalos: lo decide el dueño o T2); `isBoardBusy` en la acción y releer los pares antes del anuncio; la cadena de video entera se descarta sin compensar. **T2/T3:** la cuenta de la ruleta apagada y la lluvia `notApplicable` con piquete. **T3:** localizar `SideRailClock`. **Perf:** medir `refreshSideRail` (`planMergeAll` a 8 Hz).

### E6a T12 — Changes requested (arreglos en `0852191`, el controlador leyó el diff)

La plata salió limpia: el latch se suelta en todos los caminos, `isPurchasing` lo respalda, `creditStorePurchase` es idempotente por `transactionID` y no hay `.disabled`; el watcher de la vidriera es único en el `MainActor`. Los tres obligatorios eran de turno y de marcado:

1. **`.offer` se encolaba sin `isCalmMoment`.** Con otra hoja arriba no se apila, y como la celebración no tiene timeout la cola se congelaba hasta 24 h. Arreglo: `.offer` sólo con `isCalmMoment`, y re-sync por tick (`CelebrationQueue.contains`, con test en EK).
2. **`offerSelection` fuera de `boardIsCovered`.** Ahora entra por `syncCover`.
3. **`markOfferPresented` marcaba la primera presentable, no la mostrada.** Ahora `markOfferPresented(id:)` y `presentingOfferId` (una línea en `GameState.swift`, `@ObservationIgnored`) más `offerTurnHasSomethingToShow`; `presented` y el `save` ocurren al mostrarse.

Menores hechos: el chip marca la oferta, se monta sólo si hay ofertas y lleva `accessibilityValue`; `gregorianCalendar` es `static let`; un UI test de «una sola vez»; `debugOpenOffer` con guard. RED por mutación visto (2 rojos).

**Carries:** el cofre queda bajo la hoja al cerrar; la Bienvenida sin tabla con `.nothingYet` (dueño, 3.1.1); el chip sólo cubre `.first`; la vidriera de `StoreView` y `store.subtitle` viejo en Gastar ORO → **E6a T13** (con un UI test de punta a punta); E6b T7: las hojas nuevas van en `boardIsCovered`; E9a: el ancla `.offerChip` es condicional y el ancla `.oroShop` sigue sin lección. **Dueño:** el veterano que actualiza recibe la Bienvenida al día siguiente; un BE/AU que se muda la recibe meses después.

## El spike E8e T10a (opus, rama desechable)

**Parámetros fijados** (los que usa T10b en adelante, si el dueño da el gate):

| Parámetro | Valor |
|---|---|
| Cuadros por hoja | **16** |
| Lado de cada cuadro | **256 px** |
| Formato | `png8-sheet`, `idle_<tipo>.png`, dentro de `anim-piso-<n>` |
| Índices de cuadro | `int(i*120/N + 0,5)` |
| fps | `N / 5,0 s` = **3,2** (el loop real dura 5,0 s, no 5,04) |
| Tope de animados y memoria física mínima | `maxAnimated` y `minPhysicalMemoryGB` en `nil`: **PROVISORIOS** |
| Texturas | una `SKTexture(cgImage:)` por cuadro, en el main (o fuera) |
| Fase por personaje | `slot * 5 mod N` |

**Disco medido:** A16·256 pesa **6,34 MB** en total (el pack del piso 3, 1,26 MB); todas las variantes A entran. **C (ASTC) DESCARTADA:** 12,7 a 15,1 MB, y con target iOS 18 el *thinning* elige HEVC (sin ahorro de GPU); además 34 ms en el main y +30 MB transitorio.
**Simulador SE 3 / iOS 18.6:** el decode fuera del main tarda 62 a 108 ms y el armado en el main 15 ms, así que **T10c arma ≤ 1 hoja por frame**.
**Memoria: NO medible en simulador.** `phys_footprint` no ve las hojas (viven en GPU); la estimación es ~40 MiB de RGBA para el piso 3 con 16·256, el doble de la vara de 20 MB. Por eso el gate **🔒 es del dueño en su SE** (instructivo en el reporte): ≥ 59 fps, ≤ 1 % de cuadros > 25 ms, animado − quieto ≤ 20 MB. Si no entra: escalera 12 cuadros → 192 px → N más cercanos → quieto < 3 GB (ASTC ya no está en la escalera).

**Hallazgo (el más caro de la ola):** en todo build Debug lanzado a mano, `StoreKitTest` (weak-linked) carga `XCTest`, y `VideoPlaybackPolicy` fuerza el modo quieto **aunque haya `--uitest-video`**. El spike lo parchea; lo que queda sin parchear es que afecta también a `--uitest-anim-stress` y a los gates G1/G4 de E8d en el SE. **Arreglo propio en `version-2` (carry a E8d T15 y a E8e T10b).**
El agente se cortó con `TaskStop` tras entregar (un `tail -F` colgado; `ps`: 0 después). Worktree del spike borrado.

## Carries

| A | Qué |
|---|---|
| **E8d T15 / E8e T10b** | el arreglo de `VideoPlaybackPolicy` (el `XCTest` que carga `StoreKitTest`); sin él los gates G1/G4 de E8d y `--uitest-anim-stress` miden quieto en el SE. Y `BonusHUDUITests.testTwoBonuses...` cae en conjunto y pasa solo (el orden) |
| **E8e T4** | sacar `shopIcons` de `pendingPlaces` de `AnimatedPlacesTests`; ya está destrabada por E6a T12 |
| **E7b-b T2 / T3** | los de la revisión opus de T1 (dos enfriamientos del mismo premio, `isBoardBusy` en la acción, cadena de video descartada sin compensar, cuenta de la ruleta apagada, lluvia `notApplicable`, `SideRailClock`, perf de `refreshSideRail`) |
| **E6a T13 / E6b T7 / E9a** | los de la revisión opus de T12 (vidriera de `StoreView` y `store.subtitle`; hojas nuevas en `boardIsCovered`; ancla `.offerChip` condicional; ancla `.oroShop` sin lección) |
| **Dueño** | la Bienvenida: veterano que actualiza (al día siguiente) y BE/AU que se muda (meses después); la Bienvenida sin tabla con `.nothingYet` (3.1.1); dos enfriamientos del mismo premio en la columna; la medición del spike en su SE |
| **Los del 30 y anteriores** | siguen (HANDOFF §8, «cierre del relevo 30»): el movimiento real en device, `visitorArrive` con el presentador, eventos de 0 s, `ui_oro_extra_slots` en `pendingShopIcons` (E6b T7), B22, E9b T8, E2b/E11, E12 |

## Trampas nuevas

- **En todo build Debug lanzado a mano, `StoreKitTest` carga `XCTest` y `VideoPlaybackPolicy` fuerza quieto aunque haya `--uitest-video`.** Una captura o una medición de video «animado» en un build Debug propio puede ser el póster quieto sin avisar. Afecta a `--uitest-anim-stress` y a los gates G1/G4 en el SE hasta que se arregle la política.
- **Dos hojas de la misma raíz no se apilan, y una celebración sin timeout congela la cola.** Un `.offer` sin `isCalmMoment` quedaba esperando una hoja que no iba a cerrarse hasta 24 h. Toda celebración nueva decide si necesita momento calmo y si tiene timeout.
- **La memoria de texturas no se mide en simulador.** `phys_footprint` no ve las hojas de cuadros (GPU); el simulador sirve para tiempos de decode, no para el gate de 20 MB.
- **Un `.offer` que marca «la primera presentable» marca la equivocada.** Lo que se marca es la que se mostró (`presentingOfferId`), y se marca al mostrarse, no al armar el turno.
- **Un agujero viejo aparece al reusar el camino:** el video `merge_all` de Regalos no miraba la cadena encolada; lo encontró la revisión opus cuando la columna reusó `mergeAllIsQueued`. Quien reusa un guard lo audita en todos los llamadores.
- **El `TaskStop` de un agente ya integrado** (E8d T15 Step 1 y el spike): seguían figurando con una espera de fondo colgada (`tail -F`); `ps` confirma que no había proceso vivo antes de cortarlos.
- **Las horas de un journal escrito de memoria se adelantan:** las cuatro primeras horas del relevo estaban estimadas. Se corrigieron a las 20:47; la hora sale de `date`.
- **700 de carga con tres tareas y un revisor:** el cupo de «≤ 2 con la máquina cargada» sigue valiendo y el revisor cuenta.
- Siguen: los briefs con la ruta absoluta del protocolo y «prohibido `find /`», las claves por snapshot, un oráculo por vez y nada de tocar `integ` mientras corre, el `.xcodeproj` no versionado, los UI que se contaminan por orden, los `switch` exhaustivos que obligan a tocar archivos fuera de la lista.

## Para el dueño

- **La medición del spike en tu SE** (instructivo en `.superpowers/sdd/e8e/task-10a-report.md`, rama `v2i/e8e-t10a-spike`): `--uitest-idle-bench` y `--uitest-idle-bench-still` con `--uitest-video`. Con ≥ 59 fps, ≤ 1 % de cuadros > 25 ms y animado − quieto ≤ 20 MB se despacha T10b; si no, la escalera de arriba. Sin tu medición T10b a T10f no se despachan.
- **La Bienvenida de las ofertas:** un veterano que actualiza la recibe al día siguiente y un BE/AU que se muda la recibe meses después; y sin tabla de probabilidades con `.nothingYet` (3.1.1). ¿Se acepta tal cual?
- **El video de Regalos y la columna** comparten (o no) el enfriamiento del mismo premio: (a) un solo enfriamiento o (b) sacarlo de Regalos.
- Siguen `PREGUNTAS-DUENO.md` (A1–A10 gates; B1–B26 con su default), los dominios de B22, los eventos de 0 s y mirar lo animado de E8e en un iPhone sin `--uitest-video`.

## Oráculo

- **`completo` COMPLETO_PENDIENTE** sobre `45bc9bf` (`build/relevo31-completo.log`, PID 25594, solo). Si es VERDE: E5b T3, E7b-b T1 y E6a T12 ✅ (217 de 269), `version-2` ff a `45bc9bf` (o al commit de docs que lo sume), y E8d T15 Step 2 hecho. Si es ROJO: aislar la clase caída sobre la misma build antes de culpar a una tarea (candidatas: `BoardChangeUITests` y `BoardGestureUITests`, que no corrieron con E5b T3; los UI de ofertas y de regalos; `BonusHUDUITests` por orden).
- Las tres tareas de la ola corrieron su `tarea` VERDE (E5b T3: EK 845 · unit 48; E7b-b T1: EK 845 · unit 39; E6a T12: EK 847 · unit 49) y E8d T15 Step 1 EK 845 · unit 18. No hubo `rapido` en la ola: el único oráculo es el `completo`.
- Los dos rojos por orden del `completo` del 29 (`MenuPagerUITests`, `CustomizationUITests`) se aíslan antes de declarar.

## Lo descartado

- **C (ASTC) para las hojas del tablero:** pesa el doble o más, el *thinning* elige HEVC con target iOS 18 y cuesta 34 ms en el main.
- **Un `rapido` por merge:** el oráculo de la ola es un solo `completo` al final, que además es el Step 2 de E8d T15. Esperó a que terminara el banco del spike para no ensuciar sus mediciones.
- **Despachar E5b T5 con E6a T12 en vuelo:** `TutorialAnchor` es de E6a T12; no se despachó hasta que ésta se integrara.
- **Despachar E8e T4 y E5b T5 en la ola:** E6a T12 llegó a 🟢 a las 21:22 con el contexto en 250k, así que no se despachó nada nuevo; las dos quedan ⏳ para el 32, ya destrabadas.
- **Integrar la rama del spike:** es desechable. T10b en adelante nacen de `version-2` con los parámetros de arriba, tras el gate del dueño.

## Cierre

- Subagentes de tarea en vuelo: 0 al despachar los docs del cierre. `LOCK`: lo libera el controlador, tras el veredicto del `completo` (o sin él, con el `completo` documentado como pendiente).
- Worktrees: se borró el de cada tarea al integrarla (`v2i-e5b-t3` 1730 MB, `v2i-e7b-b-t1` 1792, `v2i-e8d-t15` 1707, `v2i-e6a-t12` y el del spike); quedan por barrer `v2i-integ-r31` y `v2i-docs-r31`, más los de relevos anteriores si no se barrieron. Un `--apply` por worktree, con el shell fuera de él.
  `v2-e8-recortes`, `v2-e8e-plan` y el de `v2/estudio-assets` **no son `v2i-*`: no tocar.**
