# E9b — Tutorial v2, el currículo, el Tour de novedades y los Ajustes (repaso y "Resetear partida") · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que el tutorial de la 2.0 explique **absolutamente todo** (pedido del dueño): cada
mecánica con su lección, en el momento en que aparece; que los veteranos de la v1 reciban un Tour
de lo nuevo; que Ajustes ofrezca "Ver tutorial de nuevo" y "Ver novedades de la 2.0" en modo
demostración, y una **zona de peligro** con "Resetear partida" en tres pasos (resumen con números,
escribir RESETEAR, mantener 3 s) que conserva lo comprado —el ORO comprado sólo si no se gastó:
`min(saldo, comprado)`— sin acreditar dos veces ninguna compra.

**Architecture:** E9a dejó el motor (director, pasos, señales, coach, manos, tarjetas y el
registro de cobertura con 20 huecos). E9b es **contenido + dos guiones + un reset**: T1–T3
escriben las lecciones (`TutorialLesson.steps`, su señal de elegibilidad, su ancla y sus textos)
hasta vaciar `TutorialMechanic.knownGaps`; T4 y T5 son dos guiones de demostración del mismo
director (`.tour`, `.replay`); el reset es una función pura en EconomyKit (`ResetPlan`: lo que se
muestra es exactamente lo que se ejecuta), una época de reset en el save para que CloudKit no
resucite la partida (`resetEpoch`), la ejecución en la app (`GameState+Reset`: backup, partida
nueva, entitlements re-empujados, banderas de juego borradas y las del dispositivo intactas) y la
pantalla (`ResetGameFlowView`).

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
StoreKit 2 · EconomyKit (SPM puro) · Swift Testing · XCUITest · XcodeGen.

**Fuente:** `Docs/PLAN-v2.md` §4 "E9" (currículo, Tour, "Ver tutorial de nuevo", Ajustes, reset
técnico, tests) y §2 ("Tutorial (ítem 14)", "Reset", "Válvulas del tutorial"); E9a
(`2026-10-07-v2-e9a-tutorial-tour-ajustes.md`) es la base: **sus Global Constraints, su
"Verificación", su Receta R y su tabla de herencia valen acá enteras**. Abajo van los agregados.

**Rama de la épica:** `v2/e9-tutorial` (la misma de E9a).

## Global Constraints (además de las de E9a)

- **La regla de oro de la v1 sigue**: una lección nace sólo cuando en ESE momento hay algo que
  hacer en su pantalla (su `isEligible` es una proyección barata, nunca una fila computada: corre
  a 8 Hz).
- **Cada lección nueva**: un caso en `TutorialLesson` con `steps`, `introducedIn`, su línea de
  `isEligible`, sus claves `tutorial.<lección>.<paso>` (minúscula y `_`), su ancla publicada en la
  vista y su `TutorialMechanic` sacado de `knownGaps`. `TutorialCoverageTests` y
  `TutorialCurriculumTests` lo vigilan.
- **Las claves viejas `tutorial.tip.<x>` de una lección reescrita se borran** en la misma tarea
  (`Tools/v2/catalogo.py quitar`), salvo las de las lecciones heredadas que T3 conserva.
- **El repaso y el Tour no tocan el save** (ni el cofre de bienvenida: `welcomeChestGiven` no se
  lee ni se escribe) y no exigen acciones: son demostraciones (`TutorialRun.isDemo`).
- **El reset**: lo que se muestra sale del mismo `ResetPlan` que se ejecuta. Se conserva lo
  comprado con plata (`removedAds`, `ownedSkins`, `creditedPurchases`, el mapa de compras de ORO
  de E1 T6c y lo pagado de las ofertas) y `oro = min(saldo, comprado)`. Todo lo demás es partida
  nueva. Antes de escribir, una copia en `SaveBackups/` (nunca se borra). Las banderas de
  dispositivo no se tocan (E9a, Global Constraints).
- **Ningún botón del reset se deshabilita: tiembla** (PLAN-v2 §2). La casilla, la palabra y los
  3 s se piden en orden, y saltear uno sacude el botón que no corresponde.
- **`SettingsView.swift` es 🔥**: T5 y T9 lo tocan de a una, después de E11 T4 y E7b-a T5. La
  sección de privacidad (UMP) de E7b-a T5 **no se rehace**; la zona de peligro va **última**, después
  de "Acerca de".

## Verificación

La de E9a (oráculo, Receta R con `build/DD-e9` y simulador `e9-…`). `rapido` al cerrar T6 y T7;
`completo` al cerrar T1–T5, T8, T9 y la épica (T10). Los UI tests nuevos
(`WhatsNewTourUITests`, `TutorialReplayUITests`, `SettingsResetUITests`) entran solos al
`completo`. Cada tarea con UI se mira en el **iPhone SE** y el **iPad Pro 13"**, con Reduce Motion
prendido y apagado; capturas al reporte.

## Las referencias de PLAN-v2 E9 que toca E9b, verificadas contra el árbol (`32d1300`) y los planes

| Lo que cita el plan | Dónde está | Qué hace E9b |
|---|---|---|
| "Lecciones, cada una cuando su función aparece" (la lista larga) | 18 lecciones al cierre de E7b (9 de la v1 + `share`, `visitor`, `eventChip`, `album`, `packages`, `mattress`, `wheel`, `sideRail`, `mergeAllVideo`); las de E9a son de un paso | T1–T3 |
| "toda mecánica tiene su lección" | `TutorialMechanic.knownGaps` (20, E9a T9) | T1–T3 lo vacían; T3 exige cero |
| "Los veteranos (hay save y no hay `v2.version`) reciben el Tour" | `TutorialFlags.tourPending` (E9a T3) | T4 |
| "«Ver tutorial de nuevo» (`settings.tutorial.replay`) y «Ver novedades de la 2.0»" | no existen | T5 |
| "Terminar repaso, sólo en el repaso" | `TutorialCard.onEnd` (E9a T5) | T5 |
| "Opciones de privacidad (UMP)" | **la hizo E7b-a T5** (su duda 10) | nada: el Tour la nombra |
| "Zona de peligro: cinta y tarjeta rosa, `ActionPill` «Resetear partida» → `ResetGameFlowView`, tres pasos" | `SettingsView.swift:96-116` (las secciones del `VStack`) | T9 |
| "`ResetPlan` puro: lo que se muestra es exactamente lo que se ejecuta" | no existe | T7 |
| "Contador nuevo `meta.oroPurchasedLifetime`. Hoy no existe" | **viejo**: lo creó E1 T4 y E1 T6c lo dejó **calculado** desde un mapa crece-sólo (`oroPurchases` + `revokedPurchases`, puerta `recordOroPurchase`) | T7 lo lee; no lo crea |
| "`creditedPurchases` intactos (si no, una transacción re-entregada se acreditaría dos veces)" | `MetaState.creditedPurchases` (`PlayerState.swift`), guarda en `creditStorePurchase` (`GameState+Store.swift:231-235`) | T7, T8 (`GameStateResetTests`) |
| "Backup del save antes de sobrescribir" | `SaveBackupStore` (`rotate`, `keepPremigration`, `keepUnreadable`), `PlayerStateRepository.keepSnapshotCopy()` | T8: `keepBeforeReset` |
| "`StoreManager.repushEntitlements()` público: hoy `applyStoreEntitlements` no hace nada si el estado no cambió" | `StoreManager.pushEntitlementsToGameState()` privado (`StoreManager.swift:354-363`); el `guard` de `GameState+Store.swift:215` | T8 |
| "Se borran las banderas de tutorial y se conservan las de dispositivo. Arranca el núcleo y vuelve el cofre" | `TutorialFlags.wipeGameFlags()` (E9a T2); `beginTutorialPhase()`; `welcomeChestGiven` | T8 |
| "⚠️ Antes de prender CloudKit hace falta un `resetEpoch`" | `SaveConflictResolver.pickWinner` (`SaveConflictResolver.swift:76-81`): gana el mayor `lifetimeEarnings` → la partida vieja ganaría | T6 |
| `GameConfirmCard` "E9 la reusa en el reset" (E3b T2) | `UI/Art/GameConfirmCard.swift` | T9 la usa para salir del flujo a medio camino |
| "UI: `SettingsResetUITests` (escribir RESET + presionar 3,5 s)" | no existe | T9 |

## Lo que E9b usa de otras épicas (el paso 0 de cada tarea lo comprueba)

| Pieza | La deja | La usa |
|---|---|---|
| `quickHireOffer` (`affordable`, `blocker`, `isPinned`) | E3b T5–T6 | T1 (`quickHire`, `floorFull`) |
| `ElevatorPanel` (display + botones), `floorMap` (ocupados/capacidad/desbloqueado) | E3a T8 | T1 (`elevator`, `staffedFloors`) |
| `StaffedFloors`, `EconomyConfig.staffedBonusPerFloor` | E2a T4, T13 | T1 |
| `PrestigePreview.isBlockedByWall`, `wallGoalShortText` | E2a T8 | T1 (`prestigeGate`) |
| `JobRow.priceTrendText` ("+6 %") | E2a T10 | T2 (`hirePriceStep`) |
| `unlockedTabs`, `newTabs` (`GameState`) | E3a T9 | T2 (`newTabs`, `store`, `menuSwipe`) |
| `MenuPagerView` y `PagerDots` (ancla `.menuPager`, E9a T7) | E3b T3 | T2 (`menuSwipe`) |
| `GameContent.oroShop`, la mitad "Gastar ORO" con `.tutorialAnchor(.oroShop)`; la fila de Suerte y su tabla; las pintas de ORO | E6a T4, T7, T8; E6b T4 | T2 |
| el ×3 pendiente del próximo offline/diario; el modificador del auto-tap | E6a T5 | T2 |
| `offerChip` y la oferta abierta | E6a T12 | T2 |
| lugares extra (nivel del permanente), efectos comprados | E6b T6–T7, T4 | T2 |
| `RewardedInterstitialIntroView` (la pausa se explica sola) | E7b-a T3 | registro (E9a T9) |
| `OffersState` (`active`, `lastClosedAt`, `everOpened`, `purchases`), `EngagementState.firstLaunchDay`, `shop` | E6a T1 | T7 |
| `oroPurchases`, `revokedPurchases`, `oroPurchasedLifetime` (calculado), `recordOroPurchase` | E1 T6c | T6, T7, T8 |
| la sección de avisos y la de privacidad de Ajustes | E11 T4, E7b-a T5 | T5, T9 |
| `GameConfirmCard` | E3b T2 | T9 |

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `FisuEvolution/Game/State/GameState+TutorialTips.swift` | las lecciones: casos, `steps`, `introducedIn`, `isEligible`, el orden | 1–3 |
| vistas que publican anclas nuevas: `UpgradesView`, `MenuView`, `ElevatorPanel`, `HUDView`, `GiftsView`, `CustomizationView`, `FisuJobsView`, `StoreView`, `ActiveBonusBar`, `PrestigeButton` | una línea `.tutorialAnchor(…)` cada una (y la señal donde haga falta) | 1, 2 |
| `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` | las anclas nuevas | 1, 2 |
| `FisuEvolution/Game/Tutorial/TutorialCurriculum.swift` | `knownGaps` se vacía (T3); `tour`, `replay(…)` (T4, T5) | 1–5 |
| `FisuEvolution/Game/State/GameState+Tutorial.swift` | el Tour y el repaso | 4, 5 |
| `FisuEvolution/UI/Tutorial/TutorialOverlay.swift` | "Terminar repaso" | 5 |
| `FisuEvolution/UI/Menu/SettingsView.swift` 🔥 | la sección "Tutorial" (T5), la zona de peligro (T9) | 5, 9 |
| `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` 🔥 | `MetaState.resetEpoch` | 6 |
| `Packages/EconomyKit/Sources/EconomyKit/SaveConflictResolver.swift` | el reset gana entero | 6 |
| `Packages/EconomyKit/Sources/EconomyKit/ResetPlan.swift` | **nuevo** — qué se borra, qué se conserva, con números | 7 |
| `FisuEvolution/Game/State/GameState+Reset.swift` | **nuevo** — la ejecución | 8 |
| `FisuEvolution/Persistence/SaveBackupStore.swift`, `PlayerStateRepository.swift` | la copia de antes del reset | 8 |
| `FisuEvolution/Managers/Store/StoreManager.swift`, `FisuEvolution/Game/State/GameState+Store.swift` | `repushEntitlements()`, `applyStoreEntitlements(…, force:)` | 8 |
| `FisuEvolution/Game/State/GameState+Debug.swift` | `debugResetSave` delega en el reset real; `--uitest-veteran` | 4, 8 |
| `FisuEvolution/UI/Menu/ResetGameFlowView.swift` | **nuevo** — los tres pasos | 9 |
| tests | `TutorialLessonsTests` (T1–T3), `TutorialTourTests`, `TutorialReplayTests`, `ResetEpochTests` (EK), `ResetPlanTests` (EK), `GameStateResetTests`, `ResetGameFlowTests`; UI: `TutorialLessonsUITests`, `WhatsNewTourUITests`, `TutorialReplayUITests`, `SettingsResetUITests` | 1–9 |

## Orden, olas y paralelismo

| T | Qué | 🔥 calientes | Tibios / compartidos | Depende de | Modelo |
|---|---|---|---|---|---|
| 1 | lecciones del tablero y la torre | catálogo (dueña) | `+TutorialTips`, `TutorialAnchor`, `UpgradesView`, `MenuView`, `ElevatorPanel`, `HUDView`, `PrestigeButton` | E9a-T9; E3a-T8, E3b-T8, E2a-T8, E2a-T13 | sonnet |
| 2 | lecciones de la economía, el ORO, la tienda y el menú | catálogo (dueña o snapshot) | `+TutorialTips`, `TutorialAnchor`, `GiftsView`, `CustomizationView`, `FisuJobsView`, `StoreView`, `ActiveBonusBar` | T1 (`+TutorialTips`); E2a-T10, E3a-T9, E6a-T8, E6a-T12, E6b-T7 | sonnet |
| 3 | las heredadas al formato y la cobertura completa | catálogo (snapshot) | `+TutorialTips`, `TutorialCurriculum`, tests | T2 | sonnet |
| 4 | el Tour de novedades | catálogo (snapshot) | `+Tutorial`, `TutorialCurriculum`, `+Debug` | E9a-T6; T3 (marca lecciones que T1–T3 definen) | sonnet |
| 5 | el repaso y "Ver novedades" en Ajustes | `SettingsView.swift`, catálogo | `+Tutorial`, `TutorialOverlay` | T4; **E11-T4, E7b-a-T5** (dueños previos de `SettingsView`) | sonnet |
| 6 | `resetEpoch` | `PlayerState.swift` (sólo `MetaState`) | `SaveConflictResolver` (EK) | **E1-T6c** | sonnet |
| 7 | `ResetPlan` | — | — | T6; **E1-T6c**, **E6a-T1** (`OffersState`) | sonnet |
| 8 | el reset en la app | — | `+Reset` (nuevo), `+Debug`, `+Store`, `StoreManager`, `SaveBackupStore`, `PlayerStateRepository` | T7; E9a-T3 (`TutorialFlags`); **E6a-T11** (último en `+Store`) | sonnet (revisión opus) |
| 9 | la pantalla del reset y la zona de peligro | `SettingsView.swift`, catálogo | `ResetGameFlowView` (nuevo) | T8, T5 (`SettingsView` de a una); E3b-T2 (`GameConfirmCard`) | sonnet |
| 10 | cierre de E9 (controlador) | — | `Docs/` | E9a entera, T1–T9 | controlador |

```
Ola A (fría, puede ir al lado de E9a T2–T9)    T6 resetEpoch → T7 ResetPlan → T8 el reset en la app
Ola B (tras E9a T9)                            T1 lecciones del tablero (dueña del catálogo)
Ola C                                          T2 lecciones de la economía ║ T9 pantalla del reset (si T5 no está en vuelo)
Ola D                                          T3 heredadas y cobertura → T4 el Tour
Ola E (caliente: SettingsView)                 T5 el repaso
Ola F                                          T10 cierre
```

T5 y T9 nunca en la misma ola (`SettingsView`). T6 toca `PlayerState.swift` 🔥: no al lado de
otra tarea dueña de `MetaState` (a esta altura, ninguna: E2b no lo toca).

## Helpers de test que EXISTEN

Los de E9a, más:

| Necesidad | Qué usar | Dónde |
|---|---|---|
| un save con ORO comprado | `recordOroPurchase(transactionID:amount:)` | E1 T6c (`MetaState`) |
| una compra re-entregada | `creditStorePurchase(_:transactionID:)` con el mismo id | `GameState+Store.swift:231` |
| entrada del catálogo de productos | `ProductCatalog.load(from: .main)`, `entry(for:)` | `ProductCatalog.swift` |
| partida nueva igual a la del bootstrap | `GameState.newGame(content:)` (privado hoy: T8 lo vuelve interno) | `GameState.swift:595` |
| fixtures de UI | `--uitest-reset`, `--uitest-skip-tutorial`, `--uitest-lessons`, `--uitest-lesson=<id>`, `--uitest-tutorial-lock=0.3`, `--uitest-oro=<n>` (E6a), `--uitest-coins`, `--uitest-unlock-tower` | `+Debug` |

---

### Task 1: Las lecciones del tablero y la torre

**Objetivo:** el atajo con sus cinco pasos (tocar → mantener → fijar → soltar → el botón gris), el
ingreso pasivo, los multiplicadores, el organigrama, la botonera del ascensor (display, desplegar,
tocar un piso, el mapa), deslizar pisos, el piso lleno, los pisos en marcha, el piso móvil para
reencarnar, la reencarnación y la ficha del personaje.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift`
- Modify: `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` (`.upgradesPassive`, `.upgradesRow`, `.menuOrgChart`, `.elevatorDisplay`, `.elevatorButtons`)
- Modify: `FisuEvolution/UI/Store/UpgradesView.swift`, `FisuEvolution/UI/Menu/MenuView.swift`, `FisuEvolution/UI/HUD/ElevatorPanel.swift` (E3a T8)
- Modify: `FisuEvolution/Game/State/GameState+Tutorial.swift` (`tutorialBoardTarget` también para lecciones)
- Modify: `FisuEvolution/Game/Tutorial/TutorialCurriculum.swift` (`knownGaps` −8)
- Strings: catálogo (`e9b-t1.json` + `e9b-t1.quitar`)
- Create: `FisuEvolutionTests/TutorialLessonsTests.swift`, `FisuEvolutionUITests/TutorialLessonsUITests.swift`

**Interfaces:**
- Consumes: E9a (`TutorialStep.act/explain`, señales, `HoldHand`/`SwipeHand`, `.pickerFace`);
  `quickHireOffer` (E3b), `floorMap` (E3a T8), `PrestigePreview.isBlockedByWall` (E2a T8),
  `content.economy.staffedBonusPerFloor` (E2a T4).
- Produces: `TutorialLesson.passive`, `.orgChart`, `.floorSwipe`, `.floorFull`,
  `.staffedFloors`, `.prestigeGate`, `.characterSheet`; `steps` explícitos de `quickHire`,
  `upgrades`, `elevator`, `prestige`; las anclas de arriba; `ElevatorPanel` manda
  `tutorialSignal(.elevatorExpanded)`.

- [ ] **Step 0: Los nombres de E2a, E3a y E3b**

Run: `grep -rn "var quickHireOffer\|enum Blocker\|case floorFull\|var floorMap\|isBlockedByWall\|staffedBonusPerFloor\|struct ElevatorPanel\|func characterUpgradeCost\|seenTypes" --include='*.swift' FisuEvolution Packages/EconomyKit/Sources | head -20`
Expected: los nueve. Si `floorMap` no tiene `occupied`/`capacity`, la elegibilidad de
`staffedFloors` usa `StaffedFloors.ordinals(state:tiers:floorTable:)` (E2a T4) `!isEmpty`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/TutorialLessonsTests.swift` (con el `makeGameState()` de
`TutorialDirectorTests`, copiado privado):

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Las lecciones del currículo v2", .serialized)
@MainActor
struct TutorialLessonsTests {
    private func makeGameState() async -> GameState {
        for lesson in GameState.TutorialLesson.allCases {
            UserDefaults.standard.removeObject(forKey: lesson.defaultsKey)
        }
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "lessons-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        return gameState
    }

    private func only(_ lesson: GameState.TutorialLesson, in gameState: GameState) {
        for other in GameState.TutorialLesson.allCases where other != lesson { gameState.markLessonDone(other) }
    }

    @Test("el atajo: tocar → mantener → fijar → soltar → el botón gris")
    func quickHireWalksItsFiveSteps() async throws {
        let gameState = await makeGameState()
        only(.quickHire, in: gameState)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.tap")
        gameState.tutorialTipCompleted(.quickHire)
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.hold")
        #expect(gameState.tutorialRun?.step?.hand == .hold)
        gameState.tutorialSignal(.pickerOpened)
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.pin")
        let type = try #require(gameState.content?.tiers.baseType.id)
        gameState.setQuickHirePin(type)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.unpin")
        gameState.setQuickHirePin(nil)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "quick_hire.blocked")
        #expect(gameState.tutorialRun?.step?.clockKind == .explain)
    }

    @Test("la botonera: display → desplegar → piso → mapa")
    func elevatorWalksTheBoard() async {
        let gameState = await makeGameState()
        only(.elevator, in: gameState)
        gameState.debugUnlockFloors(throughTier: 5)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["elevator.display", "elevator.expand", "elevator.floor", "elevator.map"])
    }

    @Test("el pasivo nace sólo con un pasivo pagable")
    func passiveNeedsAnAffordablePassive() async {
        let gameState = await makeGameState()
        only(.passive, in: gameState)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil)
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.lessonID == "passive")
    }

    @Test("toda lección de T1 tiene pasos, y las de la 2.0 no se dan por vistas al veterano")
    func declaredRelease() {
        let v2: [GameState.TutorialLesson] = [.quickHire, .staffedFloors, .prestigeGate, .characterSheet]
        for lesson in v2 { #expect(lesson.introducedIn == .v2, "\(lesson)") }
        let v1: [GameState.TutorialLesson] = [.passive, .upgrades, .orgChart, .elevator, .floorSwipe, .floorFull, .prestige]
        for lesson in v1 { #expect(lesson.introducedIn == .v1, "\(lesson)") }
    }
}
```

(`setQuickHirePin(_:)` es la puerta de E3b T6; si se llama distinto, usá la que haya —el paso 0—.)

`FisuEvolutionUITests/TutorialLessonsUITests.swift`:

```swift
import XCTest

final class TutorialLessonsUITests: XCTestCase {
    func testElAtajoEnseniaAMantenerYFijar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins",
                               "--uitest-lesson=quickHire", "--uitest-tutorial-lock=0.3"]
        app.launch()
        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertTrue(step.waitForExistence(timeout: 10))
        XCTAssertEqual(step.value as? String, "quick_hire.tap")
        app.buttons["hud.quickhire"].tap()
        XCTAssertTrue(step.waitForValue("quick_hire.hold"))
        app.buttons["hud.quickhire"].press(forDuration: 1.0)
        XCTAssertTrue(step.waitForValue("quick_hire.pin"))
    }
}

private extension XCUIElement {
    func waitForValue(_ value: String, timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }
}
```

(El id del botón del atajo es el de hoy, `hud.quickhire`; el paso 0 lo confirma.)

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialLessonsTests`.
Expected: no compila (`.passive`, `.orgChart`… no existen).

- [ ] **Step 3: Las lecciones**

En `enum TutorialLesson`, los casos nuevos (el orden final lo fija T3):

```swift
        /// Hay un ingreso pasivo pagable (la v1 lo tenía, sin lección).
        case passive
        /// Ya hay jerarquías: cuatro tipos vistos y el Menú abierto.
        case orgChart
        /// Dos pisos: también se cambia deslizando.
        case floorSwipe
        /// El atajo está gris por piso lleno.
        case floorFull
        /// Un piso con todos sus lugares ocupados (pisos en marcha, E2a).
        case staffedFloors
        /// Reencarnar pide llegar al tier más alto de la vida anterior (piso móvil, E2a).
        case prestigeGate
        /// La ficha del personaje (mantener presionado).
        case characterSheet
```

`steps` deja de ser `[legacyStep]` para estas once (las demás siguen con `legacyStep` hasta T2/T3):

```swift
        var steps: [TutorialStep] {
            switch self {
            case .quickHire: [
                .act("quick_hire.tap", .lessonAction, text: "tutorial.quick_hire.tap", on: .quickHire),
                .act("quick_hire.hold", .pickerOpened, text: "tutorial.quick_hire.hold", on: .quickHire, hand: .hold),
                .act("quick_hire.pin", .pinned, text: "tutorial.quick_hire.pin", on: .pickerFace, windows: [.quickHire]),
                .act("quick_hire.unpin", .unpinned, text: "tutorial.quick_hire.unpin", on: .quickHire,
                     hand: .hold, windows: [.pickerFace]),
                .explain("quick_hire.blocked", text: "tutorial.quick_hire.blocked", on: .quickHire),
            ]
            case .passive: [
                .act("passive.open", .screenOpened(.upgrades), text: "tutorial.passive.open", on: .upgrades),
                .act("passive.unlock", .passiveUnlocked, text: "tutorial.passive.unlock", on: .upgradesPassive,
                     surface: .page(.upgrades)),
                .explain("passive.done", text: "tutorial.passive.done", surface: .page(.upgrades)),
            ]
            case .upgrades: [
                .act("upgrades.open", .screenOpened(.upgrades), text: "tutorial.upgrades.open", on: .upgrades),
                .act("upgrades.buy", .upgradeBought, text: "tutorial.upgrades.buy", on: .upgradesRow,
                     surface: .page(.upgrades)),
                .explain("upgrades.done", text: "tutorial.upgrades.done", surface: .page(.upgrades)),
            ]
            case .orgChart: [
                .act("org_chart.open", .screenOpened(.menu), text: "tutorial.org_chart.open", on: .menu),
                .explain("org_chart.card", text: "tutorial.org_chart.card", on: .menuOrgChart, surface: .page(.menu)),
            ]
            case .elevator: [
                .explain("elevator.display", text: "tutorial.elevator.display", on: .elevatorDisplay),
                .act("elevator.expand", .elevatorExpanded, text: "tutorial.elevator.expand", on: .elevatorDisplay),
                .act("elevator.floor", .floorChanged, text: "tutorial.elevator.floor", on: .elevatorButtons),
                .act("elevator.map", .lessonAction, text: "tutorial.elevator.map", on: .map),
            ]
            case .floorSwipe: [
                .explain("floor_swipe.explain", text: "tutorial.floor_swipe.explain", hand: .swipe(.up)),
            ]
            case .floorFull: [
                .explain("floor_full.explain", text: "tutorial.floor_full.explain", on: .quickHire),
            ]
            case .staffedFloors: [
                .explain("staffed_floors.light", text: "tutorial.staffed_floors.light", on: .elevatorDisplay),
                .explain("staffed_floors.bonus", text: "tutorial.staffed_floors.bonus", on: .map),
            ]
            case .prestigeGate: [
                .explain("prestige_gate.explain", text: "tutorial.prestige_gate.explain", on: .prestige),
            ]
            case .prestige: [
                .explain("prestige.oro", text: "tutorial.prestige.oro", on: .prestige),
                .act("prestige.open", .lessonAction, text: "tutorial.prestige.open", on: .prestige),
            ]
            case .characterSheet: [
                .act("character_sheet.hold", .characterSheetOpened, text: "tutorial.character_sheet.hold",
                     on: .boardUnit, hand: .hold, boardTarget: .anyUnit),
                .explain("character_sheet.inside", text: "tutorial.character_sheet.inside", surface: .characterSheet),
            ]
            default: [legacyStep]
            }
        }
```

`introducedIn`: `.passive, .upgrades, .orgChart, .elevator, .floorSwipe, .floorFull, .prestige`
→ `.v1`; `.quickHire, .staffedFloors, .prestigeGate, .characterSheet` → `.v2` (el `default` sigue
hasta T3).

`isEligible`, las nuevas y las cambiadas:

```swift
        case .quickHire:
            quickHireOffer?.affordable == true
        case .passive:
            canAffordAnyPassiveUnlock()
        case .upgrades:
            canAffordAnyCharacterUpgrade()
        case .orgChart:
            (player?.run.seenTypes.count ?? 0) >= 4 && unlockedTabs.contains(.menu)
        case .floorSwipe:
            unlockedFloorsCount >= 2 && isLessonDone(.elevator)
        case .floorFull:
            quickHireOffer?.blocker == .floorFull
        case .staffedFloors:
            (content?.economy.staffedBonusPerFloor ?? 0) > 0
                && floorMap.contains { $0.unlocked && $0.occupied >= $0.capacity }
        case .prestigeGate:
            prestigePreview?.isBlockedByWall == true
        case .characterSheet:
            (player?.meta.stats.totalHiresEver ?? 0) >= 3 && !visiblePlacements.isEmpty
```

con dos ayudantes al lado de `computeCanAffordAnyUpgrade` (misma dieta: costos crudos a 8 Hz):

```swift
    func canAffordAnyPassiveUnlock() -> Bool {
        guard let player else { return false }
        return characterUpgradeTypes.contains {
            player.run.passiveUnlocked[$0.id] != true && player.run.coins >= $0.passiveUnlockCost
        }
    }

    func canAffordAnyCharacterUpgrade() -> Bool {
        guard let player else { return false }
        return characterUpgradeTypes.contains {
            characterUpgradeCost(of: $0).map { player.run.coins >= $0 } ?? false
        }
    }
```

En `+Tutorial.progressTutorialRun`, `tutorialBoardTarget = tutorialRun?.step?.boardTarget` pasa a
correr para **toda** corrida (no sólo el núcleo): la ficha señala a un empleado del tablero.

- [ ] **Step 4: Las anclas y la señal**

- `TutorialAnchor.swift`: `upgradesPassive`, `upgradesRow`, `menuOrgChart`, `elevatorDisplay`,
  `elevatorButtons`, con su comentario de una línea cada una.
- `UpgradesView`: la **primera** fila con pasivo pagable publica `.upgradesPassive`; la primera
  con multiplicador pagable, `.upgradesRow` (un `if` sobre el índice; nunca en el contenedor).
- `MenuView`: la tarjeta del organigrama (`menu.card.orgchart` o la que haya) publica
  `.menuOrgChart`.
- `ElevatorPanel` (E3a T8): el display publica `.elevatorDisplay`; la columna de botones,
  `.elevatorButtons`; al desplegarse: `gameState.tutorialSignal(.elevatorExpanded)`.
- `.map` ya existe (`HUDView.swift:232`) y el mapa abierto ya manda `tutorialTipCompleted(.elevator)`
  (`RootView.swift:433`): nada nuevo.

- [ ] **Step 5: Los textos**

`Tools/v2/claves-pendientes/e9b-t1.json`:

```json
{
  "tutorial.quick_hire.tap": {"es": "Este botón contrata al mejor empleado que te alcanza. Tocalo.", "en": "This button hires the best worker you can afford. Tap it."},
  "tutorial.quick_hire.hold": {"es": "Ahora mantenelo apretado: elegís vos a quién contratar.", "en": "Now press and hold it: you pick who to hire."},
  "tutorial.quick_hire.pin": {"es": "Tocá una cara para fijarla. El botón va a contratar siempre a ése.", "en": "Tap a face to pin it. The button will always hire that one."},
  "tutorial.quick_hire.unpin": {"es": "Mantené el botón y tocá la cara fijada para soltarla.", "en": "Hold the button and tap the pinned face to unpin it."},
  "tutorial.quick_hire.blocked": {"es": "Si el piso está lleno o no te alcanza, el botón se pone gris y te dice por qué. Nunca desaparece.", "en": "If the floor is full or you're short on cash, the button turns gray and tells you why. It never disappears."},
  "tutorial.passive.open": {"es": "Te alcanza para algo importante. Abrí Mejoras.", "en": "You can afford something important. Open Upgrades."},
  "tutorial.passive.unlock": {"es": "Desbloqueá el ingreso pasivo: este empleado va a producir aunque no lo toques.", "en": "Unlock passive income: this worker will earn even when you don't tap."},
  "tutorial.passive.done": {"es": "Listo: ahora gana solo, incluso con el juego cerrado.", "en": "Done: now they earn on their own, even with the game closed."},
  "tutorial.upgrades.open": {"es": "Ya te alcanza para una mejora. Abrí Mejoras.", "en": "You can afford an upgrade. Open Upgrades."},
  "tutorial.upgrades.buy": {"es": "Comprá un nivel: multiplica todo lo que produce ese personaje.", "en": "Buy a level: it multiplies everything that character makes."},
  "tutorial.upgrades.done": {"es": "Cada nivel suma. Volvé seguido: siempre hay alguna para comprar.", "en": "Every level adds up. Check back often: there's always one to buy."},
  "tutorial.org_chart.open": {"es": "Tu torre ya tiene jerarquías. Abrí el Menú.", "en": "Your tower has a pecking order now. Open the Menu."},
  "tutorial.org_chart.card": {"es": "En el Organigrama ves quién manda, cuántos tenés de cada uno y cuánto produce cada uno.", "en": "The Org Chart shows who's in charge, how many of each you have, and how much each one earns."},
  "tutorial.elevator.display": {"es": "Este display te dice en qué piso estás.", "en": "This display tells you which floor you're on."},
  "tutorial.elevator.expand": {"es": "Tocalo y se despliega la botonera del ascensor.", "en": "Tap it and the elevator panel slides open."},
  "tutorial.elevator.floor": {"es": "Tocá un piso y el ascensor te lleva. ¡Ding!", "en": "Tap a floor and the elevator takes you there. Ding!"},
  "tutorial.elevator.map": {"es": "Y este ícono abre el mapa de toda la torre.", "en": "And this icon opens the map of the whole tower."},
  "tutorial.floor_swipe.explain": {"es": "También podés deslizar el tablero para arriba o para abajo y cambiar de piso.", "en": "You can also swipe the board up or down to change floors."},
  "tutorial.floor_full.explain": {"es": "Este piso está lleno. Fusioná dos iguales para hacer lugar, o subí a otro piso.", "en": "This floor is full. Merge two of a kind to make room, or move up a floor."},
  "tutorial.staffed_floors.light": {"es": "¿Ves la luz verde? Ese piso tiene todos sus lugares ocupados.", "en": "See the green light? That floor has every spot filled."},
  "tutorial.staffed_floors.bonus": {"es": "Cada piso lleno suma +5 % a todo lo que ganás. Con los diez, +50 %. Los pisos de abajo también cuentan.", "en": "Each full floor adds +5% to everything you earn. All ten: +50%. The lower floors count too."},
  "tutorial.prestige_gate.explain": {"es": "Para reencarnar tenés que llegar al personaje más alto de tu vida anterior. El botón te dice a quién.", "en": "To reincarnate you need to reach your previous life's top character. The button tells you who."},
  "tutorial.prestige.oro": {"es": "¡Ya podés reencarnar! Empezás de cero, pero con ORO que multiplica todo para siempre.", "en": "You can reincarnate! You start over, but with ORO that multiplies everything forever."},
  "tutorial.prestige.open": {"es": "Tocá acá para ver cuánto ORO te llevás.", "en": "Tap here to see how much ORO you'd get."},
  "tutorial.character_sheet.hold": {"es": "Mantené apretado a un empleado para ver su ficha.", "en": "Press and hold a worker to see their card."},
  "tutorial.character_sheet.inside": {"es": "Acá ves cuánto produce, le cambiás la pinta o lo despedís.", "en": "Here you see what they earn, change their outfit, or fire them."}
}
```

`Tools/v2/claves-pendientes/e9b-t1.quitar`: `tutorial.tip.quickhire`, `tutorial.tip.upgrades`,
`tutorial.tip.elevator`, `tutorial.tip.prestige` (sin usos después del Step 3: verificalo con
`grep -rn` antes de quitar).

- [ ] **Step 6: La cobertura**

`TutorialMechanic.knownGaps` pierde `.passiveIncome`, `.orgChart`, `.floorSwipe`, `.floorFull`,
`.characterSheet`, `.staffedFloors`, `.prestigeGate` (y `knownGapsCeiling` baja a 13); en
`coverage`: `.passiveIncome: .lesson(.passive)`, `.orgChart: .lesson(.orgChart)`,
`.floorSwipe: .lesson(.floorSwipe)`, `.floorFull: .lesson(.floorFull)`,
`.characterSheet: .lesson(.characterSheet)`, `.staffedFloors: .lesson(.staffedFloors)`,
`.prestigeGate: .lesson(.prestigeGate)`.

- [ ] **Step 7: Verde, a mano y oráculo**

Run: Receta R con `TutorialLessonsTests`, `TutorialCoverageTests`, `TutorialCurriculumTests`,
`TutorialTipsTests`, `LocalizationCompletenessTests` → PASS. UI: `TutorialLessonsUITests`,
`TutorialUITests` → PASS. A mano (`--uitest-lesson=<id> --uitest-tutorial-lock=0.3` con los
fixtures de cada una): las once, en el SE y el iPad 13"; las manos de mantener y deslizar con
Reduce Motion en los dos sentidos. Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/Game/State/GameState+TutorialTips.swift FisuEvolution/Game/State/GameState+Tutorial.swift
git add FisuEvolution/UI/Tutorial/TutorialAnchor.swift FisuEvolution/UI/Store/UpgradesView.swift
git add FisuEvolution/UI/Menu/MenuView.swift FisuEvolution/UI/HUD/ElevatorPanel.swift
git add FisuEvolution/Game/Tutorial/TutorialCurriculum.swift
git add FisuEvolutionTests/TutorialLessonsTests.swift FisuEvolutionUITests/TutorialLessonsUITests.swift
# + el catálogo o e9b-t1.{json,quitar}
git diff --cached --stat
git commit -m "feat(tutorial): las lecciones del tablero y la torre — atajo con pin, botonera, pasivo y ficha"
```

---

### Task 2: Las lecciones de la economía, el ORO, la tienda y el menú

**Objetivo:** boosts, regalos (el calendario), cofres, pintas, logros, mejoras de ORO, tienda
(alineada con la pestaña: aparece con ella), "+6 % por compra", deslizar el menú, las pestañas
nuevas ("¡Nuevo!"), la tienda de ORO (las dos mitades y los topes del día), la suerte (dónde se
ven las probabilidades), el ×3 guardado, el auto-tap, las ofertas de 24 h, los cosméticos de ORO,
los efectos de pinta y los lugares extra.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift`
- Modify: `FisuEvolution/UI/Tutorial/TutorialAnchor.swift` (`.giftsBoosts`, `.giftsCalendar`, `.giftsChest`, `.skinsEquip`, `.skinsEffects`, `.menuAchievements`, `.upgradesOro`, `.jobsPriceStep`, `.storeOdds`, `.storeCosmetics`, `.activeBonuses`)
- Modify: `FisuEvolution/UI/Gifts/GiftsView.swift`, `FisuEvolution/UI/Skins/CustomizationView.swift`, `FisuEvolution/UI/Menu/MenuView.swift`, `FisuEvolution/UI/Store/UpgradesView.swift`, `FisuEvolution/UI/Jobs/FisuJobsView.swift`, `FisuEvolution/UI/Store/StoreView.swift`, `FisuEvolution/UI/HUD/ActiveBonusBar.swift`
- Modify: `FisuEvolution/Game/Tutorial/TutorialCurriculum.swift` (`knownGaps` −13)
- Strings: catálogo (`e9b-t2.json` + `e9b-t2.quitar`)
- Modify: `FisuEvolutionTests/TutorialLessonsTests.swift`

**Interfaces:**
- Consumes: `unlockedTabs`, `newTabs` (E3a T9); `JobRow.priceTrendText` (E2a T10);
  `GameContent.oroShop`, `LootBoxGate.lastKnown` (E5a T8/E6a T7); el ×3 y el auto-tap (E6a T5);
  `offerChip` visible (E6a T12); pintas y efectos de ORO (E6b T4/T5); lugares extra (E6b T7).
- Produces: `TutorialLesson.boosts`, `.chests`, `.hirePriceStep`, `.menuSwipe`, `.newTabs`,
  `.oroShop`, `.pendingTriple`, `.autoTap`, `.luck`, `.offers`, `.cosmetics`, `.skinEffects`,
  `.extraSlots`; `steps` explícitos de `gifts`, `skins`, `achievements`, `oroUpgrades`, `store`;
  `StoreView` manda `tutorialTipCompleted(.oroShop)` al elegir "Gastar ORO".

- [ ] **Step 0: Los nombres de E6a/E6b**

Run: `grep -rn "pendingOffline\|nextOfflineMultiplier\|nextDailyMultiplier\|autoTapPerSecond\|offerPresentation\|var openOffer\|extraSlotsLevel\|extraSlots\b\|lastKnown\|struct OroShopConfig" --include='*.swift' FisuEvolution Packages/EconomyKit/Sources | head -20`
Expected: cómo se llaman, en el árbol, el ×3 guardado (offline y diario), el modificador del
auto-tap, la oferta visible, el nivel de lugares extra, la última respuesta de la puerta del azar
y los ítems de la tienda. Las líneas de `isEligible` de abajo usan los nombres de los planes; se
cambian por los reales y se anotan.

- [ ] **Step 1: Los tests, en rojo**

En `TutorialLessonsTests.swift`:

```swift
    @Test("la tienda se enseña cuando aparece su pestaña, no una sesión después")
    func storeFollowsItsTab() async {
        let gameState = await makeGameState()
        only(.store, in: gameState)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "una partida nueva no tiene la pestaña")
        gameState.debugUnlockTab(.store)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.lessonID == "store")
    }

    @Test("deslizar el menú se cumple deslizando")
    func menuSwipeNeedsAPagerMove() async {
        let gameState = await makeGameState()
        only(.menuSwipe, in: gameState)
        for tab in [GameScreen.skins, .gifts] { gameState.debugUnlockTab(tab) }
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.step?.id == "menu_swipe.open")
        gameState.uiCoversBoard = true
        gameState.menuDidOpen(at: .upgrades)
        #expect(gameState.tutorialRun?.step?.id == "menu_swipe.swipe")
        #expect(gameState.tutorialRun?.step?.hand == .swipe(.left))
        gameState.menuPageChanged(to: .skins)
        #expect(gameState.tutorialRun == nil || gameState.tutorialRun?.isFinished == true)
    }

    @Test("la tienda de ORO pasa por la mitad «Gastar ORO»")
    func oroShopNeedsTheSpendHalf() async {
        let gameState = await makeGameState()
        only(.oroShop, in: gameState)
        gameState.debugUnlockTab(.store)
        gameState.debugGrantOro(500)
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.steps.map(\.id) == ["oro_shop.open", "oro_shop.spend", "oro_shop.caps"])
    }

    @Test("las de T2 declaran su versión")
    func declaredReleaseT2() {
        let v1: [GameState.TutorialLesson] = [.boosts, .gifts, .chests, .skins, .achievements, .oroUpgrades, .store]
        for lesson in v1 { #expect(lesson.introducedIn == .v1, "\(lesson)") }
        let v2: [GameState.TutorialLesson] = [.hirePriceStep, .menuSwipe, .newTabs, .oroShop, .pendingTriple,
                                               .autoTap, .luck, .offers, .cosmetics, .skinEffects, .extraSlots]
        for lesson in v2 { #expect(lesson.introducedIn == .v2, "\(lesson)") }
    }
```

(`debugUnlockTab(_:)` y `debugGrantOro(_:)`: si no existen en `+Debug` —E3a T9 y E6a dejan
puertas parecidas—, se suman en esta tarea, `#if DEBUG`, de una línea cada una.)

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/TutorialLessonsTests`. Expected: no compila.

- [ ] **Step 3: Las lecciones**

Casos nuevos: `boosts`, `chests`, `hirePriceStep`, `menuSwipe`, `newTabs`, `oroShop`,
`pendingTriple`, `autoTap`, `luck`, `offers`, `cosmetics`, `skinEffects`, `extraSlots` (un
comentario de una línea cada uno, como los de T1). En `steps`:

```swift
            case .gifts: [
                .act("gifts.open", .screenOpened(.gifts), text: "tutorial.gifts.open", on: .gifts),
                .explain("gifts.calendar", text: "tutorial.gifts.calendar", on: .giftsCalendar, surface: .page(.gifts)),
            ]
            case .boosts: [
                .act("boosts.open", .screenOpened(.gifts), text: "tutorial.boosts.open", on: .gifts),
                .explain("boosts.explain", text: "tutorial.boosts.explain", on: .giftsBoosts, surface: .page(.gifts)),
            ]
            case .chests: [
                .act("chests.open", .screenOpened(.gifts), text: "tutorial.chests.open", on: .gifts),
                .explain("chests.explain", text: "tutorial.chests.explain", on: .giftsChest, surface: .page(.gifts)),
            ]
            case .skins: [
                .act("skins.open", .screenOpened(.skins), text: "tutorial.skins.open", on: .skins),
                .explain("skins.wear", text: "tutorial.skins.wear", on: .skinsEquip, surface: .page(.skins)),
            ]
            case .achievements: [
                .act("achievements.open", .screenOpened(.menu), text: "tutorial.achievements.open", on: .menu),
                .explain("achievements.card", text: "tutorial.achievements.card", on: .menuAchievements, surface: .page(.menu)),
            ]
            case .oroUpgrades: [
                .act("oro_upgrades.open", .screenOpened(.upgrades), text: "tutorial.oro_upgrades.open", on: .upgrades),
                .act("oro_upgrades.buy", .upgradeBought, text: "tutorial.oro_upgrades.buy", on: .upgradesOro,
                     surface: .page(.upgrades)),
            ]
            case .store: [
                .act("store.open", .screenOpened(.store), text: "tutorial.store.open", on: .store),
                .explain("store.packs", text: "tutorial.store.packs", surface: .page(.store)),
            ]
            case .hirePriceStep: [
                .act("hire_price_step.open", .screenOpened(.jobs), text: "tutorial.hire_price_step.open", on: .hire),
                .explain("hire_price_step.explain", text: "tutorial.hire_price_step.explain", on: .jobsPriceStep,
                         surface: .page(.jobs)),
            ]
            case .menuSwipe: [
                .act("menu_swipe.open", .screenOpened(.upgrades), text: "tutorial.menu_swipe.open", on: .upgrades),
                .act("menu_swipe.swipe", .pagerMoved, text: "tutorial.menu_swipe.swipe", on: .menuPager,
                     surface: .page(.upgrades), hand: .swipe(.left)),
            ]
            case .newTabs: [
                .explain("new_tabs.explain", text: "tutorial.new_tabs.explain", on: .bottomBar),
            ]
            case .oroShop: [
                .act("oro_shop.open", .screenOpened(.store), text: "tutorial.oro_shop.open", on: .store),
                .act("oro_shop.spend", .lessonAction, text: "tutorial.oro_shop.spend", on: .oroShop, surface: .page(.store)),
                .explain("oro_shop.caps", text: "tutorial.oro_shop.caps", surface: .page(.store)),
            ]
            case .luck: [
                .act("luck.open", .screenOpened(.store), text: "tutorial.luck.open", on: .store),
                .explain("luck.odds", text: "tutorial.luck.odds", on: .storeOdds, surface: .page(.store)),
            ]
            case .cosmetics: [
                .act("cosmetics.open", .screenOpened(.store), text: "tutorial.cosmetics.open", on: .store),
                .explain("cosmetics.where", text: "tutorial.cosmetics.where", on: .storeCosmetics, surface: .page(.store)),
            ]
            case .skinEffects: [
                .act("skin_effects.open", .screenOpened(.skins), text: "tutorial.skin_effects.open", on: .skins),
                .explain("skin_effects.wear", text: "tutorial.skin_effects.wear", on: .skinsEffects, surface: .page(.skins)),
            ]
            case .pendingTriple: [
                .explain("pending_triple.explain", text: "tutorial.pending_triple.explain", on: .activeBonuses),
            ]
            case .autoTap: [
                .explain("auto_tap.explain", text: "tutorial.auto_tap.explain", on: .activeBonuses),
            ]
            case .offers: [
                .explain("offers.chip", text: "tutorial.offers.chip", on: .offerChip),
            ]
            case .extraSlots: [
                .explain("extra_slots.explain", text: "tutorial.extra_slots.explain"),
            ]
```

`isEligible` (los nombres de E6a/E6b, corregidos en el paso 0):

```swift
        case .gifts:
            (player?.meta.daily.cycleDay ?? 1) > 1
        case .boosts:
            unlockedTabs.contains(.gifts) && isLessonDone(.gifts)
                && (player?.meta.stats.boostsActivatedEver ?? 0) == 0
        case .chests:
            unlockedTabs.contains(.gifts) && (player?.meta.chestsPending ?? 0) > 0
        case .store:
            unlockedTabs.contains(.store)
        case .hirePriceStep:
            (player?.meta.stats.totalHiresEver ?? 0) >= 5
        case .menuSwipe:
            unlockedTabs.count >= 3
        case .newTabs:
            !newTabs.isEmpty
        case .oroShop:
            unlockedTabs.contains(.store) && (player?.meta.oro ?? 0) >= cheapestOroShopPrice
        case .luck:
            isLessonDone(.oroShop) && LootBoxGate.lastKnown == true
        case .cosmetics:
            isLessonDone(.oroShop) && (player?.meta.oro ?? 0) >= cheapestCosmeticPrice
        case .skinEffects:
            !(player?.meta.engagement.shop.skins.isEmpty ?? true)
        case .pendingTriple:
            pendingTripleIsArmed
        case .autoTap:
            activeBonuses.contains { $0.effect == .autoTapPerSecond }
        case .offers:
            visibleOffer != nil
        case .extraSlots:
            (player?.meta.engagement.shop.levels["extra_slots"] ?? 0) > 0
```

(`cheapestOroShopPrice`, `cheapestCosmeticPrice` y `pendingTripleIsArmed` son tres ayudantes de
una línea en `+TutorialTips` sobre los datos de E6a; `skins`, `achievements`, `oroUpgrades`
conservan la elegibilidad de la v1.)

`introducedIn`: `.boosts, .gifts, .chests, .skins, .achievements, .oroUpgrades, .store` → `.v1`;
las otras once → `.v2`.

- [ ] **Step 4: Las anclas y la señal**

Cada ancla nueva en `TutorialAnchor.swift` (un comentario de una línea) y montada en **un**
control de su vista (nunca en un contenedor):

| Ancla | Vista | Dónde |
|---|---|---|
| `.giftsCalendar` | `GiftsView` | la tira del calendario |
| `.giftsBoosts` | `GiftsView` | la primera tarjeta de boost |
| `.giftsChest` | `GiftsView` | la tarjeta del cofre |
| `.skinsEquip` | `CustomizationView` | el botón "Ponérsela" de la primera pinta disponible |
| `.skinsEffects` | `CustomizationView` | la fila de efectos (E6b T5) |
| `.menuAchievements` | `MenuView` | la tarjeta de Logros (`menu.card.achievements`) |
| `.upgradesOro` | `UpgradesView` | la primera línea de ORO pagable |
| `.jobsPriceStep` | `FisuJobsView` | el "+6 %" de la primera fila (E2a T10) |
| `.storeOdds` | `StoreView` | la fila de Suerte con su tabla (E6a T7) |
| `.storeCosmetics` | `StoreView` | el estante de cosméticos (E6b) |
| `.activeBonuses` | `ActiveBonusBar` | el primer chip |

`StoreView`: al elegir la mitad "Gastar ORO", `gameState.tutorialTipCompleted(.oroShop)`.

- [ ] **Step 5: Los textos**

`Tools/v2/claves-pendientes/e9b-t2.json`:

```json
{
  "tutorial.gifts.open": {"es": "Cobraste tu primer premio diario. Mirá lo que viene en Regalos.", "en": "You got your first daily reward. See what's coming in Gifts."},
  "tutorial.gifts.calendar": {"es": "Cada día que volvés, un premio más grande. No cortes la racha.", "en": "Every day you come back, a bigger reward. Don't break the streak."},
  "tutorial.boosts.open": {"es": "Hay boosts esperándote en Regalos.", "en": "There are boosts waiting for you in Gifts."},
  "tutorial.boosts.explain": {"es": "Un boost multiplica lo que ganás por un rato. Uno por video, cada tanto.", "en": "A boost multiplies what you earn for a while. One per video, every so often."},
  "tutorial.chests.open": {"es": "¡Te ganaste un cofre! Está en Regalos.", "en": "You earned a chest! It's in Gifts."},
  "tutorial.chests.explain": {"es": "Abrilo: adentro hay una pinta o plata. Las probabilidades están a la vista.", "en": "Open it: there's an outfit or cash inside. The odds are right there."},
  "tutorial.skins.open": {"es": "Tenés una pinta para estrenar. Abrí Vestimenta.", "en": "You've got a new outfit. Open Outfits."},
  "tutorial.skins.wear": {"es": "Ponésela: cambia cómo se ve, no cuánto produce.", "en": "Put it on: it changes the look, not the earnings."},
  "tutorial.achievements.open": {"es": "Tenés un logro para cobrar. Abrí el Menú.", "en": "You have an achievement to claim. Open the Menu."},
  "tutorial.achievements.card": {"es": "En Logros cobrás ORO. El puntito rojo te avisa cuando hay algo.", "en": "Claim ORO in Achievements. The red dot tells you when there's something."},
  "tutorial.oro_upgrades.open": {"es": "¡Tu primer ORO! Abrí Mejoras para canjearlo.", "en": "Your first ORO! Open Upgrades to spend it."},
  "tutorial.oro_upgrades.buy": {"es": "Las mejoras de ORO son permanentes: sobreviven a la reencarnación.", "en": "ORO upgrades are permanent: they survive reincarnation."},
  "tutorial.store.open": {"es": "Abrió la Tienda.", "en": "The Store is open."},
  "tutorial.store.packs": {"es": "Acá comprás ORO y packs. Nada de esto hace falta para llegar a Dios.", "en": "Buy ORO and packs here. None of it is needed to reach God."},
  "tutorial.hire_price_step.open": {"es": "Mirá cómo suben los precios. Abrí Contratar.", "en": "Watch how prices climb. Open Hire."},
  "tutorial.hire_price_step.explain": {"es": "Cada compra del mismo empleado sube su precio +6 %. Fusionar lo abarata un poco.", "en": "Each hire of the same worker raises their price +6%. Merging brings it down a bit."},
  "tutorial.menu_swipe.open": {"es": "Abrí Mejoras.", "en": "Open Upgrades."},
  "tutorial.menu_swipe.swipe": {"es": "Deslizá para pasar de una pestaña a otra sin cerrar.", "en": "Swipe to move between tabs without closing."},
  "tutorial.new_tabs.explain": {"es": "¡Apareció una pestaña nueva! Las pestañas llegan cuando las necesitás; las que dicen «¡Nuevo!» todavía no las abriste.", "en": "A new tab showed up! Tabs arrive when you need them; the ones marked “New!” you haven't opened yet."},
  "tutorial.oro_shop.open": {"es": "Tenés ORO para gastar. Abrí la Tienda.", "en": "You have ORO to spend. Open the Store."},
  "tutorial.oro_shop.spend": {"es": "Tocá «Gastar ORO»: boosts, atajos y mejoras permanentes.", "en": "Tap “Spend ORO”: boosts, shortcuts and permanent upgrades."},
  "tutorial.oro_shop.caps": {"es": "Algunos tienen tope por día. Lo que compraste con plata, también se gasta acá.", "en": "Some have a daily cap. ORO you bought can be spent here too."},
  "tutorial.luck.open": {"es": "Abrí la Tienda.", "en": "Open the Store."},
  "tutorial.luck.odds": {"es": "Todo lo que es al azar muestra sus probabilidades acá, antes de pagar.", "en": "Everything random shows its odds right here, before you pay."},
  "tutorial.cosmetics.open": {"es": "Abrí la Tienda.", "en": "Open the Store."},
  "tutorial.cosmetics.where": {"es": "Las pintas de ORO se compran acá y se ponen en Vestimenta.", "en": "ORO outfits are bought here and worn in Outfits."},
  "tutorial.skin_effects.open": {"es": "Estrenaste un efecto. Abrí Vestimenta.", "en": "You got a new effect. Open Outfits."},
  "tutorial.skin_effects.wear": {"es": "Los efectos se ponen por personaje, como cualquier pinta.", "en": "Effects are worn per character, like any outfit."},
  "tutorial.pending_triple.explain": {"es": "Tenés un ×3 guardado: se aplica en tu próxima vuelta o en tu próximo premio diario.", "en": "You have a ×3 saved: it applies to your next return or your next daily reward."},
  "tutorial.auto_tap.explain": {"es": "El auto-tap toca solo por vos mientras dure.", "en": "Auto-tap taps for you while it lasts."},
  "tutorial.offers.chip": {"es": "Una oferta por 24 horas. Tocá el chip para verla; si no te interesa, se va sola.", "en": "A 24-hour offer. Tap the chip to see it; if you're not interested, it goes away on its own."},
  "tutorial.extra_slots.explain": {"es": "¡Más lugar! Ahora cada piso tiene una fila más.", "en": "More room! Every floor has an extra row now."}
}
```

`Tools/v2/claves-pendientes/e9b-t2.quitar`: `tutorial.tip.gifts`, `tutorial.tip.skins`,
`tutorial.tip.achievements`, `tutorial.tip.oro`, `tutorial.tip.store` (verificar con `grep -rn`
que no queden usos).

- [ ] **Step 6: La cobertura**

`knownGaps` pierde `.boosts`, `.chests`, `.menuSwipe`, `.newTabs`, `.hirePriceStep`,
`.oroShopShelf`, `.pendingTriple`, `.autoTap`, `.luckOdds`, `.offers`, `.cosmetics`,
`.skinEffects`, `.extraSlots` (queda vacío; `knownGapsCeiling` = 0); `coverage` les asigna su
lección (`.oroShopShelf: .lesson(.oroShop)`, `.luckOdds: .lesson(.luck)`, el resto con su nombre).

- [ ] **Step 7: Verde, a mano y oráculo**

Run: Receta R con `TutorialLessonsTests`, `TutorialCoverageTests`, `TutorialCurriculumTests`,
`LocalizationCompletenessTests` → PASS. UI: `TutorialLessonsUITests`, `TutorialUITests`,
`StoreUITests` (la tienda sigue abriendo en "Comprar ORO") → PASS. A mano, las dieciocho con
`--uitest-lesson=<id>` y su fixture; SE y iPad 13". Capturas al reporte.
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution/Game/State/GameState+TutorialTips.swift FisuEvolution/UI/Tutorial/TutorialAnchor.swift
git add FisuEvolution/UI/Gifts/GiftsView.swift FisuEvolution/UI/Skins/CustomizationView.swift
git add FisuEvolution/UI/Menu/MenuView.swift FisuEvolution/UI/Store/UpgradesView.swift
git add FisuEvolution/UI/Jobs/FisuJobsView.swift FisuEvolution/UI/Store/StoreView.swift
git add FisuEvolution/UI/HUD/ActiveBonusBar.swift FisuEvolution/Game/Tutorial/TutorialCurriculum.swift
git add FisuEvolution/Game/State/GameState+Debug.swift FisuEvolutionTests/TutorialLessonsTests.swift
# + el catálogo o e9b-t2.{json,quitar}
git diff --cached --stat
git commit -m "feat(tutorial): las lecciones de la economía, el ORO, la tienda y el menú"
```

---

### Task 3: Las lecciones heredadas al formato, el orden y la cobertura completa

**Objetivo:** las nueve lecciones que trajeron E3b, E4b, E5b y E7b-b (`share`, `visitor`,
`eventChip`, `album`, `packages`, `mattress`, `wheel`, `sideRail`, `mergeAllVideo`) dejan
`legacyStep` y declaran sus pasos (con sus **mismos** textos: ya están en el catálogo y los
aprobó su épica); `introducedIn` se vuelve exhaustivo (sin `default`); el orden de `allCases`
queda fijado; y la cobertura exige **cero** huecos.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift`
- Modify: `FisuEvolution/Game/Tutorial/TutorialCurriculum.swift` (`knownGaps` y su techo se borran)
- Modify: `FisuEvolutionTests/TutorialCoverageTests.swift`, `FisuEvolutionTests/TutorialLessonsTests.swift`

**Interfaces:**
- Consumes: las lecciones y anclas de E3b T9, E4b T3/T4/T8, E5b T5, E7b-b T3/T5.
- Produces: `TutorialLesson.allCases` en el orden de abajo; `legacyStep` borrado;
  `TutorialMechanic.knownGaps` borrado.

- [ ] **Step 0: Las nueve, como quedaron**

Run: `grep -n "case share\|case visitor\|case eventChip\|case album\|case packages\|case mattress\|case wheel\|case sideRail\|case mergeAllVideo" FisuEvolution/Game/State/GameState+TutorialTips.swift`
y, para cada una, su `textKey`, `anchorTarget` y `destinationScreen`. Expected: lo que dicen sus
planes (`wheel` → `.sideWheel`, sin destino; `album` → `.menu`/`.menu`; `sideRail` → `.sideRail`).

- [ ] **Step 1: Los tests, en rojo**

En `TutorialCoverageTests.swift`, el test de los huecos pasa a:

```swift
    @Test("no queda ninguna mecánica sin lección")
    func noGapsLeft() {
        for mechanic in TutorialMechanic.allCases {
            if case .lesson(let lesson) = mechanic.coverage {
                #expect(!lesson.steps.contains { $0.id.hasSuffix(".legacy") }, "\(mechanic) sigue con el paso de la v1")
            }
        }
    }
```

y en `TutorialLessonsTests.swift`:

```swift
    @Test("cada lección declara su versión a mano, y ninguna conserva el paso heredado")
    func everyLessonIsExplicit() {
        for lesson in GameState.TutorialLesson.allCases {
            #expect(!lesson.steps.isEmpty)
            #expect(!lesson.steps.contains { $0.id.hasSuffix(".legacy") }, "\(lesson)")
        }
    }

    @Test("el orden: lo que se usa primero, se enseña primero")
    func order() {
        let all = GameState.TutorialLesson.allCases
        let index = { (lesson: GameState.TutorialLesson) in all.firstIndex(of: lesson)! }
        #expect(index(.quickHire) < index(.upgrades))
        #expect(index(.newTabs) < index(.skins))
        #expect(index(.newTabs) < index(.store))
        #expect(index(.elevator) < index(.floorSwipe))
        #expect(index(.oroShop) < index(.luck))
        #expect(index(.sideRail) < index(.packages))
    }
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `TutorialCoverageTests`, `TutorialLessonsTests` → rojo (las nueve con
`.legacy`).

- [ ] **Step 3: Los pasos de las nueve**

```swift
            case .share: [
                .act("share.tap", .lessonAction, text: "tutorial.tip.share", on: .share),
            ]
            case .visitor: [
                .act("visitor.tap", .lessonAction, text: "tutorial.tip.visitor", on: .visitor),
            ]
            case .eventChip: [
                .explain("event_chip.explain", text: "tutorial.tip.event_chip", on: .eventChip),
            ]
            case .album: [
                .act("album.open", .screenOpened(.menu), text: "tutorial.tip.album", on: .menu),
            ]
            case .sideRail: [
                .act("side_rail.open", .lessonAction, text: "tutorial.tip.side_rail", on: .sideRail),
            ]
            case .packages: [
                .act("packages.tap", .lessonAction, text: "tutorial.tip.packages", on: .sidePackages),
            ]
            case .mattress: [
                .act("mattress.tap", .lessonAction, text: "tutorial.tip.mattress", on: .sideMattress),
            ]
            case .wheel: [
                .act("wheel.tap", .lessonAction, text: "tutorial.tip.wheel", on: .sideWheel),
            ]
            case .mergeAllVideo: [
                .act("merge_all_video.tap", .lessonAction, text: "tutorial.tip.merge_all_video", on: .sideBoost),
            ]
```

⚠️ Cada una conserva la **señal** que le dio su épica: si la suya era abrir una pantalla
(`destinationScreen != nil`), el paso es `.screenOpened(<esa>)`; si era la acción firma
(`tutorialTipCompleted(.x)` desde su vista), `.lessonAction`. El chip del evento era un aviso
sin acción: queda de explicar (con su candado). Lo que diga el paso 0 manda sobre la tabla.
Después se borra `legacyStep` y el `default:` de `steps`.

- [ ] **Step 4: El orden y la versión**

Los casos de `enum TutorialLesson` quedan declarados en este orden (es el desempate cuando dos son
elegibles a la vez):

```
quickHire, upgrades, passive, newTabs, skins, gifts, boosts, chests, achievements, oroUpgrades,
elevator, floorSwipe, floorFull, characterSheet, menuSwipe, hirePriceStep, store, staffedFloors,
prestige, prestigeGate, share, sideRail, packages, mattress, wheel, mergeAllVideo, visitor,
eventChip, album, oroShop, luck, cosmetics, skinEffects, pendingTriple, autoTap, offers,
extraSlots, orgChart
```

`introducedIn` sin `default`: las de la v1 (`upgrades`, `passive`, `skins`, `gifts`, `boosts`,
`chests`, `achievements`, `oroUpgrades`, `elevator`, `floorSwipe`, `floorFull`, `store`,
`prestige`, `orgChart`) → `.v1`; todas las demás → `.v2`.

- [ ] **Step 5: La cobertura completa**

En `TutorialCurriculum.swift` se borran `knownGaps`, `knownGapsCeiling` y el bloque de "hasta
E9b" del `switch` (todas las mecánicas ya tienen su caso). En `TutorialCoverageTests`, el
`where !knownGaps.contains(...)` y el test `gapsAreDeclared` se borran.

- [ ] **Step 6: Verde y oráculo**

Run: Receta R con `TutorialCoverageTests`, `TutorialCurriculumTests`, `TutorialLessonsTests`,
`TutorialTipsTests`, `PrizeAccessTests` y los tests de lecciones de E4b/E7b-b → PASS. UI: los
de lecciones de E4b/E5b/E7b-b (`grep -ln "tutorial.tip" FisuEvolutionUITests`) → PASS.
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/State/GameState+TutorialTips.swift FisuEvolution/Game/Tutorial/TutorialCurriculum.swift
git add FisuEvolutionTests/TutorialCoverageTests.swift FisuEvolutionTests/TutorialLessonsTests.swift
git diff --cached --stat
git commit -m "feat(tutorial): toda mecánica con su lección — las heredadas al formato y cero huecos"
```

---

### Task 4: El Tour de novedades para los veteranos

**Objetivo:** el veterano de la v1 (lo marcó la migración de E9a T3) recibe, la primera vez que el
tablero está tranquilo, un recorrido de demostración —sólo explicar, con el candado de 5 s y sin
exigir acciones— por lo nuevo de la 2.0: el atajo con pin, el menú que se desliza, la ficha
nueva, la botonera del ascensor, la columna de "Premios", los visitantes y eventos, el Álbum y
Ajustes. Al terminar, las lecciones que el Tour ya cubrió quedan dadas; lo que depende de eventos
se le enseña en su primera ocurrencia.

**Files:**
- Modify: `FisuEvolution/Game/Tutorial/TutorialCurriculum.swift` (`tour`, `tourCoveredLessons`)
- Modify: `FisuEvolution/Game/State/GameState+Tutorial.swift` (`startTourIfDue`, el fin del Tour)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`--uitest-veteran`)
- Strings: catálogo (snapshot `e9b-t4.json`)
- Create: `FisuEvolutionTests/TutorialTourTests.swift`, `FisuEvolutionUITests/WhatsNewTourUITests.swift`

**Interfaces:**
- Consumes: `TutorialFlags.tourPending` (E9a T3), `startTutorialRun(.tour, …)`, el overlay de
  demostración (E9a T6), `TutorialCard`.
- Produces: `TutorialCurriculum.tour: [TutorialStep]`, `TutorialCurriculum.tourCoveredLessons`;
  `GameState.startTour()`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/TutorialTourTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El Tour de novedades", .serialized)
@MainActor
struct TutorialTourTests {
    private func makeVeteran() async -> GameState {
        TutorialFlags.wipeGameFlags()
        TutorialFlags.setCoreCompleted(true)
        TutorialFlags.setTourPending(true)
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "tour-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        return gameState
    }

    @Test("el Tour gana sobre cualquier lección y es sólo de explicar")
    func tourFirstAndExplainOnly() async {
        let gameState = await makeVeteran()
        gameState.debugGrantCoins()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .tour)
        #expect(gameState.tutorialRun?.isDemo == true)
        #expect(TutorialCurriculum.tour.allSatisfy { $0.clockKind == .explain })
    }

    @Test("al terminar: sin Tour pendiente, lo cubierto queda dado y el save no cambió")
    func tourEnd() async {
        let gameState = await makeVeteran()
        let before = gameState.player
        gameState.refreshProjections()
        for _ in TutorialCurriculum.tour {
            gameState.advanceTutorial(delta: 5)
            gameState.confirmTutorialStep()
        }
        #expect(gameState.tutorialRun == nil)
        #expect(!TutorialFlags.tourPending())
        for lesson in TutorialCurriculum.tourCoveredLessons {
            #expect(TutorialFlags.isLessonDone(lesson.rawValue), "\(lesson)")
        }
        #expect(gameState.player?.meta == before?.meta, "el Tour no toca el save")
    }

    @Test("una instalación nueva no ve el Tour")
    func freshInstallHasNoTour() async {
        TutorialFlags.wipeGameFlags()
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "tour-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        gameState.tutorialLessonsAutorun = true
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script != .tour)
    }
}
```

`FisuEvolutionUITests/WhatsNewTourUITests.swift`:

```swift
import XCTest

final class WhatsNewTourUITests: XCTestCase {
    func testElVeteranoRecorreLasNovedadesYTermina() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-veteran", "--uitest-tutorial-lock=0.3"]
        app.launch()
        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertTrue(step.waitForExistence(timeout: 10))
        XCTAssertEqual(step.value as? String, "tour.intro")
        XCTAssertFalse(app.buttons["tutorial.replay.end"].exists, "el Tour no se termina antes")
        let confirm = app.buttons["tutorial.confirm"]
        var guardRail = 0
        while step.exists, guardRail < 15 {
            if confirm.waitForExistence(timeout: 5),
               XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'unlocked'"), object: confirm)], timeout: 5) == .completed {
                confirm.tap()
            } else if app.buttons["tutorial.done"].exists {
                app.buttons["tutorial.done"].tap()
            }
            guardRail += 1
        }
        XCTAssertTrue(step.waitForNonExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `TutorialTourTests` → no compila (`TutorialCurriculum.tour` no existe).

- [ ] **Step 3: El guion**

En `TutorialCurriculum`:

```swift
    /// Lo nuevo de la 2.0 para el veterano (PLAN-v2 E9). Sólo explicar: el estado es arbitrario,
    /// así que señala y cuenta. Lo que depende de eventos (visitantes, paquetes, ofertas) se
    /// enseña en su primera ocurrencia.
    static let tour: [TutorialStep] = [
        .explain("tour.intro", text: "tutorial.tour.intro", pose: "fisura_celebrate"),
        .explain("tour.quick_hire", text: "tutorial.tour.quick_hire", on: .quickHire, hand: .hold),
        .explain("tour.menu_swipe", text: "tutorial.tour.menu_swipe", on: .bottomBar, hand: .swipe(.left)),
        .explain("tour.character_sheet", text: "tutorial.tour.character_sheet", hand: .hold),
        .explain("tour.elevator", text: "tutorial.tour.elevator", on: .elevatorDisplay),
        .explain("tour.side_rail", text: "tutorial.tour.side_rail", on: .sideRail, hand: .tap),
        .explain("tour.visitors", text: "tutorial.tour.visitors"),
        .explain("tour.album", text: "tutorial.tour.album", on: .menu),
        .explain("tour.settings", text: "tutorial.tour.settings", on: .menu),
        .explain("tour.done", text: "tutorial.tour.done", pose: "fisura_celebrate"),
    ]

    /// Lo que el Tour ya enseñó: al terminarlo quedan dadas.
    static let tourCoveredLessons: [GameState.TutorialLesson] = [
        .quickHire, .menuSwipe, .characterSheet, .elevator, .sideRail,
    ]
```

- [ ] **Step 4: El director**

En `+Tutorial.startNextLessonIfDue()`, **antes** de buscar una lección:

```swift
        if TutorialFlags.tourPending(), TutorialFlags.coreCompleted() {
            startTutorialRun(.tour, steps: TutorialCurriculum.tour)
            return
        }
```

(con las mismas guardas de ritmo y de tablero libre que ya tiene la función). En
`finishTutorialRun()`, `case .tour`:

```swift
        case .tour:
            TutorialFlags.setTourPending(false)
            for lesson in TutorialCurriculum.tourCoveredLessons { TutorialFlags.markLessonDone(lesson.rawValue) }
            celebrationFinished(.tutorialTip)
```

El último paso (`tour.done`) usa `confirmKey: "tutorial.done"` ("¡Vamos!"): el overlay elige la
clave por `step.id.hasSuffix(".done") || step.id == "core.finish"`.

`+Debug`, `applyLaunchArgumentDefaults`: `--uitest-veteran` (después del bloque de
`--uitest-reset`) escribe `TutorialFlags.setCoreCompleted(true)`, `setTourPending(true)` y
`markCurrent()`, y deja `tutorialLessonsAutorun = true` (el Tour no es una lección al azar: lo
pide el test).

- [ ] **Step 5: Los textos**

`Tools/v2/claves-pendientes/e9b-t4.json`:

```json
{
  "tutorial.tour.intro": {"es": "¡Bienvenido a la 2.0! Te muestro lo nuevo en un minuto.", "en": "Welcome to 2.0! Let me show you what's new in a minute."},
  "tutorial.tour.quick_hire": {"es": "El atajo ahora elige al mejor que te alcanza. Mantenelo apretado para fijar a quien quieras.", "en": "The shortcut now picks the best you can afford. Press and hold it to pin whoever you want."},
  "tutorial.tour.menu_swipe": {"es": "Las pestañas ahora se deslizan: pasás de una a otra sin cerrar.", "en": "Tabs now swipe: move from one to the next without closing."},
  "tutorial.tour.character_sheet": {"es": "Mantené apretado a un empleado: la ficha es nueva, más grande, y te deja despedirlo.", "en": "Press and hold a worker: the card is new, bigger, and lets you fire them."},
  "tutorial.tour.elevator": {"es": "El ascensor ahora es una botonera. El display te dice en qué piso estás; tocalo para viajar.", "en": "The elevator is now a button panel. The display shows your floor; tap it to travel."},
  "tutorial.tour.side_rail": {"es": "En «Premios» están la Ruleta, el Colchón, los Paquetes y el boost por video.", "en": "“Prizes” holds the Wheel, the Mattress, the Packages and the video boost."},
  "tutorial.tour.visitors": {"es": "Ahora te visitan personajes con tratos, y los eventos llegan con cara y cuenta regresiva. Te los presento cuando aparezcan.", "en": "Characters now drop by with deals, and events arrive with a face and a countdown. I'll introduce them when they show up."},
  "tutorial.tour.album": {"es": "Los especiales que consigas viven en el Álbum, en el Menú.", "en": "The specials you collect live in the Album, in the Menu."},
  "tutorial.tour.settings": {"es": "En Menú › Ajustes elegís qué avisos te llegan y podés ver el tutorial de nuevo.", "en": "In Menu › Settings you choose which alerts you get and can replay the tutorial."},
  "tutorial.tour.done": {"es": "¡Eso es todo! A seguir juntando.", "en": "That's it! Back to the grind."}
}
```

- [ ] **Step 6: Verde, a mano y oráculo**

Run: Receta R con `TutorialTourTests`, `TutorialDirectorTests`, `TutorialCurriculumTests`,
`LocalizationCompletenessTests` → PASS. UI: `WhatsNewTourUITests` → PASS. A mano: una v1 real
actualizada a ésta (el procedimiento de E9a T3 Step 6): el Tour aparece una vez y no vuelve.
Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/Tutorial/TutorialCurriculum.swift FisuEvolution/Game/State/GameState+Tutorial.swift
git add FisuEvolution/Game/State/GameState+Debug.swift FisuEvolution/UI/Tutorial/TutorialOverlay.swift
git add FisuEvolutionTests/TutorialTourTests.swift FisuEvolutionUITests/WhatsNewTourUITests.swift
# + el catálogo o e9b-t4.json
git diff --cached --stat
git commit -m "feat(tutorial): el Tour de novedades de la 2.0 para los veteranos"
```

---

### Task 5: "Ver tutorial de nuevo" y "Ver novedades de la 2.0" en Ajustes

**Objetivo:** dos filas en una sección nueva de Ajustes, "Tutorial": el **repaso** (el núcleo y
las lecciones ya vistas, en modo demostración, con "Terminar repaso" en cada tarjeta) y el **Tour**
otra vez (sin salida anticipada, como el primer recorrido). Ninguno toca el save ni las banderas
de lecciones, ni vuelve a dar el cofre de bienvenida.

**Files:**
- Modify: `FisuEvolution/UI/Menu/SettingsView.swift` 🔥 (sección "Tutorial", antes de "Compras")
- Modify: `FisuEvolution/Game/State/GameState+Tutorial.swift` (`requestTutorialReplay`, `requestTour`, `endReplay`)
- Modify: `FisuEvolution/Game/Tutorial/TutorialCurriculum.swift` (`replay(seenLessons:)`)
- Modify: `FisuEvolution/UI/Tutorial/TutorialOverlay.swift` (`onEnd` en el repaso)
- Strings: catálogo (dueña)
- Create: `FisuEvolutionTests/TutorialReplayTests.swift`, `FisuEvolutionUITests/TutorialReplayUITests.swift`

**Interfaces:**
- Consumes: E9a (director, `TutorialCard.onEnd`), T4 (`tour`), la sección de avisos de E11 T4 y
  la de privacidad de E7b-a T5.
- Produces: `GameState.requestTutorialReplay()`, `requestTour()`, `endReplay()`;
  `TutorialCurriculum.replay(seenLessons:) -> [TutorialStep]`; ids `settings.tutorial.replay`,
  `settings.tutorial.tour`, `tutorial.replay.end`.

- [ ] **Step 0: Ajustes hoy**

Run: `grep -n "Section\|languageSection\|audioSection\|gameSection\|notifications\|privacy\|purchasesSection\|legalSection\|aboutSection" FisuEvolution/UI/Menu/SettingsView.swift`
Expected: las secciones de E11 T4 y la de privacidad de E7b-a T5 en el `VStack` del `body`. La
nueva va **antes** de `purchasesSection`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/TutorialReplayTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El repaso del tutorial", .serialized)
@MainActor
struct TutorialReplayTests {
    private func makeGameState() async -> GameState {
        TutorialFlags.wipeGameFlags()
        TutorialFlags.setCoreCompleted(true)
        TutorialFlags.markLessonDone("upgrades")
        let gameState = GameState(repository: PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "replay-\(UUID().uuidString).json")
        ))
        await gameState.bootstrap()
        return gameState
    }

    @Test("el repaso es el núcleo y lo ya visto, sólo de explicar")
    func replayContents() {
        let steps = TutorialCurriculum.replay(seenLessons: [.upgrades])
        #expect(steps.first?.id == "replay.core.tap")
        #expect(steps.contains { $0.id == "replay.upgrades.open" })
        #expect(!steps.contains { $0.id.hasPrefix("replay.passive") }, "lo no visto no se repasa")
        #expect(steps.allSatisfy { $0.clockKind == .explain && $0.surface == .board })
    }

    @Test("pedirlo arranca con el tablero libre; terminarlo no toca nada")
    func replayLeavesNoTrace() async {
        let gameState = await makeGameState()
        let before = gameState.player
        let chestGiven = gameState.player?.meta.welcomeChestGiven
        gameState.requestTutorialReplay()
        gameState.uiCoversBoard = true
        gameState.refreshProjections()
        #expect(gameState.tutorialRun == nil, "espera a que se cierre la hoja")
        gameState.uiCoversBoard = false
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .replay)
        gameState.endReplay()
        #expect(gameState.tutorialRun == nil)
        #expect(gameState.player?.meta == before?.meta, "el repaso no toca el save")
        #expect(gameState.player?.meta.welcomeChestGiven == chestGiven)
        #expect(TutorialFlags.isLessonDone("upgrades"))
        #expect(TutorialFlags.coreCompleted())
        #expect(!gameState.tutorialPhaseActive, "el repaso del núcleo no reabre la fase")
    }

    @Test("«Ver novedades» corre el Tour aunque ya se haya visto, y no se puede terminar antes")
    func tourOnDemand() async {
        let gameState = await makeGameState()
        gameState.requestTour()
        gameState.refreshProjections()
        #expect(gameState.tutorialRun?.script == .tour)
        gameState.endReplay()
        #expect(gameState.tutorialRun?.script == .tour, "«Terminar repaso» es sólo del repaso")
    }
}
```

`FisuEvolutionUITests/TutorialReplayUITests.swift`:

```swift
import XCTest

final class TutorialReplayUITests: XCTestCase {
    func testElRepasoSePideDesdeAjustesYSeTermina() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-tutorial-lock=0.3"]
        app.launch()
        app.buttons["hud.settings"].tap()
        let settings = app.buttons["menu.card.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let replay = app.buttons["settings.tutorial.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        replay.tap()
        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertTrue(step.waitForExistence(timeout: 10))
        XCTAssertEqual(step.value as? String, "replay.core.tap")
        let end = app.buttons["tutorial.replay.end"]
        XCTAssertTrue(end.exists)
        end.tap()
        XCTAssertTrue(step.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hud.upgrades"].isHittable, "el tablero vuelve a ser del jugador")
    }
}
```

(El id de la tarjeta de Ajustes del Menú es el de hoy; el paso 0 lo confirma. Si E3a T9 escondió
el Menú en una partida nueva, el test usa el mismo fixture que `MenuUITests`.)

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `TutorialReplayTests` → no compila.

- [ ] **Step 3: El guion del repaso**

```swift
    /// El repaso (PLAN-v2 E9): el núcleo y las lecciones ya vistas, en demostración. Cada paso
    /// se vuelve de explicar y de tablero (una demostración no abre hojas: señala la pestaña).
    static func replay(seenLessons: [GameState.TutorialLesson]) -> [TutorialStep] {
        let lessons = GameState.TutorialLesson.allCases.filter(seenLessons.contains)
        return (core + lessons.flatMap(\.steps)).map { step in
            TutorialStep(
                id: "replay." + step.id,
                kind: .explain,
                target: step.surface == .board ? step.target : nil,
                boardTarget: step.boardTarget,
                surface: .board,
                hand: step.hand,
                textKey: step.textKey,
                pose: step.pose
            )
        }
    }
```

- [ ] **Step 4: El director**

En `+Tutorial`:

```swift
    /// Ajustes pide el repaso: arranca cuando el tablero vuelva a estar a la vista.
    func requestTutorialReplay() {
        tutorialEngine.requested = .replay
    }

    func requestTour() {
        tutorialEngine.requested = .tour
    }

    /// "Terminar repaso": sólo existe en el repaso.
    func endReplay() {
        guard tutorialRun?.script == .replay else { return }
        celebrationFinished(.tutorialTip)
    }
```

con `var requested: TutorialRun.Script?` en `TutorialEngine`; y en `startNextLessonIfDue()`,
antes del Tour pendiente y **sin** mirar `tutorialLessonsAutorun` ni el ritmo (lo pidió el
jugador):

```swift
        if let requested = tutorialEngine.requested, showing == nil, !uiCoversBoard, !tutorialPhaseActive {
            tutorialEngine.requested = nil
            let seen = TutorialLesson.allCases.filter { isLessonDone($0) }
            let steps = requested == .tour ? TutorialCurriculum.tour : TutorialCurriculum.replay(seenLessons: seen)
            startTutorialRun(requested, steps: steps)
            return
        }
```

⚠️ `startNextLessonIfDue` tiene hoy un `guard tutorialLessonsAutorun, …` al principio: el pedido va
**antes** de esa guarda. `finishTutorialRun` `case .replay`: sólo `celebrationFinished(.tutorialTip)`
(no marca nada). El Tour pedido desde Ajustes termina por el mismo camino de T4 (que vuelve a
marcar lo cubierto: es idempotente).

- [ ] **Step 5: "Terminar repaso" en la tarjeta**

En `TutorialOverlay`, la tarjeta recibe `onEnd: run.script == .replay ? gameState.endReplay : nil`;
`TutorialCard` dibuja, con `onEnd`, una píldora secundaria (la de "Saltar" que se borró, mismo
estilo) con `Text("tutorial.replay.end")` e id `tutorial.replay.end`.

- [ ] **Step 6: La sección de Ajustes (🔥)**

En `SettingsView`, `tutorialSection` entre `gameSection` (o la de avisos de E11) y
`purchasesSection`:

```swift
    private var tutorialSection: some View {
        VStack(spacing: Tokens.s12) {
            SectionHeader("settings.section.tutorial")
            GameCard(style: .normal) {
                VStack(spacing: Tokens.s8) {
                    ActionPill(
                        titleKey: "settings.tutorial.replay",
                        systemImage: "graduationcap.fill",
                        tint: Color("PaletteBlue"),
                        identifier: "settings.tutorial.replay"
                    ) {
                        gameState.requestTutorialReplay()
                        close()
                    }
                    ActionPill(
                        titleKey: "settings.tutorial.tour",
                        systemImage: "sparkles",
                        tint: Color("PaletteOrange"),
                        identifier: "settings.tutorial.tour"
                    ) {
                        gameState.requestTour()
                        close()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
```

(`@Environment(GameState.self) private var gameState` se suma a `SettingsView` si no lo tiene.)

- [ ] **Step 7: Los textos**

`Tools/v2/claves-pendientes/e9b-t5.json` (o directo al catálogo, si la ola se lo da):

```json
{
  "settings.section.tutorial": {"es": "Tutorial", "en": "Tutorial"},
  "settings.tutorial.replay": {"es": "Ver tutorial de nuevo", "en": "Replay the tutorial"},
  "settings.tutorial.tour": {"es": "Ver novedades de la 2.0", "en": "See what's new in 2.0"},
  "tutorial.replay.end": {"es": "Terminar repaso", "en": "End review"}
}
```

`LocalizationCompletenessTests.settingsRows` (la familia de E11 T4) suma
`settings.tutorial.replay` y `settings.tutorial.tour`.

- [ ] **Step 8: Verde, a mano y oráculo**

Run: Receta R con `TutorialReplayTests`, `TutorialTourTests`, `LocalizationCompletenessTests` →
PASS. UI: `TutorialReplayUITests`, `MenuUITests`, `SettingsPrivacyUITests` (E7b-a) y el de avisos
de E11 → PASS. A mano: el repaso entero en el SE, "Terminar repaso" a la mitad; "Ver novedades"
completo. Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 9: Commit**

```bash
git add FisuEvolution/UI/Menu/SettingsView.swift FisuEvolution/Game/State/GameState+Tutorial.swift
git add FisuEvolution/Game/Tutorial/TutorialCurriculum.swift FisuEvolution/UI/Tutorial/TutorialOverlay.swift
git add FisuEvolution/UI/Tutorial/TutorialCard.swift FisuEvolutionTests/TutorialReplayTests.swift
git add FisuEvolutionUITests/TutorialReplayUITests.swift FisuEvolutionTests/LocalizationCompletenessTests.swift
# + el catálogo
git diff --cached --stat
git commit -m "feat(ajustes): ver el tutorial de nuevo y las novedades de la 2.0, sin tocar la partida"
```

---

### Task 6: `resetEpoch` — una partida reseteada le gana a la vieja de la nube

**Objetivo:** el ⚠️ de PLAN-v2: hoy `SaveConflictResolver` elige el save de mayor
`lifetimeEarnings`, así que después de "Resetear partida" el save viejo de otro dispositivo (o de
CloudKit, cuando se prenda) **ganaría y resucitaría la partida**. Una época de reset en `meta`
que sólo sube: entre dos épocas distintas gana la más nueva **entera**, y del lado viejo sólo
sobreviven las compras (con el ORO comprado que el nuevo todavía no vio).

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` 🔥 (sólo `MetaState`: `resetEpoch`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/SaveConflictResolver.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/ResetEpochTests.swift`

**Interfaces:**
- Consumes: el mapa de compras de E1 T6c (`oroPurchases`, `revokedPurchases`, `recordOroPurchase`,
  `oroPurchasedLifetime` calculado) y su unión en el resolver.
- Produces: `MetaState.resetEpoch: Int` (default `0`, `decodeIfPresent ?? 0`);
  `SaveConflictResolver.resolve` con la regla de épocas.

- [ ] **Step 0: Lo que dejó E1 T6c**

Run: `grep -n "oroPurchases\|revokedPurchases\|func recordOroPurchase\|func revokePurchase\|var oroPurchasedLifetime" Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift Packages/EconomyKit/Sources/EconomyKit/SaveConflictResolver.swift`
Expected: el mapa, el conjunto, las dos puertas, el contador calculado y su unión en el resolver.
Si T6c eligió otros nombres, se usan ésos. Si no está, **`NEEDS_CONTEXT`** (E9 depende de T6c).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/ResetEpochTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("La época de reset en el resolver")
struct ResetEpochTests {
    private func state(epoch: Int, earnings: Double, oro: Int, purchases: [String: Int] = [:]) -> PlayerState {
        var state = fxState()
        state.meta.resetEpoch = epoch
        state.meta.lifetimeEarnings = earnings
        state.meta.oro = oro
        for (id, amount) in purchases { state.meta.recordOroPurchase(transactionID: id, amount: amount) }
        state.meta.creditedPurchases = Set(purchases.keys)
        return state
    }

    @Test("la partida reseteada gana aunque la vieja haya ganado más")
    func theResetWins() {
        let old = state(epoch: 0, earnings: 1e12, oro: 900)
        let fresh = state(epoch: 1, earnings: 10, oro: 0)
        let resolved = SaveConflictResolver.resolve(local: fresh, remote: old)
        #expect(resolved.meta.resetEpoch == 1)
        #expect(resolved.meta.lifetimeEarnings == 10)
        #expect(resolved.meta.oro == 0)
        #expect(SaveConflictResolver.resolve(local: old, remote: fresh).meta.lifetimeEarnings == 10, "en los dos órdenes")
    }

    @Test("lo comprado del lado viejo sobrevive, y su ORO se acredita una sola vez")
    func purchasesCrossTheReset() {
        let old = state(epoch: 0, earnings: 1e12, oro: 900, purchases: ["a": 160, "b": 550])
        var fresh = state(epoch: 1, earnings: 10, oro: 160, purchases: ["a": 160])
        fresh.meta.removedAds = false
        var oldWithAds = old
        oldWithAds.meta.removedAds = true
        let resolved = SaveConflictResolver.resolve(local: fresh, remote: oldWithAds)
        #expect(resolved.meta.oroPurchasedLifetime == 710)
        #expect(resolved.meta.oro == 160 + 550, "el pack «b» no lo había visto el lado nuevo")
        #expect(resolved.meta.creditedPurchases == ["a", "b"])
        #expect(resolved.meta.removedAds)
        let again = SaveConflictResolver.resolve(local: resolved, remote: oldWithAds)
        #expect(again.meta.oro == resolved.meta.oro, "idempotente")
    }

    @Test("lo ganado del lado viejo NO cruza el reset: ni logros, ni pintas, ni cofres")
    func progressDoesNotCross() {
        var old = state(epoch: 0, earnings: 1e12, oro: 900)
        old.meta.unlockedAchievements = ["a1"]
        old.meta.milestoneSkins = ["s1"]
        old.meta.chestsPending = 3
        let fresh = state(epoch: 1, earnings: 10, oro: 0)
        let resolved = SaveConflictResolver.resolve(local: fresh, remote: old)
        #expect(resolved.meta.unlockedAchievements.isEmpty)
        #expect(resolved.meta.milestoneSkins.isEmpty)
        #expect(resolved.meta.chestsPending == 0)
    }

    @Test("con la misma época, la regla de siempre")
    func sameEpoch() {
        let a = state(epoch: 2, earnings: 100, oro: 5)
        let b = state(epoch: 2, earnings: 200, oro: 7)
        #expect(SaveConflictResolver.resolve(local: a, remote: b).meta.lifetimeEarnings == 200)
    }

    @Test("un save sin la clave decodifica en época 0")
    func decodesWithoutTheKey() throws {
        let data = try JSONEncoder().encode(fxState())
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var meta = try #require(json["meta"] as? [String: Any])
        meta.removeValue(forKey: "resetEpoch")
        json["meta"] = meta
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.meta.resetEpoch == 0)
    }
}
```

(`fxState()` es el helper de estado de los tests de EK; si se llama distinto, el que use
`SaveConflictResolverTests`.)

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter ResetEpochTests` → no compila.

- [ ] **Step 3: La época**

En `MetaState` (🔥 `PlayerState.swift`), al final de las propiedades:

```swift
    /// Cuántas veces se reseteó la partida (E9). Sólo sube. Entre dos saves de épocas
    /// distintas gana el más nuevo entero: así un save viejo de otro dispositivo (o de la nube)
    /// no resucita la partida que el jugador borró.
    public var resetEpoch: Int
```

en el `init` (`resetEpoch: Int = 0`), en la asignación y en `init(from:)`
(`resetEpoch = try container.decodeIfPresent(Int.self, forKey: .resetEpoch) ?? 0`). No sube el
schema (patrón de E1 T4: un campo con default).

- [ ] **Step 4: El resolver**

Al principio de `resolve(local:remote:)`:

```swift
        if local.meta.resetEpoch != remote.meta.resetEpoch {
            return resolveAcrossReset(local: local, remote: remote)
        }
```

y:

```swift
    /// Dos épocas distintas: gana entera la del reset más nuevo. Del lado viejo cruzan sólo las
    /// compras —lo pagado con plata no se pierde por resetear— y el ORO de las compras que el
    /// lado nuevo todavía no vio (cada transacción, una vez).
    static func resolveAcrossReset(local: PlayerState, remote: PlayerState) -> PlayerState {
        var newer = local.meta.resetEpoch > remote.meta.resetEpoch ? local : remote
        let older = newer == local ? remote : local
        let unseen = older.meta.oroPurchases
            .filter { newer.meta.oroPurchases[$0.key] == nil && !older.meta.revokedPurchases.contains($0.key)
                && !newer.meta.revokedPurchases.contains($0.key) }
        newer.meta.oro += unseen.values.reduce(0, +)
        for (id, amount) in older.meta.oroPurchases { newer.meta.recordOroPurchase(transactionID: id, amount: amount) }
        for id in older.meta.revokedPurchases { newer.meta.revokePurchase(transactionID: id) }
        newer.meta.creditedPurchases.formUnion(older.meta.creditedPurchases)
        newer.meta.removedAds = newer.meta.removedAds || older.meta.removedAds
        newer.meta.ownedSkins = Array(Set(newer.meta.ownedSkins).union(older.meta.ownedSkins)).sorted()
        return newer
    }
```

(`recordOroPurchase` asigna y no suma: repetirla con el mismo id no cambia nada —el invariante de
T6c—. Si T6c expone el mapa con otro nombre, se adapta.)

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter "ResetEpochTests|SaveConflictResolverTests"`
→ PASS; `swift test --package-path Packages/EconomyKit` entero → PASS.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift
git add Packages/EconomyKit/Sources/EconomyKit/SaveConflictResolver.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/ResetEpochTests.swift
git diff --cached --stat
git commit -m "fix(save): la época de reset — una partida borrada no resucita desde otro dispositivo"
```

---

### Task 7: `ResetPlan` — lo que se muestra es lo que se ejecuta

**Objetivo:** una función pura que, dada la partida actual y una partida nueva, devuelve **el
estado resultante y el resumen con números** que la pantalla muestra. La cuenta del ORO de PLAN-v2
fijada por test: "tenés 1.250: comprados 500, ganados 750 → conservás 500".

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/ResetPlan.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/ResetPlanTests.swift`

**Interfaces:**
- Consumes: `MetaState.resetEpoch` (T6), el mapa de compras (E1 T6c), `EngagementState.offers`
  (`OffersState`: `active`, `lastClosedAt`, `everOpened`, `purchases`) y `firstLaunchDay` (E6a T1).
- Produces: `public struct ResetPlan: Sendable, Equatable` con `summary: Summary`, `result:
  PlayerState` y `static func make(current:fresh:) -> ResetPlan`; `Summary` (`oroBalance`,
  `oroPurchased`, `oroEarned`, `oroKept`, `prestigeLevel`, `unitsOnBoard`, `achievements`,
  `skinsLost`, `keepsRemoveAds`, `keptSkins`).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/ResetPlanTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("El plan del reset")
struct ResetPlanTests {
    private func current(balance: Int, purchased: [String: Int], revoked: Set<String> = []) -> PlayerState {
        var state = fxState()
        state.meta.oro = balance
        for (id, amount) in purchased { state.meta.recordOroPurchase(transactionID: id, amount: amount) }
        for id in revoked { state.meta.revokePurchase(transactionID: id) }
        state.meta.creditedPurchases = Set(purchased.keys)
        state.meta.prestigeLevel = 3
        state.meta.removedAds = true
        state.meta.ownedSkins = ["iap_skin"]
        state.meta.milestoneSkins = ["m1", "m2"]
        state.meta.unlockedAchievements = ["a1", "a2", "a3"]
        state.meta.welcomeChestGiven = true
        state.meta.resetEpoch = 4
        return state
    }

    @Test("la matriz del ORO: se conserva min(saldo, comprado)",
          arguments: [
            (1250, ["p": 500], 500, 750),
            (300, ["p": 500], 300, 0),
            (0, ["p": 500], 0, 0),
            (800, [String: Int](), 0, 800),
            (2000, ["p": 160, "q": 550], 710, 1290),
          ])
    func oroMatrix(balance: Int, purchased: [String: Int], kept: Int, earned: Int) {
        let plan = ResetPlan.make(current: current(balance: balance, purchased: purchased), fresh: fxState())
        #expect(plan.summary.oroBalance == balance)
        #expect(plan.summary.oroKept == kept)
        #expect(plan.summary.oroEarned == earned)
        #expect(plan.result.meta.oro == kept, "lo que se muestra es lo que se ejecuta")
    }

    @Test("una compra reembolsada no se conserva")
    func refundedDoesNotCount() {
        let plan = ResetPlan.make(current: current(balance: 1000, purchased: ["p": 500, "r": 300], revoked: ["r"]),
                                  fresh: fxState())
        #expect(plan.summary.oroPurchased == 500)
        #expect(plan.result.meta.oro == 500)
    }

    @Test("se conserva lo comprado; lo demás es partida nueva")
    func keptAndLost() {
        let plan = ResetPlan.make(current: current(balance: 0, purchased: ["p": 500]), fresh: fxState())
        let meta = plan.result.meta
        #expect(meta.removedAds)
        #expect(meta.ownedSkins == ["iap_skin"])
        #expect(meta.creditedPurchases == ["p"], "sin esto, una transacción re-entregada se acreditaría dos veces")
        #expect(meta.oroPurchasedLifetime == 500)
        #expect(meta.prestigeLevel == 0)
        #expect(meta.milestoneSkins.isEmpty)
        #expect(meta.unlockedAchievements.isEmpty)
        #expect(!meta.welcomeChestGiven, "vuelve el cofre de bienvenida")
        #expect(meta.resetEpoch == 5)
        #expect(plan.summary.prestigeLevel == 3)
        #expect(plan.summary.achievements == 3)
        #expect(plan.summary.skinsLost == 2)
        #expect(plan.summary.keptSkins == 1)
        #expect(plan.summary.keepsRemoveAds)
    }

    @Test("las ofertas de una vez no vuelven, y lo pagado de las ofertas queda")
    func offersSurvive() {
        var state = current(balance: 0, purchased: [:])
        state.meta.engagement.offers.everOpened = ["bienvenida"]
        state.meta.engagement.offers.purchases = ["renacer": 1]
        state.meta.engagement.firstLaunchDay = "2026-10-01"
        let plan = ResetPlan.make(current: state, fresh: fxState())
        #expect(plan.result.meta.engagement.offers.everOpened == ["bienvenida"])
        #expect(plan.result.meta.engagement.offers.purchases == ["renacer": 1])
        #expect(plan.result.meta.engagement.firstLaunchDay == "2026-10-01")
        #expect(plan.result.meta.engagement.offers.active.isEmpty)
    }

    @Test("la pinta comprada con plata sigue puesta; la de un cofre, no")
    func equippedSkins() {
        var state = current(balance: 0, purchased: [:])
        state.meta.activeSkinByType = ["homeless": "iap_skin", "chef": "m1"]
        let plan = ResetPlan.make(current: state, fresh: fxState())
        #expect(plan.result.meta.activeSkinByType == ["homeless": "iap_skin"])
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter ResetPlanTests` → no compila.

- [ ] **Step 3: El plan**

`Packages/EconomyKit/Sources/EconomyKit/ResetPlan.swift`:

```swift
import Foundation

/// "Resetear partida" (PLAN-v2 E9), puro: la pantalla muestra `summary` y el juego escribe
/// `result`, los dos salidos de la misma cuenta. Se conserva lo comprado con plata; el ORO
/// comprado sólo si no se gastó (`min(saldo, comprado)`: gastar primero el ganado, sin llevar
/// dos saldos). Todo lo demás es la partida nueva que recibe.
public struct ResetPlan: Sendable, Equatable {
    public struct Summary: Sendable, Equatable {
        public let oroBalance: Int
        public let oroPurchased: Int
        public let oroEarned: Int
        public let oroKept: Int
        public let prestigeLevel: Int
        public let unitsOnBoard: Int
        public let achievements: Int
        public let skinsLost: Int
        public let keepsRemoveAds: Bool
        public let keptSkins: Int
    }

    public let summary: Summary
    public let result: PlayerState

    public static func make(current: PlayerState, fresh: PlayerState) -> ResetPlan {
        let old = current.meta
        let kept = max(0, min(old.oro, old.oroPurchasedLifetime))
        var result = fresh
        result.meta.oro = kept
        result.meta.removedAds = old.removedAds
        result.meta.ownedSkins = old.ownedSkins
        result.meta.activeSkinByType = old.activeSkinByType.filter { old.ownedSkins.contains($0.value) }
        result.meta.creditedPurchases = old.creditedPurchases
        for (id, amount) in old.oroPurchases { result.meta.recordOroPurchase(transactionID: id, amount: amount) }
        for id in old.revokedPurchases { result.meta.revokePurchase(transactionID: id) }
        result.meta.purchasedOroReconstructed = old.purchasedOroReconstructed
        result.meta.engagement.offers.everOpened = old.engagement.offers.everOpened
        result.meta.engagement.offers.purchases = old.engagement.offers.purchases
        result.meta.engagement.offers.lastClosedAt = old.engagement.offers.lastClosedAt
        result.meta.engagement.firstLaunchDay = old.engagement.firstLaunchDay
        result.meta.resetEpoch = old.resetEpoch + 1

        let summary = Summary(
            oroBalance: old.oro,
            oroPurchased: old.oroPurchasedLifetime,
            oroEarned: old.oro - kept,
            oroKept: kept,
            prestigeLevel: old.prestigeLevel,
            unitsOnBoard: current.run.totalUnits,
            achievements: old.unlockedAchievements.count,
            skinsLost: Set(old.milestoneSkins).subtracting(old.ownedSkins).count,
            keepsRemoveAds: old.removedAds,
            keptSkins: old.ownedSkins.count
        )
        return ResetPlan(summary: summary, result: result)
    }
}
```

(Las pintas y los niveles comprados con ORO en la tienda —`engagement.shop`— **no** se conservan:
son gasto de ORO, y el ORO comprado ya vuelve como `min(saldo, comprado)`; ver duda 3. Si la
tienda guarda las pintas de ORO fuera de `milestoneSkins`, `skinsLost` las suma: el paso 0 de
T8 lo mira.)

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter ResetPlanTests` → PASS (9 casos);
`swift test` entero → PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/ResetPlan.swift
git add Packages/EconomyKit/Tests/EconomyKitTests/ResetPlanTests.swift
git diff --cached --stat
git commit -m "feat(reset): el plan del reset — se conserva lo comprado y el ORO comprado sin gastar"
```

---

### Task 8: El reset en la app — copia, partida nueva, compras re-empujadas y el núcleo de vuelta

**Objetivo:** ejecutar un `ResetPlan`: copia del save en `SaveBackups/`, la partida del plan en
memoria y en disco, todo lo de la sesión vieja fuera (celebraciones, escenario, ofertas abiertas,
cambios del tablero en vuelo: lo mismo que ya limpia `debugResetSave`), las banderas de juego
borradas y las del dispositivo intactas, los entitlements de StoreKit re-empujados **aunque no
hayan cambiado**, y el núcleo arrancando con su cofre.

**Files:**
- Create: `FisuEvolution/Game/State/GameState+Reset.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` 🔥 — **sólo** si `newGame(content:)` sigue `private` (una palabra: pasa a interno). Si E1 o la partición de §4.4 de `tasks.md` ya lo movió, no se toca.
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`debugResetSave` delega)
- Modify: `FisuEvolution/Game/State/GameState+Store.swift` (`applyStoreEntitlements(…, force:)`)
- Modify: `FisuEvolution/Managers/Store/StoreManager.swift` (`repushEntitlements()`)
- Modify: `FisuEvolution/Persistence/SaveBackupStore.swift` (`keepBeforeReset`), `FisuEvolution/Persistence/PlayerStateRepository.swift` (`keepResetCopy()`)
- Create: `FisuEvolutionTests/GameStateResetTests.swift`

**Interfaces:**
- Consumes: `ResetPlan` (T7), `TutorialFlags.wipeGameFlags()` (E9a T2), `beginTutorialPhase()`.
- Produces: `GameState.resetPlan() -> ResetPlan?`, `GameState.resetGame(_ plan: ResetPlan) async`,
  `GameState.clearSessionRuntime()`; `StoreManager.repushEntitlements()`;
  `GameState.applyStoreEntitlements(removedAds:ownedSkins:force:)`;
  `SaveBackupStore.keepBeforeReset(_:now:) -> URL?`; `PlayerStateRepository.keepResetCopy()`.

- [ ] **Step 0: Lo que limpia hoy el reset de debug**

Run: `awk '/func debugResetSave/,/^    }$/' FisuEvolution/Game/State/GameState+Debug.swift`
Expected: el cuerpo con todo lo que E1 T9, E4a, E4b, E5, E6 y E7b le sumaron (cola de cambios del
tablero, `activeEvent`, escenario, ofertas, columna…). **Todo eso se muda tal cual** a
`clearSessionRuntime()` en esta tarea: es la lista de "la sesión vieja", y el reset real no puede
olvidarse de una.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/GameStateResetTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Resetear partida", .serialized)
@MainActor
struct GameStateResetTests {
    private func makeGameState() async throws -> (GameState, URL) {
        let backups = FileManager.default.temporaryDirectory.appending(path: "reset-backups-\(UUID().uuidString)")
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: FileManager.default.temporaryDirectory.appending(path: "reset-\(UUID().uuidString).json"),
            backups: SaveBackupStore(directory: backups)
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return (gameState, backups)
    }

    @Test("una compra re-entregada después del reset no se acredita dos veces")
    func noDoubleCredit() async throws {
        let (gameState, _) = try await makeGameState()
        let catalog = try ProductCatalog.load(from: .main)
        let pack = try #require(catalog.entries.first { $0.oroAmount != nil })
        gameState.creditStorePurchase(pack, transactionID: "tx-1")
        let oroAfterPurchase = try #require(gameState.player?.meta.oro)
        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan)
        #expect(gameState.player?.meta.oro == oroAfterPurchase, "no se gastó: se conserva entero")
        gameState.creditStorePurchase(pack, transactionID: "tx-1")
        #expect(gameState.player?.meta.oro == oroAfterPurchase)
    }

    @Test("sin anuncios sigue sin anuncios, y los entitlements se re-empujan")
    func removedAdsSurvives() async throws {
        let (gameState, _) = try await makeGameState()
        gameState.applyStoreEntitlements(removedAds: true, ownedSkins: [])
        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan)
        #expect(gameState.player?.meta.removedAds == true)
    }

    @Test("queda una copia del save de antes en SaveBackups")
    func backupBeforeReset() async throws {
        let (gameState, backups) = try await makeGameState()
        await gameState.persistNow(includingCloud: false)
        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan)
        let names = try FileManager.default.contentsOfDirectory(atPath: backups.path())
        #expect(names.contains { $0.hasPrefix("reset-") })
    }

    @Test("el núcleo vuelve, el cofre también, y las banderas del dispositivo no se tocan")
    func tutorialComesBack() async throws {
        let (gameState, _) = try await makeGameState()
        TutorialFlags.setCoreCompleted(true)
        TutorialFlags.markLessonDone("upgrades")
        UserDefaults.standard.set("en", forKey: "settings.language")
        defer { UserDefaults.standard.removeObject(forKey: "settings.language") }
        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan)
        #expect(!TutorialFlags.coreCompleted())
        #expect(!TutorialFlags.isLessonDone("upgrades"))
        #expect(gameState.tutorialPhaseActive)
        #expect(gameState.tutorialRun?.script == .core)
        #expect(gameState.player?.meta.welcomeChestGiven == false)
        #expect(UserDefaults.standard.string(forKey: "settings.language") == "en")
    }

    @Test("lo que se ejecuta es lo que se mostró")
    func executesThePlan() async throws {
        let (gameState, _) = try await makeGameState()
        let plan = try #require(gameState.resetPlan())
        await gameState.resetGame(plan)
        #expect(gameState.player?.meta.oro == plan.result.meta.oro)
        #expect(gameState.player?.meta.resetEpoch == plan.result.meta.resetEpoch)
    }
}
```

(`entries`/`oroAmount` son los nombres de `ProductCatalog`; si difieren, el paso 0 de esta
tarea los mira con `grep -n "struct Entry" -A 12 FisuEvolution/Managers/Store/ProductCatalog.swift`.
Si `PlayerStateRepository` no acepta `backups:` en el `init`, se usa la propiedad `backups` que
ya tiene.)

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `-only-testing:FisuEvolutionTests/GameStateResetTests` → no compila.

- [ ] **Step 3: La copia**

`SaveBackupStore`:

```swift
    /// La foto de antes de "Resetear partida". Como las otras, nunca se borra.
    @discardableResult
    func keepBeforeReset(_ payload: Data, now: Date = Date()) -> URL? {
        write(payload, stampedBy: "reset-", now: now)
    }
```

`PlayerStateRepository`, al lado de `keepSnapshotCopy()` (mismo patrón: lee el snapshot actual y
lo copia):

```swift
    func keepResetCopy() {
        guard let payload = try? Data(contentsOf: snapshotURL) else { return }
        backups?.keepBeforeReset(payload)
    }
```

- [ ] **Step 4: Los entitlements**

`GameState+Store.swift`:

```swift
    func applyStoreEntitlements(removedAds: Bool, ownedSkins: [String], force: Bool = false) {
        guard var player else { return }
        guard force || player.meta.removedAds != removedAds || player.meta.ownedSkins != ownedSkins else { return }
        // (el resto, igual)
    }
```

`StoreManager`:

```swift
    /// Después de "Resetear partida": vuelve a empujar lo que StoreKit dice que es tuyo, aunque
    /// no haya cambiado (sin `force`, `applyStoreEntitlements` no haría nada y el coordinador de
    /// anuncios no se enteraría).
    func repushEntitlements() {
        guard let catalog else { return }
        let removedAds = !catalog.removeAdsProductIDs.isDisjoint(with: purchasedProductIDs)
        let ownedSkins = catalog.skinByProductID.filter { purchasedProductIDs.contains($0.key) }.map(\.value).sorted()
        gameState?.applyStoreEntitlements(removedAds: removedAds, ownedSkins: ownedSkins, force: true)
    }
```

(y `pushEntitlementsToGameState()` pasa a llamar a ésta sin `force`, o queda como está: lo que
sea más corto sin duplicar la cuenta.) `GameState` le llega al store como `weak var gameState`
hoy; el reset lo llama por `store?.repushEntitlements()` (la referencia que `GameState` ya tenga
del `StoreManager`; si no tiene, `resetGame` recibe un cierre `onReset` desde `SettingsView`, que
sí tiene el `@Environment(StoreManager.self)`: anotar cuál se eligió).

- [ ] **Step 5: El reset**

`FisuEvolution/Game/State/GameState+Reset.swift`:

```swift
import EconomyKit
import Foundation

/// "Resetear partida" (PLAN-v2 E9). La pantalla pide el plan, lo muestra, y si el jugador
/// confirma ejecuta ESE plan: lo que se mostró es lo que se escribe.
extension GameState {
    func resetPlan() -> ResetPlan? {
        guard let content, let player else { return nil }
        return ResetPlan.make(current: player, fresh: newGame(content: content))
    }

    func resetGame(_ plan: ResetPlan) async {
        repository?.keepResetCopy()
        clearSessionRuntime()
        var fresh = plan.result
        fresh.meta.daily.lastClaimDay = DailyRewardManager.dayString(for: Date())
        player = fresh
        TutorialFlags.wipeGameFlags()
        ftueTapped = false
        ftueSpawned = false
        ftueMerged = false
        tutorialRun = nil
        beginTutorialPhase()
        reconcileTower()
        bumpBoard()
        await persistNow()
        store?.repushEntitlements()
        Log.lifecycle.info("partida reseteada: época \(fresh.meta.resetEpoch), ORO conservado \(fresh.meta.oro)")
    }

    /// Todo lo de la sesión vieja: payloads de celebraciones, la cola, el escenario, los
    /// cambios del tablero en vuelo… Es el cuerpo que `debugResetSave` fue juntando épica por
    /// épica; vive acá para que el reset real no se olvide de ninguno.
    func clearSessionRuntime() {
        offlineReward = nil
        dailyClaim = nil
        careerPrompt = nil
        skinAward = nil
        specialDrop = nil
        towerNotice = nil
        achievementToast = nil
        pendingAchievementToasts.removeAll()
        shareCardSubject = nil
        boardCelebrationShowsSomethingNew = false
        celebrations = CelebrationQueue()
        // + lo que E1 T9, E4a, E4b, E5, E6 y E7b sumaron a `debugResetSave` (Step 0), tal cual.
    }
}
```

(El comentario `// + lo que …` es una instrucción para esta tarea: el commit lleva las líneas
reales del Step 0, no el comentario. `repository` y `store` son los nombres de las referencias
que `GameState` ya tiene; `private var repository` pasa a interno si hace falta —archivo
caliente: una palabra, en esta tarea—.) `debugResetSave` queda:

```swift
    func debugResetSave() {
        guard let plan = resetPlan() else { return }
        debugTimeScale = 1
        Task { await resetGame(plan) }
    }
```

⚠️ Esto cambia el reset de debug a **conservar lo comprado** (antes borraba todo). Es lo que el
dueño quiere mirar con ese botón desde la 2.0; si hace falta un borrado total para pruebas, ya
existe `--uitest-reset`.

- [ ] **Step 6: Verde y oráculo**

Run: Receta R con `GameStateResetTests`, `CelebrationWiringTests`, `TutorialCoreTests`,
`StoreManagerTests` → PASS. La suite store-unit en un simulador 18.6 propio (como E1 T6c) → PASS.
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Reset.swift FisuEvolution/Game/State/GameState+Debug.swift
git add FisuEvolution/Game/State/GameState+Store.swift FisuEvolution/Managers/Store/StoreManager.swift
git add FisuEvolution/Persistence/SaveBackupStore.swift FisuEvolution/Persistence/PlayerStateRepository.swift
git add FisuEvolutionTests/GameStateResetTests.swift
# + GameState.swift sólo si newGame/repository dejaron de ser private
git diff --cached --stat
git commit -m "feat(reset): resetear la partida conserva lo comprado y vuelve a empezar el núcleo"
```

---

### Task 9: La zona de peligro y `ResetGameFlowView` — tres pasos, nada deshabilitado

**Objetivo:** al final de Ajustes, una cinta y una tarjeta rosa con "Resetear partida" que empuja
`ResetGameFlowView` en la misma pila del menú. Tres pasos: (1) el resumen con números —qué se
borra, qué se conserva y la cuenta del ORO— y una casilla "Entiendo que no se puede deshacer";
(2) escribir **RESETEAR** (en inglés, **RESET**); (3) **mantener presionado 3 s** con un anillo
de progreso. Ningún botón se deshabilita: si falta algo, tiembla.

**Files:**
- Create: `FisuEvolution/UI/Menu/ResetGameFlowView.swift`
- Modify: `FisuEvolution/UI/Menu/SettingsView.swift` 🔥 (`dangerSection`, el destino de navegación)
- Strings: catálogo (dueña)
- Create: `FisuEvolutionTests/ResetGameFlowTests.swift`, `FisuEvolutionUITests/SettingsResetUITests.swift`

**Interfaces:**
- Consumes: `GameState.resetPlan()`, `resetGame(_:)` (T8); `ResetPlan.Summary` (T7);
  `GameConfirmCard` (E3b T2); `PanelCard`/`GameCard`, `ActionPill`, `SectionHeader`, `RowDivider`,
  `StateBadge` (la casa).
- Produces: `struct ResetGameFlowView: View` (`close: () -> Void`); `enum ResetFlowStep { summary, word, hold }`;
  `static func ResetGameFlowView.matchesWord(_ typed: String, word: String) -> Bool`; ids
  `settings.reset`, `reset.summary`, `reset.understand`, `reset.next`, `reset.word`, `reset.hold`,
  `reset.cancel`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/ResetGameFlowTests.swift`:

```swift
import Testing
@testable import FisuEvolution

@Suite("La palabra del reset")
struct ResetGameFlowTests {
    @Test("se acepta la palabra del idioma, sin importar mayúsculas ni espacios")
    func wordMatches() {
        #expect(ResetGameFlowView.matchesWord("RESETEAR", word: "RESETEAR"))
        #expect(ResetGameFlowView.matchesWord("  reseteár ", word: "RESETEAR") == false, "con tilde no es la palabra")
        #expect(ResetGameFlowView.matchesWord(" reset ", word: "RESET"))
        #expect(!ResetGameFlowView.matchesWord("RESE", word: "RESET"))
        #expect(!ResetGameFlowView.matchesWord("", word: "RESET"))
    }
}
```

`FisuEvolutionUITests/SettingsResetUITests.swift`:

```swift
import XCTest

final class SettingsResetUITests: XCTestCase {
    func testResetearPideCasillaPalabraYMantenerTresSegundos() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins"]
        app.launch()
        app.buttons["hud.settings"].tap()
        app.buttons["menu.card.settings"].tap()
        let reset = app.buttons["settings.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()

        XCTAssertTrue(app.descendants(matching: .any)["reset.summary"].waitForExistence(timeout: 5))
        let next = app.buttons["reset.next"]
        next.tap()
        XCTAssertTrue(app.descendants(matching: .any)["reset.summary"].exists, "sin la casilla no se avanza")
        app.buttons["reset.understand"].tap()
        next.tap()

        let word = app.textFields["reset.word"]
        XCTAssertTrue(word.waitForExistence(timeout: 5))
        word.tap()
        word.typeText("RESE")
        app.buttons["reset.next"].tap()
        XCTAssertTrue(word.exists, "con la palabra mal no se avanza")
        word.typeText("T")
        app.buttons["reset.next"].tap()

        let hold = app.buttons["reset.hold"]
        XCTAssertTrue(hold.waitForExistence(timeout: 5))
        hold.press(forDuration: 1.0)
        XCTAssertTrue(hold.exists, "soltar antes de los 3 s no resetea")
        hold.press(forDuration: 3.5)

        let step = app.descendants(matching: .any)["tutorial.step"]
        XCTAssertTrue(step.waitForExistence(timeout: 10), "la partida nueva arranca con el núcleo")
        XCTAssertEqual(step.value as? String, "core.tap")
    }
}
```

(El runner corre en inglés —trampa 6—: la palabra es **RESET**.)

- [ ] **Step 2: Verlos fallar**

Run: `/opt/homebrew/bin/xcodegen generate` y Receta R con `ResetGameFlowTests` → no compila.

- [ ] **Step 3: La pantalla**

`FisuEvolution/UI/Menu/ResetGameFlowView.swift`:

```swift
import EconomyKit
import SwiftUI

/// "Resetear partida" (PLAN-v2 E9): tres pasos con números, y ningún botón deshabilitado —el
/// que no corresponde tiembla—. Se empuja en la pila del menú, como los legales. El plan se
/// arma UNA vez al entrar: lo que se muestra es lo que se ejecuta.
struct ResetGameFlowView: View {
    enum ResetFlowStep { case summary, word, hold }

    let close: () -> Void

    @Environment(GameState.self) private var gameState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plan: ResetPlan?
    @State private var step = ResetFlowStep.summary
    @State private var understood = false
    @State private var typed = ""
    @State private var holding = false
    @State private var shakes = 0
    @State private var askLeave = false

    static let holdSeconds: Double = 3

    static func matchesWord(_ typed: String, word: String) -> Bool {
        let clean = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return !clean.isEmpty && clean.compare(word, options: .caseInsensitive) == .orderedSame
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.s12) {
                switch step {
                case .summary: summaryCard
                case .word: wordCard
                case .hold: holdCard
                }
            }
            .padding(.horizontal, MenuView.panelInset)
            .padding(.vertical, Tokens.s12)
        }
        .panelSheet { PanelTitleBanner(titleKey: "reset.title") }
        .navigationTitle(Text(verbatim: ""))
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ArtCloseButton(action: close) } }
        .overlay {
            if askLeave {
                GameConfirmCard(
                    titleKey: "reset.leave.title",
                    message: Text("reset.leave.body"),
                    confirmTitleKey: "reset.leave.confirm",
                    confirmSystemImage: "arrow.uturn.backward",
                    confirmTint: Color("PaletteBlue"),
                    cancelTitleKey: "reset.leave.stay",
                    onConfirm: close,
                    onCancel: { askLeave = false }
                )
            }
        }
        .onAppear { plan = plan ?? gameState.resetPlan() }
    }

    // MARK: Paso 1 — el resumen

    @ViewBuilder private var summaryCard: some View {
        if let summary = plan?.summary {
            GameCard(style: .normal) {
                VStack(alignment: .leading, spacing: Tokens.s8) {
                    Text("reset.summary.lost").font(Tokens.body.weight(.heavy))
                    row("reset.summary.prestige \(String(summary.prestigeLevel))")
                    row("reset.summary.units \(String(summary.unitsOnBoard))")
                    row("reset.summary.achievements \(String(summary.achievements))")
                    row("reset.summary.skins \(String(summary.skinsLost))")
                    RowDivider()
                    Text("reset.summary.kept").font(Tokens.body.weight(.heavy))
                    if summary.keepsRemoveAds { row("reset.summary.no_ads") }
                    row("reset.summary.iap_skins \(String(summary.keptSkins))")
                    RowDivider()
                    Text("reset.summary.oro \(summary.oroBalance.formatted()) \(summary.oroPurchased.formatted()) \(summary.oroEarned.formatted()) \(summary.oroKept.formatted())")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("reset.summary.oro")
                    understandToggle
                    nextButton { understood ? (step = .word) : (shakes += 1) }
                }
            }
            .background(Color.clear.accessibilityElement().accessibilityIdentifier("reset.summary"))
        }
    }

    private func row(_ key: LocalizedStringKey) -> some View {
        Text(key).font(Tokens.caption).foregroundStyle(Color("PaletteInk").opacity(0.8))
    }

    private var understandToggle: some View {
        Button { understood.toggle() } label: {
            HStack(spacing: Tokens.s8) {
                Image(systemName: understood ? "checkmark.square.fill" : "square")
                    .foregroundStyle(understood ? Color("PalettePink") : Color("PaletteInk").opacity(0.5))
                Text("reset.understand").font(Tokens.body).foregroundStyle(Color("PaletteInk"))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reset.understand")
        .accessibilityValue(Text(verbatim: understood ? "on" : "off"))
        .accessibilityAddTraits(.isToggle)
    }

    // MARK: Paso 2 — la palabra

    private var wordCard: some View {
        GameCard(style: .normal) {
            VStack(alignment: .leading, spacing: Tokens.s8) {
                Text("reset.word.prompt \(String(localized: "reset.word"))").font(Tokens.body)
                TextField(String(localized: "reset.word"), text: $typed)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .padding(Tokens.s8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color("PaletteCream")))
                    .accessibilityIdentifier("reset.word")
                nextButton {
                    Self.matchesWord(typed, word: String(localized: "reset.word")) ? (step = .hold) : (shakes += 1)
                }
            }
        }
    }

    // MARK: Paso 3 — mantener 3 s

    private var holdCard: some View {
        GameCard(style: .normal) {
            VStack(spacing: Tokens.s12) {
                Text("reset.hold.prompt").font(Tokens.body).multilineTextAlignment(.center)
                ZStack {
                    Circle().stroke(Color("PalettePink").opacity(0.25), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: holding ? 1 : 0)
                        .stroke(Color("PalettePink"), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(holding ? .linear(duration: Self.holdSeconds) : .easeOut(duration: 0.2), value: holding)
                    Text("reset.hold").font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color("PalettePink"))
                }
                .frame(width: 140, height: 140)
                .contentShape(Circle())
                .onLongPressGesture(minimumDuration: Self.holdSeconds) {
                    guard let plan else { return }
                    Task {
                        await gameState.resetGame(plan)
                        close()
                    }
                } onPressingChanged: { holding = $0 }
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text("reset.hold"))
                .accessibilityIdentifier("reset.hold")
                Button("reset.cancel") { askLeave = true }
                    .font(Tokens.caption)
                    .accessibilityIdentifier("reset.cancel")
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: El botón que tiembla

    private func nextButton(_ action: @escaping () -> Void) -> some View {
        ActionPill(titleKey: "reset.next", systemImage: "arrow.right", tint: Color("PalettePink"), identifier: "reset.next", action: action)
            .keyframeAnimator(initialValue: 0.0, trigger: shakes) { content, x in
                content.offset(x: reduceMotion ? 0 : x)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-8, duration: 0.06)
                    LinearKeyframe(8, duration: 0.08)
                    LinearKeyframe(-4, duration: 0.06)
                    LinearKeyframe(0, duration: 0.06)
                }
            }
    }
}
```

(⚠️ Con un `Int` interpolado, `LocalizedStringKey` busca `%lld` (trampa 5): por eso los números
van como `String`. `ActionPill`, `GameCard`, `RowDivider`, `PanelTitleBanner`, `ArtCloseButton`,
`panelSheet`, `MenuView.panelInset` y `Tokens` son los de la casa: si alguno cambió de firma con
E3, se usa la que haya. Si `onLongPressGesture(minimumDuration:perform:onPressingChanged:)` no
alcanza para XCUITest `press(forDuration:)`, el plan B es un `DragGesture(minimumDistance: 0)`
que guarda el inicio y confirma con un `Task.sleep` cancelable de 3 s: anotarlo.)

- [ ] **Step 4: La zona de peligro (🔥 `SettingsView`)**

Al final del `VStack` del `body`, **después** de `aboutSection` (y de la de privacidad de E7b-a,
que va antes de ésta):

```swift
    private var dangerSection: some View {
        VStack(spacing: Tokens.s12) {
            SectionHeader("settings.section.danger", tint: Color("PalettePink"))
            GameCard(style: .danger) {
                VStack(spacing: Tokens.s8) {
                    Text("settings.reset.hint")
                        .font(Tokens.caption)
                        .foregroundStyle(Color("PaletteInk").opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    NavigationLink(value: SettingsDestination.reset) {
                        ActionPillLabel(titleKey: "settings.reset", systemImage: "trash.fill", tint: Color("PalettePink"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.reset")
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
```

y `.navigationDestination(for: SettingsDestination.self) { _ in ResetGameFlowView(close: close).clearNavigationBackdrop() }`
al lado del de los legales, con `enum SettingsDestination: Hashable { case reset }`.
(`SectionHeader(_:tint:)`, `GameCard(style: .danger)` y `ActionPillLabel` —la etiqueta de una
`ActionPill` para usar dentro de un `NavigationLink`— se suman a la casa si no existen, con la
paleta rosa; si existen con otro nombre, se usa ése.)

- [ ] **Step 5: Los textos**

Al catálogo (dueña) o `Tools/v2/claves-pendientes/e9b-t9.json`:

```json
{
  "settings.section.danger": {"es": "Zona de peligro", "en": "Danger zone"},
  "settings.reset": {"es": "Resetear partida", "en": "Reset game"},
  "settings.reset.hint": {"es": "Empezás de cero. Lo que compraste con plata se queda.", "en": "Start from scratch. What you bought with money stays."},
  "reset.title": {"es": "Resetear partida", "en": "Reset game"},
  "reset.summary.lost": {"es": "Se borra:", "en": "You'll lose:"},
  "reset.summary.prestige %@": {"es": "Reencarnaciones: %@", "en": "Reincarnations: %@"},
  "reset.summary.units %@": {"es": "Empleados en la torre: %@", "en": "Workers in the tower: %@"},
  "reset.summary.achievements %@": {"es": "Logros: %@", "en": "Achievements: %@"},
  "reset.summary.skins %@": {"es": "Pintas ganadas: %@", "en": "Earned outfits: %@"},
  "reset.summary.kept": {"es": "Se conserva:", "en": "You keep:"},
  "reset.summary.no_ads": {"es": "Sin anuncios", "en": "No ads"},
  "reset.summary.iap_skins %@": {"es": "Pintas compradas: %@", "en": "Purchased outfits: %@"},
  "reset.summary.oro %@ %@ %@ %@": {"es": "ORO: tenés %1$@ (comprados %2$@, ganados %3$@) → conservás %4$@", "en": "ORO: you have %1$@ (bought %2$@, earned %3$@) → you keep %4$@"},
  "reset.understand": {"es": "Entiendo que no se puede deshacer", "en": "I understand this can't be undone"},
  "reset.next": {"es": "Seguir", "en": "Continue"},
  "reset.word": {"es": "RESETEAR", "en": "RESET"},
  "reset.word.prompt %@": {"es": "Escribí %@ para seguir.", "en": "Type %@ to continue."},
  "reset.hold.prompt": {"es": "Mantené apretado 3 segundos para borrar la partida.", "en": "Press and hold for 3 seconds to erase the game."},
  "reset.hold": {"es": "Mantener", "en": "Hold"},
  "reset.cancel": {"es": "Mejor no", "en": "Never mind"},
  "reset.leave.title": {"es": "¿Salir sin resetear?", "en": "Leave without resetting?"},
  "reset.leave.body": {"es": "Tu partida queda como está.", "en": "Your game stays as it is."},
  "reset.leave.confirm": {"es": "Salir", "en": "Leave"},
  "reset.leave.stay": {"es": "Quedarme", "en": "Stay"}
}
```

(Las claves con placeholders siguen la forma de la casa —`clave %@` con el valor interpolado
como `String`—; `LocalizationCompletenessTests` compara las firmas de los dos idiomas.)
`LocalizationCompletenessTests.settingsRows` suma `settings.reset`.

- [ ] **Step 6: Verde, a mano y oráculo**

Run: Receta R con `ResetGameFlowTests`, `GameStateResetTests`, `LocalizationCompletenessTests` →
PASS. UI: `SettingsResetUITests`, `MenuUITests`, `SettingsPrivacyUITests`, el de avisos de E11 →
PASS. A mano, en el SE y el iPad 13", en es y en: los tres pasos, cada botón tiembla cuando falta
algo (Reduce Motion: no tiembla, y no pasa nada más), el anillo se llena en 3 s y se vacía al
soltar antes; con una compra de ORO de sandbox en el `.storekit` local, la cuenta del resumen y el
ORO conservado coinciden. Capturas al reporte. `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/UI/Menu/ResetGameFlowView.swift FisuEvolution/UI/Menu/SettingsView.swift
git add FisuEvolutionTests/ResetGameFlowTests.swift FisuEvolutionUITests/SettingsResetUITests.swift
git add FisuEvolutionTests/LocalizationCompletenessTests.swift
# + los componentes de la casa si se sumaron, y el catálogo
git diff --cached --stat
git commit -m "feat(ajustes): la zona de peligro — resetear en tres pasos, con números y sin botones muertos"
```

---

### Task 10: Cierre de E9 (controlador)

1. `Tools/v2/oraculo.sh completo --limpio` y otra vez sin tocar nada → `VERDE` las dos.
2. `TutorialCoverageTests` sin huecos (`knownGaps` ya no existe) y `TutorialCurriculumTests`
   verde: es el criterio de aceptación del dueño ("explica absolutamente todo").
3. A mano, en el simulador propio (SE y iPad 13", es y en, Reduce Motion en los dos sentidos):
   instalación nueva → núcleo; una v1 real actualizada → Tour una sola vez; el repaso desde
   Ajustes con "Terminar repaso"; "Resetear partida" con una compra de ORO de sandbox (el resumen
   dice lo mismo que queda) y `SaveBackups/reset-*.json` en el contenedor.
4. `Docs/SESION-<fecha>-v2-e9b.md`; las cuatro ediciones de `Docs/HANDOFF.md` (§4 la entrada de
   E9; §5: el currículo completo y la regla de cobertura, el Tour para veteranos, el repaso que no
   toca el save, el reset con `min(saldo, comprado)` y la época de reset; §7 las trampas; §9); la
   tabla de fixtures de HANDOFF §6 suma `--uitest-veteran`; journal, `LOCK` y
   `handoffs/HANDOFF-<fecha>-v2-e9.md`. `Docs/PLAN-v2.md`: E9 marcada hecha.

---

## Lo que E9 le deja a otras épicas

- **E2b**: el reset no toca la economía; el `pacing-sim` no modela el tutorial. Nada que calibrar.
- **E10**:
  - notas a App Review: "El tutorial no se puede saltear: explica cada mecánica la primera vez
    que aparece. Ajustes › Tutorial permite verlo de nuevo. Ajustes › Zona de peligro permite
    resetear la partida; lo comprado con dinero se conserva (sin anuncios, pintas compradas y el
    ORO comprado que no se gastó)";
  - capturas: `--uitest-skip-tutorial` (escribe `tutorial.v2.*`); una captura del Tour con
    `--uitest-veteran` si el dueño la quiere para la ficha de novedades;
  - la ficha "Novedades de la 2.0" puede copiar los textos del Tour.
- **CloudKit (cuando se prenda)**: `resetEpoch` ya resuelve el "save viejo gana"; la regla de las
  compras entre épocas está pineada en `ResetEpochTests`.
- **Toda épica futura**: su lección en el currículo y su caso en `TutorialMechanic` (no compila
  sin cobertura); si su mecánica sobrevive o no al reset, en `ResetPlan` con su test.

## Para el dueño / dudas

Ninguna frena: la ejecución sigue con el default anotado.

1. **El repaso es el núcleo y lo ya visto**, todo en demostración (sólo explicar, con candado):
   con ~38 lecciones, repasar todo serían varios minutos. Por eso "Terminar repaso". **Default:**
   así; las que todavía no viste no se adelantan.
2. **El Tour no abre hojas**: el paso de Ajustes señala el Menú y lo nombra, en vez de anclarse en
   `settings.notifications` como sugería E11 (una demostración no puede abrir el menú del jugador).
   **Default:** así.
3. **Las pintas, efectos y lugares comprados con ORO no sobreviven al reset** (E6b duda 5): son
   gasto de ORO, y el ORO comprado ya vuelve como `min(saldo, comprado)`; conservarlos además
   devolvería dos veces lo mismo. **Default:** no sobreviven. Si el dueño quiere que sí, es una
   línea en `ResetPlan` y un test.
4. **Las ofertas de 24 h**: sobreviven `everOpened` (la de una vez no vuelve), `purchases` (lo
   pagado) y `lastClosedAt` (el enfriamiento, para que resetear no sea la forma de ver ofertas);
   la oferta abierta se pierde. **Default:** así.
5. **La pinta comprada con plata sigue puesta** después del reset; las demás vuelven a la de base.
   **Default:** así.
6. **El reset de debug cambia**: ahora es el real (conserva lo comprado). El borrado total para
   pruebas sigue siendo `--uitest-reset`. **Default:** así.
7. **"ORO" en inglés**: el catálogo mezcla "ORO" y "GOLD" (`tutorial.tip.oro` dice ORO;
   `tutorial.tip.prestige`, GOLD). Los textos nuevos dicen **ORO** (el nombre propio de la
   moneda, como en la tienda). **Default:** ORO; si el dueño prefiere GOLD, es un
   reemplazo en el catálogo.
8. **La tienda se enseña cuando aparece su pestaña** (sesión ≥ 1, la regla de E3a T9) y no una
   sesión después como en la v1 (E3a duda 4). **Default:** alineadas.
9. **La palabra del reset se compara sin mayúsculas pero con tildes**: "reseteár" no vale. Es una
   palabra que se copia de la pantalla. **Default:** así.
10. **38 lecciones con 20 s de aire** pueden sentirse muchas en la primera hora. Las de la v1
    llegan cuando su función aparece (la regla de oro), así que no se amontonan; si el playtest
    dice otra cosa, el número del ritmo es una constante (`TutorialPacing.gapBetweenLessons`).
    **Default:** 20 s, el número del dueño.
