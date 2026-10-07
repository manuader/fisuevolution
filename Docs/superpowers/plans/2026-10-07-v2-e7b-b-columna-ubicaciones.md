# E7b-b — Anuncios v2, lo que se toca: la columna plegable, sus videos, el diario y la carrera ×2, y el mapa de ubicaciones · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** la columna lateral **plegable** que eligió el dueño (opción C del 🔒, 2026-10-07): en
reposo, un solo botón "Premios" abajo a la izquierda con el "!" sumado; al tocarlo despliega la
Ruleta, El Colchón, los Paquetes y Fusionar todo, cada uno con su "!" y su latido cuando hay algo
listo y su reloj cuando falta, y se repliega sola a los 3 s (o al tocar uno). Además: sus dos
videos (Fusionar todo y la lluvia de paquetes), el diario ×2 y la carrera ×2 por video, un botón
de video que precarga y un contrato que pinea en qué unidad de AdMob cae cada video del juego.

**Architecture:** la columna no decide nada: lee una proyección pura (`SideRailModel` →
`GameState.sideRail`, publicada a lo sumo una vez por segundo) que junta lo que E5 ya publica
(`prizeAccess`) con dos relojes y dos videos nuevos, y toca por las puertas que E5 dejó
(`openWheel()`, `mattressTapped()`, `packageTapped()`). Fusionar todo por video encola los pares
del piso con su propio origen en el embudo de E1 (`enqueueMergeAll(onFloor:origin:)` de E2a),
y la lluvia es un `RewardSpec` entregado por `grant` (E4a). La columna es **hermana de la
botonera del ascensor** (E3a T8): la misma placa de metal (`MetalPlate`), el botón en reposo del
alto del display (44 pt), la persiana que se despliega con el mismo resorte y se recoge sola con
el mismo `.task(id:)`, botones de 30 pt (los del spike S6) con su reloj en LED. Cuelga del borde
de arriba de la franja de abajo, contra el borde izquierdo de la pantalla; los chips de premios
que E5b puso bajo el HUD se van. **`PlayLayout` no se toca**: plegada, la columna no le pide
lugar a la multitud. Los dos videos nuevos de E7 (diario y carrera) usan la unidad `daily`, y
`RewardedOfferButton` se vuelve el botón completo de los cimientos (precarga, sondeo, unidad
explícita). Un test que lee las fuentes pinea el mapa de ubicaciones de PLAN-v2 E7.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI
(`Grid`, `phaseAnimator`, `keyframeAnimator`) · EconomyKit · Swift Testing · XCUITest · XcodeGen.

**Fuente:** `Docs/PLAN-v2.md` §2 ("Accesos en pantalla", "Fusionar todo", "Sin anuncios"), §4
"E7" (columna lateral y mapa de ubicaciones), E2a ("Fusionar todo se activa con video"), E5
(la columna como acceso), E9 (anclas y lecciones), la botonera del ascensor (plan de E3a, Task 8)
y los spikes S4, S5 y S6 de E3a (`.superpowers/sdd/2026-10-07-v2-e3a-ux-nucleo/task-2-report.md`,
en `version-2`); la decisión del dueño sobre el 🔒 (relevo 6, 2026-10-07). **Las Global
Constraints, la "Verificación" y la Receta R de E7b-a (`2026-10-07-v2-e7b-a-forzados-mediacion.md`)
valen acá enteras**; abajo van sólo los agregados. Lo que PLAN deja abierto, en "Para el dueño".

**Rama de la épica:** `v2/e7b-anuncios` (la de E7b-a). E7b-b arranca cuando E4, E5 y E6
cerraron (sus planes dejan lo que esta mitad lee) y E7b-a T3 entró.

### Decidido por el dueño (2026-10-07, relevo 6): C, la columna plegable

El 🔒 era que la columna pisa la multitud en todo iPhone. El spike S5 de E3a lo midió: una
columna fija de 56 pt contra el borde izquierdo tapa entre 15 y 56 pt de la **primera columna de
personajes** en el SE, el 16 Pro y el Pro Max, en toda la altura de la multitud. En el iPad 13" no
toca nada: el campo está centrado y arranca en x = 210. Tampoco había lugar para subirla por
encima de la multitud: en el SE las cabezas de atrás empiezan en 139,5 pt.

La respuesta del dueño, textual: **"En reposo un solo botón «Premios» con el «!» abajo a la
izquierda; al tocarlo despliega los cuatro por 3 s. Sin achicar, pero un toque más y deja de ser
«fija»."** Queda como registro lo que se descartó y por qué:

| Opción | Qué cambiaba | Por qué no (o sí) |
|---|---|---|
| A | `PlayLayout` reservaba 64 pt a la izquierda cuando la columna se veía: el campo se corría y se achicaba. | **Descartada**: los personajes de iPhone pasaban a medir ~83 % de lo de hoy (celda SE 68,6 → 56,3; 16 Pro 74 → 61,5; Pro Max 81,6 → 68,7), justo cuando la crítica de Marco pidió más multitud. |
| B | La columna fija, encima de la multitud, sin margen. | **Descartada**: la primera columna de personajes quedaba tapada 15–56 pt todo el tiempo, y los toques ahí los tomaba la columna. |
| **C (elegida)** | Columna plegable, hermana de la botonera del ascensor. En reposo, un botón "Premios" de 44 pt con el "!" sumado, abajo a la izquierda. Al tocarlo despliega los cuatro botones por 3 s. | **Elegida**: no achica nada. En reposo tapa ~44 × 44 pt (el botón). Abierta, la persiana tapa ~94 × 112 pt de la multitud mientras dura, como la botonera abierta tapa las filas de atrás (S6). El costo es un toque más, y deja de ser "fija". |

Con C, **`PlayLayout` no cambia** (la tarea 4 quedó salteada) y la columna es una pieza de
SwiftUI que no toca la escena.

**Qué vive dónde** (la reconciliación con E4b/E5b/E6a):

| Lugar | Qué va | Quién lo puso |
|---|---|---|
| Columna plegable (abajo a la izquierda, arriba de la fila del atajo) | en reposo, "Premios" con el "!" sumado; abierta, Ruleta · El Colchón · Paquetes (con la lluvia por video cuando no hay) · Fusionar todo por video | **E7b-b** |
| `StageChips` (bajo el HUD, a la derecha) | el visitante en escena y su reto | E4b T3, T5 — **E7b-b le saca** los chips del paquete y del colchón que E5b T2 puso "hasta que exista la columna" |
| `ActiveBonusBar` (bajo el HUD, a la izquierda) | boosts, eventos con la cara del presentador | E1–E4b |
| Chip de oferta (bajo el HUD, a la izquierda) | la oferta de 24 h | E6a T12 |
| Cajas y colchón en el tablero (línea del escenario, ≥ 72 pt de cada borde) | se quedan: también abren el paquete y el colchón | E5b T3 |
| Botonera del ascensor (derecha) | el display y los pisos | E3a T8 |

## Global Constraints (además de las de E7b-a)

- **La columna no decide nada**: todo lo que muestra sale de `GameState.sideRail` (puro,
  `SideRailModel`), y todo lo que hace pasa por `sideRailTapped(_:)` y las puertas de E5b. Ningún
  cálculo de premios ni de relojes en la vista.
- **La proyección cambia a lo sumo una vez por segundo** (los relojes van en segundos enteros):
  la columna no invalida SwiftUI a 8 Hz.
- **La columna es hermana de la botonera del ascensor** (E3a T8): la misma `MetalPlate`, los
  mismos tonos de LED (`ElevatorPanel.ledScreen`/`ledLit`), el botón en reposo del alto del display
  (`ElevatorPanel.displayHeight`), los botones de 30 pt de la persiana (spike S6), el mismo resorte
  de 0,35 s para desplegar y el mismo `.task(id:)` para recogerse. La diferencia es a propósito: se
  recoge a los **3 s** (lo pidió el dueño para ésta; la botonera sigue en 2 s).
- **En reposo, un solo botón; abierta, a lo sumo 3 s sin uso.** La persiana se despliega sólo al
  tocar "Premios" o cuando una lección señala uno de sus botones (T5); nunca sola por un "!" nuevo.
  Tocar un botón la recoge.
- **Un video de la columna dice qué da ANTES del anuncio** (política de AdMob: opt-in con el
  premio a la vista): Fusionar todo y la lluvia se ofrecen en una tarjeta al lado de "Premios",
  nunca al primer toque.
- **Un video sin efecto no gasta su enfriamiento y compensa** (E1 T14, `compensateRewardedVideo()`).
- **La columna se esconde con el núcleo del tutorial y con las celebraciones que apagan la UI**
  (`hidesUIForCelebration`), igual que el resto del HUD.
- **Reduce Motion**: la persiana aparece con fundido (como la botonera); sin latido ni temblor; la
  tarjeta entra con fundido.
- **La escena no se toca**: con la columna plegable, `PlayLayout` y `BoardScene` quedan como los
  dejó E3a.
- **Strings por snapshot** `Tools/v2/claves-pendientes/e7b-b-tN.json` (regla de E7b-a).
- **Commits** `feat(columna): …`, `feat(anuncios): …`, `test(anuncios): …`, SIN `Co-Authored-By`.

## Verificación

La de E7b-a (oráculo y Receta R con `build/DD-e7b`). `rapido` al cerrar T1, T2, T6 y T7;
`completo` al cerrar T3 y T5 (lo que se ve) y T8. Cada tarea con UI se mira en el
**iPhone SE**, el **16 Pro** y el **iPad Pro 13"**, con Reduce Motion prendido y apagado;
capturas al reporte.

## Las referencias de PLAN-v2 que toca E7b-b, verificadas contra el árbol (`8d17b8d`)

| Lo que cita el plan | Dónde está hoy | Qué hace E7b-b |
|---|---|---|
| "Columna lateral fija a la izquierda: Ruleta, El Colchón, Paquetes y Boost por video; «!», reloj y latido" (§2, E7) | no existe; `RootView.hudColumn` (`RootView.swift:429-460`) y `bottomBar` (`:506-530`); S5: fija, pisa la multitud en todo iPhone → **el dueño eligió la plegable (C)** | T1–T3, T5 |
| la botonera del ascensor, de la que la columna es hermana | **E3a T8** (`UI/HUD/ElevatorPanel.swift`, todavía no en el árbol): display de 44 pt (`displayHeight`), persiana en `Grid` de 2 columnas sobre `MetalPlate`, `collapseDelay` 2 s con `.task(id: activity)`, resorte 0,35 s y fundido con Reduce Motion; **S6**: botones de 30 pt (no 34) y la grilla abierta tapa las filas de atrás mientras dura | T3 copia la mecánica y el material |
| los accesos de E5 | **E5b T2**: `PrizeAccess` (`packagesWaiting`, `packagesBlocked`, `mattressReady`, `wheelSpinsReady`), `refreshPrizeAccess`, `packageTapped()`, `mattressTapped()`, `openWheel()`; chips en `StageChips` | T1 lee, T3 toca y muda |
| "Boost por video" en la columna; "Fusionar todo: boost por video o por ORO" (§2) | `enqueueMergeAll(onFloor:origin:)` (**E2a T14**); `BoardChange.Origin` (`BoardChange.swift:13-20`, E1 T7, ya en el árbol: `eventStartup`, `eventBlanqueo`, `rewardedInstantMerge`, `rewardedRareUnit`, `career`, `debug`) sin caso de video; `.oroShop` (**E6a T6**) | T1 (`.rewardedMergeAll`), T2 |
| "lluvia de paquetes (treasure)" en el mapa de E7 | **nadie la ofrece por video**: `packageRateMultiplier` (**E4a T2**), por ORO en E6a; E5a: "va por `RewardedPlacement.treasure`" | T2, T3 |
| "diario ×2 y carrera ×2 (daily)" en el mapa de E7 | `DailyRewardView.swift:61-100` y `CareerChoiceView.swift:22-115` sin video; `lumpMinutes` de las carreras (**E2a T12**); `chooseCareer` acredita antes del merge (**E1 T12**) | T6 |
| `RewardedOfferButton`: "precarga + sondeo + spinner + id de accesibilidad" (cimientos de PLAN-v2 §4) | **E4b T3** lo hace sin precarga ni sondeo y con `placement` por defecto `.visitor` | T7 |
| "Mapa de ubicaciones (unidad entre paréntesis)" | `RewardedPlacement` (8 casos, `FeatureFlags.swift:17-36`), `rewarded(for:)` exhaustivo (`:118-130`); llamadores hoy: `GiftsView.swift:60-83, 265-268` (gifts, boost), `OfflineEarningsView.swift:45, 134-139` (offlineX2), `ChestOpeningView.swift:277-279, 784` (chestExtra) | T7: contrato |
| "Vendedor Ambulante: boost por video cada ~3 min" (§2; en el árbol de PLAN-v2 bajo E7b) | **E4a T5** (su carril) y **E4b T5** (`VendorCardsView`, `RewardedOfferButton` con `.visitor`) | nada nuevo: T7 lo pinea en el mapa |
| "personajes no deambulan debajo de las columnas" (E3, S5) | `PlayLayout.swift:39-50` sin margen | nada: con la plegable `PlayLayout` queda intacto (T4 salteada) |
| anclas `.sideWheel`, `.sideMattress`, `.sidePackages`, `.sideBoost` (E9) | `TutorialTarget` (`TutorialAnchor.swift:8-30`); **E5b T5** suma `.sidePackages`/`.sideMattress` en los chips y la lección `.wheel` señala Regalos | T3 suma `.sideRail` (el botón en reposo), `.sideWheel` y `.sideBoost`; T5 enseña a abrir la columna |

## Lo que E7b-b usa de otros planes (y el paso 0 que lo comprueba)

| API | La define | La usa |
|---|---|---|
| `PrizeAccess`, `prizeAccess`, `refreshPrizeAccess()`, `packageTapped() -> PackageOpenResult`, `mattressTapped()`, `openWheel()`, `wheelSheet`, `PackageGlyph`, `MattressGlyph`, `PackageChip`, `MattressChip`, `prize.package.full` | E5b T2 | T1, T3 |
| `WheelGlyph` | E5b T1 | T3 |
| `debugAddPackages(_:)`, `debugSpawnMattress()`, `debugAddWheelSpins(_:)`; `content.packages.maxWaiting`; `meta.engagement.packages.secondsUntilNext`, `.treasures.secondsUntilNext` | E5a T4–T8 | T1, T2 |
| las lecciones `.packages`, `.mattress`, `.wheel` y las anclas `.sidePackages`, `.sideMattress` | E5b T5 | T3, T5 |
| `BoardChangePlanner.planMergeAll(floorOrdinal:state:tower:tiers:floorTable:config:origin:)`, `enqueueMergeAll(onFloor:origin:)` | E2a T6, T9, T14 | T1, T2 |
| `BoardChange`, `BoardChange.Origin`, `pendingBoardChanges`, `inFlightBoardChange`, `discardBoardChange(_:)` | E1 T7, T9, T14 | T1, T2 |
| `compensateRewardedVideo()` | E1 T14 | T2 |
| `grant(_:multiplier:source:now:)` (E4a T8), `ActiveModifier.Effect.packageRateMultiplier` (E4a T2); `ModifierMath.factor(_:effect:now:)` ya existe (`ActiveModifier.swift:37-39`) | E4a T2, T8 | T1, T2 |
| `RewardedOfferButton(title:identifier:placement:onRewarded:)`, `StageChips`, `VisitorPopupView`, `VendorCardsView`, `EventPopupView` | E4b T3, T4, T5 | T3, T6, T7 |
| `RewardCopy.title(_:)` | E5b T1 | T3 |
| `MetalPlate`, `ElevatorPanel` (`displayHeight`, `ledScreen`, `ledLit`), los botones de 30 pt de S6 | E3a T8 | T3 |
| `GameState.tutorialTip` (observado, `.lesson`), `tutorialTipCompleted(_:)`, `isLessonDone(_:)` | hoy (`GameState.swift:349`, `GameState+TutorialTips.swift:95-97, 181-203`) | T5 |
| `VectorTabGiftsIcon` (el glifo de "Premios" mientras no haya arte) | hoy (`UI/Art/GameIcons.swift:215`) | T3 |
| `CareersConfig.Career.lumpMinutes`, `grantCareerReward` | E2a T12; E1 T12 | T6 |
| `TowerNotice.Kind.rewardGranted(text:)`; "todo anuncio pasa por `AdsCoordinator`" | **E7b-a T3** | T2 (no lo usa: la cadena del tablero es el aviso), T7 |

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `FisuEvolution/Game/State/SideRail.swift` | **nuevo** — `SideRailKind`, `SideRailStatus`, `SideRailItem`, `SideRailState`, `RailVideoStatus`, `SideRailInput`, `SideRailModel`, `SideRailClock`, `SideRailAX` | 1 |
| `FisuEvolution/Game/State/GameState+SideRail.swift` | **nuevo** — la proyección, los relojes, los dos videos, los toques, la lección de abrirla | 1, 2, 3, 5 |
| `FisuEvolution/Game/State/GameState.swift` 🔥 | `sideRail` y una línea en `refreshProjections` | 1 |
| `FisuEvolution/Managers/Ads/AdsProvider.swift`, `Resources/Config/rewarded_ads.json` | `RewardedAdsConfig.SideRail` | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift`, `FisuEvolution/Game/State/GameState+BoardChanges.swift` | `Origin.rewardedMergeAll` y su regla al descartarse | 1 |
| `FisuEvolution/UI/SideRail/SideRailView.swift`, `SideRailOfferCard.swift`, `SideRailGlyphs.swift` | **nuevos** — la columna plegable (botón en reposo + persiana), la tarjeta de los videos, los glifos | 3, 5 |
| `FisuEvolution/UI/HUD/ElevatorPanel.swift` (E3a T8) | `ledScreen` y `ledLit` dejan de ser `private` (los comparten las dos hermanas) | 3 |
| `FisuEvolution/App/RootView.swift` 🔥 | la columna colgada de la franja de abajo; el toque afuera cierra la tarjeta | 3 |
| `FisuEvolution/UI/Visitors/StageChips.swift`, `FisuEvolution/UI/Prizes/PrizeChips.swift` | sin los chips de premios | 3 |
| `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` | `.sideRail`, `.sideWheel`, `.sideBoost` | 3 |
| `FisuEvolution/Game/State/GameState+TutorialTips.swift` | `.sideRail` (abrir la columna) y `.mergeAllVideo`; `.wheel` señala la columna; las lecciones de los cuatro esperan a la de abrirla | 5 |
| `FisuEvolution/Game/State/GameState+AdPlacements.swift` | **nuevo** — diario ×2 y carrera ×2 | 6 |
| `FisuEvolution/UI/Popups/DailyRewardView.swift`, `CareerChoiceView.swift` | los dos botones de video | 6 |
| `FisuEvolution/UI/Art/RewardedOfferButton.swift` | precarga, sondeo, unidad obligatoria | 7 |
| `VisitorPopupView.swift`, `VendorCardsView.swift`, `EventPopupView.swift` (E4b) | `placement: .visitor` explícito | 7 |
| tests | `SideRailModelTests`, `SideRailProjectionTests`, `SideRailVideosTests`, `AdPlacementRewardsTests`, `AdPlacementMapTests` (unit); `SideRailUITests` (UI); retocados `TutorialTipsTests`, `PrizesUITests`, `EconomyLoopUITests` | 1–7 |

`PlayLayout.swift`, `BoardScene.swift`, `PlayLayoutTests`, `CrowdDepthTests` y el espejo de
`AscentRenderingUITests` **no se tocan** (la T4 de la reserva quedó salteada).

## Orden, olas y paralelismo

Calientes y tibios como en E7b-a. Tibios propios: `GameState+BoardChanges.swift` (E1 T9/T14,
E2a T14, E5a T6, E6a T6), `BoardChange.swift` de EconomyKit (E1 T7, E2a T6/T9, E5a, E6a),
`StageChips.swift` (E4b T3/T5, E5b T2), `PrizeChips.swift` (E5b T2/T5), `TutorialAnchor.swift` y
`GameState+TutorialTips.swift` (E4b, E5b T5, E6a T8/T12), `ElevatorPanel.swift` (E3a T8, T10), los
archivos de visitantes de E4b. **`BoardScene.swift` no aparece**: la columna plegable no toca la
escena.

| T | Archivos | 🔥 calientes | Tibios | Depende de |
|---|---|---|---|---|
| 1 | `SideRail.swift`, `GameState+SideRail.swift`, `GameState.swift`, `AdsProvider.swift`, `rewarded_ads.json`, `BoardChange.swift` (EK), `+BoardChanges`, `SideRailModelTests`, `SideRailProjectionTests` | `GameState.swift` | `BoardChange.swift`, `+BoardChanges` | **E5b T2**, **E2a T14**, **E1 T14**, **E5a T4–T8**, **E6a T6** (último en `+BoardChanges`) |
| 2 | `GameState+SideRail.swift`, `SideRailVideosTests` | — | — | T1; **E4a T2/T8** |
| 3 | `SideRailView.swift`, `SideRailOfferCard.swift`, `SideRailGlyphs.swift`, `ElevatorPanel.swift`, `RootView.swift`, `StageChips.swift`, `PrizeChips.swift`, `TutorialAnchor.swift`, `GameState+SideRail.swift`, `PrizesUITests`, `EconomyLoopUITests`, `SideRailUITests`, catálogo | `RootView.swift`, catálogo | `StageChips`, `PrizeChips`, `TutorialAnchor`, `ElevatorPanel` | T2; **E3a T8, T10, T11**; **E5b T2, T5**; **E4b T3**; **E6a T12** (último en `RootView`); **E7b-a T3** |
| 4 | — **salteada** (el dueño eligió C) | — | — | — |
| 5 | `GameState+TutorialTips.swift`, `GameState+SideRail.swift`, `SideRailView.swift`, `TutorialTipsTests`, `SideRailUITests`, catálogo (snapshot) | catálogo | `+TutorialTips` | T3 |
| 6 | `GameState+AdPlacements.swift`, `DailyRewardView.swift`, `CareerChoiceView.swift`, `AdPlacementRewardsTests`, catálogo (snapshot) | catálogo | — | **E2a T11, T12**; **E1 T12**; **E4a T8**; **E4b T3** (`RewardedOfferButton`) |
| 7 | `RewardedOfferButton.swift`, `VisitorPopupView.swift`, `VendorCardsView.swift`, `EventPopupView.swift`, `AdPlacementMapTests`, catálogo (snapshot) | catálogo | archivos de E4b | T3, T6; **E4b T3–T5**; **E5b T1, T2** |
| 8 | cierre (controlador) | — | `Docs/` | todas |

```
Ola 1 (caliente: GameState.swift)   T1 la columna, pura
Ola 2                               T2 los videos ║ T6 diario y carrera (snapshot)
Ola 3 (caliente: RootView)          T3 la columna plegable en pantalla (dueña del catálogo)
Ola 4                               T5 las lecciones (snapshot) ║ T7 el botón y el mapa (snapshot)
Ola 5                               T8 cierre
```

T5 y T7 corren a la vez: T5 toca `SideRailView` y las lecciones, T7 el botón de video y los
popups de E4b; el único archivo que comparten de lectura es `SideRailOfferCard` (T7 lo lee en el
contrato, no lo edita). La T4 no se despacha.

## Helpers de test que EXISTEN

Los de E7b-a, más:

| Necesidad | Qué usar | Dónde |
|---|---|---|
| un piso con pares | `player?.run.units = ["homeless": 4]` + `reconcileTower()` (con 4 da 3 fusiones en cadena) | `GameState.swift:783`; el test de E2a T14 |
| la cola del tablero | `pendingBoardChanges`, `inFlightBoardChange` | E1 T9 |
| paquetes, colchón y giros puestos | `debugAddPackages(_:)`, `debugSpawnMattress()`, `debugAddWheelSpins(_:)`; fixtures `--uitest-packages=N`, `--uitest-mattress`, `--uitest-wheel-spins=N` | E5a T6–T8 |
| una carrera para elegir | `debugPresentCareerChoice()`; fixture `--uitest-career` | `GameState+Debug.swift:249`; `GameState.swift:722` |
| el popup del diario | fixture `--uitest-daily-popup` | `GameState.swift:765` |
| el director de lecciones aislado | el `makeGameState()` privado de `TutorialTipsTests`, `markLessonDone(_:)` | `TutorialTipsTests.swift:17-31` |
| leer una fuente desde un test | `#filePath` + `URL(fileURLWithPath:)` | `LocalizationCompletenessTests.swift` |
| marcadores | `board.units`, `board.layout` (E3a T10), `hud.coins` (`HUDView.swift:180`), `hud.quickhire` (`QuickHireButton.swift:176`) | — |

---

### Task 1: La columna, pura — qué dice cada botón, y el origen de Fusionar todo por video

**Objetivo:** el estado de la columna como dato puro y testeable (`SideRailModel`), publicado en
`GameState.sideRail` con los relojes en segundos enteros; la config de sus dos videos en
`rewarded_ads.json`; y el origen `.rewardedMergeAll` en el embudo de E1, con su regla al
descartarse. Todavía nada en pantalla.

**Files:**
- Create: `FisuEvolution/Game/State/SideRail.swift` (+ `xcodegen generate`)
- Create: `FisuEvolution/Game/State/GameState+SideRail.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` 🔥
- Modify: `FisuEvolution/Managers/Ads/AdsProvider.swift`, `FisuEvolution/Resources/Config/rewarded_ads.json`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift`, `FisuEvolution/Game/State/GameState+BoardChanges.swift`
- Create: `FisuEvolutionTests/SideRailModelTests.swift`, `FisuEvolutionTests/SideRailProjectionTests.swift`

**Interfaces:**
- Consumes: E5b T2 (`prizeAccess`, `packagesBlocked`); E5a (`meta.engagement.packages`,
  `.treasures`, `content.packages.maxWaiting`); E2a (`BoardChangePlanner.planMergeAll`); E4a T2
  (`ModifierMath.factor`, `.packageRateMultiplier`).
- Produces: `enum SideRailKind: String, CaseIterable` (`wheel`, `mattress`, `packages`, `boost`);
  `enum SideRailStatus: Equatable` (`ready(count: Int?)`, `blocked`, `waiting(seconds: Int)`,
  `idle`); `struct SideRailItem`; `struct SideRailState` (`items`, `mergeAllPairs`,
  `packageRain`, `isVisible`, `readyCount`, `status(of:)`, `.hidden`); `enum RailVideoStatus` (`available`,
  `coolingDown(seconds:)`, `notApplicable`); `struct SideRailInput`; `enum SideRailModel`
  (`state(_:)`); `enum SideRailClock` (`text(_:)`); `enum SideRailAX` (`value(_:)`);
  `GameState.sideRail` (observado), `refreshSideRail(now:)`, `mergeAllPairsOnVisibleFloor()`,
  `mergeAllVideoStatus(pairs:now:)`, `packageRainStatus(now:)`, `static mergeAllVideoKey`,
  `static packageRainVideoKey`, `static secondsUntilNextWheelDay(now:calendar:)`;
  `RewardedAdsConfig.SideRail` (`mergeAllCooldownSeconds`, `packageRainCooldownSeconds`,
  `packageRain: RewardSpec`, `.default`), `sideRail`, `effectiveSideRail`;
  `BoardChange.Origin.rewardedMergeAll`.

- [ ] **Step 0: Lo de E5, E2a, E1 y E4a está**

Run (uno por llamada):

```bash
grep -n "struct PrizeAccess" FisuEvolution/Game/State/PrizeAccess.swift
grep -n "func refreshPrizeAccess\|func packageTapped\|func mattressTapped\|func openWheel" FisuEvolution/Game/State/GameState+Prizes.swift
grep -n "static func planMergeAll" Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift
grep -n "func enqueueMergeAll\|func discardBoardChange" FisuEvolution/Game/State/GameState+BoardChanges.swift
grep -n "maxWaiting" Packages/EconomyKit/Sources/EconomyKit/Prizes/PackagesConfig.swift
grep -n "case packageRateMultiplier" Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift
grep -n "refreshPrizeAccess()" FisuEvolution/Game/State/GameState.swift
```

Expected: una o más líneas cada uno. La firma de `planMergeAll` manda: si no tiene `config:`, se
llama como esté. Si falta algo, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/SideRailModelTests.swift`:

```swift
import Testing
@testable import FisuEvolution

/// La columna lateral, pura (PLAN-v2 §2): cada botón dice "!" con algo listo,
/// el reloj cuando falta, y nada que confunda cuando no hay nada.
@Suite("La columna lateral, pura")
struct SideRailModelTests {
    private func input(_ change: (inout SideRailInput) -> Void = { _ in }) -> SideRailInput {
        var input = SideRailInput(
            shown: true,
            access: .none,
            packageSecondsUntilNext: 90,
            mattressSecondsUntilNext: 300,
            wheelSecondsUntilReset: 7200,
            mergeAllPairs: 0,
            mergeAll: .notApplicable,
            packageRain: .notApplicable
        )
        change(&input)
        return input
    }

    @Test("oculta no hay columna; a la vista, los cuatro en su orden")
    func visibility() {
        #expect(SideRailModel.state(input { $0.shown = false }) == .hidden)
        #expect(SideRailModel.state(input()).items.map(\.kind) == [.wheel, .mattress, .packages, .boost])
    }

    @Test("la ruleta: cuántos giros quedan, o el reloj hasta mañana")
    func wheel() {
        #expect(SideRailModel.state(input { $0.access.wheelSpinsReady = 3 }).status(of: .wheel) == .ready(count: 3))
        #expect(SideRailModel.state(input()).status(of: .wheel) == .waiting(seconds: 7200))
    }

    @Test("el colchón: «!» si espera, el reloj si no, nada si no hay reloj")
    func mattress() {
        #expect(SideRailModel.state(input { $0.access.mattressReady = true }).status(of: .mattress) == .ready(count: nil))
        #expect(SideRailModel.state(input()).status(of: .mattress) == .waiting(seconds: 300))
        #expect(SideRailModel.state(input { $0.mattressSecondsUntilNext = nil }).status(of: .mattress) == .idle)
    }

    @Test("los paquetes: cuántos, LLENO si no entra ninguno, o el reloj del próximo")
    func packages() {
        #expect(SideRailModel.state(input { $0.access.packagesWaiting = 2 }).status(of: .packages) == .ready(count: 2))
        #expect(SideRailModel.state(input {
            $0.access.packagesWaiting = 1
            $0.access.packagesBlocked = true
        }).status(of: .packages) == .blocked)
        #expect(SideRailModel.state(input()).status(of: .packages) == .waiting(seconds: 90))
    }

    @Test("Fusionar todo: listo con pares, el reloj si se está enfriando, apagado sin pares")
    func boost() {
        #expect(SideRailModel.state(input { $0.mergeAll = .available }).status(of: .boost) == .ready(count: nil))
        #expect(SideRailModel.state(input { $0.mergeAll = .coolingDown(seconds: 61.2) }).status(of: .boost) == .waiting(seconds: 62))
        #expect(SideRailModel.state(input()).status(of: .boost) == .idle)
    }

    @Test("el «!» del botón en reposo suma los accesos listos; LLENO no cuenta")
    func readyCount() {
        #expect(SideRailModel.state(input()).readyCount == 0, "todo con reloj o apagado: sin «!»")
        let busy = SideRailModel.state(input {
            $0.access.wheelSpinsReady = 2
            $0.access.mattressReady = true
            $0.access.packagesWaiting = 1
            $0.access.packagesBlocked = true
            $0.mergeAll = .available
        })
        #expect(busy.readyCount == 3)
        #expect(SideRailModel.state(input { $0.shown = false }).readyCount == 0)
    }

    @Test("el reloj: segundos, minutos y horas")
    func clock() {
        #expect(SideRailClock.text(42) == "42s")
        #expect(SideRailClock.text(245) == "4:05")
        #expect(SideRailClock.text(3 * 3600 + 10).contains("3"))
    }

    @Test("lo que leen VoiceOver y los tests")
    func accessibilityValue() {
        #expect(SideRailAX.value(.ready(count: 2)) == "ready:2")
        #expect(SideRailAX.value(.ready(count: nil)) == "ready")
        #expect(SideRailAX.value(.blocked) == "full")
        #expect(SideRailAX.value(.waiting(seconds: 9)) == "waiting:9")
        #expect(SideRailAX.value(.idle) == "idle")
    }
}
```

`FisuEvolutionTests/SideRailProjectionTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La columna en la partida", .serialized)
@MainActor
struct SideRailProjectionTests {
    @Test("con el núcleo del tutorial no hay columna; sin él, los cuatro")
    func visibility() async {
        let gameState = await makeGameState()
        gameState.refreshProjections()
        #expect(gameState.sideRail.items.map(\.kind) == SideRailKind.allCases)
        gameState.beginTutorialPhase()
        gameState.refreshProjections()
        #expect(gameState.sideRail == .hidden)
    }

    @Test("lee los accesos de E5: paquetes, colchón y giros")
    func readsThePrizeAccess() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(2)
        gameState.debugSpawnMattress()
        gameState.refreshProjections()
        #expect(gameState.sideRail.status(of: .packages) == .ready(count: 2))
        #expect(gameState.sideRail.status(of: .mattress) == .ready(count: nil))
        #expect(gameState.sideRail.status(of: .wheel) == .ready(count: gameState.prizeAccess.wheelSpinsReady))
    }

    @Test("Fusionar todo: con pares en el piso se ofrece y dice cuántos; con uno solo, no")
    func mergeAllNeedsPairs() async {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 1]
        gameState.reconcileTower()
        gameState.refreshProjections()
        #expect(gameState.sideRail.status(of: .boost) == .idle)
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        gameState.refreshProjections()
        #expect(gameState.sideRail.status(of: .boost) == .ready(count: nil))
        #expect(gameState.sideRail.mergeAllPairs == 3)
    }

    @Test("el reloj de la ruleta va hasta la medianoche local")
    func wheelClock() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Argentina/Buenos_Aires"))
        let lateNight = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 23, minute: 59)))
        #expect(GameState.secondsUntilNextWheelDay(now: lateNight, calendar: calendar) == 60)
    }

    @Test("el JSON trae la sección de la columna y la lluvia se puede entregar")
    func configIsThere() throws {
        let content = try GameContentLoader.load(from: .main)
        let rail = try #require(content.rewardedAds.sideRail)
        #expect(rail.mergeAllCooldownSeconds > 0)
        #expect(rail.packageRainCooldownSeconds > 0)
        try rail.packageRain.validate()
        #expect(GameState.grantableRewardKinds.contains(rail.packageRain.kind))
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/SideRailModelTests -only-testing:FisuEvolutionTests/SideRailProjectionTests`.
Expected: no compila (`SideRailModel`, `sideRail` no existen).

- [ ] **Step 3: El modelo**

`FisuEvolution/Game/State/SideRail.swift`:

```swift
import EconomyKit
import Foundation

/// Los cuatro accesos de la columna lateral (PLAN-v2 §2, "Accesos en
/// pantalla"), en el orden en que se leen en la persiana: de arriba abajo y de
/// izquierda a derecha.
enum SideRailKind: String, CaseIterable, Sendable {
    case wheel
    case mattress
    case packages
    case boost
}

/// Lo que dice un botón de la columna.
enum SideRailStatus: Equatable, Sendable {
    /// Hay algo para tocar: el "!" (o el número) y el latido.
    case ready(count: Int?)
    /// Hay algo, pero no entra (paquetes con todo lleno): "LLENO".
    case blocked
    /// Falta: el reloj, en segundos enteros.
    case waiting(seconds: Int)
    /// Nada que ofrecer ni reloj que mostrar.
    case idle
}

struct SideRailItem: Identifiable, Equatable, Sendable {
    let kind: SideRailKind
    let status: SideRailStatus
    var id: SideRailKind { kind }
}

/// Un video de la columna: Fusionar todo o la lluvia de paquetes.
enum RailVideoStatus: Equatable, Sendable {
    case available
    case coolingDown(seconds: Double)
    /// Ahora no haría nada (sin pares, el buzón lleno, un piquete): no se ofrece.
    case notApplicable
}

/// Lo que la columna muestra. Publicado por `GameState.refreshSideRail`.
struct SideRailState: Equatable, Sendable {
    var items: [SideRailItem] = []
    /// Cuántas fusiones haría "Fusionar todo" ahora en el piso a la vista.
    var mergeAllPairs = 0
    /// La lluvia de paquetes, que ofrece el botón de Paquetes cuando no hay ninguno.
    var packageRain = RailVideoStatus.notApplicable

    var isVisible: Bool { !items.isEmpty }

    /// Cuántos accesos tienen algo listo: el número del "!" del botón en reposo
    /// (la suma de los avisos de los cuatro). "LLENO" no cuenta: no hay nada
    /// que tocar.
    var readyCount: Int {
        items.filter { if case .ready = $0.status { true } else { false } }.count
    }

    static let hidden = SideRailState()

    func status(of kind: SideRailKind) -> SideRailStatus? {
        items.first { $0.kind == kind }?.status
    }
}

/// Todo lo que la columna necesita saber, ya resuelto por `GameState`.
struct SideRailInput: Equatable, Sendable {
    /// Fuera del núcleo del tutorial y con la partida cargada.
    var shown: Bool
    var access: PrizeAccess
    var packageSecondsUntilNext: Double?
    var mattressSecondsUntilNext: Double?
    var wheelSecondsUntilReset: Double
    var mergeAllPairs: Int
    var mergeAll: RailVideoStatus
    var packageRain: RailVideoStatus
}

/// La columna como función pura de su entrada.
enum SideRailModel {
    static func state(_ input: SideRailInput) -> SideRailState {
        guard input.shown else { return .hidden }
        return SideRailState(
            items: SideRailKind.allCases.map { SideRailItem(kind: $0, status: status($0, input)) },
            mergeAllPairs: input.mergeAllPairs,
            packageRain: input.packageRain
        )
    }

    private static func status(_ kind: SideRailKind, _ input: SideRailInput) -> SideRailStatus {
        switch kind {
        case .wheel:
            if input.access.wheelSpinsReady > 0 { return .ready(count: input.access.wheelSpinsReady) }
            return .waiting(seconds: whole(input.wheelSecondsUntilReset))
        case .mattress:
            if input.access.mattressReady { return .ready(count: nil) }
            return input.mattressSecondsUntilNext.map { .waiting(seconds: whole($0)) } ?? .idle
        case .packages:
            if input.access.packagesBlocked { return .blocked }
            if input.access.packagesWaiting > 0 { return .ready(count: input.access.packagesWaiting) }
            return input.packageSecondsUntilNext.map { .waiting(seconds: whole($0)) } ?? .idle
        case .boost:
            switch input.mergeAll {
            case .available: return .ready(count: nil)
            case .coolingDown(let seconds): return .waiting(seconds: whole(seconds))
            case .notApplicable: return .idle
            }
        }
    }

    /// Hacia arriba: un reloj que dice 0 con algo todavía faltando miente.
    private static func whole(_ seconds: Double) -> Int {
        max(0, Int(seconds.rounded(.up)))
    }
}

/// El reloj de un botón: "42s", "4:05", y arriba de la hora "3 h" (la ruleta
/// espera a la medianoche y los minutos ahí no dicen nada).
enum SideRailClock {
    static func text(_ seconds: Int) -> String {
        guard seconds >= 3600 else { return ActiveBonusBar.timeText(TimeInterval(seconds)) }
        return String(localized: "siderail.hours \(String(seconds / 3600))")
    }
}

/// El valor de accesibilidad de un botón: lo leen VoiceOver y los tests de UI
/// (mismo criterio que el atajo: `ready:<n>`).
enum SideRailAX {
    static func value(_ status: SideRailStatus) -> String {
        switch status {
        case .ready(let count): count.map { "ready:\($0)" } ?? "ready"
        case .blocked: "full"
        case .waiting(let seconds): "waiting:\(seconds)"
        case .idle: "idle"
        }
    }
}
```

(La clave `siderail.hours %@` la suma el snapshot de T3; mientras tanto el test del reloj sólo
pide que el número aparezca.)

- [ ] **Step 4: La config, el origen y la proyección**

`AdsProvider.swift`, en `RewardedAdsConfig`:

```swift
    /// Los dos videos de la columna lateral (E7b): cada cuánto se puede volver a
    /// mirar cada uno y qué da la lluvia de paquetes. Opcional, con default.
    struct SideRail: Codable, Sendable, Equatable {
        let mergeAllCooldownSeconds: Double
        let packageRainCooldownSeconds: Double
        let packageRain: RewardSpec

        static let `default` = SideRail(
            mergeAllCooldownSeconds: 600,
            packageRainCooldownSeconds: 1800,
            packageRain: .modifier(effect: .packageRateMultiplier, magnitude: 10, seconds: 60)
        )
    }

    let sideRail: SideRail?

    var effectiveSideRail: SideRail { sideRail ?? .default }
```

`rewarded_ads.json`, en la raíz:

```json
  "sideRail": {
    "mergeAllCooldownSeconds": 600,
    "packageRainCooldownSeconds": 1800,
    "packageRain": {"kind": "modifier", "effect": "packageRateMultiplier", "magnitude": 10, "seconds": 60}
  }
```

`BoardChange.swift` (EconomyKit), en `Origin`:

```swift
        /// "Fusionar todo" por video, desde la columna lateral (E7b).
        case rewardedMergeAll
```

`GameState+BoardChanges.swift`, en `discardBoardChange(_:)`: `.rewardedMergeAll` va al grupo que
**no** compensa, el mismo que `.oroShop` de E6a T6 (un par que el jugador fusionó a mano antes de
su turno no es un premio perdido; el video ya pagó con los pares que sí se jugaron).

`GameState.swift` 🔥:

1. En las proyecciones observadas, después de `prizeAccess` (E5b T2):

```swift
    /// La columna lateral (`+SideRail`): cambia a lo sumo una vez por segundo.
    var sideRail = SideRailState.hidden
```

2. En `refreshProjections()`, justo después de `refreshPrizeAccess()`:

```swift
        refreshSideRail()
```

`FisuEvolution/Game/State/GameState+SideRail.swift`:

```swift
import EconomyKit
import Foundation

/// La columna lateral en la partida (PLAN-v2 §2, "Accesos en pantalla"): qué
/// dice cada botón —publicado en `sideRail`— y, en las tareas siguientes, sus
/// dos videos, sus toques y lo que le deja el tablero.
extension GameState {
    /// Las claves de `meta.rewardedActivations` de los dos videos de la columna.
    static let mergeAllVideoKey = "siderail.mergeAll"
    static let packageRainVideoKey = "siderail.packageRain"

    func refreshSideRail(now: TimeInterval = Date().timeIntervalSince1970) {
        let pairs = mergeAllPairsOnVisibleFloor()
        let input = SideRailInput(
            shown: phase == .ready && !tutorialPhaseActive,
            access: prizeAccess,
            packageSecondsUntilNext: player?.meta.engagement.packages.secondsUntilNext,
            mattressSecondsUntilNext: player?.meta.engagement.treasures.secondsUntilNext,
            wheelSecondsUntilReset: Self.secondsUntilNextWheelDay(now: Date(timeIntervalSince1970: now)),
            mergeAllPairs: pairs,
            mergeAll: mergeAllVideoStatus(pairs: pairs, now: now),
            packageRain: packageRainStatus(now: now)
        )
        let state = SideRailModel.state(input)
        if sideRail != state { sideRail = state }
    }

    /// Cuántas fusiones encolaría "Fusionar todo" ahora: el mismo plan que se
    /// ejecuta (lo que se muestra es lo que se aplica).
    func mergeAllPairsOnVisibleFloor() -> Int {
        guard let content, let player, let tower else { return 0 }
        return BoardChangePlanner.planMergeAll(
            floorOrdinal: visibleFloorOrdinal, state: player, tower: tower, tiers: content.tiers,
            floorTable: content.floorTable, config: content.economy, origin: .rewardedMergeAll
        ).count
    }

    func mergeAllVideoStatus(pairs: Int, now: TimeInterval) -> RailVideoStatus {
        guard let content else { return .notApplicable }
        let remaining = cooldownRemaining(
            key: Self.mergeAllVideoKey, seconds: content.rewardedAds.effectiveSideRail.mergeAllCooldownSeconds, now: now
        )
        if remaining > 0 { return .coolingDown(seconds: remaining) }
        return pairs > 0 ? .available : .notApplicable
    }

    /// La lluvia se ofrece si puede hacer algo: hay lugar en el buzón, el
    /// paquete entra y ningún evento cortó los paquetes (el piquete).
    func packageRainStatus(now: TimeInterval) -> RailVideoStatus {
        guard let content, let player else { return .notApplicable }
        let remaining = cooldownRemaining(
            key: Self.packageRainVideoKey, seconds: content.rewardedAds.effectiveSideRail.packageRainCooldownSeconds, now: now
        )
        if remaining > 0 { return .coolingDown(seconds: remaining) }
        let rate = ModifierMath.factor(player.run.activeModifiers, effect: .packageRateMultiplier, now: now)
        let room = player.meta.engagement.packages.waiting < content.packages.maxWaiting
        return rate > 0 && room && !packagesBlocked ? .available : .notApplicable
    }

    /// Hasta la medianoche local: el día de los cupos de la ruleta es el del
    /// diario (`wheelDay`, E5a).
    static func secondsUntilNextWheelDay(now: Date, calendar: Calendar = .current) -> TimeInterval {
        let start = calendar.startOfDay(for: now)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86_400)
        return max(0, next.timeIntervalSince(now))
    }

    private func cooldownRemaining(key: String, seconds: Double, now: TimeInterval) -> Double {
        let last = player?.meta.rewardedActivations[key] ?? -.infinity
        return max(0, seconds - (now - last))
    }
}
```

(`refreshSideRail` corre a 8 Hz desde el flush; el plan de "Fusionar todo" mide a lo sumo 20
unidades. Si el perfil de Instruments lo marca, se cachea por `boardVersion` y piso visible;
anotarlo en el reporte con el número medido.)

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS. Receta R con `SideRailModelTests`,
`SideRailProjectionTests`, `PrizeAccessTests`, `GameContentValidationTests` → PASS.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Game/State/SideRail.swift
git add FisuEvolution/Game/State/GameState+SideRail.swift
git add FisuEvolution/Game/State/GameState.swift
git add FisuEvolution/Managers/Ads/AdsProvider.swift
git add FisuEvolution/Resources/Config/rewarded_ads.json
git add Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift
git add FisuEvolution/Game/State/GameState+BoardChanges.swift
git add FisuEvolutionTests/SideRailModelTests.swift
git add FisuEvolutionTests/SideRailProjectionTests.swift
git diff --cached --stat
git commit -m "feat(columna): la columna lateral, pura — qué dice cada botón, y el origen de Fusionar todo por video"
```

---

### Task 2: Los videos de la columna — Fusionar todo y la lluvia de paquetes

**Objetivo:** lo que pasa cuando termina cada video de la columna. Fusionar todo encola todos los
pares del piso a la vista con `.rewardedMergeAll` (cada uno se juega en su turno del tablero y un
tier nuevo se revela como siempre) y arranca su enfriamiento; la lluvia entrega su `RewardSpec`
(×10 paquetes por 60 s) y arranca el suyo. Si al terminar el video ya no hace nada, no gasta el
enfriamiento y compensa (E1 T14).

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+SideRail.swift`
- Create: `FisuEvolutionTests/SideRailVideosTests.swift`

**Interfaces:**
- Consumes: T1; E2a T14 (`enqueueMergeAll(onFloor:origin:)`); E1 T14 (`compensateRewardedVideo()`);
  E4a T8 (`grant`).
- Produces: `GameState.mergeAllVideoWatched(now:)`, `packageRainVideoWatched(now:)`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/SideRailVideosTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los dos videos de la columna (PLAN-v2 E7: "boost sin esperar y Fusionar
/// todo (boost)", "colchón, otro colchón y lluvia de paquetes (treasure)").
@Suite("Los videos de la columna", .serialized)
@MainActor
struct SideRailVideosTests {
    @Test("Fusionar todo por video encola los pares del piso y arranca el enfriamiento")
    func mergeAllQueuesThePairs() async throws {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        let now = Date().timeIntervalSince1970
        gameState.mergeAllVideoWatched(now: now)
        let queued = gameState.pendingBoardChanges.count + (gameState.inFlightBoardChange == nil ? 0 : 1)
        #expect(queued == 3)
        let cooldown = try #require(gameState.content?.rewardedAds.effectiveSideRail.mergeAllCooldownSeconds)
        #expect(gameState.mergeAllVideoStatus(pairs: 3, now: now + 1) == .coolingDown(seconds: cooldown - 1))
    }

    @Test("sin pares el video no gasta el enfriamiento y compensa")
    func noPairsCompensates() async throws {
        let gameState = await makeGameState()
        gameState.player?.run.units = ["homeless": 1]
        gameState.reconcileTower()
        let before = try #require(gameState.player?.run.coins)
        gameState.mergeAllVideoWatched(now: Date().timeIntervalSince1970)
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.player?.meta.rewardedActivations[GameState.mergeAllVideoKey] == nil)
    }

    @Test("un par que se descarta porque el jugador lo fusionó antes no compensa")
    func aDiscardedPairIsNotCompensated() async throws {
        let gameState = await makeGameState()
        let before = try #require(gameState.player?.run.coins)
        gameState.discardBoardChange(BoardChange(
            kind: .merge(floorOrdinal: 0, typeId: "homeless", sourceSlot: 0, targetSlot: 1, newTypeId: "homeless"),
            origin: .rewardedMergeAll
        ))
        #expect(gameState.player?.run.coins == before)
    }

    @Test("la lluvia: ×10 paquetes por 60 s y su enfriamiento")
    func packageRain() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        #expect(gameState.packageRainStatus(now: now) == .available)
        gameState.packageRainVideoWatched(now: now)
        let rain = try #require(gameState.player?.run.activeModifiers.first { $0.effect == .packageRateMultiplier })
        #expect(rain.magnitude == 10)
        #expect(abs(rain.expiresAt - (now + 60)) < 0.001)
        guard case .coolingDown = gameState.packageRainStatus(now: now + 1) else {
            Issue.record("la lluvia no arrancó su enfriamiento")
            return
        }
    }

    @Test("con el buzón lleno la lluvia no se ofrece, y si el video termina igual, compensa")
    func fullBoxMeansNoRain() async throws {
        let gameState = await makeGameState()
        let maxWaiting = try #require(gameState.content?.packages.maxWaiting)
        gameState.debugAddPackages(maxWaiting)
        let now = Date().timeIntervalSince1970
        #expect(gameState.packageRainStatus(now: now) == .notApplicable)
        let before = try #require(gameState.player?.run.coins)
        gameState.packageRainVideoWatched(now: now)
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.player?.run.activeModifiers.contains { $0.effect == .packageRateMultiplier } == false)
    }
}
```

(`BoardChange.Kind.merge` y el `init(id:kind:origin:)` son los de `BoardChange.swift:7, 26-30`,
ya en el árbol; el test sólo mira que descartarlo no pague.)

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/SideRailVideosTests`.
Expected: no compila (`mergeAllVideoWatched`, `packageRainVideoWatched`).

- [ ] **Step 3: Los dos videos**

`GameState+SideRail.swift`, en la extensión:

```swift
    // MARK: - Los videos

    /// Terminó el video de "Fusionar todo": se encolan todos los pares del piso
    /// a la vista (E2a) y cada uno se juega en su turno del tablero. Si para
    /// entonces no queda ninguno, el video no gasta su enfriamiento y compensa
    /// (E1 T14: un video nunca es en vano).
    func mergeAllVideoWatched(now: TimeInterval = Date().timeIntervalSince1970) {
        countRailVideo()
        let queued = enqueueMergeAll(onFloor: visibleFloorOrdinal, origin: .rewardedMergeAll)
        guard queued > 0 else {
            compensateRewardedVideo()
            return
        }
        player?.meta.rewardedActivations[Self.mergeAllVideoKey] = now
        Log.ads.info("fusionar todo por video: \(queued) pares")
        refreshSideRail(now: now)
        scheduleSave()
    }

    /// Terminó el video de la lluvia: ×10 paquetes por un minuto (el dato de
    /// `rewarded_ads.json`). Si ya no podía hacer nada, compensa sin gastar.
    func packageRainVideoWatched(now: TimeInterval = Date().timeIntervalSince1970) {
        countRailVideo()
        guard let content, packageRainStatus(now: now) == .available else {
            compensateRewardedVideo()
            return
        }
        player?.meta.rewardedActivations[Self.packageRainVideoKey] = now
        grant(content.rewardedAds.effectiveSideRail.packageRain, source: "siderail.packageRain", now: now)
        refreshSideRail(now: now)
        scheduleSave()
    }

    /// El contador de videos va donde va el video, con o sin efecto (el mismo
    /// criterio que `applyRewardedReward`).
    private func countRailVideo() {
        player?.meta.stats.videosWatchedEver += 1
    }
```

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con `SideRailVideosTests`, `SideRailProjectionTests`, `DebugEconomyKnobsTests`
(E2a T14), `BoardChangeWiringTests`/la suite de E1 T9 → PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+SideRail.swift
git add FisuEvolutionTests/SideRailVideosTests.swift
git diff --cached --stat
git commit -m "feat(columna): los videos de la columna — Fusionar todo por el embudo y la lluvia de paquetes"
```

---

### Task 3: La columna plegable en pantalla — "Premios" en reposo, la persiana de los cuatro y la tarjeta de los videos

**Objetivo:** la columna que eligió el dueño (opción C), hermana de la botonera del ascensor de
E3a T8. En reposo hay un solo botón "Premios" de 44 pt sobre la placa de metal, abajo a la
izquierda, con el "!" sumado: el número de accesos que tienen algo listo. Al tocarlo se despliega
hacia arriba una persiana de 2 × 2 con la Ruleta, El Colchón, los Paquetes y Fusionar todo. Cada
botón es de 30 pt, como los de la botonera después del spike S6, y tiene su "!" o su número, su
latido y su reloj en LED. La persiana se recoge sola a los 3 s sin uso, y al tocar un botón que
abre algo. Fusionar todo y la lluvia de paquetes se ofrecen en una tarjeta al lado de "Premios",
con el premio dicho antes del anuncio. Los chips de premios de `StageChips` se van, y las anclas
`.sidePackages` y `.sideMattress` se mudan a la persiana.

**Dónde cae** (medido contra el árbol y los spikes de E3a):

- **Cuelga del borde de arriba de `bottomBar`** (`RootView.swift:506-530`: la fila del atajo
  —`QuickHireButton`, `hud.quickhire`, a la izquierda; `PrestigeButton`, a la derecha— y
  `BottomMenuBar`), con 10 pt de aire, y contra el borde izquierdo de la pantalla con 12 pt: es el
  espejo del `.padding(.trailing, Tokens.s12)` con que la botonera cuelga del HUD.
- **En reposo** ocupa 44 × 44 pt en x 12–56, justo arriba de `hud.quickhire`.
  - En el SE (S4: insets 0/0, sin home indicator) la franja de abajo mide la barra más el
    `minimumBottomGap`, 8 de aire y los 56 del atajo, así que el botón queda hacia y ≈ 465–509. Con
    la barra 20 pt más baja de E3a T7 baja otro tanto. `SideRailUITests` lo mide por frames.
  - **No choca con ningún control.** Los dos toasts (`TowerNoticeView`, `AchievementToastView`)
    flotan ~260 pt por encima de la barra; las cajas del Paquete (E5b T3) se paran a ≥ 72 pt del
    borde; el escenario de visitantes va en x ∈ [28 %, 72 %]; la llave de DEBUG está arriba a la
    derecha.
  - **Lo único que tapa es la parte de abajo a la izquierda del personaje de la celda 0.** En el SE
    su arte visible arranca en x ≈ 35 (S5) y el botón termina en 56: ~20 pt. Un toque ahí lo toma
    "Premios". Es el costo que el dueño aceptó.
- **Abierta**, la persiana es una `Grid` de 2 × 2 sobre `MetalPlate`, como la de la botonera:
  2 × 36 + 6 + 16 = 94 pt de ancho y 2 × (30 + 3 + 12) + 6 + 16 = 112 de alto, 4 pt arriba de
  "Premios".
  - En el SE cae en x 12–106 e y ≈ 349–461: tapa las primeras celdas de la multitud mientras está
    abierta (≤ 3 s), igual que la persiana del ascensor tapa las filas de atrás (S6).
  - Puede tapar, por ese rato, una caja del Paquete parada en su borde (x 72–106) o un toast ancho
    (el toast queda encima: se dibuja después en el `ZStack`).
- **Las dos hermanas abiertas a la vez no se cruzan.** La botonera se despliega desde el display,
  arriba a la derecha (en el SE x 207–363, y 147–329 con los botones de 30); la columna, desde abajo
  a la izquierda. Pasa lo mismo en todo iPhone y en iPad. Cada una tiene su reloj, y abrir una no
  cierra la otra (duda 4).

**Files:**
- Create: `FisuEvolution/UI/SideRail/SideRailView.swift`, `SideRailOfferCard.swift`, `SideRailGlyphs.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/UI/HUD/ElevatorPanel.swift` (E3a T8: `ledScreen` y `ledLit` dejan de ser `private`)
- Modify: `FisuEvolution/Game/State/GameState+SideRail.swift` (`SideRailTap`, `sideRailTapped(_:)`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` (`.sideRail`, `.sideWheel`, `.sideBoost`)
- Modify: `FisuEvolution/App/RootView.swift` 🔥
- Modify: `FisuEvolution/UI/Visitors/StageChips.swift`, `FisuEvolution/UI/Prizes/PrizeChips.swift`
- Modify: `FisuEvolutionUITests/PrizesUITests.swift` (E5b T2), `FisuEvolutionUITests/EconomyLoopUITests.swift`
- Create: `FisuEvolutionUITests/SideRailUITests.swift`
- Strings: el catálogo (dueña en su ola) o `Tools/v2/claves-pendientes/e7b-b-t3.json` (13 claves)

**Interfaces:**
- Consumes: T1, T2; **E3a T8** (`MetalPlate`, `ElevatorPanel.displayHeight`, `ledScreen`,
  `ledLit`); E5b (`openWheel()`, `wheelSheet`, `mattressTapped()`, `packageTapped()`,
  `PackageOpenResult`, `WheelGlyph`, `MattressGlyph`, `PackageGlyph`, `prize.package.full`); E5b T1
  (`RewardCopy.title(_:)`); E4b T3 (`RewardedOfferButton`); `VectorTabGiftsIcon`
  (`UI/Art/GameIcons.swift:215`).
- Produces: `enum SideRailTap: Equatable` (`acted`, `offer`, `refused`);
  `GameState.sideRailTapped(_:) -> SideRailTap`; `@MainActor enum SideRailLayout` (`restSide`,
  `button`, `glyph`, `cellWidth`, `spacing`, `edgeInset`, `gapAboveBottomBar`, `collapseDelay`);
  `SideRailView(offer:)`, `SideRailButton(item:tap:)`, `SideRailBadge(text:)`,
  `SideRailOfferCard(kind:close:)`, `SideRailGlyph(kind:)`, `MergeAllGlyph`;
  `TutorialTarget.sideRail`, `.sideWheel`, `.sideBoost`; `SideRailKind.tutorialTarget`.
- Identificadores: `siderail.toggle` (el botón en reposo; valor = `readyCount`); `siderail.wheel`,
  `siderail.mattress`, `siderail.packages`, `siderail.boost` (sólo con la persiana abierta; valor =
  `SideRailAX.value`); `siderail.offer.video`, `siderail.offer.close`.
- Borra (si quedan sin llamadores): `PackageChip`, `MattressChip` y sus helpers privados de
  `PrizeChips.swift`; los glifos se quedan.

- [ ] **Step 0: La botonera de E3a, lo de E5b y E4b, y quién usa los chips**

Run (uno por llamada):

```bash
grep -n "struct ElevatorPanel\|static let displayHeight\|static let collapseDelay\|static let ledScreen\|static let ledLit" FisuEvolution/UI/HUD/ElevatorPanel.swift
grep -n "private static let side" FisuEvolution/UI/HUD/ElevatorPanel.swift
grep -n "struct MetalPlate" FisuEvolution/UI/Art/PanelFrames.swift
grep -n "struct WheelGlyph" FisuEvolution/UI/Wheel/WheelCanvas.swift
grep -n "struct PackageGlyph\|struct MattressGlyph\|struct PackageChip\|struct MattressChip" FisuEvolution/UI/Prizes/PrizeChips.swift
grep -rn "PackageChip\|MattressChip" FisuEvolution
grep -n "case sidePackages\|case sideMattress" FisuEvolution/UI/Tutorial/TutorialAnchor.swift
grep -n "private var bottomBar" FisuEvolution/App/RootView.swift
grep -n "\"prize.package.full\"" FisuEvolution/Resources/Localizable.xcstrings
```

Expected: E3a T8 dejó la botonera, con los botones de piso en **30** pt (el cambio del spike S6;
si dice 34, la persiana de la columna usa igual 30 y se anota la diferencia). El sexto lista los
usos de los chips: además de `StageChips`, si alguno aparece en otro lado (un test, la escena), se
conserva el tipo y sólo se quita de `StageChips`. Si falta la botonera, `NEEDS_CONTEXT`: la
columna es su hermana y toma de ella el material y las medidas.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionUITests/SideRailUITests.swift`:

```swift
import XCTest

/// La columna plegable (PLAN-v2 §2; opción C del dueño): en reposo un solo botón
/// "Premios" abajo a la izquierda; al tocarlo despliega los cuatro, que se
/// recogen solos a los 3 s o al tocar uno. El anuncio lo pone el stub (2 s, y
/// paga).
final class SideRailUITests: XCTestCase {
    private let buttons = ["siderail.wheel", "siderail.mattress", "siderail.packages", "siderail.boost"]

    override func setUp() {
        continueAfterFailure = false
    }

    func testEnReposoUnSoloBotonQueDespliegaLosCuatroYSeRecogeSolo() {
        let app = launch()
        let toggle = app.buttons["siderail.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        for id in buttons {
            XCTAssertFalse(app.buttons[id].exists, "\(id) a la vista con la columna plegada")
        }
        XCTAssertLessThanOrEqual(toggle.frame.maxY, app.buttons["hud.quickhire"].frame.minY, "«Premios» pisa el atajo")
        XCTAssertLessThanOrEqual(toggle.frame.maxX, 60, "«Premios» se sale de su esquina")
        attach(app, named: "E7b columna plegada")

        toggle.tap()
        let top = app.otherElements["hud.coins"].frame.maxY
        for id in buttons {
            let button = app.buttons[id]
            XCTAssertTrue(button.waitForExistence(timeout: 3), "\(id) no se desplegó")
            XCTAssertGreaterThanOrEqual(button.frame.minY, top, "\(id) pisa el HUD")
            XCTAssertLessThanOrEqual(button.frame.maxY, toggle.frame.minY, "\(id) pisa «Premios»")
            XCTAssertLessThanOrEqual(button.frame.maxX, 110, "\(id) se sale de la persiana")
        }
        attach(app, named: "E7b columna desplegada")
        XCTAssertTrue(app.buttons["siderail.wheel"].waitForNonExistence(timeout: 6), "la persiana no se recogió a los 3 s")
    }

    func testTocarUnoAbreLoSuyoYRecogeLaPersiana() {
        let app = launch(extra: ["--uitest-packages=1"])
        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let before = Int(units.value as? String ?? "") ?? 0
        let toggle = app.buttons["siderail.toggle"]
        XCTAssertGreaterThanOrEqual(Int(toggle.value as? String ?? "") ?? 0, 1, "el «!» suma el paquete")
        toggle.tap()
        let packages = app.buttons["siderail.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 3))
        XCTAssertEqual(packages.value as? String, "ready:1")
        packages.tap()
        XCTAssertTrue(packages.waitForNonExistence(timeout: 2), "tocar uno recoge la persiana")
        expectation(for: NSPredicate(format: "value == %@", String(before + 1)), evaluatedWith: units)
        waitForExpectations(timeout: 10)
    }

    func testLosPaquetesSinNadaOfrecenLaLluvia() {
        let app = launch()
        let toggle = app.buttons["siderail.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.tap()
        let packages = app.buttons["siderail.packages"]
        XCTAssertTrue(packages.waitForExistence(timeout: 3))
        packages.tap()
        let video = app.buttons["siderail.offer.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 5), "sin paquetes, Paquetes ofrece la lluvia por video")
        XCTAssertFalse(packages.exists, "la tarjeta sale al lado de «Premios», con la persiana recogida")
        app.buttons["siderail.offer.close"].tap()
        XCTAssertTrue(video.waitForNonExistence(timeout: 3))
    }

    func testFusionarTodoPorVideo() {
        let app = launch(extra: ["--uitest-coins"])
        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let start = Int(units.value as? String ?? "") ?? 0
        let quickHire = app.buttons["hud.quickhire"]
        quickHire.tap()
        quickHire.tap()
        expectation(for: NSPredicate(format: "value == %@", String(start + 2)), evaluatedWith: units)
        waitForExpectations(timeout: 10)

        app.buttons["siderail.toggle"].tap()
        let boost = app.buttons["siderail.boost"]
        XCTAssertTrue(boost.waitForExistence(timeout: 3))
        XCTAssertEqual(boost.value as? String, "ready")
        boost.tap()
        let video = app.buttons["siderail.offer.video"]
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        video.tap()

        expectation(for: NSPredicate(format: "value == %@", String(start + 1)), evaluatedWith: units)
        waitForExpectations(timeout: 20)
        app.buttons["siderail.toggle"].tap()
        XCTAssertTrue(boost.waitForExistence(timeout: 3))
        XCTAssertTrue((boost.value as? String ?? "").hasPrefix("waiting"), "el video arrancó su enfriamiento")
    }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial"] + extra
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
```

(Con `--uitest-coins` el juego arranca con un Fisura; dos contrataciones dejan tres, o sea un
par: Fusionar todo hace una fusión y `board.units` baja uno.)

`PrizesUITests.swift` (E5b T2): los chips pasan a la columna, que hay que abrir primero. Antes de
cada toque a un chip va `app.buttons["siderail.toggle"].tap()`. Además:

- `prize.chip.package` → `siderail.packages`, y su valor `"1"` → `"ready:1"`;
- `prize.chip.mattress` → `siderail.mattress`;
- las esperas finales `chip.waitForNonExistence(…)` pasan a "reabrir la columna y que el valor ya
  no sea `ready:1` / `ready`": el botón se queda en la persiana y cambia de estado.

`EconomyLoopUITests.swift:28`: el toque al tablero pasa de `dx: 0.13` a `dx: 0.22`. El Fisura de
la celda 0 está en x ≈ 88 pt, y 0,22 cae dentro de su óvalo (x ≈ 82 en el SE, 88 en el 16 Pro) y
lejos de "Premios", que termina en 56. El comentario de arriba suma "y fuera del botón de la
columna (E7b)".

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate`; UI con
`-only-testing:FisuEvolutionUITests/SideRailUITests -only-testing:FisuEvolutionUITests/PrizesUITests`.
Expected: FAIL — `siderail.toggle` no existe.

- [ ] **Step 3: El toque**

`GameState+SideRail.swift`:

```swift
    // MARK: - Los toques

    /// Qué hizo un toque a un botón de la columna.
    enum SideRailTap: Equatable {
        /// Abrió algo (la ruleta, el colchón, un paquete).
        case acted
        /// Ofrece un video: la vista muestra su tarjeta.
        case offer
        /// No hay nada que hacer: el botón tiembla.
        case refused
    }

    func sideRailTapped(_ kind: SideRailKind) -> SideRailTap {
        switch kind {
        case .wheel:
            openWheel()
            return wheelSheet != nil ? .acted : .refused
        case .mattress:
            guard prizeAccess.mattressReady else { return .refused }
            mattressTapped()
            return .acted
        case .packages:
            if prizeAccess.packagesWaiting > 0 {
                if case .opened = packageTapped() { return .acted }
                return .refused
            }
            return sideRail.packageRain == .available ? .offer : .refused
        case .boost:
            return sideRail.status(of: .boost) == .ready(count: nil) ? .offer : .refused
        }
    }
```

(`SideRailTap` anidado en `GameState` vía la extensión; si el compilador lo rechaza en una
extensión de otro archivo, va a nivel de archivo con el mismo nombre.)

- [ ] **Step 4: Los tonos compartidos, las anclas y los glifos**

`ElevatorPanel.swift` (E3a T8): `private static let ledScreen` y `private static let ledLit` pasan a
`static let` (sin `private`), con una línea en el comentario: "los comparte la columna plegable
(E7b), su hermana".

`TutorialAnchor.swift`, en `TutorialTarget`, después de `sideMattress` (E5b T5):

```swift
    /// La columna plegable (E7b): el botón en reposo y dos de los cuatro de su
    /// persiana (los otros dos los sumó E5b).
    case sideRail
    case sideWheel
    case sideBoost
```

`FisuEvolution/UI/SideRail/SideRailGlyphs.swift`:

```swift
import SwiftUI

/// El glifo de cada acceso: el arte del atlas `ui` si E8 lo entregó, si no el
/// dibujo por código que ya usan los chips y la ruleta (E5b).
struct SideRailGlyph: View {
    let kind: SideRailKind

    var body: some View {
        switch kind {
        case .wheel: GameIcon(artKey: "wheel_icon", size: SideRailLayout.glyph) { WheelGlyph() }
        case .mattress: GameIcon(artKey: "pickup_mattress", size: SideRailLayout.glyph) { MattressGlyph() }
        case .packages: GameIcon(artKey: "pickup_package", size: SideRailLayout.glyph) { PackageGlyph() }
        case .boost: GameIcon(artKey: "siderail_boost", size: SideRailLayout.glyph) { MergeAllGlyph() }
        }
    }
}

/// "Fusionar todo" dibujado, mientras no llegue `siderail_boost` (E8).
struct MergeAllGlyph: View {
    var body: some View {
        Image(systemName: "arrow.triangle.merge")
            .resizable()
            .scaledToFit()
            .fontWeight(.black)
            .foregroundStyle(Color("PaletteInk"))
            .padding(3)
            .background(Circle().fill(Color("PaletteYellow")))
            .accessibilityHidden(true)
    }
}

extension SideRailKind {
    /// El ancla del tutorial de cada botón de la persiana (los nombres los
    /// eligió E9).
    var tutorialTarget: TutorialTarget {
        switch self {
        case .wheel: .sideWheel
        case .mattress: .sideMattress
        case .packages: .sidePackages
        case .boost: .sideBoost
        }
    }
}
```

(Si `WheelGlyph` toma parámetros, se le pasan los que pida para el tamaño de 20 pt.)

- [ ] **Step 5: La columna plegable**

`FisuEvolution/UI/SideRail/SideRailView.swift`:

```swift
import SwiftUI

/// La geometría de la columna plegable: la de la botonera del ascensor (E3a T8),
/// espejada contra el borde izquierdo.
@MainActor
enum SideRailLayout {
    /// "Premios" mide lo que el display del ascensor: las dos piezas de
    /// maquinaria del HUD tienen el mismo alto.
    static let restSide: CGFloat = ElevatorPanel.displayHeight
    /// Los botones de la persiana: los de la botonera después del spike S6.
    static let button: CGFloat = 30
    static let glyph: CGFloat = 20
    /// Una celda: el botón y, debajo, su reloj en LED ("12:05").
    static let cellWidth: CGFloat = 36
    static let spacing: CGFloat = 6
    /// Contra el borde, como la botonera contra el suyo.
    static let edgeInset: CGFloat = Tokens.s12
    static let gapAboveBottomBar: CGFloat = 10
    /// 3 s y no los 2 de la botonera: lo pidió el dueño para ésta.
    static let collapseDelay: Duration = .seconds(3)
}

/// La columna lateral plegable (PLAN-v2 §2; opción C del dueño), hermana de la
/// botonera del ascensor. En reposo, un solo botón "Premios" con el "!" sumado;
/// al tocarlo se despliega la persiana con la Ruleta, El Colchón, los Paquetes
/// y Fusionar todo, que se recoge sola a los 3 s sin uso o al tocar uno. Lee
/// `sideRail` y toca por `sideRailTapped(_:)`: no decide nada.
///
/// ⚠️ Fuera de sus controles no toca nada: un gesto que arranca al lado sigue
/// siendo del tablero, como con la botonera (spike S6).
struct SideRailView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// La tarjeta del video abierta. Vive en `RootView`: el toque afuera la cierra.
    @Binding var offer: SideRailKind?
    @State private var expanded = false
    /// Cada toque reinicia la cuenta de los 3 s (el mecanismo de la botonera).
    @State private var activity = 0

    var body: some View {
        Group {
            if gameState.sideRail.isVisible {
                column(gameState.sideRail)
            }
        }
        .onChange(of: gameState.sideRail.isVisible) { _, visible in
            guard !visible else { return }
            expanded = false
            offer = nil
        }
    }

    private func column(_ rail: SideRailState) -> some View {
        VStack(alignment: .leading, spacing: Tokens.s4) {
            if expanded {
                shutter(rail)
                    .transition(reduceMotion
                        ? .opacity
                        : .scale(scale: 0.2, anchor: .bottomLeading).combined(with: .opacity))
            }
            restButton(rail)
                .overlay(alignment: .bottomLeading) {
                    // Con la persiana recogida, la tarjeta sale al lado de "Premios".
                    if let offer {
                        SideRailOfferCard(kind: offer) { self.offer = nil }
                            .fixedSize()
                            .offset(x: SideRailLayout.restSide + Tokens.s12)
                            .transition(.opacity)
                    }
                }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35), value: expanded)
        .animation(.easeInOut(duration: 0.2), value: offer)
        .task(id: activity) {
            guard expanded else { return }
            try? await Task.sleep(for: SideRailLayout.collapseDelay)
            guard !Task.isCancelled else { return }
            expanded = false
        }
    }

    // MARK: "Premios", en reposo

    private func restButton(_ rail: SideRailState) -> some View {
        Button {
            offer = nil
            if expanded { expanded = false } else { unfold() }
        } label: {
            GameIcon(artKey: "siderail_prizes", size: 28) { VectorTabGiftsIcon() }
                .frame(width: SideRailLayout.restSide, height: SideRailLayout.restSide)
                .background(MetalPlate(cornerRadius: 12))
                .overlay(alignment: .topTrailing) {
                    if rail.readyCount > 0 {
                        SideRailBadge(text: String(rail.readyCount))
                            .offset(x: 6, y: -6)
                    }
                }
                .modifier(ReadyPulse(active: rail.readyCount > 0 && !expanded && !reduceMotion))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tutorialAnchor(.sideRail)
        .accessibilityIdentifier("siderail.toggle")
        .accessibilityLabel(Text("siderail.toggle.ax"))
        .accessibilityValue(Text(verbatim: String(rail.readyCount)))
    }

    // MARK: La persiana

    private func shutter(_ rail: SideRailState) -> some View {
        let rows = stride(from: 0, to: rail.items.count, by: 2).map {
            Array(rail.items[$0 ..< min($0 + 2, rail.items.count)])
        }
        // `Grid` y no `LazyVGrid`, por lo mismo que la botonera: la perezosa se
        // lleva puestos los identifiers.
        return Grid(horizontalSpacing: SideRailLayout.spacing, verticalSpacing: SideRailLayout.spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { item in
                        SideRailButton(item: item) { tapped(item.kind) }
                    }
                }
            }
        }
        .padding(Tokens.s8)
        .background(MetalPlate(cornerRadius: 14))
    }

    private func unfold() {
        expanded = true
        activity &+= 1
    }

    /// Si abre algo u ofrece un video, la persiana se recoge (la tarjeta sale al
    /// lado de "Premios"); si no había nada, el botón tiembla y la persiana se
    /// queda 3 s más.
    private func tapped(_ kind: SideRailKind) -> Bool {
        switch gameState.sideRailTapped(kind) {
        case .acted:
            expanded = false
            offer = nil
            return true
        case .offer:
            expanded = false
            offer = kind
            return true
        case .refused:
            activity &+= 1
            return false
        }
    }
}

/// Un botón de la persiana: redondo como los de la botonera, con el glifo, el
/// "!" (o el número) y, debajo, su reloj en el LED del ascensor.
struct SideRailButton: View {
    let item: SideRailItem
    /// `false` = no había nada que hacer: el botón tiembla.
    let tap: () -> Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes = 0

    private var isReady: Bool {
        if case .ready = item.status { return true }
        return false
    }

    var body: some View {
        Button {
            if !tap(), !reduceMotion { shakes += 1 }
        } label: {
            VStack(spacing: 3) {
                SideRailGlyph(kind: item.kind)
                    .frame(width: SideRailLayout.glyph, height: SideRailLayout.glyph)
                    .frame(width: SideRailLayout.button, height: SideRailLayout.button)
                    .background(
                        Circle()
                            .fill(LinearGradient(colors: [Color.white.opacity(0.85), Color("PaletteCream")],
                                                 startPoint: .top, endPoint: .bottom))
                            .overlay(Circle().strokeBorder(Color("PaletteInk").opacity(0.85), lineWidth: 2))
                    )
                    .opacity(item.status == .idle ? 0.55 : 1)
                    .overlay(alignment: .topTrailing) {
                        if case .ready(let count) = item.status {
                            SideRailBadge(text: count.map { $0 > 9 ? "9+" : String($0) } ?? "!")
                                .scaleEffect(0.8)
                                .offset(x: 5, y: -5)
                        }
                    }
                    .modifier(ReadyPulse(active: isReady && !reduceMotion))
                led
            }
            .frame(width: SideRailLayout.cellWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(RailShake(trigger: shakes))
        .tutorialAnchor(item.kind.tutorialTarget)
        .accessibilityIdentifier("siderail.\(item.kind.rawValue)")
        .accessibilityLabel(Text(LocalizedStringKey("siderail.\(item.kind.rawValue).ax")))
        .accessibilityValue(Text(verbatim: SideRailAX.value(item.status)))
    }

    /// El reloj, con los tonos del display del ascensor. Listo o apagado, la
    /// pantalla queda oscura: el "!" ya lo dice.
    private var led: some View {
        Group {
            switch item.status {
            case .waiting(let seconds): Text(verbatim: SideRailClock.text(seconds))
            case .blocked: Text("prize.package.full")
            case .ready, .idle: Text(verbatim: " ")
            }
        }
        .font(.system(size: 9, weight: .heavy, design: .monospaced))
        .foregroundStyle(ElevatorPanel.ledLit)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(width: SideRailLayout.cellWidth, height: 12)
        .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(ElevatorPanel.ledScreen))
        .accessibilityHidden(true)
    }
}

/// El "!" (o el número) naranja de la columna. El de "Premios" suma los avisos
/// de los cuatro.
struct SideRailBadge: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, 2)
            .background(
                Capsule()
                    .fill(Color("PaletteOrange"))
                    .overlay(Capsule().strokeBorder(Color("PaletteInk"), lineWidth: 2))
            )
            .accessibilityHidden(true)
    }
}

/// El latido de lo que está listo. Sólo mientras lo está y sin Reduce Motion:
/// nada de un `repeatForever` incondicional.
private struct ReadyPulse: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([1.0, 1.08]) { view, scale in
                view.scaleEffect(scale)
            } animation: { _ in
                .easeInOut(duration: 0.7)
            }
        } else {
            content
        }
    }
}

/// Un "no" con la cabeza, como el paquete trabado de E5b.
private struct RailShake: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-5, duration: 0.06)
                CubicKeyframe(5, duration: 0.06)
                CubicKeyframe(-3, duration: 0.06)
                CubicKeyframe(0, duration: 0.06)
            }
        }
    }
}
```

`FisuEvolution/UI/SideRail/SideRailOfferCard.swift`:

```swift
import SwiftUI

/// La tarjeta que sale al lado de "Premios" cuando lo que se tocó ofrece un
/// video: dice qué da ANTES del anuncio (política de AdMob: el video con premio
/// es opt-in y el premio se conoce de antemano).
struct SideRailOfferCard: View {
    let kind: SideRailKind
    let close: () -> Void
    @Environment(GameState.self) private var gameState

    var body: some View {
        GameCard(style: .normal) {
            VStack(alignment: .leading, spacing: Tokens.s8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(kind == .boost ? "siderail.boost.title" : "siderail.rain.title")
                        .font(Tokens.title)
                        .foregroundStyle(Color("PaletteInk"))
                    Spacer(minLength: Tokens.s8)
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color("PaletteInk").opacity(0.6))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("siderail.offer.close")
                    .accessibilityLabel(Text("siderail.offer.close.ax"))
                }
                Text(verbatim: pitch)
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                video
            }
            .frame(width: 220, alignment: .leading)
        }
    }

    /// Un botón por unidad, escrito entero: el contrato del mapa (T7) lee la
    /// unidad en la fuente.
    @ViewBuilder private var video: some View {
        switch kind {
        case .boost:
            RewardedOfferButton(title: String(localized: "siderail.boost.video"),
                                identifier: "siderail.offer.video", placement: .boost) {
                gameState.mergeAllVideoWatched()
                close()
            }
        default:
            RewardedOfferButton(title: String(localized: "siderail.rain.video"),
                                identifier: "siderail.offer.video", placement: .treasure) {
                gameState.packageRainVideoWatched()
                close()
            }
        }
    }

    private var pitch: String {
        switch kind {
        case .boost:
            String(localized: "siderail.boost.pitch \(String(gameState.sideRail.mergeAllPairs))")
        default:
            String(localized: "siderail.rain.pitch \(RewardCopy.title(gameState.content?.rewardedAds.effectiveSideRail.packageRain ?? RewardedAdsConfig.SideRail.default.packageRain))")
        }
    }
}
```

(La tarjeta mide 220 pt y arranca 12 pt a la derecha de "Premios": en el SE termina en x ≈ 300,
dentro de la pantalla; crece hacia arriba desde la base de "Premios".)

`RootView.swift` 🔥:

1. `@State private var railOffer: SideRailKind?` junto a los otros `@State`.
2. En el `body`, después del bloque del `SpriteView` y antes de `hudColumn`, el toque afuera que
   cierra la tarjeta:

```swift
            // Con la tarjeta de un video de la columna abierta, tocar el tablero
            // la cierra (como el selector del atajo).
            if railOffer != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { railOffer = nil }
                    .accessibilityHidden(true)
            }
```

3. En `bottomBar`, después de `.tutorialAnchor(.bottomBar)`:

```swift
        // La columna plegable (E7b) cuelga del borde de arriba de esta franja,
        // contra el borde izquierdo de la PANTALLA (esta franja mide el ancho
        // entero también en iPad): el espejo de la botonera del ascensor, que
        // cuelga del HUD contra el borde derecho. Hereda la atenuación de las
        // celebraciones.
        .overlay(alignment: .topLeading) {
            SideRailView(offer: $railOffer)
                .fixedSize()
                .alignmentGuide(.top) { $0[.bottom] + SideRailLayout.gapAboveBottomBar }
                .padding(.leading, SideRailLayout.edgeInset)
        }
```

4. `.onChange(of: hidesUIForCelebration) { _, hides in if hides { railOffer = nil } }` junto a los
   otros `onChange`.

(Si en el árbol el `bottomBar` quedó adentro de `playColumn()` y en iPad no mide el ancho de la
pantalla, la columna se monta igual pero con `.overlay(alignment: .bottomLeading)` del `ZStack`
del `body` y un `padding(.bottom:)` con el alto de la franja; se mide en el iPad y se anota.)

`StageChips.swift`: se sacan `prizeChips` y su `.animation(…, value: gameState.prizeAccess)`; el
`HStack` queda con lo de E4b. `PrizeChips.swift`: se borran `PackageChip`, `MattressChip`,
`prizeChipBackground()` y `chipShake(_:)` si el Step 0 no les encontró otros usos (con ellos se van
sus anclas `.sidePackages`/`.sideMattress`, que ahora ponen los botones de la persiana);
`PackageGlyph` y `MattressGlyph` se quedan.

- [ ] **Step 6: Los textos**

`Tools/v2/claves-pendientes/e7b-b-t3.json`:

```json
{
  "siderail.toggle.ax": {"es": "Premios", "en": "Prizes"},
  "siderail.wheel.ax": {"es": "Ruleta", "en": "Wheel"},
  "siderail.mattress.ax": {"es": "El Colchón", "en": "The Mattress"},
  "siderail.packages.ax": {"es": "Paquetes de la Aduana", "en": "Customs packages"},
  "siderail.boost.ax": {"es": "Fusionar todo", "en": "Merge all"},
  "siderail.hours %@": {"es": "%@ h", "en": "%@ h"},
  "siderail.boost.title": {"es": "Fusionar todo", "en": "Merge all"},
  "siderail.boost.pitch %@": {"es": "Mirá un video y se hacen de una las %@ fusiones de este piso.", "en": "Watch a video and all %@ merges on this floor happen at once."},
  "siderail.boost.video": {"es": "Fusionar con video", "en": "Merge with a video"},
  "siderail.rain.title": {"es": "Lluvia de paquetes", "en": "Package rain"},
  "siderail.rain.pitch %@": {"es": "Con un video: %@. ¡Andá recogiendo, muchachos!", "en": "Watch a video: %@. Start collecting!"},
  "siderail.rain.video": {"es": "Que llueva", "en": "Make it rain"},
  "siderail.offer.close.ax": {"es": "Cerrar", "en": "Close"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e7b-b-t3.json` → `13 claves nuevas`.

- [ ] **Step 7: Verde, a mano y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `SideRailModelTests`,
`SideRailProjectionTests`, `TutorialTipsTests`, `LocalizationCompletenessTests` → PASS; UI con
`SideRailUITests`, `PrizesUITests`, `EconomyLoopUITests`, `ElevatorPanelUITests` (E3a T8),
`WheelUITests` (E5b) → PASS en el 16 Pro, y `SideRailUITests` en el SE y el iPad Pro 13" → PASS.
A mano, con capturas al reporte (SE, 16 Pro, iPad):

1. la columna plegada al lado de la fila del atajo;
2. desplegada, con la botonera del ascensor abierta al mismo tiempo (las dos hermanas, sin
   cruzarse);
3. la tarjeta de Fusionar todo;
4. el latido de "Premios" con Reduce Motion apagado, y quieto con Reduce Motion prendido (la
   persiana aparece con fundido);
5. un reveal apaga la columna con el resto del HUD.

`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/UI/SideRail/SideRailView.swift
git add FisuEvolution/UI/SideRail/SideRailOfferCard.swift
git add FisuEvolution/UI/SideRail/SideRailGlyphs.swift
git add FisuEvolution/UI/HUD/ElevatorPanel.swift
git add FisuEvolution/Game/State/GameState+SideRail.swift
git add FisuEvolution/UI/Tutorial/TutorialAnchor.swift
git add FisuEvolution/App/RootView.swift
git add FisuEvolution/UI/Visitors/StageChips.swift
git add FisuEvolution/UI/Prizes/PrizeChips.swift
git add FisuEvolutionUITests/PrizesUITests.swift
git add FisuEvolutionUITests/EconomyLoopUITests.swift
git add FisuEvolutionUITests/SideRailUITests.swift
git add Tools/v2/claves-pendientes/e7b-b-t3.json
git diff --cached --stat
git commit -m "feat(columna): la columna plegable — «Premios» en reposo y la persiana de los cuatro, hermana de la botonera"
```

(Si la ola la hace dueña del catálogo: `git add FisuEvolution/Resources/Localizable.xcstrings` y
sin el JSON.)

---

### Task 4: La multitud le deja lugar a la columna — **salteada: el dueño eligió C**

Plegada, la columna no le pide lugar a la multitud. En reposo tapa ~44 × 44 pt; abierta,
~94 × 112 pt por ≤ 3 s. El dueño aceptó eso a cambio de no achicar a los personajes (con A medían
~17 % menos en iPhone). `PlayLayout`, `BoardScene`, `PlayLayoutTests`, `CrowdDepthTests` y el
espejo de `AscentRenderingUITests` quedan como los deja E3a. El código de la opción A (la reserva
de 64 pt y el arte que asoma 0,24 celdas) quedó en la historia de este archivo (commit `5968823`)
por si algún día se reabre.

---

### Task 5: Las lecciones de la columna — primero, abrirla

**Objetivo:** que el tutorial enseñe la columna plegada (PLAN-v2 E9: "cada épica publica su ancla
y declara su lección").

- **La primera lección es abrirla** (`.sideRail`): con algo listo, señala "Premios" ("¡Tenés
  premios guardados! Tocá acá para abrir la columna") y se cumple al desplegarla.
- **Las cuatro lecciones de los botones esperan a ésa.** Son `.packages`, `.mattress` y `.wheel`
  (de E5b T5) y `.mergeAllVideo` (nueva) y señalan su botón adentro de la persiana.
- **Mientras una de ellas está en pantalla, la persiana se abre sola y no se recoge**: si se
  recogiera a los 3 s, el ancla de la lección desaparecería.
- **La de la ruleta deja de mandar a Regalos.**

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift`
- Modify: `FisuEvolution/Game/State/GameState+SideRail.swift` (`sideRailOpened()`; las lecciones se cumplen al tocar)
- Modify: `FisuEvolution/UI/SideRail/SideRailView.swift` ("Premios" avisa que se abrió; la persiana que espera a la lección)
- Modify: `FisuEvolutionTests/TutorialTipsTests.swift`
- Strings: `Tools/v2/claves-pendientes/e7b-b-t5.json` (3 claves)

**Interfaces:**
- Consumes: T3 (`.sideRail`, `.sideWheel`, `.sideBoost`, `sideRailTapped`, `SideRailView`);
  E5b T5 (`.wheel`, `.packages`, `.mattress`); `GameState.tutorialTip` (`GameState.swift:349`,
  observado), `tutorialTipCompleted(_:)`, `isLessonDone(_:)`.
- Produces: `GameState.TutorialLesson.sideRail`, `.mergeAllVideo`; `GameState.sideRailOpened()`;
  la lección `.wheel` con ancla `.sideWheel`.

- [ ] **Step 0: Las lecciones de E5b**

Run: `grep -n "case wheel\|case packages\|case mattress\|case .wheel\|case .packages\|case .mattress" FisuEvolution/Game/State/GameState+TutorialTips.swift`
Expected: los tres casos y sus ramas en los cuatro `switch` (`anchorTarget`, `destinationScreen`,
`textKey`, `isEligible`).

- [ ] **Step 1: Los tests, en rojo**

`TutorialTipsTests.swift`, con el `makeGameState()` privado de ese archivo (el que barre los
defaults y prende `tutorialLessonsAutorun`), sumar:

```swift
    @Test("con algo listo en la columna, la primera lección es abrirla, y abrirla la cumple")
    func openTheRailFirst() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .sideRail && lesson != .packages {
            gameState.markLessonDone(lesson)
        }
        gameState.debugAddPackages(1)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .sideRail, "la de los paquetes espera a la de abrir la columna")
        #expect(GameState.TutorialLesson.sideRail.anchorTarget == .sideRail)
        gameState.sideRailOpened()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .packages, "abierta, ahora sí el botón de los paquetes")
    }

    @Test("Fusionar todo por video se enseña con pares en el piso, señalando su botón")
    func mergeAllVideoLesson() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .mergeAllVideo {
            gameState.markLessonDone(lesson)
        }
        gameState.player?.run.units = ["homeless": 4]
        gameState.reconcileTower()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .mergeAllVideo)
        #expect(GameState.TutorialLesson.mergeAllVideo.anchorTarget == .sideBoost)
        #expect(GameState.TutorialLesson.mergeAllVideo.destinationScreen == nil)
        _ = gameState.sideRailTapped(.boost)
        #expect(gameState.tutorialTip?.lesson != .mergeAllVideo, "tocar el botón la cumple")
    }

    @Test("la ruleta se enseña en la columna, no en Regalos")
    func wheelLessonPointsAtTheRail() {
        #expect(GameState.TutorialLesson.wheel.anchorTarget == .sideWheel)
        #expect(GameState.TutorialLesson.wheel.destinationScreen == nil)
    }
```

(Si el director pide un respiro entre lecciones, se avanza su reloj como lo hacen los tests de
`.packages` de E5b T5 en el mismo archivo.)

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialTipsTests`.
Expected: no compila (`.sideRail`, `.mergeAllVideo`, `sideRailOpened`).

- [ ] **Step 3: Las lecciones**

`GameState+TutorialTips.swift`:

- `TutorialLesson`: `.sideRail` **justo antes de `.packages`** (el orden es la prioridad) y
  `.mergeAllVideo` después de `.wheel`:

```swift
        /// La columna plegable con algo listo: enseña a abrirla. Las de sus
        /// cuatro botones la esperan (E7b).
        case sideRail
```

```swift
        /// Fusionar todo por video, adentro de la columna (E7b): cuando hay
        /// pares en el piso a la vista.
        case mergeAllVideo
```

- `anchorTarget`: `case .sideRail: .sideRail`, `case .mergeAllVideo: .sideBoost`, y `.wheel` pasa a
  `.sideWheel`.
- `destinationScreen`: `.sideRail`, `.mergeAllVideo` y `.wheel` en la fila de `nil` (la ruleta ya
  no manda a Regalos).
- `textKey`: `case .sideRail: "tutorial.tip.side_rail"`,
  `case .mergeAllVideo: "tutorial.tip.merge_all_video"`, y `.wheel` pasa a
  `"tutorial.tip.wheel.rail"`.
- `isEligible` (las de E5b conservan su condición y suman la espera):

```swift
        case .sideRail:
            sideRail.readyCount > 0
        case .packages:
            isLessonDone(.sideRail) && prizeAccess.packagesWaiting > 0 && !prizeAccess.packagesBlocked
        case .mattress:
            isLessonDone(.sideRail) && prizeAccess.mattressReady
        case .wheel:
            // Ya no espera a la de Regalos: no la señala.
            isLessonDone(.sideRail) && prizeAccess.wheelSpinsReady > 0
        case .mergeAllVideo:
            isLessonDone(.sideRail) && sideRail.status(of: .boost) == .ready(count: nil)
```

`GameState+SideRail.swift`:

```swift
    /// El jugador desplegó la columna: la lección de abrirla está cumplida.
    func sideRailOpened() {
        tutorialTipCompleted(.sideRail)
    }
```

y en `sideRailTapped(_:)`, la rama `.wheel` arranca con `tutorialTipCompleted(.wheel)` y la rama
`.boost` con `tutorialTipCompleted(.mergeAllVideo)` (paquetes y colchón ya la cumplen adentro de
`packageTapped()` y `mattressTapped()`, E5b T5).

`SideRailView.swift`:

1. En la acción de "Premios", la rama que despliega avisa: `else { unfold(); gameState.sideRailOpened() }`.
2. La persiana que espera a la lección:

```swift
    /// Una lección señala un botón de la persiana: tiene que estar abierta para
    /// que el ancla exista, y no se recoge mientras la lección esté en pantalla.
    private var lessonHoldsOpen: Bool {
        guard let target = gameState.tutorialTip?.lesson.anchorTarget else { return false }
        return SideRailKind.allCases.contains { $0.tutorialTarget == target }
    }
```

   En `column(_:)`, sobre el `VStack`:

```swift
        .onChange(of: lessonHoldsOpen, initial: true) { _, holds in
            if holds {
                unfold()
            } else {
                // Terminó la lección: desde acá, los 3 s de siempre.
                activity &+= 1
            }
        }
```

   y en el `.task(id: activity)`, la guarda después del `sleep` pasa a
   `guard !Task.isCancelled, !lessonHoldsOpen else { return }`.

`Tools/v2/claves-pendientes/e7b-b-t5.json`:

```json
{
  "tutorial.tip.side_rail": {"es": "¡Tenés premios guardados! Tocá acá para abrir la columna.", "en": "You've got prizes waiting! Tap here to open the column."},
  "tutorial.tip.merge_all_video": {"es": "¿Muchos repetidos? Tocá acá: con un video se fusiona todo el piso de una.", "en": "Lots of duplicates? Tap here: one video merges the whole floor at once."},
  "tutorial.tip.wheel.rail": {"es": "¡Tenés giros de la Ruleta! Están acá, en la columna.", "en": "You've got Wheel spins! They're right here, in the column."}
}
```

(La clave vieja `tutorial.tip.wheel` queda sin uso: la saca E9 cuando reescriba los textos de las
lecciones, o el controlador con la herramienta del catálogo. Anotarla en el reporte.)

- [ ] **Step 4: Verde, a mano y oráculo**

Run: Receta R con `TutorialTipsTests`, `SideRailProjectionTests`, `LocalizationCompletenessTests`
→ PASS; UI con `TutorialUITests` y `SideRailUITests` → PASS (con `--uitest*` las lecciones no
corren solas). A mano, sin flags y con una partida nueva, después del núcleo:

1. con un premio listo, el tip señala "Premios";
2. al tocarlo se despliega la persiana, y el tip siguiente señala el botón que corresponde;
3. la persiana no se recoge mientras ese tip está arriba, y a los 3 s de cumplirlo, sí.

Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+TutorialTips.swift
git add FisuEvolution/Game/State/GameState+SideRail.swift
git add FisuEvolution/UI/SideRail/SideRailView.swift
git add FisuEvolutionTests/TutorialTipsTests.swift
git add Tools/v2/claves-pendientes/e7b-b-t5.json
git diff --cached --stat
git commit -m "feat(columna): las lecciones enseñan a abrir la columna, y la persiana espera a la lección"
```

---

### Task 6: El diario ×2 y la carrera ×2 por video (unidad `daily`)

**Objetivo:** los dos lugares de video del mapa de E7 que todavía no existen. El popup del diario
ofrece duplicar con un video la plata que ya acreditó (una vez por día; el special y el cofre del
día 7 no se duplican). El fork de carrera ofrece, en las carreras con premio de una vez (Juicio
ganado, Obra social), elegirla con el premio ×2 por video.

**Files:**
- Create: `FisuEvolution/Game/State/GameState+AdPlacements.swift` (+ `xcodegen generate`)
- Modify: `FisuEvolution/UI/Popups/DailyRewardView.swift`
- Modify: `FisuEvolution/UI/Popups/CareerChoiceView.swift`
- Create: `FisuEvolutionTests/AdPlacementRewardsTests.swift`
- Strings: `Tools/v2/claves-pendientes/e7b-b-t6.json` (2 claves)

**Interfaces:**
- Consumes: `DailyRewardManager.Claim`, `dayString(for:)` (`ContentSystems.swift:349-361`);
  `CareersConfig.Career.lumpMinutes` (E2a T12); `chooseCareer(optionId:)` (E1 T12); `grant` (E4a T8);
  `RewardedOfferButton` (E4b T3).
- Produces: `GameState.dailyDoubleKey`, `dailyRewardDoubled(now:)`,
  `canDoubleDailyReward(_:now:)`, `doubleDailyReward(_:now:)`, `careerLumpMinutes(optionId:)`,
  `chooseCareerWithVideo(optionId:)`.
- Identificadores: `daily.double`, `career.x2.<optionId>`.

- [ ] **Step 0: Las carreras de E2a y el diario**

Run (uno por llamada):

```bash
grep -n "lumpMinutes" FisuEvolution/Managers/ContentConfigs.swift
grep -n "struct Claim" FisuEvolution/Managers/ContentSystems.swift
grep -n "grantCareerReward(optionId: optionId)" FisuEvolution/Game/State/GameState+Actions.swift
```

Expected: E2a T12 sumó `lumpMinutes`; `chooseCareer` acredita antes del merge (E1 T12). Si la
forma de `Claim` cambió (E2a T11), los tests arman la que haya.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/AdPlacementRewardsTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El diario ×2 y la carrera ×2 (PLAN-v2 E7, unidad `daily`).
@Suite("El diario y la carrera ×2 por video", .serialized)
@MainActor
struct AdPlacementRewardsTests {
    private func coinsClaim(_ gameState: GameState, coins: Double = 500) throws -> DailyRewardManager.Claim {
        let day = try #require(gameState.content?.dailyRewards.days.first)
        return DailyRewardManager.Claim(day: day, coinsGranted: coins, specialGranted: nil, chestGranted: false)
    }

    @Test("el diario de plata se duplica una vez por día")
    func dailyDoublesOncePerDay() async throws {
        let gameState = await makeGameState()
        let claim = try coinsClaim(gameState)
        let now = Date()
        let before = try #require(gameState.player?.run.coins)
        #expect(gameState.canDoubleDailyReward(claim, now: now))
        gameState.doubleDailyReward(claim, now: now)
        #expect(try #require(gameState.player?.run.coins) == before + 500)
        #expect(!gameState.canDoubleDailyReward(claim, now: now))
        gameState.doubleDailyReward(claim, now: now)
        #expect(try #require(gameState.player?.run.coins) == before + 500, "una vez")
        #expect(gameState.canDoubleDailyReward(claim, now: now.addingTimeInterval(86_400)), "mañana es otro diario")
    }

    @Test("el cofre o el special del día 7 no se duplican")
    func onlyCoinsDouble() async throws {
        let gameState = await makeGameState()
        let day = try #require(gameState.content?.dailyRewards.days.last)
        let chest = DailyRewardManager.Claim(day: day, coinsGranted: 0, specialGranted: nil, chestGranted: true)
        #expect(!gameState.canDoubleDailyReward(chest))
    }

    @Test("carrera ×2: elegir con video paga el premio de una vez dos veces")
    func careerTimesTwo() async throws {
        let once = await makeGameState()
        once.debugPresentCareerChoice()
        let before = try #require(once.player?.run.coins)
        once.chooseCareer(optionId: "junior_lawyer")
        let lump = try #require(once.player?.run.coins) - before

        let twice = await makeGameState()
        twice.debugPresentCareerChoice()
        let start = try #require(twice.player?.run.coins)
        twice.chooseCareerWithVideo(optionId: "junior_lawyer")
        let paid = try #require(twice.player?.run.coins) - start

        #expect(lump > 0)
        #expect(abs(paid - 2 * lump) <= max(1, lump) * 0.0001)
        #expect(twice.careerPrompt == nil, "se eligió")
    }

    @Test("sólo las carreras con premio de una vez ofrecen el ×2")
    func onlyLumpCareersOffer() async {
        let gameState = await makeGameState()
        #expect(gameState.careerLumpMinutes(optionId: "junior_lawyer") != nil)
        #expect(gameState.careerLumpMinutes(optionId: "junior_doctor") != nil)
        #expect(gameState.careerLumpMinutes(optionId: "junior_programmer") == nil)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/AdPlacementRewardsTests`.
Expected: no compila (`canDoubleDailyReward`, `chooseCareerWithVideo`).

- [ ] **Step 3: La lógica**

`FisuEvolution/Game/State/GameState+AdPlacements.swift`:

```swift
import EconomyKit
import Foundation

/// Los dos videos de la unidad `daily` (PLAN-v2 E7, mapa de ubicaciones): el
/// diario ×2 y la carrera ×2. Opt-in, con el premio a la vista antes del video.
extension GameState {
    /// La clave de `meta.rewardedActivations`: cuándo se duplicó el último diario.
    static let dailyDoubleKey = "daily.x2"

    /// Si el diario de hoy ya se duplicó. El diario se cobra una vez por día,
    /// así que "hoy" alcanza para decir "este".
    func dailyRewardDoubled(now: Date = Date()) -> Bool {
        guard let last = player?.meta.rewardedActivations[Self.dailyDoubleKey] else { return false }
        return DailyRewardManager.dayString(for: Date(timeIntervalSince1970: last)) == DailyRewardManager.dayString(for: now)
    }

    /// Sólo la plata se duplica: el special y el cofre del día 7 no.
    func canDoubleDailyReward(_ claim: DailyRewardManager.Claim, now: Date = Date()) -> Bool {
        claim.coinsGranted > 0 && !dailyRewardDoubled(now: now)
    }

    /// Terminó el video del ×2: se paga otra vez lo mismo, como el offline (el
    /// diario ya se acreditó cuando el popup apareció).
    func doubleDailyReward(_ claim: DailyRewardManager.Claim, now: Date = Date()) {
        guard canDoubleDailyReward(claim, now: now), var player else { return }
        player.run.coins += claim.coinsGranted
        player.meta.lifetimeEarnings += claim.coinsGranted
        player.meta.rewardedActivations[Self.dailyDoubleKey] = now.timeIntervalSince1970
        player.meta.stats.videosWatchedEver += 1
        self.player = player
        audio?.play(.coin)
        refreshProjections()
        scheduleSave()
    }

    /// Los minutos del premio de una vez de esa carrera (Juicio ganado, Obra
    /// social), o `nil` si su premio no es plata.
    func careerLumpMinutes(optionId: String) -> Double? {
        guard let minutes = content?.careers.careers.first(where: { $0.id == optionId })?.lumpMinutes,
              minutes > 0
        else { return nil }
        return minutes
    }

    /// Elegir carrera con el ×2 del video: lo de siempre, y el premio de una vez
    /// se paga otra vez con la misma cuenta (`grant` de `coinsSeconds` es la de
    /// `lumpMinutes`, E2a). `chooseCareer` acredita antes del merge (E1 T12):
    /// las dos pagas caen en el mismo instante.
    func chooseCareerWithVideo(optionId: String) {
        let minutes = careerLumpMinutes(optionId: optionId)
        chooseCareer(optionId: optionId)
        player?.meta.stats.videosWatchedEver += 1
        guard let minutes else { return }
        grant(.coinsSeconds(minutes * 60), source: "career.x2.\(optionId)")
    }
}
```

- [ ] **Step 4: Los botones**

`DailyRewardView.swift`: `@State private var doubled = false` (el `player` no se observa: el
botón se va por estado local, como en el popup offline); entre `prizeCard` y el `ActionPill` de
cobrar:

```swift
                if !doubled, gameState.canDoubleDailyReward(claim) {
                    RewardedOfferButton(title: String(localized: "daily.double"), identifier: "daily.double",
                                        placement: .daily) {
                        gameState.doubleDailyReward(claim)
                        doubled = true
                    }
                }
```

y el detent pasa a `.presentationDetents([.fraction(gameState.canDoubleDailyReward(claim) && !doubled ? 0.6 : 0.52)])`
(medido en el SE: el botón nuevo no puede recortar el de cobrar contra el marco, el defecto que
el popup offline ya pagó).

`CareerChoiceView.swift`, el `ForEach`:

```swift
                    ForEach(prompt.options) { option in
                        VStack(spacing: Tokens.s4) {
                            optionRow(option, reward: rewards[option.id]?.previewText)
                            // El ×2 va APARTE de la tarjeta (que es el control de
                            // elegir): un video nunca es el mismo botón que la acción.
                            if gameState.careerLumpMinutes(optionId: option.id) != nil {
                                RewardedOfferButton(title: String(localized: "career.double"),
                                                    identifier: "career.x2.\(option.id)", placement: .daily) {
                                    gameState.chooseCareerWithVideo(optionId: option.id)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
```

`Tools/v2/claves-pendientes/e7b-b-t6.json`:

```json
{
  "daily.double": {"es": "Duplicar con un video", "en": "Double it with a video"},
  "career.double": {"es": "Elegir con premio ×2 (video)", "en": "Pick it with a ×2 prize (video)"}
}
```

- [ ] **Step 5: Verde, a mano y oráculo**

Run: Receta R con `AdPlacementRewardsTests`, `CareerRewardTests`, `DailyCalendarTests`,
`LocalizationCompletenessTests` → PASS. A mano en el SE: `--uitest-daily-popup` (el botón y el
cobrar enteros dentro del marco, con y sin el botón) y `--uitest-career` (las cuatro carreras y los
dos ×2 entran sin scroll recortado). Capturas al reporte. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Game/State/GameState+AdPlacements.swift
git add FisuEvolution/UI/Popups/DailyRewardView.swift
git add FisuEvolution/UI/Popups/CareerChoiceView.swift
git add FisuEvolutionTests/AdPlacementRewardsTests.swift
git add Tools/v2/claves-pendientes/e7b-b-t6.json
git diff --cached --stat
git commit -m "feat(anuncios): el diario ×2 y la carrera ×2 por video"
```

---

### Task 7: El botón de video completo, y el contrato del mapa de ubicaciones

**Objetivo:** `RewardedOfferButton` pasa a ser el de los cimientos de PLAN-v2: precarga su video
al aparecer, sondea hasta que llega (4 Hz los primeros 5 s, después cada 2 s mientras se vea) y
mientras tanto dice "Cargando…" en vez de ofrecer un botón que no hace nada; y la unidad deja de
tener default (`.visitor`): cada llamador la dice. Un test que lee las fuentes pinea el mapa de
ubicaciones de PLAN-v2 E7 (qué archivo ofrece videos de qué unidad), y que toda unidad tenga al
menos un lugar.

**Files:**
- Modify: `FisuEvolution/UI/Art/RewardedOfferButton.swift` (E4b T3)
- Modify: `FisuEvolution/UI/Visitors/VisitorPopupView.swift`, `VendorCardsView.swift`, `FisuEvolution/UI/Events/EventPopupView.swift` (E4b; y todo otro llamador sin `placement:`)
- Create: `FisuEvolutionTests/AdPlacementMapTests.swift`
- Strings: `Tools/v2/claves-pendientes/e7b-b-t7.json` (1 clave)

**Interfaces:**
- Consumes: `AdsCoordinator.preloadRewarded(for:)`, `isRewardedReady(for:)`, `showRewarded(for:)`.
- Produces: `RewardedOfferButton(title:identifier:placement:onRewarded:)` con `placement`
  obligatorio; `static RewardedOfferButton.pollInterval(attempt:) -> Duration`.
- Identificadores: `<identifier>.loading` (nuevo), `<identifier>.watching` (de E4b).

- [ ] **Step 0: Todos los llamadores**

Run (uno por llamada):

```bash
grep -rn "RewardedOfferButton(" FisuEvolution
grep -rln "showRewarded(for:\|preloadRewarded(for:\|placement: \." FisuEvolution
```

Expected: la lista completa de los lugares de video. Cada archivo que aparece tiene que estar en
la tabla del Step 1 con sus unidades; si aparece uno que el plan no previó (un llamador nuevo de
otra épica), se suma con su unidad según el mapa de PLAN-v2 E7 y se anota.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/AdPlacementMapTests.swift`:

```swift
import Foundation
import Testing
@testable import FisuEvolution

/// El mapa de ubicaciones de PLAN-v2 E7: qué lugar del juego ofrece videos de
/// qué unidad de AdMob. AdMob reporta por unidad, así que este mapa es lo que
/// el dueño lee en el panel. Un lugar nuevo sin fila acá, o con otra unidad,
/// pone esto en rojo.
@Suite("El mapa de ubicaciones de video")
struct AdPlacementMapTests {
    /// Rutas desde `FisuEvolution/`.
    static let map: [String: Set<RewardedPlacement>] = [
        "UI/Gifts/GiftsView.swift": [.gifts, .boost],
        "UI/Popups/OfflineEarningsView.swift": [.offlineX2],
        "UI/Popups/ChestOpeningView.swift": [.chestExtra],
        "UI/Popups/DailyRewardView.swift": [.daily],
        "UI/Popups/CareerChoiceView.swift": [.daily],
        "UI/SideRail/SideRailOfferCard.swift": [.boost, .treasure],
        "UI/Wheel/WheelView.swift": [.wheel],
        "UI/Prizes/MattressPopupView.swift": [.treasure],
        "UI/Visitors/VisitorPopupView.swift": [.visitor],
        "UI/Visitors/VendorCardsView.swift": [.visitor],
        "UI/Events/EventPopupView.swift": [.visitor],
    ]

    private static let usage = try! NSRegularExpression(
        pattern: #"(?:placement:\s*|showRewarded\(for:\s*|preloadRewarded\(for:\s*|isRewardedReady\(for:\s*)\.([A-Za-z0-9]+)"#
    )

    private static var appRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "FisuEvolution")
    }

    static func placements(in source: String) -> Set<RewardedPlacement> {
        let range = NSRange(source.startIndex..., in: source)
        return Set(usage.matches(in: source, range: range).compactMap { match in
            Range(match.range(at: 1), in: source).flatMap { RewardedPlacement(rawValue: String(source[$0])) }
        })
    }

    @Test("cada lugar ofrece videos de su unidad, y no hay lugares fuera del mapa")
    func everyOfferUsesItsUnit() throws {
        let root = Self.appRoot
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        var found: [String: Set<RewardedPlacement>] = [:]
        for file in files {
            let path = String(file.path.dropFirst(root.path.count + 1))
            // La costura misma (proveedor, coordinador, flags) habla de unidades
            // en general; no es un lugar del juego.
            guard !path.hasPrefix("Managers/Ads/"), path != "Managers/FeatureFlags.swift" else { continue }
            let used = Self.placements(in: try String(contentsOf: file, encoding: .utf8))
            if !used.isEmpty { found[path] = used }
        }
        #expect(found == Self.map)
    }

    @Test("toda unidad de video tiene al menos un lugar")
    func everyUnitHasAPlace() {
        #expect(Set(Self.map.values.flatMap { $0 }) == Set(RewardedPlacement.allCases))
    }

    @Test("el botón sondea rápido al principio y después espaciado")
    func pollInterval() {
        #expect(RewardedOfferButton.pollInterval(attempt: 0) == .milliseconds(250))
        #expect(RewardedOfferButton.pollInterval(attempt: 19) == .milliseconds(250))
        #expect(RewardedOfferButton.pollInterval(attempt: 20) == .seconds(2))
    }
}
```

(El Vendedor Ambulante —que el árbol de PLAN-v2 ponía en E7b— vive entero en E4a/E4b; su lugar en
el mapa es la fila de `VendorCardsView`.)

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/AdPlacementMapTests`.
Expected: no compila (`pollInterval`); con eso puesto, `everyOfferUsesItsUnit` FAIL — los
llamadores de E4b no dicen su unidad (usan el default).

- [ ] **Step 3: El botón**

`RewardedOfferButton.swift`:

```swift
import SwiftUI

/// El botón de "mirá un video y…" de la 2.0 (PLAN-v2, cimientos). Precarga su
/// video al aparecer y sondea hasta que llega: mientras tanto dice "Cargando…"
/// en vez de ofrecer un botón que no haría nada. El premio se entrega SÓLO si
/// el anuncio terminó con premio (`onRewarded`). La unidad es obligatoria: es
/// la fila del mapa de ubicaciones (`AdPlacementMapTests`).
struct RewardedOfferButton: View {
    let title: String
    let identifier: String
    let placement: RewardedPlacement
    let onRewarded: () -> Void

    @Environment(AdsCoordinator.self) private var ads
    @State private var ready = false
    @State private var watching = false
    /// Cambia después de cada video: rearranca la espera del próximo.
    @State private var generation = 0

    var body: some View {
        Group {
            if watching {
                ProgressView()
                    .frame(minWidth: 92, minHeight: 36)
                    .accessibilityIdentifier("\(identifier).watching")
            } else if ready {
                ActionPill(verbatim: title, systemImage: "play.fill", tint: Color("PaletteGreen"),
                           identifier: identifier) { watch() }
            } else {
                StateBadge(text: String(localized: "ads.loading"), systemImage: "hourglass", muted: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("\(identifier).loading")
            }
        }
        .task(id: generation) { await waitForInventory() }
    }

    /// 4 Hz los primeros 5 s (un video suele tardar 1–3 s) y después cada 2 s,
    /// mientras la vista exista: si el video llega tarde, el botón aparece solo.
    static func pollInterval(attempt: Int) -> Duration {
        attempt < 20 ? .milliseconds(250) : .seconds(2)
    }

    private func waitForInventory() async {
        ads.preloadRewarded(for: placement)
        var attempt = 0
        while !Task.isCancelled {
            if ads.isRewardedReady(for: placement) {
                ready = true
                return
            }
            try? await Task.sleep(for: Self.pollInterval(attempt: attempt))
            attempt += 1
        }
    }

    private func watch() {
        watching = true
        Task {
            let earned = await ads.showRewarded(for: placement)
            watching = false
            ready = false
            generation += 1
            if earned { onRewarded() }
        }
    }
}
```

(El `ActionPill(verbatim:…)` es el de E4b T3; el resto de la API de E4b se conserva.)

En los llamadores de E4b (`VisitorPopupView`, `VendorCardsView`, `EventPopupView` y cualquier otro
que el Step 0 haya listado sin `placement:`): `placement: .visitor` explícito en cada
`RewardedOfferButton(…)`.

`Tools/v2/claves-pendientes/e7b-b-t7.json`:

```json
{
  "ads.loading": {"es": "Cargando video…", "en": "Loading video…"}
}
```

- [ ] **Step 4: Verde, a mano y oráculo**

Run: Receta R con `AdPlacementMapTests`, `LocalizationCompletenessTests` → PASS; UI con
`VisitorUITests`/`EventChipUITests` (E4b), `PrizesUITests`, `WheelUITests`, `SideRailUITests` →
PASS (con el stub el video está listo en el primer sondeo). A mano en DEBUG (anuncios de prueba de
Google, sin `--uitest`): abrir el colchón con la red lenta (Network Link Conditioner, "3G") → se ve
"Cargando video…" y después el botón, sin cerrar el popup. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/UI/Art/RewardedOfferButton.swift
git add FisuEvolution/UI/Visitors/VisitorPopupView.swift
git add FisuEvolution/UI/Visitors/VendorCardsView.swift
git add FisuEvolution/UI/Events/EventPopupView.swift
git add FisuEvolutionTests/AdPlacementMapTests.swift
git add Tools/v2/claves-pendientes/e7b-b-t7.json
git diff --cached --stat
git commit -m "feat(anuncios): el botón de video precarga y espera, y el mapa de ubicaciones queda pineado"
```

---

### Task 8: Cierre de E7b (controlador)

- [ ] **Step 1: Oráculo, capturas y escenarios**

`Tools/v2/oraculo.sh completo` sobre la punta de la épica → `VERDE`. Capturas al reporte:

- la columna plegada y desplegada en el SE, el 16 Pro, el Pro Max y el iPad 13", con 10 y 15
  lugares;
- la columna abierta junto a la botonera del ascensor abierta;
- la tarjeta de Fusionar todo;
- el diario con su ×2 y el fork con sus ×2.

Escenarios de PLAN-v2 §8:

- "15 lugares en el SE sin pisar el HUD ni las columnas". Con la plegable, "Premios" tapa ~20 pt
  del personaje de la celda 0, como aceptó el dueño, y la persiana tapa la multitud ≤ 3 s.
- "Fusionar todo con un tier nuevo en el medio, que se celebra". Ahora también por video, desde la
  columna.

- [ ] **Step 2: Documentación (controlador)**

1. `Docs/SESION-<fecha>-v2-e7b.md` (la de E7b-a, ampliada): la tabla por tarea de E7b-b, la
   decisión del 🔒 (C, la plegable) con lo medido en el SE (dónde cae "Premios" y cuánto tapa la
   persiana abierta).
2. `Docs/HANDOFF.md`:
   - **§4**: "E7b-b — la columna plegable". Lee `sideRail` y toca por las puertas de E5. Hereda la
     placa de metal, el LED y la persiana de la botonera. Suma sus dos videos, saca los chips de
     premios, y trae el diario y la carrera ×2, el botón con precarga y el mapa pineado.
   - **§5**: el dueño eligió la columna plegable (C), con el porqué; los defaults que no cambió.
   - **§7** (trampas nuevas):
     - "un lugar de video nuevo tiene que decir su unidad y sumar su fila a `AdPlacementMapTests`";
     - "la columna cuelga de la franja de abajo: si esa franja deja de medir el ancho de la
       pantalla, en iPad la columna se va al medio";
     - "la persiana no se recoge mientras una lección señala uno de sus botones: si se recogiera,
       el ancla desaparece";
     - "la proyección de la columna cambia a lo sumo una vez por segundo: no publicar segundos con
       decimales";
     - las que aparezcan.
   - **§9**: los dos planes y la sesión.
3. `Docs/PLAN-v2.md`: E7 marcada hecha, con el desvío de la columna ("plegable, decisión del
   dueño") y los demás que el dueño confirmó.

---

## Lo que E7b le deja a otras épicas

- **E9 (tutorial v2):**
  - Anclas: `.sideRail` es "Premios"; `.sideWheel`, `.sideMattress`, `.sidePackages` y `.sideBoost`
    son los botones de la persiana.
  - Lecciones para migrar a su currículo y registrar en `TutorialCoverageTests`: `.sideRail` (abrir
    la columna), y `.packages`, `.mattress`, `.wheel` y `.mergeAllVideo`, que esperan a la primera.
    La pausa publicitaria no lleva lección: se explica sola en su pantalla previa.
  - El Tour de veteranos tiene su paso de "columna plegable": tocar "Premios".
  - La clave vieja `tutorial.tip.wheel` quedó sin uso.
  - **UMP ya está en Ajustes** (E7b-a T5): E9 no la rehace.
  - El reset de partida **no** toca `ads.pacing` (`UserDefaults`, preferencia del dispositivo); sí
    borra los enfriamientos de la columna y el ×2 del diario (`rewardedActivations`, en el save).
- **E2b (calibración):**
  - Fuentes nuevas para el perfil `.ads` del simulador: Fusionar todo por video (cada 10 min, con
    pares), la lluvia de paquetes (cada 30 min), la pausa publicitaria (10 min de producción / ×2
    por 5 min / un Paquete, cada ~4 min de cortes con alternancia 1:1), el diario ×2 y la carrera
    ×2.
  - Las perillas: `rewarded_ads.json` (`sideRail`, `adBreak`) y la cadencia de `ads.json`.
  - El tablero no cambia de tamaño: la columna plegable no toca `PlayLayout`.
- **E10 (release):**
  - Notas a App Review con todos los lugares de anuncios:
    - los forzados, sólo en cortes naturales: cerrar el menú, cerrar el popup offline, reencarnar,
      el fin de una celebración grande;
    - la pausa con su pantalla previa de 5 s y "No, gracias";
    - el app open al volver tras ≥ 3 min (1 cada 20 min, desde el segundo arranque);
    - los videos opt-in de la columna (detrás de "Premios"), del diario y de la carrera.
  - App Privacy con la tabla de los SDK (E7b-a T6).
  - Publicar `config/ads.json`; crear las unidades nuevas de AdMob y prender `switches.appOpen`.
  - Las capturas muestran "Premios" (plegada).
- **E8 (arte):**
  - Las claves del atlas `ui`: `siderail_prizes` ("Premios"; mientras tanto, el regalo vectorial de
    la pestaña) y `siderail_boost` (el glifo de Fusionar todo).
  - La placa es la `MetalPlate` de la botonera, por código.
- **E11:** ninguna notificación nueva (guía 4.5.4: nada de anuncios ni ofertas).

## Para el dueño / dudas

Las de E7b-a siguen en pie. Éstas son de E7b-b; **ninguna frena**: la ejecución sigue con el
default.

1. **La columna: decidido, C (plegable)**. Ver "Decidido por el dueño" al principio. T4 quedó
   salteada y `PlayLayout` intacto.
2. **El "!" de "Premios" cuenta los accesos listos**, de 0 a 4, y la ruleta cuenta. Con 6 giros
   por día, la ruleta está lista casi todo el día, así que el "!" queda prendido casi siempre. Es
   el mismo problema que E5b evitó con el puntito de Regalos (su duda 5).
   **Default:** cuenta; con la columna plegada, el número igual dice "hay algo adentro".
   **Alternativa:** que la ruleta cuente sólo con giros regalados. Para eso `PrizeAccess` tiene que
   separar los regalados de los de video (E5b T2).
3. **La persiana se recoge a los 3 s, la botonera a los 2.** Lo de la columna lo pidió el dueño;
   la botonera no se toca. **Default:** cada una con el suyo.
4. **Las dos hermanas abiertas a la vez no se cruzan**: la botonera está arriba a la derecha y la
   columna abajo a la izquierda, en todo iPhone y en iPad. Abrir una no cierra la otra, y cada una
   se recoge con su reloj. **Default:** independientes.
5. **"Premios" tapa en reposo ~20 pt del personaje de la celda 0** (la parte de abajo a la
   izquierda; en el SE su arte arranca en x ≈ 35 y el botón termina en 56), y un toque ahí lo toma
   el botón. No choca con ningún control: el atajo queda 10 pt abajo, los toasts ~260 pt arriba, y
   las cajas del Paquete a ≥ 72 pt del borde. **Default:** así (es el costo que el dueño aceptó).
6. **Abierta, la persiana tapa ~94 × 112 pt de la multitud por ≤ 3 s.** Puede tapar una caja del
   Paquete parada en su borde, o un toast ancho (el toast queda encima). **Default:** así, como la
   botonera abierta tapa las filas de atrás (S6).
7. **La persiana sólo se abre al tocar "Premios"**, o cuando una lección señala uno de sus botones
   (y entonces espera a que la lección termine). Nunca por un "!" nuevo: abrirse sola taparía la
   multitud sin que nadie lo pidiera. **Default:** así.
8. **La tarjeta de un video sale al lado de "Premios", con la persiana recogida** ("tocar uno la
   recoge"); la cierran la X, el video o un toque al tablero. **Default:** así.
9. **Las lecciones de los cuatro botones esperan a la de abrir la columna.** **Default:** así; la
   de la ruleta deja de pasar por Regalos.
10. **Material de metal, no de madera.** La columna es maquinaria del HUD y hermana de la botonera
    (FisuJobs manda en paneles y tarjetas; el metal, en la maquinaria). **Default:** `MetalPlate`.
11. **"Boost por video" es Fusionar todo.** PLAN-v2 §2 llama a Fusionar todo "Boost por video o
    por ORO", y E2a le deja el video a E7b. Los boosts con enfriamiento de Regalos ("boost sin
    esperar") siguen en Regalos. **Default:** el cuarto botón es Fusionar todo por video, cada
    10 min, sólo con pares en el piso a la vista.
12. **La lluvia de paquetes por video la ofrece Paquetes** cuando no hay ninguno esperando (cada
    30 min; con el buzón lleno o un piquete, no). Nadie la ofrecía y el mapa de E7 la nombra.
    **Default:** así.
13. **Los chips de premios de `StageChips` se van.** La columna es el acceso al paquete y al
    colchón (más sus cajas en el tablero, E5b T3). **Default:** se borran.
14. **El diario ×2 sólo duplica la plata**, una vez por día; el special y el cofre del día 7 no.
    **Default:** así.
15. **La carrera ×2 se elige desde el fork**: un botón aparte debajo de las carreras con premio de
    una vez (Abogado, Médico). El Programador y la pinta no tienen ×2. **Default:** así.
16. **`RewardedOfferButton` pierde el default `.visitor`.** Cada lugar dice su unidad y el
    contrato del mapa lo pinea. **Default:** así.
17. **Los relojes de Paquetes y Colchón son de juego activo** (los de E5a): corren mientras se
    juega, no con la app cerrada. **Default:** así; el de la ruleta es de reloj (la medianoche).
