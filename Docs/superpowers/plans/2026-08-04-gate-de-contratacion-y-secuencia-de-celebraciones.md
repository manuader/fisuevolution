# Gate de contratación + secuencia de celebraciones — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Contratar en un piso exige dos pisos desbloqueados por encima (el
callejón queda exento), con aviso al destrabarse; y las celebraciones del ascenso
que abre piso pasan a reproducirse de a una.

**Architecture:** La condición del gate vive en **una** función pura de EconomyKit
que usan el juego y el simulador de pacing. La cadena de celebraciones se encadena
por *completion* dentro de `BoardScene` (que ya es dueña de esas animaciones), y
`GameState` retiene el sheet de skin y el toast hasta que la escena avisa.

**Tech Stack:** Swift 6 (`SWIFT_STRICT_CONCURRENCY: complete`), SpriteKit,
SwiftUI, swift-testing para unit tests, XCTest para UI tests.

**Spec:** `Docs/superpowers/specs/2026-08-04-gate-de-contratacion-y-secuencia-de-celebraciones-design.md`

## Global Constraints

- Cero warnings: `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`. Un warning rompe el build.
- Al agregar o borrar archivos Swift: `/opt/homebrew/bin/xcodegen generate` es
  **obligatorio** (el `.xcodeproj` no se versiona).
- Strings nuevos van a `FisuEvolution/Resources/Localizable.xcstrings`, es (base)
  + en, **en el mismo commit que su vista**.
- Los controles interactivos llevan `accessibilityIdentifier`.
- Commits en español, atómicos por tarea, terminados en
  `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- Nunca `.disabled` para comunicar un estado bloqueado: el dimming del sistema
  baja el texto a ~0.3 y lo vuelve ilegible. Patrón del proyecto: texto ink +
  desaturación leve.
- **No se re-pinean `PacingTests` sin traerle los números al dueño.**

---

### Task 1: `canHire` y el error nuevo en EconomyKit

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift`
- Test: `Packages/EconomyKit/Tests/EconomyKitTests/GameActionsTests.swift` (ahí
  vive el suite `@Suite("Contratación")`; **no existe** un `TowerActionsTests.swift`)

**Interfaces:**
- Consumes: `FloorTable` (`.count`, `subscript(ordinal:)`, `.floors`), `PlayerState`.
- Produces:
  - `TowerActions.canHire(floorOrdinal: Int, unlockedFloors: [String], floorTable: FloorTable) -> Bool`
  - `TowerError.hireLocked`

> ⚠️ **El fixture de la torre tiene sólo DOS pisos** (`f1` {T1-2} / `f2` {T3-4},
> `maxTier` 4). Con dos pisos el gate es invisible: el ordinal 1 siempre cae en
> el escape del tope, así que `hireLocked` es inalcanzable. Este suite arma su
> propia tabla de **cuatro** pisos, que sigue entrando en `maxTier: 4` y por lo
> tanto sirve con `fxTiers()` tal cual está.

- [ ] **Step 1: Escribir los tests que fallan**

Agregar al final de `GameActionsTests.swift`:

```swift
// MARK: - Gate de contratación (dos pisos por encima)

private func gateFloor(_ id: String, _ tier: Int) -> FloorDef {
    FloorDef(
        id: id, background: "alley", firstTier: tier, lastTier: tier,
        capacity: 5, incomeMultiplier: 1.0
    )
}

@Suite("Gate de contratación")
struct HireGateTests {
    let config = fxConfig()
    let economy = fxEconomy()
    let tiers: TierRepository
    let floorTable: FloorTable

    init() throws {
        tiers = try fxTiers()
        // Cuatro pisos de un tier cada uno: el mínimo para que "dos por encima"
        // sea distinguible del escape del tope.
        floorTable = try FloorTable(
            floors: [gateFloor("g1", 1), gateFloor("g2", 2), gateFloor("g3", 3), gateFloor("g4", 4)],
            maxTier: 4
        )
    }

    @Test("el piso de abajo siempre deja contratar, aunque no haya nada arriba")
    func groundFloorIsAlwaysHireable() {
        #expect(TowerActions.canHire(floorOrdinal: 0, unlockedFloors: ["g1"], floorTable: floorTable))
    }

    @Test("un piso necesita DOS pisos desbloqueados por encima")
    func upperFloorNeedsTwoAbove() {
        #expect(!TowerActions.canHire(floorOrdinal: 1, unlockedFloors: ["g1", "g2", "g3"], floorTable: floorTable))
        #expect(TowerActions.canHire(floorOrdinal: 1, unlockedFloors: ["g1", "g2", "g3", "g4"], floorTable: floorTable))
    }

    @Test("los dos pisos del tope se destraban al abrir el último")
    func topOfTowerEscapes() {
        // Sin el último abierto no hay forma: no existen dos pisos por encima.
        #expect(!TowerActions.canHire(floorOrdinal: 3, unlockedFloors: ["g1", "g2", "g3"], floorTable: floorTable))
        #expect(!TowerActions.canHire(floorOrdinal: 2, unlockedFloors: ["g1", "g2", "g3"], floorTable: floorTable))
        let all = ["g1", "g2", "g3", "g4"]
        #expect(TowerActions.canHire(floorOrdinal: 3, unlockedFloors: all, floorTable: floorTable))
        #expect(TowerActions.canHire(floorOrdinal: 2, unlockedFloors: all, floorTable: floorTable))
    }

    @Test("hire rechaza con hireLocked y no cobra ni ocupa slot")
    func hireRejectsWhenGateClosed() throws {
        var state = PlayerState.newGame(
            startTypeId: "a", startFloorId: "g1",
            offlineEfficiencyBase: 0.5, critChanceBase: 0, now: 1000
        )
        state.run.units = ["a": 1]
        state.run.unlockedFloors = ["g1", "g2"]   // g4 cerrado ⇒ el gate de g2 no pasa
        state.run.coins = 1_000_000
        var tower = TowerReconciler.reconcile(run: &state.run, floorTable: floorTable, tiers: tiers).tower
        let coinsBefore = state.run.coins
        let quote = try #require(TowerActions.hireQuote(
            floorOrdinal: 1, state: state, tiers: tiers,
            floorTable: floorTable, config: config, economy: economy
        ))

        #expect(throws: TowerError.hireLocked) {
            try TowerActions.hire(quote: quote, state: &state, tower: &tower, floorTable: floorTable)
        }
        #expect(state.run.coins == coinsBefore, "un hire rechazado no puede cobrar")
        #expect(tower.floors[1].slots.allSatisfy { $0 == nil }, "ni ocupar un slot")
    }
}
```

> Si `TowerReconciler.reconcile` volviera a dejar `unlockedFloors` con más pisos
> de los seteados (sincroniza por unidades y por `unlockTier`), fijar el valor
> **después** del reconcile y antes del `hireQuote`.

- [ ] **Step 2: Correr y verificar que fallan**

```bash
cd Packages/EconomyKit && swift test --filter "Gate de contratación"
```

Esperado: error de compilación, `canHire` y `hireLocked` no existen.

- [ ] **Step 3: Implementar**

En `TowerActions.swift`, agregar el caso al enum (línea ~25):

```swift
    case noHireableType
    /// El piso está abierto, pero todavía no habilita contratar: falta que se
    /// desbloqueen dos pisos por encima. Distinto de `floorLocked` a propósito.
    case hireLocked
```

Y la función, justo antes de `hire`:

```swift
    /// ¿Este piso habilita contratar?
    ///
    /// El backfill sólo tiene sentido cuando tu frontera ya está bastante más
    /// arriba: el precio punitivo lo desalentaba de forma implícita y esto lo
    /// vuelve una regla explícita.
    ///
    /// - El callejón (ordinal 0) SIEMPRE deja contratar: es el motor del early
    ///   game y ya es la excepción de precio.
    /// - Los dos pisos del tope nunca van a tener dos por encima, así que
    ///   desbloquear el último piso de la torre los habilita.
    ///
    /// La usan `hire` y `PacingSimulator`. **No duplicar la condición**: es el
    /// mismo error que el balance-log documenta para la fórmula de costo.
    public static func canHire(
        floorOrdinal: Int,
        unlockedFloors: [String],
        floorTable: FloorTable
    ) -> Bool {
        guard floorOrdinal >= 0, floorOrdinal < floorTable.count else { return false }
        if floorOrdinal == 0 { return true }
        let unlocked = Set(unlockedFloors)
        if let top = floorTable.floors.last, unlocked.contains(top.id) { return true }
        let required = floorOrdinal + 2
        guard required < floorTable.count else { return false }
        return unlocked.contains(floorTable[required].id)
    }
```

En `hire`, después del guard de `floorLocked` (línea ~96):

```swift
        guard state.run.unlockedFloors.contains(floor.id) else { throw TowerError.floorLocked }
        guard canHire(
            floorOrdinal: quote.floorOrdinal,
            unlockedFloors: state.run.unlockedFloors,
            floorTable: floorTable
        ) else { throw TowerError.hireLocked }
```

- [ ] **Step 4: Correr y verificar que pasan**

```bash
cd Packages/EconomyKit && swift test
```

Esperado: todo verde. Si algún test viejo de contratación en pisos superiores se
cae, **es información, no ruido**: significa que asumía el comportamiento sin
gate. Ajustarlo desbloqueando los pisos que ahora hacen falta, no relajando el gate.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit
git commit -m "feat(torre): contratar exige dos pisos desbloqueados por encima"
```

---

### Task 2: `newlyHireableFloors`

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift`
- Test: `Packages/EconomyKit/Tests/EconomyKitTests/GameActionsTests.swift` (mismo
  suite `HireGateTests` de la Task 1, que ya tiene la tabla de cuatro pisos)

**Interfaces:**
- Consumes: `canHire` (Task 1).
- Produces: `TowerActions.newlyHireableFloors(unlockedBefore: [String], unlockedAfter: [String], floorTable: FloorTable) -> [Int]` — ordinales, ascendente.

- [ ] **Step 1: Escribir los tests que fallan**

Dentro de `HireGateTests`:

```swift
    @Test("desbloquear un piso destraba la contratación del que está dos abajo")
    func unlockingAFloorOpensHiringTwoBelow() {
        let before = ["g1", "g2", "g3"]
        #expect(
            TowerActions.newlyHireableFloors(
                unlockedBefore: before, unlockedAfter: before + ["g4"], floorTable: floorTable
            ) == [1, 2, 3],
            "g4 es además el tope, así que destraba g2 por la regla y g3/g4 por el escape"
        )
    }

    @Test("un unlock que no destraba a nadie devuelve vacío")
    func unlockingNothingNewReturnsEmpty() {
        #expect(
            TowerActions.newlyHireableFloors(
                unlockedBefore: ["g1"], unlockedAfter: ["g1", "g2"], floorTable: floorTable
            ).isEmpty,
            "abrir g2 no le da dos pisos por encima a nadie"
        )
    }
```

> Con cuatro pisos, abrir el último dispara la regla general **y** el escape a la
> vez, por eso devuelve tres ordinales. Con los once pisos reales el caso normal
> devuelve uno solo; ese caso lo cubre el test de wiring de la Task 5, que corre
> contra la torre de verdad.

- [ ] **Step 2: Correr y verificar que fallan**

```bash
cd Packages/EconomyKit && swift test --filter newlyHireable
```

Esperado: `newlyHireableFloors` no existe.

- [ ] **Step 3: Implementar**

```swift
    /// Pisos que pasan de NO contratables a contratables por un desbloqueo.
    ///
    /// En el caso normal es uno solo (el que está dos abajo del que se abrió);
    /// al abrir el último piso son dos, porque el escape del tope habilita a los
    /// dos de arriba juntos.
    public static func newlyHireableFloors(
        unlockedBefore: [String],
        unlockedAfter: [String],
        floorTable: FloorTable
    ) -> [Int] {
        (0..<floorTable.count).filter { ordinal in
            !canHire(floorOrdinal: ordinal, unlockedFloors: unlockedBefore, floorTable: floorTable)
                && canHire(floorOrdinal: ordinal, unlockedFloors: unlockedAfter, floorTable: floorTable)
        }
    }
```

- [ ] **Step 4: Correr y verificar que pasan**

```bash
cd Packages/EconomyKit && swift test
```

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit
git commit -m "feat(torre): calcular qué pisos destraba un desbloqueo"
```

---

### Task 3: El simulador de pacing respeta el gate

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift:235`

**Interfaces:**
- Consumes: `TowerActions.canHire` (Task 1).

- [ ] **Step 1: Aplicar el gate en el barrido de backfill**

Reemplazar el `for` de la línea ~235:

```swift
        // 4. Backfill: hire en pisos superiores desbloqueados SOLO si es rentable
        //    (precio punitivo) y si el gate los habilita — la misma condición que
        //    usa el juego, no una copia.
        for ordinal in 1..<floorTable.count
        where state.run.unlockedFloors.contains(floorTable[ordinal].id)
            && TowerActions.canHire(
                floorOrdinal: ordinal,
                unlockedFloors: state.run.unlockedFloors,
                floorTable: floorTable
            ) {
            if let hire = hireAction(floorOrdinal: ordinal, state: state, requireProfit: true, passiveRate: passiveRate) {
                candidates.append(hire)
            }
        }
```

- [ ] **Step 2: Correr el simulador y anotar los números**

```bash
swift run --package-path Tools/pacing-sim pacing-sim \
  --economy FisuEvolution/Resources/Data/economy.json \
  --tiers FisuEvolution/Resources/Data/tiers.json
```

Anotar los cuatro hitos: fase fisura, gradiente, primera reencarnación, dios +
cantidad de reencarnaciones.

- [ ] **Step 3: Correr `PacingTests`**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD \
  -only-testing:FisuEvolutionTests/PacingTests test
```

- [ ] **Step 4: PARAR si se cayeron**

Si `PacingTests` falla, **no re-pinear**. Traerle al dueño la tabla
antes/después con los cuatro hitos y esperar su decisión: los targets están
pineados a la conducta real por decisión suya (`balance-log §F7.6`).

Si pasa, seguir.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit
git commit -m "fix(pacing): el simulador respeta el gate de contratación"
```

---

### Task 4: La proyección y el botón

**Files:**
- Modify: `FisuEvolution/Game/State/GameState.swift` (declaración de proyecciones ~línea 140, `refreshProjections` ~línea 1276)
- Modify: `FisuEvolution/UI/HUD/SpawnButtonView.swift`
- Modify: `FisuEvolution/Resources/Localizable.xcstrings`
- Test: `FisuEvolutionTests/GameLoopWiringTests.swift`

**Interfaces:**
- Consumes: `TowerActions.canHire` (Task 1).
- Produces: `GameState.visibleFloorAllowsHiring: Bool`.

- [ ] **Step 1: Escribir el test que falla**

En `GameLoopWiringTests.swift`, siguiendo el patrón de los tests de torre que ya
están ahí (usan los helpers DEBUG para desbloquear pisos):

```swift
@Test("el piso visible no habilita contratar hasta tener dos pisos arriba")
func visibleFloorGatesHiringUntilTwoFloorsAbove() async {
    let state = await makeReadyGameState()          // helper existente del archivo
    await MainActor.run {
        state.debugUnlockFloors(throughTier: 5)     // abre hasta urban (ordinal 1)
        state.setVisibleFloorForTests(ordinal: 1)   // usar el mecanismo del archivo
        state.flushHUD()
        #expect(state.visibleFloorAllowsHiring == false)

        state.debugUnlockFloors(throughTier: 13)    // abre hasta luxury (ordinal 3)
        state.flushHUD()
        #expect(state.visibleFloorAllowsHiring == true)
    }
}
```

> Ajustar los nombres de helpers a los que el archivo ya usa. **No agregar
> helpers DEBUG nuevos si ya existe uno equivalente.**

- [ ] **Step 2: Correr y verificar que falla**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD \
  -only-testing:FisuEvolutionTests/GameLoopWiringTests test
```

Esperado: no compila, `visibleFloorAllowsHiring` no existe.

- [ ] **Step 3: Agregar la proyección**

Junto a las otras (~línea 140):

```swift
    private(set) var visibleFloorIsUnlocked = false
    /// El piso está abierto pero todavía no habilita contratar (faltan dos pisos
    /// por encima). El callejón nunca entra acá.
    private(set) var visibleFloorAllowsHiring = false
```

En `refreshProjections`, junto a las otras dos:

```swift
        let floorUnlocked = visibleFloorDef.map { player.run.unlockedFloors.contains($0.id) } ?? false
        let allowsHiring = content.map {
            TowerActions.canHire(
                floorOrdinal: visibleFloorOrdinal,
                unlockedFloors: player.run.unlockedFloors,
                floorTable: $0.floorTable
            )
        } ?? false
        if visibleFloorIsFull != floorFull { visibleFloorIsFull = floorFull }
        if visibleFloorIsUnlocked != floorUnlocked { visibleFloorIsUnlocked = floorUnlocked }
        if visibleFloorAllowsHiring != allowsHiring { visibleFloorAllowsHiring = allowsHiring }
        let affordable = (quote.map { player.run.coins >= $0.cost } ?? false)
            && !floorFull && floorUnlocked && allowsHiring
```

- [ ] **Step 4: Agregar el estado al botón**

En `SpawnButtonView.buttonTitle`, entre el caso de bloqueado y el normal:

```swift
            if gameState.visibleFloorIsFull {
                Text("spawn.button.full")
            } else if !gameState.visibleFloorIsUnlocked {
                Text("spawn.button.locked")
            } else if !gameState.visibleFloorAllowsHiring {
                Text("spawn.button.hire_locked")
            } else {
                Text("spawn.button.title \(quote.type.displayName)")
            }
```

Y el mismo orden en el detalle del `body`:

```swift
                    } else if !gameState.visibleFloorAllowsHiring {
                        Text("spawn.button.hire_locked.detail")
                            .font(.subheadline.weight(.semibold))
                    } else {
```

- [ ] **Step 5: Agregar las claves es/en**

En `Localizable.xcstrings`, con el mismo formato que `spawn.button.locked`:

| clave | es | en |
|---|---|---|
| `spawn.button.hire_locked` | Todavía no | Not yet |
| `spawn.button.hire_locked.detail` | Abrí dos pisos más arriba | Open two floors above |

- [ ] **Step 6: Correr y verificar que pasa**

```bash
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD \
  -only-testing:FisuEvolutionTests/GameLoopWiringTests test
```

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution FisuEvolutionTests
git commit -m "feat(hud): el botón de contratar muestra el gate de dos pisos"
```

---

### Task 5: Retener el sheet de skin y el toast

**Files:**
- Modify: `FisuEvolution/Game/State/GameState.swift`
- Modify: `FisuEvolution/App/RootView.swift` (`TowerNoticeView.messageKey`, el `.sheet` de `skinAward`)
- Modify: `FisuEvolution/Resources/Localizable.xcstrings`
- Test: `FisuEvolutionTests/GameLoopWiringTests.swift`

**Interfaces:**
- Consumes: `TowerActions.newlyHireableFloors` (Task 2).
- Produces:
  - `GameState.celebrationsDidFinish()`
  - `GameState.skinAwardDismissed()`
  - `GameState.TowerNotice.Kind.hireUnlocked(floorID: String)`

- [ ] **Step 1: Escribir los tests que fallan**

**No inventar helpers DEBUG nuevos**: el camino real ya está cubierto por
`tier2MergePromotesToUrbanAndUnlocksIt`, que hoy asserta el award **inmediatamente
después del merge** (`GameLoopWiringTests.swift:163-164`). Ese test **se va a caer
con este cambio y ése es el punto**: es el lugar natural para fijar la conducta
nueva. Reemplazar esas dos líneas por:

```swift
        // El sheet ya no aparece en el instante del merge: taparía el vuelo, el
        // reveal y la celebración del piso. Espera a que la escena termine.
        #expect(gameState.skinAward == nil, "el sheet no puede tapar la cadena")
        gameState.celebrationsDidFinish()
        #expect(gameState.skinAward?.id == "urban_trailblazer")
        #expect(gameState.skinAward?.characterType.id == "cartonero")
```

Y agregar el test del toast, que necesita llegar a **luxury** (ordinal 3): recién
ahí urban (ordinal 1) junta dos pisos por encima. Con los helpers DEBUG que el
archivo ya usa:

```swift
    @Test("el toast de contratación espera a la cadena y al sheet")
    func hireUnlockedNoticeWaitsItsTurn() async throws {
        let gameState = await makeGameState()
        // Tier 9 vive en corporate; mergear un par promueve a T10 = luxury, y
        // luxury es el que le da a urban sus dos pisos por encima.
        gameState.debugSetMaxTier(9)
        gameState.debugGrantPair()
        let pair = slots(of: gameState.visiblePlacements.first?.typeId ?? "", in: gameState)
        #expect(pair.count >= 2)

        _ = gameState.handleDrop(fromCell: pair[0], toCell: pair[1])
        #expect(gameState.player?.run.unlockedFloors.contains("luxury") == true)
        #expect(gameState.towerNotice == nil, "el toast no sale durante la cadena")

        gameState.celebrationsDidFinish()
        gameState.skinAwardDismissed()   // no-op si no hubo skin que otorgar
        #expect(gameState.towerNotice?.kind == .hireUnlocked(floorID: "urban"))
    }
```

> Ajustar `slots(of:in:)` al helper exacto del archivo. Si `debugGrantPair` deja
> el par en un piso que no es el visible, usar el mismo mecanismo que
> `tier2MergePromotesToUrbanAndUnlocksIt` para ubicarlos.

- [ ] **Step 2: Correr y verificar que fallan**

Mismo comando de Task 4 Step 2. Esperado: `tier2MergePromotesToUrbanAndUnlocksIt`
falla (el award ya no llega diferido porque todavía no implementamos nada, así que
falla el `#expect(skinAward == nil)`) y el test del toast no compila.

- [ ] **Step 3: Implementar la retención**

Agregar el caso al enum de `TowerNotice.Kind` (~línea 87):

```swift
        enum Kind: Equatable {
            case floorFull
            case destinationFloorFull(floorID: String)
            /// Un piso que antes no dejaba contratar ahora sí.
            case hireUnlocked(floorID: String)
        }
```

Estado nuevo, junto a las otras propiedades no observadas:

```swift
    /// Un merge que abre piso dispara una cadena de celebraciones en la escena.
    /// Mientras corre, las superficies de SwiftUI esperan su turno: si el sheet
    /// de skin apareciera en el instante del merge, taparía el vuelo, el reveal
    /// y la celebración del piso —los tres a la vez, que es el bug que esto
    /// arregla—.
    @ObservationIgnored private var celebrationChainActive = false
    @ObservationIgnored private var pendingSkinAward: SkinAward?
    @ObservationIgnored private var pendingHireUnlockedFloorID: String?
```

En `awardEligibleMilestoneSkins`, reemplazar la asignación directa:

```swift
        if let first = newlyUnlocked.sorted().first,
           let entry = content.skins.entry(id: first),
           let type = content.tiers.type(id: entry.characterType) {
            let award = SkinAward(id: first, characterType: type)
            if celebrationChainActive {
                pendingSkinAward = award
            } else {
                skinAward = award
            }
        }
```

Los métodos nuevos:

```swift
    /// La escena terminó de reproducir la cadena del ascenso. Recién ahora
    /// SwiftUI puede poner su parte arriba.
    func celebrationsDidFinish() {
        celebrationChainActive = false
        if let award = pendingSkinAward {
            pendingSkinAward = nil
            skinAward = award
            return  // el toast espera a que el jugador cierre el sheet
        }
        flushPendingHireNotice()
    }

    /// El sheet de skin se cerró (por botón o por gesto).
    func skinAwardDismissed() {
        flushPendingHireNotice()
    }

    private func flushPendingHireNotice() {
        guard let floorID = pendingHireUnlockedFloorID else { return }
        pendingHireUnlockedFloorID = nil
        towerNotice = TowerNotice(kind: .hireUnlocked(floorID: floorID))
    }
```

- [ ] **Step 4: Encolar desde el merge**

En `handleDrop`, en la rama `.promoted`. Capturar `unlockedFloors` **antes** de
`applyMerge` (el `applyMerge` lo muta) y comparar después:

```swift
        let unlockedBefore = player.run.unlockedFloors
```

y después de `self.player = player`, antes de `updateMaxFloorStat()`:

```swift
                // El sheet de skin y el toast tienen que esperar a que la escena
                // termine su cadena; marcarlo ANTES de updateMaxFloorStat(), que
                // es quien acredita la skin de milestone.
                if case .promoted = result {
                    celebrationChainActive = true
                    let newlyHireable = TowerActions.newlyHireableFloors(
                        unlockedBefore: unlockedBefore,
                        unlockedAfter: player.run.unlockedFloors,
                        floorTable: content.floorTable
                    )
                    // El más bajo: es el que el jugador va a querer rellenar.
                    if let ordinal = newlyHireable.first {
                        pendingHireUnlockedFloorID = content.floorTable[ordinal].id
                    }
                }
```

- [ ] **Step 5: Cablear la vista**

En `RootView`, el `.sheet` de `skinAward` pasa a avisar al cerrarse:

```swift
        .sheet(item: Binding(
            get: { tutorialDone ? gameState.skinAward : nil },
            set: { gameState.skinAward = $0 }
        ), onDismiss: { gameState.skinAwardDismissed() }) { award in
            SkinAwardView(award: award)
        }
```

Y `TowerNoticeView.messageKey` suma el caso:

```swift
        case .hireUnlocked: "tower.notice.hire_unlocked"
```

- [ ] **Step 6: Agregar la clave es/en**

| clave | es | en |
|---|---|---|
| `tower.notice.hire_unlocked` | ¡Ya podés contratar en los pisos de abajo! | You can hire on the floors below now! |

> El texto es genérico a propósito: `LocalizedStringKey` con interpolación
> dinámica ya rompió una vez en este proyecto (F7.2, la clave salía cruda en
> pantalla). Si se quiere nombrar el piso, se hace con el mapeo exhaustivo de
> claves estáticas de `TowerNaming`, no interpolando el id.

- [ ] **Step 7: Correr y verificar que pasan**

```bash
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD \
  -only-testing:FisuEvolutionTests/GameLoopWiringTests test
```

- [ ] **Step 8: Commit**

```bash
git add FisuEvolution FisuEvolutionTests
git commit -m "feat(torre): avisar cuando un piso habilita contratar"
```

---

### Task 6: Encadenar las animaciones de la escena

**Files:**
- Modify: `FisuEvolution/Scenes/BoardScene.swift` (`touchesEnded` rama `.merged`,
  `runAscentAnimation`, `runEvolutionReveal`, `runFloorUnlockCelebration`)

**Interfaces:**
- Consumes: `GameState.celebrationsDidFinish()` (Task 5).

- [ ] **Step 1: Dar completion a las tres animaciones**

Cambiar las tres firmas para aceptar un closure y llamarlo al terminar su
secuencia. Patrón, aplicado a cada una:

```swift
    private func runFloorUnlockCelebration(
        floorID: String,
        destinationOrdinal: Int,
        completion: @escaping () -> Void
    ) {
```

y en la acción MÁS LARGA de cada método (la que define su duración real — en
`runFloorUnlockCelebration` es la secuencia del `title`), cerrar con:

```swift
        title.run(.sequence([
            titleEntrance,
            .wait(forDuration: 0.9),
            .fadeOut(withDuration: 0.22),
            .removeFromParent(),
        ]), completion: completion)
```

**Ojo**: no poner el completion en dos acciones distintas del mismo método o se
llamaría dos veces y la cadena saltearía un paso.

- [ ] **Step 2: Encadenar en el sitio del merge**

Reemplazar el bloque de la rama `.merged` de `touchesEnded` (hoy dispara los tres
en paralelo) por la cadena. El pop del merge queda INMEDIATO: es la respuesta al
gesto y demorarla haría sentir el juego trabado.

```swift
            particles.emit(.merge, at: feedbackPoint, in: fieldNode)
            if let mergedNode {
                mergedNode.run(.sequence([
                    .scale(to: 1.25, duration: 0.1),
                    .scale(to: 1.0, duration: 0.12),
                ]))
            }

            // Cadena: vuelo → reveal del personaje → piso nuevo → avisar a
            // GameState, que recién ahí suelta el sheet de skin y el toast.
            // Antes los tres arrancaban juntos y no se apreciaba ninguno.
            let finish: () -> Void = { [weak self] in
                self?.gameState.celebrationsDidFinish()
            }
            let celebrateFloor: () -> Void = { [weak self] in
                guard let self, let unlockedFloorID, let promotedToFloor else { finish(); return }
                self.runFloorUnlockCelebration(
                    floorID: unlockedFloorID,
                    destinationOrdinal: promotedToFloor,
                    completion: finish
                )
            }
            let revealEvolution: () -> Void = { [weak self] in
                guard let self, let evolvedTo else { celebrateFloor(); return }
                self.gameState.playHaptic(.evolution)
                self.runEvolutionReveal(for: evolvedTo, at: mergedNode?.position, completion: celebrateFloor)
            }
            if let promotedType, let promotionStart {
                runAscentAnimation(type: promotedType, from: promotionStart, completion: revealEvolution)
            } else {
                if evolvedTo == nil { gameState.playHaptic(.merge) }
                revealEvolution()
            }
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD build
```

Esperado: BUILD SUCCEEDED, cero warnings.

- [ ] **Step 4: Ajustar la espera del smoke**

`FisuEvolutionUITests/AscentRenderingUITests.swift`: el
`Thread.sleep(forTimeInterval: 3.0)` tras el segundo merge se queda corto ahora
que la cadena es secuencial (0,7 + ~2 + ~1,3 ≈ 4 s antes del sheet). Subirlo a
`6.0` con el comentario de por qué.

- [ ] **Step 5: Verificar en simulador con capturas**

Correr el smoke y exportar los attachments:

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD \
  -resultBundlePath /tmp/cadena.xcresult \
  -only-testing:FisuEvolutionUITests/AscentRenderingUITests test
xcrun xcresulttool export attachments --path /tmp/cadena.xcresult --output-path /tmp/cadena-shots
```

Mirar las capturas: la del ascenso NO debe tener el sheet de skin encima. Ése es
el veredicto del cambio y no se puede sacar del exit code — el smoke tolera que
el sheet no esté.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution FisuEvolutionUITests
git commit -m "fix(escena): las celebraciones del ascenso se reproducen de a una"
```

---

### Task 7: Verificación final

- [ ] **Step 1: Las cuatro suites**

```bash
cd Packages/EconomyKit && swift test
cd - && /opt/homebrew/bin/xcodegen generate
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD test
cd Tools/asset-pipeline && .venv/bin/python -m unittest discover -s tests -q
```

Punto de partida: EconomyKit 134, app 82, UI 10, pipeline 20. Las tareas suman
tests, así que los dos primeros números tienen que SUBIR.

- [ ] **Step 2: Recorrido manual en el simulador**

Instalar, `--uitest-reset`, y con los helpers DEBUG: pararse en urban con sólo
corporate abierto → el botón dice "Todavía no". Abrir luxury → aparece el toast y
el botón se habilita. Capturas de los dos estados a `scratchpad/qa-shots/`.

- [ ] **Step 3: Actualizar la bitácora**

Agregar a `Docs/SESION-2026-08-03-f7-torre.md` (o una bitácora nueva del día) qué
se hizo, con los números de pacing de la Task 3.

- [ ] **Step 4: Commit**

```bash
git add Docs scratchpad/qa-shots
git commit -m "docs: bitácora del gate de contratación y la secuencia de celebraciones"
```
