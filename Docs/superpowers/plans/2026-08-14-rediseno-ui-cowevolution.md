# Rediseño de UI estilo Cow Evolution — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el rediseño completo especificado en
`Docs/superpowers/specs/2026-08-14-rediseno-ui-cowevolution-design.md`
(leerlo ANTES de cualquier tarea: este plan lo referencia como "el spec").

**Architecture:** Se mantiene la arquitectura de 3 capas (EconomyKit puro →
GameState con proyecciones → SwiftUI/SpriteKit). El rediseño agrega una
cotización por tipo en EconomyKit, contadores persistidos con decoders
manuales, un catálogo de logros data-driven, y reemplaza HUD + navegación +
6 pantallas conservando los identifiers pineados por tests.

**Tech Stack:** SwiftUI + SpriteKit, Swift 6 strict concurrency, swift-testing
(unit) / XCTest (UI), XcodeGen, StoreKit 2.

## Global Constraints (aplican a TODAS las tareas)

- **Ejecución SECUENCIAL, un subagente por tarea, mismo working tree.** NO
  paralelizar tareas: comparten `RootView.swift`, `GameArt.swift` y
  `Localizable.xcstrings`. Commitear apenas la tarea esté verde.
- Leer `Docs/HANDOFF.md` §2, §3 y §7 antes de tocar nada. Trampas que van a
  aparecer sí o sí: 5 (claves interpoladas), 9a/9a-bis (árbol de AX), 15
  (xcodegen con Xcode abierto).
- Al **agregar o borrar** un archivo Swift: `/opt/homebrew/bin/xcodegen generate`
  (el `.xcodeproj` no se versiona). Cerrar Xcode antes.
- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` — cero warnings.
- Strings nuevos a `FisuEvolution/Resources/Localizable.xcstrings` (**es base
  + en**) en el MISMO commit que su vista, editados A MANO (nunca con
  scripts). Claves armadas por id → `String(localized: String.LocalizationValue(key))`
  en una función del estado; `Int` interpolado en `%@` → `String(x)`.
- `accessibilityIdentifier` en todo control interactivo; NUNCA en
  contenedores (VStack/HStack pelados); capas decorativas
  `.allowsHitTesting(false)`.
- SwiftUI nunca lee `PlayerState`: proyecciones publicadas (patrón
  `refreshProjections`, escribir sólo si cambió) o computadas re-evaluadas
  contra `effectsVersion`/`coinsText`/`boardVersion`. Nada de tiempo restante
  en proyecciones (timer 1 Hz en la vista).
- Comandos de verificación por tarea:
  - `cd Packages/EconomyKit && swift test` (hoy: 150 verdes)
  - `xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'id=<UDID propio>' -derivedDataPath build/DD test -only-testing:FisuEvolutionTests -parallel-testing-enabled NO` para iterar; la corrida con UI agrega `-skip-testing:FisuEvolutionUITests/AscentRenderingUITests`.
  - Crear simulador propio: `xcrun simctl create "frente-ui" "iPhone 16 Pro"`
    y **apagarlo/borrarlo al terminar** (`shutdown` + `delete`).
- Commits atómicos en español (`tipo(ámbito): mensaje`), footer
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Rojos preexistentes que NO son tuyos: `AscentRenderingUITests` (saltear),
  pipeline 1 rojo por Chrome ausente. Flakies sensibles a carga:
  `EconomyLoopUITests`, `StoreManagerTests.refundRevokesEntitlement` —
  correr aislados antes de culpar al código.
- Paleta y componentes: usar SIEMPRE `GameArt.swift` (+ los componentes de la
  Tarea 4). Colores por `Color("PaletteX")`. Tipografía `.rounded`.

---

## FASE 1 — Fundaciones

### Task 1: Decoders manuales y campos nuevos del save (EconomyKit)

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/SaveConflictResolver.swift`
- Test: `Packages/EconomyKit/Tests/EconomyKitTests/SaveCompatibilityTests.swift` (nuevo)

**Interfaces (Produces):**
- `RunState.hireCountsByType: [String: Int]` (default `[:]`, muere al reencarnar)
- `MetaStats` con: `maxFloorOrdinalEver`, `totalMergesEver`, `totalHiresEver`,
  `totalTapsEver`, `videosWatchedEver`, `boostsActivatedEver` (todos `Int`,
  default 0)
- `MetaState.unlockedAchievements: Set<String>`, `MetaState.claimedAchievements: Set<String>` (default `[]`)
- Todo decodifica desde JSON v4 SIN las claves nuevas (decoders manuales).

- [ ] **Step 1: Test rojo — un save v4 real sin claves nuevas decodifica**

En `SaveCompatibilityTests.swift`, armar por `JSONSerialization` un dict v4
mínimo (copiar la forma del fixture de `FisuEvolutionTests/SaveMigratorTests.swift:157-215`,
pero como JSON literal en el test del paquete) que NO tenga `seenTypes`,
`hireCountsByType`, ni los campos nuevos de stats/achievements, y:

```swift
@Test func v4SinClavesNuevasDecodifica() throws {
    let data = try JSONSerialization.data(withJSONObject: fixtureV4SinClavesNuevas)
    let state = try JSONDecoder().decode(PlayerState.self, from: data)
    #expect(state.run.seenTypes.isEmpty)
    #expect(state.run.hireCountsByType.isEmpty)
    #expect(state.meta.stats.totalMergesEver == 0)
    #expect(state.meta.unlockedAchievements.isEmpty)
}
@Test func roundTripConservaLosCamposNuevos() throws { /* encode→decode con valores puestos */ }
```

⚠️ Este test HOY falla incluso sin campos nuevos (el default de `seenTypes`
no protege el decode sintetizado — bug latente documentado en el spec §13.1).
Verificar que falla por `keyNotFound`.

- [ ] **Step 2: `RunState.init(from:)` manual**

`decode` para los campos que todo v4 tiene (coins, units, passiveUnlocked,
chosenCareerPath vía decodeIfPresent porque puede faltar, hireCounts,
maxTierReached, charUpgradeLevels, unlockedFloors, activeModifiers);
`decodeIfPresent ?? default` para `seenTypes` y `hireCountsByType`. Declarar
`hireCountsByType: [String: Int] = [:]` y agregarlo a `RunState.fresh` como
`[:]` y al init memberwise si existe.

- [ ] **Step 3: `MetaStats` — campos + `init(from:)` manual**

```swift
public struct MetaStats: Codable, Equatable, Sendable {
    public var maxFloorOrdinalEver: Int
    public var totalMergesEver: Int
    public var totalHiresEver: Int
    public var totalTapsEver: Int
    public var videosWatchedEver: Int
    public var boostsActivatedEver: Int
    public init(maxFloorOrdinalEver: Int = 0, totalMergesEver: Int = 0,
                totalHiresEver: Int = 0, totalTapsEver: Int = 0,
                videosWatchedEver: Int = 0, boostsActivatedEver: Int = 0) { ... }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        maxFloorOrdinalEver = try c.decodeIfPresent(Int.self, forKey: .maxFloorOrdinalEver) ?? 0
        totalMergesEver = try c.decodeIfPresent(Int.self, forKey: .totalMergesEver) ?? 0
        // ... resto igual, ?? 0
    }
}
```

- [ ] **Step 4: `MetaState` — achievements en el decoder manual existente**

Agregar las dos propiedades con default `[]`, y en el `init(from:)` existente
(PlayerState.swift:235-257) dos líneas `decodeIfPresent(Set<String>.self, ...) ?? []`.
Sumarlas al init memberwise.

- [ ] **Step 5: `SaveConflictResolver` — reglas de merge**

En `resolve` (SaveConflictResolver.swift:11-35), tras elegir ganador:

```swift
resolved.meta.stats.totalMergesEver = max(a.meta.stats.totalMergesEver, b.meta.stats.totalMergesEver)
// ídem los otros 4 contadores y maxFloorOrdinalEver (ya se recalcula al cargar, pero max es gratis)
resolved.meta.unlockedAchievements = a.meta.unlockedAchievements.union(b.meta.unlockedAchievements)
resolved.meta.claimedAchievements = a.meta.claimedAchievements.union(b.meta.claimedAchievements)
```

Test en el mismo archivo: dos estados con contadores cruzados → gana el max /
la unión.

- [ ] **Step 6: `swift test` verde (los 150 + nuevos) y commit**

```bash
git add Packages/EconomyKit && git commit -m "fix(economia): decoders manuales del save y campos de stats/logros"
```

---

### Task 2: Contadores en los choke points (EconomyKit + GameState)

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift` (applyMerge :236-295, hire :187-209)
- Modify: `FisuEvolution/Game/State/GameState+Actions.swift` (registerTap), `GameState+Bonus.swift` (applyRewardedReward :36, activateBoost :146)
- Test: `Packages/EconomyKit/Tests/EconomyKitTests/StatsCountersTests.swift` (nuevo), `FisuEvolutionTests/StatsCountersAppTests.swift` (nuevo)

**Interfaces:**
- Consumes: campos de Task 1.
- Produces: los contadores se incrementan en: `applyMerge` → `totalMergesEver`;
  `hire` → `totalHiresEver` + `run.hireCountsByType[typeId]`; `registerTap` →
  `totalTapsEver`; `applyRewardedReward` → `videosWatchedEver`;
  `activateBoost` (sólo si activó) → `boostsActivatedEver`.

- [ ] **Step 1: Tests rojos en EconomyKit** — merge por los 3 caminos suma 1
  (usar los fixtures existentes de `GameActionsTests`), hire suma
  `totalHiresEver` y `hireCountsByType`; un merge que lanza
  `destinationFloorFull` NO cuenta (incrementar DESPUÉS de los guards, junto a
  `run.maxTierReached` en TowerActions.swift:270 y a `hireCounts` en :204).
- [ ] **Step 2: Implementar los dos incrementos en TowerActions.** El
  auto-merge del reconciliador NO cuenta (no tocar TowerReconciler).
- [ ] **Step 3: Tests rojos en app** (`makeGameState()` de
  `FisuEvolutionTests/Support/GameStateFixture.swift`): `registerTap()` suma
  taps; `applyRewardedReward` suma video aunque el efecto no caiga; boost
  bloqueado NO suma.
- [ ] **Step 4: Implementar los 3 incrementos de capa app** (una línea cada
  uno, junto al código existente citado arriba).
- [ ] **Step 5: `swift test` + `-only-testing:FisuEvolutionTests` verdes; commit**
  `feat(stats): contadores históricos en los choke points`

---

### Task 3: Cotización por tipo + tierPremium + pacing (EconomyKit)

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` (HireConfig :16-24, hireCost :125-130)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/TowerActions.swift`
- Modify: `FisuEvolution/Resources/Data/economy.json` (bloque `hire`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` (:228-290)
- Modify: `FisuEvolutionTests/GameContentValidationTests.swift` (pins :113-114)
- Test: `Packages/EconomyKit/Tests/EconomyKitTests/TypeHireQuoteTests.swift` (nuevo)

**Interfaces (Produces):**
```swift
// EconomyConfig.HireConfig
public let tierPremium: Double   // decodeIfPresent ?? 1.8; economy.json: "tierPremium": 1.8

// EconomyConfig
public func hireCost(floor: FloorDef, tier: Int, purchases: Int) -> Double
// = hireCostMultiplier(floor) × tapYield(tier) × floor.incomeMultiplier
//   × pow(hire.tierPremium, Double(tier − floor.firstTier))
//   × pow(hireCostGrowth(floor), Double(purchases))
// (la firma vieja hireCost(floor:tapYield:purchases:) delega en ésta con tier = firstTier)

// TowerActions
public static func hireQuote(typeId: String, state: PlayerState, config: EconomyConfig,
                             floorTable: FloorTable, tiers: TierRepository,
                             costMultiplier: Double, now: TimeInterval) -> HireQuote?
// nil si el typeId no existe o es choice node. purchases = run.hireCountsByType[typeId] ?? 0.
// Aplica los mismos 3 descuentos que hireQuote(floorOrdinal:) (TowerActions.swift:64-72).
// El HireQuote resultante entra al hire(quote:...) EXISTENTE sin cambios de firma.
```

- [ ] **Step 1: Tests rojos** — pins de la curva:
  - tier base de cada piso = precio idéntico al de `hireQuote(floorOrdinal:)`
    hoy (premium 1): primer Fisura 50, segundo 60.
  - tier no-base: costo(tier+1, 0 compras) > 2 × costo(tier, 0 compras)
    (regla anti-atajo del spec §5.2) para TODO piso con más de un tier.
  - growth por TIPO: dos compras del mismo tipo escalan 1.2; comprar otro tipo
    del mismo piso NO escala el primero.
  - choice node (`junior`) → nil; typeId inexistente → nil.
- [ ] **Step 2: Implementar** `tierPremium` (decodeIfPresent ?? 1.8 en el
  `init(from:)` de HireConfig — ojo que HireConfig hoy decodifica
  sintetizado: darle CodingKeys + init manual), `hireCost(floor:tier:purchases:)`
  y `hireQuote(typeId:)`. Agregar `"tierPremium": 1.8` a economy.json.
- [ ] **Step 3: `hire()` existente**: verificar que los guards usan
  `quote.floorOrdinal`/`quote.type` (ya lo hacen) — no tocar su firma.
- [ ] **Step 4: Pin nuevo en GameContentValidationTests**: `hire.tierPremium == 1.8`.
- [ ] **Step 5: PacingSimulator**: migrar la compra a
  `hireQuote(typeId: baseType(of: floor).id, ...)` manteniendo la política
  (base del piso 0 siempre; backfill si cost ≤ coins×0.25). La conducta no
  debe moverse: correr `swift run pacing-sim` (Tools/pacing-sim) ANTES y
  DESPUÉS y pegar las dos salidas en `Docs/balance-log.md` con fecha, más el
  porqué de tierPremium=1.8 (2.8×1.8 ≈ 5× por tier ⇒ mergear siempre gana).
- [ ] **Step 6: `swift test` + suite de app verdes; commit**
  `feat(economia): cotización de contratación por tipo con tierPremium`

---

### Task 4: Design system v2 (componentes + iconos vectoriales)

**Files:**
- Create: `FisuEvolution/UI/Art/GameArtComponents.swift`, `FisuEvolution/UI/Art/GameIcons.swift`
- Modify: `FisuEvolution/UI/Art/GameArt.swift` (sólo si hay que exponer helpers)
- Test: `FisuEvolutionTests/GameArtComponentsTests.swift` (nuevo)

**Interfaces (Produces):** (las consumen TODAS las pantallas de F2/F3)
```swift
enum Tokens { // tipografía y espaciado
    static let display = Font.system(.title, design: .rounded).weight(.black)
    static let title   = Font.system(.title3, design: .rounded).weight(.heavy)
    static let body    = Font.system(.subheadline, design: .rounded).weight(.bold)
    static let caption = Font.system(.caption, design: .rounded).weight(.semibold)
    static let s4: CGFloat = 4; static let s8: CGFloat = 8; static let s12: CGFloat = 12
    static let s16: CGFloat = 16; static let s24: CGFloat = 24
}
struct GameCard<Content: View>: View { // crema, radio 14, stroke ink 2, sombra
    enum Style { case normal, highlighted(Color), locked }
    init(style: Style = .normal, @ViewBuilder content: () -> Content)
}
struct SectionHeader: View { init(_ titleKey: LocalizedStringKey) } // usa ui_header_ribbon 9-slice o cinta vectorial
struct ProgressBar: View { init(progress: Double, tint: Color, labelText: String? = nil) }
struct PricePill: View { // cinta de precio estilo cow evolution
    enum Currency { case coins, oro }
    init(text: String, currency: Currency, affordable: Bool, identifier: String, action: @escaping () -> Void)
}
struct CountBadge: View { init(count: Int, dimmed: Bool) } // "xN"
struct IconButton: View { init(artKey: String?, fallback: @escaping () -> AnyView, size: CGFloat = 52, tint: Color, labelKey: String, identifier: String, action: @escaping () -> Void) }
struct GameIcon: View { init(artKey: String, size: CGFloat = 30, @ViewBuilder vector: () -> some View) } // UIArt.image(artKey) ?? vector
struct GameTabBar: View { init(items: [GameTabItem], selection: @escaping (GameScreen) -> Void) }
struct GameTabItem: Identifiable { let screen: GameScreen; let icon: AnyView; let labelKey: String; let identifier: String; let prominent: Bool }
enum GameScreen: String, Identifiable, CaseIterable { case jobs, upgrades, skins, gifts, store, menu; var id: String { rawValue } }
```
En `GameIcons.swift`, los 16 iconos vectoriales del spec §12.1 como Views
(`VectorTabJobsIcon` usa `UIArt.image("homeless_face")`, `VectorElevatorIcon`,
`VectorCoinPlusIcon`, `VectorTabUpgradesIcon`, `VectorTabSkinsIcon`,
`VectorTabGiftsIcon`, `VectorTabShopIcon`, `VectorTabMenuIcon`,
`VectorOrgchartIcon`, `VectorStatsIcon`, `VectorTrophyIcon(tier:)`,
`VectorSettingsIcon`, `VectorCalendarIcon`) — flat, outline `PaletteInk` 2pt,
fills de paleta, dibujados con formas SwiftUI (Circle/Capsule/Path). Calidad
alta: cada uno con 2-4 formas compuestas, no un SF Symbol pelado.

- [ ] **Step 1:** Escribir los componentes + iconos (sin tests aún es
  aceptable arrancar por la implementación acá: son Views).
- [ ] **Step 2:** Tests unitarios de lo testeable: `GameScreen` casos y
  orden; `PricePill` — snapshot lógico vía inspección de que el init no
  crashea con montos astronómicos formateados (`CoinFormatter`).
- [ ] **Step 3:** `xcodegen generate` (archivos nuevos) + build verde +
  commit `feat(arte): design system v2 — tarjetas, tab bar, iconos vectoriales`

---

## FASE 2 — Cáscara

### Task 5: Proyección de FisuJobs y acción de contratar (GameState)

**Files:**
- Create: `FisuEvolution/Game/State/GameState+Hiring.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` (comentario en spawnQuote/hireOffer: sin consumidor de UI)
- Test: `FisuEvolutionTests/JobRowsTests.swift` (nuevo)

**Interfaces (Produces):**
```swift
struct JobRow: Identifiable, Equatable {
    enum State: Equatable { case hirable, floorFull, gated(aboveFloorNameKey: String), lockedFloor(floorNameKey: String), unseen }
    let id: String            // typeId
    let displayName: String   // resuelto (tiers displayName ya viene resuelto del JSON)
    let faceKey: String       // "<typeId>_face"
    let incomeText: String    // "X /s" formateado con CoinFormatter
    let hiredCount: Int       // run.units[typeId] ?? 0  (visible en la tarjeta)
    let purchases: Int        // run.hireCountsByType[typeId] ?? 0
    let costText: String
    let affordable: Bool
    let state: State
    let tier: Int
    let floorID: String
}
extension GameState {
    var jobRows: [JobRow] { get }        // computada; re-evaluar contra coinsText+boardVersion+effectsVersion
    func hireCharacter(typeId: String)   // cotiza por tipo, TowerActions.hire, ftueSpawned, haptics .purchase, audio .buy, bumpBoard, scheduleSave; floorFull → TowerNotice(.floorFull)
}
```
Orden de `jobRows`: contratables por tier DESC, después gated/locked por tier
ASC, `unseen` al final como "???" (displayName "???", costText ""). Un tipo es
`hirable` si su piso ∈ `unlockedFloors` ∧ `canHire(su piso)` ∧ hay slot; los
textos de gated/locked usan `TowerNaming.floorNameKey` → `String`.

- [ ] **Step 1: Tests rojos** (fixture `makeGameState()` + `--uitest`-style
  debug helpers): partida nueva → fisura `hirable` con costText "50" y el
  resto unseen; con `debugUnlockFloors(throughTier: 5)` + coins → tipos de
  urban hirable, corporate gated; piso lleno → floorFull; `hireCharacter`
  crea la unidad, marca ftue.spawned, incrementa hireCountsByType.
- [ ] **Step 2: Implementar** `GameState+Hiring.swift` usando
  `TowerActions.hireQuote(typeId:...)` (Task 3) y `content.tiers.concreteTypes`.
- [ ] **Step 3:** `xcodegen generate`, suites verdes, commit
  `feat(contratacion): jobRows y hireCharacter para fisujobs`

---

### Task 6: HUD superior nuevo

**Files:**
- Modify: `FisuEvolution/UI/HUD/HUDView.swift` (reescritura del cuerpo)
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (claves nuevas + fix de la clave del pill)
- Test: `FisuEvolutionUITests/HUDRedesignUITests.swift` (nuevo)

**Interfaces:**
- Consumes: `coinsText`, `towerIncomePerSecondText`, `towerNavigation`,
  `prestigePreview`; closures existentes de HUDView (RootView las cablea).
- Produces: layout del spec §3. Identifiers: conserva `hud.coins`, `hud.map`,
  `tower.pill`, `tower.arrow.up/down`, `hud.prestige.multiplier`; nuevos
  `hud.coins.plus` (abre tienda vía `onStoreTap`), `hud.income` (estado).
  Anclas `.coins`, `.map`, `.hudBar` conservadas.

- [ ] **Step 1:** Reescribir `HUDView`: barra contigua (HStack dentro de una
  cápsula ancha crema borde ink): `IconButton` moneda+ (izq) · columna
  central `coinsText` grande + `hud.income` chico · `IconButton` ascensor
  (der, `GameIcon("ui_elevator")`, conserva `showFloorMap` y `onMapOpen`).
  Debajo, fila compacta de torre (flechas + pill SOLO nombre + `occ/cap` —
  armar el texto con `String(_:)` sobre los Int y borrar la clave muerta
  `%@/%@ · %@/%@ · %@/s` del catálogo). Debajo, chip de prestigio (igual
  semántica que hoy, HUDView.swift:145-176).
- [ ] **Step 2:** Strings nuevos (`hud.coins.plus.label`, `hud.income.label`,
  es+en) a mano en Xcode.
- [ ] **Step 3:** UI test nuevo: `hud.coins.plus` existe y abre la tienda
  (aparece `sheet.close`), `hud.income` tiene value no vacío, `tower.pill`
  sigue existiendo. Captura ANTES de asserts.
- [ ] **Step 4:** Corridas: unit + UI (skip Ascent). Commit
  `feat(hud): barra superior contigua estilo cow evolution`

---

### Task 7: Barra inferior, navegación y tutorial

**Files:**
- Modify: `FisuEvolution/App/RootView.swift` (bottomBar :246-269, sheets :175-236, @State :80-85)
- Delete: `FisuEvolution/UI/HUD/SpawnButtonView.swift`
- Modify: `FisuEvolution/Scenes/BoardScene.swift` (`bottomInset` :128 → alto real de la barra, medir ~96)
- Modify: `FisuEvolution/UI/Tutorial/TutorialOverlay.swift` (steps :67-89), `TutorialAnchor.swift` (el caso `.hire` se ancla al tab)
- Modify: `FisuEvolutionUITests/EconomyLoopUITests.swift`, `FisuEvolutionUITests/TutorialUITests.swift`, `FisuEvolutionUITests/BoardGestureUITests.swift` (si usan `hud.spawn`)
- Test: `FisuEvolutionUITests/BottomMenuUITests.swift` (nuevo)

**Interfaces:**
- Consumes: `GameTabBar`/`GameScreen` (Task 4), `hireCharacter` (Task 5).
- Produces: `@State activeScreen: GameScreen?` + UN `.sheet(item: $activeScreen)`
  que switchea a las 6 vistas (mientras las pantallas nuevas no existen,
  jobs → placeholder mínimo con `jobRows` en List cruda que se reemplaza en
  Task 8; skins/menu → `Text` placeholder que se reemplazan en F3 — los
  placeholders llevan ya sus identifiers de tab). Ids de tabs según spec §4:
  `hud.hire`, `hud.upgrades`, `hud.skins`, `hud.bonus`, `hud.store`,
  `hud.settings`. Los `@State showX` viejos mueren; los popups `item:` quedan.

- [ ] **Step 1:** `BottomMenuBar` montado en `bottomBar` (conserva
  `.tutorialAnchor(.bottomBar)`); tab 1 y 6 prominentes (56pt vs 48pt).
  Botón de prestigio flotante sobre el tablero (conserva `hud.prestige`).
- [ ] **Step 2:** Borrar `SpawnButtonView.swift` (+ `xcodegen generate`).
  Quitar sus strings huérfanos SÓLO si ninguna otra vista los usa.
- [ ] **Step 3:** `bottomInset` al alto real; correr
  `-only-testing:FisuEvolutionTests/CrowdDepthTests` y `CrowdBandTests`.
- [ ] **Step 4:** Tutorial: paso "contratá" spotlightea el tab `hud.hire`
  (ancla `.hire` en el tab); avanza con `ftueMilestones.spawned` (ya
  publicado) cuando el jugador contrata en la hoja y la cierra. Pasos de
  mejoras/mapa re-apuntados (el copy nuevo a xcstrings es+en).
- [ ] **Step 5:** Reescribir `EconomyLoopUITests` (tap → coins suben; abre
  `hud.hire`, toca `jobs.hire.homeless` — el placeholder de Task 7 ya lo
  expone —, `board.units` sube) y `TutorialUITests` (ids nuevos).
- [ ] **Step 6:** UI test nuevo: los 6 tabs existen y cada uno abre una hoja
  con `sheet.close`. Suites + commit
  `feat(navegacion): barra inferior de 6 pantallas y tutorial re-apuntado`

---

## FASE 3 — Pantallas (secuencial, una tarea por pantalla)

### Task 8: FisuJobsView

**Files:**
- Create: `FisuEvolution/UI/Jobs/FisuJobsView.swift`
- Modify: `FisuEvolution/App/RootView.swift` (reemplaza el placeholder del case .jobs)
- Modify: `Localizable.xcstrings` (`jobs.*`)
- Test: `FisuEvolutionUITests/FisuJobsUITests.swift` (nuevo)

**Interfaces:** Consumes `jobRows`/`hireCharacter` (Task 5), `GameCard`/`PricePill` (Task 4).

- [ ] **Step 1:** Vista: NavigationStack + `PanelBackground(art: "panel_store")`
  + `PanelTitleBanner(titleKey: "jobs.title")` + `ArtCloseButton`. Header
  parodia (logo "FisuJobs" con `Tokens.display` + subtítulo `jobs.subtitle`).
  ScrollView de `GameCard` por `jobRow` (retrato `UIArt.image(faceKey)` 72pt,
  nombre, `incomeText`, `jobs.hired_count` con `String(hiredCount)`, tag del
  piso); `PricePill(identifier: "jobs.hire.\(row.id)")` — comentario del
  porqué del id interpolado, patrón StoreView.swift:206-209. Estados gated/
  locked/unseen según spec §5.1 (unseen: silueta `.silhouette` — reusar el
  tratamiento de silueta de `CharacterSheetView`/tinta plena — y "???").
  Fila entera `jobs.row.<typeId>` como elemento de estado con value del
  estado. Botones sin `.disabled` (patrón SpawnButtonView viejo: saturación).
- [ ] **Step 2:** Strings `jobs.title/subtitle/hired_count/full/gated %@/locked %@/unseen` es+en.
- [ ] **Step 3:** UI test: con `--uitest-coins --uitest-skip-tutorial`, abrir
  `hud.hire`, contratar `jobs.hire.homeless`, asertar que `board.units` sube
  y que el costText de la fila cambió (growth). Captura antes de asserts;
  scroll para List perezosa.
- [ ] **Step 4:** Suites + commit `feat(fisujobs): tienda de contratación por personaje`

### Task 9: Upgrades v2 (restyle)

**Files:**
- Modify: `FisuEvolution/UI/Store/UpgradesView.swift`
- Test: los existentes (`UpgradesMenuUITests`, `UpgradesFaceUITests`) deben seguir verdes sin tocarlos (los ids no cambian).

- [ ] **Step 1:** Restyle con `GameCard`/`SectionHeader`/`ProgressBar`/`PricePill`
  manteniendo TODOS los identifiers (`upgrades.tab.*`,
  `upgrades.character.<id>.*`, `upgrades.permanent.<id>`) y las proyecciones.
  Retrato 88pt a la izquierda, efecto `X → Y` en acento, `Level N/M` como
  `ProgressBar(labelText:)` (los Int con `String(_:)`). Header de la pestaña
  ORO con `OroIcon` + `oroText`. Fix VoiceOver: la carita
  `.accessibilityHidden(true)` (spec §6).
- [ ] **Step 2:** Correr `UpgradesMenuUITests` + `UpgradesFaceUITests`
  aislados. Commit `feat(mejoras): restyle high-end de la pantalla de upgrades`

### Task 10: ElevatorView (restyle del mapa)

**Files:**
- Modify: `FisuEvolution/UI/Popups/FloorMapView.swift` (o rename a `ElevatorView.swift` con typealias NO — mantener el nombre de archivo para no romper nada, cambiar sólo el título visual)
- Modify: `Localizable.xcstrings` (`elevator.title` es+en)
- Test: `FloorMapUITests` existentes deben pasar sin cambios.

- [ ] **Step 1:** Restyle: panel de ascensor (columna de botones de piso como
  `GameCard` con miniatura + nombre + `occ/cap` + candado; piso actual con
  marco `PaletteYellow`). Ids `map.floor.<id>` y lógica idénticos; título
  `elevator.title`.
- [ ] **Step 2:** `FloorMapUITests` aislado verde. Commit
  `feat(torre): el mapa de pisos es un ascensor`

### Task 11: Customization Shop

**Files:**
- Create: `FisuEvolution/UI/Skins/CustomizationView.swift`
- Modify: `FisuEvolution/Game/State/GameState+Store.swift` (agregar `skinCatalogRows(forCharacterType:)`)
- Modify: `FisuEvolution/App/RootView.swift` (case .skins)
- Modify: `Localizable.xcstrings` (`skins.*`)
- Test: `FisuEvolutionTests/SkinCatalogRowsTests.swift`, `FisuEvolutionUITests/CustomizationUITests.swift` (nuevos)

**Interfaces (Produces):**
```swift
struct SkinCatalogRow: Identifiable, Equatable {
    enum State: Equatable { case equipped, owned, milestoneLocked(conditionText: String), purchasable(productID: String) }
    let id: String; let displayName: String; let textureKey: String?; let state: State
}
func skinCatalogRows(forCharacterType typeId: String) -> [SkinCatalogRow]
// base primero (id "base"), después las del catálogo; conditionText resuelto en el estado
// (floorReached → "skins.unlock.floor %@" con TowerNaming.floorName; reincarnations → "skins.unlock.prestige %@" con String(n))
```

- [ ] **Step 1: Tests rojos** de `skinCatalogRows`: tipo con skin de piso
  bloqueada → milestoneLocked con texto resuelto (no clave cruda — assert
  `!text.contains("skins.unlock")`); mundialista sin comprar → purchasable
  con el productID correcto; equipada → equipped.
- [ ] **Step 2:** Implementar sobre `skinOptions`/`ownsSkin`/`activeSkinID` +
  `store.skinId(for:)` inverso vía `ProductCatalog`.
- [ ] **Step 3:** Vista: selector horizontal de caras arriba
  (`skins.character.<typeId>`, sólo `characterUpgradeTypes`; unseen no
  aparecen), grilla 2 columnas de tarjetas de skin (preview
  `UIArt.characterImage`, silueta para locked), botones
  `skins.equip.<skinId>` / `store.buy.<productId>` (compra vía
  `StoreManager.purchase`). Filas `skins.row.<skinId>` con value del estado.
- [ ] **Step 4:** UI test smoke: abrir `hud.skins`, elegir personaje, equipar
  una skin poseída (fixture `--uitest-seen-types` + `grantMilestoneSkinsForTests`
  — cablear un arg nuevo `--uitest-skins` en GameState+Debug si hace falta).
- [ ] **Step 5:** Suites + commit `feat(skins): customization shop`

### Task 12: Tienda IAP v2 + fix Loading

**Files:**
- Modify: `FisuEvolution/Managers/Store/StoreManager.swift` (loadProducts :54-67)
- Modify: `FisuEvolution/UI/Store/StoreView.swift`
- Test: `FisuEvolutionTests/StoreTimeoutTests.swift` (nuevo); `StoreUITests`/`StoreManagerTests`/`StoreProductsTests` existentes verdes.

- [ ] **Step 1: Test rojo del timeout**: inyectar el fetch (cerrar
  `Product.products(for:)` detrás de `var productsFetcher: ([String]) async throws -> [Product]`
  o un protocolo) y un fetcher que nunca vuelve → `loadState == .failed`
  después del timeout (usar un timeout parametrizado corto en el test).
- [ ] **Step 2:** Implementar: carrera `withThrowingTaskGroup` entre fetch y
  `Task.sleep(for: .seconds(10))` → el sleep gana ⇒ `.failed` con
  `store.error.load`. La rama `.loading` de la vista muestra `store.retry`
  pasados 10 s (estado local de la vista con su timer).
- [ ] **Step 3:** Restyle de StoreView (spec §8): starter pack como tarjeta
  destacada ancha, remove-ads banner, packs como filas `GameCard` con
  `packRewardText`, skins con preview. **Eliminar la Section de settings**
  (:56-66). Ids conservados (`store.buy.<id>`, `store.restore`, `store.retry`,
  `store.unavailable`). Precios SIEMPRE `product.displayPrice`.
- [ ] **Step 4:** `StoreManagerTests` + `StoreProductsTests` + `StoreUITests`
  (ajustar `scrollUntilVisible` si el layout dejó de ser List). Commit
  `feat(tienda): restyle + timeout del loading`

### Task 13: GiftsView (regalos v2)

**Files:**
- Create: `FisuEvolution/UI/Gifts/GiftsView.swift` (reemplaza BonusView en el case .gifts; borrar `BonusView.swift`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (agregar `dailyCalendar` y `rewardText` en RewardRow)
- Modify: `Localizable.xcstrings` (`gifts.*`)
- Test: `FisuEvolutionTests/DailyCalendarTests.swift` (nuevo); `BonusHUDUITests` ajustado.

**Interfaces (Produces):**
```swift
struct DailyDayRow: Identifiable, Equatable { let id: Int /* 1...7 */; let titleKey: String; let isToday: Bool; let isClaimed: Bool; let isChest: Bool }
var dailyCalendar: [DailyDayRow] { get }  // computada de meta.daily.cycleDay + content.dailyRewards
// RewardRow gana: let rewardText: String  // "×2 por 2 min", resuelto en el estado
```

- [ ] **Step 1: Tests rojos** de `dailyCalendar` (cycleDay 3 → días 1-2
  claimed, 3 today, 7 chest) y de `rewardText` (no clave cruda).
- [ ] **Step 2:** Implementar proyecciones. El claim del daily NO se toca
  (sigue automático).
- [ ] **Step 3:** Vista: sección Daily (calendario horizontal,
  `gifts.daily.day<i>` estado), sección Boosts (filas actuales de `boostRows`
  con ids conservados `bonus.activate/cooldown/locked.<id>`, textos vía
  `displayNameKey(buildVariant:)`), sección Videos (`ads.watch/cooldown.<id>`
  + `rewardText`). Timer 1 Hz único. Borrar `BonusView.swift` + xcodegen.
- [ ] **Step 4:** `BonusHUDUITests` verde (ids conservados; ajustar sólo la
  apertura si cambia el scroll). Commit `feat(regalos): gifts view con calendario diario`

### Task 14: Logros — catálogo, motor y persistencia

**Files:**
- Create: `FisuEvolution/Resources/Config/achievements.json`
- Modify: `FisuEvolution/Managers/ContentConfigs.swift` (AchievementsConfig), `GameContentLoader.swift` (campo + decode + validate)
- Create: `FisuEvolution/Game/State/GameState+Achievements.swift` (engine + proyección + claim)
- Modify: `GameState.swift` (`updateMaxFloorStat` llama a `evaluateAchievements()`), `GameState+Actions.swift`/`+Bonus.swift`/`+Prestige.swift` (hooks tras hire/video/boost/share/prestige/tap-milestones — un solo método `evaluateAchievements()` barato)
- Modify: `FisuEvolution/App/RootView.swift` (banner de logro: reusar el patrón `TowerNoticeView` con id `ach.toast`)
- Modify: `Localizable.xcstrings` (72 claves `ach.*` — título+desc por logro, es+en)
- Test: `FisuEvolutionTests/AchievementEngineTests.swift` (nuevo)

**Interfaces (Produces):**
```swift
struct AchievementsConfig: Codable, Sendable { let schemaVersion: Int; let achievements: [Achievement]
    struct Achievement: Codable, Sendable, Identifiable {
        let id: String; let titleKey: String; let descKey: String; let icon: String
        let trigger: Trigger; let reward: Reward }
    struct Trigger: Codable, Sendable { let type: String; let value: Double?; let floorId: String? }
    struct Reward: Codable, Sendable { let kind: String; let factor: Double?; let amount: Int?; let boostId: String? } }
struct AchievementRow: Identifiable, Equatable {
    enum State: Equatable { case locked, unlocked, claimed }
    let id: String; let titleText: String; let descText: String; let icon: String
    let state: State; let progress: Double; let rewardText: String }
extension GameState {
    var achievementRows: [AchievementRow] { get }   // computada
    func evaluateAchievements()                      // desbloquea + toast + audio .reward + scheduleSave
    func claimAchievement(id: String)                // acredita reward, claimed, scheduleSave
}
```
Trigger types (switch exhaustivo): `floorUnlocked` (floorId ∈ unlockedFloors ∨
maxFloorOrdinalEver ≥ ordinal), `tierReached` (run.maxTierReached — histórico
via max con meta si hace falta: usar run, los logros ya desbloqueados no se
re-lockean), `totalMerges/totalHires/totalTaps` (meta.stats),
`prestigeLevel`, `skinsOwned`/`skinsAll` (allOwnedSkins), `specialsOwned`,
`videosWatched`, `boostsActivated`, `lifetimeEarnings`, `seenAllTypes`
(seenTypes ⊇ concreteTypes), `dailyDay7` (meta.daily.cycleDay == 7),
`sharesCompleted`. Rewards: `coins` → `passiveUnlockCost(maxTierReached) × factor`
a run.coins+lifetime; `oro` → meta.oro += amount (NO oroEarnedLifetime);
`freeBoost` → mecanismo del premio del Médico (GameState+Bonus.swift:448-465).
El catálogo son los **36 logros del spec §10.3** con estos valores de
recompensa: pisos coins factor 4/6/8/10/12/16/20/26, god_realm oro 40;
merges coins 2/12/40, merges_10000 oro 60; hires coins 4/16, hires_1000 oro 30;
carrera coins 10, T24 coins 30, T37 oro 100; prestigio coins 20, oro 25/80;
skins coins 10/oro 20/oro 120; specials coins 6/oro 25; videos coins 4/16;
boosts coins 4/16; taps coins 2/20; riqueza coins 6/oro 20/oro 60;
seen_all oro 40; daily_7 coins 12; share coins 6.

- [ ] **Step 1: Tests rojos del engine**: cada trigger type con un estado
  armado que lo cruza; idempotencia (evaluar 2 veces no duplica); claim
  acredita y no se puede re-claimar; reward coins escala con maxTierReached;
  validación del loader rechaza floorId inexistente y trigger desconocido.
- [ ] **Step 2:** `achievements.json` completo (36 entradas) + mirror +
  `GameContent.achievements` + decode + `validate` (ids únicos, triggers del
  set conocido, floorIds existentes, rewards bien formadas, titleKey/descKey
  no vacíos). ⚠️ El JSON nuevo entra al bundle por carpeta (Resources/Config)
  — no requiere xcodegen, pero `GameState+Achievements.swift` sí.
- [ ] **Step 3:** Engine + hooks + toast. `evaluateAchievements()` compara
  contra `meta.unlockedAchievements` (barato: sólo los locked).
- [ ] **Step 4:** Las 72 claves `ach.*` es+en (a mano, con humor argentino en
  es: p.ej. "Primer laburo" / "First gig").
- [ ] **Step 5:** Suites + commit `feat(logros): catálogo data-driven, motor y recompensas`

### Task 15: MenuView + AchievementsView + StatsView + OrgChartView

**Files:**
- Create: `FisuEvolution/UI/Menu/MenuView.swift`, `AchievementsView.swift`, `StatsView.swift`, `OrgChartView.swift`
- Create: `FisuEvolution/Game/State/GameState+Stats.swift` (statsSnapshot + orgChartRows)
- Modify: `FisuEvolution/App/RootView.swift` (case .menu)
- Modify: `Localizable.xcstrings` (`menu.*`, `stats.*`, `orgchart.*`)
- Test: `FisuEvolutionTests/StatsSnapshotTests.swift`, `FisuEvolutionUITests/MenuUITests.swift` (nuevos)

**Interfaces (Produces):**
```swift
struct StatsSnapshot: Equatable {  // todo String ya formateado (CoinFormatter/String(_:))
    let lifetimeEarnings: String; let oro: String; let oroLifetime: String
    let prestigeLevel: String; let maxFloorName: String; let maxTier: String
    let unitCount: String; let seenTypes: String /* "12/43" */; let skins: String /* "5/45" */
    let specials: String; let shares: String; let floorsUnlocked: String
    let totalMerges: String; let totalHires: String; let totalTaps: String
    let videosWatched: String; let boostsActivated: String; let incomePerSecond: String }
var statsSnapshot: StatsSnapshot { get }   // computada
struct OrgChartRow: Identifiable, Equatable {
    let id: String; let displayName: String; let faceKey: String
    let count: Int; let tier: Int; let floorID: String; let seen: Bool }
var orgChartRows: [OrgChartRow] { get }    // tiers DESC (jefe arriba); unseen → displayName "???"
```

- [ ] **Step 1: Tests rojos** de `statsSnapshot` (valores formateados, sin
  claves crudas) y `orgChartRows` (orden DESC, count de units, seen).
- [ ] **Step 2:** Implementar `GameState+Stats.swift`.
- [ ] **Step 3:** `MenuView`: grilla 2×2 de tarjetas grandes
  (`menu.card.orgchart/stats/achievements/settings`) con `GameIcon` vectorial
  + push de NavigationStack a las 4 sub-vistas (el sheet del menú ya es
  NavigationStack).
- [ ] **Step 4:** `OrgChartView`: tarjeta "El Jefe" arriba (multiplicador
  global + nivel de prestigio del `prestigePreview`), después secciones por
  piso con nodos `orgchart.node.<typeId>` (retrato + `CountBadge` xN, gris
  con x0, silueta "???" si !seen) y conectores (Rectangle ink 2pt entre
  filas).
- [ ] **Step 5:** `StatsView`: grupos de `GameCard` con filas
  `stats.row.<key>` (elemento de estado con value).
- [ ] **Step 6:** `AchievementsView`: lista de `achievementRows` —
  `ach.row.<id>` con value locked/unlocked/claimed, `ProgressBar` de
  progreso, botón `ach.claim.<id>` en los unlocked, trofeo
  `VectorTrophyIcon` según icon.
- [ ] **Step 7:** UI test: abrir `hud.settings` → 4 tarjetas; entrar a
  logros con fixture y reclamar uno (`--uitest-achievements` nuevo en
  GameState+Debug: siembra contadores para desbloquear 3). Suites + commit
  `feat(menu): organigrama, stats y logros`

### Task 16: SettingsView + NotificationsManager + legales

**Files:**
- Create: `FisuEvolution/UI/Menu/SettingsView.swift`, `FisuEvolution/Managers/NotificationsManager.swift`, `FisuEvolution/UI/Menu/LegalView.swift`
- Create: `Distribution/site/terms.md` (es+en, mismo formato que privacy.md, contacto adermanu@gmail.com)
- Delete: `FisuEvolution/UI/Config/ConfigView.swift`
- Modify: `FisuEvolution/App/RootView.swift` (el case .menu ya navega; borrar el sheet de ConfigView), `FisuEvolution/Game/Effects/ParticlePool.swift` (consulta el toggle), `project.yml` NO se toca
- Modify: `Localizable.xcstrings` (`settings.*` nuevos, `terms.*`/`privacy.*` si se muestran como texto)
- Test: `FisuEvolutionTests/SettingsPersistenceTests.swift`, UI smoke en `MenuUITests`

**Interfaces (Produces):**
```swift
@Observable @MainActor final class NotificationsManager {
    var isEnabled: Bool          // AppStorage-backed "settings.notificationsEnabled", default false
    func requestAndSchedule() async  // requestAuthorization + 1 recordatorio diario local; al apagar, removeAllPendingNotificationRequests
}
// AppStorage nuevo: "settings.particlesEnabled" (Bool, default true) — ParticlePool lo lee vía UserDefaults al emitir
// Idioma: escribe UserDefaults "AppleLanguages" = ["es"]/["en"] o remueve la key (Sistema) + alert de reinicio
```
Secciones y ids exactos del spec §10.4: `settings.language`, `settings.music`,
`settings.sfx`, `settings.haptics`, `settings.particles`,
`settings.notifications`, `settings.restore`, `settings.privacy`,
`settings.terms`. Los .md legales se cargan del bundle (agregar
`Distribution/site/privacy.md` y `terms.md` como recursos vía carpeta
`FisuEvolution/Resources/Legal/` — COPIARLOS ahí, no mover los originales) y
se muestran en `LegalView` (ScrollView de Text markdown
`try AttributedString(markdown:)`).

- [ ] **Step 1:** Escribir `terms.md` (es+en en el mismo archivo, como
  privacy.md: EULA estándar de juego gratis con IAP — licencia de uso, IAP no
  reembolsables por fuera del App Store, sin garantía, ley aplicable
  Argentina, contacto).
- [ ] **Step 2:** Tests: toggle de partículas persiste y ParticlePool no
  emite con el flag off (test unitario sobre UserDefaults + un
  `ParticlePool.emit` que retorna temprano); idioma escribe AppleLanguages.
- [ ] **Step 3:** `SettingsView` + `NotificationsManager` + `LegalView` +
  borrar ConfigView (y su sheet; `hud.settings` ahora es el tab del menú) +
  xcodegen.
- [ ] **Step 4:** Suites + commit `feat(ajustes): settings completos con idioma, notificaciones y legales`

---

## FASE 4 — Vida

### Task 17: Espejado de personajes (facing)

**Files:**
- Modify: `FisuEvolution/Scenes/Nodes/CharacterNode.swift` (API setFacing), `FisuEvolution/Scenes/BoardScene.swift` (startWander :1536, renderPlacements :1424)
- Test: `FisuEvolutionTests/CharacterFacingTests.swift` (nuevo)

**Interfaces (Produces):**
```swift
// CharacterNode
func setFacing(left: Bool)   // sprite.xScale = left ? -abs(x) : abs(x) — NUNCA node.xScale
var isFacingLeft: Bool { get } // para tests
static let facingActionKey = "facing"
```

- [ ] **Step 1: Tests rojos** (patrón `BoardGestureTests` con `debugNode`):
  tras `renderPlacements`, cada nodo tiene `action(forKey: "facing")`; con
  Reduce Motion simulado NO la tiene (inyectar el flag: `startWander` ya
  guarda contra `UIAccessibility.isReduceMotionEnabled` — extraer a
  `BoardScene.reduceMotionOverride: Bool?` #if DEBUG para testearlo);
  `setFacing(left: true)` deja `sprite.xScale < 0` y el nodo del pool
  reciclado vuelve a 1.
- [ ] **Step 2:** Implementar: (a) `setFacing` sobre el `sprite` privado
  (exponer con `private(set)` o método); (b) en el `map` de `startWander`,
  antes de cada `.move`, `.run { node.setFacing(left: stop.x < previous.x) }`;
  (c) flip periódico `repeatForever(.sequence([.wait(5, withRange: 5), .run { flip }]))`
  con clave `"facing"`, sembrado por el hash de `cellIndex`
  (BoardScene.swift:1540), arrancado en `renderPlacements` junto a
  `startWander`, detrás del MISMO guard de Reduce Motion.
- [ ] **Step 3:** Verificación visual en simulador: 4 capturas separadas 6 s
  → los personajes cambian de orientación; con Reduce Motion ON
  (`xcrun simctl spawn <UDID> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true`)
  → idénticas. Las dos direcciones (trampa 9 del HANDOFF).
- [ ] **Step 4:** `CrowdDepthTests` + `BoardGestureTests` verdes. Commit
  `feat(escena): los personajes miran hacia donde caminan y se dan vuelta solos`

### Task 18: Micro-animaciones de pulido

**Files:**
- Modify: `GameArtComponents.swift` (bounce de tab, shake de PricePill), `HUDView.swift` (`.contentTransition(.numericText())` en el contador), las 6 vistas (stagger de aparición: `.opacity+.offset` con delay por índice, tope 8), `RootView.swift` (toast de logro ya montado en Task 14 — pulso)
- Test: build + verificación visual; ningún `repeatForever` incondicional (grep).

- [ ] **Step 1:** Implementar las animaciones del spec §11.2, todas detrás de
  `@Environment(\.accessibilityReduceMotion)`.
- [ ] **Step 2:** `grep -rn "repeatForever" FisuEvolution/UI` → cada hit debe
  estar condicionado a un estado que lo apaga (patrón SpawnButtonView viejo,
  hoy en `GameArtComponents`).
- [ ] **Step 3:** Capturas de verificación + commit
  `feat(ui): micro-animaciones — contador rodante, stagger, bounce y shake`

### Task 19: Cola de prompts de iconos Gemini

**Files:**
- Create: `Tools/asset-pipeline/prompts/gemini_pro/NNN_<key>.md` × 15 (los del spec §12.1 MENOS `ui_tab_jobs`, que usa `homeless_face` y no se genera)
- Modify: `Tools/asset-pipeline/prompts/prompts.json` (15 entradas `{"assetKey", "category": "ui", "prompt"}`)
- Test: `cd Tools/asset-pipeline && .venv/bin/python -m unittest discover -s tests -q` (el parser valida el formato; 1 rojo preexistente por Chrome)

- [ ] **Step 1:** Numerar desde `max(números en gemini_pro/)+1`. Cada .md:
  `- **archivo**: <key>.png`, `- **estado**: pendiente`,
  `- **destino**: Tools/asset-pipeline/dropbox/`, sin `referencia`,
  `## Prompt` con el estilo maestro flat (paleta lockeada #FFD93D #FF6B35
  #FF4D6D #4D96FF #6BCB77 + #FFF8E7/#2C2C2C, outline negro grueso uniforme,
  sin gradientes, "Simple flat vector game icon, centered, plain white
  background.") + descripción específica (ascensor: cabina con puertas y
  flechas; calendario: hoja con 7 casillas y un check; trofeos
  bronce/plata/oro; etc.).
- [ ] **Step 2:** Tests del pipeline + commit
  `arte(pipeline): cola de 15 iconos del rediseño para el batch de gemini`
- [ ] **Step 3:** Dejar anotado en el commit y en el HANDOFF (Task 20) que el
  batch lo corre el dueño DESDE Terminal.app
  (`launch_gemini_chrome.py` → `gemini_selenium_runner.py --process`), y la
  advertencia de rembg con fills interiores (verificar % de píxeles opacos).

---

## FASE 5 — Verificación y cierre

### Task 20: Suite completa, capturas y documentación

**Files:**
- Modify: `Docs/HANDOFF.md` (sección de sesión nueva + estado de tests), `Docs/balance-log.md` (ya tocado en Task 3 — verificar), `Docs/superpowers/specs/2026-08-14-rediseno-ui-cowevolution-design.md` (marcar implementado)
- Create: `Docs/SESION-2026-08-14-rediseno-ui.md` (qué se hizo, qué queda, cómo se verifica)

- [ ] **Step 1:** Corrida completa: EconomyKit + app+UI
  (`-skip-testing:FisuEvolutionUITests/AscentRenderingUITests
  -parallel-testing-enabled NO`, simulador propio por UDID) + pipeline.
  Flakies conocidos: re-correr aislados antes de investigar.
- [ ] **Step 2:** Verificación visual: instalar en el simulador
  (`simctl install/launch booted ... --uitest-reset --uitest-skip-tutorial --uitest-coins`)
  y capturar CADA pantalla (HUD, las 6 hojas, las 4 sub-pantallas del menú,
  ascensor) — revisar contra el spec con ojo de diseñador: alineaciones,
  jerarquía, que nada muestre claves crudas (buscar "." en textos visibles).
  Probar también el flujo FTUE completo con `--uitest-reset` SOLO.
- [ ] **Step 3:** Tutorial end-to-end a mano (reset → tap → FisuJobs → merge).
- [ ] **Step 4:** Actualizar HANDOFF (nueva sesión, conteos de tests reales,
  la nota del batch de iconos pendiente del dueño) + sesión doc + marcar
  tareas del plan.
- [ ] **Step 5:** Commit final `docs(handoff): rediseño de ui estilo cow evolution — sesión 2026-08-14`
