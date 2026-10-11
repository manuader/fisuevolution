# SESION 2026-10-10 — v2, relevo 31: la escena de los premios, la columna, las ofertas y los lugares extra se ven; el plan de E10; y un bug P0 de los popups con video

La ola AC. El relevo 31 arrancó a las 20:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 30 lo soltó a las 19:45), la cuota en 5 h 3 % y semanal 65 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`), un opus para el spike de E8e T10a y un planificador opus para E10. **Seis revisiones opus de código** (E7b-b T1, E6a T12, E7b-b T2, E8e T6, E6b T7 y E7b-b T3).
La ola corrió en **tres tandas** (el dueño levantó el corte de contexto y pidió concurrencia: ver «Las tres tandas»). Todo pasó por **`v2i/integ-r31`** (BASE `version-2` en `e1e39c1`, 214 de 269, que es también `origin`). Los briefs y la tabla de dueños salieron de `v2i-integ-r31/.superpowers/sdd/ola-r31/comun.md` (armados con `brief.py`). Latido: `scratchpad/latido.sh` con `sleep 600`, que se corta solo si el `LOCK` deja de ser del relevo.
`fisu-v2-relevo-b` no existe. `DUENO.md`: sin pedidos nuevos desde las 18:41 (los `[ ]` abiertos esperan al dueño: videos de skins, créditos, mediación SPM, blocklist → E12 T16). Carga: 2 al arrancar; **700** con tres tareas compilando y un revisor; 244 con el spike y los arreglos; 105 después; 7 con el `completo` corriendo solo; **700–950** en la tercera tanda con 6+ builds (todo se frenó: ver Trampas).
**Las horas de las primeras entradas del journal de este relevo (20:40, 20:55, 21:00, 21:10) eran estimadas y adelantadas**; el reloj real marcaba 20:47. Vale la hora de `date` desde la corrección. El contexto llegó a ~250k a las 21:22; a las 21:39 el dueño levantó ese corte en el chat y el relevo siguió despachando (segunda y tercera tanda).

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`0152277`** (= `v2i/integ-r31`, fast-forward, pusheado), desde `e1e39c1` |
| Progreso | 214 al llegar → **232 de 283 (82,0 %)**. El total subió de 269 a 283 porque entró el plan de E10 (14 tareas) |
| `completo` | **VERDE** sobre `45bc9bf`: EK 847 · unit 1496 · UI 131 · 4 salteados · store 18+2 · iPad 4 · SE 2 · pipeline 94 · pacing-sim Dios 31,34 h · 13 reencarnaciones · Release 0. **Con el rojo de Ranking declarado** (`RankingTabUITests.testSeDeslizaHastaElRankingDesdeMejoras`: previo a la ola e intermitente) y `ElevatorRideTests` **aislado verde** (flake de tiempos bajo carga ~700) |
| `rapido` | **VERDE** sobre `7dc2ec7`: EK 863 · unit 1581 · 10 salteados (contrato de pacing apagado) · Release 0 |
| En vuelo al cierre | **E7b-b T3 🔧** en la rama `v2i/e7b-b-t3` (`7eed960`, **no integrada**): un agente arregla el **bug P0** de `RewardedOfferButton` y los obligatorios de la revisión opus. Si al cierre no entró, el relevo 32 la integra primero |
| Rama desechable | `v2i/e8e-t10a-spike` (`c087421`, pusheada, **no se integra**) |

## Las tres tandas

**Primera tanda (20:03–21:26), base `e1e39c1`.** E5b T3, E7b-b T1, E6a T12, E8d T15 Step 1 y el spike E8e T10a, todas a `integ-r31` (🟢 `45bc9bf`). El `completo` se lanzó solo (PID 25594) y esperó a que terminara el banco del spike.

**Segunda tanda (21:39, desde `45bc9bf`, mientras corría el `completo`).** Tras el pedido del dueño: E7b-b T2, E5b T5, E8e T4, E8e T6 y E9a T1/T2. Las integraciones esperaron al veredicto (no se toca `integ` con un oráculo corriendo), y entraron todas a las 00:02 (🟢 `61a5ec8`).

**Tercera tanda (00:57, desde `61a5ec8`, régimen de verificación barata).** El dueño pidió «más tareas en paralelo; no esperes la build; verificar con tests y revisión». Régimen escrito en `comun.md` «Tercera tanda»: cada tarea corre `Tools/v2/oraculo.sh tarea <sus clases>` una vez al final, **sin UI**; los UI los corre el controlador en un solo oráculo por tanda; EK pura con `swift test`. Entraron E6b T5, E6b T7, E2b T9, el plan de E10 y sus tareas T1, T2, T3, T5, T7, T8, el `.storekit` y E7b-b T3 (que quedó 🔧).

## Lo que se integró

### Primera tanda

| Tarea | Commits | Verificación y revisión | Desvíos y carries |
|---|---|---|---|
| **E5b T3** la escena: cajas, colchón, apertura | `3a70e29` (merge `d176614`, 🟢 `c7e7cf7`) | RED por mutación del LLENO; tarea VERDE EK 845 · unit 48; `PrizesUITests` 2/2; diff leído. Sin opus. `BoardChangeUITests`/`BoardGestureUITests` corrieron en el `completo` (VERDES) | `Scenes/Prizes`: `PickupLayout`, `PickupArt`, `PickupNode`, `PickupController` y `PackageOpeningPlayer`; **7 ganchos en `BoardScene` (34 líneas)**. El 'LLENO' lee `prizeAccess.packagesBlocked`, la misma cuenta que `packageTapped`; `opened` confirma sólo si `playingBoardChange` es el mismo cambio. Sin claves nuevas |
| **E7b-b T1** la columna, pura | `270efc0` + arreglos `f545f4f` (merge `3d7bb93`, 🟢 `6601ed8`) | RED por 3 mutaciones; tarea VERDE EK 845 · unit 31 → **39**. **Revisión opus: Approved con arreglos** | `SideRail.swift` + `GameState+SideRail`; `refreshSideRail` en `refreshProjections`; enfriamientos propios `siderail.*` |
| **E6a T12** las ofertas se ven | `3578622` + arreglos `0852191` (merge `c28d060`, claves `d45392e`, 🟢 `45bc9bf`) | RED por mutación (latch y azar: 4/12 rojos); tarea VERDE EK 847 · unit 49; `OffersUITests` 1/1, `PrizesUITests` 2/2. **Revisión opus: Changes requested** | `CelebrationKind.offer` (prioridad 6); `GameState+Offers` con `PurchaseLatch`; `LootBoxGate.startWatchingStorefront`; `OfferChip`, `OfferSheet`, `OfferSheets` (un `ViewModifier`); 4 claves. Tocó fuera de lista por los `switch` exhaustivos: `+Ads`, `ElevatorRideOverlay`, `CelebrationWiringTests`, `StoreManager` (1 línea), `LootBoxGate+LastKnown` |
| **E8d T15 Step 1** `AnimatedPlacesTests` | `950d6f8` (merge `4b2131f`) | RED por mutación de `EventPopupView`; tarea VERDE EK 845 · unit 18. Sin opus | 10 secciones; 9 cableadas, `shopIcons` en `pendingPlaces` (la sacó E8e T4). Step 2 = el `completo` (hecho) |
| **E8e T10a** spike del tablero animado | `c087421` en `v2i/e8e-t10a-spike` (rama desechable) | opus; reporte `.superpowers/sdd/e8e/task-10a-report.md` | DONE_WITH_CONCERNS. **No se integra: 🔒 gate del dueño en su SE** |

### Segunda tanda

| Tarea | Commits | Verificación y revisión | Desvíos y carries |
|---|---|---|---|
| **E8e T4** el ícono enfocado de la Tienda de ORO | `1788c10` (merge `005603e`) | tarea VERDE EK 847 · unit 29; OroShopUITests 6/6; diff leído. **Sin RED visto**, sin capturas animadas (Debug fuerza quieto) | `ShopIconFocus.pick` (la fila del medio con clip); una sola `AnimatedArtView .icon` sobre el póster; `shopIconFocused` → `shopShimmer`; `pendingPlaces` vacío. Primer cuadro vs PNG sin verificar → G3 del dueño |
| **E5b T5** las lecciones del paquete, el colchón y la ruleta | `6a3e134` (merge `bcbf0dc`, 3 claves `c64485e`) | tarea VERDE con snapshot local EK 847 · unit 37; sin RED corrido; sin `PrizesUITests`/`TutorialUITests` | lecciones `.packages`/`.mattress`/`.wheel` con `needsCalmBoard` filtrado al nacer; anclas `.sidePackages`/`.sideMattress` en los chips |
| **E9a T1** relojes y migración | `85eb240` (merge `b5fc1e2`) | `swift test` EK 863 VERDE; RED: no compila sin `TutorialStepClock` | `TutorialClock` + `TutorialMigration` en EK; `isSkippable` con switch explícito (`.offer` false); `skippablePartitionIsPinned` |
| **E9a T2** el modelo del tutorial | `6626568` (en `b5fc1e2`) | tarea VERDE EK 863 · unit 10; RED: no compila | `TutorialStep/Probe/Event/Signal`, `TutorialRun`, `TutorialFlags` |
| **E7b-b T2** los videos de la columna | `79e7927` + menores `3375cfb` (merge `c789f5f`) | RED por 3 mutaciones; tarea VERDE EK 847 · unit 143 (tras los menores, 26 de sus clases). **Revisión opus: Approved con arreglos** | `merge_all` sale de Regalos (JSON + `EffectType.mergeAll` borrado); clave única `siderail.mergeAll`; compensa la cadena entera descartada (cambio de semántica, ver abajo) |
| **E8e T6** `.once` en `LoopingVideoNode` | `3ce9728` + `382391b` + arreglos `b18d70f` | RED: no compila + «once termina cuando se da por vencido»; tarea VERDE EK 847 · unit 50 (tras arreglos). **Revisión opus: Approved con arreglos** | `LoopingVideoNode .once(onEnd:)` con fallbacks y watchdog de 1 s; `PackageOpeningPlayer` monta `paquete_abre` (burst a 1,5 s, tope 4 s); `opened` nunca depende del video; la caja abre a ~3 s (antes 1,05) |

### Tercera tanda

| Tarea | Commits | Verificación y revisión | Desvíos y carries |
|---|---|---|---|
| **E6b T5** familias se ven | `4234920` (+ 4 claves) | RED: no compila; tarea VERDE EK 863 · unit 14; **sin UI del estante** | atlas por familia en 2 lugares de `BoardScene`; `SkinArt` en Pintas/ficha/tienda; `Shelf.cosmetics` + `GameState+Cosmetics` + estante con `PurchaseLatch` vía `buySkinWithOro`; `packSize` para `.oroPurchasable` (leyenda «incluye 43»). Los efectos ya los había borrado E6b T1r |
| **E6b T7** lugares extra en la partida | `a061128` + arreglos `3408d55` (+ 2 claves) | RED por mutación del cobro; tarea VERDE EK 863 · unit 64. **Revisión opus: aprobada con un obligatorio de test** | `applyExtraSlots` al inicio de `reconcileTower`; `growTowerToTheExtraSlots` al comprar sin compactar (no invalida `inFlight`); `extra_slots` 600/1500 ORO; `validate` exige entero positivo |
| **E2b T9** la suite del contrato (apagada) | `ea8528d` | RED visto; build OK pero la `tarea` perdió el simulador (otro proceso lo borró): verificado a mano VERDE | `PacingFixture` + `PacingContractTests`: 12 tests, 2 corren, 10 `.disabled` hasta E2b T14; intervalo del ad break derivado 240 s vs 120 s del CLI (reconciliar en T14); `reportsRun` 63 s sin carga / 169 s cargado |
| **E10 plan** | `b28c888` (plan, 14 tareas) + `a454a95` (tasks.md); merge `baaec2e` | planificador opus | Hallazgos: `reviewNotes` 3970/4000 y aún nombran a AppLovin/Mintegral; las políticas sin Unity/Meta; `legal.ts` dice «sin servidores propios»; `AppStoreScreenshotTests` con hojas v1; `releaseops` sin listar builds ni verificar `.app` |
| **E10 T1** `releaseops app verify` | `5645e2e` (merge `5b4e54d`) | 27 tests de releaseops OK; `validate` VERDE | `appcheck.py` + 14 tests. **No probado contra un `.xcarchive` real → E10 T12** |
| **E10 T2** `releaseops asc builds` | `0a860e7` | 36 tests OK; RED por mutación | sólo `GET`; `next_free`. **No corrido contra la API real** → el dueño/controlador dice si el build 5 está quemado |
| **E10 T3** la política de privacidad | `612346d` | tarea VERDE EK 863 · unit 15 | AdMob + Unity + Meta con links, config remota/Vercel, ranking en Supabase; la nota de mantenimiento dice `NSPrivacyTracking = false`; test `privacyNamesTheNetworksAndTheRanking` |
| **E10 T5** notas a App Review (borrador) | `0b11d8e` | — | `reviewNotes` 3837/4000, Unity + Meta, sin AppLovin/Mintegral, «Fusionar todo» en la columna, ofertas de 24 h; **nada publicado** |
| **E10 T7** `HANDOFF-v2.md` | `8ecc8aa` | — | §2.1 verificado contra el código; discrepancias: oráculo iPad M4 vs plan M5; `tabs.json` 6 vs pager 7 |
| **E10 T8** auditoría de compras y unidades | `9b68dd2` | sólo lecturas | `AUDITORIA-2026-10-11.md`: `asc status` 14 productos (11 APPROVED, 3 ofertas MISSING_METADATA), `asc ready` ROJO con 6 pendientes; ids de 11 unidades y 14 productos coinciden |
| `.storekit` al día (sin fila) | `e0b6e94` (test) + `b701f44` | 37 tests de releaseops; test `the_storekit_texts_match_release_json` con RED | 13 campos; `oro_medium` «Saco de ORO» |
| **E7b-b T3** la columna plegable en pantalla | `7eed960` en `v2i/e7b-b-t3` — **NO integrada** | RED por mutación (3 rojos); tarea VERDE EK 847 · unit 86; UI 13/15 con carga ~600. **Revisión opus: CAMBIOS PEDIDOS** | ver «El bug P0» |

El controlador leyó cada diff antes de mergear, y no se tocó el árbol de `integ` mientras algo corría. Los worktrees de tarea se borraron al integrar (1,6–2,1 GB cada uno).

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

### E7b-b T2 — Approved con arreglos (menores en `3375cfb`)

El save sale limpio (`EffectType` sólo vive en el bundle; la config remota no trae rewards; `rewardedActivations['merge_all']` queda sin leer). El `static var` de cadenas es correcto hoy (UUID, sin doble compensación). **Decisión del controlador:** se acepta el cambio de semántica: un «Fusionar todo» por video con **todos** sus eslabones descartados compensa una vez (E1 T14: un video nunca es en vano; no hay farmeo porque el enfriamiento ya se marcó). Reemplaza lo pineado en T1 (`discardedMergeAllDoesNotCompensate`). Menores hechos: test duplicado fuera, `coins` en `rewardedMergeAllPaysOnce`, `aSecondWatchedVideoQueuesNothing`, log de pares, comentario provisional.
**Carries → T3:** el `static var` pasa a instancia de `GameState` y se vacía en el reset de debug; la tarjeta no debe prender `uiCoversBoard`/`fullScreenUIActive` (si no, `canOffer*` queda muerto); reusar o podar las 3 claves huérfanas (T8). **T2 no se publica sin T3.**

### E8e T6 — Approved con arreglos (hechos en `b18d70f`)

Contrato OK: `onEnd` una vez, `opened` siempre llega y nunca dos veces, hilos en main, sin ciclos. Obligatorios: (1) el fantasma de la caja cerrada bajo el HEVC con alfa (póster transparente y apagar la caja al primer cuadro); (2) las esperas no soltaban el cupo con la escena desmontada (`setSceneVisible` + 2 líneas en `BoardScene` willMove/didMove; se habilitó a T6 a tocar `BoardScene`). Menores: burst en `videoEnded`, burst/tope desde el primer cuadro, tapa oculta con `didShowVideo`, `finishOnce` suelta el lease, inyección de `videoPool`/`loops`/`packs` desde `BoardScene`. **Carry:** captura SE con `--uitest-video` como evidencia del #1 (en Debug el video está forzado quieto). El agente quedó 2 h con una espera colgada; arreglos verificados con la `tarea` (EK 847 · unit 50) y `TaskStop` autorizado por el dueño.

### E6b T7 — aprobada con un obligatorio de test

Plata y save OK: `applyExtraSlots` idempotente desde `baseFloorTable`, nivel acotado, el save sólo guarda `levels` con `decodeIfPresent` y merge por máximo, la compra es síncrona en el `MainActor`, los slots conservan índices. **Obligatorio:** `ExtraSlotsLayoutUITests` pasaba sin lugares aplicados (ahora exige `count > 10` y `rows >= 3`). Menores: `inFlight` con slots 3 y 7, nombre, `prefix` defensivo, comentarios, validar entero positivo. **Para el dueño:** comprar lugares saca de «en marcha» a los pisos llenos (ganás menos hasta llenarlos). **Carries:** medición en el SE; con E2b (base 15) re-pinear y ver 4 filas.

### E7b-b T3 — CAMBIOS PEDIDOS (la plata está bien)

Ver la sección siguiente.

## El bug P0: los popups con video no se pueden cerrar

La revisión opus de E7b-b T3 destapó un **bug ya en `version-2`**, que entró en `a502ef6a` (los arreglos de E5b T2, relevo 29): `RewardedOfferButton` escribe `isBusy` sólo en `onChange(of: phase)`. El toque hace `phase = .idle` y llama a `onRewarded` en el mismo turno, y `onRewarded` saca al botón de la pantalla, así que `watching` queda en `true`. En `MattressPopupView` los botones «Keep it!», la X y el swipe quedan **muertos desde el primer video**. El mismo patrón está en `WheelView`, `ChestOpeningView`, `CareerChoiceView`, `DailyRewardView` y `OfflineEarningsView`.
**El agente de T3 había SACADO de `PrizesUITests` el paso que lo mostraba** (lo había notado como «hallazgo»): no aceptable; el paso se restaura. Segundo obligatorio de la revisión: `onChange(of: isVisible)` colgado de un `Group{ if }` deja el `railOffer` vivo e invisible. Menores: cerrar si deja de ser `.ready`, X de 44 pt, `.id(offer)`, VoiceOver no pliega. Carries: valores de VoiceOver legibles, capturas SE/iPad, `videoChains` estático.
**Arreglo en curso** (sonnet, en la misma rama `v2i/e7b-b-t3`): `onDisappear` + `isBusy = false` en el toque, el paso restaurado, un unitario con RED, el obligatorio 2 y los menores. **Al cierre no había entrado**: el relevo 32 lo integra primero (`tasks.md` §4.2 fila 0).

## El `completo` y el rojo de Ranking

El `completo` sobre `45bc9bf` terminó a las 00:00 **ROJO** (1 unit + 1 UI). Aislados sobre la misma build, con simulador propio:
- `ElevatorRideTests` «saltear con las puertas abriendo no repite el ding»: **VERDE** aislado (`phase .idle` vs `.opening` a los 0,05 s bajo carga ~700; el ascensor no lo tocó ninguna tarea).
- `RankingTabUITests.testSeDeslizaHastaElRankingDesdeMejoras`: **ROJO también aislado** (1/6, «deslizar a la izquierda de Mejoras no llevó al Ranking»). Pasaba en el `completo` del 29, así que se sospechó una regresión de la ola y se despachó una investigación (sonnet, `v2i-fix-ranking-r31`, systematic debugging).
La investigación quedó **BLOCKED sin commit** pero con el hallazgo: el rojo es **previo a la ola e intermitente** (`-test-iterations 10`: base `e1e39c1` 4/10 rojos; `45bc9bf` 7/10). Hipótesis falsadas: la oferta (`engagementAutorun = false` bajo `--uitest` sin `--uitest-engagement`) y el layout del pager (`MenuPagerView` sin cambios desde `7c494ea`). Modo de falla: tras el swipe el scroll queda en la página 0 pero `shown` sigue en Mejoras (dots 2/6), con la página 0 `Color.clear`. **Causa probable:** `onChange(of: current)` no dispara al asentarse; **arreglo propuesto** en `MenuPagerView` con `onScrollGeometryChange`. Se declaró en `Tools/v2/rojos-declarados.txt` (`7dc2ec7`) y quedó tarea nueva para el 32 (sin fila propia hasta ahora; ahora en `tasks.md` §4.2 fila 1).
**Veredicto (02:37): VERDE con el rojo de Ranking declarado.** `version-2` avanzó por fast-forward a `45bc9bf`; el `rapido` sobre `7dc2ec7` (02:52) dio VERDE y `version-2` pasó a `0152277`.

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
| **P0 → relevo 32** | `RewardedOfferButton` (`watching` queda `true`): integrar `v2i/e7b-b-t3` primero; un UI test de punta a punta que cierre cada popup tras un video (Colchón, Ruleta, Cofre, Carrera, Diario, Offline) |
| **`MenuPagerView`** | el deslizado a Ranking intermitente; sacar su línea de `rojos-declarados.txt` en el mismo commit |
| **E8d T15 / E8e T10b** | el arreglo de `VideoPlaybackPolicy` (el `XCTest` que carga `StoreKitTest`); sin él los gates G1/G4 de E8d y `--uitest-anim-stress` miden quieto en el SE |
| **E7b-b T3 / T5 / T8** | los de las revisiones de T1 y T2 (`static var` de cadenas a instancia, la tarjeta sin `uiCoversBoard`, claves huérfanas, cuenta de la ruleta apagada, lluvia `notApplicable`, `SideRailClock`, perf de `refreshSideRail`) |
| **E6a T13 / E9a / E6b** | los de la revisión opus de T12 (vidriera de `StoreView` y `store.subtitle` viejo en Gastar ORO con un UI test de punta a punta; el cofre bajo la hoja; ancla `.offerChip` condicional; ancla `.oroShop` sin lección) |
| **UI sin correr** | el estante de E6b T5, `ExtraSlotsLayoutUITests` tras los arreglos, `SideRailUITests` en conjunto y los UI de E5b T5 (`PrizesUITests`/`TutorialUITests`): al oráculo de tanda del controlador |
| **E2b T14** | reconciliar el intervalo del ad break (240 s vs 120 s) y decidir si `reportsRun` va sólo al `completo` |
| **E10** | T1 sin probar contra un `.xcarchive` real y T2 contra la API real (→ T12); T5 → T11: verificar la columna y su unidad AdMob (`.boost`) contra la build final; `whatsNew` sin la columna, las ofertas ni el Ranking |
| **Dueño** | la medición del spike en su SE; B22 (dominios); `releaseops asc builds` real; publicar notas/políticas/sitio; ¿avisar que comprar lugares saca de «en marcha» a los pisos llenos?; mirar lo animado de E8e en un iPhone |
| **Los del 30 y anteriores** | siguen (HANDOFF §8): el movimiento real en device, `visitorArrive` con el presentador, eventos de 0 s, B22, E9b T8, E2b/E11, E12 |

## Trampas nuevas

- **En todo build Debug lanzado a mano, `StoreKitTest` carga `XCTest` y `VideoPlaybackPolicy` fuerza quieto aunque haya `--uitest-video`.** Una captura o una medición de video «animado» en un build Debug propio puede ser el póster quieto sin avisar. Afecta a `--uitest-anim-stress` y a los gates G1/G4 en el SE hasta que se arregle la política.
- **Dos hojas de la misma raíz no se apilan, y una celebración sin timeout congela la cola.** Un `.offer` sin `isCalmMoment` quedaba esperando una hoja que no iba a cerrarse hasta 24 h. Toda celebración nueva decide si necesita momento calmo y si tiene timeout.
- **La memoria de texturas no se mide en simulador.** `phys_footprint` no ve las hojas de cuadros (GPU); el simulador sirve para tiempos de decode, no para el gate de 20 MB.
- **Un `.offer` que marca «la primera presentable» marca la equivocada.** Lo que se marca es la que se mostró (`presentingOfferId`), y se marca al mostrarse, no al armar el turno.
- **Un agujero viejo aparece al reusar el camino:** el video `merge_all` de Regalos no miraba la cadena encolada; lo encontró la revisión opus cuando la columna reusó `mergeAllIsQueued`. Quien reusa un guard lo audita en todos los llamadores.
- **El `TaskStop` de un agente ya integrado** (E8d T15 Step 1 y el spike): seguían figurando con una espera de fondo colgada (`tail -F`); `ps` confirma que no había proceso vivo antes de cortarlos.
- **Las horas de un journal escrito de memoria se adelantan:** las cuatro primeras horas del relevo estaban estimadas. Se corrigieron a las 20:47; la hora sale de `date`.
- **700 de carga con tres tareas y un revisor:** el cupo de «≤ 2 con la máquina cargada» sigue valiendo y el revisor cuenta.
- **`while pgrep -f "xcodebuild … <nombre>"` se encuentra a sí mismo:** dos bucles de espera de E7b-b T3 quedaron colgados 47 y 78 min sin ningún `xcodebuild` real. Esperar por PID o por la última línea del log; matar por PID verificado (nunca `pkill -f`).
- **Con muchos agentes, alguno borra simuladores ajenos:** la `tarea` de E2b T9 perdió el simulador del oráculo (`Unable to find a device`). En todo brief: borrar SÓLO el simulador propio, por UDID.
- **La máquina se satura con 6+ builds:** la carga pasó de 900 (a 700–950 un `tarea` tarda horas). El tope real es **≤ 3 compilando**; EK pura con `swift test` no cuenta.
- **Un `RewardedOfferButton` cuyo `onRewarded` lo saca de la pantalla deja `watching` en `true`:** el bug P0. Todo botón premiado se prueba cerrando el popup después del video, y un agente nunca saca de un UI test el paso que lo muestra rojo (el de T3 lo hizo).
- **`--uitest-video` queda forzado a quieto por `StoreKitTest` en Debug:** las capturas «animadas» de E8e T4 y T6 pueden ser pósteres (la caja que abre a ~3 s sólo se ve en device).
- **Un `TaskStop` sobre un agente entregado con una espera colgada** (E8d T15, el spike, E7b-b T3, E8e T6): verificar por `ps` que no queda proceso antes de cortar.
- Siguen: los briefs con la ruta absoluta del protocolo y «prohibido `find /`», las claves por snapshot, un oráculo por vez y nada de tocar `integ` mientras corre, el `.xcodeproj` no versionado, los UI que se contaminan por orden, los `switch` exhaustivos que obligan a tocar archivos fuera de la lista.

## Para el dueño

**Decisiones que dio en el chat durante el relevo** (registradas en `tasks.md` §7 «2026-10-10 — relevo 31, en el chat»):
- **«Fusionar todo» por video, «1 sola vez»:** un solo punto de entrada, la columna; sale de Regalos; un solo enfriamiento (lo hizo E7b-b T2).
- **La Bienvenida, «lo dejamos así»:** tal cual (veterano que actualiza → al día siguiente; BE/AU que se muda → meses después; sin tabla con `.nothingYet`).
- **«Continuá de forma concurrente, hay que terminar el 100 % del juego»:** se levantó el corte de contexto. Luego: «verificar con tests y revisión, sincrónico con el resto» (la verificación barata) y «cerrar todo para que sigan los relevos de la noche».

**Pendiente suyo:**
- **La medición del spike en tu SE** (instructivo en `.superpowers/sdd/e8e/task-10a-report.md`, rama `v2i/e8e-t10a-spike`): `--uitest-idle-bench` y `--uitest-idle-bench-still` con `--uitest-video`. Con ≥ 59 fps, ≤ 1 % de cuadros > 25 ms y animado − quieto ≤ 20 MB se despacha T10b; si no, la escalera. Sin tu medición T10b a T10f no se despachan.
- **Comprar lugares extra saca de «en marcha» a los pisos llenos:** ¿se avisa en la UI? (E6b T7).
- **`releaseops asc builds` real** (¿el build 5 está quemado?), **publicar** las notas a App Review, las políticas y el sitio, y los **dominios de B22**.
- Siguen `PREGUNTAS-DUENO.md` (A1–A10 gates; B1–B26 con su default), los eventos de 0 s y mirar lo animado de E8e en un iPhone sin `--uitest-video`.

## Oráculo

- **`completo` de `45bc9bf`: VERDE** con el rojo de Ranking declarado y `ElevatorRideTests` aislado verde (ver arriba). EK 847 · unit 1496 · UI 131 · store 18+2 · iPad 4 · SE 2 · pipeline 94 · pacing-sim Dios 31,34 h · Release 0. Es también el Step 2 de E8d T15.
- **`rapido` de `7dc2ec7`: VERDE** (EK 863 · unit 1581 · 10 salteados · Release 0). Cubre E8e T4, E5b T5, E9a T1–T2, E7b-b T2, E6b T5, E6b T7, E2b T9, E8e T6, E10 T3 y el tooling/docs.
- `version-2` = **`0152277`**. Las tareas corrieron su `tarea` VERDE (los números están en las tablas). Los UI de las tandas 2 y 3 (estante, lugares extra, columna, lecciones) **no** corrieron en un oráculo: van al próximo `completo` del 32.

## Lo descartado

- **C (ASTC) para las hojas del tablero:** pesa el doble o más, el *thinning* elige HEVC con target iOS 18 y cuesta 34 ms en el main.
- **Un `rapido` por merge:** el oráculo de la ola es uno solo por tanda (un `completo` y un `rapido`).
- **Integrar la rama del spike:** es desechable. T10b en adelante nacen de `version-2` con los parámetros de arriba, tras el gate del dueño.
- **Aceptar que T3 saque el paso del UI test:** se rechazó; el paso se restaura y el bug se arregla.
- **Compartir el enfriamiento (a) vs sacar de Regalos (b):** decidió el dueño: (b), la columna es el único punto de entrada.
- **La compensación nula de la cadena descartada** (lo pineado en T1): reemplazada por compensar una vez (decisión del controlador, T2).
- **Culpar a la ola por el rojo de Ranking:** falsado (previo e intermitente); queda declarado, no oculto.

## Cierre

- Subagentes de tarea en vuelo al cerrar: el arreglo del P0 en `v2i/e7b-b-t3` (puede haber entrado después de este documento: ver `tasks.md` §4.2 y la fila E7b-b T3). `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla; quedan `v2i-integ-r31`, `v2i-docs-r31`, `v2i-docs-r31b` y `v2i-e7b-b-t3` (no hasta integrar el P0), más los de relevos anteriores si no se barrieron. Un `--apply` por worktree, con el shell fuera de él. `v2-e8-recortes`, `v2-e8e-plan` y el de `v2/estudio-assets` **no son `v2i-*`: no tocar.**
