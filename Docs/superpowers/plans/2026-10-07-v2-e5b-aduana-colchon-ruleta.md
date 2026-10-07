# E5b — Paquete de la Aduana, El Colchón y Ruleta, lo que se ve: la ruleta, los accesos, las cajas y la apertura · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que el jugador vea y toque los tres premios de E5: la Ruleta presentada por el Conductor
de TV, que gira con un ease-out de 3,8 s y un tic por rebanada y tiene la tabla de
probabilidades a la vista; el Paquete de la Aduana y El Colchón esperando en el tablero y en un
chip bajo el HUD; la caja que se abre (sacudida, tapa que vuela, monedas y resorte) en el lugar
donde llega el empleado; el colchón con su popup de video y "otro colchón"; la ruleta en
Regalos; las tres lecciones y el aviso `wheel_ready`.

**Architecture:** E5a dejó el motor (qué, cuándo, cuánto). E5b le pone cara sin decidir nada: la
ruleta es una vista SwiftUI (`Canvas` + `TimelineView`) cuya geometría es pura
(`WheelGeometry`) y que anima un premio **ya acreditado**; los accesos leen una sola proyección
(`GameState.prizeAccess`, publicada a 8 Hz) y llaman a `packageTapped()`, `mattressTapped()` y
`openWheel()`, que son también las puertas de la columna de E7b; las cajas y el colchón del
tablero son un colaborador de `BoardScene` (`PickupController`, por frame, como el escenario de
E4b); y la apertura del paquete es parte del **turno del tablero de E1** (`PackageOpeningPlayer`
dentro de `performBoardChange`), así hereda la revalidación, el salto, el watchdog, el asiento al
irse y la revelación. El arte de E8 todavía no existe: todo cae a un respaldo dibujado por código.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI (`Canvas`,
`TimelineView`, `keyframeAnimator`) · SpriteKit · CoreHaptics · EconomyKit · Swift Testing ·
XCUITest · XcodeGen.

**Fuente:** `Docs/PLAN-v2.md` §4 "E5" (Paquete: "apertura procedural"; Colchón: "`PickupNode` en
el borde del tablero y botón de la columna lateral"; Ruleta: `Canvas`, ~3,8 s, ticks hápticos,
"vive en Regalos y en la columna lateral; la presenta el Conductor de TV"), §2, §5 (por código y
sonidos), E11 (la notificación `wheel_ready`), E9 (toda mecánica declara su lección) y E7
(columna lateral). E5a (`2026-10-07-v2-e5a-aduana-colchon-ruleta.md`) es la base: **sus Global
Constraints, su "Verificación" y su tabla de herencia valen acá enteras**; abajo van sólo los
agregados.

**Rama de la épica:** `v2/e5-premios` (la misma de E5a). E5b arranca cuando E5a cerró (T9).

## Global Constraints (además de las de E5a)

- **La escena no se toca más que en ganchos cortos**: `BoardScene.swift` es caliente, tiene ~1.830
  líneas y sus miembros son `private`. Lo nuevo vive en `Scenes/Prizes/` y `BoardScene` sólo
  adjunta, ubica, actualiza, pasa los toques y, en el turno del tablero, delega la apertura. La
  Task 3 dice exactamente qué líneas.
- **Todo lo que se mueve en el tablero se mueve por frame** (`update(delta:reduceMotion:)`), no
  con `SKAction`: así el test lo ejerce con un `SKNode` pelado y deltas inyectados (criterio de
  E4b). La ruleta gira por `TimelineView`, con la geometría pura testeada aparte.
- **Reduce Motion**: la ruleta no gira (salta al resultado), las cajas aparecen con fundido y sin
  rebote, la apertura del paquete es un fundido corto sin sacudida ni monedas, los chips no laten.
  Cada tarea con movimiento se verifica en el simulador **en los dos sentidos** (trampa 9).
- **Toda hoja nueva con `fisuSheet()`** (E3a T6; `SheetPresentationGuardTests` lo exige). ⚠️ El
  spike S1 de E3a cambió el mecanismo a `fullScreenCover` en iPad (sesión del relevo 4): el paso
  0 de cada tarea con hojas mira cómo quedó la firma (`grep -n "func fisuSheet" FisuEvolution/UI/Art/PanelFrames.swift`)
  y usa la que haya; si ya no es un modificador de vista, se presenta con la API que dejó E3a T6
  y se anota en el reporte.
- **Mientras una hoja de E5 está abierta, `uiCoversBoard` está en `true`** (el `coversBoard` de
  `RootView` que dejó E4b T3): así frenan los cambios del tablero, las lecciones, la paciencia
  de los visitantes y los intersticiales.
- **`accessibilityIdentifier` en cada control, nunca en un contenedor con hijos** (trampa 9a-bis);
  los marcadores para tests van como elemento combinado (`.accessibilityElement(children:
  .combine)`) o `.accessibilityElement()` sobre una hoja sin hijos accesibles.
- **FisuJobs es la referencia visual**: `PanelCard`/`GameCard`, `ActionPill`/`PricePill`/`StateBadge`,
  pergamino, paleta (`PaletteYellow`, `PaletteGreen`, `PaletteOrange`, `PaletteBlue`,
  `PalettePink`, `PaletteBrown`, `PaletteCream`, `PaletteInk`) y tipografía de la casa (`Tokens`).
  Nada de botones ni alertas del sistema.
- **Sin arte, con respaldo**: las claves del atlas `ui` que E8 tiene que entregar son
  `pickup_package`, `pickup_package_lid`, `pickup_mattress` y `wheel_icon`; sin entrada en el
  manifest, se dibuja por código (`PickupArt.placeholder`, `PackageGlyph`, `MattressGlyph`,
  `WheelGlyph`). Ningún flujo espera al batch.
- **Sonido**: `sfx_wheel_tick.caf` ya está en `Resources/Audio`; se cablea como
  `AudioManager.SFX.wheelTick` con su llamada en `Game/State` (`AudioWiringTests` lo exige).
- **Strings por snapshot** `Tools/v2/claves-pendientes/e5b-tN.json` y `Tools/v2/catalogo.py
  aplicar` (E3a T1, formato canónico, trampa 29). Los textos con números **interpolan el dato**
  con `%1$@` en el VALOR y se llenan con `RewardCopy.text(_:_:)` (la regla de `IAPCopy`, HANDOFF
  §5); a una clave con `%@` se le interpola un `String`, nunca un `Int` (trampa 5).
- **Commits** `feat(ruleta): …`, `feat(paquetes): …`, `feat(colchon): …`, `feat(premios): …`, SIN
  `Co-Authored-By`.

## Verificación

La de E5a (oráculo, Receta R con `build/DD-e5` y simulador `e5-…`). `rapido` al cerrar T1 y T6;
`completo` al cerrar T2, T3, T4 y T5 (tocan lo que se ve o la escena) y la épica (T7). Los UI tests
nuevos (`PrizesUITests`, `WheelUITests`) entran solos al `completo`.

Mirar en el simulador cada tarea con UI en el **iPhone SE** y el **iPad Pro 13"**, claro y
oscuro (la app fuerza claro: se verifica que nada dependa del esquema), con Reduce Motion
prendido y apagado. Capturas al reporte de la tarea.

## Las referencias de PLAN-v2 E5 que toca E5b, verificadas contra el árbol (`d22eb7a`)

| Lo que cita el plan | Dónde está hoy | Qué hace E5b |
|---|---|---|
| "Apertura procedural: sacudida, tapa que vuela, partículas y resorte" | `ParticlePool` (`Game/Effects/ParticlePool.swift`), `particles.emit(_:at:in:)` desde `BoardScene.swift:12`; el turno del tablero (`performBoardChange`, `confirmWithoutGesture`) lo crea **E1 T10** | T3: `PackageOpeningPlayer` por frame dentro del turno |
| "Un tipo nunca visto pasa por la revelación de E1" | `confirmWithoutGesture` → `presentResolution(withinTurn:)` (E1 T10) | T3 confirma la llegada al terminar la caja: la revelación sale sola |
| `PickupNode` "en el borde del tablero" (y "los pickups cuelgan del escenario como `StageEffects`", E4b) | no existe; E4b T1 deja el patrón (`StageController`: `attach`, `layout`, `update`, `handleTap`) y `StageLayout` (escenario en x ∈ [28 %, 72 %]) | T3: `PickupController` + `PickupNode` + `PickupLayout` |
| "Se ve como botón de la columna lateral, con el badge «!»" | la columna es de **E7b** (🔒 del dueño, S5: pisa la multitud en todo iPhone) | T2 pone chips en `StageChips` (E4b T3) y publica `prizeAccess`; no toca la columna |
| `Canvas` y ease-out de ~3,8 s, ticks hápticos | `HapticsManager.Pattern` (`HapticsManager.swift:13-19`) no tiene tic; `sfx_wheel_tick.caf` en el bundle sin caso en `AudioManager.SFX` (`AudioManager.swift:14-30`) | T1: `.tick`, `.wheelTick`, `WheelGeometry.boundariesCrossed` |
| "Vive en Regalos" | `GiftsView` (`UI/Gifts/GiftsView.swift:32-275`): `NavigationStack` sin destinos (`:117-190`), cascada `staggeredAppearance` por índice (`:132-167`); el tab es `hud.bonus` | T4: tarjeta y empuje |
| "La presenta el Conductor de TV" | `npc_conductor`, guion `conductor_ruleta` (E4a T7); `VisitorFace` (E4b T3); el popup del visitante es un `.sheet(item:)` de `RootView` (E4b T3) | T1 (anfitrión en la ruleta), T2 (abrirla al cerrarse su popup) |
| `OddsDisclosureView` "compartida por la ruleta, el cofre por ORO y el Colchón" | no existe; PLAN la pone en E6 | T1 la crea; T2 la usa en el colchón; E6 la reusa |
| `wheel_ready` "giros nuevos de la ruleta" | `NotificationKind` (3 casos, `NotificationsConfig.swift:10-17`), `NotificationSnapshot` (`NotificationPlanner.swift:6-21`), `moments` (`:91-111`), `notifications.json` (3 ids) | T6, con las cinco piezas que dejó E11 |
| "el punto del paquete lo agrega E5" (E3a duda 6) | la botonera del ascensor es de E3a T8 | no se agrega (duda 4) |
| toda mecánica nueva declara su lección (E9) | `GameState.TutorialLesson` (9 casos, `GameState+TutorialTips.swift:18-45`), `TutorialTarget` (`UI/Tutorial/TutorialAnchor.swift:8-30`) | T5 suma tres, con las anclas `.sidePackages`/`.sideMattress` de E9 |

## Lo que E5b usa (además de lo que E5a hereda de E1, E3b y E4a)

| API | La define | La usa |
|---|---|---|
| todo lo de E5a: `openPackage`, `packagesWaiting/Blocked`, `openMattress`, `openExtraMattress`, `MattressOutcome`, `wheelSegments`, `wheelOdds`, `wheelAvailability`, `spinWheel`, `repeatWheelPrize`, `WheelSpinOutcome`, `WheelAvailability`, `LootBoxGate`, `debug*` | E5a T6–T8 | T1–T6 |
| `RewardedOfferButton(title:identifier:placement:onRewarded:)`, `VisitorFace(visitorId:side:)`, `ActionPill(verbatim:…)`, `StageChips` | E4b T3 | T1, T2 |
| `GameState.visitorPopup`, `closeVisitorPopup()`, el `coversBoard` de `RootView` y sus `onChange` | E4b T3, T4 | T2 |
| `StageController` y sus cinco ganchos en `BoardScene`; `StageLayout` (`standX`, `actorSide`, `baselineY`) | E4b T1 | T3 |
| `performBoardChange`, `confirmWithoutGesture`, `abortBoardCelebration` con el cambio en vuelo, `presentResolution` | E1 T10 | T3 |
| `fisuSheet()`, `playColumn()`, `PlayLayout` | E3a T6, T4, T3 | T1, T2 |
| `GameState.notificationSnapshot(now:)` en `GameState+Notifications.swift`; las filas de Ajustes por motivo | E11 T6, T4 | T6 |

## El paquete, de la caja al empleado

```
packages.waiting > 0 ──► refreshProjections → refreshPrizeAccess → prizeAccess (8 Hz)
   ├─ StageChips: PackageChip "×2" / "LLENO"            ─┐
   └─ PickupController: hasta 3 cajas sobre la línea      ├─ tocar → packageTapped() → openPackage()
      del escenario, a la izquierda del visitante        ─┘      .full → la caja/el chip tiemblan
                                                                 .opened → BoardChange.arrival(origin: .package)
turno del tablero (E1, prioridad 3) ─► playBoardChange: vuela al piso
   └─ performBoardChange: .arrival + .package ─► PackageOpeningPlayer en el lugar libre
        cae 0,25 s · se sacude 0,5 s · la tapa vuela 0,3 s + monedas ─► confirmWithoutGesture
        └─ placeUnit → layoutBoard → el empleado aparece donde estaba la caja → presentResolution
skip / watchdog / irse: abortBoardCelebration → packageOpening.cancel(); el cambio lo asienta E1
```

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `FisuEvolution/UI/Wheel/WheelGeometry.swift` | **nuevo** — rebanadas, dónde para, ticks, ease-out, `WheelSpinAnimation` | 1 |
| `FisuEvolution/UI/Wheel/WheelCanvas.swift` | **nuevo** — la rueda en `Canvas`, el puntero y `WheelGlyph` | 1 |
| `FisuEvolution/UI/Wheel/WheelView.swift` | **nuevo** — la pantalla de la ruleta | 1 |
| `FisuEvolution/UI/Art/OddsDisclosureView.swift` | **nuevo** — las probabilidades a la vista | 1 |
| `FisuEvolution/Managers/RewardCopy.swift` | **nuevo** — cómo se dice cada `RewardSpec` | 1 |
| `FisuEvolution/Audio/AudioManager.swift`, `FisuEvolution/Managers/HapticsManager.swift` | `.wheelTick`, `.tick` | 1 |
| `FisuEvolution/Game/State/GameState+Wheel.swift` | `playWheelTick()` (T1), `wheelSpinsReadyAt` (T6) | 1, 6 |
| `FisuEvolution/Game/State/PrizeAccess.swift` | **nuevo** — `PrizeAccess`, `MattressPopup`, `WheelSheet` | 2 |
| `FisuEvolution/Game/State/GameState.swift` | tres proyecciones y una bandera; una línea en `refreshProjections` | 2 |
| `FisuEvolution/Game/State/GameState+Prizes.swift` | **nuevo** — los accesos: publicar, tocar, el popup del colchón, la ruleta suelta, el Conductor | 2, 5 |
| `FisuEvolution/Game/State/GameState+Rewards.swift` | un giro regalado por un visitante abre la ruleta | 2 |
| `FisuEvolution/UI/Prizes/PrizeChips.swift` | **nuevo** — `PackageChip`, `MattressChip` y sus glifos | 2, 5 |
| `FisuEvolution/UI/Visitors/StageChips.swift` | los dos chips al lado del visitante | 2 |
| `FisuEvolution/UI/Prizes/MattressPopupView.swift` | **nuevo** — el colchón | 2 |
| `FisuEvolution/App/RootView.swift` | dos hojas, `coversBoard`, el `onDismiss` del visitante | 2 |
| `FisuEvolution/UI/DebugPanelView.swift` | la sección de premios | 2 |
| `FisuEvolution/Scenes/Prizes/PickupLayout.swift`, `PickupNode.swift`, `PickupController.swift`, `PickupArt.swift`, `PackageOpeningPlayer.swift` | **nuevos** — las cajas, el colchón y la apertura | 3 |
| `FisuEvolution/Scenes/BoardScene.swift` | siete ganchos | 3 |
| `FisuEvolution/UI/Gifts/GiftsView.swift`, `FisuEvolution/UI/Wheel/WheelGiftCard.swift` | la ruleta en Regalos | 4 |
| `FisuEvolution/Game/State/GameState+TutorialTips.swift`, `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` | tres lecciones, dos anclas | 5 |
| `Packages/EconomyKit/Sources/EconomyKit/NotificationsConfig.swift`, `NotificationPlanner.swift`, `FisuEvolution/Resources/Config/notifications.json`, `FisuEvolution/Game/State/GameState+Notifications.swift` | `wheel_ready` | 6 |
| tests | `WheelGeometryTests`, `RewardCopyTests`, `PrizeAccessTests`, `PickupLayoutTests`, `PickupControllerTests`, `PackageOpeningPlayerTests`, `WheelReadyNotificationTests`; UI: `PrizesUITests`, `WheelUITests`; retocados: `AudioWiringTests`, `TutorialTipsTests`, `NotificationPlannerTests`, `NotificationsContentTests` | 1–6 |

## Orden, olas y paralelismo

| T | Qué | 🔥 calientes | Tibios / compartidos | Depende de |
|---|---|---|---|---|
| 1 | la ruleta en pantalla | — | `AudioManager`, `AudioWiringTests` (E4b T6, E3a T8), `HapticsManager`, `+Wheel`, catálogo (snapshot) | E5a T8; **E4b T3** (`RewardedOfferButton`, `VisitorFace`) |
| 2 | hojas y accesos | `GameState.swift`, `RootView.swift`, catálogo (dueño) | `+Rewards`, `StageChips` (E4b T3/T5), `DebugPanelView` (E2a T14, E3b, E4b) | T1; E5a T6–T8; **E4b T3, T4, T9** (dueños previos de `RootView`/`GameState.swift`); **E3a T6, T11** |
| 3 | la escena | `BoardScene.swift` | — | T2 (`prizeAccess`); **E1 T10**; **E4b T1** (`StageLayout`, ganchos), **T6, T9** (últimos en `BoardScene`); **E3a T10** |
| 4 | Regalos | — | `GiftsView` (E1 T14), catálogo (dueño o snapshot) | T1 |
| 5 | las lecciones | — | `+TutorialTips`, `TutorialAnchor` (E4b T3/T4/T8), `PrizeChips`, `+Prizes`, `TutorialTipsTests`, catálogo (snapshot) | T2, T4 |
| 6 | `wheel_ready` | — | `NotificationsConfig`, `NotificationPlanner`, `notifications.json`, `+Notifications`, `NotificationPlannerTests`, `NotificationsContentTests` (E11), `+Wheel`, catálogo (snapshot) | T1 (comparten `+Wheel`); **E11 T4, T6** |
| 7 | cierre | — | `Docs/` (controlador) | todas |

```
Ola 1                                           T1 la ruleta en pantalla
Ola 2 (caliente: GameState + RootView + catálogo)   T2 hojas y accesos  ║ T6 wheel_ready (snapshot)
Ola 3 (caliente: BoardScene)                    T3 la escena ║ T4 Regalos (dueña del catálogo)
Ola 4                                           T5 las lecciones
Ola 5                                           T7 cierre
```

**E4 ∥ E5 por tarea**: T2 no va en la misma ola que E4b T3, T4 o T9 (los tres tocan `RootView`)
ni que E4b T1/T4/T9 (`GameState.swift`); T3 no va con E4b T1, T6 o T9 (`BoardScene`). Lo demás
corre al lado. **El 🔒 de la columna de E7b no bloquea nada de E5b**: E5b no pone botones en la
columna (ver duda 1).

## Helpers de test que EXISTEN

Los de E5a, más:

| Necesidad | Qué usar | Dónde |
|---|---|---|
| paquetes, colchón y giros ya puestos | `debugAddPackages(_:)`, `debugSpawnMattress()`, `debugAddWheelSpins(_:)`, `debugWheelNewDay()`; fixtures `--uitest-packages=N`, `--uitest-mattress`, `--uitest-wheel-spins=N` | E5a T6–T8 |
| el escenario sin vista | `StageController(gameState:)` + `attach(to: SKNode())` + `update(delta:reduceMotion:)` | E4b T1 |
| Reduce Motion en un test de escena | `BoardScene.reduceMotionOverride` (DEBUG) | `BoardScene.swift:253` |
| el director de lecciones aislado | el `makeGameState()` privado de `TutorialTipsTests` (barre los defaults y prende `tutorialLessonsAutorun`), `markLessonDone(_:)`, `tutorialTipHandled(opening:)` | `TutorialTipsTests.swift:17-31`, `GameState+TutorialTips.swift` |
| los avisos sin `Date()` | `BuenosAires` (`at(_:_:)`) y el `plan(leavingAt:…)` privados de `NotificationPlannerTests` | `NotificationPlannerTests.swift:29-75` |
| esperas de UI | `waitForExistence`, `waitForNonExistence(timeout:)`; un elemento combinado se busca con `app.descendants(matching: .any)["id"]` | XCTest |
| el anuncio en UI tests | el stub (`StubAdsProvider`): bajo `--uitest*` todo video "se mira" en 2 s y paga | `AdsProvider.swift:88-104`, `AdsCoordinator.swift:112-136` |

---

### Task 1: La Ruleta en pantalla — `Canvas`, el giro que frena, el tic y la tabla a la vista

**Objetivo:** la pantalla de la ruleta (PLAN-v2 E5): el Conductor de TV la presenta; la rueda
tiene rebanadas iguales con el ícono y el número de cada premio, gira cinco vueltas con un
ease-out de `wheel.json` `spinSeconds` (3,8 s) y hace un tic (sonido + háptico) por rebanada que
pasa bajo el puntero; abajo, los botones (regalado, por video, con ORO donde la tienda lo
permite, "repetir premio" por video) y la tabla de probabilidades **que es la que gira**. El
premio ya se acreditó cuando la rueda arranca (`spinWheel`, E5a T8). La vista sirve empujada
(Regalos, T4) o sola (la hoja raíz, T2): quien la muestra decide qué hace `close`.

**Files:**
- Create: `FisuEvolution/UI/Wheel/WheelGeometry.swift`
- Create: `FisuEvolution/UI/Wheel/WheelCanvas.swift`
- Create: `FisuEvolution/UI/Wheel/WheelView.swift`
- Create: `FisuEvolution/UI/Art/OddsDisclosureView.swift`
- Create: `FisuEvolution/Managers/RewardCopy.swift`
- Modify: `FisuEvolution/Audio/AudioManager.swift` (`SFX.wheelTick`)
- Modify: `FisuEvolution/Managers/HapticsManager.swift` (`Pattern.tick`)
- Modify: `FisuEvolution/Game/State/GameState+Wheel.swift` (`playWheelTick()`)
- Modify: `FisuEvolutionTests/AudioWiringTests.swift` (`declaredCases`)
- Create: `FisuEvolutionTests/WheelGeometryTests.swift`, `FisuEvolutionTests/RewardCopyTests.swift`
- Strings: `Tools/v2/claves-pendientes/e5b-t1.json` (26 claves)

**Interfaces:**
- Consumes: E5a T8 (`wheelSegments`, `wheelOdds`, `wheelAvailability(storefrontAllows:)`,
  `spinWheel`, `repeatWheelPrize`, `WheelSpinOutcome`, `WheelAvailability`, `LootBoxGate.current()`,
  `content.wheel.spinSeconds`); **E4b T3** (`RewardedOfferButton(title:identifier:placement:onRewarded:)`,
  `VisitorFace(visitorId:side:)`).
- Produces: `enum WheelGeometry` (`Arc`, `arcs(count:)`, `pointerAngle(rotation:)`,
  `segmentIndex(at:count:)`, `stopRotation(from:arc:turns:landing:)`,
  `boundariesCrossed(from:to:count:)`, `easeOut(_:)`); `struct WheelSpinAnimation`
  (`outcome`, `from`, `to`, `start`, `duration`, `rotation(at:)`, `isFinished(at:)`);
  `WheelCanvas(segments:rotation:)`, `WheelPointer`, `WheelGlyph`; `WheelView(close:)`;
  `OddsDisclosureView(titleKey:rows:identifier:)` con `OddsDisclosureView.Row(id:title:symbol:probability:)`
  y `static func percent(_:)`; `enum RewardCopy` (`title(_:)`, `slice(_:)`, `symbol(_:)`,
  `text(_:_:)`); `AudioManager.SFX.wheelTick`, `HapticsManager.Pattern.tick`;
  `GameState.playWheelTick()`.
- Identificadores: `wheel.wheel`, `wheel.spin.bonus`, `wheel.spin.video`, `wheel.spin.oro`,
  `wheel.repeat`, `wheel.empty`, `wheel.result` (valor = id del segmento), `wheel.odds.<segmento>`.

- [ ] **Step 0: Lo de E4b y E5a está**

Run (uno por llamada):

```bash
grep -rn "struct RewardedOfferButton" FisuEvolution/UI
grep -rn "struct VisitorFace" FisuEvolution/UI
grep -n "func spinWheel\|func repeatWheelPrize\|func wheelAvailability" FisuEvolution/Game/State/GameState+Wheel.swift
grep -n "enum LootBoxGate" FisuEvolution/Managers/LootBoxGate.swift
```

Expected: una línea por comando. Si falta algo, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/WheelGeometryTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La ruleta: la geometría")
struct WheelGeometryTests {
    @Test("rebanadas iguales que dan la vuelta entera")
    func equalSlices() {
        let arcs = WheelGeometry.arcs(count: 10)
        #expect(arcs.count == 10)
        #expect(arcs.first?.start == 0)
        #expect(arcs.last?.end == 360)
        #expect(arcs.allSatisfy { abs($0.span - 36) < 1e-9 })
        #expect(WheelGeometry.arcs(count: 0).isEmpty)
    }

    @Test("el puntero cae adentro de la rebanada ganadora, lejos de la raya, después de cinco vueltas",
          arguments: [0.0, 0.5, 1.0])
    func theStopLandsInsideTheWinner(landing: Double) {
        for count in [9, 10] {
            let arcs = WheelGeometry.arcs(count: count)
            for from in [0.0, 123.4, 3_000] {
                for (index, arc) in arcs.enumerated() {
                    let stop = WheelGeometry.stopRotation(from: from, arc: arc, turns: 5, landing: landing)
                    #expect(stop >= from + 5 * 360 && stop < from + 6 * 360)
                    let angle = WheelGeometry.pointerAngle(rotation: stop)
                    #expect(WheelGeometry.segmentIndex(at: angle, count: count) == index)
                    #expect(angle - arc.start >= arc.span * 0.15 - 1e-6)
                    #expect(arc.end - angle >= arc.span * 0.15 - 1e-6)
                }
            }
        }
    }

    @Test("una vuelta entera hace un tic por rebanada")
    func oneTickPerSlice() {
        #expect(WheelGeometry.boundariesCrossed(from: 0, to: 360, count: 10) == 10)
        #expect(WheelGeometry.boundariesCrossed(from: 10, to: 30, count: 10) == 0)
        #expect(WheelGeometry.boundariesCrossed(from: 30, to: 40, count: 10) == 1)
        #expect(WheelGeometry.boundariesCrossed(from: 40, to: 30, count: 10) == 0)
    }

    @Test("frena como una rueda: arranca rápido y llega justo")
    func easeOut() {
        #expect(WheelGeometry.easeOut(0) == 0)
        #expect(WheelGeometry.easeOut(1) == 1)
        #expect(WheelGeometry.easeOut(0.5) > 0.8)
        #expect(WheelGeometry.easeOut(2) == 1)
    }

    @Test("la animación arranca donde estaba y termina donde dijo el sorteo")
    func theSpinAnimation() {
        let segment = WheelConfig.Segment(id: "x", weight: 100, reward: .oro(1))
        let outcome = WheelSpinOutcome(segments: [segment], index: 0, coins: 0)
        let start = Date(timeIntervalSince1970: 1000)
        let spin = WheelSpinAnimation(outcome: outcome, from: 10, to: 1900, start: start, duration: 3.8)
        #expect(spin.rotation(at: start) == 10)
        #expect(spin.rotation(at: start.addingTimeInterval(3.8)) == 1900)
        #expect(!spin.isFinished(at: start.addingTimeInterval(3.7)))
        #expect(spin.isFinished(at: start.addingTimeInterval(3.8)))
        #expect(spin.rotation(at: start.addingTimeInterval(1)) < spin.rotation(at: start.addingTimeInterval(2)))
    }
}
```

`FisuEvolutionTests/RewardCopyTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
import UIKit
@testable import FisuEvolution

@Suite("Cómo se dice un premio")
struct RewardCopyTests {
    /// Un ejemplo por tipo, con un `switch` SIN `default`: un tipo nuevo sin
    /// texto no compila (el mismo truco que `RewardSpecTests.sample` de E4a).
    static func sample(_ kind: RewardSpec.Kind) -> RewardSpec {
        switch kind {
        case .coinsSeconds: .coinsSeconds(1800)
        case .oro: .oro(3)
        case .package: .package(1)
        case .skinChest: .skinChest(2)
        case .modifier: .modifier(effect: .incomeMultiplier, magnitude: 3, seconds: 600)
        case .clearBoostCooldowns: .clearBoostCooldowns
        case .autoTap: .autoTap(perSecond: 5, seconds: 600)
        case .nextOfflineMultiplier: .nextOfflineMultiplier(3)
        case .nextDailyMultiplier: .nextDailyMultiplier(3)
        case .wheelSpin: .wheelSpin(2)
        case .extraSlots: .extraSlots(3)
        case .eventImmunity: .eventImmunity(seconds: 1800)
        }
    }

    @Test("todo premio tiene título e ícono, y ninguna clave cruda", arguments: RewardSpec.Kind.allCases)
    func everyKindHasCopy(kind: RewardSpec.Kind) {
        let reward = Self.sample(kind)
        let title = RewardCopy.title(reward)
        #expect(!title.isEmpty)
        #expect(!title.contains("reward."), "\(kind): «\(title)» es la clave cruda")
        #expect(!title.contains("%"), "\(kind): «\(title)» quedó sin interpolar")
        #expect(UIImage(systemName: RewardCopy.symbol(reward)) != nil, "\(kind): el ícono no existe")
    }

    @Test("los minutos y los números salen del dato")
    func numbersComeFromTheData() {
        #expect(RewardCopy.title(.coinsSeconds(1800)).contains("30"))
        #expect(RewardCopy.title(.oro(3)).contains("3"))
        #expect(RewardCopy.slice(.coinsSeconds(2700)) == "45 min")
        #expect(RewardCopy.slice(.modifier(effect: .incomeMultiplier, magnitude: 3, seconds: 600)) == "×3")
        #expect(RewardCopy.slice(.oro(3)) == "3")
        #expect(RewardCopy.slice(.package(1)) == nil, "el paquete se dice con el ícono")
    }

    @Test("los porcentajes no inventan decimales")
    func percents() {
        #expect(OddsDisclosureView.percent(0.18).contains("18"))
        #expect(!OddsDisclosureView.percent(0.18).contains("18,0") && !OddsDisclosureView.percent(0.18).contains("18.0"))
    }
}
```

En `FisuEvolutionTests/AudioWiringTests.swift`, `declaredCases` suma `"wheelTick"` al final.

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/WheelGeometryTests -only-testing:FisuEvolutionTests/RewardCopyTests -only-testing:FisuEvolutionTests/AudioWiringTests`.
Expected: no compila (`WheelGeometry`, `RewardCopy` no existen).

- [ ] **Step 3: La geometría y la copia**

`FisuEvolution/UI/Wheel/WheelGeometry.swift`:

```swift
import EconomyKit
import Foundation

/// La geometría de la ruleta, pura. Las rebanadas son iguales —la tabla de
/// probabilidades va abajo, a la vista—, el puntero está arriba y la rueda gira
/// en sentido horario. Los ángulos van en grados, desde arriba, horarios.
enum WheelGeometry {
    struct Arc: Equatable {
        let start: Double
        let end: Double
        var mid: Double { (start + end) / 2 }
        var span: Double { end - start }
    }

    static func arcs(count: Int) -> [Arc] {
        guard count > 0 else { return [] }
        let span = 360 / Double(count)
        return (0..<count).map { Arc(start: Double($0) * span, end: Double($0 + 1) * span) }
    }

    /// El ángulo de la rueda que queda bajo el puntero con la rueda girada
    /// `rotation` grados.
    static func pointerAngle(rotation: Double) -> Double {
        let angle = (-rotation).truncatingRemainder(dividingBy: 360)
        return angle < 0 ? angle + 360 : angle
    }

    static func segmentIndex(at angle: Double, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return min(count - 1, Int(angle / (360 / Double(count))))
    }

    /// La rotación final para que el puntero caiga dentro de `arc` después de
    /// por lo menos `turns` vueltas. `landing` ∈ [0, 1] elige el punto adentro
    /// del 70 % del medio: nunca sobre la raya, que se lee como "casi".
    static func stopRotation(from current: Double, arc: Arc, turns: Int, landing: Double) -> Double {
        let inside = arc.start + arc.span * (0.15 + 0.7 * min(max(landing, 0), 1))
        let target = (360 - inside).truncatingRemainder(dividingBy: 360)
        let minimum = current + Double(turns) * 360
        var delta = target - minimum.truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        return minimum + delta
    }

    /// Cuántas rayas pasan bajo el puntero entre dos rotaciones: el ritmo del tic.
    static func boundariesCrossed(from: Double, to: Double, count: Int) -> Int {
        guard count > 0, to > from else { return 0 }
        let span = 360 / Double(count)
        return Int(floor(to / span)) - Int(floor(from / span))
    }

    /// Frena como una rueda de verdad: rápido al principio, despacio al final.
    static func easeOut(_ progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        return 1 - pow(1 - t, 3)
    }
}

/// Un giro en pantalla. El premio ya está acreditado: esto es el espectáculo.
struct WheelSpinAnimation: Equatable {
    let outcome: WheelSpinOutcome
    let from: Double
    let to: Double
    let start: Date
    let duration: TimeInterval

    func rotation(at date: Date) -> Double {
        guard duration > 0 else { return to }
        return from + (to - from) * WheelGeometry.easeOut(date.timeIntervalSince(start) / duration)
    }

    func isFinished(at date: Date) -> Bool {
        date.timeIntervalSince(start) >= duration
    }
}
```

`FisuEvolution/Managers/RewardCopy.swift`:

```swift
import EconomyKit
import Foundation

/// Cómo se dice un premio (`RewardSpec`) en pantalla: la ruleta, el colchón y,
/// después, la tienda y las ofertas (E6). Los números se interpolan del dato,
/// nunca se escriben en el texto (la regla de `IAPCopy`, HANDOFF §5): el valor
/// del catálogo lleva `%1$@` y esto lo llena.
enum RewardCopy {
    /// Lo que se lee en una fila de probabilidades o en un resultado.
    static func title(_ reward: RewardSpec) -> String {
        switch reward {
        case .coinsSeconds(let seconds):
            text("reward.title.coins", minutes(seconds))
        case let .modifier(effect, magnitude, seconds):
            text(effect == .incomeMultiplier ? "reward.title.income" : "reward.title.modifier",
                 multiplier(magnitude), minutes(seconds))
        case .oro(let amount):
            text("reward.title.oro", String(amount))
        case .package(let count):
            count == 1 ? text("reward.title.package") : text("reward.title.packages", String(count))
        case .skinChest(let count):
            count == 1 ? text("reward.title.chest") : text("reward.title.chests", String(count))
        case .wheelSpin(let count):
            count == 1 ? text("reward.title.spin") : text("reward.title.spins", String(count))
        case .clearBoostCooldowns:
            text("reward.title.cooldowns")
        case .eventImmunity(let seconds):
            text("reward.title.immunity", minutes(seconds))
        case let .autoTap(_, seconds):
            text("reward.title.autotap", minutes(seconds))
        case .nextOfflineMultiplier(let value):
            text("reward.title.next_offline", multiplier(value))
        case .nextDailyMultiplier(let value):
            text("reward.title.next_daily", multiplier(value))
        case .extraSlots(let count):
            text("reward.title.slots", String(count))
        }
    }

    /// Lo que entra en una rebanada de la ruleta, al lado del ícono. `nil`:
    /// el ícono solo alcanza.
    static func slice(_ reward: RewardSpec) -> String? {
        switch reward {
        case .coinsSeconds(let seconds): "\(minutes(seconds)) min"
        case let .modifier(_, magnitude, _): "×\(multiplier(magnitude))"
        case .oro(let amount): String(amount)
        case .package, .skinChest, .wheelSpin, .clearBoostCooldowns, .eventImmunity, .autoTap,
             .nextOfflineMultiplier, .nextDailyMultiplier, .extraSlots: nil
        }
    }

    /// El ícono (SF Symbols) de cada tipo.
    static func symbol(_ reward: RewardSpec) -> String {
        switch reward {
        case .coinsSeconds: "dollarsign.circle.fill"
        case .modifier: "chart.line.uptrend.xyaxis"
        case .oro: "seal.fill"
        case .package: "shippingbox.fill"
        case .skinChest: "gift.fill"
        case .wheelSpin: "arrow.clockwise.circle.fill"
        case .clearBoostCooldowns: "bolt.fill"
        case .eventImmunity: "cross.case.fill"
        case .autoTap: "hand.tap.fill"
        case .nextOfflineMultiplier: "moon.zzz.fill"
        case .nextDailyMultiplier: "calendar"
        case .extraSlots: "square.grid.3x3.fill"
        }
    }

    /// Una clave del catálogo con sus `%1$@`, `%2$@` llenos.
    static func text(_ key: String, _ arguments: String...) -> String {
        let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    private static func minutes(_ seconds: Double) -> String {
        (seconds / 60).formatted(.number.precision(.fractionLength(0...1)))
    }

    private static func multiplier(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
```

`FisuEvolution/UI/Art/OddsDisclosureView.swift`:

```swift
import SwiftUI

/// Las probabilidades a la vista (Apple 3.1.1): la ruleta, el colchón y —en E6—
/// el cofre por ORO las muestran con esto, y siempre es la tabla con la que se
/// sortea.
struct OddsDisclosureView: View {
    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let symbol: String
        let probability: Double
    }

    let titleKey: LocalizedStringKey
    let rows: [Row]
    let identifier: String

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(titleKey)
                    .font(Tokens.caption)
                    .foregroundStyle(Color("PaletteInk").opacity(0.7))
                ForEach(rows) { row in
                    HStack(spacing: Tokens.s8) {
                        Image(systemName: row.symbol)
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 22)
                        Text(verbatim: row.title)
                            .font(Tokens.body)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: Tokens.s8)
                        Text(verbatim: Self.percent(row.probability))
                            .font(Tokens.body)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color("PaletteInk"))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("\(identifier).\(row.id)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "18 %", "2,5 %": sin decimales de más.
    static func percent(_ probability: Double) -> String {
        probability.formatted(.percent.precision(.fractionLength(0...1)))
    }
}
```

- [ ] **Step 4: El tic**

`AudioManager.swift`, en `enum SFX`, después de `chestShakeB`:

```swift
        /// El tic de cada rebanada de la ruleta que pasa bajo el puntero.
        case wheelTick = "sfx_wheel_tick"
```

`HapticsManager.swift`: `case tick` en `enum Pattern` y, en el `switch pattern` de `makePattern`:

```swift
        case .tick:
            [transient(time: 0, intensity: 0.35, sharpness: 0.9)]
```

`GameState+Wheel.swift` (E5a T8), al final de la extensión (fuera del `#if DEBUG`):

```swift
    /// El tic de una rebanada que pasa bajo el puntero: el sonido y una
    /// vibración corta. El ritmo lo marca la vista (`WheelGeometry.boundariesCrossed`);
    /// el anti-duplicado de `AudioManager` evita la ametralladora al arrancar.
    func playWheelTick() {
        audio?.play(.wheelTick)
        haptics?.play(.tick)
    }
```

- [ ] **Step 5: La rueda**

`FisuEvolution/UI/Wheel/WheelCanvas.swift`:

```swift
import EconomyKit
import SwiftUI

/// La rueda dibujada: rebanadas iguales alternando los colores de la casa, el
/// ícono y el número de cada premio, el aro y el centro. `rotation` en grados,
/// sentido horario.
struct WheelCanvas: View {
    let segments: [WheelConfig.Segment]
    let rotation: Double

    static let palette = ["PaletteYellow", "PaletteGreen", "PaletteOrange", "PaletteBlue", "PalettePink"]

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: .degrees(rotation))
            for (index, arc) in WheelGeometry.arcs(count: segments.count).enumerated() {
                var wedge = Path()
                wedge.move(to: .zero)
                wedge.addArc(center: .zero, radius: radius * 0.92,
                             startAngle: .degrees(arc.start - 90), endAngle: .degrees(arc.end - 90), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(Color(Self.palette[index % Self.palette.count])))
                context.stroke(wedge, with: .color(Color("PaletteInk").opacity(0.55)), lineWidth: 1.5)

                var label = context
                label.rotate(by: .degrees(arc.mid))
                let reward = segments[index].reward
                var icon = label.resolve(Image(systemName: RewardCopy.symbol(reward)))
                icon.shading = .color(Color("PaletteInk"))
                let iconSide = radius * 0.16
                label.draw(icon, in: CGRect(x: -iconSide / 2, y: -radius * 0.70 - iconSide / 2,
                                            width: iconSide, height: iconSide))
                if let text = RewardCopy.slice(reward) {
                    label.draw(
                        Text(verbatim: text)
                            .font(.system(size: radius * 0.10, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color("PaletteInk")),
                        at: CGPoint(x: 0, y: -radius * 0.47)
                    )
                }
            }
            let rim = Path(ellipseIn: CGRect(x: -radius * 0.96, y: -radius * 0.96, width: radius * 1.92, height: radius * 1.92))
            context.stroke(rim, with: .color(Color("PaletteBrown")), lineWidth: radius * 0.08)
            let hub = Path(ellipseIn: CGRect(x: -radius * 0.14, y: -radius * 0.14, width: radius * 0.28, height: radius * 0.28))
            context.fill(hub, with: .color(Color("PaletteCream")))
            context.stroke(hub, with: .color(Color("PaletteInk")), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }
}

/// El puntero de arriba.
struct WheelPointer: View {
    var body: some View {
        PointerShape()
            .fill(Color("PaletteOrange"))
            .overlay(PointerShape().stroke(Color("PaletteInk"), lineWidth: 2))
            .accessibilityHidden(true)
    }

    private struct PointerShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

/// La ruleta en chiquito, para tarjetas y chips, mientras no llegue `wheel_icon` (E8).
struct WheelGlyph: View {
    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            context.translateBy(x: size.width / 2, y: size.height / 2)
            for (index, arc) in WheelGeometry.arcs(count: 8).enumerated() {
                var wedge = Path()
                wedge.move(to: .zero)
                wedge.addArc(center: .zero, radius: radius * 0.9,
                             startAngle: .degrees(arc.start - 90), endAngle: .degrees(arc.end - 90), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(Color(WheelCanvas.palette[index % WheelCanvas.palette.count])))
            }
            let rim = Path(ellipseIn: CGRect(x: -radius * 0.9, y: -radius * 0.9, width: radius * 1.8, height: radius * 1.8))
            context.stroke(rim, with: .color(Color("PaletteInk")), lineWidth: max(1.5, radius * 0.1))
        }
        .accessibilityHidden(true)
    }
}
```

`FisuEvolution/UI/Wheel/WheelView.swift`:

```swift
import EconomyKit
import SwiftUI

/// La Ruleta (PLAN-v2 E5): la presenta el Conductor de TV, gira con un frenado
/// de `wheel.json` `spinSeconds` y un tic por rebanada, y la tabla de
/// probabilidades está a la vista, debajo (Apple 3.1.1). El premio ya se
/// acreditó cuando la rueda arranca (`spinWheel`).
///
/// Se empuja desde Regalos o se presenta sola (`GameState.wheelSheet`): quien
/// la muestra decide qué hace `close`.
struct WheelView: View {
    let close: () -> Void

    @Environment(GameState.self) private var gameState
    @Environment(AdsCoordinator.self) private var ads
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var storefrontAllows = false
    @State private var resting: Double = 0
    @State private var spin: WheelSpinAnimation?
    @State private var lastTick: Double = 0
    @State private var result: WheelSpinOutcome?

    /// Quien presenta la ruleta (PLAN-v2 §2).
    private static let hostVisitorId = "npc_conductor"
    private static let wheelSide: CGFloat = 300
    private static let turns = 5

    var body: some View {
        let _ = gameState.effectsVersion
        let availability = gameState.wheelAvailability(storefrontAllows: storefrontAllows)
        let segments = spin?.outcome.segments ?? result?.segments ?? gameState.wheelSegments
        ScrollView {
            VStack(spacing: Tokens.s16) {
                host
                wheel(segments: segments)
                if let result, spin == nil {
                    resultCard(result)
                }
                buttons(availability)
                OddsDisclosureView(titleKey: "wheel.odds.title", rows: oddsRows, identifier: "wheel.odds")
            }
            .padding(.horizontal, WoodPanelBackground.columnInset)
            .padding(.top, Tokens.s12)
            .padding(.bottom, Tokens.s24)
        }
        .panelSheet { PanelTitleBanner(titleKey: "wheel.title") }
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ArtCloseButton(action: close) }
        }
        .task {
            ads.preloadRewarded(for: .wheel)
            storefrontAllows = await LootBoxGate.current()
        }
    }

    private var host: some View {
        HStack(spacing: Tokens.s12) {
            VisitorFace(visitorId: Self.hostVisitorId, side: 56)
            Text("wheel.host.line")
                .font(Tokens.body)
                .foregroundStyle(Color("PaletteInk"))
                .padding(Tokens.s8)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Color("PaletteCream"))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                )
            Spacer(minLength: 0)
        }
    }

    private func wheel(segments: [WheelConfig.Segment]) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: spin == nil)) { context in
            WheelCanvas(segments: segments, rotation: spin?.rotation(at: context.date) ?? resting)
                .frame(width: Self.wheelSide, height: Self.wheelSide)
                .overlay(alignment: .top) {
                    WheelPointer()
                        .frame(width: 28, height: 34)
                        .offset(y: -10)
                }
                .onChange(of: context.date) { _, date in advance(to: date) }
        }
        .frame(height: Self.wheelSide + 12)
        .accessibilityElement()
        .accessibilityIdentifier("wheel.wheel")
        .accessibilityValue(Text(verbatim: spin == nil ? "idle" : "spinning"))
    }

    @ViewBuilder
    private func buttons(_ availability: WheelAvailability) -> some View {
        VStack(spacing: Tokens.s8) {
            if spin != nil {
                StateBadge(text: String(localized: "wheel.spinning"), systemImage: "hourglass",
                           textAlignment: .center, muted: true)
            } else {
                if availability.bonus > 0 {
                    ActionPill(titleKey: "wheel.spin.bonus", systemImage: "gift.fill",
                               tint: Color("PaletteGreen"), identifier: "wheel.spin.bonus") { start(.bonus) }
                } else if availability.videoLeft > 0 {
                    RewardedOfferButton(
                        title: RewardCopy.text("wheel.spin.video", String(availability.videoLeft)),
                        identifier: "wheel.spin.video",
                        placement: .wheel
                    ) { start(.video) }
                } else {
                    StateBadge(text: String(localized: "wheel.empty"), systemImage: "moon.zzz.fill",
                               textAlignment: .center, muted: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("wheel.empty")
                }
                if availability.oroLeft > 0 {
                    PricePill(text: String(availability.oroCost), currency: .oro, affordable: availability.canPayOro,
                              identifier: "wheel.spin.oro", accessibilityPurpose: Text("wheel.spin.oro.ax")) {
                        if availability.canPayOro { start(.oro) }
                    }
                }
                if availability.canRepeat, result != nil {
                    RewardedOfferButton(title: String(localized: "wheel.repeat"), identifier: "wheel.repeat",
                                        placement: .wheel) { repeatPrize() }
                }
            }
        }
    }

    private func resultCard(_ outcome: WheelSpinOutcome) -> some View {
        let reward = outcome.segment.reward
        let text = outcome.coins > 0 ? "+\(CoinFormatter.string(from: outcome.coins))" : RewardCopy.title(reward)
        return GameCard(style: .highlighted(Color("PaletteYellow"))) {
            HStack(spacing: Tokens.s8) {
                Image(systemName: RewardCopy.symbol(reward))
                    .font(.system(size: 26, weight: .heavy))
                VStack(alignment: .leading, spacing: 2) {
                    Text("wheel.result.title")
                        .font(Tokens.caption)
                    Text(verbatim: text)
                        .font(Tokens.title)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color("PaletteInk"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wheel.result")
        .accessibilityValue(Text(verbatim: outcome.segment.id))
    }

    private var oddsRows: [OddsDisclosureView.Row] {
        zip(gameState.wheelSegments, gameState.wheelOdds).map { segment, odds in
            OddsDisclosureView.Row(
                id: segment.id, title: RewardCopy.title(segment.reward),
                symbol: RewardCopy.symbol(segment.reward), probability: odds.probability
            )
        }
    }

    // MARK: El giro

    private func start(_ source: WheelSpinSource) {
        guard spin == nil, let outcome = gameState.spinWheel(source, storefrontAllows: storefrontAllows) else { return }
        result = nil
        let arcs = WheelGeometry.arcs(count: outcome.segments.count)
        let target = WheelGeometry.stopRotation(from: resting, arc: arcs[outcome.index], turns: Self.turns,
                                                landing: .random(in: 0...1))
        guard !reduceMotion else {
            resting = target.truncatingRemainder(dividingBy: 360)
            result = outcome
            return
        }
        lastTick = resting
        spin = WheelSpinAnimation(outcome: outcome, from: resting, to: target, start: .now,
                                  duration: gameState.content?.wheel.spinSeconds ?? 0)
    }

    private func advance(to date: Date) {
        guard let spin else { return }
        let rotation = spin.rotation(at: date)
        if WheelGeometry.boundariesCrossed(from: lastTick, to: rotation, count: spin.outcome.segments.count) > 0 {
            gameState.playWheelTick()
        }
        lastTick = rotation
        guard spin.isFinished(at: date) else { return }
        resting = spin.to.truncatingRemainder(dividingBy: 360)
        result = spin.outcome
        self.spin = nil
    }

    private func repeatPrize() {
        guard spin == nil, let outcome = gameState.repeatWheelPrize() else { return }
        result = outcome
    }
}
```

- [ ] **Step 6: Los textos**

`Tools/v2/claves-pendientes/e5b-t1.json`:

```json
{
  "reward.title.coins": {"es": "%1$@ min de producción", "en": "%1$@ min of production"},
  "reward.title.income": {"es": "Ingresos ×%1$@ por %2$@ min", "en": "Income ×%1$@ for %2$@ min"},
  "reward.title.modifier": {"es": "×%1$@ por %2$@ min", "en": "×%1$@ for %2$@ min"},
  "reward.title.oro": {"es": "%1$@ de ORO", "en": "%1$@ ORO"},
  "reward.title.package": {"es": "Un Paquete de la Aduana", "en": "A Customs Package"},
  "reward.title.packages": {"es": "%1$@ Paquetes de la Aduana", "en": "%1$@ Customs Packages"},
  "reward.title.chest": {"es": "Un cofre de pintas", "en": "A skin chest"},
  "reward.title.chests": {"es": "%1$@ cofres de pintas", "en": "%1$@ skin chests"},
  "reward.title.spin": {"es": "Un giro de la ruleta", "en": "A wheel spin"},
  "reward.title.spins": {"es": "%1$@ giros de la ruleta", "en": "%1$@ wheel spins"},
  "reward.title.cooldowns": {"es": "Los boosts, sin esperar", "en": "Boosts, no waiting"},
  "reward.title.immunity": {"es": "Inmune a los eventos por %1$@ min", "en": "Immune to events for %1$@ min"},
  "reward.title.autotap": {"es": "Toques automáticos por %1$@ min", "en": "Auto-taps for %1$@ min"},
  "reward.title.next_offline": {"es": "La próxima vuelta, ×%1$@", "en": "Your next return, ×%1$@"},
  "reward.title.next_daily": {"es": "El próximo diario, ×%1$@", "en": "Your next daily, ×%1$@"},
  "reward.title.slots": {"es": "+%1$@ lugares por piso", "en": "+%1$@ slots per floor"},
  "wheel.title": {"es": "La Ruleta", "en": "The Wheel"},
  "wheel.host.line": {"es": "¡Y ahora… el momento que todos esperaban… LA RULETA!", "en": "And now… the moment you've all been waiting for… THE WHEEL!"},
  "wheel.spin.bonus": {"es": "¡Girar gratis!", "en": "Free spin!"},
  "wheel.spin.video": {"es": "Girar con un video (quedan %1$@)", "en": "Spin with a video (%1$@ left)"},
  "wheel.spin.oro.ax": {"es": "Girar la ruleta", "en": "Spin the wheel"},
  "wheel.repeat": {"es": "Repetir el premio con un video", "en": "Repeat the prize with a video"},
  "wheel.spinning": {"es": "Girando…", "en": "Spinning…"},
  "wheel.empty": {"es": "Por hoy no quedan giros. Mañana hay más.", "en": "No spins left today. More tomorrow."},
  "wheel.result.title": {"es": "¡Te tocó!", "en": "You got:"},
  "wheel.odds.title": {"es": "Lo que puede tocar", "en": "What you can get"}
}
```

Run: `Tools/v2/catalogo.py aplicar Tools/v2/claves-pendientes/e5b-t1.json` → `26 claves nuevas`.

- [ ] **Step 7: Verde, a mano y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/WheelGeometryTests -only-testing:FisuEvolutionTests/RewardCopyTests -only-testing:FisuEvolutionTests/AudioWiringTests -only-testing:FisuEvolutionTests/AudioManagerTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests`
→ PASS (5 + 3 nuevos, uno con 12 argumentos). A mano: la ruleta todavía no tiene entrada (la da T2/T4); se mira con un
`#Preview` local que no se commitea, o se adelanta con T4 en el mismo simulador. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/UI/Wheel/WheelGeometry.swift
git add FisuEvolution/UI/Wheel/WheelCanvas.swift
git add FisuEvolution/UI/Wheel/WheelView.swift
git add FisuEvolution/UI/Art/OddsDisclosureView.swift
git add FisuEvolution/Managers/RewardCopy.swift
git add FisuEvolution/Audio/AudioManager.swift
git add FisuEvolution/Managers/HapticsManager.swift
git add FisuEvolution/Game/State/GameState+Wheel.swift
git add FisuEvolutionTests/AudioWiringTests.swift
git add FisuEvolutionTests/WheelGeometryTests.swift
git add FisuEvolutionTests/RewardCopyTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e5b-t1.json, según la ola
git diff --cached --stat
git commit -m "feat(ruleta): la Ruleta en pantalla — el giro que frena, el tic y la tabla a la vista"
```

---

### Task 2: Los accesos y las hojas — chips, el popup del colchón y la ruleta sobre el tablero

**Objetivo:** que el paquete y el colchón se toquen desde un chip bajo el HUD (al lado del
visitante, en `StageChips`), que el colchón tenga su popup (lo que puede tocar a la vista, "abrir
con video", lo que salió y "otro colchón"), que la ruleta se pueda presentar sola sobre el
tablero, y que el Conductor de TV la abra al irse (su giro regalado). Todo lee una proyección,
`GameState.prizeAccess`, que es la que va a leer la columna de E7b. Es la única tarea de E5 con
`GameState.swift` y `RootView.swift`.

**Files:**
- Create: `FisuEvolution/Game/State/PrizeAccess.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` (🔥: tres proyecciones, una bandera, una línea en `refreshProjections`)
- Create: `FisuEvolution/Game/State/GameState+Prizes.swift`
- Modify: `FisuEvolution/Game/State/GameState+Rewards.swift` (el caso `.wheelSpin` de `grant`)
- Create: `FisuEvolution/UI/Prizes/PrizeChips.swift`
- Modify: `FisuEvolution/UI/Visitors/StageChips.swift` (E4b T3)
- Create: `FisuEvolution/UI/Prizes/MattressPopupView.swift`
- Modify: `FisuEvolution/App/RootView.swift` (🔥)
- Modify: `FisuEvolution/UI/DebugPanelView.swift`
- Create: `FisuEvolutionTests/PrizeAccessTests.swift`, `FisuEvolutionUITests/PrizesUITests.swift`
- Strings: el catálogo (dueña en su ola) o `Tools/v2/claves-pendientes/e5b-t2.json` (10 claves)

**Interfaces:**
- Consumes: T1 (`WheelView`, `OddsDisclosureView`, `RewardCopy`); E5a T6–T8; **E4b T3**
  (`StageChips`, `visitorPopup`, `coversBoard`, `RewardedOfferButton`), **T4** (`eventPopup` en
  `coversBoard`); **E3a T6** (`fisuSheet()`).
- Produces: `struct PrizeAccess: Equatable` (`packagesWaiting`, `packagesBlocked`,
  `mattressReady`, `wheelSpinsReady`, `static let none`); `struct MattressPopup: Identifiable, Equatable`
  (`id`, `outcome: MattressOutcome?`); `struct WheelSheet: Identifiable, Equatable`;
  `GameState.prizeAccess`, `mattressPopup`, `wheelSheet` (observados),
  `wheelOpensAfterVisit` (`@ObservationIgnored`); `refreshPrizeAccess(now:)`,
  `packageTapped() -> PackageOpenResult` (`@discardableResult`), `mattressTapped()`,
  `mattressVideoWatched()`, `extraMattressVideoWatched()`, `closeMattressPopup()`, `openWheel()`,
  `closeWheel()`, `visitorPopupDismissed()`; `PackageChip`, `MattressChip`, `PackageGlyph`,
  `MattressGlyph`; `MattressPopupView`.
- Identificadores: `prize.chip.package` (valor: cuántos, o `full`), `prize.chip.mattress`,
  `mattress.open`, `mattress.extra`, `mattress.collect`, `mattress.result` (valor = id del
  premio), `mattress.odds.<premio>`, `debug.prizes.package`, `debug.prizes.mattress`,
  `debug.prizes.spins`, `debug.prizes.newday`.

- [ ] **Step 0: Los dueños previos de los calientes cerraron**

Run (uno por llamada):

```bash
grep -n "struct StageChips" FisuEvolution/UI/Visitors/StageChips.swift
grep -n "private var coversBoard" FisuEvolution/App/RootView.swift
grep -n "var visitorPopup\|var eventPopup" FisuEvolution/Game/State/GameState.swift
grep -n "func fisuSheet" FisuEvolution/UI/Art/PanelFrames.swift
```

Expected: una línea por comando (E4b T3/T4 y E3a T6 entraron). Si falta algo, `NEEDS_CONTEXT`.
Si `fisuSheet` cambió de forma por el plan B de S1, se usa la que haya en los dos lugares de
abajo y se anota.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/PrizeAccessTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Los accesos al Paquete, el Colchón y la Ruleta")
@MainActor
struct PrizeAccessTests {
    @Test("publica cuántos paquetes, si están trabados, si hay colchón y cuántos giros sin pagar")
    func publishes() async {
        let gameState = await makeGameState()
        gameState.refreshProjections()
        #expect(gameState.prizeAccess == PrizeAccess(packagesWaiting: 0, packagesBlocked: false, mattressReady: false, wheelSpinsReady: 6))
        gameState.debugAddPackages(2)
        gameState.debugSpawnMattress()
        gameState.debugAddWheelSpins(1)
        gameState.refreshProjections()
        #expect(gameState.prizeAccess == PrizeAccess(packagesWaiting: 2, packagesBlocked: false, mattressReady: true, wheelSpinsReady: 7))
    }

    @Test("tocar el paquete lo abre y el acceso se actualiza en el acto")
    func tappingAPackage() async {
        let gameState = await makeGameState()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        guard case .opened = gameState.packageTapped() else {
            Issue.record("el paquete no se abrió")
            return
        }
        #expect(gameState.prizeAccess.packagesWaiting == 0)
    }

    @Test("el colchón: el popup, el video, lo que salió y otro más")
    func theMattressFlow() async throws {
        let gameState = await makeGameState()
        gameState.mattressTapped()
        #expect(gameState.mattressPopup == nil, "sin colchón no hay popup")
        gameState.debugSpawnMattress()
        gameState.mattressTapped()
        #expect(gameState.mattressPopup?.outcome == nil)
        gameState.mattressVideoWatched()
        let first = try #require(gameState.mattressPopup?.outcome)
        #expect(first.extraOpensLeft == 1)
        #expect(!gameState.prizeAccess.mattressReady)
        gameState.extraMattressVideoWatched()
        #expect(gameState.mattressPopup?.outcome?.extraOpensLeft == 0)
        gameState.closeMattressPopup()
        #expect(gameState.mattressPopup == nil)
    }

    @Test("el giro que regala un visitante abre la ruleta cuando su popup se va; los demás, no")
    func theHostOpensTheWheel() async {
        let gameState = await makeGameState()
        gameState.grant(.wheelSpin(1), source: "treasure.test")
        gameState.visitorPopupDismissed()
        #expect(gameState.wheelSheet == nil)
        gameState.grant(.wheelSpin(1), source: "visit.conductor_ruleta")
        gameState.visitorPopupDismissed()
        #expect(gameState.wheelSheet != nil)
        gameState.closeWheel()
        gameState.visitorPopupDismissed()
        #expect(gameState.wheelSheet == nil, "se abre una vez por giro regalado")
    }

    @Test("la ruleta y el colchón no se pisan")
    func oneSheetAtATime() async {
        let gameState = await makeGameState()
        gameState.debugSpawnMattress()
        gameState.openWheel()
        gameState.mattressTapped()
        #expect(gameState.mattressPopup == nil)
        gameState.closeWheel()
        gameState.mattressTapped()
        gameState.openWheel()
        #expect(gameState.wheelSheet == nil)
    }
}
```

`FisuEvolutionUITests/PrizesUITests.swift`:

```swift
import XCTest

/// El paquete y el colchón se tocan desde sus chips (PLAN-v2 E5). El video del
/// colchón lo pone el stub de anuncios: 2 s y paga.
final class PrizesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAPackageBringsAWorker() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-packages=1"]
        app.launch()

        let units = app.otherElements["board.units"]
        XCTAssertTrue(units.waitForExistence(timeout: 15))
        let before = Int(units.value as? String ?? "") ?? 0
        let chip = app.buttons["prize.chip.package"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.value as? String, "1")
        chip.tap()

        expectation(for: NSPredicate(format: "value == %@", String(before + 1)), evaluatedWith: units)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(chip.waitForNonExistence(timeout: 3), "con el buzón vacío el chip se va")
    }

    func testTheMattressOpensWithAVideo() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-mattress"]
        app.launch()

        let chip = app.buttons["prize.chip.mattress"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()

        XCTAssertTrue(app.descendants(matching: .any)["mattress.odds.coins"].waitForExistence(timeout: 5),
                      "lo que puede tocar está a la vista antes del video")
        app.buttons["mattress.open"].tap()
        let result = app.descendants(matching: .any)["mattress.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(["coins", "package", "oro"].contains(result.value as? String ?? ""))

        let extra = app.buttons["mattress.extra"]
        XCTAssertTrue(extra.waitForExistence(timeout: 3))
        extra.tap()
        XCTAssertTrue(extra.waitForNonExistence(timeout: 8), "otro colchón es uno solo")
        app.buttons["mattress.collect"].tap()
        XCTAssertTrue(chip.waitForNonExistence(timeout: 5), "abierto, el colchón se va")
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/PrizeAccessTests`.
Expected: no compila (`PrizeAccess` no existe).

- [ ] **Step 3: El estado**

`FisuEvolution/Game/State/PrizeAccess.swift`:

```swift
import Foundation

/// Lo que dicen los accesos a los premios —los chips de hoy, la columna lateral
/// de E7b—: cuántos paquetes esperan, si ninguno entra, si hay colchón y
/// cuántos giros hay sin pagar. Publicado a 8 Hz porque `player` no se observa.
struct PrizeAccess: Equatable {
    var packagesWaiting = 0
    var packagesBlocked = false
    var mattressReady = false
    var wheelSpinsReady = 0

    static let none = PrizeAccess()
}

/// El popup del colchón; `outcome` es lo que salió, cuando ya se abrió.
struct MattressPopup: Identifiable, Equatable {
    let id = UUID()
    var outcome: MattressOutcome?
}

/// La ruleta presentada sobre el tablero (un chip, la columna, el Conductor).
/// Desde Regalos se empuja y no pasa por acá.
struct WheelSheet: Identifiable, Equatable {
    let id = UUID()
}
```

`GameState.swift` (🔥, cuatro toques):

1. En las proyecciones observadas, después de las del escenario de E4b (`stageChallenge`):

```swift
    /// Los accesos a paquetes, colchón y ruleta. Lo escribe `+Prizes`.
    var prizeAccess = PrizeAccess.none
    /// El popup del colchón (`+Prizes`).
    var mattressPopup: MattressPopup?
    /// La ruleta presentada sola (`+Prizes`).
    var wheelSheet: WheelSheet?
```

2. En "Authoritative state", junto a las otras banderas `@ObservationIgnored`:

```swift
    /// Un visitante regaló un giro: la ruleta se abre al cerrarse su popup.
    @ObservationIgnored var wheelOpensAfterVisit = false
```

3. En `refreshProjections()`, justo antes de `refreshTutorialTip()`:

```swift
        refreshPrizeAccess()
```

`FisuEvolution/Game/State/GameState+Prizes.swift`:

```swift
import EconomyKit
import Foundation

/// Los accesos al Paquete, al Colchón y a la Ruleta (PLAN-v2 E5): qué dicen y
/// qué hacen al tocarlos. Los tocan los chips, las cajas del tablero y —con
/// E7b— la columna lateral, todos por acá.
extension GameState {
    func refreshPrizeAccess(now: TimeInterval = Date().timeIntervalSince1970) {
        let wheel = wheelAvailability(storefrontAllows: false, now: now)
        let access = PrizeAccess(
            packagesWaiting: packagesWaiting,
            packagesBlocked: packagesBlocked,
            mattressReady: mattressWaiting,
            wheelSpinsReady: wheel.bonus + wheel.videoLeft
        )
        if prizeAccess != access { prizeAccess = access }
    }

    /// El chip o una caja del tablero.
    @discardableResult
    func packageTapped() -> PackageOpenResult {
        let result = openPackage()
        refreshPrizeAccess()
        return result
    }

    /// El chip o el colchón del tablero: abre su popup.
    func mattressTapped() {
        guard mattressWaiting, mattressPopup == nil, wheelSheet == nil else { return }
        mattressPopup = MattressPopup()
    }

    /// Terminó el video del colchón: lo que salió queda en el popup.
    func mattressVideoWatched() {
        guard mattressPopup != nil, let outcome = openMattress() else { return }
        mattressPopup?.outcome = outcome
        refreshPrizeAccess()
    }

    /// Terminó el segundo video: "otro colchón".
    func extraMattressVideoWatched() {
        guard mattressPopup?.outcome != nil, let outcome = openExtraMattress() else { return }
        mattressPopup?.outcome = outcome
    }

    func closeMattressPopup() {
        mattressPopup = nil
    }

    func openWheel() {
        guard wheelSheet == nil, mattressPopup == nil else { return }
        wheelSheet = WheelSheet()
    }

    func closeWheel() {
        wheelSheet = nil
    }

    /// El popup de un visitante terminó de irse. Si su premio fue un giro (el
    /// Conductor de TV: "abre la ruleta y da +1 giro", Anexo A), la ruleta se
    /// abre ahora, con la hoja anterior ya cerrada.
    func visitorPopupDismissed() {
        guard wheelOpensAfterVisit else { return }
        wheelOpensAfterVisit = false
        openWheel()
    }
}
```

`GameState+Rewards.swift`, el caso de `grant`:

```swift
        case .wheelSpin(let count):
            player.meta.engagement.wheel.bonusSpins += count
            if source.hasPrefix("visit.") { wheelOpensAfterVisit = true }
```

- [ ] **Step 4: Los chips y el popup**

`FisuEvolution/UI/Prizes/PrizeChips.swift`:

```swift
import SwiftUI

/// Los paquetes que esperan, tocables desde arriba: cuántos, y "LLENO" si
/// ninguno entra (el paquete se queda: PLAN-v2 §2).
struct PackageChip: View {
    let count: Int
    let blocked: Bool
    let action: () -> Void
    @State private var shakes = 0

    var body: some View {
        Button {
            if blocked { shakes += 1 }
            action()
        } label: {
            HStack(spacing: 6) {
                GameIcon(artKey: "pickup_package", size: 30) { PackageGlyph() }
                Text(verbatim: blocked ? String(localized: "prize.package.full") : "×\(count)")
                    .font(Tokens.body)
                    .monospacedDigit()
                    .foregroundStyle(blocked ? Color("PaletteOrange") : Color("PaletteInk"))
            }
            .prizeChipBackground()
        }
        .buttonStyle(.plain)
        .chipShake(shakes)
        .accessibilityIdentifier("prize.chip.package")
        // Dos `Text` y no un ternario adentro de uno: con el ternario, Swift elige
        // el `init` de `String` y la clave se lee cruda.
        .accessibilityLabel(blocked ? Text("prize.package.full.ax") : Text("prize.package.ax \(String(count))"))
        .accessibilityValue(Text(verbatim: blocked ? "full" : String(count)))
    }
}

/// El colchón esperando, con su "!" que late.
struct MattressChip: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                GameIcon(artKey: "pickup_mattress", size: 30) { MattressGlyph() }
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color("PaletteOrange"))
                    .scaleEffect(pulse ? 1.15 : 1)
            }
            .prizeChipBackground()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("prize.chip.mattress")
        .accessibilityLabel(Text("prize.mattress.ax"))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// La caja de la Aduana dibujada, mientras no llegue `pickup_package` (E8).
struct PackageGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color("PaletteBrown"))
            Rectangle().fill(Color("PaletteYellow")).frame(width: 5)
            Rectangle().fill(Color("PaletteYellow")).frame(height: 5)
            RoundedRectangle(cornerRadius: 4).strokeBorder(Color("PaletteInk"), lineWidth: 1.5)
        }
        .padding(3)
        .accessibilityHidden(true)
    }
}

/// El colchón dibujado, mientras no llegue `pickup_mattress` (E8).
struct MattressGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color("PaletteBlue").opacity(0.8))
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Color("PaletteCream")).frame(width: 4, height: 4)
                }
            }
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color("PaletteInk"), lineWidth: 1.5)
        }
        .aspectRatio(1.6, contentMode: .fit)
        .padding(2)
        .accessibilityHidden(true)
    }
}

private extension View {
    /// La cápsula de los chips del escenario (la misma que el del visitante, E4b).
    func prizeChipBackground() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color("PaletteCream"))
                    .overlay(Capsule().strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            )
            .contentShape(Capsule())
    }

    /// Un "no" con la cabeza: el paquete trabado tiembla al tocarlo.
    func chipShake(_ trigger: Int) -> some View {
        keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-6, duration: 0.06)
                CubicKeyframe(6, duration: 0.06)
                CubicKeyframe(-4, duration: 0.06)
                CubicKeyframe(0, duration: 0.06)
            }
        }
    }
}
```

`FisuEvolution/UI/Visitors/StageChips.swift` (de E4b T3): el `body` envuelve lo que haya en un
`HStack` con los chips de premios adelante, y suma su animación:

```swift
    var body: some View {
        HStack(spacing: 8) {
            prizeChips
            // lo de E4b, tal como esté: el chip del visitante (T3) y el del reto (T5)
            Group {
                if let visit = gameState.stageVisit, visit.phase == .waiting,
                   visit.offer != nil, gameState.stageChallenge == nil {
                    VisitorChip(visit: visit) { gameState.openVisitorPopup() }
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.3), value: gameState.stageVisit?.offer != nil)
        .animation(.spring(duration: 0.3), value: gameState.prizeAccess)
    }

    /// El paquete y el colchón esperando (PLAN-v2 E5). Hasta que exista la
    /// columna de E7b, éste es su acceso tocable y accesible.
    @ViewBuilder private var prizeChips: some View {
        let access = gameState.prizeAccess
        if access.packagesWaiting > 0 {
            PackageChip(count: access.packagesWaiting, blocked: access.packagesBlocked) {
                _ = gameState.packageTapped()
            }
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
        if access.mattressReady {
            MattressChip { gameState.mattressTapped() }
                .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
    }
```

(si E4b T5 dejó otra cosa adentro del `Group` —el chip del reto—, se conserva tal cual; lo único
nuevo es el `HStack`, `prizeChips` y la segunda `.animation`.)

`FisuEvolution/UI/Prizes/MattressPopupView.swift`:

```swift
import EconomyKit
import SwiftUI

/// El Colchón (PLAN-v2 E5): "tus empleados escondieron plata en el colchón".
/// Se abre sólo con video, y lo que puede tocar está a la vista antes de
/// mirarlo. Después: lo que salió y "otro colchón" con un segundo video.
struct MattressPopupView: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let outcome = gameState.mattressPopup?.outcome
        PanelCard {
            VStack(spacing: Tokens.s12) {
                PanelTitleBanner(titleKey: "mattress.title")
                if let outcome {
                    result(outcome)
                    if outcome.extraOpensLeft > 0 {
                        RewardedOfferButton(title: String(localized: "mattress.extra"), identifier: "mattress.extra",
                                            placement: .treasure) { gameState.extraMattressVideoWatched() }
                    }
                    ActionPill(titleKey: "mattress.collect", systemImage: "checkmark",
                               identifier: "mattress.collect") { dismiss() }
                } else {
                    Text("mattress.pitch")
                        .font(Tokens.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color("PaletteInk"))
                    GameIcon(artKey: "pickup_mattress", size: 88) { MattressGlyph() }
                    RewardedOfferButton(title: String(localized: "mattress.open"), identifier: "mattress.open",
                                        placement: .treasure) { gameState.mattressVideoWatched() }
                    OddsDisclosureView(titleKey: "mattress.odds.title", rows: oddsRows, identifier: "mattress.odds")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            ArtCloseButton { dismiss() }
                .padding(10)
        }
        .padding(16)
        .presentationDetents([.fraction(outcome == nil ? 0.66 : 0.5)])
        .fisuSheet()
    }

    private func result(_ outcome: MattressOutcome) -> some View {
        let text = outcome.coins > 0
            ? "+\(CoinFormatter.string(from: outcome.coins))"
            : outcome.rewards.map(RewardCopy.title).joined(separator: " + ")
        return GameCard(style: .highlighted(Color("PaletteYellow"))) {
            HStack(spacing: Tokens.s8) {
                Image(systemName: outcome.rewards.first.map(RewardCopy.symbol) ?? "gift.fill")
                    .font(.system(size: 28, weight: .heavy))
                Text(verbatim: text)
                    .font(Tokens.title)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color("PaletteInk"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mattress.result")
        .accessibilityValue(Text(verbatim: outcome.prizeId))
    }

    private var oddsRows: [OddsDisclosureView.Row] {
        guard let treasures = gameState.content?.treasures else { return [] }
        return zip(treasures.prizes, treasures.odds).map { prize, odds in
            OddsDisclosureView.Row(
                id: prize.id,
                title: prize.rewards.map(RewardCopy.title).joined(separator: " + "),
                symbol: prize.rewards.first.map(RewardCopy.symbol) ?? "gift.fill",
                probability: odds.probability
            )
        }
    }
}
```

- [ ] **Step 5: `RootView` (🔥) y el panel de debug**

`RootView.swift`, en `GameBoardView`:

1. `coversBoard` (E4b T3) suma los dos términos:

```swift
    private var coversBoard: Bool {
        activeScreen != nil || showPrestige || gameState.specialInfo != nil
            || gameState.visitorPopup != nil || gameState.eventPopup != nil
            || gameState.mattressPopup != nil || gameState.wheelSheet != nil
    }
```

(si E4b T9 ya sacó `specialInfo`, se conserva su versión y se suman sólo las dos líneas.)

2. Junto a los otros `onChange` que escriben `uiCoversBoard`:

```swift
        .onChange(of: gameState.mattressPopup) { _, _ in
            gameState.uiCoversBoard = coversBoard
        }
        .onChange(of: gameState.wheelSheet) { _, _ in
            gameState.uiCoversBoard = coversBoard
        }
```

3. En "Bindings de las celebraciones" (propiedades con tipo explícito: con `Binding` en línea el
   type-checker se cae con tantas hojas encadenadas):

```swift
    private var mattressPopupBinding: Binding<MattressPopup?> {
        Binding(get: { gameState.mattressPopup }, set: { if $0 == nil { gameState.closeMattressPopup() } })
    }

    private var wheelSheetBinding: Binding<WheelSheet?> {
        Binding(get: { gameState.wheelSheet }, set: { if $0 == nil { gameState.closeWheel() } })
    }
```

4. Junto a las otras hojas:

```swift
        .sheet(item: mattressPopupBinding) { _ in
            MattressPopupView()
        }
        .sheet(item: wheelSheetBinding) { _ in
            NavigationStack {
                WheelView(close: { gameState.closeWheel() })
            }
            .tint(Color("PaletteInk"))
            .fisuSheet()
        }
```

5. A la hoja del visitante (E4b T3) se le suma el `onDismiss`, sin tocar su `Binding`:

```swift
        .sheet(item: Binding(
            get: { gameState.visitorPopup },
            set: { if $0 == nil { gameState.closeVisitorPopup() } }
        ), onDismiss: { gameState.visitorPopupDismissed() }) { _ in
            VisitorPopupView()
        }
```

`FisuEvolution/UI/DebugPanelView.swift`, una sección antes de "Peligro":

```swift
                // Los premios de E5 salen cada 2 y 8 minutos de juego: sin esta
                // puerta no se pueden ni fotografiar ni probar dos veces seguidas.
                Section("Paquete, colchón y ruleta") {
                    Button("+1 Paquete de la Aduana") {
                        gameState.debugAddPackages(1)
                        gameState.refreshPrizeAccess()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.prizes.package")
                    Button("Que aparezca el colchón") {
                        gameState.debugSpawnMattress()
                        gameState.refreshPrizeAccess()
                        dismiss()
                    }
                    .accessibilityIdentifier("debug.prizes.mattress")
                    Button("+3 giros de la ruleta") {
                        gameState.debugAddWheelSpins(3)
                    }
                    .accessibilityIdentifier("debug.prizes.spins")
                    Button("La ruleta: un día nuevo") {
                        gameState.debugWheelNewDay()
                    }
                    .accessibilityIdentifier("debug.prizes.newday")
                }
```

- [ ] **Step 6: Los textos**

`Tools/v2/claves-pendientes/e5b-t2.json`:

```json
{
  "prize.package.full": {"es": "LLENO", "en": "FULL"},
  "prize.package.ax %@": {"es": "Paquetes de la Aduana esperando: %@", "en": "Customs Packages waiting: %@"},
  "prize.package.full.ax": {"es": "Paquete de la Aduana: no hay lugar. Fusioná para hacer lugar.", "en": "Customs Package: no room. Merge to make room."},
  "prize.mattress.ax": {"es": "El colchón tiene plata escondida", "en": "There's cash hidden in the mattress"},
  "mattress.title": {"es": "El Colchón", "en": "The Mattress"},
  "mattress.pitch": {"es": "Tus empleados escondieron plata en el colchón. ¿Lo abrimos?", "en": "Your workers stashed cash in the mattress. Shall we open it?"},
  "mattress.open": {"es": "Abrir con un video", "en": "Open with a video"},
  "mattress.extra": {"es": "Otro colchón con un video", "en": "Another mattress with a video"},
  "mattress.collect": {"es": "¡Guardar!", "en": "Keep it!"},
  "mattress.odds.title": {"es": "Lo que puede haber adentro", "en": "What could be inside"}
}
```

(10 claves; `prize.package.ax %@` interpola un `String`.) Si la tarea es dueña del catálogo en su
ola, `Tools/v2/catalogo.py aplicar …` y se commitea el catálogo; si no, el JSON.

- [ ] **Step 7: Verde, a mano y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/PrizeAccessTests -only-testing:FisuEvolutionTests/SheetPresentationGuardTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionTests/CelebrationWiringTests`
→ PASS (5 nuevos); UI: `-only-testing:FisuEvolutionUITests/PrizesUITests -only-testing:FisuEvolutionUITests/VisitorUITests`
→ PASS. A mano (SE y iPad 13", Reduce Motion sí/no, VoiceOver una pasada): panel de debug →
"+1 Paquete" → el chip "×1" al lado del visitante; tocarlo → el empleado llega (todavía sin caja:
la apertura es T3); con el callejón lleno, "LLENO" y el chip tiembla; "Que aparezca el colchón" →
chip con "!" → popup con la tabla → video (stub) → resultado → otro → guardar;
`--uitest-visitor=conductor_ruleta` (E4b) → aceptar → al cerrarse su popup se abre la ruleta.
Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/Game/State/PrizeAccess.swift
git add FisuEvolution/Game/State/GameState.swift
git add FisuEvolution/Game/State/GameState+Prizes.swift
git add FisuEvolution/Game/State/GameState+Rewards.swift
git add FisuEvolution/UI/Prizes/PrizeChips.swift
git add FisuEvolution/UI/Visitors/StageChips.swift
git add FisuEvolution/UI/Prizes/MattressPopupView.swift
git add FisuEvolution/App/RootView.swift
git add FisuEvolution/UI/DebugPanelView.swift
git add FisuEvolutionTests/PrizeAccessTests.swift
git add FisuEvolutionUITests/PrizesUITests.swift
# + el catálogo o Tools/v2/claves-pendientes/e5b-t2.json, según la ola
git diff --cached --stat
git commit -m "feat(premios): los chips del paquete y el colchón, su popup y la ruleta sobre el tablero"
```

---

### Task 3: La escena — las cajas y el colchón en el tablero, y el paquete que se abre donde llega

**Objetivo:** que el paquete y el colchón **se vean** en el tablero (PLAN-v2: "`PickupNode` en el
borde del tablero"): hasta tres cajas apiladas y el colchón, apoyados en la línea del escenario a
los costados de donde se para un visitante y lejos de los bordes (la columna de E7b y la
botonera); que se toquen (la caja abre un paquete, "LLENO" la hace temblar; el colchón abre su
popup); y que el paquete abierto **se abra en el lugar donde va a quedar el empleado**, adentro
del turno del tablero de E1: cae, se sacude, la tapa vuela, saltan monedas y recién ahí se
confirma la llegada (el empleado aparece y, si fuera nuevo, se revela).

**Files:**
- Create: `FisuEvolution/Scenes/Prizes/PickupLayout.swift`
- Create: `FisuEvolution/Scenes/Prizes/PickupArt.swift`
- Create: `FisuEvolution/Scenes/Prizes/PickupNode.swift`
- Create: `FisuEvolution/Scenes/Prizes/PickupController.swift`
- Create: `FisuEvolution/Scenes/Prizes/PackageOpeningPlayer.swift`
- Modify: `FisuEvolution/Scenes/BoardScene.swift` (🔥: siete ganchos)
- Create: `FisuEvolutionTests/PickupLayoutTests.swift`, `FisuEvolutionTests/PickupControllerTests.swift`, `FisuEvolutionTests/PackageOpeningPlayerTests.swift`

**Interfaces:**
- Consumes: T2 (`prizeAccess`, `packageTapped()`, `mattressTapped()`, `mattressPopup`); E5a T6
  (`Origin.package`); **E1 T10** (`performBoardChange`, `confirmWithoutGesture`,
  `abortBoardCelebration`, `position(ofCell:)`, `depthZ(for:)`); **E4b T1** (`StageLayout`, el
  gancho de toques del escenario); `ParticlePool.emit(_:at:in:)`, `UIArt.uiImage(_:)`.
- Produces: `struct PickupLayout` (`packageXRatio`, `mattressXRatio`, `sideRatio`, `stackStep`,
  `maxVisibleBoxes`, `edgeClearance`, `side`, `baselineY`, `packagePosition(index:)`,
  `mattressPosition`); `enum PickupArt` (`Piece`, `texture(_:)`, `placeholder(_:)`);
  `final class PickupNode: SKNode` (`kind`, `showsFull`, `shake()`, `update(delta:reduceMotion:)`,
  `resize(side:)`, `hitTest(_:)`); `@MainActor final class PickupController` (`layer`,
  `attach(to:)`, `layout(sceneSize:bottomInset:cellSize:)`, `update(delta:reduceMotion:)`,
  `handleTap(at:) -> Bool`, `boxes`, `mattress`); `@MainActor final class PackageOpeningPlayer`
  (`totalSeconds`, `fadeSeconds`, `isPlaying`, `play(at:in:z:side:burst:opened:)`,
  `update(delta:reduceMotion:)`, `cancel()`).

- [ ] **Step 0: El turno del tablero y el escenario están**

Run (uno por llamada):

```bash
grep -n "private func performBoardChange\|private func confirmWithoutGesture\|private func abortBoardCelebration" FisuEvolution/Scenes/BoardScene.swift
grep -n "stage.handleTap\|private lazy var stage" FisuEvolution/Scenes/BoardScene.swift
grep -n "struct StageLayout" FisuEvolution/Scenes/Stage/StageLayout.swift
```

Expected: las cinco líneas (E1 T10 y E4b T1). Si falta algo, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/PickupLayoutTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import FisuEvolution

/// Dónde se paran las cajas y el colchón: ni bajo la columna de E7b ni bajo la
/// botonera, ni encima de quien está en escena (E4b).
@Suite("Las cajas y el colchón: dónde se paran")
struct PickupLayoutTests {
    /// iPhone SE, 16 Pro, Pro Max y el iPad 13", con la celda de `PlayLayout`.
    static let screens: [(CGSize, CGFloat)] = [
        (CGSize(width: 375, height: 667), 68),
        (CGSize(width: 393, height: 852), 72),
        (CGSize(width: 440, height: 956), 81.6),
        (CGSize(width: 1032, height: 1376), 112),
    ]

    @Test("lejos de los bordes y a los costados del visitante")
    func clearOfTheEdgesAndTheVisitor() {
        for (size, cell) in Self.screens {
            let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let visitorLeft = stage.standX - stage.actorSide / 2
            let visitorRight = stage.standX + stage.actorSide / 2
            for index in 0..<PickupLayout.maxVisibleBoxes {
                let box = layout.packagePosition(index: index)
                #expect(box.x - layout.side / 2 >= PickupLayout.edgeClearance, "\(size): la caja \(index) va bajo la columna")
                #expect(box.x + layout.side / 2 <= visitorLeft + 0.5, "\(size): la caja \(index) pisa al visitante")
            }
            let mattress = layout.mattressPosition
            #expect(mattress.x - layout.side / 2 >= visitorRight - 0.5, "\(size): el colchón pisa al visitante")
            #expect(mattress.x + layout.side / 2 <= size.width - PickupLayout.edgeClearance, "\(size): el colchón va al borde")
        }
    }

    @Test("apoyados en la línea del escenario, y la pila no pasa de media pantalla")
    func onTheStageLine() {
        for (size, cell) in Self.screens {
            let layout = PickupLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            let stage = StageLayout(sceneSize: size, bottomInset: 118, cellSize: cell)
            #expect(abs(layout.packagePosition(index: 0).y - layout.side / 2 - stage.baselineY) < 0.5)
            let top = layout.packagePosition(index: PickupLayout.maxVisibleBoxes - 1).y + layout.side / 2
            #expect(top < size.height / 2, "\(size): la pila sube hasta \(top)")
        }
    }
}
```

`FisuEvolutionTests/PackageOpeningPlayerTests.swift`:

```swift
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("La apertura del Paquete de la Aduana")
@MainActor
struct PackageOpeningPlayerTests {
    private func run(_ player: PackageOpeningPlayer, seconds: TimeInterval, reduceMotion: Bool) {
        let step = 1.0 / 60
        var elapsed = 0.0
        while elapsed < seconds {
            player.update(delta: step, reduceMotion: reduceMotion)
            elapsed += step
        }
    }

    @Test("se sacude, saltan las monedas una vez y recién al final confirma la llegada, una sola vez")
    func opensOnce() {
        let player = PackageOpeningPlayer()
        let parent = SKNode()
        var bursts = 0
        var opened = 0
        player.play(at: CGPoint(x: 100, y: 200), in: parent, z: 50, side: 44,
                    burst: { _ in bursts += 1 }, opened: { opened += 1 })
        #expect(parent.children.count == 1)
        run(player, seconds: PackageOpeningPlayer.totalSeconds - 0.1, reduceMotion: false)
        #expect(opened == 0)
        #expect(bursts == 1)
        run(player, seconds: 0.5, reduceMotion: false)
        #expect(opened == 1)
        #expect(bursts == 1)
        #expect(parent.children.isEmpty)
        #expect(!player.isPlaying)
    }

    @Test("con Reduce Motion: un fundido corto, sin sacudida ni monedas")
    func reduceMotionIsAFade() {
        let player = PackageOpeningPlayer()
        let parent = SKNode()
        var bursts = 0
        var opened = 0
        player.play(at: .zero, in: parent, z: 0, side: 44, burst: { _ in bursts += 1 }, opened: { opened += 1 })
        run(player, seconds: PackageOpeningPlayer.fadeSeconds + 0.05, reduceMotion: true)
        #expect(opened == 1)
        #expect(bursts == 0)
    }

    @Test("cortarla no confirma nada y no deja nodos")
    func cancelling() {
        let player = PackageOpeningPlayer()
        let parent = SKNode()
        var opened = 0
        player.play(at: .zero, in: parent, z: 0, side: 44, burst: { _ in }, opened: { opened += 1 })
        run(player, seconds: 0.3, reduceMotion: false)
        player.cancel()
        run(player, seconds: 2, reduceMotion: false)
        #expect(opened == 0)
        #expect(parent.children.isEmpty)
    }
}
```

`FisuEvolutionTests/PickupControllerTests.swift`:

```swift
import EconomyKit
import SpriteKit
import Testing
@testable import FisuEvolution

@Suite("Las cajas y el colchón en el tablero")
@MainActor
struct PickupControllerTests {
    private func pickups() async -> (GameState, PickupController) {
        let gameState = await makeGameState()
        let controller = PickupController(gameState: gameState)
        controller.attach(to: SKNode())
        controller.layout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
        return (gameState, controller)
    }

    @Test("una caja por paquete esperando, hasta tres")
    func oneBoxPerPackage() async {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(5)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.boxes.count == 3)
        #expect(controller.mattress == nil)
    }

    @Test("tocar una caja abre un paquete, y la caja se va")
    func tappingABox() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let box = try #require(controller.boxes.first)
        #expect(controller.handleTap(at: box.position))
        #expect(gameState.pendingBoardChanges.last?.origin == .package)
        controller.update(delta: 1.0 / 60, reduceMotion: true)
        #expect(controller.boxes.isEmpty)
    }

    @Test("sin lugar la de arriba dice LLENO, y tocarla no gasta el paquete")
    func aFullTower() async throws {
        let (gameState, controller) = await pickups()
        let base = try #require(gameState.content?.tiers.baseType.id)
        let capacity = try #require(gameState.tower?.floors.first?.def.capacity)
        gameState.player?.run.units = [base: capacity]
        gameState.reconcileTower()
        gameState.debugAddPackages(2)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        #expect(controller.boxes.last?.showsFull == true)
        #expect(controller.boxes.first?.showsFull == false)
        let top = try #require(controller.boxes.last)
        #expect(controller.handleTap(at: top.position))
        #expect(gameState.packagesWaiting == 2)
    }

    @Test("el colchón aparece y tocarlo abre su popup")
    func theMattress() async throws {
        let (gameState, controller) = await pickups()
        gameState.debugSpawnMattress()
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        let mattress = try #require(controller.mattress)
        #expect(controller.handleTap(at: mattress.position))
        #expect(gameState.mattressPopup != nil)
    }

    @Test("un toque lejos no es suyo, y con la UI apagada no se ven")
    func farTapsAndCelebrations() async {
        let (gameState, controller) = await pickups()
        gameState.debugAddPackages(1)
        gameState.refreshPrizeAccess()
        controller.update(delta: 1, reduceMotion: true)
        #expect(!controller.handleTap(at: CGPoint(x: 380, y: 800)))
        gameState.celebrationHidesUI = true
        controller.update(delta: 1.0 / 60, reduceMotion: true)
        #expect(controller.layer.isHidden)
        gameState.celebrationHidesUI = false
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con
`-only-testing:FisuEvolutionTests/PickupLayoutTests -only-testing:FisuEvolutionTests/PickupControllerTests -only-testing:FisuEvolutionTests/PackageOpeningPlayerTests`.
Expected: no compila (`PickupLayout` no existe).

- [ ] **Step 3: El layout y el arte**

`FisuEvolution/Scenes/Prizes/PickupLayout.swift`:

```swift
import CoreGraphics

/// Dónde se paran las cajas del Paquete y el colchón: abajo, sobre la línea del
/// escenario (E4b), a los costados de donde se para un visitante y lejos de los
/// bordes, que son de la columna lateral (E7b) y de la botonera (E3a).
struct PickupLayout: Equatable {
    static let packageXRatio: CGFloat = 0.31
    static let mattressXRatio: CGFloat = 0.69
    /// El lado de una caja, en celdas.
    static let sideRatio: CGFloat = 0.62
    /// Cada caja de más se apila encima, montada sobre la de abajo.
    static let stackStep: CGFloat = 0.55
    static let maxVisibleBoxes = 3
    /// Lo que se deja libre contra cada borde: el ancho de la columna de E7b, con aire.
    static let edgeClearance: CGFloat = 72

    let sceneSize: CGSize
    let bottomInset: CGFloat
    let cellSize: CGFloat

    var side: CGFloat { cellSize * Self.sideRatio }
    /// La misma línea que pisa un visitante (`StageLayout.baselineY`).
    var baselineY: CGFloat { bottomInset + cellSize * 0.25 }

    func packagePosition(index: Int) -> CGPoint {
        CGPoint(x: sceneSize.width * Self.packageXRatio,
                y: baselineY + side / 2 + CGFloat(index) * side * Self.stackStep)
    }

    var mattressPosition: CGPoint {
        CGPoint(x: sceneSize.width * Self.mattressXRatio, y: baselineY + side * 0.35)
    }
}
```

`FisuEvolution/Scenes/Prizes/PickupArt.swift`:

```swift
import SpriteKit
import UIKit

/// El arte de las cajas y el colchón del tablero: el del atlas `ui` si E8 ya lo
/// entregó, y si no, uno dibujado por código.
@MainActor
enum PickupArt {
    enum Piece: String, CaseIterable {
        case package = "pickup_package"
        case packageLid = "pickup_package_lid"
        case mattress = "pickup_mattress"
    }

    private static var cache: [Piece: SKTexture] = [:]

    static func texture(_ piece: Piece) -> SKTexture {
        if let cached = cache[piece] { return cached }
        let texture = SKTexture(image: UIArt.uiImage(piece.rawValue) ?? placeholder(piece))
        cache[piece] = texture
        return texture
    }

    /// El respaldo, a escala de 96 pt (la escena lo achica).
    static func placeholder(_ piece: Piece) -> UIImage {
        let size: CGSize = switch piece {
        case .package: CGSize(width: 96, height: 84)
        case .packageLid: CGSize(width: 100, height: 28)
        case .mattress: CGSize(width: 96, height: 60)
        }
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3)
            let body = UIBezierPath(roundedRect: rect, cornerRadius: piece == .mattress ? 14 : 8)
            (UIColor(named: piece == .mattress ? "PaletteBlue" : "PaletteBrown") ?? .brown).setFill()
            body.fill()
            if piece != .mattress {
                (UIColor(named: "PaletteYellow") ?? .yellow).setFill()
                context.fill(CGRect(x: rect.midX - 5, y: rect.minY, width: 10, height: rect.height))
            }
            (UIColor(named: "PaletteInk") ?? .black).setStroke()
            body.lineWidth = 3
            body.stroke()
        }
    }
}
```

- [ ] **Step 4: La caja, el controlador y la apertura**

`FisuEvolution/Scenes/Prizes/PickupNode.swift`:

```swift
import SpriteKit

/// Una caja del Paquete o el colchón, en el tablero. Todo lo que se mueve va por
/// frame (`update`): entra con un resorte, respira, y tiembla si se la toca sin
/// lugar.
final class PickupNode: SKNode {
    enum Kind: Equatable {
        case package
        case mattress
    }

    static let popSeconds: TimeInterval = 0.35
    static let shakeSeconds: TimeInterval = 0.4

    let kind: Kind
    private let sprite: SKSpriteNode
    private let fullSign = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var age: TimeInterval = 0
    private var shakeLeft: TimeInterval = 0

    init(kind: Kind, texture: SKTexture, side: CGFloat) {
        self.kind = kind
        sprite = SKSpriteNode(texture: texture)
        super.init()
        addChild(sprite)
        fullSign.text = String(localized: "prize.package.full")
        fullSign.fontColor = UIColor(named: "PaletteOrange")
        fullSign.verticalAlignmentMode = .center
        fullSign.isHidden = true
        addChild(fullSign)
        resize(side: side)
        setScale(0.01)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func resize(side: CGFloat) {
        let size = sprite.texture?.size() ?? CGSize(width: 1, height: 1)
        sprite.size = CGSize(width: side, height: side * size.height / max(size.width, 1))
        fullSign.fontSize = side * 0.3
        fullSign.position = CGPoint(x: 0, y: sprite.size.height * 0.75)
    }

    /// El cartel "LLENO" (PLAN-v2 §2).
    var showsFull: Bool {
        get { !fullSign.isHidden }
        set { fullSign.isHidden = !newValue }
    }

    func shake() {
        shakeLeft = Self.shakeSeconds
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        age += delta
        if reduceMotion {
            setScale(1)
            zRotation = 0
            alpha = CGFloat(min(1, age / Self.popSeconds))
            return
        }
        alpha = 1
        let pop = min(1, age / Self.popSeconds)
        let overshoot = pop < 1 ? 0.2 * sin(pop * .pi) : 0
        let breathe = kind == .package ? 0.025 * sin(age * 3) : 0.015 * sin(age * 2)
        setScale(CGFloat(pop + overshoot + breathe))
        guard shakeLeft > 0 else {
            zRotation = 0
            return
        }
        shakeLeft = max(0, shakeLeft - delta)
        zRotation = CGFloat(sin(shakeLeft * 60) * 0.14 * (shakeLeft / Self.shakeSeconds))
    }

    /// `point` en las coordenadas del padre, con un margen generoso para el dedo.
    func hitTest(_ point: CGPoint) -> Bool {
        calculateAccumulatedFrame().insetBy(dx: -8, dy: -8).contains(point)
    }
}
```

`FisuEvolution/Scenes/Prizes/PickupController.swift`:

```swift
import SpriteKit

/// Las cajas del Paquete de la Aduana y el colchón, en el tablero (PLAN-v2 E5).
/// Colaborador de `BoardScene` como el escenario de E4b: vive en la capa de la
/// cámara, se mueve por frame y le pasa los toques a `GameState`. Lo que muestra
/// sale de `GameState.prizeAccess`, lo mismo que los chips.
@MainActor
final class PickupController {
    /// Delante de la multitud, detrás del visitante (190) y del reveal (195).
    static let layerZ: CGFloat = 186

    let layer = SKNode()
    private weak var gameState: GameState?
    private var layout = PickupLayout(sceneSize: CGSize(width: 393, height: 852), bottomInset: 118, cellSize: 72)
    private(set) var boxes: [PickupNode] = []
    private(set) var mattress: PickupNode?

    init(gameState: GameState) {
        self.gameState = gameState
        layer.zPosition = Self.layerZ
        layer.name = "pickups"
    }

    func attach(to parent: SKNode) {
        guard layer.parent == nil else { return }
        parent.addChild(layer)
    }

    func layout(sceneSize: CGSize, bottomInset: CGFloat, cellSize: CGFloat) {
        layout = PickupLayout(sceneSize: sceneSize, bottomInset: bottomInset, cellSize: cellSize)
        for node in boxes { node.resize(side: layout.side) }
        mattress?.resize(side: layout.side)
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        guard let gameState else { return }
        let access = gameState.prizeAccess
        layer.isHidden = gameState.celebrationHidesUI
        syncBoxes(count: min(access.packagesWaiting, PickupLayout.maxVisibleBoxes), blocked: access.packagesBlocked)
        syncMattress(present: access.mattressReady)
        for (index, box) in boxes.enumerated() {
            box.position = layout.packagePosition(index: index)
            box.update(delta: delta, reduceMotion: reduceMotion)
        }
        if let mattress {
            mattress.position = layout.mattressPosition
            mattress.update(delta: delta, reduceMotion: reduceMotion)
        }
    }

    /// `point` en coordenadas de `layer`. Devuelve si el toque era suyo.
    @discardableResult
    func handleTap(at point: CGPoint) -> Bool {
        guard let gameState, !layer.isHidden else { return false }
        if let mattress, mattress.hitTest(point) {
            gameState.mattressTapped()
            return true
        }
        guard boxes.contains(where: { $0.hitTest(point) }) else { return false }
        if gameState.packageTapped() == .full { boxes.last?.shake() }
        return true
    }

    private func syncBoxes(count: Int, blocked: Bool) {
        while boxes.count > count { boxes.removeLast().removeFromParent() }
        while boxes.count < count {
            let box = PickupNode(kind: .package, texture: PickupArt.texture(.package), side: layout.side)
            box.zPosition = CGFloat(boxes.count)
            layer.addChild(box)
            boxes.append(box)
        }
        for (index, box) in boxes.enumerated() {
            box.showsFull = blocked && index == boxes.count - 1
        }
    }

    private func syncMattress(present: Bool) {
        if present, mattress == nil {
            let node = PickupNode(kind: .mattress, texture: PickupArt.texture(.mattress), side: layout.side)
            layer.addChild(node)
            mattress = node
        } else if !present, let node = mattress {
            node.removeFromParent()
            mattress = nil
        }
    }
}
```

`FisuEvolution/Scenes/Prizes/PackageOpeningPlayer.swift`:

```swift
import SpriteKit

/// La apertura del Paquete de la Aduana, adentro del turno del tablero (E1): la
/// caja cae donde va a quedar el empleado, se sacude, la tapa vuela, saltan
/// monedas y recién ahí se confirma la llegada, que hace el resto (el pop del
/// empleado y, si fuera nuevo, su revelación). Por frame, como el escenario de
/// E4b: se prueba sin vista.
@MainActor
final class PackageOpeningPlayer {
    static let dropSeconds: TimeInterval = 0.25
    static let shakeSeconds: TimeInterval = 0.5
    static let lidSeconds: TimeInterval = 0.3
    static let fadeSeconds: TimeInterval = 0.3
    static var totalSeconds: TimeInterval { dropSeconds + shakeSeconds + lidSeconds }

    private var box: SKSpriteNode?
    private var lid: SKSpriteNode?
    private var point: CGPoint = .zero
    private var side: CGFloat = 0
    private var elapsed: TimeInterval = 0
    private var burstDone = false
    private var onBurst: ((CGPoint) -> Void)?
    private var onOpened: (() -> Void)?

    var isPlaying: Bool { box != nil }

    func play(
        at point: CGPoint,
        in parent: SKNode,
        z: CGFloat,
        side: CGFloat,
        burst: @escaping (CGPoint) -> Void,
        opened: @escaping () -> Void
    ) {
        cancel()
        let box = SKSpriteNode(texture: PickupArt.texture(.package))
        let textureSize = box.texture?.size() ?? CGSize(width: 1, height: 1)
        box.size = CGSize(width: side, height: side * textureSize.height / max(textureSize.width, 1))
        box.position = point
        box.zPosition = z
        let lid = SKSpriteNode(texture: PickupArt.texture(.packageLid))
        lid.size = CGSize(width: side * 1.04, height: side * 0.3)
        lid.position = CGPoint(x: 0, y: box.size.height / 2)
        lid.zPosition = 1
        box.addChild(lid)
        parent.addChild(box)
        self.box = box
        self.lid = lid
        self.point = point
        self.side = side
        elapsed = 0
        burstDone = false
        onBurst = burst
        onOpened = opened
    }

    func update(delta: TimeInterval, reduceMotion: Bool) {
        guard let box, let lid else { return }
        elapsed += delta
        if reduceMotion {
            box.setScale(1)
            box.zRotation = 0
            box.alpha = CGFloat(min(1, elapsed / Self.fadeSeconds))
            if elapsed >= Self.fadeSeconds { finish() }
            return
        }
        let shakeStart = Self.dropSeconds
        let lidStart = shakeStart + Self.shakeSeconds
        if elapsed < shakeStart {
            let t = elapsed / Self.dropSeconds
            box.setScale(CGFloat(0.3 + 0.7 * t + 0.15 * sin(t * .pi)))
            box.position = CGPoint(x: point.x, y: point.y + side * CGFloat(1 - t))
        } else if elapsed < lidStart {
            box.setScale(1)
            box.position = point
            let t = (elapsed - shakeStart) / Self.shakeSeconds
            box.zRotation = CGFloat(sin(t * .pi * 8) * 0.14 * (1 - t))
        } else {
            box.zRotation = 0
            if !burstDone {
                burstDone = true
                onBurst?(point)
            }
            let t = min(1, (elapsed - lidStart) / Self.lidSeconds)
            lid.position = CGPoint(x: side * 0.3 * CGFloat(t), y: box.size.height / 2 + side * 1.2 * CGFloat(t))
            lid.zRotation = CGFloat(0.9 * t)
            lid.alpha = CGFloat(1 - t)
            box.alpha = CGFloat(1 - 0.6 * t)
            if elapsed >= Self.totalSeconds { finish() }
        }
    }

    /// Se corta (el salto o el watchdog del turno): sin avisos. El cambio en
    /// vuelo lo asienta `GameState` (E1).
    func cancel() {
        box?.removeFromParent()
        box = nil
        lid = nil
        onBurst = nil
        onOpened = nil
    }

    private func finish() {
        let opened = onOpened
        cancel()
        opened?()
    }
}
```

- [ ] **Step 5: Los siete ganchos de `BoardScene` (🔥)**

1. Junto a `stage` (E4b T1):

```swift
    /// Las cajas del Paquete y el colchón (PLAN-v2 E5): un colaborador más, como el escenario.
    private lazy var pickups = PickupController(gameState: gameState)
    /// La caja que se abre en el turno del tablero.
    private let packageOpening = PackageOpeningPlayer()
```

2. En `init(gameState:)`, después de `stage.attach(to: cameraOverlay)`: `pickups.attach(to: cameraOverlay)`.
3. Al final de `layoutBoard()`, junto a `stage.layout(…)`:
   `pickups.layout(sceneSize: size, bottomInset: Self.bottomInset, cellSize: cellSize)`.
4. En `update(_:)`, después de `stage.update(…)` (y del de `stageEffects`, E4b T6):

```swift
        pickups.update(delta: delta, reduceMotion: Self.prefersReducedMotion)
        packageOpening.update(delta: delta, reduceMotion: Self.prefersReducedMotion)
```

5. En `touchesBegan`, justo después de `if stage.handleTap(…) { return }`:

```swift
        if pickups.handleTap(at: touch.location(in: pickups.layer)) { return }
```

6. En `performBoardChange(_:)` (E1 T10), el caso de las llegadas se parte:

```swift
        case .arrival where change.origin == .package:
            playPackageArrival(change)
        case .arrival, .departure:
            confirmWithoutGesture(change)
```

y, debajo de `confirmWithoutGesture`:

```swift
    /// El paquete se abre donde va a quedar el empleado y recién ahí llega
    /// (PLAN-v2 E5): la llegada confirma, el empleado aparece en ese lugar y la
    /// revelación sale como siempre. Si el piso no está a la vista o ya no hay
    /// lugar, llega sin caja: la revalidación del turno es de E1.
    private func playPackageArrival(_ change: BoardChange) {
        guard let ordinal = gameState.floorOrdinal(of: change), ordinal == gameState.visibleFloorOrdinal,
              let slot = gameState.tower?.floors[ordinal].firstFreeSlot()
        else { return confirmWithoutGesture(change) }
        let point = position(ofCell: slot)
        packageOpening.play(
            at: point, in: fieldNode, z: depthZ(for: point) + 1, side: cellSize * PickupLayout.sideRatio,
            burst: { [weak self] at in
                guard let self else { return }
                self.particles.emit(.coins, at: at, in: self.fieldNode)
            },
            opened: { [weak self] in self?.confirmWithoutGesture(change) }
        )
    }
```

7. En `abortBoardCelebration()`, junto a lo que E1 T10 le sumó: `packageOpening.cancel()`.

- [ ] **Step 6: Verde, a mano y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con
`-only-testing:FisuEvolutionTests/PickupLayoutTests -only-testing:FisuEvolutionTests/PickupControllerTests -only-testing:FisuEvolutionTests/PackageOpeningPlayerTests -only-testing:FisuEvolutionTests/StageControllerTests -only-testing:FisuEvolutionTests/BoardChangeWiringTests -only-testing:FisuEvolutionTests/BoardGestureTests`
→ PASS (10 nuevos); UI: `-only-testing:FisuEvolutionUITests/PrizesUITests -only-testing:FisuEvolutionUITests/BoardChangeUITests -only-testing:FisuEvolutionUITests/BoardGestureUITests`
→ PASS (el paquete llega igual, ahora con la caja; el resto del tablero no cambió). A mano (SE,
16 Pro y iPad 13", Reduce Motion sí y no): `--uitest-packages=3` → tres cajas apiladas a la
izquierda, sin tocar al visitante (`--uitest-visitor=turista_propina`) ni el borde; tocar una →
la cámara va al piso, la caja cae, tiembla, la tapa vuela con monedas y el empleado aparece donde
estaba; con el callejón lleno → "LLENO" sobre la de arriba y tiembla; `--uitest-mattress` → el
colchón a la derecha, tocarlo abre su popup; un ascenso con reveal tapa las cajas (se esconden).
Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Scenes/Prizes/PickupLayout.swift
git add FisuEvolution/Scenes/Prizes/PickupArt.swift
git add FisuEvolution/Scenes/Prizes/PickupNode.swift
git add FisuEvolution/Scenes/Prizes/PickupController.swift
git add FisuEvolution/Scenes/Prizes/PackageOpeningPlayer.swift
git add FisuEvolution/Scenes/BoardScene.swift
git add FisuEvolutionTests/PickupLayoutTests.swift
git add FisuEvolutionTests/PickupControllerTests.swift
git add FisuEvolutionTests/PackageOpeningPlayerTests.swift
git diff --cached --stat
git commit -m "feat(paquetes): las cajas y el colchón en el tablero, y el paquete que se abre donde llega"
```

---

### Task 4: La Ruleta en Regalos

**Objetivo:** "vive en Regalos" (PLAN-v2 E5): una tarjeta en la pantalla de Regalos, después de
los cofres y antes de la racha, con los giros de hoy y un botón que empuja la ruleta dentro de la
misma hoja (como Ajustes en el Menú). Es el camino a la ruleta para todo jugador mientras no
exista la columna de E7b.

**Files:**
- Create: `FisuEvolution/UI/Wheel/WheelGiftCard.swift`
- Modify: `FisuEvolution/UI/Gifts/GiftsView.swift`
- Create: `FisuEvolutionUITests/WheelUITests.swift`
- Strings: el catálogo (dueña en su ola) o `Tools/v2/claves-pendientes/e5b-t4.json` (6 claves)

**Interfaces:**
- Consumes: T1 (`WheelView`, `WheelGlyph`, `RewardCopy.text`); E5a T8 (`wheelAvailability`,
  `WheelAvailability`); `GiftsView` (con la `VideoCard.rail` de E1 T14).
- Produces: `WheelGiftCard(availability:open:)`; identificador `gifts.wheel.open`.

- [ ] **Step 1: El test, en rojo**

`FisuEvolutionUITests/WheelUITests.swift`:

```swift
import XCTest

/// La ruleta se gira desde Regalos (PLAN-v2 E5): un giro regalado, el premio
/// a la vista, "repetir" una vez y la tabla siempre visible.
final class WheelUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTheWheelSpinsFromGifts() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-wheel-spins=1"]
        app.launch()

        let gifts = app.buttons["hud.bonus"]
        XCTAssertTrue(gifts.waitForExistence(timeout: 15))
        gifts.tap()
        let open = app.buttons["gifts.wheel.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()

        XCTAssertTrue(app.descendants(matching: .any)["wheel.odds.coins_30"].waitForExistence(timeout: 5),
                      "la tabla está a la vista antes de girar")
        let free = app.buttons["wheel.spin.bonus"]
        XCTAssertTrue(free.waitForExistence(timeout: 5))
        free.tap()

        let result = app.descendants(matching: .any)["wheel.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertFalse((result.value as? String ?? "").isEmpty)
        let again = app.buttons["wheel.repeat"]
        XCTAssertTrue(again.waitForExistence(timeout: 3))
        again.tap()
        XCTAssertTrue(again.waitForNonExistence(timeout: 6), "repetir es una vez por giro")
        XCTAssertTrue(app.buttons["wheel.spin.video"].exists, "después del regalado quedan los de video")
    }
}
```

- [ ] **Step 2: Verlo fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionUITests/WheelUITests`.
Expected: FAIL — `gifts.wheel.open` no existe.

- [ ] **Step 3: La tarjeta y el empuje**

`FisuEvolution/UI/Wheel/WheelGiftCard.swift`:

```swift
import SwiftUI

/// La ruleta en Regalos: cuántos giros quedan hoy y el botón que la abre.
struct WheelGiftCard: View {
    let availability: WheelAvailability
    let open: () -> Void

    var body: some View {
        GameCard(style: availability.hasFreeSpin ? .highlighted(Color("PaletteYellow")) : .normal) {
            HStack(spacing: Tokens.s12) {
                GameIcon(artKey: "wheel_icon", size: 46) { WheelGlyph() }
                VStack(alignment: .leading, spacing: 2) {
                    Text("gifts.wheel.title")
                        .font(Tokens.body)
                    Text(verbatim: subtitle)
                        .font(Tokens.caption)
                        .opacity(0.75)
                }
                .foregroundStyle(Color("PaletteInk"))
                Spacer(minLength: Tokens.s8)
                ActionPill(titleKey: "gifts.wheel.open", systemImage: "arrow.clockwise.circle.fill",
                           tint: Color("PaletteOrange"), identifier: "gifts.wheel.open", action: open)
            }
        }
    }

    private var subtitle: String {
        if availability.bonus > 0 { return RewardCopy.text("gifts.wheel.bonus", String(availability.bonus)) }
        if availability.videoLeft > 0 { return RewardCopy.text("gifts.wheel.left", String(availability.videoLeft)) }
        return String(localized: "gifts.wheel.empty")
    }
}
```

`GiftsView.swift`:

1. Un estado más, junto a los otros `@State`:

```swift
    /// La ruleta se empuja dentro de esta misma hoja (PLAN-v2 E5: "vive en Regalos").
    @State private var showWheel = false
```

2. En el `body`, junto a las otras lecturas de una vez por evaluación:

```swift
        let wheel = gameState.wheelAvailability(storefrontAllows: false)
```

3. La tarjeta va después de la del cofre y antes de la racha, y la cascada corre un lugar:

```swift
                    section("gifts.section.wheel")
                    WheelGiftCard(availability: wheel) { showWheel = true }
                        .staggeredAppearance(index: chestRows)

                    section("gifts.section.daily")
                    DailyStrip(days: days)
                        .staggeredAppearance(index: chestRows + 1)
```

   y en los dos `ForEach` de abajo, `chestRows + 1 + offset` pasa a `chestRows + 2 + offset` y
   `chestRows + 1 + boosts.count + offset` a `chestRows + 2 + boosts.count + offset`.

4. Junto al `.toolbar` de la hoja:

```swift
            .navigationDestination(isPresented: $showWheel) {
                WheelView(close: { dismiss() })
                    // Empujada, la vista pierde el telón transparente de la hoja.
                    .clearNavigationBackdrop()
            }
```

5. Al `NavigationStack`, como el Menú, para que el "atrás" no salga azul:
   `.tint(Color("PaletteInk"))`.

(el comentario de la cascada del `VStack` dice "la fila 0 es el cofre si está, y si no la tira del
calendario": pasa a "…y si no la ruleta". Es el que el cambio vuelve mentira.)

- [ ] **Step 4: Los textos**

`Tools/v2/claves-pendientes/e5b-t4.json`:

```json
{
  "gifts.section.wheel": {"es": "La Ruleta", "en": "The Wheel"},
  "gifts.wheel.title": {"es": "La Ruleta del Conductor", "en": "The TV Host's Wheel"},
  "gifts.wheel.left": {"es": "Giros de hoy: %1$@", "en": "Spins today: %1$@"},
  "gifts.wheel.bonus": {"es": "Giros gratis: %1$@", "en": "Free spins: %1$@"},
  "gifts.wheel.empty": {"es": "Mañana hay más giros", "en": "More spins tomorrow"},
  "gifts.wheel.open": {"es": "Girar", "en": "Spin"}
}
```

- [ ] **Step 5: Verde, a mano y oráculo**

Run: Receta R con `-only-testing:FisuEvolutionUITests/WheelUITests -only-testing:FisuEvolutionUITests/BonusHUDUITests -only-testing:FisuEvolutionUITests/ChestOpeningUITests`
→ PASS (los dos de Regalos no cambiaron: la tarjeta nueva corre la cascada, no los
identificadores). `-only-testing:FisuEvolutionTests/LocalizationCompletenessTests` → PASS. A mano
(SE y iPad 13", Reduce Motion sí/no): Regalos → La Ruleta → girar por video (stub) → la rueda da
cinco vueltas y frena, un tic por rebanada (con sonido y háptico en un dispositivo); con Reduce
Motion salta al resultado; "repetir" una vez; la tabla abajo suma 100 %; en una tienda permitida
(simulador en Argentina) aparece el botón de 12 ORO; con 0 ORO tiembla y no gira. Capturas al
reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/UI/Wheel/WheelGiftCard.swift
git add FisuEvolution/UI/Gifts/GiftsView.swift
git add FisuEvolutionUITests/WheelUITests.swift
# + el catálogo o Tools/v2/claves-pendientes/e5b-t4.json, según la ola
git diff --cached --stat
git commit -m "feat(ruleta): la Ruleta en Regalos"
```

---

### Task 5: Las lecciones — el paquete, el colchón y la ruleta se enseñan la primera vez

**Objetivo:** la regla de E9 —toda mecánica nueva declara su lección— con el sistema de hoy
(`TutorialLesson` + `TutorialTarget` + `tutorial.tip.<id>`), como hizo E4b: un paquete esperando
enseña a tocarlo, un colchón esperando enseña a abrirlo, y la ruleta se enseña en Regalos después
de la lección de Regalos. Tocar el acceso cumple la lección. E9 las migra a su currículo; las
anclas usan los nombres que E9 ya eligió (`.sidePackages`, `.sideMattress`).

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift`
- Modify: `FisuEvolution/UI/Tutorial/TutorialAnchor.swift`
- Modify: `FisuEvolution/UI/Prizes/PrizeChips.swift` (las dos anclas)
- Modify: `FisuEvolution/Game/State/GameState+Prizes.swift` (tocar cumple la lección)
- Modify: `FisuEvolutionTests/TutorialTipsTests.swift`
- Strings: `Tools/v2/claves-pendientes/e5b-t5.json` (3 claves)

**Interfaces:**
- Consumes: T2 (`prizeAccess`, `packageTapped()`, `mattressTapped()`, los chips), T4 (la tarjeta
  de Regalos: la lección de la ruleta se cumple al abrir Regalos, `tutorialTipHandled(opening: .gifts)`).
- Produces: `GameState.TutorialLesson.packages`, `.mattress`, `.wheel`;
  `TutorialTarget.sidePackages`, `.sideMattress`.

- [ ] **Step 1: Los tests, en rojo**

En `FisuEvolutionTests/TutorialTipsTests.swift` (con su `makeGameState()` privado, que barre los
defaults y prende el director):

```swift
    @Test("un paquete esperando enseña a tocarlo, y tocarlo cumple la lección")
    func thePackagesLesson() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .packages {
            gameState.markLessonDone(lesson)
        }
        gameState.debugAddPackages(1)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .packages)
        #expect(gameState.showing == .tutorialTip)
        #expect(GameState.TutorialLesson.packages.anchorTarget == .sidePackages)
        _ = gameState.packageTapped()
        #expect(gameState.showing != .tutorialTip)
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.packages.defaultsKey))
    }

    @Test("un colchón esperando enseña a abrirlo, y tocarlo la cumple")
    func theMattressLesson() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .mattress {
            gameState.markLessonDone(lesson)
        }
        gameState.debugSpawnMattress()
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .mattress)
        gameState.mattressTapped()
        #expect(gameState.showing != .tutorialTip)
        #expect(UserDefaults.standard.bool(forKey: GameState.TutorialLesson.mattress.defaultsKey))
    }

    @Test("la ruleta se enseña después de Regalos, y abrir Regalos la cumple")
    func theWheelLesson() async {
        let gameState = await makeGameState()
        for lesson in GameState.TutorialLesson.allCases where lesson != .wheel && lesson != .gifts {
            gameState.markLessonDone(lesson)
        }
        gameState.refreshProjections()
        #expect(gameState.tutorialTip == nil, "sin la lección de Regalos dada, la ruleta espera")
        gameState.markLessonDone(.gifts)
        gameState.refreshProjections()
        #expect(gameState.tutorialTip?.lesson == .wheel)
        #expect(GameState.TutorialLesson.wheel.destinationScreen == .gifts)
        gameState.tutorialTipHandled(opening: .gifts)
        #expect(gameState.showing != .tutorialTip)
    }
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialTipsTests`.
Expected: no compila (`TutorialLesson.packages` no existe).

- [ ] **Step 3: Las lecciones**

`GameState+TutorialTips.swift`, en `enum TutorialLesson`, al final (después de `prestige`: las
más nuevas esperan a todas):

```swift
        /// Un Paquete de la Aduana esperando (E5).
        case packages
        /// El Colchón esperando (E5).
        case mattress
        /// La Ruleta, después de la lección de Regalos (E5).
        case wheel
```

y en los cuatro `switch`:

- `anchorTarget`: `case .packages: .sidePackages`, `case .mattress: .sideMattress`,
  `case .wheel: .gifts`.
- `destinationScreen`: `.wheel` va con `.gifts` (`case .gifts, .wheel: .gifts`, si el `switch`
  agrupa así; si no, `case .wheel: .gifts`); `.packages` y `.mattress` se suman a la fila de `nil`.
- `textKey`: `case .packages: "tutorial.tip.packages"`, `case .mattress: "tutorial.tip.mattress"`,
  `case .wheel: "tutorial.tip.wheel"`.
- `isEligible`:

```swift
        case .packages:
            // Hay uno que se puede abrir: con todo lleno, la lección mandaría a
            // tocar algo que tiembla y no hace nada.
            prizeAccess.packagesWaiting > 0 && !prizeAccess.packagesBlocked
        case .mattress:
            prizeAccess.mattressReady
        case .wheel:
            // Después de Regalos: la lección señala esa pestaña, y la de Regalos
            // es la que la presenta.
            prizeAccess.wheelSpinsReady > 0 && isLessonDone(.gifts)
```

`TutorialAnchor.swift`, en `enum TutorialTarget`, después de `prestige`:

```swift
    /// Los accesos de E5 (los nombres son los que E9 eligió para la columna
    /// lateral: el ancla viaja con el botón cuando E7b lo mude).
    case sidePackages
    case sideMattress
```

`PrizeChips.swift`: `PackageChip` suma `.tutorialAnchor(.sidePackages)` y `MattressChip`
`.tutorialAnchor(.sideMattress)`, después de su `accessibilityLabel`.

`GameState+Prizes.swift`:

```swift
    @discardableResult
    func packageTapped() -> PackageOpenResult {
        tutorialTipCompleted(.packages)
        let result = openPackage()
        refreshPrizeAccess()
        return result
    }

    func mattressTapped() {
        guard mattressWaiting, mattressPopup == nil, wheelSheet == nil else { return }
        tutorialTipCompleted(.mattress)
        mattressPopup = MattressPopup()
    }
```

- [ ] **Step 4: Los textos**

`Tools/v2/claves-pendientes/e5b-t5.json`:

```json
{
  "tutorial.tip.packages": {"es": "¡Llegó un Paquete de la Aduana! Tocalo: adentro viene un empleado.", "en": "A Customs Package arrived! Tap it: there's a worker inside."},
  "tutorial.tip.mattress": {"es": "Tus empleados escondieron plata en el colchón. Tocalo para abrirlo.", "en": "Your workers stashed cash in the mattress. Tap it to open it."},
  "tutorial.tip.wheel": {"es": "La Ruleta te espera en Regalos: giros nuevos todos los días.", "en": "The Wheel is waiting in Gifts: new spins every day."}
}
```

- [ ] **Step 5: Verde, a mano y oráculo**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialTipsTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionTests/PrizeAccessTests`
→ PASS (3 nuevos; los de siempre sin cambios: una partida nueva sigue sin lección). UI:
`-only-testing:FisuEvolutionUITests/TutorialUITests` → PASS. A mano con `--uitest-lessons
--uitest-packages=1`: el globo señala el chip del paquete; tocarlo lo cumple. Captura al reporte.
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Game/State/GameState+TutorialTips.swift
git add FisuEvolution/UI/Tutorial/TutorialAnchor.swift
git add FisuEvolution/UI/Prizes/PrizeChips.swift
git add FisuEvolution/Game/State/GameState+Prizes.swift
git add FisuEvolutionTests/TutorialTipsTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e5b-t5.json, según la ola
git diff --cached --stat
git commit -m "feat(tutorial): el paquete, el colchón y la ruleta se enseñan la primera vez"
```

---

### Task 6: `wheel_ready` — la ruleta avisa cuando vuelve a haber giros

**Objetivo:** la notificación que E11 le dejó a E5 ("giros nuevos de la ruleta"), con sus cinco
piezas: el caso en `NotificationKind`, la entrada en `notifications.json` (al final = la prioridad
más baja), la hora en `NotificationSnapshot` y en `moments`, los textos (sin anuncios ni precios:
los giros por video no se mencionan) y su test. Avisa sólo si ese día el jugador ya usó un giro
por video: los giros vuelven a la medianoche, y el horario silencioso los corre a las 9.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/NotificationsConfig.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/NotificationPlanner.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/NotificationPlannerTests.swift`
- Modify: `FisuEvolution/Resources/Config/notifications.json`
- Modify: `FisuEvolution/Game/State/GameState+Notifications.swift` (E11 T6)
- Modify: `FisuEvolution/Game/State/GameState+Wheel.swift`
- Modify: `FisuEvolutionTests/NotificationsContentTests.swift`
- Create: `FisuEvolutionTests/WheelReadyNotificationTests.swift`
- Strings: `Tools/v2/claves-pendientes/e5b-t6.json` (3 claves)

**Interfaces:**
- Consumes: E5a T8 (`spinWheel`, `wheelDay`); **E11 T1** (`NotificationPlanner`), **T2**
  (`notifications.json` validado), **T4** (una fila de Ajustes por motivo, `settingsKey`),
  **T6** (`notificationSnapshot(now:)`).
- Produces: `NotificationKind.wheelReady = "wheel_ready"`; `NotificationSnapshot.wheelSpinsReadyAt: TimeInterval?`
  (último parámetro del `init`, con default `nil`); `GameState.wheelSpinsReadyAt(now:calendar:) -> TimeInterval?`.

- [ ] **Step 0: E11 está entera**

Run (uno por llamada):

```bash
grep -n "func notificationSnapshot" FisuEvolution/Game/State/GameState+Notifications.swift
grep -rn "settingsKey" FisuEvolution/UI/Menu/SettingsView.swift
```

Expected: las dos (E11 T6 y T4). Si falta, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`NotificationPlannerTests.swift`: el `plan(leavingAt:…)` privado suma el parámetro y se lo pasa al
snapshot:

```swift
    private func plan(
        leavingAt now: TimeInterval,
        producesOffline: Bool = true,
        capHours: Double = 10,
        dailyClaimedToday: Bool = true,
        wheelReadyAt: TimeInterval? = nil,
        config: NotificationsConfig = fxNotifications(),
        preferences: NotificationPreferences = NotificationPreferences()
    ) -> [PlannedNotification] {
        NotificationPlanner.plan(
            NotificationSnapshot(
                now: now,
                producesOffline: producesOffline,
                offlineCapHours: capHours,
                dailyClaimedToday: dailyClaimedToday,
                wheelSpinsReadyAt: wheelReadyAt
            ),
            config: config,
            preferences: preferences,
            calendar: ba.calendar
        )
    }
```

y dos casos en `// MARK: Cada motivo`:

```swift
    @Test("la ruleta avisa cuando vuelven los giros, corrida fuera del silencio")
    func wheelReadyAfterTheQuietHours() throws {
        let midnight = try ba.at(6, 0)
        let nine = try ba.at(6, 9)
        let planned = plan(leavingAt: try ba.at(5, 20), producesOffline: false, wheelReadyAt: midnight)
        #expect(fireAt(.wheelReady, in: planned) == nine)
    }

    @Test("sin giros por recuperar, la ruleta no avisa")
    func noWheelNoNotice() throws {
        #expect(fireAt(.wheelReady, in: plan(leavingAt: try ba.at(5, 20))) == nil)
    }
```

`NotificationsContentTests.catalogOrder` pasa a:

```swift
    @Test("los cuatro motivos de la 2.0, en su orden de prioridad")
    func catalogOrder() {
        #expect(config.kinds == [.vaultFull, .dailyReady, .comeback, .wheelReady])
    }
```

`FisuEvolutionTests/WheelReadyNotificationTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("La ruleta en el aviso de la ausencia")
@MainActor
struct WheelReadyNotificationTests {
    @Test("sin giros por video hoy no hay nada que avisar")
    func anUntouchedWheelIsQuiet() async {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        #expect(gameState.wheelSpinsReadyAt(now: now) == nil)
        #expect(gameState.notificationSnapshot(now: now)?.wheelSpinsReadyAt == nil)
    }

    @Test("con un giro por video hoy, los giros vuelven a la medianoche")
    func aSpinTodayMeansMidnight() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        _ = try #require(gameState.spinWheel(.video, now: now))
        let calendar = Calendar.current
        let midnight = try #require(calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: Date(timeIntervalSince1970: now))
        )).timeIntervalSince1970
        #expect(gameState.wheelSpinsReadyAt(now: now) == midnight)
        #expect(gameState.notificationSnapshot(now: now)?.wheelSpinsReadyAt == midnight)
    }

    @Test("un giro regalado no cuenta: no se perdió nada")
    func aBonusSpinIsNotAReason() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        gameState.debugAddWheelSpins(1)
        _ = try #require(gameState.spinWheel(.bonus, now: now))
        #expect(gameState.wheelSpinsReadyAt(now: now) == nil)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter NotificationPlannerTests`
Expected: no compila (`wheelSpinsReadyAt` no existe en `NotificationSnapshot`).

- [ ] **Step 3: EconomyKit**

`NotificationsConfig.swift`, en `enum NotificationKind`, al final:

```swift
    /// La ruleta tiene giros nuevos (E5).
    case wheelReady = "wheel_ready"
```

`NotificationPlanner.swift`, en `NotificationSnapshot`:

```swift
    /// Cuándo vuelve a haber giros de la ruleta (E5), o `nil` si no hay por qué avisar.
    public var wheelSpinsReadyAt: TimeInterval?

    public init(
        now: TimeInterval,
        producesOffline: Bool,
        offlineCapHours: Double,
        dailyClaimedToday: Bool,
        wheelSpinsReadyAt: TimeInterval? = nil
    ) {
        self.now = now
        self.producesOffline = producesOffline
        self.offlineCapHours = offlineCapHours
        self.dailyClaimedToday = dailyClaimedToday
        self.wheelSpinsReadyAt = wheelSpinsReadyAt
    }
```

y en `moments(for:config:calendar:)`, antes de `return moments`:

```swift
        if let wheel = snapshot.wheelSpinsReadyAt {
            moments.append(PlannedNotification(kind: .wheelReady, fireAt: wheel))
        }
```

- [ ] **Step 4: La app y el dato**

`notifications.json`, al final de `notifications`: `{ "id": "wheel_ready" }`.

`GameState+Wheel.swift`:

```swift
    /// Cuándo vuelven los giros por video, si hoy se usó alguno: la medianoche
    /// (el día del diario). Sin giros por video usados hoy, nada que avisar.
    func wheelSpinsReadyAt(now: TimeInterval, calendar: Calendar = .current) -> TimeInterval? {
        guard let wheel = player?.meta.engagement.wheel,
              wheel.day == Self.wheelDay(now), wheel.videoSpinsUsed > 0
        else { return nil }
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: now))
        return calendar.date(byAdding: .day, value: 1, to: today)?.timeIntervalSince1970
    }
```

`GameState+Notifications.swift` (E11 T6), en `notificationSnapshot(now:)`, el `return` suma:

```swift
            dailyClaimedToday: player.meta.daily.lastClaimDay == today,
            wheelSpinsReadyAt: wheelSpinsReadyAt(now: now)
```

`Tools/v2/claves-pendientes/e5b-t6.json` (sin "gratis", "video" ni precios: los vigila
`NotificationsContentTests.copyNeverSells`):

```json
{
  "notif.wheel_ready.title": {"es": "¡La Ruleta tiene giros nuevos!", "en": "The Wheel has new spins!"},
  "notif.wheel_ready.body": {"es": "El Conductor ya está calentando el estudio. Vení a girar.", "en": "The TV host is warming up the studio. Come spin."},
  "settings.notifications.wheel_ready": {"es": "La Ruleta", "en": "The Wheel"}
}
```

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter NotificationPlannerTests` → PASS (2
nuevos). Receta R con
`-only-testing:FisuEvolutionTests/WheelReadyNotificationTests -only-testing:FisuEvolutionTests/NotificationsContentTests -only-testing:FisuEvolutionTests/NotificationsWiringTests -only-testing:FisuEvolutionTests/LocalizationCompletenessTests -only-testing:FisuEvolutionTests/SettingsPersistenceTests`
→ PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/NotificationsConfig.swift
git add Packages/EconomyKit/Sources/EconomyKit/NotificationPlanner.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/NotificationPlannerTests.swift
git add FisuEvolution/Resources/Config/notifications.json
git add FisuEvolution/Game/State/GameState+Notifications.swift
git add FisuEvolution/Game/State/GameState+Wheel.swift
git add FisuEvolutionTests/NotificationsContentTests.swift
git add FisuEvolutionTests/WheelReadyNotificationTests.swift
# + el catálogo o Tools/v2/claves-pendientes/e5b-t6.json, según la ola
git diff --cached --stat
git commit -m "feat(notif): la Ruleta avisa cuando vuelve a haber giros"
```

---

### Task 7: Cierre de E5

**Objetivo:** la verificación de punta a punta de la épica entera (E5a + E5b) y la documentación.
La hace el controlador.

- [ ] **Step 1: Oráculo completo**

Run: `Tools/v2/oraculo.sh completo`.
Expected: `VERDE`, con las suites nuevas de E5b en la salida: `WheelGeometryTests`,
`RewardCopyTests`, `PrizeAccessTests`, `PickupLayoutTests`, `PickupControllerTests`,
`PackageOpeningPlayerTests`, `WheelReadyNotificationTests`; y las de UI `PrizesUITests` y
`WheelUITests`. `rojos-declarados.txt` no cambió por E5.

- [ ] **Step 2: Los escenarios a mano (SE y iPad 13", Reduce Motion sí/no)**

1. Con `--uitest-engagement` y los relojes de `packages.json`/`treasures.json` bajados en un build
   local (no se commitea): cae un paquete (chip "×1" y una caja en el tablero), después otro; con
   dos, no cae un tercero; a los minutos, el colchón.
2. Abrir un paquete con FisuJobs abierto encima no puede pasar (la hoja tapa el tablero); con la
   hoja cerrada: la caja se abre en su lugar y llega el empleado. Home en medio de la apertura y
   volver: el empleado ya está (E1 lo asentó al irse).
3. Lluvia de Paquetes (`--uitest-event=lluvia_paquetes`): cae uno cada 12 s mientras se los va
   abriendo; Piquete: el reloj se frena.
4. El Conductor (`--uitest-visitor=conductor_ruleta`): aceptar → al cerrarse el popup se abre la
   ruleta con un giro gratis.
5. La ruleta: seis giros por video (stub), el séptimo dice "mañana"; "La ruleta: un día nuevo"
   del panel devuelve los seis; con un cofre sin nada que dar (todas las pintas del callejón) la
   rueda tiene nueve rebanadas y la plata de 30 min pesa 23 %.
6. Matar la app en medio del giro: al volver, el premio está acreditado.

- [ ] **Step 3: Documentación (controlador)**

1. `Docs/SESION-<fecha>-v2-e5.md` (el de E5a, ampliado): la tabla por tarea de E5b con su commit,
   las capturas de los reportes y el porqué de cada default de "Para el dueño".
2. `Docs/HANDOFF.md`:
   - **§4**: "E5 — Paquete de la Aduana, El Colchón y Ruleta": el motor en `EconomyKit/Prizes/`,
     `prizeAccess` como la única fuente de los accesos, los chips y las cajas, la apertura en el
     turno del tablero, la ruleta que acredita antes de animar, Regalos, `wheel_ready`.
   - **§5**: los defaults de las dudas que el dueño no cambió.
   - **§7**: las trampas nuevas — "la ruleta dibuja la tabla EFECTIVA (`wheelSegments`), nunca
     `content.wheel.segments`"; "la caja del paquete es parte del turno del tablero: un
     `abortBoardCelebration` sin `packageOpening.cancel()` deja la caja huérfana"; "las cajas y el
     colchón se paran a ≥ 72 pt de los bordes y al costado del visitante (`PickupLayoutTests`): si
     E7b ensancha la columna, ese test se pone rojo"; "un giro regalado por un visitante abre la
     ruleta al cerrarse su popup (`wheelOpensAfterVisit`); por eso el `onDismiss` de esa hoja"; las
     que aparezcan.
   - **§9**: los dos planes y la sesión.
3. `Docs/PLAN-v2.md`: E5 marcada hecha, con los desvíos (las dudas que el dueño confirmó).

---

## Lo que E5 le deja a otras épicas

- **E6 (tienda de ORO y ofertas):** `OddsDisclosureView` y `RewardCopy` son los suyos para el
  cofre por ORO y para describir el contenido de las ofertas; `LootBoxGate` apaga el cofre por ORO
  igual que el giro; "Giro extra de ruleta" ya existe (`spinWheel(.oro, storefrontAllows:)`); el
  "mejor proveedor" y los "+1/+2/+3 giros diarios" enchufan en un solo lugar cada uno (E5a, "Lo que
  E5a le deja"); "Mudanza = 3 Paquetes" es `grant(.package(3), …)`.
- **E7b (columna lateral):** la columna lee `GameState.prizeAccess` (paquetes, trabado, colchón,
  giros) y llama a `packageTapped()`, `mattressTapped()` y `openWheel()`; las anclas
  `.sidePackages`/`.sideMattress` se mudan con los botones. Cuando la columna exista, los chips de
  `StageChips` pueden quedarse o irse (decisión de E7b con el 🔒 del dueño); las cajas del tablero
  no la pisan (`edgeClearance`). La lluvia de paquetes por video (unidad `treasure`) es
  `grant(.modifier(effect: .packageRateMultiplier, magnitude: 10, seconds: 60), …)`. Los
  intersticiales: las hojas de E5 ya escriben `uiCoversBoard`.
- **E8 (arte):** las claves del atlas `ui`: `pickup_package`, `pickup_package_lid` (la tapa
  aparte, para que vuele), `pickup_mattress` (más ancho que alto; abierto con plata, si se hace,
  sería `pickup_mattress_open` y se suma) y `wheel_icon`; el marco, el puntero y los íconos de la
  ruleta siguen por código salvo que el dueño quiera arte (PLAN-v2 §5 los estima en ~6 piezas).
  `sfx_wheel_tick` ya suena.
- **E9 (tutorial v2):** tres lecciones con el sistema de hoy (`.packages`, `.mattress`, `.wheel`)
  para migrar a su currículo; la de la ruleta señala la pestaña Regalos hasta que exista
  `.sideWheel` en la columna. El paquete es una "primera vez interactiva" candidata a
  `TutorialInlineCard`.
- **E11:** `wheel_ready` está; queda último en prioridad (duda 8).
- **E10 (App Review):** la ruleta muestra su tabla en la misma pantalla y el colchón en su popup;
  el giro con ORO se esconde en Bélgica y Australia (`restrictedStorefronts`); capturas posibles
  con `--uitest-wheel-spins=N`, `--uitest-packages=N` y `--uitest-mattress`.
- **E2b:** ver E5a.

## Para el dueño / dudas

Las de E5a siguen en pie. Éstas son de E5b; **ninguna frena**: la ejecución sigue con el default.

1. **Los accesos antes de E7b, y el 🔒 de la columna.** E5b no pone nada en la columna lateral:
   el paquete y el colchón se tocan desde un chip bajo el HUD (al lado del visitante) y desde sus
   cajas en el tablero; la ruleta, desde Regalos. Las cajas se paran a ≥ 72 pt de cada borde y al
   costado de donde se para un visitante, así que **no dependen de cómo se resuelva el 🔒**: si la
   columna queda, E7b muda los chips a ella leyendo `prizeAccess`; si se descarta en iPhone, los
   chips siguen siendo el acceso. **Default:** así. PLAN-v2 dice "en el borde del tablero": se leyó
   como el borde de abajo (la línea del escenario), porque los bordes de los costados son de la
   columna y de la botonera.
2. **La apertura del paquete es el turno del tablero**, no un `.packageOpening` en la cola de
   celebraciones (PLAN-v2 lo listaba en E4 y E4b lo pasó a E5). Así la caja hereda la
   revalidación, el salto, el watchdog, el asiento al irse y la revelación de E1, sin un turno
   más. **Default:** así.
3. **La rueda tiene rebanadas iguales y la tabla de probabilidades abajo.** Con rebanadas del
   tamaño de su peso, el ×5 (3 %) y el cofre (5 %) serían líneas sin ícono. **Default:** iguales,
   con la tabla siempre visible en la misma pantalla.
4. **Sin punto del paquete en la botonera del ascensor** (E3a duda 6 se lo dejaba a E5): el
   paquete no está en ningún piso hasta que se abre. **Default:** no se agrega.
5. **La pestaña Regalos no prende su puntito por los giros de la ruleta**: habría giros nuevos
   todos los días y el punto quedaría siempre prendido (el mismo criterio que con los cofres que no
   se pueden abrir). **Default:** no.
6. **El Conductor abre la ruleta al irse.** Un giro regalado por un visitante deja una bandera y
   la ruleta se abre cuando su popup termina de cerrarse; los giros regalados por otras fuentes no
   la abren. **Default:** así.
7. **La lección de la ruleta señala Regalos y llega después de la de Regalos.** **Default:** así;
   E9/E7b la mudan a `.sideWheel`.
8. **`wheel_ready`**: avisa a la medianoche (corrido a las 9 por el silencio) sólo si ese día se
   usó un giro por video, y es el último del catálogo: con el tope de 3 avisos por ausencia, en
   una ausencia larga le ganan la caja fuerte, el diario y el regreso. **Default:** así; cambiar la
   prioridad es reordenar `notifications.json`.
9. **`OddsDisclosureView` y `RewardCopy` nacen en E5** (PLAN-v2 ponía la primera en E6): los
   necesita la ruleta antes. `RewardCopy` cubre los 12 tipos de `RewardSpec`, aunque E5 use 6, para
   que el `switch` sin `default` no deje un tipo mudo. **Default:** así.
10. **El colchón dice "20 min de producción" antes de abrirlo y el monto exacto después.**
    **Default:** así (el monto de antes cambiaría mientras el popup está abierto).
11. **El giro con ORO se esconde, no se deshabilita**, donde la tienda no lo permite; con poco
    ORO se muestra y tiembla. **Default:** así.
12. **Hasta 3 cajas en el tablero**; el chip dice cuántas hay de verdad. Las cajas se esconden
    durante una celebración que apaga la UI. **Default:** así.
13. **Reduce Motion**: la ruleta salta al resultado, las cajas aparecen con fundido y la apertura
    es un fundido corto sin sacudida ni monedas. **Default:** así.
