# E1 — Correcciones críticas y save v6 seguro · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que la 2.0 arranque sobre una base que no pierde plata en segundo plano, no
evoluciona personajes a escondidas, no cobra videos por nada, no pisa un save ilegible y
guarda en el save v6 todo lo que las épicas siguientes necesitan.

**Architecture:** la economía nueva (offline integrado, mutadores únicos de la run, el
embudo `BoardChange` con planear y aplicar) vive **pura en EconomyKit**; `GameState`
orquesta el turno (planear → esperar el tablero visible → confirmar una sola vez) y
`BoardScene` lo reproduce con el vehículo que ya existe (`runAssistedMerge` →
`presentResolution` → vuelo → revelación → piso nuevo). El save sube **una sola vez** a v6;
lo de épicas futuras entra a `meta.engagement` sin volver a subir el schema.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit · EconomyKit (SPM puro, `Sendable`) · StoreKit 2 · Swift Testing · XCUITest ·
XcodeGen (el `.xcodeproj` no se versiona).

**Fuente:** `Docs/PLAN-v2.md` §4, "E1 — Correcciones críticas y save v6 seguro", más lo que
E2a/E3/E6/E9 le piden al save. Las decisiones de §2 **no se re-litigan**; lo que el código
contradice está en la sección final "Para el dueño / dudas".

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning
  rompe el build. Nada de `Timer` para lógica de juego (regla 2): todo reloj va por el tick
  o el flush de 8 Hz.
- **El `.xcodeproj` no se versiona: `xcodegen generate` al agregar o borrar un archivo
  Swift**, en el mismo paso en que se crea.
- **Strings nuevos** en `FisuEvolution/Resources/Localizable.xcstrings`, **es + en,
  `"extractionState" : "manual"`, en el mismo commit que la vista**. A mano, o por script
  sólo en formato canónico (2 espacios, `" : "`, objeto vacío `{\n\n}`, claves en orden
  natural, **sin salto de línea final**; trampa 29: serializar sin cambios y exigir `diff`
  vacío antes de escribir).
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor** (trampa
  9a-bis). Los marcadores para tests van como `Color.clear` de fondo, igual que
  `board.units`.
- **FisuJobs es la referencia visual de toda pantalla nueva**: `PanelCard`/`GameCard`,
  `ActionPill`/`PricePill`/`StateBadge`, pergamino, paleta y tipografía de la casa. Nada de
  botones ni alertas del sistema.
- **Nada nuevo corre bajo `--uitest*` salvo que el test lo pida** con su propio flag
  (patrón `tutorialLessonsAutorun`). Los fixtures que suben la frontera marcan lo revelado.
- **Lo que quede a medio hacer, detrás de un flag.** El orden de tareas de este plan está
  armado para que no haga falta ninguno: el embudo se conecta a la escena (T10) antes de que
  ningún productor real lo use (T12).
- Contenido data-driven: los umbrales nuevos (popup offline, gracia de eventos, reintento
  del sorteo, compensación de videos) van a los JSON. Lo único que se escribe en código es
  la foto de un migrador (como `SaveMigrator.rebalanceLevelCaps`).
- EconomyKit no conoce UI, `upgrades.json` ni StoreKit; lo que necesite ya resuelto se le
  pasa. `EconomyKitTests` **no tiene recursos**: sus tests van con datos sintéticos
  (`fxConfig`, `fxTiers`…); los hechos de los JSON reales se pinean del lado de la app.
- Código nuevo limpio y con pocos comentarios (regla del dueño: prolijidad antes que
  comentarios); los comentarios heredados no se borran por deporte.
- **Commits en español, estilo `fix(offline): …`, SIN `Co-Authored-By`.** Staging
  selectivo por archivo y `git diff --cached --stat` antes de cada commit (trampa del índice
  de `git rm`).
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente en paralelo): commit
  de la tarea → `Docs/SESION-<fecha>-v2-e1.md` (tabla de estado por tarea, el porqué y lo
  medido) → las cuatro ediciones de `Docs/HANDOFF.md` (§4 entrada de la sesión, §5 si algo
  quedó decidido, §7 si hubo trampa, §9 el mapa) → journal AVO y latido del `LOCK` →
  `handoffs/HANDOFF-<fecha>-v2-e1.md` (gitignored) al cortar la sesión. Recién ahí se
  despacha la siguiente.

## Verificación (vale para toda tarea)

**El oráculo del run** (`Tools/v2/oraculo.sh`, lo creó E0) es el juez de cada commit:

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5)
Tools/v2/oraculo.sh completo          # + Store (18.6) + UI en la matriz + pipeline + pacing-sim + Release
```

- Termina en 0 sólo si todo está verde salvo los rojos de `Tools/v2/rojos-declarados.txt`.
  **Los tests nuevos de E1 entran solos** (corre las suites enteras). Un test que se commitee
  en rojo a propósito se declara ahí con su motivo, y se saca en el commit que lo arregla.
- `rapido` al cerrar cada tarea; `completo` al cerrar las tareas con UI (T5, T10, T13, T14)
  y al cerrar la épica (T16).

**Receta R — correr UNA suite para ver el rojo y el verde** (el oráculo corre todo y tarda;
para el ciclo rojo→verde se usa esto):

```bash
# EconomyKit: --filter matchea el NOMBRE DEL TIPO, no el @Suite("…") (trampa del cierre de cofres)
swift test --package-path Packages/EconomyKit --filter OfflineModifierTests
```

```bash
# App: simulador propio por UDID, DerivedData absoluto, filtro por SUITE (sin "()" no corre nada)
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e1-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e1" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e1" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/LifecycleTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
```

⚠️ **Una corrida que no nombra los tests esperados no probó nada** ("0 tests" con éxito es
el modo de falla de `--filter` y de `-only-testing:`). Mirá la salida. Y antes de culpar al
código ante un rojo en masa: `uptime`, `ps aux | grep '[x]codebuild'` y qué árbol compiló
(trampas 16, 33 y 44).

## Las referencias de PLAN-v2 §3, verificadas contra el árbol (`a92e793`)

| Lo que cita el plan | Dónde está hoy | Estado |
|---|---|---|
| `handleScenePhase` `GameState.swift:897-917` | `GameState.swift:897-917` | ✅ la rama `.background, .inactive` sella `lastSeenTimestamp` (línea 899-904) |
| `RootView.swift:42-44` | `RootView.swift:42-44` | ✅ `.onChange(of: scenePhase) { _, newPhase in … }` tira la fase vieja |
| `OfflineCalculator.swift:26-42` | igual | ✅ y además `earnings` usa los modificadores de `now` para todo el período (línea 19) |
| clamp de `IncomeTicker` | `IncomeTicker.swift:10,41` | ✅ descarta `delta > 2` |
| watchdog sin clamp | `GameState.swift:872` (`advanceCelebrations(delta: delta)`) | ✅ |
| load que pisa `GameState.swift:532-551` | igual | ✅ `repository.load()` devuelve `nil` tanto para "no hay save" como para "no se pudo leer" (`PlayerStateRepository.swift:38-57`) |
| predicado de momento calmo `GameState.swift:468-473` | igual, pero se llama `isSafeMomentForInterstitial` | ⚠️ el nombre `isCalmMoment` es de E4 |
| "Startup comprada" `ContentSystems.swift:216-230` | igual | ✅ y **no mira la capacidad del piso destino**: si está lleno, `resyncTower` deja que el reconciliador auto-fusione o descarte en silencio |
| reconciliador `TowerReconciler.swift:56-154` | igual | ✅ |
| carrera `GameState+Actions.swift:240-288` | `GameState+Actions.swift:238-286` (`chooseCareer`) | ✅ aplica el merge sin `celebrateBoard` |
| `runAssistedMerge` `BoardScene.swift:969-1002` | igual | ✅ |
| Abogado `GameState+Bonus.swift:582-588` | `GameState+Bonus.swift:577-583` | ✅ corrido 5 líneas |
| descuento `TowerActions.swift:81,128` | `TowerActions.swift:80,127` | ✅ corrido 1 |
| contadores `TowerActions.swift:306-309` | `TowerActions.swift:302-307` | ✅ |
| `hireCost` `EconomyConfig.swift:428-438` | igual | ✅ `purchases: Int` |
| timeout del tablero `CelebrationQueue.swift:68` | igual (8 s) | ✅ |
| escritores de `maxTierReached` (6) | `TowerActions.swift:373`, `TowerReconciler.swift:96`, `PacingSimulator.swift:663`, `ContentSystems.swift:229`, `GameState+Bonus.swift:250`, `GameState+Debug.swift:166,185` | ✅ seis archivos, siete asignaciones |

Dos hallazgos que el plan maestro no nombra y E1 cubre igual, porque son la misma clase de
bug: el video **"Evolución gratis"** (`performInstantMerge`, `GameState+Bonus.swift:67-109`)
y el **"Personaje de regalo"** (`grantRareUnit`, `:112-127`) también mutan el tablero sin
turno ni revelación.

## Save v6: qué nace en E1 y qué se agrega después

El schema sube **una sola vez** (5 → 6, `PlayerState.currentSchemaVersion`). Todo campo nuevo
se decodifica con `decodeIfPresent ?? default`; `migrateV5toV6` **sólo** sube la versión y
fija los defaults que dependen de otros campos.

| Campo | Dónde | Nace en | Lo usa | Default (save viejo) |
|---|---|---|---|---|
| `revealedTier: Int` | `RunState` | **E1** (T4) | E1 (red de seguridad) | migrador: `= maxTierReached`; decoder: `?? maxTierReached` |
| `priceRelief: Double` (el `D` del amortiguador) | `RunState` | **E1** (T4) | E2a | `1` (precio v1) |
| `hireCounts`, `hireCountsByType`: `Int → Double` | `RunState` | **E1** (T3) | E2a (reintegro) | el JSON entero decodifica como `Double` sin migrar |
| `oroPurchasedLifetime: Int` | `MetaState` | **E1** (T4) | E9 (reset), E6 | `0`, y lo reconstruye T6 |
| `purchasedOroReconstructed: Bool` | `MetaState` | **E1** (T4) | T6 | migrador: `false`; decoder: `?? true` (nunca reconstruir dos veces) |
| `lastRunMaxTier: Int` (piso móvil) | `MetaState` | **E1** (T4, se graba al reencarnar) | E2a (gate) | `0` = sin requisito |
| `quickHirePinnedTypeId: String?` | `MetaState` | **E1** (T4) | E3 | `nil` |
| `unlockedTabs: Set<String>` | `MetaState` | **E1** (T4) | E3 | migrador: las seis de la v1 (veterano); decoder y partida nueva: `[]` |
| `stats.oroSpentEver: Int` | `MetaStats` | **E1** (T4, `spendOro`) | E9 | `0` |
| `engagement: EngagementState` | `MetaState` | **E1** (T4, **vacío**) | E4–E8 | `.initial` |
| `visitors`, `events` (v2) | `meta.engagement` | E4 | | `decodeIfPresent ?? .initial` |
| `packages` (buzón), `treasures` (colchón), `wheel` | `meta.engagement` | E5 | | ídem |
| `shop`, `shopSkins`, `offers` | `meta.engagement` | E6 | | ídem |
| `firstLaunchDay`, `seenCinematics` | `meta.engagement` | E6 / E8 | | ídem |
| estadísticas de cada épica | `MetaStats` | cada épica | | `MetaStats` ya decodifica todo con `decodeIfPresent ?? 0`: no sube el schema |

`MetaStats` y `EngagementState` crecen sin bump; **ningún otro campo de `run`/`meta` se agrega
después de E1 sin subir a v7**. Cada campo nuevo de `engagement` suma su regla a
`EngagementState.resolve(winner:loser:)` (lo llama `SaveConflictResolver`).

## El embudo `BoardChange` en una página

```
productor (evento, video, carrera; E4/E5: visitante, paquete)
   │  BoardChangePlanner.plan…(state, tower) → BoardChange?        ← EconomyKit, puro
   ▼
GameState.enqueueBoardChange  ── pendingBoardChanges (FIFO, en memoria)
   │  syncCelebrations: si boardIsVisibleForChanges → enqueue(.boardCelebration)
   ▼
turno .boardCelebration  (prioridad 3: el offline y la carrera pasan antes)
   │  BoardScene.startBoardCelebrationIfItsTurn → gameState.beginNextBoardChange()
   │     revalida contra el tablero de AHORA (replanea la misma intención o descarta)
   ▼
la escena navega al piso, destaca, funde (runAssistedMerge)
   │  en el punto de fusión: gameState.confirmBoardChange(id) → BoardChangeApplier.apply
   ▼
presentResolution(withinTurn: true) → vuelo → revelación (markRevealed) → piso nuevo → fin del turno

skip / watchdog / sellar al irse:  settleInFlightBoardChange() → confirma sin animación
red de seguridad: run.revealedTier < run.maxTierReached → turno de "sólo revelación"
```

**Confirmar es exactamente una vez por construcción**: `confirmBoardChange(id:)` consume
`inFlightBoardChange` y cualquier segunda llamada (completion tardío, skip, watchdog) devuelve
`nil`. Ninguna fuente de cambios toca contadores de compra.

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/OfflineCalculator.swift` | acredita toda ausencia > 2 s; `OfflineCredit` con `showsPopup` | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` | `ModifierMath.offlineFactor`; T13: `.spendingFrozen` | 1, 13 |
| `Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift` | `basePassivePerSecond` | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` | `offlinePopupMinSeconds`; `hireCost(purchases: Double)` | 1, 3 |
| `FisuEvolution/Managers/ContentSystems.swift` | Milanesa; `spendOro`; sorteo; intents de eventos; Corralito | 2, 4, 11, 12, 13 |
| `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` | `raiseFrontier`, `registerHire`, Double; campos v6; `spendOro` | 3, 4 |
| `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift` | `hire(countsAsPurchase:)`, `evolveUnit`, `placeUnit`; freeze en el quote | 3, 7, 13 |
| `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift` | **nuevo** — el contenedor vacío | 4 |
| `Packages/EconomyKit/Sources/EconomyKit/SaveConflictResolver.swift` | reglas de los campos v6 | 4 |
| `FisuEvolution/Persistence/SaveMigrator.swift` | `migrateV5toV6`, `version(of:)` | 4, 5 |
| `FisuEvolution/Persistence/PlayerStateRepository.swift` | `load() -> SaveLoadResult` | 5 |
| `FisuEvolution/Persistence/SaveBackupStore.swift` | **nuevo** — `SaveBackups/` (10 + premigración + ilegibles) | 5 |
| `FisuEvolution/UI/Popups/SaveRecoveryView.swift` | **nuevo** — "No pudimos leer tu partida" | 5 |
| `FisuEvolution/Managers/Store/PurchasedOroHistory.swift` | **nuevo** — la cuenta pura del ORO comprado en la v1 | 6 |
| `FisuEvolution/Managers/Store/StoreManager.swift` | reconstrucción con `Transaction.all` antes del listener | 6 |
| `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift` | **nuevo** — el tipo, el planificador y el aplicador | 7 |
| `FisuEvolution/App/BackgroundTasks.swift` | **nuevo** — `beginBackgroundTask` detrás de un protocolo | 8 |
| `FisuEvolution/Game/State/GameState+Lifecycle.swift` | **nuevo** — fases, sellado, offline, latido | 8 |
| `FisuEvolution/Game/State/GameState+BoardChanges.swift` | **nuevo** — el turno de los cambios | 9 |
| `FisuEvolution/Scenes/BoardScene.swift` | `presentResolution`, `playBoardChange`, `markRevealed` | 10 |
| `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` | timeout del tablero 8 → 14 s | 10 |
| `FisuEvolutionTests/EffectContractTests.swift` | **nuevo** — el contrato | 15 |

## Orden, olas y paralelismo

```
Ola 1   T1 offline ║ T2 Milanesa                       (archivos disjuntos)
Ola 2   T3 frontera y contadores → T4 save v6           (los dos tocan PlayerState)
Ola 3   T5 load/recuperación ║ T6 ORO comprado ║ T7 BoardChange (EK)
Ola 4   T8 ciclo de vida                                (GameState.swift y RootView, después de T5)
Ola 5   T9 el turno de los cambios                      (GameState.swift)
Ola 6   T10 escena + red de seguridad ║ T11 sorteo de eventos
Ola 7   T12 productores → T13 Corralito → T14 videos inaplicables   (ContentSystems/+Bonus/catálogo)
Ola 8   T15 contrato → T16 cierre
```

**Reglas del paralelismo** (trampas 16, 33 y "con una sesión paralela el build compila el
árbol AJENO"):

1. La épica corre en su worktree `.claude/worktrees/v2-e1`, rama `v2/e1-correcciones`, creada
   desde el HEAD **local** de `version-2` (no desde `origin`). Antes: `git log`/`status`,
   symlink del `.venv` del pipeline y `xcodegen generate`.
2. **Dos subagentes en paralelo nunca comparten árbol**: cada uno trabaja en
   `.claude/worktrees/v2-e1-tN` (rama `v2/e1-tN` desde la punta de `v2/e1-correcciones`), con
   su DerivedData y su simulador por UDID, y los apaga al terminar.
3. El controlador integra de a una (`git rebase` sobre la punta + `git merge --ff-only`),
   corre `oraculo.sh rapido` sobre la integración y recién ahí hace los docs de la tarea.
4. Lo que toca `GameState.swift`, `RootView.swift`, `BoardScene.swift`, `ContentSystems.swift`,
   `GameState+Bonus.swift` o el catálogo de strings **nunca** va en paralelo con otra tarea
   que toque el mismo archivo: por eso las olas 4, 5 y 7 son secuenciales.
5. Ningún subagente toca `Docs/`, `handoffs/` ni el journal: eso es del controlador.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` (async, **no** throws) | `FisuEvolutionTests/Support/GameStateFixture.swift:11` |
| `GameState` con repositorio propio | `GameState(repository:)` + `await bootstrap()` | patrón de `CelebrationWiringTests.makeGameState` |
| Vaciar la cola de celebraciones | `drainCelebrations(_:)` | `CelebrationWiringTests.swift` (privado: copiarlo si hace falta, no moverlo) |
| RNG determinista, app | `FixedRNG(seed:)` | `ContentSystemsTests.swift:9` (privado) |
| `PlayerState` con contenido real | `makeState(maxTier:coins:)` | `ContentSystemsTests.swift:41` (privado) |
| Config/estado sintético, EK | `fxConfig`, `fxEconomy`, `fxTiers`, `fxFloorTable`, `fxState`, `fxStateAndTower`, `fxSlots` | `EconomyKitTests/Fixtures.swift` |
| RNG determinista, EK | `SeededRNG` | `EconomyKitTests/Fixtures.swift` |
| Save viejo para migrar | `[String: Any]` + `JSONSerialization` | `SaveMigratorTests.v3Fixture()` |

La escalera sintética de EK: `a(1) → b(2) → c (3, nodo de carrera: c_prog/c_law) → d(4)`;
pisos `f1 {1–2}` y `f2 {3–4}`, capacidad 5; el pasivo de `a` rinde 0,3/s por unidad.
El tipo base real es `homeless`; la carrera real es `administrativo (10) → junior (11, nodo)
→ junior_programmer | _architect | _doctor | _lawyer`.

---

### Task 1: Offline — toda ausencia se paga, el popup desde 30 s y los modificadores integrados

**Objetivo:** que el offline acredite cualquier ausencia de más de 2 s (el mismo corte con el
que `IncomeTicker` descarta el delta), que el umbral de 30 s gobierne **sólo** el popup, y
que un buff pague hasta que vence y los debuffs no cuenten afuera.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/OfflineCalculator.swift` (entero)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (`ModifierMath.offlineFactor`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift` (`basePassivePerSecond`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` (`offlinePopupMinSeconds`, `offlinePopupThreshold`)
- Modify: `FisuEvolution/Resources/Data/economy.json` (`"offlinePopupMinSeconds": 30`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (`applyOfflineProgressIfNeeded(now:)`, 919-938)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/OfflineModifierTests.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/GameLoopTests.swift` (suite `OfflineTests`, 297-356)
- Create: `FisuEvolutionTests/OfflinePopupTests.swift`
- Modify: `FisuEvolutionTests/GameContentValidationTests.swift` (pin del dato)

**Interfaces:**
- Produces: `OfflineCalculator.minimumCreditedSeconds: TimeInterval` (= `IncomeTicker.deltaClampThreshold`).
- Produces: `struct OfflineCredit: Equatable, Sendable { amount: Double; elapsed: TimeInterval; showsPopup: Bool }` y `OfflineCalculator.apply(...) -> OfflineCredit`.
- Produces: `ModifierMath.offlineFactor(_:effect:from:to:) -> Double`.
- Produces: `IncomeTicker.basePassivePerSecond(state:tiers:floorTable:config:) -> Double` (todo menos los modificadores temporales).
- Produces: `EconomyConfig.offlinePopupMinSeconds: Double?` y `EconomyConfig.offlinePopupThreshold: TimeInterval`.
- Produces: `GameState.applyOfflineProgressIfNeeded(now: TimeInterval = Date().timeIntervalSince1970)`.

- [ ] **Step 1: Los tests de EconomyKit, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/OfflineModifierTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Offline: los modificadores se integran sobre la ausencia")
struct OfflineModifierTests {
    let config = fxConfig()
    let economy = fxEconomy()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        floorTable = try fxFloorTable()
    }

    /// Dos `a` con pasivo: 0,6/s de base, eficiencia 1 para que las cuentas sean limpias.
    private func producing(_ modifiers: [ActiveModifier]) throws -> PlayerState {
        var state = fxState(units: ["a": 2])
        state.run.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers)
        state.run.activeModifiers = modifiers
        state.meta.lastSeenTimestamp = 1000
        state.meta.derivedEffects.offlineEfficiency = 1
        return state
    }

    private func income(_ magnitude: Double, until expiresAt: TimeInterval) -> ActiveModifier {
        ActiveModifier(effect: .incomeMultiplier, magnitude: magnitude, expiresAt: expiresAt, sourceKey: "test")
    }

    private func earned(_ state: PlayerState, now: TimeInterval) -> Double {
        OfflineCalculator.earnings(state: state, tiers: tiers, floorTable: floorTable, config: config, now: now)
    }

    @Test("un buff que venció mientras no estabas paga su tramo")
    func expiredBuffPaysItsShare() throws {
        let state = try producing([income(3, until: 1000 + 600)])
        #expect(abs(earned(state, now: 1000 + 3600) - 0.6 * (600 * 3 + 3000)) < 1e-6)
    }

    @Test("un debuff vivo al volver no cuenta afuera")
    func debuffsAreIgnored() throws {
        let state = try producing([income(0.5, until: 1000 + 7200)])
        #expect(abs(earned(state, now: 1000 + 3600) - 0.6 * 3600) < 1e-6)
    }

    @Test("dos buffs se multiplican mientras viven los dos")
    func stackedBuffs() throws {
        let state = try producing([income(2, until: 1100), income(3, until: 1300)])
        #expect(abs(earned(state, now: 2000) - 0.6 * (100 * 6 + 200 * 3 + 700)) < 1e-6)
    }

    @Test("la ventana es la del tope y arranca cuando te fuiste")
    func windowIsCapped() throws {
        let state = try producing([income(2, until: 1000 + 9 * 3600)])
        #expect(abs(earned(state, now: 1000 + 20 * 3600) - 0.6 * 8 * 3600 * 2) < 1e-6)
    }

    @Test("sin modificadores el factor es 1")
    func neutralFactor() {
        #expect(ModifierMath.offlineFactor([], effect: .incomeMultiplier, from: 0, to: 100) == 1)
    }
}
```

En `GameLoopTests.swift`, suite `OfflineTests`: **reemplazar** `shortAbsencesCreditNothingButStamp`
y ajustar `applyCreditsCoinsAndStampsTimestamp` al tipo nuevo:

```swift
    @Test func applyCreditsCoinsAndStampsTimestamp() throws {
        var state = try unlockedState()
        let coinsBefore = state.run.coins
        let credit = OfflineCalculator.apply(state: &state, tiers: tiers, floorTable: floorTable, config: config, now: 1000 + 3600)
        #expect(credit.amount > 0)
        #expect(credit.showsPopup)
        #expect(abs(state.run.coins - coinsBefore - credit.amount) < 1e-9)
        #expect(state.meta.lastSeenTimestamp == 1000 + 3600)
    }

    @Test("más de 2 s afuera se acredita aunque no llegue al popup")
    func shortAbsencesAreCreditedSilently() throws {
        var state = try unlockedState()
        let credit = OfflineCalculator.apply(state: &state, tiers: tiers, floorTable: floorTable, config: config, now: 1010)
        #expect(credit.amount > 0)
        #expect(!credit.showsPopup)
        #expect(state.meta.lastSeenTimestamp == 1010)
    }

    @Test("2 s o menos no se acreditan: los paga el tick")
    func theTickWindowIsNotCredited() throws {
        var state = try unlockedState()
        let credit = OfflineCalculator.apply(state: &state, tiers: tiers, floorTable: floorTable, config: config, now: 1002)
        #expect(credit.amount == 0)
        #expect(state.meta.lastSeenTimestamp == 1002)
    }

    @Test("el popup aparece desde el umbral del dato")
    func popupFromTheThreshold() throws {
        var justBelow = try unlockedState()
        var atThreshold = try unlockedState()
        let threshold = config.offlinePopupThreshold
        #expect(!OfflineCalculator.apply(state: &justBelow, tiers: tiers, floorTable: floorTable, config: config, now: 1000 + threshold - 1).showsPopup)
        #expect(OfflineCalculator.apply(state: &atThreshold, tiers: tiers, floorTable: floorTable, config: config, now: 1000 + threshold).showsPopup)
    }
```

- [ ] **Step 2: Correrlos y verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "OfflineModifierTests|OfflineTests"`
Expected: no compila (`OfflineCredit`, `offlineFactor`, `offlinePopupThreshold` no existen).
Primer rojo de comportamiento a confirmar cuando compile el resto: `expiredBuffPaysItsShare`
da 2160 en vez de 2880 y `debuffsAreIgnored` da la mitad.

- [ ] **Step 3: La implementación de EconomyKit**

`ActiveModifier.swift`, dentro de `ModifierMath`:

```swift
    /// Promedio del factor de `effect` sobre `[from, to]` contando sólo los buffs
    /// (magnitud ≥ 1): cada uno paga hasta que vence y los debuffs no cuentan afuera.
    public static func offlineFactor(
        _ modifiers: [ActiveModifier],
        effect: ActiveModifier.Effect,
        from: TimeInterval,
        to: TimeInterval
    ) -> Double {
        let buffs = modifiers.filter { $0.effect == effect && $0.magnitude >= 1 }
        guard to > from else { return factor(buffs, effect: effect, now: from) }
        let cuts = buffs.map(\.expiresAt).filter { $0 > from && $0 < to }
        let edges = ([from, to] + cuts).sorted()
        let area = zip(edges, edges.dropFirst()).reduce(0.0) { total, segment in
            total + factor(buffs, effect: effect, now: segment.0) * (segment.1 - segment.0)
        }
        return area / (to - from)
    }
```

`IncomeTicker.swift`: partir `passivePerSecond` en base × factor del momento:

```swift
    public static func basePassivePerSecond(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig
    ) -> Double {
        var total = 0.0
        for (typeId, count) in state.run.units where state.run.passiveUnlocked[typeId] == true {
            guard count > 0, let type = tiers.type(id: typeId) else { continue }
            total += type.passiveYieldPerInstance
                * Double(count)
                * CharUpgrades.multiplier(typeId: typeId, levels: state.run.charUpgradeLevels, config: config)
                * floorTable.floor(forTier: type.tier).incomeMultiplier
        }
        return total * state.meta.globalMultiplier * state.meta.derivedEffects.incomeMultiplier
    }

    public static func passivePerSecond(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        now: TimeInterval
    ) -> Double {
        basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config)
            * ModifierMath.factor(state.run.activeModifiers, effect: .incomeMultiplier, now: now)
    }
```

`EconomyConfig.swift`: propiedad opcional con su valor efectivo, mismo molde que
`tapFloorMultiplierExponent` (el sintetizado la lee con `decodeIfPresent` y las cinco
fixtures que construyen el config no cambian). Sumar `offlinePopupMinSeconds: Double? = nil`
al `init` público, después de `offlineCapHours`, y:

```swift
    /// Desde cuántos segundos afuera aparece el popup de ganancias. Lo de menos
    /// se acredita igual, en silencio.
    public let offlinePopupMinSeconds: Double?

    public var offlinePopupThreshold: TimeInterval { offlinePopupMinSeconds ?? 30 }
```

`OfflineCalculator.swift`, entero:

```swift
import Foundation

public struct OfflineCredit: Equatable, Sendable {
    public let amount: Double
    public let elapsed: TimeInterval
    public let showsPopup: Bool
}

/// Offline: `min(ausencia, tope) × pasivo base × factor integrado × eficiencia`.
/// Toda la torre produce offline (F7 §3.5).
public enum OfflineCalculator {
    /// El mismo corte con el que `IncomeTicker` descarta el delta: lo que el
    /// tick no paga lo paga esto, y nada se paga dos veces.
    public static let minimumCreditedSeconds = IncomeTicker.deltaClampThreshold

    public static func earnings(
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        now: TimeInterval
    ) -> Double {
        let from = state.meta.lastSeenTimestamp
        let capped = min(max(0, now - from), config.offlineCapHours * 3600)
        guard capped > 0 else { return 0 }
        let base = IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config)
        let factor = ModifierMath.offlineFactor(
            state.run.activeModifiers, effect: .incomeMultiplier, from: from, to: from + capped
        )
        return capped * base * factor * state.meta.derivedEffects.offlineEfficiency
    }

    @discardableResult
    public static func apply(
        state: inout PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        config: EconomyConfig,
        now: TimeInterval
    ) -> OfflineCredit {
        let elapsed = max(0, now - state.meta.lastSeenTimestamp)
        let amount = elapsed > minimumCreditedSeconds
            ? earnings(state: state, tiers: tiers, floorTable: floorTable, config: config, now: now)
            : 0
        state.meta.lastSeenTimestamp = now
        if amount > 0 {
            state.run.coins += amount
            state.meta.lifetimeEarnings += amount
        }
        return OfflineCredit(
            amount: amount,
            elapsed: elapsed,
            showsPopup: amount > 0 && elapsed >= config.offlinePopupThreshold
        )
    }
}
```

`economy.json`: `"offlinePopupMinSeconds": 30,` debajo de `"offlineCapHours": 10`.

- [ ] **Step 4: EconomyKit en verde**

Run: `swift test --package-path Packages/EconomyKit --filter "OfflineModifierTests|OfflineTests"`
Expected: PASS, con los 5 + 7 tests nombrados en la salida. Después `swift test --package-path Packages/EconomyKit` entero.

- [ ] **Step 5: El lado de la app, en rojo**

`FisuEvolutionTests/OfflinePopupTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Offline: el popup sólo desde el umbral")
@MainActor
struct OfflinePopupTests {
    private func producingGame() async throws -> GameState {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        return gameState
    }

    @Test("diez segundos afuera se acreditan en silencio")
    func shortAbsenceIsSilent() async throws {
        let gameState = try await producingGame()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.lastSeenTimestamp = now - 10
        let before = try #require(gameState.player?.run.coins)
        gameState.applyOfflineProgressIfNeeded(now: now)
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.offlineReward == nil)
    }

    @Test("una hora afuera abre el popup con lo acreditado")
    func longAbsenceShowsThePopup() async throws {
        let gameState = try await producingGame()
        let now = Date().timeIntervalSince1970
        gameState.player?.meta.lastSeenTimestamp = now - 3600
        gameState.applyOfflineProgressIfNeeded(now: now)
        #expect((gameState.offlineReward?.amount ?? 0) > 0)
    }
}
```

En `GameContentValidationTests.swift`, junto a los otros pines de `economy.json`:

```swift
    @Test("el umbral del popup offline viaja en el dato, no en el default del código")
    func offlinePopupThresholdIsDeclared() {
        #expect(content.economy.offlinePopupMinSeconds == 30)
    }
```

Run: Receta R con `-only-testing:FisuEvolutionTests/OfflinePopupTests -only-testing:FisuEvolutionTests/GameContentValidationTests`.
Expected: no compila (`applyOfflineProgressIfNeeded(now:)`).

- [ ] **Step 6: `GameState.applyOfflineProgressIfNeeded`**

Reemplazar `GameState.swift:919-938`:

```swift
    /// La llama también `+Debug`, para simular una vuelta después de N horas.
    func applyOfflineProgressIfNeeded(now: TimeInterval = Date().timeIntervalSince1970) {
        guard let content, var player else { return }
        let credit = OfflineCalculator.apply(
            state: &player,
            tiers: content.tiers,
            floorTable: content.floorTable,
            config: content.economy,
            now: now
        )
        self.player = player
        guard credit.amount > 0 else { return }
        Log.economy.info("offline earnings credited: \(credit.amount) after \(credit.elapsed) s")
        guard credit.showsPopup else { return }
        // Vuelta nueva, oferta nueva: el video puede duplicar ESTE premio.
        offlineRewardDoubled = false
        offlineReward = OfflineReward(amount: credit.amount)
        audio?.play(.coin)
    }
```

- [ ] **Step 7: Verde y oráculo**

Run: Receta R con las dos suites → PASS. Después `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 8: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/OfflineCalculator.swift \
  Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift \
  Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift \
  Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/OfflineModifierTests.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/GameLoopTests.swift \
  FisuEvolution/Resources/Data/economy.json FisuEvolution/Game/State/GameState.swift \
  FisuEvolutionTests/OfflinePopupTests.swift FisuEvolutionTests/GameContentValidationTests.swift
git diff --cached --stat
git commit -m "fix(offline): acreditar toda ausencia de más de 2 s, el popup desde 30 s y los modificadores integrados"
```

---

### Task 2: La Milanesa lee su magnitud del JSON

**Objetivo:** que el permanente de la Milanesa sume el `magnitude` de `boosts.json` y no un
`0.05` escrito en `ContentSystems.swift:98`. Puede ir en paralelo con T1 (archivos disjuntos).

**Files:**
- Modify: `FisuEvolution/Managers/ContentSystems.swift` (`UpgradeManager.purchase`, `recomputeDerivedEffects`, `BoostManager.activate`, `SpecialDropManager.rollOnMerge`, `DailyRewardManager.claimIfAvailable`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (`registerShareCompleted`, `claimDailyIfAvailable`)
- Modify: `FisuEvolution/Game/State/GameState+Upgrades.swift` (`buyUpgrade`)
- Modify: `FisuEvolution/Game/State/GameState+Actions.swift` (`rollSpecialDrop`)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (cualquier llamada a `claimIfAvailable`)
- Test: `FisuEvolutionTests/ContentSystemsTests.swift`, `FisuEvolutionTests/PacingTests.swift:515` (call site)

**Interfaces:**
- Produces: `UpgradeManager.recomputeDerivedEffects(state:config:specials:viral:boosts:economy:)` — `boosts: BoostsConfig` **sin default** (un default es la forma de apagar la regla sin que nada se ponga rojo).
- Produces: el mismo parámetro `boosts:` en `UpgradeManager.purchase`, `SpecialDropManager.rollOnMerge` y `DailyRewardManager.claimIfAvailable`.

- [ ] **Step 1: El test, en rojo**

En `ContentSystemsTests.swift`, sección de boosts:

```swift
    @Test("la Milanesa suma lo que dice su JSON, no un número escrito en el código")
    func milanesaReadsItsMagnitude() throws {
        let boosts = try Self.boosts(content.boosts, milanesaMagnitude: 0.2)
        var state = makeState(maxTier: 30)
        let before = state.meta.derivedEffects.offlineEfficiency
        try BoostManager.activate(
            boostId: "milanesa", state: &state, config: boosts,
            upgrades: content.upgradesConfig, specials: content.specials, viral: content.viral,
            tiers: content.tiers, economy: economy, now: 0
        )
        #expect(abs(state.meta.derivedEffects.offlineEfficiency - before - 0.2) < 1e-9)
    }

    /// El catálogo real con la magnitud de la Milanesa cambiada: un valor que el
    /// literal viejo (0,05) no puede imitar.
    private static func boosts(_ config: BoostsConfig, milanesaMagnitude: Double) throws -> BoostsConfig {
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        var list = try #require(json["boosts"] as? [[String: Any]])
        for index in list.indices where list[index]["id"] as? String == "milanesa" {
            list[index]["magnitude"] = milanesaMagnitude
        }
        json["boosts"] = list
        return try JSONDecoder().decode(BoostsConfig.self, from: JSONSerialization.data(withJSONObject: json))
    }
```

- [ ] **Step 2: Verlo fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/ContentSystemsTests`.
Expected: FAIL — suma 0,05 en vez de 0,2.

- [ ] **Step 3: La implementación**

En `recomputeDerivedEffects` sumar el parámetro y reemplazar la línea 98:

```swift
        // Milanesa (boost permanente) reusa el dict de niveles con key propia.
        let milanesaStep = boosts.boosts.first { $0.effectType == .offlineEfficiencyPermanent }?.magnitude ?? 0
        offline += Double(state.meta.oroUpgradeLevels[BoostManager.milanesaLevelKey] ?? 0) * milanesaStep
```

`BoostManager.activate` ya recibe `config: BoostsConfig`: pasárselo como `boosts: config`.
`UpgradeManager.purchase`, `SpecialDropManager.rollOnMerge` y
`DailyRewardManager.claimIfAvailable` suman `boosts: BoostsConfig` y lo propagan. En la app,
cada llamador pasa `content.boosts` (el compilador lista los que faltan; `PacingTests.swift:515`
y `ContentSystemsTests.swift:105` también).

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con `ContentSystemsTests` y `PacingTests` → PASS (el guard de las dos
derivaciones de `PacingTests` sigue igual). Después `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Managers/ContentSystems.swift FisuEvolution/Game/State/GameState+Bonus.swift \
  FisuEvolution/Game/State/GameState+Upgrades.swift FisuEvolution/Game/State/GameState+Actions.swift \
  FisuEvolution/Game/State/GameState+Debug.swift FisuEvolutionTests/ContentSystemsTests.swift \
  FisuEvolutionTests/PacingTests.swift
git diff --cached --stat
git commit -m "fix(boosts): la Milanesa lee su magnitud del JSON"
```

---

### Task 3: Un solo mutador de la frontera, contadores en `Double` y la contratación gratis que no cuenta

**Objetivo:** `RunState.raiseFrontier(to:)` pasa a ser el **único** escritor de
`maxTierReached` (hoy hay seis archivos que lo escriben a mano), `registerHire` el único de
las curvas, los contadores pasan a `Double` (los necesita el reintegro de E2a) y
`TowerActions.hire(countsAsPurchase:)` deja de sumar la curva cuando la compra no costó nada.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` (`RunState`: `maxTierReached` `public internal(set)`, contadores `[String: Double]`, `raiseFrontier`, `registerHire`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift` (`HireQuote.purchases: Double`, `hire(…, countsAsPurchase:)`, `applyMerge:373`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerReconciler.swift:96`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift:600-604, 663, 923, 955-967` (y el reporte `floorUnlockPeakHirePurchases` con `Int(…)`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` (`hireCost(…, purchases: Double)`)
- Modify: `FisuEvolution/Managers/ContentSystems.swift:229`, `FisuEvolution/Game/State/GameState+Bonus.swift:250`, `FisuEvolution/Game/State/GameState+Debug.swift:166,185`
- Modify: `FisuEvolution/Game/State/GameState+Actions.swift` (`buySpawn`), `GameState+Hiring.swift` (`hireCharacter`, `JobRow.purchases`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/RunMutatorsTests.swift`
- Modify (mecánico): los 15 call sites de `TowerActions.hire` en EK tests suman `countsAsPurchase: true`; `ContentSystemsTests.makeState`, `AchievementEngineTests` y `StatsSnapshotTests` cambian `maxTierReached =` por `raiseFrontier(to:)`.

**Interfaces:**
- Produces: `RunState.raiseFrontier(to tier: Int) -> Bool` (`@discardableResult`; sólo sube). **E2a cuelga acá el `D ×= J` del amortiguador.**
- Produces: `RunState.registerHire(floorId: String, typeId: String)`.
- Produces: `RunState.hireCounts`, `hireCountsByType`: `[String: Double]`; `HireQuote.purchases: Double`; `EconomyConfig.hireCost(floor:tier:frontierTier:purchases: Double)`.
- Produces: `TowerActions.hire(quote:state:tower:floorTable:config:countsAsPurchase: Bool)` — **sin default** (trampa "un parámetro con default es una regla que se apaga sin ponerse roja").

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/RunMutatorsTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Run: mutadores únicos")
struct RunMutatorsTests {
    @Test("la frontera sólo sube")
    func frontierOnlyRises() {
        var run = fxState().run
        #expect(run.raiseFrontier(to: 3))
        #expect(!run.raiseFrontier(to: 2))
        #expect(run.maxTierReached == 3)
    }

    @Test("nadie fuera de RunState escribe la frontera a mano")
    func onlyRunStateWritesTheFrontier() throws {
        let sources = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/EconomyKit")
        let offenders = try FileManager.default
            .contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "PlayerState.swift" }
            .filter { try String(contentsOf: $0, encoding: .utf8).contains("maxTierReached = ") }
            .map(\.lastPathComponent)
        #expect(offenders.isEmpty, "escriben la frontera a mano: \(offenders)")
    }

    @Test("una contratación gratis no mueve la curva, pero cuenta como contratación")
    func freeHireDoesNotMoveTheCurve() throws {
        let fixture = try fxStateAndTower()
        var state = fixture.state
        var tower = fixture.tower
        state.run.coins = 0
        let quote = try #require(TowerActions.hireQuote(
            typeId: "a", state: state, config: fxConfig(), floorTable: fixture.floorTable, tiers: try fxTiers(),
            costMultiplier: 0
        ))
        try TowerActions.hire(
            quote: quote, state: &state, tower: &tower, floorTable: fixture.floorTable, config: fxConfig(),
            countsAsPurchase: false
        )
        #expect(state.run.hireCounts.isEmpty)
        #expect(state.run.hireCountsByType.isEmpty)
        #expect(state.meta.stats.totalHiresEver == 1)
    }

    @Test("los contadores de un save v5 (enteros) decodifican como Double")
    func integerCountersDecode() throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fxState())) as? [String: Any])
        var run = try #require(object["run"] as? [String: Any])
        run["hireCounts"] = ["f1": 3]
        run["hireCountsByType"] = ["a": 2]
        object["run"] = run
        let decoded = try JSONDecoder().decode(PlayerState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.run.hireCounts["f1"] == 3)
        #expect(decoded.run.hireCountsByType["a"] == 2)
    }

    @Test("un contador fraccionario cotiza entre sus vecinos")
    func fractionalCountsPriceBetweenNeighbours() throws {
        let config = fxConfig()
        let floor = try fxFloorTable()[1]
        let one = config.hireCost(floor: floor, tier: 3, frontierTier: 3, purchases: 1)
        let half = config.hireCost(floor: floor, tier: 3, frontierTier: 3, purchases: 1.5)
        let two = config.hireCost(floor: floor, tier: 3, frontierTier: 3, purchases: 2)
        #expect(one < half && half < two)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter RunMutatorsTests`
Expected: no compila (`raiseFrontier`, `countsAsPurchase`, `purchases: 1.5`). Con lo mínimo
para compilar, `onlyRunStateWritesTheFrontier` falla listando `TowerActions.swift`,
`TowerReconciler.swift` y `PacingSimulator.swift`.

- [ ] **Step 3: La implementación**

`PlayerState.swift`, en `RunState`:

```swift
    public var hireCounts: [String: Double]
    public var hireCountsByType: [String: Double]
    /// Tier máximo alcanzado en esta run. Se escribe sólo con `raiseFrontier`.
    public internal(set) var maxTierReached: Int
```

(el `init` y el `init(from:)` cambian el tipo de los dos diccionarios; `decode([String: Double].self …)`
lee igual un JSON con enteros) y, en una extensión al final de `RunState`:

```swift
extension RunState {
    @discardableResult
    public mutating func raiseFrontier(to tier: Int) -> Bool {
        guard tier > maxTierReached else { return false }
        maxTierReached = tier
        return true
    }

    public mutating func registerHire(floorId: String, typeId: String) {
        hireCounts[floorId, default: 0] += 1
        hireCountsByType[typeId, default: 0] += 1
    }
}
```

`TowerActions.hire` suma `countsAsPurchase: Bool` y reemplaza las líneas de contadores
(302-307) por:

```swift
        state.run.coins -= quote.cost
        if countsAsPurchase {
            state.run.registerHire(floorId: floor.id, typeId: quote.type.id)
        }
        state.meta.stats.totalHiresEver += 1
```

`applyMerge:373` → `state.run.raiseFrontier(to: newType.tier)`; `TowerReconciler:96` →
`run.raiseFrontier(to: newType.tier)`; `PacingSimulator:663` → `state.run.raiseFrontier(to: newType.tier)`
dentro del mismo `if`; `PacingSimulator:602-603` → `s.run.registerHire(floorId: floorId, typeId: typeId)`.
`hireCost(…, purchases: Double)` y `HireQuote.purchases: Double` (el `pow` ya trabaja en `Double`).

En la app: `ContentSystems.swift:229` y `GameState+Bonus.swift:250` → `raiseFrontier(to:)`;
`GameState+Debug.swift:185` → `player.run.raiseFrontier(to: tier)`; `debugSetMaxTier` (`:166`)
→ `player.run.raiseFrontier(to: min(max(1, tier), content.tiers.maxTier))` y su docstring
dice que ya **no baja** la frontera (anotado en dudas). `buySpawn` y `hireCharacter` pasan
`countsAsPurchase: quote.cost > 0`. `JobRow.purchases` queda `Int` y se arma con
`Int(quote.purchases.rounded(.down))`.

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (nombra `RunMutatorsTests`).
Después `Tools/v2/oraculo.sh rapido` → `VERDE`. El `pacing-sim` no se mueve (los contadores
siguen subiendo de a 1): se confirma en T16 contra la línea de base.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift \
  Packages/EconomyKit/Sources/EconomyKit/TowerReconciler.swift Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift \
  Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift Packages/EconomyKit/Tests/EconomyKitTests/ \
  FisuEvolution/Managers/ContentSystems.swift FisuEvolution/Game/State/GameState+Bonus.swift \
  FisuEvolution/Game/State/GameState+Debug.swift FisuEvolution/Game/State/GameState+Actions.swift \
  FisuEvolution/Game/State/GameState+Hiring.swift FisuEvolutionTests/ContentSystemsTests.swift \
  FisuEvolutionTests/AchievementEngineTests.swift FisuEvolutionTests/StatsSnapshotTests.swift
git diff --cached --stat
git commit -m "refactor(frontera): un solo mutador de la frontera y contadores de compra en Double"
```

---

### Task 4: Save v6 — los campos de la 2.0 y el contenedor de engagement

**Objetivo:** el único salto de schema de la 2.0, con la tabla "Save v6" de arriba; un
`MetaState.spendOro` que es la única salida de ORO; `lastRunMaxTier` grabado al reencarnar;
y las reglas de los campos nuevos en `SaveConflictResolver`.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` (campos v6 en `RunState`, `MetaState`, `MetaStats`; `spendOro`; `currentSchemaVersion = 6`)
- Create: `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PrestigeCalculator.swift` (`applyReincarnation`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/SaveConflictResolver.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift:729` (`spendOro`)
- Modify: `FisuEvolution/Managers/ContentSystems.swift:39-43` (`UpgradeManager.purchase` `.oro` → `spendOro`)
- Modify: `FisuEvolution/Persistence/SaveMigrator.swift` (`migrateV5toV6` y la cadena)
- Test: `Packages/EconomyKit/Tests/EconomyKitTests/SaveCompatibilityTests.swift`, `SaveConflictResolverTests.swift`, `FisuEvolutionTests/SaveMigratorTests.swift`

**Interfaces:**
- Produces: `RunState.revealedTier: Int`, `RunState.priceRelief: Double`.
- Produces: `MetaState.oroPurchasedLifetime: Int`, `purchasedOroReconstructed: Bool`, `lastRunMaxTier: Int`, `quickHirePinnedTypeId: String?`, `unlockedTabs: Set<String>`, `engagement: EngagementState`; `MetaStats.oroSpentEver: Int`.
- Produces: `MetaState.spendOro(_ amount: Int) -> Bool` (`@discardableResult`).
- Produces: `public struct EngagementState: Codable, Sendable, Equatable` con `static let initial` y `static func resolve(winner:loser:) -> EngagementState`.
- Produces: `SaveMigrator.v1Tabs: [String]` (foto: las seis pestañas de la v1).

- [ ] **Step 1: Los tests, en rojo**

En `SaveCompatibilityTests.swift`:

```swift
    /// Un sobre v5 tal como lo escribe la v1: sin ninguna clave de la 2.0.
    private func v5Blob(maxTier: Int) throws -> Data {
        var state = fxState()
        state.run.raiseFrontier(to: maxTier)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var run = try #require(object["run"] as? [String: Any])
        var meta = try #require(object["meta"] as? [String: Any])
        for key in ["revealedTier", "priceRelief"] { run.removeValue(forKey: key) }
        for key in ["oroPurchasedLifetime", "purchasedOroReconstructed", "lastRunMaxTier",
                    "quickHirePinnedTypeId", "unlockedTabs", "engagement"] { meta.removeValue(forKey: key) }
        object["run"] = run
        object["meta"] = meta
        object["schemaVersion"] = 5
        return try JSONSerialization.data(withJSONObject: object)
    }

    @Test("un sobre sin los campos de la 2.0 decodifica con defaults seguros")
    func v5BlobDecodesWithSafeDefaults() throws {
        let decoded = try JSONDecoder().decode(PlayerState.self, from: v5Blob(maxTier: 4))
        #expect(decoded.run.revealedTier == 4, "nunca una lluvia de revelaciones al actualizar")
        #expect(decoded.run.priceRelief == 1)
        #expect(decoded.meta.oroPurchasedLifetime == 0)
        #expect(decoded.meta.purchasedOroReconstructed, "sin el migrador no se reconstruye")
        #expect(decoded.meta.lastRunMaxTier == 0)
        #expect(decoded.meta.unlockedTabs.isEmpty)
        #expect(decoded.meta.engagement == .initial)
    }

    @Test("gastar ORO pasa por un solo lugar y lo cuenta")
    func spendOroIsTheOnlyWayOut() {
        var meta = fxState().meta
        meta.oro = 10
        #expect(!meta.spendOro(11))
        #expect(meta.oro == 10)
        #expect(meta.spendOro(4))
        #expect(meta.oro == 6)
        #expect(meta.stats.oroSpentEver == 4)
    }

    @Test("reencarnar recuerda la pared de la run que muere")
    func reincarnationRemembersTheLastRunWall() throws {
        var state = fxState()
        state.run.raiseFrontier(to: 4)
        PrestigeCalculator.applyReincarnation(
            state: &state, economy: fxEconomy(), tiers: try fxTiers(), floorTable: try fxFloorTable(), now: 0
        )
        #expect(state.meta.lastRunMaxTier == 4)
        #expect(state.run.maxTierReached == 1)
        #expect(state.run.revealedTier == 1)
    }
```

En `SaveConflictResolverTests.swift`:

```swift
    @Test("los campos de la 2.0 no retroceden al resolver")
    func v6FieldsResolve() {
        var local = fxState()
        var remote = fxState()
        local.meta.lifetimeEarnings = 10
        remote.meta.lifetimeEarnings = 5
        remote.meta.oroPurchasedLifetime = 550
        remote.meta.unlockedTabs = ["gifts"]
        local.meta.unlockedTabs = ["jobs"]
        remote.meta.stats.oroSpentEver = 30
        let resolved = SaveConflictResolver.resolve(local: local, remote: remote)
        #expect(resolved.meta.oroPurchasedLifetime == 550)
        #expect(resolved.meta.unlockedTabs == ["gifts", "jobs"])
        #expect(resolved.meta.stats.oroSpentEver == 30)
    }
```

En `FisuEvolutionTests/SaveMigratorTests.swift` (fixture al estilo de `v3Fixture()`):

```swift
    private func v5Fixture(maxTier: Int) throws -> Data {
        var state = PlayerState.newGame(
            startTypeId: "homeless", startFloorId: "alley",
            offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 1_700_000_000
        )
        state.run.raiseFrontier(to: maxTier)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var run = try #require(object["run"] as? [String: Any])
        var meta = try #require(object["meta"] as? [String: Any])
        run.removeValue(forKey: "revealedTier")
        for key in ["purchasedOroReconstructed", "unlockedTabs"] { meta.removeValue(forKey: key) }
        object["run"] = run
        object["meta"] = meta
        object["schemaVersion"] = 5
        return try JSONSerialization.data(withJSONObject: object)
    }

    @Test("un save v5 sube a v6 como veterano y con la reconstrucción pendiente")
    func v5MigratesToV6() throws {
        let state = try SaveMigrator.migrate(v5Fixture(maxTier: 14))
        #expect(state.schemaVersion == 6)
        #expect(state.run.revealedTier == 14)
        #expect(state.meta.unlockedTabs == ["jobs", "upgrades", "skins", "gifts", "store", "menu"])
        #expect(!state.meta.purchasedOroReconstructed)
    }
```

⚠️ Las dos últimas aserciones son las que **distinguen** el migrador del decoder (la trampa
del test de v5 que pasaba con o sin migrar): sin `migrateV5toV6`, `unlockedTabs` queda `[]` y
la reconstrucción en `true`.

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "SaveCompatibilityTests|SaveConflictResolverTests"`
y Receta R con `-only-testing:FisuEvolutionTests/SaveMigratorTests`.
Expected: no compila (los campos no existen); después, `v5MigratesToV6` falla con `schemaVersion == 5`.

- [ ] **Step 3: La implementación**

`EngagementState.swift`:

```swift
import Foundation

/// Lo que suman las épicas de engagement (visitantes, paquetes, colchón, ruleta,
/// tienda, ofertas). Crece campo a campo con `decodeIfPresent ?? default` y su
/// regla en `resolve`, sin volver a subir el schema del save. Nace vacío.
public struct EngagementState: Codable, Sendable, Equatable {
    public static let initial = EngagementState()

    public init() {}

    public static func resolve(winner: EngagementState, loser: EngagementState) -> EngagementState {
        winner
    }
}
```

`RunState`: `revealedTier` y `priceRelief`, con `init(…, revealedTier: Int? = nil, priceRelief: Double = 1)`
(`self.revealedTier = revealedTier ?? maxTierReached`), y en `init(from:)`:

```swift
        revealedTier = try container.decodeIfPresent(Int.self, forKey: .revealedTier) ?? maxTierReached
        priceRelief = try container.decodeIfPresent(Double.self, forKey: .priceRelief) ?? 1
```

`MetaStats`: `oroSpentEver` con `?? 0`, como sus vecinos. `MetaState`: los seis campos con
defaults en el `init` (`oroPurchasedLifetime: 0`, `purchasedOroReconstructed: true`,
`lastRunMaxTier: 0`, `quickHirePinnedTypeId: nil`, `unlockedTabs: []`, `engagement: .initial`)
y en `init(from:)` con `decodeIfPresent` y los mismos valores. Y:

```swift
    /// La única salida de ORO. El reset de E9 conserva `min(saldo, comprado)`:
    /// eso equivale a gastar primero el ORO ganado, sin llevar dos saldos.
    @discardableResult
    public mutating func spendOro(_ amount: Int) -> Bool {
        guard amount >= 0, oro >= amount else { return false }
        oro -= amount
        stats.oroSpentEver += amount
        return true
    }
```

`PlayerState.currentSchemaVersion = 6`. `PrestigeCalculator.applyReincarnation`, antes de
`state.run = .fresh(...)`: `state.meta.lastRunMaxTier = state.run.maxTierReached`.

`UpgradeManager.purchase`, caso `.oro`:

```swift
        case .oro:
            guard state.meta.spendOro(Int(price.rounded(.up))) else { throw PurchaseError.insufficientOro }
```

`PacingSimulator:729` → `state.meta.spendOro(oroPrice(of: line, atLevel: level))`.

`SaveConflictResolver.resolve`, antes del `return`:

```swift
        winner.meta.oroPurchasedLifetime = max(local.meta.oroPurchasedLifetime, remote.meta.oroPurchasedLifetime)
        winner.meta.purchasedOroReconstructed = local.meta.purchasedOroReconstructed || remote.meta.purchasedOroReconstructed
        winner.meta.unlockedTabs = local.meta.unlockedTabs.union(remote.meta.unlockedTabs)
        winner.meta.stats.oroSpentEver = max(local.meta.stats.oroSpentEver, remote.meta.stats.oroSpentEver)
        winner.meta.engagement = EngagementState.resolve(winner: winner.meta.engagement, loser: loser.meta.engagement)
```

(`revealedTier`, `priceRelief`, `lastRunMaxTier` y el pin viajan con el ganador.)

`SaveMigrator`: cada `case` de la cadena termina en `migrateV5toV6(…)`, `case 5:` nuevo, y:

```swift
    /// Las seis pestañas de la v1. Un veterano las tiene todas (PLAN-v2 E3); es
    /// una foto, como `rebalanceLevelCaps`: no se lee de `GameScreen`.
    static let v1Tabs = ["jobs", "upgrades", "skins", "gifts", "store", "menu"]

    /// v5 → v6 (la 2.0): sube la versión y fija los defaults que dependen de
    /// otros campos. El resto entra por `decodeIfPresent`.
    private static func migrateV5toV6(_ data: Data) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var run = object["run"] as? [String: Any],
              var meta = object["meta"] as? [String: Any]
        else { throw SaveMigrationError.unsupportedVersion(5) }
        run["revealedTier"] = run["maxTierReached"] as? Int ?? 1
        meta["unlockedTabs"] = v1Tabs
        meta["purchasedOroReconstructed"] = false
        object["run"] = run
        object["meta"] = meta
        object["schemaVersion"] = 6
        return try JSONSerialization.data(withJSONObject: object)
    }
```

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` (un archivo nuevo del paquete no pide
`xcodegen`: el proyecto referencia el paquete, no sus archivos) y Receta R con
`SaveMigratorTests` y `PersistenceTests` → PASS. Después `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift \
  Packages/EconomyKit/Sources/EconomyKit/PrestigeCalculator.swift Packages/EconomyKit/Sources/EconomyKit/SaveConflictResolver.swift \
  Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift Packages/EconomyKit/Tests/EconomyKitTests/SaveCompatibilityTests.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/SaveConflictResolverTests.swift FisuEvolution/Managers/ContentSystems.swift \
  FisuEvolution/Persistence/SaveMigrator.swift FisuEvolutionTests/SaveMigratorTests.swift
git diff --cached --stat
git commit -m "feat(save): save v6 con los campos de la 2.0 y el contenedor de engagement"
```

---

### Task 5: Nunca más pisar un save ilegible — copias y pantalla de recuperación

**Objetivo:** `load()` distingue `empty | loaded | unreadable`; cada carga buena deja una copia
cruda en `Application Support/SaveBackups/` (quedan las últimas 10), la primera migración deja
`save_v5_premigration.json`, y un save ilegible lleva a la fase `.recovery` con la pantalla
"No pudimos leer tu partida" (Reintentar / Empezar de nuevo, sin borrar la copia). En
recuperación **no se escribe nada**: ni `persistNow`, ni el sellado, ni la tienda.

**Files:**
- Modify: `FisuEvolution/Persistence/PlayerStateRepository.swift` (`load() -> SaveLoadResult`, `backups`)
- Create: `FisuEvolution/Persistence/SaveBackupStore.swift`
- Modify: `FisuEvolution/Persistence/SaveMigrator.swift` (`version(of:)`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (`Phase.recovery`, `bootstrap` partido, `retryLoad`, `startOverFromRecovery`, guard en `persistNow`)
- Modify: `FisuEvolution/App/RootView.swift` (`case .recovery` en el `switch` de las líneas 10-21)
- Modify: `FisuEvolution/App/FisuEvolutionApp.swift` (tienda, Game Center y anuncios sólo con `.ready`)
- Create: `FisuEvolution/UI/Popups/SaveRecoveryView.swift`
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (8 claves)
- Test: `FisuEvolutionTests/PersistenceTests.swift`; Create `FisuEvolutionTests/SaveRecoveryTests.swift`; Create `FisuEvolutionUITests/SaveRecoveryUITests.swift`

**Interfaces:**
- Consumes: `PlayerState.currentSchemaVersion` (6, de T4).
- Produces: `enum SaveLoadResult: Equatable, Sendable { case empty, loaded(PlayerState), unreadable(UnreadableSave) }` y `struct UnreadableSave: Equatable, Sendable { let reason: String; let backupURL: URL? }`.
- Produces: `struct SaveBackupStore: Sendable` — `rotate(_:now:)`, `keepPremigration(_:version:)`, `keepUnreadable(_:now:) -> URL?`, `static let keptRotating = 10`, `static func defaultDirectory() -> URL`.
- Produces: `GameState.Phase.recovery(UnreadableSave)`, `GameState.isRecoveryPending`, `retryLoad() async`, `startOverFromRecovery() async`.
- Produces: `SaveMigrator.version(of: Data) throws -> Int`; `PlayerStateRepository.debugWriteUnreadableSave()` (DEBUG).

- [ ] **Step 1: Los tests, en rojo**

`PersistenceTests.swift`: `returnsNilWithoutAnySave` pasa a esperar `.empty`,
`corruptSnapshotDoesNotCrash` a esperar `.unreadable`, y los round-trips `.loaded(state)`. Más:

```swift
    @Test("cada carga buena deja una copia y quedan las últimas diez")
    func rotatesTheLastTenGoodLoads() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "backups-\(UUID().uuidString)")
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: temporarySnapshotURL(),
            backups: SaveBackupStore(directory: directory)
        )
        await repository.save(makeState(coins: 1))
        for _ in 0..<12 { _ = await repository.load() }
        let copies = try FileManager.default.contentsOfDirectory(atPath: directory.path())
            .filter { $0.hasPrefix("save-") }
        #expect(copies.count == SaveBackupStore.keptRotating)
    }

    @Test("la copia de antes de migrar se escribe una sola vez")
    func keepsThePremigrationCopyOnce() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "backups-\(UUID().uuidString)")
        let snapshot = temporarySnapshotURL()
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(makeState())) as? [String: Any])
        object["schemaVersion"] = 5
        let v5 = try JSONSerialization.data(withJSONObject: object)
        try v5.write(to: snapshot)
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true), snapshotURL: snapshot,
            backups: SaveBackupStore(directory: directory)
        )
        _ = await repository.load()
        _ = await repository.load()
        #expect(try Data(contentsOf: directory.appending(path: "save_v5_premigration.json")) == v5)
    }
```

`FisuEvolutionTests/SaveRecoveryTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Save ilegible: nunca se pisa")
@MainActor
struct SaveRecoveryTests {
    private let garbage = Data("{\"schemaVersion\": 5, \"run\": ".utf8)

    private func unreadableGame() async throws -> (GameState, URL, URL) {
        let snapshot = FileManager.default.temporaryDirectory.appending(path: "rec-\(UUID().uuidString).json")
        let backups = FileManager.default.temporaryDirectory.appending(path: "rec-backups-\(UUID().uuidString)")
        try garbage.write(to: snapshot)
        let repository = PlayerStateRepository(
            persistence: PersistenceController(inMemory: true),
            snapshotURL: snapshot,
            backups: SaveBackupStore(directory: backups)
        )
        let gameState = GameState(repository: repository)
        await gameState.bootstrap()
        return (gameState, snapshot, backups)
    }

    @Test("un save que no decodifica deja la partida en recuperación, sin jugador")
    func unreadableSaveEntersRecovery() async throws {
        let (gameState, _, _) = try await unreadableGame()
        #expect(gameState.isRecoveryPending)
        #expect(gameState.player == nil)
    }

    @Test("en recuperación no se escribe nada")
    func recoveryBlocksEveryWrite() async throws {
        let (gameState, snapshot, _) = try await unreadableGame()
        await gameState.persistNow()
        #expect(try Data(contentsOf: snapshot) == garbage)
    }

    @Test("empezar de nuevo arranca una partida y la copia ilegible queda")
    func startOverKeepsTheCopy() async throws {
        let (gameState, _, backups) = try await unreadableGame()
        await gameState.startOverFromRecovery()
        #expect(gameState.phase == .ready)
        #expect(gameState.player != nil)
        let kept = try FileManager.default.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("unreadable-") }
        #expect(try kept.map { try Data(contentsOf: $0) } == [garbage])
    }

    @Test("reintentar con el save arreglado lo carga")
    func retryLoadsAFixedSave() async throws {
        let (gameState, snapshot, _) = try await unreadableGame()
        var state = PlayerState.newGame(
            startTypeId: "homeless", startFloorId: "alley",
            offlineEfficiencyBase: 0.35, critChanceBase: 0, now: Date().timeIntervalSince1970
        )
        state.run.coins = 777
        try JSONEncoder().encode(state).write(to: snapshot)
        await gameState.retryLoad()
        #expect(gameState.phase == .ready)
        #expect((gameState.player?.run.coins ?? 0) >= 777)
    }
}
```

`FisuEvolutionUITests/SaveRecoveryUITests.swift`:

```swift
import XCTest

/// La pantalla de recuperación: se llega con un save ilegible plantado por el fixture.
final class SaveRecoveryUITests: XCTestCase {
    func testUnSaveIlegibleMuestraLaRecuperacionYEmpezarDeNuevoJuega() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-unreadable-save", "--uitest-skip-tutorial"]
        app.launch()
        XCTAssertTrue(app.otherElements["recovery.screen"].waitForExistence(timeout: 15))
        app.buttons["recovery.retry"].tap()
        XCTAssertTrue(app.otherElements["recovery.screen"].waitForExistence(timeout: 5), "el save sigue roto: no se sale")
        app.buttons["recovery.start_over"].tap()
        app.buttons["recovery.confirm.yes"].tap()
        XCTAssertTrue(app.otherElements["board.units"].waitForExistence(timeout: 15))
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/PersistenceTests -only-testing:FisuEvolutionTests/SaveRecoveryTests`.
Expected: no compila (`SaveLoadResult`, `backups:`, `isRecoveryPending`).

- [ ] **Step 3: El repositorio y las copias**

`SaveBackupStore.swift`:

```swift
import Foundation

/// Las copias crudas del save en `Application Support/SaveBackups/`: una por cada
/// carga buena (quedan las últimas diez), la foto de antes de cada migración y
/// los saves que no se pudieron leer. Ninguna se borra al empezar de nuevo.
struct SaveBackupStore: Sendable {
    static let keptRotating = 10

    let directory: URL

    static func defaultDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "SaveBackups")
    }

    func rotate(_ payload: Data, now: Date = Date()) {
        write(payload, named: "save-\(Self.stamp(now)).json")
        let copies = (try? FileManager.default.contentsOfDirectory(atPath: directory.path())) ?? []
        for stale in copies.filter({ $0.hasPrefix("save-") }).sorted(by: >).dropFirst(Self.keptRotating) {
            try? FileManager.default.removeItem(at: directory.appending(path: stale))
        }
    }

    func keepPremigration(_ payload: Data, version: Int) {
        let name = "save_v\(version)_premigration.json"
        guard !FileManager.default.fileExists(atPath: directory.appending(path: name).path()) else { return }
        write(payload, named: name)
    }

    @discardableResult
    func keepUnreadable(_ payload: Data, now: Date = Date()) -> URL? {
        write(payload, named: "unreadable-\(Self.stamp(now)).json")
    }

    @discardableResult
    private func write(_ payload: Data, named name: String) -> URL? {
        let url = directory.appending(path: name)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try payload.write(to: url, options: .atomic)
            return url
        } catch {
            Log.persistence.error("save backup failed (\(name)): \(error)")
            return nil
        }
    }

    /// Milisegundos con ancho fijo: el orden alfabético es el cronológico.
    private static func stamp(_ date: Date) -> String {
        String(format: "%015.0f", date.timeIntervalSince1970 * 1000)
    }
}
```

⚠️ Dos cargas en el mismo milisegundo pisarían la misma copia; en el juego hay una carga por
arranque, y en el test de rotación se tolera (lo que se cuenta es el tope, no el piso).

`SaveMigrator`: `VersionPeek` queda privado y se expone
`static func version(of data: Data) throws -> Int`, que `migrate` usa en su primera línea.

`PlayerStateRepository.swift`:

```swift
enum SaveLoadResult: Equatable, Sendable {
    case empty
    case loaded(PlayerState)
    case unreadable(UnreadableSave)
}

struct UnreadableSave: Equatable, Sendable {
    let reason: String
    let backupURL: URL?
}

struct PlayerStateRepository: Sendable {
    let persistence: PersistenceController
    let snapshotURL: URL
    var backups: SaveBackupStore?

    // save(_:) y defaultSnapshotURL() sin cambios.

    /// CoreData → snapshot. Un save que existe y no se puede leer NUNCA se trata
    /// como "no hay save": el arranque grabaría una partida nueva encima.
    func load() async -> SaveLoadResult {
        var failure: String?
        var unreadable: Data?
        do {
            if let (payload, _) = try await persistence.loadLatest() {
                if let state = decode(payload, failure: &failure) { return .loaded(state) }
                unreadable = payload
            }
        } catch {
            failure = "store: \(error)"
            Log.persistence.error("CoreData load failed, trying snapshot: \(error)")
        }
        do {
            let payload = try Data(contentsOf: snapshotURL)
            if let state = decode(payload, failure: &failure) {
                Log.persistence.warning("recovered save from JSON snapshot")
                return .loaded(state)
            }
            unreadable = unreadable ?? payload
        } catch CocoaError.fileReadNoSuchFile {
        } catch {
            failure = "snapshot: \(error)"
        }
        guard let failure else { return .empty }
        Log.persistence.critical("save unreadable, not overwriting: \(failure)")
        let backupURL = unreadable.flatMap { backups?.keepUnreadable($0) }
        return .unreadable(UnreadableSave(reason: failure, backupURL: backupURL))
    }

    private func decode(_ payload: Data, failure: inout String?) -> PlayerState? {
        do {
            let version = try SaveMigrator.version(of: payload)
            if version < PlayerState.currentSchemaVersion {
                backups?.keepPremigration(payload, version: version)
            }
            let state = try SaveMigrator.migrate(payload)
            backups?.rotate(payload)
            return state
        } catch {
            failure = "\(error)"
            Log.persistence.error("save payload unreadable: \(error)")
            return nil
        }
    }

    #if DEBUG
    func debugWriteUnreadableSave() async {
        let garbage = Data("{\"schemaVersion\": 5, \"run\": ".utf8)
        try? await persistence.save(payload: garbage, schemaVersion: 5, updatedAt: Date())
        try? garbage.write(to: snapshotURL, options: .atomic)
    }
    #endif
}
```

- [ ] **Step 4: La fase `.recovery` en `GameState`**

`Phase` suma `case recovery(UnreadableSave)` y:

```swift
    var isRecoveryPending: Bool {
        if case .recovery = phase { true } else { false }
    }
```

`bootstrap()` se parte en tres **sin cambiar el orden de nada**: cargar contenido y armar el
repositorio (con `backups: SaveBackupStore(directory: SaveBackupStore.defaultDirectory())`),
resolver el save, y `finishBootstrap(isFreshInstall:)` con todo lo que hoy va de
`reconcileTower()` (línea 553) a `phase = .ready` (línea 715). La resolución reemplaza las
líneas 531-551:

```swift
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitest-unreadable-save") {
                await repository.debugWriteUnreadableSave()
            }
            #endif
            let isFreshInstall: Bool
            switch forceNewGame ? .empty : await repository.load() {
            case .loaded(let saved):
                var resolved = saved
                if let cloudSync, let remote = try? await cloudSync.fetch() {
                    resolved = SaveConflictResolver.resolve(local: saved, remote: remote)
                }
                player = resolved
                isFreshInstall = false
                Log.lifecycle.info("save loaded: prestige \(resolved.meta.prestigeLevel), maxTier \(resolved.run.maxTierReached)")
            case .empty:
                let fresh = newGame(content: content)
                player = fresh
                await repository.save(fresh)
                isFreshInstall = true
                Log.lifecycle.info("new game started")
            case .unreadable(let info):
                phase = .recovery(info)
                return
            }
            finishBootstrap(isFreshInstall: isFreshInstall)
```

con `newGame(content:)` privado (el `PlayerState.newGame(...)` de hoy) y:

```swift
    func retryLoad() async {
        guard isRecoveryPending else { return }
        phase = .loading
        await bootstrap()
    }

    /// Empieza una partida nueva. La copia ilegible ya quedó en `SaveBackups/`.
    func startOverFromRecovery() async {
        guard isRecoveryPending, let content, let repository else { return }
        let fresh = newGame(content: content)
        player = fresh
        phase = .loading
        await repository.save(fresh)
        finishBootstrap(isFreshInstall: true)
    }
```

`persistNow()` arranca con `guard !isRecoveryPending, let repository, let player else { return }`
(hoy ya sale por `player == nil`; el guard explícito es el que sobrevive al primer fixture o
crédito que asigne un `player` antes de tiempo).

- [ ] **Step 5: La pantalla y el arranque de servicios**

`RootView`: `case .recovery: SaveRecoveryView()` en el `switch`.

`SaveRecoveryView.swift` (FisuJobs de referencia: pergamino en `PanelCard`, título en
`PanelTitleBanner`, acciones en `ActionPill`; la confirmación es un segundo estado de la
misma tarjeta, **no** una alerta del sistema):

```swift
import SwiftUI

struct SaveRecoveryView: View {
    @Environment(GameState.self) private var gameState
    @State private var confirmingStartOver = false
    @State private var isWorking = false

    var body: some View {
        ZStack {
            Color("PaletteCream").ignoresSafeArea()
            PanelCard {
                VStack(spacing: Tokens.s16) {
                    PanelTitleBanner(titleKey: confirmingStartOver ? "recovery.confirm.title" : "recovery.title")
                    Text(confirmingStartOver ? "recovery.confirm.body" : "recovery.body")
                        .font(Tokens.body)
                        .foregroundStyle(Color("PaletteInk"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    actions
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, Tokens.s16)
        }
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("recovery.screen")
        )
    }

    @ViewBuilder private var actions: some View {
        if isWorking {
            ProgressView().tint(Color("PaletteInk"))
        } else if confirmingStartOver {
            HStack(spacing: Tokens.s12) {
                ActionPill(titleKey: "recovery.confirm.no", systemImage: "arrow.uturn.backward",
                           tint: Color("PaletteBrown"), identifier: "recovery.confirm.no") {
                    confirmingStartOver = false
                }
                ActionPill(titleKey: "recovery.confirm.yes", systemImage: "sparkles",
                           tint: Color("PalettePink"), identifier: "recovery.confirm.yes") {
                    perform { await gameState.startOverFromRecovery() }
                }
            }
        } else {
            HStack(spacing: Tokens.s12) {
                ActionPill(titleKey: "recovery.retry", systemImage: "arrow.clockwise",
                           identifier: "recovery.retry") {
                    perform { await gameState.retryLoad() }
                }
                ActionPill(titleKey: "recovery.start_over", systemImage: "sparkles",
                           tint: Color("PaletteOrange"), identifier: "recovery.start_over") {
                    confirmingStartOver = true
                }
            }
        }
    }

    private func perform(_ work: @escaping @MainActor () async -> Void) {
        isWorking = true
        Task {
            await work()
            isWorking = false
        }
    }
}
```

`FisuEvolutionApp`: lo que hoy va después de `await gameState.bootstrap()` (tienda, Game
Center, anuncios) pasa a `startServices()`, que corre **sólo con `phase == .ready` y una sola
vez** (`@State private var servicesStarted = false`), llamada al final del `.task` y desde
`.onChange(of: gameState.phase) { _, phase in if phase == .ready { Task { await startServices() } } }`.
Es lo que impide que la tienda haga `finish()` de un consumible sin save donde acreditarlo
(hoy `creditStorePurchase` sale por `player == nil` y la transacción se finaliza igual).

Claves nuevas (es / en), a mano, `"extractionState" : "manual"`, en orden natural:

| Clave | es | en |
|---|---|---|
| `recovery.body` | Guardamos una copia intacta. Probá de nuevo; si sigue sin andar, podés empezar una partida nueva y la copia queda guardada. | We kept an untouched copy. Try again; if it still fails, you can start a new game and the copy stays saved. |
| `recovery.confirm.body` | Tu partida de ahora no se borra: la copia queda guardada en el teléfono. | Your current game isn't deleted: the copy stays on your phone. |
| `recovery.confirm.no` | Mejor no | Not now |
| `recovery.confirm.title` | ¿Empezar una partida nueva? | Start a new game? |
| `recovery.confirm.yes` | Sí, empezar | Yes, start over |
| `recovery.retry` | Reintentar | Try again |
| `recovery.start_over` | Empezar de nuevo | Start over |
| `recovery.title` | No pudimos leer tu partida | We couldn't read your game |

- [ ] **Step 6: Verde, UI y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con las dos suites unitarias → PASS;
Receta R con `-only-testing:FisuEvolutionUITests/SaveRecoveryUITests` → PASS (y una captura
de la pantalla en el SE y en el 16 Pro, comparada a ojo contra FisuJobs). Después
`Tools/v2/oraculo.sh completo` → `VERDE` (toca `RootView`, el arranque y la tienda).

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Persistence/PlayerStateRepository.swift FisuEvolution/Persistence/SaveBackupStore.swift \
  FisuEvolution/Persistence/SaveMigrator.swift FisuEvolution/Game/State/GameState.swift \
  FisuEvolution/App/RootView.swift FisuEvolution/App/FisuEvolutionApp.swift \
  FisuEvolution/UI/Popups/SaveRecoveryView.swift FisuEvolution/Resources/Localizable.xcstrings \
  FisuEvolutionTests/PersistenceTests.swift FisuEvolutionTests/SaveRecoveryTests.swift \
  FisuEvolutionUITests/SaveRecoveryUITests.swift
git diff --cached --stat
git commit -m "fix(save): nunca pisar un save ilegible — copias y pantalla de recuperación"
```

---

### Task 6: Reconstruir el ORO comprado en la v1 desde `Transaction.all`

**Objetivo:** `meta.oroPurchasedLifetime` nace en 0 para los saves de la v1; una sola vez, antes
de que el listener de StoreKit procese nada, se suma el ORO de las transacciones de packs de
ORO **que la v1 ya acreditó** (están en `creditedPurchases`), con los montos de la v1. Si falla,
queda en 0. De ahí en más, cada compra de ORO suma a `oroPurchasedLifetime` en el acto. Va en
paralelo con T5 y T7.

**Files:**
- Create: `FisuEvolution/Managers/Store/PurchasedOroHistory.swift`
- Modify: `FisuEvolution/Managers/Store/StoreManager.swift` (`start(gameState:)`, antes de `updatesTask`)
- Modify: `FisuEvolution/Game/State/GameState+Store.swift` (`creditStorePurchase`, `needsPurchasedOroReconstruction`, `completePurchasedOroReconstruction(records:)`)
- Modify: `FisuEvolution/Info.plist` (`SKIncludeConsumableInAppPurchaseHistory = YES`; no tiene `INFOPLIST_KEY_*`)
- Create: `FisuEvolutionTests/PurchasedOroHistoryTests.swift`
- Modify: `FisuEvolutionTests/StoreManagerTests.swift` (corre en 18.6, suite `store-unit` del oráculo)

**Interfaces:**
- Consumes: `MetaState.oroPurchasedLifetime`, `purchasedOroReconstructed`, `creditedPurchases` (T4).
- Produces: `enum PurchasedOroHistory` con `static let v1OroAmountByProductID: [String: Int]`, `struct Record: Equatable, Sendable { transactionID, productID, isRevoked }` y `static func reconstruct(records:creditedTransactionIDs:) -> Int`.
- Produces: `GameState.needsPurchasedOroReconstruction: Bool`, `GameState.completePurchasedOroReconstruction(records:)`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/PurchasedOroHistoryTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("ORO comprado en la v1")
@MainActor
struct PurchasedOroHistoryTests {
    private let small = "com.fisuevolution.iap.oro_small"
    private let large = "com.fisuevolution.iap.oro_large"

    @Test("suma sólo lo que la v1 acreditó, con los montos de la v1")
    func reconstructsWhatV1Credited() {
        let records: [PurchasedOroHistory.Record] = [
            .init(transactionID: "1", productID: small, isRevoked: false),
            .init(transactionID: "2", productID: large, isRevoked: false),
            .init(transactionID: "3", productID: small, isRevoked: true),
            .init(transactionID: "4", productID: small, isRevoked: false),
            .init(transactionID: "5", productID: "com.fisuevolution.iap.coins_small", isRevoked: false),
        ]
        let total = PurchasedOroHistory.reconstruct(records: records, creditedTransactionIDs: ["1", "2", "3", "5"])
        #expect(total == 250 + 2000)
    }

    @Test("los montos de la v1 son una foto: no siguen a products.json")
    func v1AmountsAreFrozen() {
        #expect(PurchasedOroHistory.v1OroAmountByProductID == [
            "com.fisuevolution.iap.oro_small": 250,
            "com.fisuevolution.iap.oro_medium": 750,
            "com.fisuevolution.iap.oro_large": 2000,
        ])
    }

    @Test("se reconstruye una sola vez y una compra nueva suma en el acto")
    func reconstructionRunsOnceAndNewPurchasesCount() async throws {
        let gameState = await makeGameState()
        gameState.player?.meta.purchasedOroReconstructed = false
        gameState.player?.meta.creditedPurchases = ["1"]
        let record = PurchasedOroHistory.Record(transactionID: "1", productID: small, isRevoked: false)
        gameState.completePurchasedOroReconstruction(records: [record])
        gameState.completePurchasedOroReconstruction(records: [record])
        #expect(gameState.player?.meta.oroPurchasedLifetime == 250)
        #expect(gameState.needsPurchasedOroReconstruction == false)
    }

    @Test("el bundle pide el historial de consumibles")
    func infoPlistIncludesConsumables() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "SKIncludeConsumableInAppPurchaseHistory") as? Bool == true)
    }
}
```

En `StoreManagerTests.swift` (con su `SKTestSession` de siempre): comprar `oro_small`, poner
`purchasedOroReconstructed = false` y `oroPurchasedLifetime = 0`, correr la reconstrucción por
el camino de `start` y esperar **250**. ⚠️ Si el StoreKit Testing de 18.6 no lista consumibles
finalizados en `Transaction.all` aun con la clave, el test se declara en
`Tools/v2/rojos-declarados.txt` (`store-unit reconstruyeElOroDeLaV1  # StoreKit Testing no lista consumibles finalizados`)
y la garantía queda en la función pura; no se debilita la aserción.

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/PurchasedOroHistoryTests`.
Expected: no compila (`PurchasedOroHistory`).

- [ ] **Step 3: La implementación**

`PurchasedOroHistory.swift`:

```swift
import Foundation

/// El ORO que la v1 vendió, reconstruido desde el historial de StoreKit.
enum PurchasedOroHistory {
    /// Lo que la v1 acreditaba por cada pack. Es una foto, como
    /// `SaveMigrator.rebalanceLevelCaps`: E6 reescala `products.json` y esta
    /// cuenta no puede cambiar con él.
    static let v1OroAmountByProductID: [String: Int] = [
        "com.fisuevolution.iap.oro_small": 250,
        "com.fisuevolution.iap.oro_medium": 750,
        "com.fisuevolution.iap.oro_large": 2000,
    ]

    struct Record: Equatable, Sendable {
        let transactionID: String
        let productID: String
        let isRevoked: Bool
    }

    /// Sólo cuenta lo que la v1 acreditó: una transacción sin acreditar la
    /// entrega el listener por el camino de siempre, que ya suma al contador.
    static func reconstruct(records: [Record], creditedTransactionIDs: Set<String>) -> Int {
        records
            .filter { !$0.isRevoked && creditedTransactionIDs.contains($0.transactionID) }
            .compactMap { v1OroAmountByProductID[$0.productID] }
            .reduce(0, +)
    }
}
```

`GameState+Store.swift`:

```swift
    var needsPurchasedOroReconstruction: Bool {
        player.map { !$0.meta.purchasedOroReconstructed } ?? false
    }

    func completePurchasedOroReconstruction(records: [PurchasedOroHistory.Record]) {
        guard var player, !player.meta.purchasedOroReconstructed else { return }
        player.meta.oroPurchasedLifetime += PurchasedOroHistory.reconstruct(
            records: records, creditedTransactionIDs: player.meta.creditedPurchases
        )
        player.meta.purchasedOroReconstructed = true
        self.player = player
        scheduleSave()
    }
```

y en `creditStorePurchase`, caso `.oro`, después de `player.meta.oro += amount`:
`player.meta.oroPurchasedLifetime += amount`.

`StoreManager.start(gameState:)`, **antes** de crear `updatesTask`:

```swift
        await reconstructPurchasedOroIfNeeded()
```

```swift
    /// Una vez por save de la v1. Corre antes del listener: así ninguna
    /// transacción nueva entra a la cuenta como si fuera de la v1.
    private func reconstructPurchasedOroIfNeeded() async {
        guard let gameState, gameState.needsPurchasedOroReconstruction else { return }
        var records: [PurchasedOroHistory.Record] = []
        for await result in Transaction.all {
            guard case .verified(let transaction) = result else { continue }
            records.append(.init(
                transactionID: String(transaction.id),
                productID: transaction.productID,
                isRevoked: transaction.revocationDate != nil
            ))
        }
        gameState.completePurchasedOroReconstruction(records: records)
        Log.store.info("purchased ORO reconstructed from \(records.count) transactions")
    }
```

`Info.plist`: `<key>SKIncludeConsumableInAppPurchaseHistory</key><true/>`. En iOS 17 los
consumibles finalizados no aparecen y la cuenta da 0 (el plan lo acepta: "si falla, 0"); E3
sube el mínimo a 18.

- [ ] **Step 4: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `PurchasedOroHistoryTests` → PASS.
Después `Tools/v2/oraculo.sh completo` (incluye `store-unit` en 18.6) → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Managers/Store/PurchasedOroHistory.swift FisuEvolution/Managers/Store/StoreManager.swift \
  FisuEvolution/Game/State/GameState+Store.swift FisuEvolution/Info.plist \
  FisuEvolutionTests/PurchasedOroHistoryTests.swift FisuEvolutionTests/StoreManagerTests.swift
git diff --cached --stat
git commit -m "feat(tienda): reconstruir el ORO comprado en la v1 desde el historial de StoreKit"
```

---

### Task 7: El embudo `BoardChange` en EconomyKit — planear y aplicar

**Objetivo:** el tipo `BoardChange`, el planificador (`planAutoMerge`, `planEvolve`,
`planArrival`, `revalidate`, `revealsSomethingNew`) y el aplicador, más los dos mutadores que
faltan en `TowerActions` (`evolveUnit`, `placeUnit`). Puro, sin contadores de compra, sin
productores todavía. Va en paralelo con T5 y T6 (sólo archivos nuevos de EK y `TowerActions`).

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift` (`evolveUnit`, `placeUnit`, y `applyMerge` usa el `land` extraído)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/BoardChangeTests.swift`

**Interfaces:**
- Consumes: `RunState.raiseFrontier(to:)` (T3), `RunState.revealedTier` (T4).
- Produces: `public struct BoardChange: Sendable, Equatable, Identifiable` con `id: UUID`, `kind: Kind`, `origin: Origin`, `resultTypeId: String?`, `floorOrdinal(floorTable:tiers:) -> Int?`.
- Produces: `BoardChange.Kind`: `.merge(floorOrdinal:typeId:sourceSlot:targetSlot:newTypeId:)`, `.evolve(floorOrdinal:slot:typeId:newTypeId:)`, `.arrival(typeId:)`, `.departure(floorOrdinal:slot:typeId:)`.
- Produces: `BoardChange.Origin: String`: `eventStartup`, `eventBlanqueo`, `rewardedInstantMerge`, `rewardedRareUnit`, `career`, `debug` (E4/E5 suman los suyos).
- Produces: `public struct BoardChangeOutcome: Sendable, Equatable { slot: Int?; resultTypeId: String?; tierBefore: Int; promotedToFloor: Int?; unlockedFloorId: String? }`.
- Produces: `BoardChangePlanner.planAutoMerge(state:tower:tiers:floorTable:origin:)`, `planEvolve(…)`, `planArrival(typeId:state:tower:tiers:floorTable:origin:)`, `revalidate(_:state:tower:tiers:floorTable:) -> BoardChange?`, `revealsSomethingNew(_:state:tiers:floorTable:) -> Bool`.
- Produces: `BoardChangeApplier.apply(_:state:tower:tiers:floorTable:) throws -> BoardChangeOutcome`.
- Produces: `TowerActions.evolveUnit(floorOrdinal:slot:newTypeId:state:tower:tiers:floorTable:) throws -> TowerMergeResult` y `TowerActions.placeUnit(typeId:state:tower:tiers:floorTable:) throws -> TowerPlacement`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/BoardChangeTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("BoardChange: planear y aplicar")
struct BoardChangeTests {
    let tiers: TierRepository

    init() throws {
        tiers = try fxTiers()
    }

    private func autoMerge(_ fx: (state: PlayerState, tower: TowerState, floorTable: FloorTable)) -> BoardChange? {
        BoardChangePlanner.planAutoMerge(state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: .debug)
    }

    @Test("el merge automático saltea el par que pide carrera")
    func autoMergeSkipsTheCareerPair() throws {
        let change = try #require(autoMerge(try fxStateAndTower(units: ["a": 2, "b": 2])))
        #expect(change.resultTypeId == "b")
    }

    @Test("con la carrera elegida, el par más alto se funde")
    func autoMergeTakesTheHighestPairWithACareer() throws {
        var fx = try fxStateAndTower(units: ["a": 2, "b": 2])
        fx.state.run.chosenCareerPath = "prog"
        #expect(try #require(autoMerge(fx)).resultTypeId == "c_prog")
    }

    @Test("sin lugar arriba no se planea el ascenso")
    func autoMergeNeedsRoomUpstairs() throws {
        var fx = try fxStateAndTower(units: ["b": 2, "d": 5])
        fx.state.run.chosenCareerPath = "prog"
        #expect(autoMerge(fx) == nil)
    }

    @Test("la evolución elige la mejor unidad que puede crecer sola")
    func evolveSkipsChoiceNodes() throws {
        let fx = try fxStateAndTower(units: ["a": 1, "b": 1])
        let change = try #require(BoardChangePlanner.planEvolve(
            state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: .eventStartup
        ))
        #expect(change.resultTypeId == "b")
    }

    @Test("evolucionar sube la frontera, marca visto y no toca las curvas")
    func applyingAnEvolution() throws {
        var fx = try fxStateAndTower(units: ["a": 1])
        let change = try #require(BoardChangePlanner.planEvolve(
            state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: .eventStartup
        ))
        let outcome = try BoardChangeApplier.apply(change, state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable)
        #expect(outcome.tierBefore == 1)
        #expect(fx.state.run.maxTierReached == 2)
        #expect(fx.state.run.units == ["b": 1])
        #expect(fx.state.run.seenTypes.contains("b"))
        #expect(fx.state.run.hireCounts.isEmpty)
        #expect(fx.tower.unitCounts == fx.state.run.units)
    }

    @Test("una llegada necesita lugar en su piso, y su piso abierto")
    func arrivalNeedsRoom() throws {
        let full = try fxStateAndTower(units: ["a": 5])
        #expect(BoardChangePlanner.planArrival(
            typeId: "b", state: full.state, tower: full.tower, tiers: tiers, floorTable: full.floorTable, origin: .debug
        ) == nil)
        let locked = try fxStateAndTower(units: ["a": 1], unlockedFloors: ["f1"])
        #expect(BoardChangePlanner.planArrival(
            typeId: "d", state: locked.state, tower: locked.tower, tiers: tiers, floorTable: locked.floorTable, origin: .debug
        ) == nil)
    }

    @Test("una llegada no es una contratación")
    func arrivalIsNotAHire() throws {
        var fx = try fxStateAndTower(units: ["a": 1])
        let change = try #require(BoardChangePlanner.planArrival(
            typeId: "a", state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable, origin: .eventBlanqueo
        ))
        _ = try BoardChangeApplier.apply(change, state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable)
        #expect(fx.state.run.units["a"] == 2)
        #expect(fx.state.run.hireCounts.isEmpty)
        #expect(fx.state.meta.stats.totalHiresEver == 0)
    }

    @Test("lo planeado se replanea si el par se movió y se descarta si ya no está")
    func revalidation() throws {
        var fx = try fxStateAndTower(units: ["a": 2])
        let change = try #require(autoMerge(fx))
        guard case .merge(let ordinal, _, let source, _, _) = change.kind else {
            Issue.record("el plan no es un merge")
            return
        }
        let free = try #require(fx.tower.floors[ordinal].firstFreeSlot())
        #expect(TowerActions.move(floorOrdinal: ordinal, fromSlot: source, toSlot: free, tower: &fx.tower))
        let replanned = try #require(BoardChangePlanner.revalidate(
            change, state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable
        ))
        #expect(replanned.id == change.id)
        #expect(replanned != change)

        let pair = fxSlots(of: "a", onFloor: ordinal, in: fx.tower).sorted()
        _ = try TowerActions.applyMerge(
            floorOrdinal: ordinal, sourceSlot: pair[0], targetSlot: pair[1], newTypeId: "b",
            state: &fx.state, tower: &fx.tower, tiers: tiers, floorTable: fx.floorTable
        )
        #expect(BoardChangePlanner.revalidate(
            change, state: fx.state, tower: fx.tower, tiers: tiers, floorTable: fx.floorTable
        ) == nil)
    }

    @Test("un personaje sin revelar o un piso sin abrir son algo nuevo")
    func revealsSomethingNew() throws {
        let fx = try fxStateAndTower(units: ["a": 2])
        let change = try #require(autoMerge(fx))
        #expect(BoardChangePlanner.revealsSomethingNew(change, state: fx.state, tiers: tiers, floorTable: fx.floorTable))
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter BoardChangeTests`
Expected: no compila (`BoardChangePlanner` no existe).

- [ ] **Step 3: `TowerActions`**

Extraer de `applyMerge` (líneas 380-402) la parte común a "el resultado se queda o asciende":

```swift
    /// El resultado se queda en el slot o asciende y abre su piso.
    private static func land(
        _ newType: CharacterType,
        from ordinal: Int,
        slot: Int,
        state: inout PlayerState,
        tower: inout TowerState,
        floorTable: FloorTable
    ) -> TowerMergeResult {
        state.run.units[newType.id, default: 0] += 1
        state.run.markSeen(newType.id)
        state.run.raiseFrontier(to: newType.tier)
        let destinationOrdinal = floorTable.ordinal(forTier: newType.tier)
        guard destinationOrdinal != ordinal else {
            tower.floors[ordinal].slots[slot] = newType.id
            return .stayed(floorOrdinal: ordinal, slot: slot, newTypeId: newType.id)
        }
        let destinationFloor = floorTable[destinationOrdinal]
        let landing = tower.floors[destinationOrdinal].firstFreeSlot()!
        tower.floors[destinationOrdinal].slots[landing] = newType.id
        var unlockedFloorId: String?
        if !state.run.unlockedFloors.contains(destinationFloor.id) {
            state.run.unlockedFloors = floorTable.floors
                .filter { Set(state.run.unlockedFloors).union([destinationFloor.id]).contains($0.id) }
                .map(\.id)
            unlockedFloorId = destinationFloor.id
        }
        return .promoted(toFloorOrdinal: destinationOrdinal, slot: landing, newTypeId: newType.id, unlockedFloorId: unlockedFloorId)
    }
```

`applyMerge` conserva sus guards, consume el par, cuenta `totalMergesEver` y termina en
`return land(newType, from: floorOrdinal, slot: targetSlot, …)` (su suite actual tiene que
seguir verde sin tocarla). Y:

```swift
    /// Una unidad sube sola un tier ("Startup comprada"): el mismo ascenso que un
    /// merge, sin consumir un par y sin contar como fusión.
    public static func evolveUnit(
        floorOrdinal: Int,
        slot: Int,
        newTypeId: String,
        state: inout PlayerState,
        tower: inout TowerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) throws -> TowerMergeResult {
        guard let typeId = tower.typeId(floorOrdinal: floorOrdinal, slot: slot),
              let newType = tiers.type(id: newTypeId)
        else { throw TowerError.invalidSlot }
        let destination = floorTable.ordinal(forTier: newType.tier)
        if destination != floorOrdinal, tower.floors[destination].firstFreeSlot() == nil {
            throw TowerError.destinationFloorFull(floorId: floorTable[destination].id)
        }
        tower.floors[floorOrdinal].slots[slot] = nil
        state.run.units[typeId, default: 0] -= 1
        if state.run.units[typeId] == 0 { state.run.units[typeId] = nil }
        return land(newType, from: floorOrdinal, slot: slot, state: &state, tower: &tower, floorTable: floorTable)
    }

    /// Una unidad que llega sin comprarse (Blanqueo, video, paquete, visitante):
    /// no toca las curvas de contratación ni sus estadísticas.
    public static func placeUnit(
        typeId: String,
        state: inout PlayerState,
        tower: inout TowerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) throws -> TowerPlacement {
        guard let type = tiers.type(id: typeId), !type.isChoiceNode else { throw TowerError.invalidSlot }
        let ordinal = floorTable.ordinal(forTier: type.tier)
        guard state.run.unlockedFloors.contains(floorTable[ordinal].id) else { throw TowerError.floorLocked }
        guard let slot = tower.floors[ordinal].firstFreeSlot() else { throw TowerError.floorFull }
        tower.floors[ordinal].slots[slot] = typeId
        state.run.units[typeId, default: 0] += 1
        state.run.markSeen(typeId)
        state.run.raiseFrontier(to: type.tier)
        return TowerPlacement(floorOrdinal: ordinal, slot: slot, typeId: typeId)
    }
```

- [ ] **Step 4: `BoardChange.swift`**

```swift
import Foundation

/// Un cambio del tablero que no hizo el jugador. Se planea en el acto y se
/// aplica recién en su turno, a la vista: así no hay evoluciones sin ver.
public struct BoardChange: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        case merge(floorOrdinal: Int, typeId: String, sourceSlot: Int, targetSlot: Int, newTypeId: String)
        case evolve(floorOrdinal: Int, slot: Int, typeId: String, newTypeId: String)
        case arrival(typeId: String)
        case departure(floorOrdinal: Int, slot: Int, typeId: String)
    }

    public enum Origin: String, Sendable, Equatable {
        case eventStartup
        case eventBlanqueo
        case rewardedInstantMerge
        case rewardedRareUnit
        case career
        case debug
    }

    public let id: UUID
    public let kind: Kind
    public let origin: Origin

    public init(id: UUID = UUID(), kind: Kind, origin: Origin) {
        self.id = id
        self.kind = kind
        self.origin = origin
    }

    public var resultTypeId: String? {
        switch kind {
        case .merge(_, _, _, _, let newTypeId), .evolve(_, _, _, let newTypeId): newTypeId
        case .arrival(let typeId): typeId
        case .departure: nil
        }
    }

    /// El piso al que la escena tiene que ir antes de reproducirlo.
    public func floorOrdinal(floorTable: FloorTable, tiers: TierRepository) -> Int? {
        switch kind {
        case .merge(let ordinal, _, _, _, _), .evolve(let ordinal, _, _, _), .departure(let ordinal, _, _):
            ordinal
        case .arrival(let typeId):
            tiers.type(id: typeId).map { floorTable.ordinal(forTier: $0.tier) }
        }
    }

    func replanned(_ kind: Kind) -> BoardChange {
        BoardChange(id: id, kind: kind, origin: origin)
    }
}

public struct BoardChangeOutcome: Sendable, Equatable {
    /// Dónde quedó el resultado en el piso del cambio; `nil` si ascendió o salió.
    public let slot: Int?
    public let resultTypeId: String?
    public let tierBefore: Int
    public let promotedToFloor: Int?
    public let unlockedFloorId: String?
}

public enum BoardChangePlanner {
    /// El par más alto de la torre cuyo resultado tiene lugar. Nunca toca el par
    /// que pide elegir carrera.
    public static func planAutoMerge(
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        origin: BoardChange.Origin
    ) -> BoardChange? {
        let pairs = tower.floors.indices.flatMap { ordinal in
            Dictionary(grouping: tower.placements(onFloor: ordinal), by: \.typeId)
                .compactMap { typeId, placements -> (ordinal: Int, typeId: String, slots: [Int], tier: Int)? in
                    guard placements.count >= 2, let type = tiers.type(id: typeId) else { return nil }
                    return (ordinal, typeId, placements.map(\.slot).sorted(), type.tier)
                }
        }
        for pair in pairs.sorted(by: { $0.tier > $1.tier }) {
            guard case .merged(let newTypeId) = MergeRules.evaluate(
                sourceTypeId: pair.typeId, targetTypeId: pair.typeId,
                chosenCareerPath: state.run.chosenCareerPath, tiers: tiers
            ), fits(newTypeId, from: pair.ordinal, tower: tower, tiers: tiers, floorTable: floorTable)
            else { continue }
            return BoardChange(
                kind: .merge(floorOrdinal: pair.ordinal, typeId: pair.typeId,
                             sourceSlot: pair.slots[0], targetSlot: pair.slots[1], newTypeId: newTypeId),
                origin: origin
            )
        }
        return nil
    }

    /// La mejor unidad que puede subir sola un tier. Un nodo de carrera no se
    /// cruza solo: eso lo decide el jugador.
    public static func planEvolve(
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        origin: BoardChange.Origin
    ) -> BoardChange? {
        let units = tower.floors.indices
            .flatMap { tower.placements(onFloor: $0) }
            .compactMap { placement in tiers.type(id: placement.typeId).map { (placement, $0) } }
            .sorted { $0.1.tier > $1.1.tier }
        for (placement, type) in units {
            guard let nextId = type.mergesInto, let next = tiers.type(id: nextId), !next.isChoiceNode,
                  fits(nextId, from: placement.floorOrdinal, tower: tower, tiers: tiers, floorTable: floorTable)
            else { continue }
            return BoardChange(
                kind: .evolve(floorOrdinal: placement.floorOrdinal, slot: placement.slot, typeId: type.id, newTypeId: nextId),
                origin: origin
            )
        }
        return nil
    }

    public static func planArrival(
        typeId: String,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable,
        origin: BoardChange.Origin
    ) -> BoardChange? {
        guard let type = tiers.type(id: typeId), !type.isChoiceNode else { return nil }
        let ordinal = floorTable.ordinal(forTier: type.tier)
        guard state.run.unlockedFloors.contains(floorTable[ordinal].id),
              tower.floors[ordinal].firstFreeSlot() != nil
        else { return nil }
        return BoardChange(kind: .arrival(typeId: typeId), origin: origin)
    }

    /// Lo planeado contra el tablero de AHORA: sigue valiendo, se replanea la
    /// misma intención (mismo id y origen), o `nil` si ya no hay cómo.
    public static func revalidate(
        _ change: BoardChange,
        state: PlayerState,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) -> BoardChange? {
        switch change.kind {
        case let .merge(ordinal, typeId, source, target, newTypeId):
            guard fits(newTypeId, from: ordinal, tower: tower, tiers: tiers, floorTable: floorTable) else { return nil }
            if source != target,
               tower.typeId(floorOrdinal: ordinal, slot: source) == typeId,
               tower.typeId(floorOrdinal: ordinal, slot: target) == typeId {
                return change
            }
            let slots = tower.placements(onFloor: ordinal).filter { $0.typeId == typeId }.map(\.slot).sorted()
            guard slots.count >= 2 else { return nil }
            return change.replanned(.merge(floorOrdinal: ordinal, typeId: typeId,
                                           sourceSlot: slots[0], targetSlot: slots[1], newTypeId: newTypeId))
        case let .evolve(ordinal, slot, typeId, newTypeId):
            guard fits(newTypeId, from: ordinal, tower: tower, tiers: tiers, floorTable: floorTable) else { return nil }
            if tower.typeId(floorOrdinal: ordinal, slot: slot) == typeId { return change }
            return tower.placements(onFloor: ordinal).first { $0.typeId == typeId }
                .map { change.replanned(.evolve(floorOrdinal: ordinal, slot: $0.slot, typeId: typeId, newTypeId: newTypeId)) }
        case let .arrival(typeId):
            return planArrival(typeId: typeId, state: state, tower: tower, tiers: tiers,
                               floorTable: floorTable, origin: change.origin).map { _ in change }
        case let .departure(ordinal, slot, typeId):
            if tower.typeId(floorOrdinal: ordinal, slot: slot) == typeId { return change }
            return tower.placements(onFloor: ordinal).first { $0.typeId == typeId }
                .map { change.replanned(.departure(floorOrdinal: ordinal, slot: $0.slot, typeId: typeId)) }
        }
    }

    /// Lo único que apaga la UI: un personaje que no se reveló o un piso que no
    /// estaba abierto (la misma regla que el merge del jugador).
    public static func revealsSomethingNew(
        _ change: BoardChange,
        state: PlayerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) -> Bool {
        guard let resultTypeId = change.resultTypeId, let result = tiers.type(id: resultTypeId) else { return false }
        let destination = floorTable[floorTable.ordinal(forTier: result.tier)]
        return result.tier > state.run.revealedTier || !state.run.unlockedFloors.contains(destination.id)
    }

    private static func fits(
        _ newTypeId: String,
        from ordinal: Int,
        tower: TowerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) -> Bool {
        guard let newType = tiers.type(id: newTypeId) else { return false }
        let destination = floorTable.ordinal(forTier: newType.tier)
        return destination == ordinal || tower.floors[destination].firstFreeSlot() != nil
    }
}

public enum BoardChangeApplier {
    public static func apply(
        _ change: BoardChange,
        state: inout PlayerState,
        tower: inout TowerState,
        tiers: TierRepository,
        floorTable: FloorTable
    ) throws -> BoardChangeOutcome {
        let tierBefore = state.run.maxTierReached
        switch change.kind {
        case let .merge(ordinal, _, source, target, newTypeId):
            let result = try TowerActions.applyMerge(
                floorOrdinal: ordinal, sourceSlot: source, targetSlot: target, newTypeId: newTypeId,
                state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
            )
            return outcome(result, tierBefore: tierBefore)
        case let .evolve(ordinal, slot, _, newTypeId):
            let result = try TowerActions.evolveUnit(
                floorOrdinal: ordinal, slot: slot, newTypeId: newTypeId,
                state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
            )
            return outcome(result, tierBefore: tierBefore)
        case let .arrival(typeId):
            let placement = try TowerActions.placeUnit(
                typeId: typeId, state: &state, tower: &tower, tiers: tiers, floorTable: floorTable
            )
            return BoardChangeOutcome(slot: placement.slot, resultTypeId: typeId, tierBefore: tierBefore,
                                      promotedToFloor: nil, unlockedFloorId: nil)
        case let .departure(ordinal, slot, _):
            guard TowerActions.removeUnit(floorOrdinal: ordinal, slot: slot, state: &state, tower: &tower) else {
                throw TowerError.invalidSlot
            }
            return BoardChangeOutcome(slot: nil, resultTypeId: nil, tierBefore: tierBefore,
                                      promotedToFloor: nil, unlockedFloorId: nil)
        }
    }

    private static func outcome(_ result: TowerMergeResult, tierBefore: Int) -> BoardChangeOutcome {
        switch result {
        case let .stayed(_, slot, newTypeId):
            BoardChangeOutcome(slot: slot, resultTypeId: newTypeId, tierBefore: tierBefore,
                               promotedToFloor: nil, unlockedFloorId: nil)
        case let .promoted(toFloor, _, newTypeId, unlockedFloorId):
            BoardChangeOutcome(slot: nil, resultTypeId: newTypeId, tierBefore: tierBefore,
                               promotedToFloor: toFloor, unlockedFloorId: unlockedFloorId)
        }
    }
}
```

⚠️ `planEvolve` cae a la siguiente unidad cuando la mejor no puede crecer (hoy "Startup
comprada" devuelve `nil` y el evento no pasa nada); es lo que hace al evento aplicable casi
siempre. Anotado en dudas.

- [ ] **Step 5: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (nombra `BoardChangeTests` y las
suites de `applyMerge`, que no se tocaron). Después `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/BoardChange.swift Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/BoardChangeTests.swift
git diff --cached --stat
git commit -m "feat(tablero): el embudo BoardChange en EconomyKit — planear y aplicar"
```

---

### Task 8: El ciclo de vida — sellar sólo al irse, tiempo de background, evento vencido y latido

**Objetivo:** `RootView` pasa la fase vieja y la nueva; se sella `lastSeenTimestamp` sólo en
`.background` o en `.inactive` viniendo de `.active` (re-sellar en `background → inactive` era
EL bug); el guardado al irse corre dentro de `beginBackgroundTask`; la escena no cobra en vivo
mientras no está activa; el watchdog recibe el delta con tope; un evento vencido se corre
+60 s al volver; y un latido cada 15 s en foreground sella y guarda, así un kill en foreground
no paga de más.

**Files:**
- Create: `FisuEvolution/App/BackgroundTasks.swift`
- Create: `FisuEvolution/Game/State/GameState+Lifecycle.swift` (se mudan `handleScenePhase` y `applyOfflineProgressIfNeeded` desde `GameState.swift:895-938`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (estado nuevo; `tick` con guard y clamp; `flushHUD` con latido; `saveTask` deja de ser `private`; `persistNow(includingCloud:)`; `attachBackgroundTasks`)
- Modify: `FisuEvolution/App/RootView.swift:42-44`
- Modify: `FisuEvolution/App/FisuEvolutionApp.swift` (adjunta `UIKitBackgroundTasks()`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (`postponeOverdueEvent(now:)`)
- Modify: `FisuEvolution/Managers/ContentConfigs.swift` (`EventsConfig.resumeGraceSeconds`) y `FisuEvolution/Resources/Config/events.json` (`"resumeGraceSeconds": 60`)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`debugSimulateOffline` sigue llamando a `applyOfflineProgressIfNeeded()`)
- Create: `FisuEvolutionTests/LifecycleTests.swift`

**Interfaces:**
- Produces: `@MainActor protocol BackgroundTaskRunning: AnyObject { func begin(_ name: String) -> BackgroundTaskToken; func end(_ token: BackgroundTaskToken) }`, `struct BackgroundTaskToken: Hashable, Sendable`, `final class UIKitBackgroundTasks`.
- Produces: `GameState.handleScenePhase(from:to:now:)`, `seal(now:)`, `beatIfDue(now:)`, `isSceneActive: Bool`, `sealTask: Task<Void, Never>?`, `static let heartbeatSeconds: TimeInterval = 15`, `attachBackgroundTasks(_:)`, `persistNow(includingCloud: Bool = true)`.
- Produces: `GameState.postponeOverdueEvent(now:)`, `EventsConfig.resumeGraceSeconds: Double`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/LifecycleTests.swift`:

```swift
import EconomyKit
import Foundation
import SwiftUI
import Testing
@testable import FisuEvolution

@MainActor
private final class RecordingBackgroundTasks: BackgroundTaskRunning {
    private(set) var begun: [BackgroundTaskToken] = []
    private(set) var ended: [BackgroundTaskToken] = []

    func begin(_ name: String) -> BackgroundTaskToken {
        let token = BackgroundTaskToken()
        begun.append(token)
        return token
    }

    func end(_ token: BackgroundTaskToken) {
        ended.append(token)
    }
}

@Suite("Ciclo de vida: la secuencia completa de fases")
@MainActor
struct LifecycleTests {
    private func producingGame() async throws -> GameState {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        return gameState
    }

    @Test("volver del background pasando por inactive no re-sella: la hora afuera se paga")
    func returningThroughInactiveKeepsTheSeal() async throws {
        let gameState = try await producingGame()
        let t0 = Date().timeIntervalSince1970
        gameState.handleScenePhase(from: .active, to: .inactive, now: t0)
        gameState.handleScenePhase(from: .inactive, to: .background, now: t0 + 1)
        gameState.handleScenePhase(from: .background, to: .inactive, now: t0 + 3600)
        gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + 3601)
        #expect((gameState.offlineReward?.amount ?? 0) > 0)
    }

    @Test("bajar el centro de notificaciones sella y acredita en silencio")
    func notificationCenterPull() async throws {
        let gameState = try await producingGame()
        let t0 = Date().timeIntervalSince1970
        let before = try #require(gameState.player?.run.coins)
        gameState.handleScenePhase(from: .active, to: .inactive, now: t0)
        gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + 10)
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.offlineReward == nil)
    }

    @Test("con la escena inactiva el tick no cobra: lo paga el offline")
    func tickPaysNothingWhileInactive() async throws {
        let gameState = try await producingGame()
        gameState.handleScenePhase(from: .active, to: .inactive)
        let before = try #require(gameState.player?.run.coins)
        gameState.tick(delta: 1)
        #expect(gameState.player?.run.coins == before)
    }

    @Test("sellar pide tiempo de background y lo devuelve al terminar de guardar")
    func sealRunsInsideABackgroundTask() async throws {
        let gameState = try await producingGame()
        let tasks = RecordingBackgroundTasks()
        gameState.attachBackgroundTasks(tasks)
        gameState.handleScenePhase(from: .inactive, to: .background)
        await gameState.sealTask?.value
        #expect(tasks.begun.count == 1)
        #expect(tasks.ended == tasks.begun)
    }

    @Test("un evento vencido no dispara al volver: se corre la gracia del dato")
    func overdueEventIsPostponed() async throws {
        let gameState = await makeGameState()
        let t0 = Date().timeIntervalSince1970
        gameState.nextEventAt = t0 + 10
        gameState.handleScenePhase(from: .active, to: .background, now: t0)
        gameState.handleScenePhase(from: .background, to: .inactive, now: t0 + 3600)
        gameState.handleScenePhase(from: .inactive, to: .active, now: t0 + 3601)
        let grace = try #require(gameState.content?.events.resumeGraceSeconds)
        #expect(gameState.nextEventAt == t0 + 3601 + grace)
    }

    @Test("el watchdog recibe el delta con tope: el salto del background no vence nada")
    func watchdogGetsAClampedDelta() async {
        let gameState = await makeGameState()
        gameState.towerNotice = GameState.TowerNotice(kind: .floorFull)
        gameState.syncCelebrations()
        #expect(gameState.showing == .towerNotice)
        gameState.tick(delta: 3600)
        #expect(gameState.showing == .towerNotice)
    }

    @Test("el latido sella cada 15 s con la escena activa, y no antes")
    func heartbeat() async {
        let gameState = await makeGameState()
        let t0 = Date().timeIntervalSince1970
        gameState.beatIfDue(now: t0)
        #expect(gameState.player?.meta.lastSeenTimestamp == t0)
        gameState.beatIfDue(now: t0 + GameState.heartbeatSeconds - 1)
        #expect(gameState.player?.meta.lastSeenTimestamp == t0)
        gameState.beatIfDue(now: t0 + GameState.heartbeatSeconds)
        #expect(gameState.player?.meta.lastSeenTimestamp == t0 + GameState.heartbeatSeconds)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/LifecycleTests`.
Expected: no compila (`handleScenePhase(from:to:now:)`, `BackgroundTaskRunning`). Con la firma
nueva sobre la lógica vieja, `returningThroughInactiveKeepsTheSeal` falla (la rama `.inactive`
re-sella) y `watchdogGetsAClampedDelta` también.

- [ ] **Step 3: `BackgroundTasks.swift`**

```swift
import UIKit

struct BackgroundTaskToken: Hashable, Sendable {
    let id = UUID()
}

/// `beginBackgroundTask` detrás de un protocolo: guardar al irse pide unos
/// segundos de vida, y los tests verifican que se pidan y se devuelvan.
@MainActor
protocol BackgroundTaskRunning: AnyObject {
    func begin(_ name: String) -> BackgroundTaskToken
    func end(_ token: BackgroundTaskToken)
}

@MainActor
final class UIKitBackgroundTasks: BackgroundTaskRunning {
    private var identifiers: [BackgroundTaskToken: UIBackgroundTaskIdentifier] = [:]

    func begin(_ name: String) -> BackgroundTaskToken {
        let token = BackgroundTaskToken()
        // El handler de expiración lo llama UIKit en main (documentado): regla 3.
        identifiers[token] = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated { self?.end(token) }
        }
        return token
    }

    func end(_ token: BackgroundTaskToken) {
        guard let identifier = identifiers.removeValue(forKey: token) else { return }
        UIApplication.shared.endBackgroundTask(identifier)
    }
}
```

- [ ] **Step 4: `GameState`**

En `GameState.swift`, junto a los otros servicios:

```swift
    @ObservationIgnored var backgroundTasks: (any BackgroundTaskRunning)?
    /// Falso desde que la app deja `.active` hasta que vuelve: en ese tramo el
    /// tick no cobra (lo paga el offline) y no se sella dos veces.
    @ObservationIgnored var isSceneActive = true
    @ObservationIgnored var sealTask: Task<Void, Never>?
    @ObservationIgnored var lastHeartbeatAt: TimeInterval = 0
    static let heartbeatSeconds: TimeInterval = 15

    func attachBackgroundTasks(_ runner: any BackgroundTaskRunning) {
        backgroundTasks = runner
    }
```

`saveTask` pasa de `private` a interno (lo usa `+Lifecycle`). `tick(delta:)`:

```swift
    func tick(delta: TimeInterval) {
        guard isSceneActive, let content, var player else { return }
        // … IncomeTicker sin cambios …
        self.player = player
        advanceCelebrations(delta: min(delta, IncomeTicker.deltaClampThreshold))
    }
```

`flushHUD()` llama a `beatIfDue(now: now)` después de `fireEventIfDue(now:)`. `persistNow`:

```swift
    func persistNow(includingCloud: Bool = true) async {
        guard !isRecoveryPending, let repository, let player else { return }
        await repository.save(player)
        if includingCloud, let cloudSync {
            await cloudSync.push(player)
        }
    }
```

`GameState+Lifecycle.swift` (con `applyOfflineProgressIfNeeded(now:)` mudado tal como quedó en T1):

```swift
import EconomyKit
import Foundation
import SwiftUI

extension GameState {
    func handleScenePhase(
        from old: ScenePhase,
        to new: ScenePhase,
        now: TimeInterval = Date().timeIntervalSince1970
    ) {
        switch (old, new) {
        case (_, .background), (.active, .inactive):
            isSceneActive = false
            seal(now: now)
        case (_, .active):
            isSceneActive = true
            guard phase == .ready else { return }
            // El tiempo en background NO es tiempo de juego: reiniciar la gracia
            // evita que volver después de horas te reciba con un interstitial.
            ads?.sessionResumed()
            applyOfflineProgressIfNeeded(now: now)
            postponeOverdueEvent(now: now)
            claimDailyIfAvailable()
            refreshProjections()
        default:
            // `.background → .inactive` NO sella: re-sellar acá hacía que `.active`
            // midiera ~0 s de ausencia y el pasivo "se congelaba".
            break
        }
    }

    func seal(now: TimeInterval) {
        guard phase == .ready, var player else { return }
        player.meta.lastSeenTimestamp = now
        self.player = player
        lastHeartbeatAt = now
        saveTask?.cancel()
        let token = backgroundTasks?.begin("fisu.save")
        sealTask = Task {
            await persistNow()
            if let token { backgroundTasks?.end(token) }
        }
    }

    /// Con la escena activa, sella y guarda cada `heartbeatSeconds`: un kill en
    /// foreground paga a lo sumo eso de menos, nunca de más.
    func beatIfDue(now: TimeInterval) {
        guard phase == .ready, isSceneActive, now - lastHeartbeatAt >= Self.heartbeatSeconds,
              var player
        else { return }
        lastHeartbeatAt = now
        player.meta.lastSeenTimestamp = now
        self.player = player
        Task { await persistNow(includingCloud: false) }
    }

    // applyOfflineProgressIfNeeded(now:) — mudado desde GameState.swift.
}
```

`GameState+Bonus.swift`, en la sección de eventos:

```swift
    func postponeOverdueEvent(now: TimeInterval) {
        guard let content, nextEventAt <= now else { return }
        nextEventAt = now + content.events.resumeGraceSeconds
    }
```

`EventsConfig` suma `let resumeGraceSeconds: Double` **declarado justo después de
`intervalJitterSeconds`** (T12 usa el init memberwise en ese orden) y `events.json`
`"resumeGraceSeconds": 60,` en el mismo lugar. `RootView`:

```swift
        .onChange(of: scenePhase) { old, new in
            gameState.handleScenePhase(from: old, to: new)
        }
```

`FisuEvolutionApp`, con los otros `attach…` previos al bootstrap:
`gameState.attachBackgroundTasks(UIKitBackgroundTasks())`.

- [ ] **Step 5: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `LifecycleTests` y `OfflinePopupTests` → PASS.
Después `Tools/v2/oraculo.sh rapido` → `VERDE`. Escenario a mano en el simulador propio (PLAN
§8): partida con pasivo, Home, `xcrun simctl status_bar`/esperar 2 min, volver → popup con
ganancias y ×2.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/App/BackgroundTasks.swift FisuEvolution/Game/State/GameState+Lifecycle.swift \
  FisuEvolution/Game/State/GameState.swift FisuEvolution/App/RootView.swift FisuEvolution/App/FisuEvolutionApp.swift \
  FisuEvolution/Game/State/GameState+Bonus.swift FisuEvolution/Game/State/GameState+Debug.swift \
  FisuEvolution/Managers/ContentConfigs.swift FisuEvolution/Resources/Config/events.json \
  FisuEvolutionTests/LifecycleTests.swift
git diff --cached --stat
git commit -m "fix(offline): sellar la hora sólo al irse, con tiempo de background, gracia de eventos y latido"
```

---

### Task 9: El turno de los cambios del tablero — confirmar una sola vez

**Objetivo:** la máquina de estados de `GameState`: la cola `pendingBoardChanges`, el
predicado `boardIsVisibleForChanges`, `beginNextBoardChange` (revalida), `confirmBoardChange`
(exactamente una vez), `settleInFlightBoardChange` (skip/watchdog), el asiento silencioso de
todo lo pendiente al sellar, y la contabilidad de `revealedTier`. **Sin productores y sin
enganche a la cola todavía**: nada del juego cambia en esta tarea.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState.swift` (`pendingBoardChanges`, `inFlightBoardChange`)
- Create: `FisuEvolution/Game/State/GameState+BoardChanges.swift`
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift` (`setBoardCelebrationShowsSomethingNew(_:)`)
- Modify: `FisuEvolution/Game/State/GameState+Lifecycle.swift` (`seal` asienta lo pendiente primero)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`debugResetSave` vacía la cola y el en vuelo)
- Create: `FisuEvolutionTests/BoardChangeWiringTests.swift`

**Interfaces:**
- Consumes: `BoardChangePlanner`, `BoardChangeApplier` (T7); `isSceneActive` (T8).
- Produces: `GameState.boardIsVisibleForChanges: Bool`, `enqueueBoardChange(_:)`, `beginNextBoardChange() -> BoardChange?`, `confirmBoardChange(id:) -> DropResolution?` (`@discardableResult`), `settleInFlightBoardChange()`, `settleAllPendingBoardChanges()`, `markRevealed(tier:)`, `typePendingReveal: CharacterType?`, `discardBoardChange(_:)`, `floorOrdinal(of:) -> Int?`.
- Produces: `GameState.setBoardCelebrationShowsSomethingNew(_:)` en `+Celebrations`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/BoardChangeWiringTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Cambios del tablero: el turno")
@MainActor
struct BoardChangeWiringTests {
    /// Partida nueva con un par del tipo base planeado como lo planearía un video.
    private func gameWithPlannedMerge() async throws -> GameState {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        let content = try #require(gameState.content)
        let change = try #require(BoardChangePlanner.planAutoMerge(
            state: try #require(gameState.player), tower: try #require(gameState.tower),
            tiers: content.tiers, floorTable: content.floorTable, origin: .debug
        ))
        gameState.enqueueBoardChange(change)
        return gameState
    }

    @Test("con una hoja abierta el cambio espera")
    func waitsForTheBoard() async throws {
        let gameState = try await gameWithPlannedMerge()
        gameState.uiCoversBoard = true
        #expect(gameState.beginNextBoardChange() == nil)
        gameState.uiCoversBoard = false
        #expect(gameState.beginNextBoardChange() != nil)
    }

    @Test("confirmar aplica exactamente una vez")
    func confirmsExactlyOnce() async throws {
        let gameState = try await gameWithPlannedMerge()
        let units = try #require(gameState.player?.run.totalUnits)
        let change = try #require(gameState.beginNextBoardChange())
        #expect(gameState.confirmBoardChange(id: change.id) != nil)
        #expect(gameState.confirmBoardChange(id: change.id) == nil)
        gameState.settleInFlightBoardChange()
        #expect(gameState.player?.run.totalUnits == units - 1)
    }

    @Test("el skip y el watchdog asientan en silencio lo que estaba en vuelo")
    func settlingConfirmsTheInFlightChange() async throws {
        let gameState = try await gameWithPlannedMerge()
        let units = try #require(gameState.player?.run.totalUnits)
        _ = try #require(gameState.beginNextBoardChange())
        gameState.settleInFlightBoardChange()
        #expect(gameState.inFlightBoardChange == nil)
        #expect(gameState.player?.run.totalUnits == units - 1)
    }

    @Test("al irse, todo lo pendiente queda aplicado antes de guardar")
    func sealSettlesEverything() async throws {
        let gameState = try await gameWithPlannedMerge()
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.handleScenePhase(from: .active, to: .background)
        await gameState.sealTask?.value
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.player?.run.totalUnits == units - 1)
    }

    @Test("revelar sólo sube, y la red nombra al más alto sin revelar")
    func revealBookkeeping() async throws {
        let gameState = try await gameWithPlannedMerge()
        let change = try #require(gameState.beginNextBoardChange())
        gameState.confirmBoardChange(id: change.id)
        #expect(gameState.typePendingReveal?.tier == 2)
        gameState.markRevealed(tier: 2)
        gameState.markRevealed(tier: 1)
        #expect(gameState.player?.run.revealedTier == 2)
        #expect(gameState.typePendingReveal == nil)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/BoardChangeWiringTests`.
Expected: no compila (`enqueueBoardChange`, `beginNextBoardChange`…).

- [ ] **Step 3: La implementación**

`GameState.swift`, en "Authoritative state":

```swift
    /// Lo que cambió el tablero sin el jugador, esperando su turno a la vista.
    @ObservationIgnored var pendingBoardChanges: [BoardChange] = []
    /// El que la escena está reproduciendo. Confirmarlo lo consume.
    @ObservationIgnored var inFlightBoardChange: BoardChange?
```

`GameState+Celebrations.swift`:

```swift
    /// La bandera de "algo nuevo" del cambio que arranca su turno. A diferencia de
    /// `celebrateBoard`, el turno ya es suyo: se publica en el acto.
    func setBoardCelebrationShowsSomethingNew(_ value: Bool) {
        boardCelebrationShowsSomethingNew = value
        publishCelebration()
    }
```

`GameState+BoardChanges.swift`:

```swift
import EconomyKit
import Foundation

/// El embudo de los cambios del tablero que no hizo el jugador: se planean en
/// el acto y se confirman en su turno, a la vista (PLAN-v2 E1).
extension GameState {
    var boardIsVisibleForChanges: Bool {
        phase == .ready && isSceneActive && !uiCoversBoard && !tutorialPhaseActive
            && careerPrompt == nil && characterSheet == nil && specialInfo == nil
    }

    func enqueueBoardChange(_ change: BoardChange) {
        pendingBoardChanges.append(change)
        Log.economy.info("board change planned: \(change.origin.rawValue)")
    }

    func floorOrdinal(of change: BoardChange) -> Int? {
        guard let content else { return nil }
        return change.floorOrdinal(floorTable: content.floorTable, tiers: content.tiers)
    }

    /// El próximo cambio, revalidado contra el tablero de ahora. Lo pide la escena
    /// al empezar su turno.
    func beginNextBoardChange() -> BoardChange? {
        guard inFlightBoardChange == nil, boardIsVisibleForChanges else { return nil }
        while !pendingBoardChanges.isEmpty {
            let planned = pendingBoardChanges.removeFirst()
            guard let content, let player, let tower else { return nil }
            guard let valid = BoardChangePlanner.revalidate(
                planned, state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable
            ) else {
                discardBoardChange(planned)
                continue
            }
            inFlightBoardChange = valid
            setBoardCelebrationShowsSomethingNew(BoardChangePlanner.revealsSomethingNew(
                valid, state: player, tiers: content.tiers, floorTable: content.floorTable
            ))
            return valid
        }
        return nil
    }

    /// Aplica el cambio en vuelo. La segunda llamada por el mismo id —completion
    /// tardío, skip, watchdog— no encuentra nada y devuelve `nil`.
    @discardableResult
    func confirmBoardChange(id: UUID) -> DropResolution? {
        guard let change = inFlightBoardChange, change.id == id else { return nil }
        inFlightBoardChange = nil
        return applyBoardChange(change)
    }

    func settleInFlightBoardChange() {
        guard let change = inFlightBoardChange else { return }
        confirmBoardChange(id: change.id)
    }

    /// Al irse: lo pendiente se aplica en silencio y queda en el save; la red de
    /// seguridad revela lo nuevo al volver.
    func settleAllPendingBoardChanges() {
        settleInFlightBoardChange()
        while !pendingBoardChanges.isEmpty {
            let planned = pendingBoardChanges.removeFirst()
            guard let content, let player, let tower,
                  let valid = BoardChangePlanner.revalidate(
                      planned, state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable
                  )
            else {
                discardBoardChange(planned)
                continue
            }
            applyBoardChange(valid)
        }
    }

    /// La escena lo llama al ARRANCAR un reveal: un reveal salteado ya se vio.
    func markRevealed(tier: Int) {
        guard var player, tier > player.run.revealedTier else { return }
        player.run.revealedTier = tier
        self.player = player
        scheduleSave()
    }

    /// El personaje más alto de la run que todavía no se reveló.
    var typePendingReveal: CharacterType? {
        guard let content, let player, player.run.maxTierReached > player.run.revealedTier else { return nil }
        let candidates = content.tiers.concreteTypes.filter { $0.tier == player.run.maxTierReached }
        return candidates.first { player.run.seenTypes.contains($0.id) } ?? candidates.first
    }

    func discardBoardChange(_ change: BoardChange) {
        Log.economy.info("board change dropped: \(change.origin.rawValue)")
    }

    @discardableResult
    private func applyBoardChange(_ change: BoardChange) -> DropResolution? {
        guard let content, var player, var tower else { return nil }
        do {
            let outcome = try BoardChangeApplier.apply(
                change, state: &player, tower: &tower, tiers: content.tiers, floorTable: content.floorTable
            )
            self.player = player
            self.tower = tower
            let result = outcome.resultTypeId.flatMap { content.tiers.type(id: $0) }
            let evolvedTo = player.run.maxTierReached > outcome.tierBefore ? result : nil
            if let ordinal = TowerActions.newlyHireableFloors(
                maxTierBefore: outcome.tierBefore, maxTierAfter: player.run.maxTierReached,
                floorTable: content.floorTable, config: content.economy
            ).first {
                towerNotice = TowerNotice(kind: .hireUnlocked(floorID: content.floorTable[ordinal].id))
            }
            updateMaxFloorStat()
            bumpBoard()
            scheduleSave()
            return .merged(
                targetCell: outcome.slot ?? -1,
                evolvedTo: evolvedTo,
                promotedType: outcome.promotedToFloor == nil ? nil : result,
                promotedToFloor: outcome.promotedToFloor,
                unlockedFloorId: outcome.unlockedFloorId
            )
        } catch {
            Log.economy.info("board change rejected on confirm: \(error)")
            discardBoardChange(change)
            return nil
        }
    }
}
```

`seal(now:)` (en `+Lifecycle`) llama a `settleAllPendingBoardChanges()` **antes** de sellar.
`debugResetSave` suma `pendingBoardChanges.removeAll()` e `inFlightBoardChange = nil` junto a
los demás payloads.

- [ ] **Step 4: Verde y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; Receta R con `BoardChangeWiringTests` y
`LifecycleTests` → PASS. Después `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState.swift FisuEvolution/Game/State/GameState+BoardChanges.swift \
  FisuEvolution/Game/State/GameState+Celebrations.swift FisuEvolution/Game/State/GameState+Lifecycle.swift \
  FisuEvolution/Game/State/GameState+Debug.swift FisuEvolutionTests/BoardChangeWiringTests.swift
git diff --cached --stat
git commit -m "feat(tablero): el turno de los cambios del tablero — confirmar una sola vez"
```

---

### Task 10: La escena reproduce los cambios como merges y revela lo que faltó

**Objetivo:** conectar el embudo a la cola y a la escena. `syncCelebrations` pide el turno del
tablero cuando hay cambios pendientes o un tier sin revelar **y** el tablero está a la vista;
`BoardScene` navega al piso, destaca, funde con `runAssistedMerge` y corre la misma cadena que
el merge del jugador (`presentResolution`, extraída de `resolveDrop`); el reveal marca
`revealedTier`; el skip y el watchdog asientan el cambio en vuelo; el timeout del turno pasa
de 8 a 14 s. Fixture `--uitest-board-change` y marcador `board.revealed` para el test de UI.
Puede ir en paralelo con T11.

**Files:**
- Modify: `FisuEvolution/Scenes/BoardScene.swift` (`startBoardCelebrationIfItsTurn` 364-371, `runBoardCelebration` 376-415, `abortBoardCelebration` 419-428, `touchesBegan` 617-626, `resolveDrop` 746-805, `runAssistedMerge` 969-1002; nuevos `presentResolution`, `playBoardChange`, `performBoardChange`, `finishBoardChangeTurn`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift:68` (`.boardCelebration: 14`)
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift` (`syncCelebrations`, `releasePayload(.boardCelebration)`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (proyección `revealedTierMarker` en `refreshProjections`)
- Modify: `FisuEvolution/App/RootView.swift` (marcador `board.revealed` junto a `board.units`, línea ~343)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`--uitest-board-change` → `debugPlanBoardChange()`; `debugUnlockFloors` y `debugSetMaxTier` marcan lo revelado)
- Test: `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift`, `FisuEvolutionTests/CelebrationWiringTests.swift`; Create `FisuEvolutionUITests/BoardChangeUITests.swift`

**Interfaces:**
- Consumes: todo lo de T9.
- Produces: `GameState.revealedTierMarker: Int` (observado), `GameState.debugPlanBoardChange()` (DEBUG).
- Produces (escena, privados): `presentResolution(_:at:sourceNode:withinTurn:)`, `playBoardChange(_:)`.

- [ ] **Step 1: Los tests, en rojo**

`CelebrationQueueTests.swift`:

```swift
    @Test("el turno del tablero tolera un cambio entero: navegar, fundir, volar y revelar")
    func boardCelebrationCoversABoardChange() {
        #expect(CelebrationKind.boardCelebration.timeout == 14)
    }

    @Test("el offline y la carrera pasan antes que un cambio del tablero")
    func offlineAndCareerGoBeforeTheBoard() {
        var queue = CelebrationQueue()
        queue.enqueue(.towerNotice)          // ocupa el turno: sobre una cola vacía se promueve en el acto
        queue.enqueue(.boardCelebration)
        queue.enqueue(.careerChoice)
        queue.enqueue(.offlineEarnings)
        queue.finish(.towerNotice)
        #expect(queue.current == .offlineEarnings)
        queue.finish(.offlineEarnings)
        #expect(queue.current == .careerChoice)
        queue.finish(.careerChoice)
        #expect(queue.current == .boardCelebration)
    }
```

(El orden ya es ése —prioridades 1, 2 y 3—; el test lo pinea porque el embudo depende de él.)

`CelebrationWiringTests.swift`. Primero, el helper: `drainCelebrations` suma, antes del bucle,
`gameState.markRevealed(tier: gameState.player?.run.maxTierReached ?? 1)` — sin escena nadie
más marca el reveal, y la red de seguridad volvería a pedir el turno (es el comportamiento
nuevo, no un bug del test). Lo mismo en **todo** test de la app que cierre a mano un
`.boardCelebration` de un merge que subió de tier: `grep -rn "celebrationFinished(.boardCelebration)" FisuEvolutionTests`
y revisar cada uno (sin `| head`: la trampa del grep truncado de los cofres). Después:

```swift
    @Test("un cambio pendiente pide el turno del tablero sólo con el tablero a la vista")
    func pendingChangeAsksForTheTurnWhenVisible() async throws {
        let gameState = await makeGameState()
        gameState.debugPlanBoardChange()
        gameState.uiCoversBoard = true
        gameState.syncCelebrations()
        #expect(gameState.showing != .boardCelebration)
        gameState.uiCoversBoard = false
        gameState.syncCelebrations()
        #expect(gameState.showing == .boardCelebration)
    }

    @Test("un tier sin revelar vuelve a pedir turno hasta que se revela")
    func unrevealedTierKeepsAskingForItsTurn() async throws {
        let gameState = await makeGameState()
        gameState.player?.run.raiseFrontier(to: 3)
        gameState.syncCelebrations()
        #expect(gameState.showing == .boardCelebration)
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.showing == .boardCelebration)
        gameState.markRevealed(tier: 3)
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.showing == nil)
    }

    @Test("saltear el turno asienta el cambio que estaba en vuelo")
    func skipSettlesTheInFlightChange() async throws {
        let gameState = await makeGameState()
        gameState.debugPlanBoardChange()
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.syncCelebrations()
        _ = try #require(gameState.beginNextBoardChange())
        gameState.advanceCelebrations(delta: CelebrationQueue.skipFloor)
        #expect(gameState.skipCurrentCelebration())
        #expect(gameState.inFlightBoardChange == nil)
        #expect(gameState.player?.run.totalUnits == units - 1)
    }
```

`FisuEvolutionUITests/BoardChangeUITests.swift`:

```swift
import XCTest

/// Un cambio del tablero que no hizo el jugador se ve: el par se funde a la
/// vista y el personaje nuevo se revela.
final class BoardChangeUITests: XCTestCase {
    func testUnCambioDelTableroSeReproduceYRevela() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-board-change"]
        app.launch()
        let revealed = app.otherElements["board.revealed"]
        let units = app.otherElements["board.units"]
        XCTAssertTrue(revealed.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "value == %@", "2"), evaluatedWith: revealed)
        expectation(for: NSPredicate(format: "value == %@", "2"), evaluatedWith: units)
        waitForExpectations(timeout: 25)
    }
}
```

(El fixture planta un par de Fisuras sobre el Fisura inicial: 3 unidades → 2, y el tier 2 se
revela. El valor se lee igual con la UI apagada por la celebración, como `board.floor`.)

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter CelebrationQueueTests` (FAIL: 8 ≠ 14)
y Receta R con `-only-testing:FisuEvolutionTests/CelebrationWiringTests` (no compila:
`debugPlanBoardChange`).

- [ ] **Step 3: La cola y el estado**

`CelebrationQueue.swift:68` → `case .boardCelebration: 14` (comentario: cubre navegar al piso,
destacar, fundir, el vuelo del ascenso y el reveal).

`GameState+Celebrations.swift`, en `syncCelebrations()` antes de `publishCelebration()`:

```swift
        if boardIsVisibleForChanges, !pendingBoardChanges.isEmpty || typePendingReveal != nil {
            celebrations.enqueue(.boardCelebration)
        }
```

y en `releasePayload`, el caso `.boardCelebration` arranca con `settleInFlightBoardChange()`
(las tres salidas —fin, tap, watchdog— pasan por acá; en el fin normal no queda nada en vuelo y
no hace nada).

`GameState.swift`: `private(set) var revealedTierMarker = 1`, escrito en `refreshProjections`
sólo si cambió (`player.run.revealedTier`). `RootView`, después del marcador de `board.units`:

```swift
        .background(
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("board.revealed")
                .accessibilityValue(Text(verbatim: String(gameState.revealedTierMarker)))
        )
```

`GameState+Debug.swift`:

```swift
    /// Un par planeado como lo planearía un video, para ver el embudo entero.
    func debugPlanBoardChange() {
        debugGrantPair()
        guard let content, let player, let tower,
              let change = BoardChangePlanner.planAutoMerge(
                  state: player, tower: tower, tiers: content.tiers,
                  floorTable: content.floorTable, origin: .debug
              )
        else { return }
        enqueueBoardChange(change)
    }
```

registrado en el bloque `#if DEBUG` de `finishBootstrap` con
`if ProcessInfo.processInfo.arguments.contains("--uitest-board-change") { debugPlanBoardChange() }`.
`debugUnlockFloors(throughTier:)` y `debugSetMaxTier(_:)` terminan con
`markRevealed(tier: player.run.maxTierReached)` (sobre el `self.player` ya asignado): un fixture
entrega el estado final, y sin esto `--uitest-unlock-tower` abriría la partida con un reveal
que ningún test pidió.

- [ ] **Step 4: La escena**

Estado nuevo en `BoardScene`:

```swift
    /// El cambio del tablero que se está reproduciendo, hasta que se confirma.
    private var playingBoardChange: BoardChange?
    private static let boardChangeActionKey = "boardChange"
    /// Lo que se destaca el par antes de fundirse: se tiene que alcanzar a ver.
    private static let boardChangeBeat: TimeInterval = 0.35
```

`startBoardCelebrationIfItsTurn` decide qué reproduce el turno, en este orden:

```swift
    private func startBoardCelebrationIfItsTurn() {
        guard gameState.showing == .boardCelebration, !boardCelebrationRunning else { return }
        if let pending = pendingBoardCelebration {
            boardCelebrationRunning = true
            pendingBoardCelebration = nil
            runBoardCelebration(pending)
        } else if let change = gameState.beginNextBoardChange() {
            boardCelebrationRunning = true
            playBoardChange(change)
        } else if gameState.boardIsVisibleForChanges, let type = gameState.typePendingReveal {
            boardCelebrationRunning = true
            runBoardCelebration(PendingBoardCelebration(
                evolvedTo: type, promotedType: nil, promotionStart: nil, promotedToFloor: nil,
                unlockedFloorID: nil, revealAt: nil, floorOrdinal: gameState.visibleFloorOrdinal
            ))
        } else {
            // El turno llegó sin nada que reproducir (el tablero dejó de estar a la
            // vista): se devuelve y la cola lo vuelve a pedir cuando se pueda.
            gameState.celebrationFinished(.boardCelebration)
        }
    }
```

⚠️ El merge del jugador no cae en la última rama: `handleDrop` pide el turno y `resolveDrop`
guarda `pendingBoardCelebration` en la misma pasada síncrona, antes del próximo `update`.

En `runBoardCelebration`, la clausura `revealEvolution` marca antes de mostrar:

```swift
            self.gameState.markRevealed(tier: evolvedTo.tier)
            self.gameState.playHaptic(.evolution)
            self.runEvolutionReveal(for: evolvedTo, at: pending.revealAt, completion: celebrateFloor)
```

`presentResolution`, extraída del caso `.merged` de `resolveDrop` (líneas 757-796), con un
parámetro que dice si el turno ya es suyo:

```swift
    private func presentResolution(
        _ resolution: GameState.DropResolution?,
        at dropPoint: CGPoint,
        sourceNode node: CharacterNode,
        withinTurn: Bool
    ) {
        guard case .merged(let cell, let evolvedTo, let promotedType, let promotedToFloor, let unlockedFloorID)? = resolution else {
            if withinTurn { finishBoardChangeTurn() }
            return
        }
        let promotionStart = promotedToFloor == nil ? nil : fieldNode.convert(node.position, to: backgroundLayer)
        layoutBoard()
        let mergedNode = promotedToFloor == nil ? characterNodes[cell] : nil
        particles.emit(.merge, at: mergedNode?.position ?? dropPoint, in: fieldNode)
        mergedNode?.run(.sequence([.scale(to: 1.25, duration: 0.1), .scale(to: 1.0, duration: 0.12)]))
        guard evolvedTo != nil || promotedType != nil else {
            gameState.playHaptic(.merge)
            if withinTurn { finishBoardChangeTurn() }
            return
        }
        let pending = PendingBoardCelebration(
            evolvedTo: evolvedTo, promotedType: promotedType, promotionStart: promotionStart,
            promotedToFloor: promotedToFloor, unlockedFloorID: unlockedFloorID,
            revealAt: mergedNode?.position, floorOrdinal: gameState.visibleFloorOrdinal
        )
        if withinTurn {
            playingBoardChange = nil
            runBoardCelebration(pending)
        } else {
            pendingBoardCelebration = pending
        }
    }

    private func finishBoardChangeTurn() {
        playingBoardChange = nil
        guard boardCelebrationRunning else { return }
        boardCelebrationRunning = false
        gameState.celebrationFinished(.boardCelebration)
    }
```

(los comentarios de por qué el pop no espera y por qué el turno lo pide `handleDrop` se mudan
con el código). `resolveDrop` queda:

```swift
        let resolution = gameState.handleDrop(fromCell: originCell, toCell: targetCell)
        switch resolution {
        case .merged:
            presentResolution(resolution, at: dropPoint, sourceNode: node, withinTurn: false)
        case .moved:
            layoutBoard()
        case .careerPending, .snapBack:
            returnToAnchor(node)
        }
```

`runAssistedMerge` suma un destino de la fusión; el del jugador sigue siendo `resolveDrop`:

```swift
    private func runAssistedMerge(
        partner: CharacterNode,
        into target: CharacterNode,
        resolve: ((Int, Int, CGPoint, CharacterNode) -> Void)? = nil
    ) {
        // … igual hasta el .run final:
            .run { [weak self, weak partner] in
                guard let self, let partner else { return }
                if let resolve {
                    resolve(originCell, targetCell, meetingPoint, partner)
                } else {
                    self.resolveDrop(from: originCell, to: targetCell, at: meetingPoint, sourceNode: partner)
                }
            },
```

La reproducción del cambio:

```swift
    private func playBoardChange(_ change: BoardChange) {
        playingBoardChange = change
        let floor = gameState.floorOrdinal(of: change) ?? gameState.visibleFloorOrdinal
        let travels = floor != gameState.visibleFloorOrdinal
        gameState.setVisibleFloor(floor)
        let leadIn = travels ? Self.flightMaxDuration + 0.1 : Self.boardChangeBeat
        run(.sequence([
            .wait(forDuration: leadIn),
            .run { [weak self] in self?.performBoardChange(change) },
        ]), withKey: Self.boardChangeActionKey)
    }

    private func performBoardChange(_ change: BoardChange) {
        if gameState.boardVersion != renderedBoardVersion { layoutBoard() }
        switch change.kind {
        case .merge(_, _, let source, let target, _):
            guard let partner = characterNodes[source], let into = characterNodes[target] else {
                return confirmWithoutGesture(change)
            }
            for node in [partner, into] {
                node.removeAction(forKey: "wander")
                node.run(.sequence([
                    .scale(to: Self.candidateScale, duration: Self.candidatePopDuration),
                    .scale(to: 1.0, duration: Self.candidatePopDuration),
                ]))
            }
            run(.sequence([
                .wait(forDuration: Self.boardChangeBeat),
                .run { [weak self] in
                    self?.runAssistedMerge(partner: partner, into: into) { [weak self] _, _, point, node in
                        guard let self else { return }
                        self.presentResolution(self.gameState.confirmBoardChange(id: change.id),
                                               at: point, sourceNode: node, withinTurn: true)
                    }
                },
            ]), withKey: Self.boardChangeActionKey)
        case .evolve(_, let slot, _, _):
            guard let node = characterNodes[slot] else { return confirmWithoutGesture(change) }
            node.removeAction(forKey: "wander")
            node.run(.sequence([
                .scale(to: Self.candidateScale * 1.1, duration: Self.boardChangeBeat),
                .scale(to: 1.0, duration: 0.12),
            ])) { [weak self, weak node] in
                guard let self, let node else { return }
                self.presentResolution(self.gameState.confirmBoardChange(id: change.id),
                                       at: node.position, sourceNode: node, withinTurn: true)
            }
        case .arrival, .departure:
            confirmWithoutGesture(change)
        }
    }

    /// Llegadas y salidas no tienen gesto que imitar: se confirma y la unidad
    /// aparece (o se va) con el pop de siempre. Si es un personaje nuevo, igual
    /// pasa por la revelación.
    private func confirmWithoutGesture(_ change: BoardChange) {
        let resolution = gameState.confirmBoardChange(id: change.id)
        layoutBoard()
        guard case .merged(let cell, _, _, _, _)? = resolution, let node = characterNodes[cell] else {
            return finishBoardChangeTurn()
        }
        presentResolution(resolution, at: node.position, sourceNode: node, withinTurn: true)
    }
```

`touchesBegan`, después del bloque del skip: mientras un cambio se está moviendo, el toque
sólo puede saltearlo (si no, el jugador arrastraría al par a mitad del gesto):

```swift
        if gameState.skipCurrentCelebration() {
            abortBoardCelebration()
        }
        guard playingBoardChange == nil else { return }
```

`abortBoardCelebration` suma `removeAction(forKey: Self.boardChangeActionKey)`,
`playingBoardChange = nil`, `clearMergeCandidates()` y, por cada nodo de `characterNodes`,
`removeAction(forKey: "assistedMerge")`. El cambio en vuelo lo asienta `releasePayload` (paso 3);
el `bumpBoard` de esa confirmación relayoutea en el frame siguiente.

- [ ] **Step 5: Verde, UI y oráculo**

Run: `swift test --package-path Packages/EconomyKit --filter CelebrationQueueTests`; Receta R con
`CelebrationWiringTests`, `BoardChangeWiringTests` y `BoardGestureTests` → PASS; Receta R con
`-only-testing:FisuEvolutionUITests/BoardChangeUITests -only-testing:FisuEvolutionUITests/AscentRenderingUITests -only-testing:FisuEvolutionUITests/BoardGestureUITests`
→ PASS (los dos últimos prueban que el merge del jugador sigue igual y que el fixture de la
torre no dispara reveals). Mirar el cambio en el simulador con Reduce Motion prendido y
apagado (trampa 9: la verificación visual corre en los dos sentidos). Después
`Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Scenes/BoardScene.swift Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift \
  FisuEvolution/Game/State/GameState+Celebrations.swift FisuEvolution/Game/State/GameState.swift \
  FisuEvolution/App/RootView.swift FisuEvolution/Game/State/GameState+Debug.swift \
  FisuEvolutionTests/CelebrationWiringTests.swift FisuEvolutionUITests/BoardChangeUITests.swift
git diff --cached --stat
git commit -m "feat(tablero): la escena reproduce los cambios como merges y revela lo que faltó"
```

---

### Task 11: El sorteo de eventos salta lo inaplicable y un sorteo vacío no gasta el intervalo

**Objetivo:** que el sorteo sólo elija eventos que pueden pasar ahora (el Aguinaldo sin pasivo,
la Startup sin nadie que pueda crecer o el Blanqueo con el piso lleno quedan afuera) y que un
sorteo sin candidatos reintente a los `retryWhenNoneApplicableSeconds` en vez de esperar otros
15 minutos (hoy `scheduleNextEvent` corre **antes** del sorteo, `GameState+Bonus.swift:209`).
Puede ir en paralelo con T10 (archivos disjuntos).

**Files:**
- Modify: `FisuEvolution/Managers/ContentSystems.swift` (`EventManager.fireRandomEvent(…, isApplicable:)`, `blanqueoType(for:state:tiers:)` extraído de `apply`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (`fireEventIfDue`, `eventIsApplicable(_:)`)
- Modify: `FisuEvolution/Managers/ContentConfigs.swift` (`EventsConfig.retryWhenNoneApplicableSeconds`)
- Modify: `FisuEvolution/Resources/Config/events.json` (`"retryWhenNoneApplicableSeconds": 30`)
- Create: `FisuEvolutionTests/EventSchedulingTests.swift`

**Interfaces:**
- Consumes: `BoardChangePlanner.planEvolve`, `planArrival` (T7).
- Produces: `EventManager.fireRandomEvent(state:config:tiers:floorTable:economy:now:lastFired:isApplicable:rng:)` — `isApplicable: (EventsConfig.Event) -> Bool`, sin default.
- Produces: `EventManager.blanqueoType(for:state:tiers:) -> CharacterType?`.
- Produces: `GameState.eventIsApplicable(_ event: EventsConfig.Event) -> Bool`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/EventSchedulingTests.swift` (copiar el `FixedRNG` de `ContentSystemsTests`,
que es privado de esa suite):

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

private struct FixedRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite("Eventos: el sorteo")
@MainActor
struct EventSchedulingTests {
    @Test("un sorteo sin candidatos no gasta el intervalo")
    func emptyDrawRetriesSoon() async throws {
        let gameState = await makeGameState()
        let now = Date().timeIntervalSince1970
        gameState.nextEventAt = now - 1
        gameState.fireEventIfDue(now: now)
        let retry = try #require(gameState.content?.events.retryWhenNoneApplicableSeconds)
        #expect(gameState.nextEventAt == now + retry)
    }

    @Test("lo que no aplica no sale nunca")
    func inapplicableEventsAreNeverDrawn() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        var state = try #require(gameState.player)
        state.run.raiseFrontier(to: 20)
        for seed in UInt64(0)..<300 {
            var rng = FixedRNG(state: seed)
            var copy = state
            let roll = EventManager.fireRandomEvent(
                state: &copy, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
                economy: try #require(gameState.economy), now: 1_000_000, lastFired: [:],
                isApplicable: { $0.id != "startup_comprada" }, rng: &rng
            )
            #expect(roll?.event.id != "startup_comprada")
        }
    }

    @Test("sin nadie que pueda crecer solo, la Startup no aplica")
    func startupNeedsSomeoneWhoCanEvolve() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        gameState.player?.run.units = ["administrativo": 1]
        gameState.reconcileTower()
        let startup = try #require(content.events.events.first { $0.id == "startup_comprada" })
        #expect(!gameState.eventIsApplicable(startup))
    }

    @Test("sin pasivo, el Aguinaldo no aplica")
    func aguinaldoNeedsPassiveIncome() async throws {
        let gameState = await makeGameState()
        let aguinaldo = try #require(gameState.content?.events.events.first { $0.id == "aguinaldo" })
        #expect(!gameState.eventIsApplicable(aguinaldo))
    }
}
```

(`administrativo` es T10 y su siguiente, `junior`, es nodo de carrera: nadie puede crecer
solo. Una partida nueva tiene frontera 1, así que ningún evento es elegible y el sorteo vuelve
vacío.)

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/EventSchedulingTests`.
Expected: no compila (`isApplicable:`, `eventIsApplicable`); `emptyDrawRetriesSoon` después
falla con `nextEventAt` a 15 min.

- [ ] **Step 3: La implementación**

`ContentSystems.swift`, en `fireRandomEvent`: el parámetro `isApplicable` y el filtro

```swift
        let eligible = config.events.filter { event in
            state.run.maxTierReached >= event.minTier
                && now - (lastFired[event.id] ?? -.infinity) >= event.cooldownSeconds
                && isApplicable(event)
        }
```

y la elección del tipo del Blanqueo sale de `apply` a una función propia, que usan el sorteo
y el apply:

```swift
    static func blanqueoType(for event: EventsConfig.Event, state: PlayerState, tiers: TierRepository) -> CharacterType? {
        let tier = max(1, state.run.maxTierReached - Int(event.magnitude))
        return tiers.concreteTypes.first { candidate in
            candidate.tier == tier && (state.run.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        } ?? tiers.concreteTypes.first { $0.tier == tier }
    }
```

`GameState+Bonus.swift`:

```swift
    func eventIsApplicable(_ event: EventsConfig.Event) -> Bool {
        guard let content, let player, let tower else { return false }
        switch event.effectType {
        case .incomeMultiplier, .spawnCostMultiplier, .frozenCoins:
            return true
        case .bonusCoins:
            return IncomeTicker.basePassivePerSecond(
                state: player, tiers: content.tiers, floorTable: content.floorTable, config: content.economy
            ) > 0
        case .instantEvolution:
            return BoardChangePlanner.planEvolve(
                state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable, origin: .eventStartup
            ) != nil
        case .freeHighTier:
            guard let type = EventManager.blanqueoType(for: event, state: player, tiers: content.tiers) else { return false }
            return BoardChangePlanner.planArrival(
                typeId: type.id, state: player, tower: tower, tiers: content.tiers,
                floorTable: content.floorTable, origin: .eventBlanqueo
            ) != nil
        }
    }
```

y `fireEventIfDue` precalcula lo aplicable (así el sorteo no lee `self` mientras `rng` está
prestado como `inout`) y reprograma **después** del sorteo:

```swift
        guard now >= nextEventAt else { return }
        let applicable = Set(content.events.events.filter(eventIsApplicable).map(\.id))
        guard let roll = EventManager.fireRandomEvent(
            state: &player, config: content.events, tiers: content.tiers, floorTable: content.floorTable,
            economy: economy, now: now, lastFired: eventLastFired,
            isApplicable: { applicable.contains($0.id) }, rng: &rng
        ) else {
            nextEventAt = now + content.events.retryWhenNoneApplicableSeconds
            return
        }
        scheduleNextEvent(from: now)
```

`EventsConfig` suma `let retryWhenNoneApplicableSeconds: Double` **después de
`resumeGraceSeconds` y antes de `events`**; `events.json` `"retryWhenNoneApplicableSeconds": 30,`.

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con `EventSchedulingTests` y `ContentSystemsTests` → PASS. Después
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Managers/ContentSystems.swift FisuEvolution/Game/State/GameState+Bonus.swift \
  FisuEvolution/Managers/ContentConfigs.swift FisuEvolution/Resources/Config/events.json \
  FisuEvolutionTests/EventSchedulingTests.swift
git diff --cached --stat
git commit -m "fix(eventos): el sorteo salta lo inaplicable y un sorteo vacío no gasta el intervalo"
```

---

### Task 12: Startup, Blanqueo, los videos y la carrera pasan por el embudo

**Objetivo:** ningún productor muta el tablero en el acto. "Startup comprada" devuelve la
intención de evolucionar; el Blanqueo, la de una llegada; los videos "Evolución gratis" y
"Personaje de regalo" planean su cambio; y `chooseCareer` acredita el premio y deja el merge
de la carrera como un `BoardChange.merge` que la escena reproduce como merge asistido, con la
revelación del T11. Se borran `performInstantMerge`, `grantRareUnit`, `placeGrantedUnit` y
`resyncTower` (quedan sin llamadores).

**Files:**
- Modify: `FisuEvolution/Managers/ContentSystems.swift` (`EventManager.Roll`, `apply` de `.instantEvolution` y `.freeHighTier`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (`fireEventIfDue` → `handleEventRoll(_:now:)`; `applyRewardedReward` `.instantMerge`/`.rareUnit`; borrar los tres privados)
- Modify: `FisuEvolution/Game/State/GameState+Actions.swift` (`chooseCareer`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (`CareerPrompt.floorOrdinal`; borrar `resyncTower`)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`debugPresentCareerChoice` pasa el piso)
- Create: `FisuEvolutionTests/BoardChangeProducersTests.swift`

**Interfaces:**
- Consumes: el embudo de T9/T10; `eventIsApplicable` y `blanqueoType` (T11).
- Produces: `EventManager.BoardIntent: Equatable { case evolveBestUnit, grantUnit(typeId: String) }` y `Roll.boardIntent: BoardIntent?` (reemplaza `grantedUnitTypeId` y `unitsChanged`).
- Produces: `GameState.handleEventRoll(_ roll: EventManager.Roll, now: TimeInterval)`.
- Produces: `GameState.rareUnitChange() -> BoardChange?`.
- Produces: `CareerPrompt.floorOrdinal: Int`.

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/BoardChangeProducersTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Cambios del tablero: los productores")
@MainActor
struct BoardChangeProducersTests {
    @Test("la Startup ya no evoluciona en el acto: deja el cambio planeado")
    func startupPlansInsteadOfMutating() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let startup = try #require(content.events.events.first { $0.id == "startup_comprada" })
        var state = try #require(gameState.player)
        state.run.raiseFrontier(to: startup.minTier)
        let units = state.run.units
        let roll = try #require(EventManager.fireRandomEvent(
            state: &state, config: EventsConfig(schemaVersion: 1, baseIntervalSeconds: 900, intervalJitterSeconds: 0,
                                                resumeGraceSeconds: 60, retryWhenNoneApplicableSeconds: 30, events: [startup]),
            tiers: content.tiers, floorTable: content.floorTable, economy: try #require(gameState.economy),
            now: 0, lastFired: [:], isApplicable: { _ in true }, rng: &gameState.rng
        ))
        #expect(state.run.units == units)
        #expect(roll.boardIntent == .evolveBestUnit)
        gameState.handleEventRoll(roll, now: 0)
        #expect(gameState.pendingBoardChanges.first?.origin == .eventStartup)
    }

    @Test("el video de evolución gratis planea su merge y no toca el tablero")
    func freeMergeVideoPlans() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        let units = try #require(gameState.player?.run.units)
        gameState.applyRewardedReward(rewardId: "accelerate_evolution")
        #expect(gameState.player?.run.units == units)
        #expect(gameState.pendingBoardChanges.first?.origin == .rewardedInstantMerge)
    }

    @Test("el personaje de regalo llega por el embudo")
    func rareUnitVideoPlans() async throws {
        let gameState = await makeGameState()
        gameState.applyRewardedReward(rewardId: "spawn_rare")
        #expect(gameState.pendingBoardChanges.first?.origin == .rewardedRareUnit)
    }

    @Test("elegir carrera acredita ya y deja el merge del T11 para su turno, con revelación")
    func careerDefersTheMerge() async throws {
        let gameState = await makeGameState()
        let content = try #require(gameState.content)
        let options = try #require(content.tiers.type(id: "junior")?.choiceOptions)
            .compactMap { content.tiers.type(id: $0) }
        gameState.player?.run.units = ["administrativo": 2]
        gameState.reconcileTower()
        let floor = content.floorTable.ordinal(forTier: 10)
        gameState.visibleFloorOrdinal = floor
        let pair = gameState.visiblePlacements.map(\.slot).sorted()
        gameState.careerPrompt = GameState.CareerPrompt(
            options: options, floorOrdinal: floor, sourceCell: pair[0], targetCell: pair[1]
        )
        gameState.player?.run.raiseFrontier(to: 10)
        gameState.markRevealed(tier: 10)
        gameState.chooseCareer(optionId: "junior_programmer")
        #expect(gameState.careerPrompt == nil)
        #expect(gameState.player?.run.units["administrativo"] == 2)
        let change = try #require(gameState.beginNextBoardChange())
        let resolution = gameState.confirmBoardChange(id: change.id)
        guard case .merged(_, let evolvedTo, _, _, _)? = resolution else {
            Issue.record("la carrera no se fusionó")
            return
        }
        #expect(evolvedTo?.id == "junior_programmer")
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/BoardChangeProducersTests`.
Expected: no compila (`boardIntent`, `handleEventRoll`, `CareerPrompt.floorOrdinal`).

- [ ] **Step 3: La implementación**

`EventManager`:

```swift
    enum BoardIntent: Equatable {
        case evolveBestUnit
        case grantUnit(typeId: String)
    }

    struct Roll {
        let event: EventsConfig.Event
        let active: ActiveEvent?
        /// Lo que el evento le hace al tablero. NO se aplica acá: el caller lo
        /// planea por el embudo y la escena lo reproduce a la vista.
        let boardIntent: BoardIntent?
    }
```

En `apply`, `.instantEvolution` deja de mutar (`boardIntent = .evolveBestUnit`) y
`.freeHighTier` usa `blanqueoType` (`boardIntent = .grantUnit(typeId: type.id)`).

`GameState+Bonus.swift`: el cuerpo de `fireEventIfDue` después del sorteo pasa a
`handleEventRoll(roll, now: now)`:

```swift
    func handleEventRoll(_ roll: EventManager.Roll, now: TimeInterval) {
        guard let content, let player, let tower else { return }
        switch roll.boardIntent {
        case .evolveBestUnit:
            BoardChangePlanner.planEvolve(
                state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable, origin: .eventStartup
            ).map(enqueueBoardChange)
        case .grantUnit(let typeId):
            BoardChangePlanner.planArrival(
                typeId: typeId, state: player, tower: tower, tiers: content.tiers,
                floorTable: content.floorTable, origin: .eventBlanqueo
            ).map(enqueueBoardChange)
        case nil:
            break
        }
        eventLastFired[roll.event.id] = now
        activeEvent = roll.active
        audio?.play(.event)
        bumpBoard()
        scheduleSave()
        Log.economy.info("event fired: \(roll.event.id)")
    }
```

`applyRewardedReward`: `.instantMerge` → `planAutoMerge(…, origin: .rewardedInstantMerge).map(enqueueBoardChange)`
y `.rareUnit` → `rareUnitChange().map(enqueueBoardChange)`, con:

```swift
    /// El "Personaje de regalo": una unidad del tier máximo (respetando la carrera)
    /// que llega por el embudo. La usa también la fila del video (T14).
    func rareUnitChange() -> BoardChange? {
        guard let content, let player, let tower else { return nil }
        let tier = player.run.maxTierReached
        guard let type = content.tiers.concreteTypes.first(where: { candidate in
            candidate.tier == tier && (player.run.chosenCareerPath.map { candidate.id.hasSuffix($0) } ?? true)
        }) ?? content.tiers.concreteTypes.first(where: { $0.tier == tier }) else { return nil }
        return BoardChangePlanner.planArrival(
            typeId: type.id, state: player, tower: tower, tiers: content.tiers,
            floorTable: content.floorTable, origin: .rewardedRareUnit
        )
    }
```

Se borran `performInstantMerge`, `grantRareUnit`, `placeGrantedUnit` y `GameState.resyncTower`.

`CareerPrompt` suma `let floorOrdinal: Int` **entre `options` y `sourceCell`** (el init
memberwise sigue ese orden; `handleDrop` lo llena con `visibleFloorOrdinal`, y
`debugPresentCareerChoice` también). `chooseCareer`:

```swift
    func chooseCareer(optionId: String) {
        guard let prompt = careerPrompt, let content, var player, let tower else { return }
        player.run.chosenCareerPath = MergeRules.careerPath(fromOptionId: optionId)
        self.player = player
        careerPrompt = nil
        celebrationFinished(.careerChoice)
        // El premio se acredita ANTES del merge: lo que la carta prometió es lo
        // que se cobra, sin el salto de frontera del T11 en el medio.
        grantCareerReward(optionId: optionId)
        if let sourceType = tower.typeId(floorOrdinal: prompt.floorOrdinal, slot: prompt.sourceCell),
           case .merged(let newTypeId) = MergeRules.evaluate(
               sourceTypeId: sourceType, targetTypeId: sourceType,
               chosenCareerPath: player.run.chosenCareerPath, tiers: content.tiers
           ) {
            enqueueBoardChange(BoardChange(
                kind: .merge(floorOrdinal: prompt.floorOrdinal, typeId: sourceType,
                             sourceSlot: prompt.sourceCell, targetSlot: prompt.targetCell, newTypeId: newTypeId),
                origin: .career
            ))
        }
        refreshProjections()
        scheduleSave()
    }
```

(si el par ya no está, `revalidate` busca otro par del mismo tipo en ese piso o lo descarta:
elegiste y cobraste igual, RF-15). `reportMergeMilestones` y `rollSpecialDrop` del merge de
carrera se van con él: un merge que no hizo el jugador no tira special (mismo criterio que hoy
el video de evolución gratis).

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con `BoardChangeProducersTests`, `CareerRewardTests`, `ContentSystemsTests`,
`BonusCooldownTests` y `CelebrationWiringTests` → PASS; Receta R con
`-only-testing:FisuEvolutionUITests/CareerChoiceUITests` → PASS. Después
`Tools/v2/oraculo.sh completo` → `VERDE`. Escenario a mano: con el panel de debug, fixture de
carrera, elegir Programador → el par se funde a la vista y se revela el Programador Jr.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Managers/ContentSystems.swift FisuEvolution/Game/State/GameState+Bonus.swift \
  FisuEvolution/Game/State/GameState+Actions.swift FisuEvolution/Game/State/GameState.swift \
  FisuEvolution/Game/State/GameState+Debug.swift FisuEvolutionTests/BoardChangeProducersTests.swift
git diff --cached --stat
git commit -m "fix(tablero): Startup, Blanqueo, los videos y la carrera pasan por el embudo"
```

---

### Task 13: El Corralito congela el gasto, no los ingresos — con salida por video

**Objetivo:** decisión del dueño (§2): "No podés gastar 45 s; los ingresos siguen; escape por
video". Efecto nuevo `ActiveModifier.Effect.spendingFrozen`: contratar, mejorar personajes y
desbloquear pasivos (todo lo que se paga con **plata**) rebotan con su motivo; el ORO no se
congela; el pasivo y el tap siguen. Hoy el evento pone `incomeMultiplier ×0`
(`ContentSystems.swift:200-207`), que hace exactamente lo contrario de lo que dice su texto.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (`case spendingFrozen`, `ModifierMath.spendingFrozenUntil(_:now:)`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift` (`HireQuote.spendingFrozen`, `TowerError.spendingFrozen`, guard en `hire`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/CharUpgrades.swift` (`purchase(…, now:)`, `PurchaseError.spendingFrozen`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/GameActions.swift` (`applyPassiveUnlock(…, now:)`, `PassiveUnlockError.spendingFrozen`)
- Modify: `FisuEvolution/Managers/ContentConfigs.swift` (`EventsConfig.EffectType.frozenCoins` → `.spendingFrozen`; `Event.escape: String?`)
- Modify: `FisuEvolution/Resources/Config/events.json` (corralito: `"effectType": "spendingFrozen"`, `"escape": "video"`)
- Modify: `FisuEvolution/Managers/ContentSystems.swift` (`EventManager.apply`, `ActiveEvent.escapableByVideo`)
- Modify: `FisuEvolution/Game/State/ActiveBonus.swift:86-95`, `FisuEvolution/UI/HUD/ActiveBonusBar.swift:129` (los dos `switch` exhaustivos)
- Modify: `FisuEvolution/Game/State/GameState.swift` (`TowerNotice.Kind.spendingFrozen`, proyección `spendingFrozenUntil`)
- Modify: `FisuEvolution/Game/State/GameState+Hiring.swift`, `GameState+Upgrades.swift`, `GameState+Actions.swift` (`now:`, el motivo y `affordable` falso con el gasto congelado)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (`escapeActiveEvent()`, `eventIsApplicable` con el caso renombrado)
- Modify: `FisuEvolution/UI/HUD/EventBannerView.swift` (botón de video)
- Create: `FisuEvolution/UI/HUD/SpendingFrozenStrip.swift`; Modify: `FisuEvolution/UI/Jobs/FisuJobsView.swift`, `FisuEvolution/UI/Store/UpgradesView.swift` (la franja arriba de la lista)
- Modify: `FisuEvolution/App/RootView.swift` (`TowerNoticeView.messageKey`)
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (fixture `--uitest-corralito`)
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (4 claves)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/SpendingFrozenTests.swift`, `FisuEvolutionTests/CorralitoTests.swift`, `FisuEvolutionUITests/CorralitoUITests.swift`
- Modify (mecánico): los call sites de `applyPassiveUnlock` y `CharUpgrades.purchase` en tests suman `now: 0`.

**Interfaces:**
- Produces: `ActiveModifier.Effect.spendingFrozen`; `ModifierMath.spendingFrozenUntil(_ modifiers:, now:) -> TimeInterval?`.
- Produces: `HireQuote.spendingFrozen: Bool` (lo llenan los dos `hireQuote`); `TowerError.spendingFrozen`.
- Produces: `CharUpgrades.purchase(type:state:config:economy:now:)`, `StandardEconomy.applyPassiveUnlock(typeId:state:tiers:now:)` — `now` sin default.
- Produces: `GameState.spendingFrozenUntil: TimeInterval?` (observado), `GameState.escapeActiveEvent(now:)`, `GameState.debugStartCorralito()` (DEBUG).
- Produces: `EventManager.ActiveEvent.escapableByVideo: Bool`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/SpendingFrozenTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Corralito: se congela el gasto, no los ingresos")
struct SpendingFrozenTests {
    let tiers: TierRepository
    let economy = fxEconomy()

    init() throws {
        tiers = try fxTiers()
    }

    private let freeze = ActiveModifier(effect: .spendingFrozen, magnitude: 1, expiresAt: 45, sourceKey: "event.corralito")

    @Test("contratar rebota mientras dura y vuelve cuando vence")
    func hiringIsFrozen() throws {
        let fixture = try fxStateAndTower()
        var state = fixture.state
        var tower = fixture.tower
        state.run.coins = 1_000_000
        state.run.activeModifiers = [freeze]
        let frozen = try #require(TowerActions.hireQuote(
            typeId: "a", state: state, config: fxConfig(), floorTable: fixture.floorTable, tiers: tiers, now: 10
        ))
        #expect(frozen.spendingFrozen)
        #expect(throws: TowerError.spendingFrozen) {
            try TowerActions.hire(quote: frozen, state: &state, tower: &tower, floorTable: fixture.floorTable,
                                  config: fxConfig(), countsAsPurchase: true)
        }
        let thawed = try #require(TowerActions.hireQuote(
            typeId: "a", state: state, config: fxConfig(), floorTable: fixture.floorTable, tiers: tiers, now: 50
        ))
        #expect(!thawed.spendingFrozen)
    }

    @Test("los ingresos siguen")
    func incomeKeepsFlowing() throws {
        var state = fxState(units: ["a": 2])
        state.run.coins = 100
        try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers, now: 0)
        let before = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: try fxFloorTable(), config: fxConfig(), now: 10)
        state.run.activeModifiers = [freeze]
        let during = IncomeTicker.passivePerSecond(state: state, tiers: tiers, floorTable: try fxFloorTable(), config: fxConfig(), now: 10)
        #expect(during == before)
    }

    @Test("mejorar y desbloquear pasivos también rebotan")
    func upgradesAndPassivesAreFrozen() throws {
        var state = fxState(units: ["a": 2])
        state.run.coins = 1_000_000
        state.run.activeModifiers = [freeze]
        let type = try #require(tiers.type(id: "a"))
        #expect(throws: CharUpgrades.PurchaseError.spendingFrozen) {
            try CharUpgrades.purchase(type: type, state: &state, config: fxConfig(), economy: economy, now: 10)
        }
        #expect(throws: PassiveUnlockError.spendingFrozen) {
            try economy.applyPassiveUnlock(typeId: "a", state: &state, tiers: tiers, now: 10)
        }
    }
}
```

`FisuEvolutionTests/CorralitoTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Corralito en el juego")
@MainActor
struct CorralitoTests {
    @Test("el evento congela el gasto con su motivo, y el video lo levanta")
    func corralitoFreezesAndTheVideoLifts() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.debugStartCorralito()
        gameState.refreshProjections()
        #expect(gameState.spendingFrozenUntil != nil)
        let base = try #require(gameState.content?.tiers.baseType.id)
        let units = try #require(gameState.player?.run.totalUnits)
        gameState.hireCharacter(typeId: base)
        #expect(gameState.player?.run.totalUnits == units)
        #expect(gameState.towerNotice?.kind == .spendingFrozen)
        gameState.escapeActiveEvent()
        gameState.refreshProjections()
        #expect(gameState.spendingFrozenUntil == nil)
        gameState.hireCharacter(typeId: base)
        #expect(gameState.player?.run.totalUnits == units + 1)
    }

    @Test("el JSON del Corralito dice lo que hace")
    func corralitoDataMatchesTheDecision() async throws {
        let gameState = await makeGameState()
        let corralito = try #require(gameState.content?.events.events.first { $0.id == "corralito" })
        #expect(corralito.effectType == .spendingFrozen)
        #expect(corralito.escape == "video")
        #expect(corralito.durationSeconds == 45)
    }
}
```

`FisuEvolutionUITests/CorralitoUITests.swift`:

```swift
import XCTest

final class CorralitoUITests: XCTestCase {
    func testElCorralitoTiemblaConSuMotivoYOfreceLaSalidaPorVideo() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-coins", "--uitest-corralito"]
        app.launch()
        XCTAssertTrue(app.buttons["event.escape"].waitForExistence(timeout: 15))
        app.buttons["hud.quickhire"].tap()
        XCTAssertTrue(app.otherElements["tower.notice"].waitForExistence(timeout: 5)
            || app.staticTexts["tower.notice"].waitForExistence(timeout: 1))
        app.buttons["hud.hire"].tap()
        XCTAssertTrue(app.otherElements["jobs.spending_frozen"].waitForExistence(timeout: 5))
    }
}
```

(Antes de escribir los selectores, confirmar en un test vecino cómo se consulta hoy
`tower.notice` y `hud.quickhire`; los ids son los de `RootView.swift:714` y
`QuickHireButton`.)

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter SpendingFrozenTests` y Receta R con
`-only-testing:FisuEvolutionTests/CorralitoTests`. Expected: no compila (`spendingFrozen`, `now:`).

- [ ] **Step 3: EconomyKit**

```swift
// ActiveModifier.Effect
        /// No se puede gastar plata mientras dura (Corralito). Los ingresos siguen.
        case spendingFrozen

// ModifierMath
    public static func spendingFrozenUntil(_ modifiers: [ActiveModifier], now: TimeInterval) -> TimeInterval? {
        modifiers.filter { $0.effect == .spendingFrozen && $0.isActive(at: now) }.map(\.expiresAt).max()
    }
```

`HireQuote` suma `public let spendingFrozen: Bool` (init con `spendingFrozen: Bool = false`: el
quote lo arman sólo los dos `hireQuote`, que lo pasan siempre); los dos `hireQuote` lo llenan
con `ModifierMath.spendingFrozenUntil(state.run.activeModifiers, now: now) != nil`. En `hire`,
antes del guard de saldo: `guard !(quote.spendingFrozen && quote.cost > 0) else { throw TowerError.spendingFrozen }`
(una contratación gratis no es gastar). `CharUpgrades.purchase` y `applyPassiveUnlock` suman
`now:` y el mismo guard con su error.

- [ ] **Step 4: La app**

`EventsConfig.EffectType`: `frozenCoins` → `spendingFrozen`; `Event` suma `let escape: String?`.
`EventManager.apply`:

```swift
        case .spendingFrozen:
            state.run.activeModifiers.append(ActiveModifier(
                effect: .spendingFrozen,
                magnitude: 1,
                expiresAt: now + event.durationSeconds,
                sourceKey: "event.\(event.id)"
            ))
```

`ActiveEvent` suma `let escapableByVideo: Bool` (`event.escape == "video"`).

`ActiveBonusBuilder.effectText`:

```swift
    private static func effectText(for modifier: ActiveModifier) -> String {
        let boostEffect: BoostsConfig.EffectType
        switch modifier.effect {
        case .incomeMultiplier: boostEffect = .incomeMultiplier
        case .tapMultiplier: boostEffect = .tapMultiplier
        case .spawnCostMultiplier: boostEffect = .spawnCostMultiplier
        case .spendingFrozen: return String(localized: "bonus.chip.spending_frozen")
        }
        return EffectFormatter.text(EffectDescriptor.amount(forBoost: boostEffect, magnitude: modifier.magnitude))
    }
```

`ActiveBonusBar.swift:129`: `case .spendingFrozen: Color("PalettePink")`.

`GameState.swift`: `TowerNotice.Kind.spendingFrozen` y `private(set) var spendingFrozenUntil: TimeInterval?`,
escrito en `refreshProjections` sólo si cambió (`ModifierMath.spendingFrozenUntil(player.run.activeModifiers, now:)`):
cambia al empezar y al terminar, nunca por segundo. `RootView.TowerNoticeView.messageKey`:
`case .spendingFrozen: "tower.notice.spending_frozen"`.

`+Hiring`: `hireCharacter` y `buySpawn` (`+Actions`) atrapan `TowerError.spendingFrozen` y
publican `towerNotice = TowerNotice(kind: .spendingFrozen)` con el háptico de error;
`JobRow.affordable` y la oferta del atajo (`computeBestHire`) son `false` con
`quote.spendingFrozen`, así `PricePill` y `QuickHireButton` tiemblan solos. `+Upgrades`
(`buyCharacterUpgrade`, filas) y `unlockPassive`/`buyPassiveFromMenu` (`+Actions`/`+Upgrades`):
lo mismo con sus errores, pasando `now: Date().timeIntervalSince1970`.

`+Bonus`:

```swift
    /// La salida por video de un evento negativo. E4 la mueve al popup del chip.
    func escapeActiveEvent(now: TimeInterval = Date().timeIntervalSince1970) {
        guard let event = activeEvent, event.escapableByVideo, var player else { return }
        player.run.activeModifiers.removeAll { $0.sourceKey == "event.\(event.id)" }
        self.player = player
        activeEvent = nil
        effectsVersion += 1
        refreshProjections()
        scheduleSave()
        Log.economy.info("event escaped by video: \(event.id)")
    }
```

`EventBannerView`: el `hud.event` (que hoy está en el `HStack` con `.combine`) pasa a la parte
de texto, y el botón va **afuera** de ese elemento (trampa 9a-bis: un id en un contenedor pisa
el de sus hijos):

```swift
            if event.escapableByVideo {
                ActionPill(titleKey: "event.escape.video", systemImage: "play.fill",
                           tint: Color("PaletteGreen"), identifier: "event.escape") {
                    Task {
                        if await ads.showRewarded(for: .gifts) { gameState.escapeActiveEvent() }
                    }
                }
            }
```

(con `@Environment(GameState.self)` y `@Environment(AdsCoordinator.self) private var ads`;
`.gifts` es la unidad que existe hoy, E7 la mueve a la suya.)

`SpendingFrozenStrip.swift` (estilo de la casa: `StateBadge` naranja, cuenta regresiva con
`TimelineView(.periodic(from: .now, by: 1))`, que es tiempo de vista y no de juego):

```swift
import SwiftUI

/// La franja de arriba de FisuJobs y Mejoras mientras dura el Corralito: las
/// hojas tapan el aviso del HUD, así que el motivo tiene que estar acá.
struct SpendingFrozenStrip: View {
    let until: TimeInterval
    let identifier: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, Int((until - context.date.timeIntervalSince1970).rounded(.up)))
            StateBadge(
                text: String(localized: "spending.frozen.strip \(String(left))"),
                systemImage: "lock.fill",
                textAlignment: .center,
                muted: false
            )
        }
        .accessibilityElement(children: .combine)
        .background(Color.clear.accessibilityElement().accessibilityIdentifier(identifier))
    }
}
```

FisuJobs y Mejoras la muestran arriba de la lista cuando
`gameState.spendingFrozenUntil` no es `nil` (ids `jobs.spending_frozen` y
`upgrades.spending_frozen`). `+Debug`: `debugStartCorralito()` corre el `apply` real del
evento `corralito` (`EventManager` con un config de un solo evento) y publica su
`activeEvent`; se registra con `--uitest-corralito`.

Claves nuevas (es / en):

| Clave | es | en |
|---|---|---|
| `bonus.chip.spending_frozen` | Sin gastos | No spending |
| `event.escape.video` | Liberar con video | Lift it with a video |
| `spending.frozen.strip %@` | Corralito: no podés gastar · %@ s | Corralito: no spending · %@ s |
| `tower.notice.spending_frozen` | ¡Corralito! No podés gastar hasta que termine; la plata sigue entrando | Corralito! You can't spend until it ends; your money keeps coming in |

- [ ] **Step 5: Verde, UI y oráculo**

Run: `/opt/homebrew/bin/xcodegen generate`; EK `swift test --package-path Packages/EconomyKit`;
Receta R con `CorralitoTests`, `ActiveBonusTests`, `JobRowsTests`, `BestHireTests`,
`UpgradesMenuTests` → PASS; Receta R con `-only-testing:FisuEvolutionUITests/CorralitoUITests`
→ PASS. Captura del banner con el botón y de la franja en FisuJobs (SE y 16 Pro), mirada contra
FisuJobs. Después `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift \
  Packages/EconomyKit/Sources/EconomyKit/CharUpgrades.swift Packages/EconomyKit/Sources/EconomyKit/GameActions.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/ FisuEvolution/Managers/ContentConfigs.swift \
  FisuEvolution/Managers/ContentSystems.swift FisuEvolution/Resources/Config/events.json \
  FisuEvolution/Game/State/ FisuEvolution/UI/HUD/ FisuEvolution/UI/Jobs/FisuJobsView.swift \
  FisuEvolution/UI/Store/UpgradesView.swift FisuEvolution/App/RootView.swift \
  FisuEvolution/Resources/Localizable.xcstrings FisuEvolutionTests/ FisuEvolutionUITests/CorralitoUITests.swift
git diff --cached --stat
git commit -m "fix(eventos): el Corralito congela el gasto y no los ingresos, con salida por video"
```

(Los `git add` de carpeta van sólo después de mirar `git status`: si aparece algo que no es de
esta tarea, se stagea por archivo.)

---

### Task 14: Un video sin efecto no gasta el cooldown — y si deja de aplicar, compensa 3 min

**Objetivo:** "Evolución gratis" sin pares y "Personaje de regalo" sin lugar no se ofrecen (la
fila dice por qué en vez del botón de video); si el efecto deja de aplicar entre que el jugador
tocó el botón y que terminó el video, o el cambio planeado ya no cabe cuando le toca el turno,
se acreditan **3 minutos de producción** (`compensationSeconds` en `rewarded_ads.json`) con
un aviso. El cooldown sólo se gasta si se miró el video.

**Files:**
- Modify: `FisuEvolution/Managers/Ads/AdsProvider.swift` (`RewardedAdsConfig.compensationSeconds`)
- Modify: `FisuEvolution/Resources/Config/rewarded_ads.json` (`"compensationSeconds": 180`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (`rewardUnavailableReason(_:)`, `isRewardApplicable(_:)`, `applyRewardedReward`, `RewardRow.unavailableReason`, `compensateRewardedVideo()`)
- Modify: `FisuEvolution/Game/State/GameState+BoardChanges.swift` (`discardBoardChange` compensa los de origen video)
- Modify: `FisuEvolution/Game/State/GameState+Achievements.swift` (`coinReward(seconds:player:content:economy:)` de `private static` a `static`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (`TowerNotice.Kind.rewardCompensated(durationText: String)`)
- Modify: `FisuEvolution/App/RootView.swift` (`TowerNoticeView.messageKey`)
- Modify: `FisuEvolution/UI/Gifts/GiftsView.swift` (`VideoCard.rail`)
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (3 claves)
- Create: `FisuEvolutionTests/RewardApplicabilityTests.swift`

**Interfaces:**
- Consumes: el embudo (T9–T12).
- Produces: `GameState.rewardUnavailableReason(_ rewardId: String) -> String?`, `isRewardApplicable(_:) -> Bool`, `RewardRow.unavailableReason: String?`, `compensateRewardedVideo()`.
- Produces: `RewardedAdsConfig.compensationSeconds: Double`; `GameState.coinReward(seconds:player:content:economy:)` interno (E4 la promueve a `RewardMath.coinPayout`).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/RewardApplicabilityTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Videos: sin efecto no se cobra el cooldown")
@MainActor
struct RewardApplicabilityTests {
    @Test("sin pares, la evolución gratis no se ofrece y dice por qué")
    func freeMergeWithoutPairsIsNotOffered() async throws {
        let gameState = await makeGameState()
        #expect(!gameState.isRewardApplicable("accelerate_evolution"))
        let row = try #require(gameState.rewardRows.first { $0.id == "accelerate_evolution" })
        let reason = try #require(row.unavailableReason)
        #expect(!reason.contains("ads.unavailable"), "la clave cruda no puede llegar a pantalla")
        #expect(row.cooldownRemaining == 0)
    }

    @Test("si dejó de aplicar durante el video, compensa los minutos del dato")
    func inapplicableAtTheEndCompensates() async throws {
        let gameState = await makeGameState()
        let base = try #require(gameState.content?.tiers.baseType.id)
        gameState.player?.run.passiveUnlocked[base] = true
        let before = try #require(gameState.player?.run.coins)
        gameState.applyRewardedReward(rewardId: "accelerate_evolution")
        #expect(try #require(gameState.player?.run.coins) > before)
        #expect(gameState.pendingBoardChanges.isEmpty)
        if case .rewardCompensated? = gameState.towerNotice?.kind {} else {
            Issue.record("falta el aviso de la compensación")
        }
        #expect(gameState.rewardCooldownRemaining(id: "accelerate_evolution") > 0, "el video se miró")
    }

    @Test("un cambio de video que ya no cabe en su turno también compensa")
    func staleRewardedChangeCompensates() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantPair()
        gameState.applyRewardedReward(rewardId: "accelerate_evolution")
        let before = try #require(gameState.player?.run.coins)
        let change = try #require(gameState.pendingBoardChanges.first)
        gameState.discardBoardChange(change)
        #expect(try #require(gameState.player?.run.coins) > before)
    }
}
```

(El piso de `coinReward` —el "trabajador solitario" del tier de recompensa— hace que la
compensación nunca sea cero aunque no haya pasivo.)

- [ ] **Step 2: Verlos fallar**

Run: Receta R con `-only-testing:FisuEvolutionTests/RewardApplicabilityTests`.
Expected: no compila (`isRewardApplicable`, `unavailableReason`, `.rewardCompensated`).

- [ ] **Step 3: La implementación**

`+Bonus`:

```swift
    /// Por qué este video no tendría efecto ahora, o `nil` si lo tiene.
    func rewardUnavailableReason(_ rewardId: String) -> String? {
        guard let content, let player, let tower,
              let reward = content.rewardedAds.rewards.first(where: { $0.id == rewardId })
        else { return nil }
        switch reward.effectType {
        case .incomeMultiplier, .skinChest:
            return nil
        case .instantMerge:
            let plan = BoardChangePlanner.planAutoMerge(
                state: player, tower: tower, tiers: content.tiers, floorTable: content.floorTable, origin: .rewardedInstantMerge
            )
            return plan == nil ? String(localized: "ads.unavailable.merge") : nil
        case .rareUnit:
            return rareUnitChange() == nil ? String(localized: "ads.unavailable.floor_full") : nil
        }
    }

    func isRewardApplicable(_ rewardId: String) -> Bool {
        rewardUnavailableReason(rewardId) == nil
    }

    func compensateRewardedVideo() {
        guard let content, let economy, var player else { return }
        let seconds = content.rewardedAds.compensationSeconds
        let amount = Self.coinReward(seconds: seconds, player: player, content: content, economy: economy)
        player.run.coins += amount
        player.meta.lifetimeEarnings += amount
        self.player = player
        towerNotice = TowerNotice(kind: .rewardCompensated(durationText: Self.durationText(seconds)))
        audio?.play(.coin)
        refreshProjections()
        scheduleSave()
    }
```

(`rareUnitChange()` es de T12.) En `applyRewardedReward`, después de marcar el cooldown y
contar el video:

```swift
        guard isRewardApplicable(rewardId) else {
            compensateRewardedVideo()
            return
        }
```

`RewardRow` suma `let unavailableReason: String?` (`rewardRows` lo llena sólo cuando el
cooldown está en cero). `discardBoardChange(_:)` en `+BoardChanges`:

```swift
    func discardBoardChange(_ change: BoardChange) {
        Log.economy.info("board change dropped: \(change.origin.rawValue)")
        switch change.origin {
        case .rewardedInstantMerge, .rewardedRareUnit: compensateRewardedVideo()
        case .eventStartup, .eventBlanqueo, .career, .debug: break
        }
    }
```

`TowerNotice.Kind.rewardCompensated(durationText: String)`; `TowerNoticeView.messageKey`:
`case .rewardCompensated(let durationText): "tower.notice.reward_compensated \(durationText)"`.
`GiftsView.VideoCard.rail`, entre el cooldown y el botón:

```swift
            } else if let reason = row.unavailableReason {
                StateBadge(text: reason, systemImage: "nosign", muted: true)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("ads.unavailable.\(row.id)")
            } else if isWatching {
```

`rewarded_ads.json`: `"compensationSeconds": 180,` en la raíz; `RewardedAdsConfig` suma
`let compensationSeconds: Double`.

Claves nuevas (es / en):

| Clave | es | en |
|---|---|---|
| `ads.unavailable.floor_full` | Piso lleno | Floor full |
| `ads.unavailable.merge` | No hay pares para fusionar | No pairs to merge |
| `tower.notice.reward_compensated %@` | No había dónde aplicarlo: te dimos %@ de producción | Nowhere to apply it: here's %@ of production |

- [ ] **Step 4: Verde y oráculo**

Run: Receta R con `RewardApplicabilityTests`, `BonusCooldownTests`, `BoardChangeProducersTests`
→ PASS; Receta R con `-only-testing:FisuEvolutionUITests/BonusHUDUITests` → PASS (pinea
`ads.watch.<id>` y `ads.cooldown.<id>`). Después `Tools/v2/oraculo.sh completo` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Managers/Ads/AdsProvider.swift FisuEvolution/Resources/Config/rewarded_ads.json \
  FisuEvolution/Game/State/GameState+Bonus.swift FisuEvolution/Game/State/GameState+BoardChanges.swift \
  FisuEvolution/Game/State/GameState+Achievements.swift FisuEvolution/Game/State/GameState.swift \
  FisuEvolution/App/RootView.swift FisuEvolution/UI/Gifts/GiftsView.swift \
  FisuEvolution/Resources/Localizable.xcstrings FisuEvolutionTests/RewardApplicabilityTests.swift
git diff --cached --stat
git commit -m "fix(videos): un video sin efecto no gasta el cooldown y compensa 3 min si deja de aplicar"
```

---

### Task 15: `EffectContractTests` — lo que se muestra es lo que se aplica

**Objetivo:** una suite que recorre **cada caso de cada enum de efecto** con un `switch` sin
`default`: un efecto nuevo sin fila de contrato no compila. Cubre multiplicadores, las dos
derivaciones de las líneas permanentes, premios (vista previa = acreditado, también cruzando
el salto de frontera de la carrera), descuentos compuestos, videos inaplicables, el offline
contra la integral y el efecto de cada evento. La inmunidad no existe todavía: **la fila la
fuerza el compilador** el día que E4 sume `.eventImmunity` a `ActiveModifier.Effect`.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift` (`Effect: CaseIterable`)
- Modify: `FisuEvolution/Managers/ContentConfigs.swift` (`EventsConfig.EffectType: CaseIterable`, `SpecialsConfig.PassiveEffect.Kind: CaseIterable`)
- Modify: `FisuEvolution/Managers/Ads/AdsProvider.swift` (`RewardedAdsConfig.EffectType: CaseIterable`)
- Create: `FisuEvolutionTests/EffectContractTests.swift`

**Interfaces:**
- Consumes: todo lo anterior de la épica.

- [ ] **Step 1: El contrato**

`FisuEvolutionTests/EffectContractTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Lo que el jugador lee —chip, fila, carta, aviso— es exactamente lo que el
/// juego aplica. Cada `for … in allCases` lleva un `switch` SIN `default`: un
/// efecto nuevo sin fila acá no compila. E4: `.eventImmunity` suma su fila.
@Suite("Contrato: lo que se muestra es lo que se aplica")
@MainActor
struct EffectContractTests {
    let content: GameContent
    let economy: StandardEconomy

    init() throws {
        content = try GameContentLoader.load(from: .main)
        economy = StandardEconomy(config: content.economy)
    }

    private var base: CharacterType { content.tiers.baseType }

    private func producing() throws -> (state: PlayerState, tower: TowerState) {
        var state = PlayerState.newGame(
            startTypeId: base.id, startFloorId: content.floorTable[0].id,
            offlineEfficiencyBase: content.economy.offlineEfficiencyBase,
            critChanceBase: 0, now: 0
        )
        state.run.units[base.id] = 3
        state.run.passiveUnlocked[base.id] = true
        state.run.coins = 1e12
        let tower = TowerReconciler.reconcile(run: &state.run, floorTable: content.floorTable, tiers: content.tiers).tower
        return (state, tower)
    }

    private func passive(_ state: PlayerState, now: TimeInterval = 0) -> Double {
        IncomeTicker.passivePerSecond(state: state, tiers: content.tiers, floorTable: content.floorTable,
                                      config: content.economy, now: now)
    }

    private func quote(_ state: PlayerState, now: TimeInterval = 0) throws -> HireQuote {
        try #require(TowerActions.hireQuote(typeId: base.id, state: state, config: content.economy,
                                            floorTable: content.floorTable, tiers: content.tiers, now: now))
    }

    /// El aplicado, escrito con el mismo formateador que lo mostrado.
    private func applied(_ ratio: Double, as unit: EffectUnit) -> String {
        switch unit {
        case .multiplier: EffectFormatter.text(EffectAmount(unit: .multiplier, value: ratio, isCapped: false))
        case .percentDiscount: EffectFormatter.text(EffectAmount(unit: .percentDiscount, value: 1 - ratio, isCapped: false))
        case .percentBonus: EffectFormatter.text(EffectAmount(unit: .percentBonus, value: ratio - 1, isCapped: false))
        case .chance: EffectFormatter.text(EffectAmount(unit: .chance, value: ratio, isCapped: false))
        }
    }

    @Test("cada efecto de modificador aplica el número de su chip")
    func modifierEffects() throws {
        for effect in ActiveModifier.Effect.allCases {
            let magnitude = effect == .spawnCostMultiplier ? 0.7 : 3
            let modifier = ActiveModifier(effect: effect, magnitude: magnitude, expiresAt: 100, sourceKey: "contract")
            let chip = try #require(ActiveBonusBuilder.bonuses(from: [modifier], catalog: [:], now: 0).first).effectText
            var (plain, tower) = try producing()
            var boosted = plain
            boosted.run.activeModifiers = [modifier]
            switch effect {
            case .incomeMultiplier:
                #expect(chip == applied(passive(boosted) / passive(plain), as: .multiplier))
            case .tapMultiplier:
                let tapPlain = economy.applyTap(type: base, state: &plain, floorTable: content.floorTable, now: 0)
                let tapBoosted = economy.applyTap(type: base, state: &boosted, floorTable: content.floorTable, now: 0)
                #expect(chip == applied(tapBoosted / tapPlain, as: .multiplier))
            case .spawnCostMultiplier:
                #expect(chip == applied(try quote(boosted).cost / quote(plain).cost, as: .percentDiscount))
            case .spendingFrozen:
                #expect(chip == String(localized: "bonus.chip.spending_frozen"))
                #expect(passive(boosted) == passive(plain), "congelar el gasto no toca los ingresos")
                #expect(throws: TowerError.spendingFrozen) {
                    try TowerActions.hire(quote: try quote(boosted), state: &boosted, tower: &tower,
                                          floorTable: content.floorTable, config: content.economy, countsAsPurchase: true)
                }
            }
        }
    }

    @Test("cada evento hace lo que su dato declara")
    func eventEffects() throws {
        for event in content.events.events {
            var (state, _) = try producing()
            state.run.raiseFrontier(to: max(event.minTier, 12))
            let single = EventsConfig(schemaVersion: 1, baseIntervalSeconds: 1, intervalJitterSeconds: 0,
                                      resumeGraceSeconds: 60, retryWhenNoneApplicableSeconds: 30, events: [event])
            var rng = SystemRandomNumberGenerator()
            let coinsBefore = state.run.coins
            let unitsBefore = state.run.units
            let roll = try #require(EventManager.fireRandomEvent(
                state: &state, config: single, tiers: content.tiers, floorTable: content.floorTable,
                economy: economy, now: 0, lastFired: [:], isApplicable: { _ in true }, rng: &rng
            ))
            #expect(String(localized: String.LocalizationValue(event.flavorTextKey)) != event.flavorTextKey)
            switch event.effectType {
            case .incomeMultiplier, .spawnCostMultiplier, .spendingFrozen:
                let modifier = try #require(state.run.activeModifiers.first { $0.sourceKey == "event.\(event.id)" })
                #expect(modifier.expiresAt == event.durationSeconds)
                switch event.effectType {
                case .spendingFrozen: #expect(modifier.effect == .spendingFrozen)
                default: #expect(modifier.magnitude == event.magnitude)
                }
            case .bonusCoins:
                var reference = state
                reference.run.activeModifiers = []
                let expected = IncomeTicker.basePassivePerSecond(state: reference, tiers: content.tiers,
                                                                 floorTable: content.floorTable, config: content.economy) * event.magnitude
                #expect(abs(state.run.coins - coinsBefore - expected) < 1e-6 * max(1, expected))
            case .instantEvolution:
                #expect(roll.boardIntent == .evolveBestUnit)
                #expect(state.run.units == unitsBefore, "el evento no muta el tablero: lo planea")
            case .freeHighTier:
                guard case .grantUnit(let typeId) = roll.boardIntent else {
                    Issue.record("el Blanqueo no pidió una llegada")
                    continue
                }
                #expect(content.tiers.type(id: typeId)?.tier == state.run.maxTierReached - Int(event.magnitude))
            }
        }
    }

    @Test("cada video aplica lo que su fila promete, y no cobra si no tiene efecto")
    func rewardedEffects() async throws {
        for effect in RewardedAdsConfig.EffectType.allCases {
            let reward = try #require(content.rewardedAds.rewards.first { $0.effectType == effect })
            let gameState = await makeGameState()
            switch effect {
            case .incomeMultiplier:
                let magnitude = try #require(reward.magnitude)
                gameState.applyRewardedReward(rewardId: reward.id, now: 0)
                let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "rewarded.\(reward.id)" })
                #expect(modifier.magnitude == magnitude)
                #expect(modifier.expiresAt == reward.durationSeconds)
            case .instantMerge, .rareUnit:
                if gameState.isRewardApplicable(reward.id) {
                    gameState.applyRewardedReward(rewardId: reward.id)
                    #expect(!gameState.pendingBoardChanges.isEmpty)
                } else {
                    let row = try #require(gameState.rewardRows.first { $0.id == reward.id })
                    #expect(row.unavailableReason != nil, "inaplicable y ofrecido: el jugador miraría un video por nada")
                }
            case .skinChest:
                let before = try #require(gameState.player?.meta.chestsPending)
                gameState.applyRewardedReward(rewardId: reward.id)
                #expect(gameState.player?.meta.chestsPending == before + 1)
            }
        }
    }

    @Test("cada boost aplica el número de su fila (la Milanesa, el de su JSON)")
    func boostEffects() async throws {
        for effect in BoostsConfig.EffectType.allCases {
            guard let boost = content.boosts.boosts.first(where: { $0.effectType == effect }) else { continue }
            let gameState = await makeGameState()
            gameState.debugUnlockFloors(throughTier: content.tiers.maxTier)
            gameState.player?.meta.stats.maxFloorOrdinalEver = content.floorTable.count - 1
            let row = try #require(gameState.boostRows.first { $0.id == boost.id })
            let shown = EffectFormatter.text(EffectDescriptor.amount(forBoost: effect, magnitude: boost.magnitude))
            #expect(row.effectText.contains(shown))
            let offlineBefore = try #require(gameState.player?.meta.derivedEffects.offlineEfficiency)
            let payout = gameState.activateBoost(id: boost.id)
            switch effect {
            case .incomeMultiplier, .tapMultiplier, .spawnCostMultiplier:
                let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "boost.\(boost.id)" })
                #expect(modifier.magnitude == boost.magnitude)
            case .offlineEfficiencyPermanent:
                let after = try #require(gameState.player?.meta.derivedEffects.offlineEfficiency)
                #expect(abs(after - offlineBefore - boost.magnitude) < 1e-9)
            case .periodicPayout:
                #expect((payout ?? 0) > 0)
            }
        }
    }

    @Test("cada línea permanente: las dos derivaciones y la fila dicen lo mismo")
    func permanentLines() throws {
        let lines = content.upgradesConfig.upgrades
        for effect in UpgradesConfig.EffectType.allCases {
            guard let line = lines.first(where: { $0.effectType == effect }) else { continue }
            var app = try producing().state
            app.meta.oroUpgradeLevels[line.id] = 2
            var kit = app
            UpgradeManager.recomputeDerivedEffects(state: &app, config: content.upgradesConfig, specials: content.specials,
                                                   viral: content.viral, boosts: content.boosts, economy: economy)
            PermanentUpgrades.recomputeDerivedEffects(state: &kit, lines: try PacingTests.permanentLines(from: content.upgradesConfig), economy: economy)
            let shown = EffectDescriptor.amount(for: effect, level: 2, magnitudePerLevel: line.magnitudePerLevel).value
            let (a, k) = (app.meta.derivedEffects, kit.meta.derivedEffects)
            switch effect {
            case .incomeMultiplier:
                #expect(a.incomeMultiplier == k.incomeMultiplier && abs(a.incomeMultiplier - 1 - shown) < 1e-9)
            case .tapMultiplier:
                #expect(a.tapMultiplier == k.tapMultiplier && abs(a.tapMultiplier - 1 - shown) < 1e-9)
            case .critChance:
                #expect(a.critChance == k.critChance && abs(a.critChance - shown) < 1e-9)
            case .goldenTouchChance:
                #expect(a.goldenChance == k.goldenChance && abs(a.goldenChance - shown) < 1e-9)
            case .offlineEfficiency:
                #expect(a.offlineEfficiency == k.offlineEfficiency
                        && abs(a.offlineEfficiency - content.economy.offlineEfficiencyBase - shown) < 1e-9)
            case .spawnCostDiscount:
                #expect(a.spawnDiscount == k.spawnDiscount && abs(a.spawnDiscount - shown) < 1e-9)
            case .prestigeBonusPerSoulPoint:
                #expect(a.prestigeBonus == k.prestigeBonus && abs(a.prestigeBonus - shown) < 1e-9)
            }
        }
    }

    @Test("la carta de cada carrera promete lo que se cobra, aunque el merge suba la frontera")
    func careerPreviewEqualsCredited() async throws {
        let options = try #require(content.tiers.type(id: "junior")?.choiceOptions)
            .compactMap { content.tiers.type(id: $0) }
        for kind in CareersConfig.RewardKind.allCases {
            let career = try #require(content.careers.careers.first { $0.rewardKind == kind })
            let gameState = await makeGameState()
            gameState.player?.run.units = ["administrativo": 2]
            gameState.reconcileTower()
            let floor = content.floorTable.ordinal(forTier: 10)
            gameState.visibleFloorOrdinal = floor
            gameState.player?.run.raiseFrontier(to: 10)
            gameState.markRevealed(tier: 10)
            let pair = gameState.visiblePlacements.map(\.slot).sorted()
            gameState.careerPrompt = GameState.CareerPrompt(
                options: options, floorOrdinal: floor, sourceCell: pair[0], targetCell: pair[1]
            )
            let preview = try #require(gameState.careerRewards[career.id]).previewText
            let coinsBefore = try #require(gameState.player?.run.coins)
            gameState.chooseCareer(optionId: career.id)
            // El salto de frontera al T11 llega DESPUÉS del premio, en el turno del tablero.
            let change = try #require(gameState.beginNextBoardChange())
            gameState.confirmBoardChange(id: change.id)
            #expect(gameState.player?.run.maxTierReached == 11)
            switch kind {
            case .coinChest:
                let credited = try #require(gameState.player?.run.coins) - coinsBefore
                #expect(preview.contains(CoinFormatter.string(from: credited)))
            case .freeBoost:
                // Hoy el Médico regala el Café (`careers.json`): un modificador de tap.
                let boost = try #require(content.boosts.boosts.first { $0.id == career.boostId })
                let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "boost.\(boost.id)" })
                #expect(modifier.magnitude == boost.magnitude)
                #expect(preview.contains(EffectFormatter.text(EffectDescriptor.amount(forBoost: boost.effectType, magnitude: boost.magnitude))))
            case .skin:
                #expect(gameState.player?.meta.milestoneSkins.contains(career.skinId ?? "") == true)
            case .temporaryModifier:
                let modifier = try #require(gameState.player?.run.activeModifiers.first { $0.sourceKey == "career.\(career.id)" })
                let shown = EffectFormatter.text(EffectDescriptor.amount(forBoost: .spawnCostMultiplier, magnitude: modifier.magnitude))
                #expect(preview.contains(shown))
            }
        }
    }

    @Test("con todos los descuentos juntos, FisuJobs cobra lo que muestra")
    func compoundDiscountsChargeWhatTheyShow() async throws {
        let gameState = await makeGameState()
        gameState.debugGrantCoins()
        gameState.player?.run.activeModifiers = [
            ActiveModifier(effect: .spawnCostMultiplier, magnitude: 0.5, expiresAt: .greatestFiniteMagnitude, sourceKey: "career.junior_lawyer"),
            ActiveModifier(effect: .spawnCostMultiplier, magnitude: 0.7, expiresAt: .greatestFiniteMagnitude, sourceKey: "boost.mate"),
        ]
        gameState.player?.meta.prestigeLevel = 3
        gameState.player?.meta.derivedEffects.spawnDiscount = 0.2
        let row = try #require(gameState.jobRows.first { $0.id == base.id })
        let before = try #require(gameState.player?.run.coins)
        gameState.hireCharacter(typeId: base.id)
        let charged = before - (try #require(gameState.player?.run.coins))
        #expect(row.costText == CoinFormatter.cost(from: charged))
    }

    @Test("el offline paga la integral de los buffs, no la foto del momento de volver")
    func offlineMatchesTheIntegral() throws {
        var (state, _) = try producing()
        state.meta.lastSeenTimestamp = 0
        state.run.activeModifiers = [
            ActiveModifier(effect: .incomeMultiplier, magnitude: 3, expiresAt: 600, sourceKey: "a"),
            ActiveModifier(effect: .incomeMultiplier, magnitude: 2, expiresAt: 1500, sourceKey: "b"),
            ActiveModifier(effect: .incomeMultiplier, magnitude: 0.5, expiresAt: 9000, sourceKey: "c"),
        ]
        let credited = OfflineCalculator.earnings(state: state, tiers: content.tiers, floorTable: content.floorTable,
                                                  config: content.economy, now: 3600)
        let buffs = state.run.activeModifiers.filter { $0.magnitude >= 1 }
        let baseRate = IncomeTicker.basePassivePerSecond(state: state, tiers: content.tiers,
                                                         floorTable: content.floorTable, config: content.economy)
        let integral = (0..<3600).reduce(0.0) { total, second in
            total + baseRate * ModifierMath.factor(buffs, effect: .incomeMultiplier, now: Double(second))
        } * state.meta.derivedEffects.offlineEfficiency
        #expect(abs(credited - integral) < 1e-6 * integral)
    }
}
```

Los nombres que usa esta suite están verificados contra el árbol: `PacingTests.permanentLines(from:)`
(`PacingTests.swift:154`, el que ya usa el espejo de `:469`), `gameState.jobRows`
(`GameState+Hiring.swift:110`) y `gameState.boostRows` (`GameState+Bonus.swift:338`). El
`sourceKey` del Abogado es el que arma `grantCareerReward` (`career.<id>`). Si al ejecutar
alguno se movió, se usa el del árbol; no se inventa un helper.

- [ ] **Step 2: Verlo en rojo donde todavía mienta**

Run: Receta R con `-only-testing:FisuEvolutionTests/EffectContractTests`.
Expected: compila sólo después de sumar `CaseIterable` a los cuatro enums; las filas deberían
pasar con T1–T14 cerrados. **Verificar que muerden**: para cada fila, romper a mano lo que
cubre (volver la Milanesa a `0.05`, quitar `isApplicable` del sorteo, volver el Corralito a
ingresos ×0, sacar el `offlineFactor`) y ver que la fila cae; revertir. Una fila que no cae
con su mutación no está cubriendo nada (trampa de los siete tests verdes con la funcionalidad
desenchufada).

- [ ] **Step 3: Verde y oráculo**

Run: Receta R con la suite → PASS; `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 4: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift FisuEvolution/Managers/ContentConfigs.swift \
  FisuEvolution/Managers/Ads/AdsProvider.swift FisuEvolutionTests/EffectContractTests.swift
git diff --cached --stat
git commit -m "test(contrato): lo que se muestra es lo que se aplica"
```

---

### Task 16: Cierre de la épica

**Objetivo:** la verificación de punta a punta de E1 y la documentación que deja a E2a/E3/E7a/E8
arrancando sin leer esta sesión.

- [ ] **Step 1: Oráculo completo, dos veces**

Run: `Tools/v2/oraculo.sh completo --limpio` y, sin tocar nada, `Tools/v2/oraculo.sh completo`.
Expected: `VERDE` las dos; si una corrida suma rojos que la otra no tiene, es la máquina (trampa
43): se corre aislado lo que falló antes de tocar código. `rojos-declarados.txt` queda sólo con
lo que E1 no arregla (`theOwnersTargetsAreMet` → E2b; el arte calado → E8).

- [ ] **Step 2: El pacing no se movió**

Run: el paso `pacing-sim` del oráculo contra la línea de base de `Docs/balance-log.md`. Ningún
cambio de E1 toca el balance (los contadores siguen subiendo de a 1, la Milanesa vale lo mismo,
el offline del simulador no pasa por `OfflineCalculator`): si un número se movió, se busca por
qué antes de cerrar.

- [ ] **Step 3: Los escenarios de PLAN-v2 §8 que son de E1, a mano en el simulador propio**

1. Vuelta en caliente después de 1 h (o el `--uitest-offline` + Home de 2 min con pasivo real)
   → popup con ganancias y ×2 por video.
2. Notificaciones bajadas 10 s → plata acreditada sin popup.
3. Startup comprada (panel de debug) → el tablero navega, la unidad crece a la vista y, si es
   nueva, se revela; con una hoja abierta espera a que se cierre.
4. Carrera: fixture `--uitest-career`, elegir → merge asistido y revelación del T11.
5. Corralito: contratar tiembla con el motivo; la plata sigue subiendo; "Liberar con video".
6. Regalos sin pares → "No hay pares para fusionar" en vez del botón.
7. Save ilegible (`--uitest-unreadable-save`) → recuperación, y la copia en `SaveBackups/`.

- [ ] **Step 4: Documentación (controlador)**

1. `Docs/SESION-<fecha>-v2-e1.md`: la tabla final por tarea con su commit, los números medidos
   y el porqué de cada decisión que no está en el plan.
2. `Docs/HANDOFF.md`:
   - **§4**: entrada "E1 — correcciones críticas y save v6": el embudo `BoardChange` es el
     único camino de los cambios del tablero que no hizo el jugador; save v6 con la tabla de
     campos; offline nuevo; recuperación.
   - **§5**: lo que quedó decidido (umbral del popup en el dato, compensación de 3 min,
     Corralito sobre plata y no sobre ORO, `lastRunMaxTier = 0` para veteranos si el dueño lo
     confirma).
   - **§7**: las trampas nuevas — "re-sellar en `background → inactive` congela el pasivo";
     "la línea de §7 *volver de background no cobra dos veces* era media verdad: entre 2 y
     30 s no cobraba nadie"; "un turno del tablero sin revelar vuelve a pedirse: los tests sin
     escena marcan lo revelado"; las que aparezcan en la ejecución.
   - **§9**: este plan y la sesión.
3. Journal AVO al día y `LOCK` liberado; `handoffs/HANDOFF-<fecha>-v2-e1.md` con lo abierto.

- [ ] **Step 5: Commit de docs**

```bash
git add Docs/SESION-*-v2-e1.md Docs/HANDOFF.md
git diff --cached --stat
git commit -m "docs(v2-e1): cierre de la épica E1 — correcciones críticas y save v6"
```

---

## Para el dueño / dudas

Cosas del código que contradicen o no cierran con el plan maestro. **Ninguna se decidió acá**;
la ejecución sigue con el supuesto anotado hasta que el dueño diga otra cosa.

1. **El buzón de paquetes, el colchón y el visitante: ¿`RunState` o `meta.engagement`?** PLAN-v2
   E1 los lista en `RunState` ("buzón de paquetes, colchón y visitante") y a `wheel`, `events`,
   `shop`, `shopSkins` y `offers` en `MetaState`; "Cimientos compartidos" (E4) pone todo eso en
   `meta.engagement` sin subir el schema. El plan sigue a los cimientos: E1 crea
   `EngagementState` vacío. **Consecuencia a confirmar**: si un paquete o el colchón tienen que
   morir al reencarnar, E5 los resetea a mano en `PrestigeCalculator.applyReincarnation`
   (`PrestigeCalculator.swift:18-35`), porque `meta` no muere con `run = .fresh(...)`.
2. **`lastRunMaxTier` para los veteranos de la v1.** El campo no existe en la v1, así que el
   migrador no sabe dónde terminó la última run. Supuesto: `0` = la primera reencarnación en la
   2.0 no pide piso móvil. PLAN-v2 dice "la primera reencarnación conserva el requisito de hoy";
   no dice si "primera" es la de la cuenta o la de la 2.0.
3. **`Transaction.all` y el iOS mínimo.** Los consumibles finalizados sólo aparecen con iOS 18 y
   `SKIncludeConsumableInAppPurchaseHistory`; el mínimo sube a 18 recién en E3
   (`project.yml:41`, hoy `17.0`). Si E1 se publicara sola, en iOS 17 el ORO comprado de la v1
   daría 0. Como la 2.0 sale entera, no pasa; queda anotado por si el orden cambia.
4. **Los montos del ORO comprado.** La reconstrucción usa los montos que la v1 acreditó
   (250/750/2000, foto en `PurchasedOroHistory`), no los de `products.json`, que E6 reescala a
   160/550/1.400. **E6 no tiene que tocar esa tabla.**
5. **La salida por video del Corralito antes de E4.** El plan pide "escape por video" en E1,
   pero la superficie de los escapes (chip con cara + popup) es de E4, que además borra
   `EventBannerView`. E1 pone un botón mínimo en el banner, sobre la unidad de video `.gifts`
   (la única cercana que existe; E7 la pasa a `rewardedVisitor`). Alternativa: diferir el
   escape a E4 y que en E1 el Corralito sólo congele.
6. **El ORO no se congela.** "No podés gastar" se interpretó como plata (contratar, mejorar
   personajes, pasivos), que es lo que nombra §2. Las siete líneas se pagan con ORO
   (`upgrades.json`) y siguen comprables durante el Corralito.
7. **`debugSetMaxTier` ya no puede bajar la frontera** (`GameState+Debug.swift:164-169` la
   asigna con `min/max`). Con un solo mutador que sólo sube, el panel de debug pierde "bajar el
   tier"; para eso queda resetear la partida.
8. **"Startup comprada" en segundo plano** (PLAN-v2 §8, escenario 2) no puede pasar: los eventos
   sólo disparan desde el flush de la escena (`GameState.swift:886`), y E1 además corre +60 s el
   que venció. El equivalente que sí existe —un cambio pendiente al irse— se asienta en silencio
   al sellar y la red de seguridad lo revela al volver. Propuesta: reescribir ese escenario como
   "un cambio pendiente al irse se revela al volver".
9. **La Startup elige "la mejor unidad que puede crecer", no "la mejor"**: hoy, si la de más
   arriba no puede (su siguiente es el nodo de carrera), el evento no hace nada
   (`ContentSystems.swift:218-224`). Con el sorteo filtrando inaplicables, quedarse en "la mejor
   o nada" lo dejaría casi siempre afuera en la zona de la carrera.
10. **El orden de la Startup y su banner.** El turno del tablero (prioridad 3) pasa antes que el
    banner del evento (prioridad 5), así que la evolución se ve antes de que el banner la
    anuncie. E4 reemplaza el banner por el presentador; mientras tanto se acepta.
11. **CloudKit y lo comprado.** `SaveConflictResolver` no une `creditedPurchases` y toma el
    máximo de `oroPurchasedLifetime`: dos compras en dos dispositivos sin sincronizar se
    contarían una. Está apagado por flag (`cloudKitEnabled`); E9 (`resetEpoch`) es el momento de
    resolverlo.
12. **Las referencias de PLAN-v2 §3 están corridas** en tres lugares (Abogado `:577-583`, carrera
    `:238-286`, contadores `:302-307`) y el predicado de momento calmo se llama
    `isSafeMomentForInterstitial`, no `isCalmMoment`. Nada cambia de fondo; la tabla de
    referencias de arriba tiene las líneas buenas.
