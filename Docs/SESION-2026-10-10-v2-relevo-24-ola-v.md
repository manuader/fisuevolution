# SESION 2026-10-10 — v2, relevo 24: el cierre de E4a, el perfil `.max` y el CLI del simulador, la Liquidación en el precio, las ofertas que se cobran y el escenario

La ola V. El relevo 24 arrancó a las 03:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 23 lo soltó a las 03:02), la cuota en 5 h 9 % y semanal 57 %.
Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); revisión opus para E4b T7 (precios), E6a T11 (dinero) y E4b T1 (el turno del tablero).
Todo pasó por **`v2i/integ-r24`** (BASE `version-2` en `5e29d35`). Carga de la máquina: 3,3 al arrancar; hasta 3 compilando. Los briefs salieron de `Tools/v2/brief.py`
(`v2i-integ-r24/.superpowers/sdd/ola-r24/`, con `duenos.md`). Latido: `scratchpad/latido.sh` (`sleep 30`, escritura por reloj ≥ 9 min). El contexto llegó a 253k a las 04:27: no se despachó
nada nuevo después, se terminó E4b T1 y se cerró.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | **`91b7634`** tras el `rapido` VERDE sobre `25cc5da` (EK 825 · unit 1190 · 0 rojos · Release 0); **182 de 254 (71,7 %)** |
| `v2i/integ-r24` | `9b02cdd` (suma E4b T1, 🟢) + `tasks.md`; los docs del cierre van en `v2i/docs-r24` |
| Progreso | **182 de 254 en `version-2`; 183 de 254 (72,0 %) con E4b T1 🟢** si el `rapido` de la punta da VERDE |
| `rapido` de la punta | VERDE (EK 827 · unit 1207 · 0 rojos · Release 0) |
| Bloqueadas | ninguna nueva. E7b-a T3 sigue ⛔ y es **bloqueo de publicación**; E12 T12 ⛔ (espera a E9b T8) |

`rapido` de la tanda, en orden: `db27a2c` **ROJO** (unit 1188 / 2 rojos: el bug de abajo); `25cc5da` VERDE (EK 825 · unit 1190 · 0 rojos · Release 0); la punta con E4b T1 (`9b02cdd` + `tasks.md`): VERDE (EK 827 · unit 1207 · 0 rojos · Release 0).
No hubo `completo` en esta ola: el último de referencia sigue siendo el de los cierres del 23 (sobre `bab8a9c`).

## Lo que se integró

| Tarea | Commits | Oráculo y revisión | Desvíos |
|---|---|---|---|
| **E4a T10** cierre de E4a (docs) | `69d81df` (merge `76a6a2b`, tasks `2c4de70`) | sin código; el paso 1 (el `completo`) lo cubre el de los cierres del 23 sobre `bab8a9c`; verificado que `loops_manifest.json` sí nombra `cayo_mercado_pago` y que `938efcb` existe | `Docs/SESION-2026-10-10-v2-e4.md` + HANDOFF §4/§5/§7/§9; los escenarios a mano pasaron a 🔒 del dueño. Se despachó **en paralelo con E4b T1** porque T10 es sólo docs y el código de E4a T1–T9 ya estaba |
| **E2b T7** el perfil `.max` (EK) | `37a26c1` (merge `ae3d7b6`) | EK 819; diff leído (4 archivos). DONE_WITH_CONCERNS | `ShopPermanents` + `PacingSources.shop`; `.max` usa `FloorTable.expanded`, `bestSupplierLevel` en el r y giros de más como videos. `.bare` **byte a byte idéntico (`cmp`)**: Dios 31,34 h · 13 reenc. La tabla `.max` vs `.ads` no se pudo medir sin el CLI de T8 |
| **E2b T8** el CLI del pacing-sim (EK) | `c89383f` (merge `892aa1e`) | EK 821; diff leído (EK, 2 líneas de motor). DONE_WITH_CONCERNS | Flags de perfil/fuentes/perillas + `--contract` + `--shop`; `SourcesLoader`, `ContractReport`; knobs `floorCapacity`/`oroDivisor`/`oroExponent`. **Fix de EK:** la pausa publicitaria sin premios colgaba `.ads` (no vencía). Default **byte a byte idéntico** (`cmp`). Tabla abajo |
| **E4b T7** la Liquidación en el precio | `a8c7a06` + arreglos `0999169` (merge `bbd1586`, tasks `3d614b8`) | tarea VERDE 51 · EK 817; `QuickHireUITests` 3/3; revisión opus: Approved con arreglos, hechos | Piso `spawnCostStackFloor` 0,25 sólo en `spawnCostMultiplier`; `listCostText` en `JobRow`/`QuickHireOffer`/`GameState`; `StrikePrice` + `PricePill.strikeText` («antes X»); clave `price.ax.was` por snapshot. **Después, el `rapido` encontró un bug real: ver abajo (`25cc5da`)** |
| **E6a T11** las ofertas se cobran | `6daa880` + arreglos `05019e2` (merge/tasks `db27a2c`) | tarea VERDE unit 35; `StoreManager`/`StoreProducts` 18/18; revisión opus: Approved con arreglos, hechos | `offer_bienvenida/renacer/mudanza` consumibles en `products.json` y `.storekit` (IDs = `release.json`); `offers.json` en `GameContent`; `GameState+Offers.creditOffer(_:transactionID:now:)` **sin mirar la ventana**; ORO por `recordOroPurchase` + `grant(.oro)`; `lastClosedAt` por `OffersEngine.markPurchased`; 6 claves por snapshot |
| **E4b T1** el escenario y su turno | `52a1b9f` + arreglos `788db95` (merge `9b02cdd`, tasks 🟢) | tarea VERDE (EK 816 · unit 39); `CharacterSheet`/`QuickHire`/`BonusHUD` UI 9/9 **antes** de los arreglos; revisión opus: Approved con arreglos, hechos. DONE_WITH_CONCERNS | `StageVisit`/`GameState+Stage`/`StageController`/`VisitorNode`/`SpeechBubbleNode`/`BubbleGeometry`/`VisitorArt`; `.visitorEncounter` en `CelebrationQueue`; fila `debug.stage.demo` en su sección al final. Tocó **una palabra fuera de tabla** por un `switch` exhaustivo: `GameState+Ads.endsInNaturalBreak` y `ElevatorRideOverlay.coversElevator` → `false` (la revisión los dio por correctos). Sin verificación visual a mano |

Merges en `integ-r24` (encadenados): E4a T10 `76a6a2b`; E2b T7 `ae3d7b6`; E4b T7 `bbd1586`; E2b T8 `892aa1e`; E6a T11 `db27a2c`; arreglo del piso `25cc5da`; E4b T1 `9b02cdd`. Los worktrees se borraron al integrar
(622 MB el de E4a T10, 908 MB E2b T7, 1.664 MB E4b T7, 969 MB E2b T8, 1.644 MB E6a T11). Claves por snapshot aplicadas al integrar E4b T7 (`price.ax.was`) y E6a T11 (6 claves).

## El bug que encontró el `rapido`: el piso de descuentos anulaba la contratación gratis

E4b T7 puso un piso de 0,25 al producto de descuentos apilados, dentro de `ModifierMath.factor`. Pero la **contratación gratis** es un modificador de **magnitud 0**: su factor es 0, y el piso lo subía a 0,25, así que
«gratis» costaba el 25 %. La tarea había pasado (51 verdes), y la **revisión opus no lo vio**: verificó que «ningún modificador baja de 0,5» y razonó sobre descuentos reales del contenido, no sobre el caso límite 0.
Lo vio el `rapido` sobre `db27a2c`: **ROJO, unit 1188 con 2 rojos**, `CorralitoTests` («contratar gratis…») y `JobRowsTests` («una contratación gratis…»). Lo arregló el controlador en **`25cc5da`**: el piso sólo se
aplica si `product > 0`, más un test de EK, `freeHiringSkipsTheFloor` (4/4). Tarea del fix VERDE (EK 825 · unit 48/0) y `rapido` relanzado sobre `25cc5da`: VERDE (EK 825 · unit 1190).
**Lección:** un clamp en una función de modificadores se prueba con magnitud 0 (gratis), con 1 (neutro) y con el borde exacto; los revisores opus lo piden en el brief (trampa abajo).

## Los perfiles del simulador: la tabla de E2b T8

La vara fue la de siempre: la base queda idéntica `cmp` línea por línea antes de medir con las perillas. Con `--prestige-threshold 4`:

| Perfil | Dios | Reencarnaciones | Notas |
|---|---|---|---|
| default (sin flags) | 31,34 h activas | 13 | **byte a byte idéntico** a antes de T7/T8 |
| `.bare` | 22,34 h | | con el umbral 4 |
| `.free` | 18,77 h | | |
| `.ads` | 12,84 h | | |
| `.max` (`--shop 5,3,3`) | 12,75 h | 6 | prácticamente igual que `.ads` |

`maxStaffedFloors`: **0 con la perilla en v1**, **7 con `--staffed 0.05 --capacity 15`** (la duda de E2b T4, resuelta). Dudas que quedan: `oro_shop.json` no existe todavía, así que `.max` es `.ads` sin `--shop`;
`sideRail`/`adBreak` **no están en `rewarded_ads.json`** (la forma de los datos se supuso: confirmar en E7b); el contrato `.free` da **3 de 8 pisos en banda**, que es el punto de partida de E2b T12.

## Las revisiones opus y sus carries

- **E4b T7** (Approved con arreglos). Obligatorio hecho: `DiscountedPriceTests.stackedDiscountsChargeTheFloor` no discriminaba (0,25 vs 0,245 con tolerancia 0,01) → 4 descuentos y tolerancia 1e-3, RED comprobado.
  Opcionales hechos: VoiceOver «antes X» en el atajo; test recargo + descuento. Verificado bien: el piso sólo en `spawnCostMultiplier`, el pacing-sim no tiene modificadores (Dios no se mueve), precio mostrado = cobrado
  (mismo quote y mismo `now`), los recargos no se tachan. **Carries:** el piso se aplica al producto **con recargos incluidos** (hoy no pasa con el contenido); captura SE del precio tachado (dueño).
- **E6a T11** (Approved con arreglos). Obligatorios hechos: `StoreManager` revoca también `.offer` en el reembolso (+ test hermano); `OffersPurchaseTests.creditsOnce` discrimina (RED comprobado). Opcionales hechos: una oferta desconocida no
  se marca acreditada (**pero `StoreManager` igual hace `finish()` de la transacción**); copy `iap.*.desc` = `release.json`; test del resolver (`unseenOro` una vez). **Carries:** **E6a T12 no debe ofrecer la Bienvenida (cofre) en BE/AU**;
  **E9b T8:** caso de oferta reembolsada; **al dueño:** el reembolso de una oferta sólo revoca su ORO (como los packs) y el resolver puede perder lo que no es ORO (el cofre pagado) comprado en el dispositivo perdedor.
- **E4b T1** (Approved con arreglos). Obligatorio hecho: la `Section` Escenario antes de Peligro del panel de debug. Opcionales hechos: `stageVisit = nil` si se cancela antes del turno; gatear la entrada con `boardIsVisibleForChanges`;
  `CelebrationWiringTests` con `phase == .entering`; 2 tests (cancelar en espera, watchdog). Verificado bien: las 3 salidas pasan por `releasePayload` idempotente, la prioridad 5 no pisa cinemática/cofre/reveal, el tope de 10 s
  alcanza (iPad 13 ~8,4 s), sin `SKAction`s ni fugas, nada del escenario se persiste. **Carries:** **E4b T2** (`presentOnStage` por `canPresentOnStage`; la paciencia no corre en intersticial; `arrive`/`openStagePopup` vacíos);
  **E4b T3/T4** (revisar los `switch` y la prioridad 5 cuando se vaya `.eventBanner`); **dueño** (visual en SE/iPad/Reduce Motion).
- **E2b T8** (diff leído): ver las dudas arriba.

## Decisiones de la ola (sin decisiones nuevas del dueño)

- **La contratación gratis no se toca con el piso** (`product > 0`): el piso de 0,25 protege contra descuentos apilados, no contra el modificador «gratis».
- **`creditOffer` acredita aunque la oferta no figure abierta** (carry del 22): la compra ya se cobró; mirar la ventana la perdería. `lastClosedAt` se marca igual (una sola vez, en `markPurchased`).
- **El reembolso de una oferta revoca su ORO** y, con el arreglo, también el entitlement `.offer`; no revoca lo no-ORO (se anota al dueño).
- **E4a T10 se despacha ∥ E4b T1**: con T10 sólo docs y el código de E4a ya integrado, no hay choque de archivos.

## Las trampas de la tanda

- **Un agente con trabajo de fondo colgado re-entrega el mismo reporte** (E2b T7: 4 entregas; E4b T7 también). Una vez integrado el trabajo: `TaskStop` y verificar con `ps` que no queden procesos suyos. Sigue siendo
  la única ocasión en que `TaskStop` es válido (el agente ya entregó).
- **Un agente cuyo reporte de arreglos nunca llega** (E4b T1: la notificación decía «entregado» y no había mensaje; un `SendMessage` pidiéndolo no sirvió). No esperar: **leer su commit** (`788db95`), leer el diff
  y verificar contra la lista de la revisión; así se hizo. Los tests que no se re-corrieron se declaran como carry (abajo).
- **Los revisores opus tienen que buscar magnitud 0 y los casos límite en los modificadores.** La revisión de E4b T7 afirmó «ningún modificador baja de 0,5» y no miró el modificador gratis (magnitud 0). Va en el brief
  de toda revisión de precios o de `ModifierMath`: «¿qué pasa con magnitud 0, con 1 y con el borde del clamp?».
- **Un clamp nuevo en una función compartida cambia a todos sus llamadores**, no sólo al caso del brief. Lo agarró el `rapido`, que corre toda la unit; el `tarea` de E4b T7 corría sus propias clases.
- **Un `tarea` no corre UI, y los arreglos de E4b T1 tampoco se re-corrieron:** se movió la `Section` del panel de debug (ningún UI test usa la sección Peligro: `grep`) y `CharacterSheet`/`QuickHire`/`BonusHUD` **no** se volvieron
  a correr. Quien siga con `DebugPanelView` (E4b T2) los corre; si no, el próximo `completo`.
- Siguen: el oráculo usa el repo de su propia ruta, `setsid` no existe en macOS, las EK puras no ocupan cupo, `rapido` uno por vez, la tabla de dueños va en cada brief.

## Carries

| A | Qué |
|---|---|
| **E4b T2** | `presentOnStage` por `canPresentOnStage`; la paciencia no corre en intersticial; `arrive`/`openStagePopup` vacíos (T1 los dejó stubs); **correr `CharacterSheetUITests`, `QuickHireUITests` y `BonusHUDUITests`** (los arreglos de T1 no los re-corrieron); fila nueva de debug al final de la `List`; presentador re-chequea `eventIsApplicable`; `loops_manifest` `events.cayo_mercado_pago` → `home_banking`; atenuar la cuota sin plata (del 23) |
| **E4b T3/T4** | revisar los `switch` exhaustivos y la prioridad 5 de `.visitorEncounter` cuando se vaya `.eventBanner`; las dos palabras en `false` (`endsInNaturalBreak`, `coversElevator`) |
| **E6a T12** | no ofrecer la Bienvenida (cofre) en BE/AU |
| **E9b T8** | caso de oferta reembolsada; unir `offers.purchases` y `seenCinematics` en `resolveAcrossReset` (del 23) |
| **E7b** | confirmar la forma de `sideRail`/`adBreak` en `rewarded_ads.json`; unificar `isCalmMoment` |
| **E2b T9/T12/T13** | `.free` da 3 de 8 pisos en banda (punto de partida de T12); `oro_shop.json` para medir `.max` con `--shop`; cap 10 vs 15; «Fusionar todo» (del 23) |
| **precios (cualquier tarea)** | el piso de 0,25 incluye recargos en el producto (hoy no pasa con el contenido) |
| **Dueño** | captura SE del precio tachado; visual del escenario en SE/iPad/Reduce Motion; los escenarios a mano de E4a T10; el reembolso de una oferta sólo revoca su ORO y el resolver puede perder el cofre pagado en el dispositivo perdedor; los del 23 y anteriores |

## Para el dueño

- E4a T10: los tres escenarios a mano (eventos desde el panel, el primer evento a los 15 min, matar la app en la espera) siguen sin hacerse en device.
- E4b T1: el escenario no se vio a mano ni en SE ni en iPad ni con Reduce Motion.
- E4b T7: captura SE del precio tachado («antes X»).
- E6a T11: el reembolso de una oferta revoca su ORO y su entitlement, pero lo no-ORO (un cofre pagado) puede perderse en el dispositivo perdedor al resolver.
- Siguen los del 23 (video de salida de un evento que vence corriendo, `.eventStartup`/`.eventBlanqueo`, llegadas del Paquete en inactivo), los del 22 (E3b T9, E6a T1, E12 T15 / `NSPrivacyTracking`) y los del 21c
  (**no publicar E7b-a T2 sin T3**). Los 🔒: credenciales de Supabase y `ANTHROPIC_API_KEY` (E12 T16), mediación por SPM (E7b-a T6).

## Oráculo

- `rapido`: `db27a2c` ROJO (unit 1188 / 2: el piso y la contratación gratis); `25cc5da` VERDE (EK 825 · unit 1190 · 0 rojos · Release 0); punta (`9b02cdd` + `tasks.md`): VERDE (EK 827 · unit 1207 · 0 rojos · Release 0).
- Tarea del fix (`CorralitoTests`, `JobRowsTests`, `DiscountedPriceTests`, `QuickHireOfferTests`): VERDE (EK 825 · unit 48/0).
- Sin `completo`: el de referencia sigue siendo el de los cierres del 23 sobre `bab8a9c`.

## Lo descartado

- Despachar nada más tras los 253k de contexto: se terminó E4b T1 y se cerró.
- E5a T7 en esta ola: comparte `+Engagement` con E4b T1/T2. Para la ola que sigue, una de las dos por ola o serializadas (ver `tasks.md` §4.2).
- E6a T12: sigue ⛔ (faltan E6a T7/T8, E5a T8, E4b T3, E5b T1/T2). E2b T9+ siguen ⛔ (esperan a E6a T4, E7b-a T3, E7b-b T2).

## Cierre

- Subagentes en vuelo: los marca el controlador. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla; quedan por barrer `v2i-integ-r24` y `v2i-docs-r24` (con el shell fuera), más los de relevos anteriores si no se barrieron.
