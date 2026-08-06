# Ola 1 — cinco frentes en simultáneo

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** cerrar nueve de los dieciséis pedidos del playtest (RF-02b, RF-03, RF-04, RF-06, RF-08, RF-11, RF-12, RF-15, RF-16) con cinco agentes trabajando a la vez sin pisarse.

**Architecture:** la Ola 0 partió `GameState` en extensiones por dominio y creó la pieza compartida de descripción de efectos. Cada frente de esta ola es **dueño exclusivo** de una extensión y de sus vistas. El único archivo compartido es `GameState.swift`, y sólo para agregar **una** propiedad observada por frente.

**Tech Stack:** Swift 6 (strict concurrency `complete`), SwiftUI + SpriteKit, EconomyKit (SPM), Swift Testing, xcodegen.

## Global Constraints

De `Docs/HANDOFF.md` §2. Aplican a **todas** las tareas.

- El `.xcodeproj` **no se versiona**. Al agregar o borrar un archivo Swift: `/opt/homebrew/bin/xcodegen generate`.
- **Cero warnings**: `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`.
- **Accessibility identifier** en todo control interactivo. Sin eso no hay test de UI posible.
- Strings nuevos a `Localizable.xcstrings` (es + en), **editado desde Xcode, nunca con script**.
- Claves con `%@` interpoladas con un `Int` salen como la clave cruda: pasá `String(x)`. **Ya pasó dos veces en este repo.**
- Commits **en español**, atómicos.
- `SwiftUI` nunca lee `PlayerState`: lee proyecciones que `refreshProjections` publica a 8 Hz.

### Reglas de no-colisión (esto es lo que hace posible la ola)

| Regla | Por qué |
|---|---|
| Cada frente toca **sólo** los archivos de su tabla | Es todo el diseño de la ola |
| Cada frente agrega **una sola** propiedad a `GameState.swift`, de tipo struct, y **el struct vive en el archivo del frente** | Las propiedades observadas no pueden ir en extensiones (Swift no permite propiedades almacenadas ahí). Una línea por frente en un lugar conocido en vez de veinte dispersas |
| Prefijo de claves de localización por frente: **B** `upgrades.*` · **C** `map.*` · **D** `bonus.*` y `career.*` · **F** `prestige.*` · **G1a** `store.*` | El catálogo está ordenado alfabéticamente: con prefijos distintos las inserciones caen en zonas distintas del JSON y git las mergea solo |
| Nadie toca `AudioManager.swift`, `economy.json`, `tiers.json` ni `Tools/` | Son de la Ola 2 |

### La pieza compartida

Creada por la Ola 0 en `FisuEvolution/Managers/EffectDescriptor.swift`. **No la modifiques**: si te falta un caso, es una señal de que el efecto no está declarado en el config.

```swift
enum EffectUnit: Equatable { case percentBonus, percentDiscount, chance, multiplier }
struct EffectAmount: Equatable { let unit: EffectUnit; let value: Double; let isCapped: Bool }

enum EffectDescriptor {
    static func amount(for effectType: UpgradesConfig.EffectType, level: Int, magnitudePerLevel: Double) -> EffectAmount
    static func amount(forBoost effectType: BoostsConfig.EffectType, magnitude: Double) -> EffectAmount
}
enum EffectFormatter {
    static func text(_ amount: EffectAmount) -> String                                  // "+30%", "−9%", "3%", "×2,5"
    static func progression(current: EffectAmount, next: EffectAmount?) -> String        // "+30% → +40%"
    static var cappedNote: String { get }                                                // "al máximo"
}
```

**Ya está implementada y mergeada** (`FisuEvolution/Managers/EffectDescriptor.swift`, 10 tests verdes). `cappedNote` es la etiqueta para las filas cuyo `EffectAmount` viene con `isCapped`: **usala en vez de escribir tu propia etiqueta**, que es justo lo que esta pieza existe para evitar.

⚠️ **Dos tests están rojos en `main` y no son tuyos**: `AscentRenderingUITests` y `PacingTests`. Verificá con
`-skip-testing:FisuEvolutionUITests/AscentRenderingUITests -skip-testing:FisuEvolutionTests/PacingTests -parallel-testing-enabled NO`.
La línea de base real es **EconomyKit 144 · app 100 · UI 7**. Detalle en `Docs/HANDOFF.md` §7.2.

### Verificación (todos los frentes, al final de cada task)

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test
```

Estado de partida tras la Ola 0: **EconomyKit 144 · app 90+ · UI 10**. Ninguna tarea puede bajar esos números.

---

## Frente B — El menú de mejoras

Cierra **RF-03**, **RF-04** y **RF-06** (mejoras). Es el frente que concentra más pedidos: cuatro de los dieciséis, y es la pantalla de la que más se quejó el jugador.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Upgrades.swift`
- Modify: `FisuEvolution/UI/Store/UpgradesView.swift`
- Modify: `FisuEvolution/UI/Popups/CharacterSheetView.swift` (sacar `passiveSection`)
- Modify: `FisuEvolution/Game/State/GameState.swift` (**una** línea: la proyección)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` (campo nuevo en `run`)
- Test: `FisuEvolutionTests/UpgradesMenuTests.swift` (crear), `Packages/EconomyKit/Tests/EconomyKitTests/SeenTypesTests.swift` (crear)

### Task B1: Recordar los tipos vistos en la run (RF-03)

**Hoy** `GameState.characterUpgradeTypes` filtra por `units[$0.id] > 0 || charUpgradeLevels[$0.id] > 0`. Si mergeás tu último Fisura, **el Fisura desaparece de la lista de mejoras** aunque su mejora te siga rindiendo. El jugador ve que se le borró algo que compró.

**Interfaces:**
- Produces: `RunState.seenTypes: Set<String>`, y `GameState.characterUpgradeTypes` filtrando por eso.

- [ ] **Step 1: Escribir el test que falla, en EconomyKit**

```swift
import Testing
@testable import EconomyKit

@Suite struct SeenTypesTests {
    @Test("un tipo visto queda registrado aunque no quede ninguna unidad viva")
    func seenSurvivesTheLastUnit() {
        var state = PlayerState.newGame(startTypeId: "homeless", startFloorId: "alley")
        state.run.units["homeless"] = 2
        state.markSeen("homeless")
        state.run.units["homeless"] = 0
        #expect(state.run.seenTypes.contains("homeless"))
    }

    @Test("reencarnar borra los vistos salvo el tipo base")
    func reincarnationResetsSeen() {
        var state = PlayerState.newGame(startTypeId: "homeless", startFloorId: "alley")
        state.markSeen("homeless")
        state.markSeen("cartonero")
        state.run = .fresh(startTypeId: "homeless", startFloorId: "alley")
        #expect(state.run.seenTypes == ["homeless"])
    }
}
```

- [ ] **Step 2: Correr y verificar que falla**

```bash
cd Packages/EconomyKit && swift test --filter SeenTypesTests
```

Esperado: **FALLA**, `value of type 'RunState' has no member 'seenTypes'`.

- [ ] **Step 3: Agregar el campo y su migración de save**

`seenTypes` es un `Set<String>` en `RunState`, con **valor por defecto al decodificar** para que los saves viejos (que no lo tienen) carguen sin romperse:

```swift
/// Tipos que el jugador vio alguna vez EN ESTA RUN. La lista de mejoras se
/// arma con esto y no con las unidades vivas: mergear tu último Fisura no
/// tiene por qué borrarte de la pantalla la mejora que le compraste.
public var seenTypes: Set<String> = []
```

Y el método que lo puebla, en `PlayerState`:

```swift
public mutating func markSeen(_ typeId: String) { run.seenTypes.insert(typeId) }
```

En `.fresh(startTypeId:startFloorId:)`, inicializar `seenTypes` en `[startTypeId]` — reencarnar empieza de cero salvo el tipo base.

⚠️ Revisá `SaveMigrator.swift`: si la versión del sobre sube, el migrador tiene que poblar `seenTypes` de un save viejo con las claves de `units` que tengan valor > 0, o el jugador que actualiza pierde la lista.

- [ ] **Step 4: Marcar los tipos como vistos donde aparecen**

En `GameState`, cada camino que crea una unidad (contratar, mergear, el spawn inicial, la recompensa de video que da una unidad rara, la carga del save) llama a `markSeen`. Buscalos con:

```bash
grep -n "run.units\[" FisuEvolution/Game/State/*.swift Packages/EconomyKit/Sources/EconomyKit/*.swift
```

- [ ] **Step 5: Cambiar el filtro de la lista**

```swift
var characterUpgradeTypes: [CharacterType] {
    guard let content, let player else { return [] }
    return content.tiers.concreteTypes
        .filter { player.run.seenTypes.contains($0.id) }
        .sorted { $0.tier < $1.tier }
}
```

- [ ] **Step 6: Correr los dos test suites y verificar que pasan**

```bash
cd Packages/EconomyKit && swift test --filter SeenTypesTests
```

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test
```

- [ ] **Step 7: Commit**

```bash
git add Packages/EconomyKit FisuEvolution/Game/State FisuEvolutionTests
git commit -m "feat(mejoras): la lista muestra todo lo que desbloqueaste en la run

Filtraba por unidades vivas, así que mergear tu último Fisura te borraba
de la pantalla la mejora que le habías comprado y te seguía rindiendo.
Ahora la lista sale de run.seenTypes, que sobrevive a quedarte sin
copias y muere al reencarnar."
```

### Task B2: Dos botones por fila y el pasivo fuera de la ficha (RF-04)

**Hoy** el pasivo se compra **sólo** manteniendo apretado el personaje en el tablero, lo que abre `CharacterSheetView`, que tiene `skinPager` y `passiveSection`. En el menú no hay forma de comprarlo y la fila tiene un solo botón.

**El pedido del dueño, textual**: *"adentro de la pestaña personajes hacer 2 botones. uno para pasive income, y otro para multiplicadores/mejoras. todas las secciones tienen explicar exactamente lo que hacen. ej: plata x5 para el fisura"*. Y el long-press *"que funcione únicamente para cambiar las skins"*.

**Interfaces:**
- Produces: en `GameState+Upgrades.swift`,

```swift
/// Todo lo que una fila del menú necesita para dibujarse, ya resuelto: la UI
/// no vuelve a preguntarle nada al estado.
struct CharacterUpgradeRow: Identifiable, Equatable {
    let id: String                 // typeId
    let displayName: String
    let tier: Int
    /// Clave del manifest para la carita (RF-05). Nil → el círculo "T7".
    let faceKey: String?
    let multiplierText: String     // "×4" — lo que rinde HOY
    let nextMultiplierText: String // "×8" — lo que rinde si comprás
    let upgradeCost: Double
    let canAffordUpgrade: Bool
    let passiveUnlocked: Bool
    let passiveCost: Double
    let canAffordPassive: Bool
    /// "+2,5/s al Fisura" — qué hace el pasivo, con el número de ESTE personaje.
    let passiveEffectText: String
}
```

y `var characterUpgradeRows: [CharacterUpgradeRow]`.

- [ ] **Step 1: Escribir el test que falla**

```swift
import Testing
@testable import FisuEvolution

@Suite("Menú de mejoras")
@MainActor
struct UpgradesMenuTests {
    @Test("cada fila dice qué hace cada botón, con el número de ese personaje")
    func rowsExplainBothButtons() async {
        let gameState = await makeGameState()          // mismo helper que GameLoopWiringTests
        let row = try #require(gameState.characterUpgradeRows.first)
        #expect(row.multiplierText.hasPrefix("×"), "la fila tiene que decir el multiplicador, no el nivel")
        #expect(row.nextMultiplierText != row.multiplierText, "tiene que decir a cuánto saltás")
        #expect(row.passiveEffectText.contains("/s"), "el pasivo tiene que decir cuánto rinde por segundo")
    }

    @Test("se compra el pasivo desde el menú")
    func buyPassiveFromMenu() async {
        let gameState = await makeGameState()
        let typeId = gameState.characterUpgradeRows[0].id
        gameState.giveCoinsForTesting(1_000_000)
        gameState.unlockPassive(typeId: typeId)
        #expect(gameState.characterUpgradeRows[0].passiveUnlocked)
    }
}
```

⚠️ `makeGameState()` es `private` en `GameLoopWiringTests`. Extraelo a un helper compartido (`FisuEvolutionTests/Support/GameStateFixture.swift`) en vez de copiarlo: dos copias divergen. `giveCoinsForTesting` va en `GameState+Debug.swift`, detrás de `#if DEBUG`.

- [ ] **Step 2: Correr y verificar que falla**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test -only-testing:FisuEvolutionTests/UpgradesMenuTests 2>&1 | tail -20
```

Esperado: **FALLA** por `characterUpgradeRows` inexistente.

- [ ] **Step 3: Construir la proyección**

El multiplicador acumulado sale de `economy.charUpgrades.effectFactorPerLevel` (hoy **2,0**, o sea que cada nivel duplica: nivel 2 = ×4, nivel 3 = ×8). **Leelo del config, no lo hardcodees.** El rinde pasivo por segundo de un tipo sale de `type.passiveYieldPerInstance`.

- [ ] **Step 4: Rehacer la fila con dos botones**

Cada fila: carita (o el círculo "T7" si `faceKey` es nil) · nombre · las dos líneas de explicación · dos botones con su costo. El de pasivo muestra un tilde si ya está comprado. **Accessibility identifier en los dos**: `upgrades.character.<id>.multiplier` y `upgrades.character.<id>.passive`.

- [ ] **Step 5: Sacar `passiveSection` de `CharacterSheetView`**

La ficha queda como superficie de skins e info. **No toques `skinPager`** ni `equipSkin`. El long-press del tablero ya abre esta ficha —no hay que tocar `BoardScene`—, así que con sacar la sección el gesto pasa a servir sólo para skins, que es lo pedido.

- [ ] **Step 6: Test de UI que prueba el gesto**

```swift
func testLongPressAbreSkinsYNoCobraPasivo() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitest-reset", "--uitest-unlock-tower"]
    app.launch()
    // ... long-press sobre un personaje ...
    XCTAssertTrue(app.buttons["character.skin.equip"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["character.passive.buy"].exists, "el pasivo se compra en el menú")
}
```

⚠️ Trampa 2 del HANDOFF: **asertá el efecto, no que el gesto no crashee.** Y trampa 3: los drags por coordenadas fijas fallan seguido desde que el reconciliador conserva la posición deambulada — contá con reintentos.

- [ ] **Step 7: Correr todo y commitear**

```bash
git add FisuEvolution FisuEvolutionTests
git commit -m "feat(mejoras): dos botones por fila y el pasivo sale de la ficha

El pasivo se compraba sólo manteniendo apretado un personaje, un gesto
que nadie descubre. Ahora cada fila del menú tiene su botón de pasivo y
su botón de multiplicador, y cada uno dice qué hace con el número de ese
personaje en vez de un nivel abstracto.

La ficha del personaje queda como superficie de skins, que es para lo
único que el long-press sirve ahora."
```

### Task B3: Descripciones de las mejoras permanentes (RF-06)

**Hoy** las 7 mejoras permanentes muestran título y "nivel 3/20". Nada dice qué hacen.

- [ ] **Step 1: Escribir el test que falla**

```swift
@Test("ninguna mejora permanente queda sin línea de efecto")
func everyPermanentUpgradeExplainsItself() async {
    let gameState = await makeGameState()
    let lines = try #require(gameState.content?.upgradesConfig.upgrades)
    for line in lines {
        let text = gameState.upgradeEffectText(for: line)
        #expect(!text.isEmpty, "\(line.id) no dice qué hace")
        #expect(text.contains("%") || text.contains("×"), "\(line.id) no muestra ningún número")
    }
}
```

- [ ] **Step 2: Correr y verificar que falla**

Esperado: **FALLA** por `upgradeEffectText(for:)` inexistente.

- [ ] **Step 3: Implementarla con la pieza compartida**

```swift
func upgradeEffectText(for line: UpgradesConfig.Line) -> String {
    let level = upgradeLevel(of: line.id)
    let current = EffectDescriptor.amount(for: line.effectType, level: level, magnitudePerLevel: line.magnitudePerLevel)
    let next = level >= line.maxLevel
        ? nil
        : EffectDescriptor.amount(for: line.effectType, level: level + 1, magnitudePerLevel: line.magnitudePerLevel)
    return EffectFormatter.progression(current: current, next: next)
}
```

- [ ] **Step 4: Agregar las dos líneas a cada fila**

La numérica de arriba, y debajo un texto corto con el humor del juego, con clave `upgrades.flavor.<id>` en el catálogo. Siete mejoras, siete chistes.

- [ ] **Step 5: Correr, mirarlo en el simulador, commitear**

```bash
xcrun simctl install booted build/DD/Build/Products/Debug-iphonesimulator/FisuEvolution.app && xcrun simctl launch booted com.manuader.fisuevolution --uitest-reset
```

Abrí el menú y leé las siete filas. Un test verifica que hay texto; que el texto **se entienda** lo verificás vos.

---

## Frente C — El mapa de pisos (RF-08)

**Files:**
- Create: `FisuEvolution/UI/Popups/FloorMapView.swift`
- Modify: `FisuEvolution/Game/State/GameState+Tower.swift`
- Modify: `FisuEvolution/Scenes/BoardScene.swift` (sólo el vuelo de cámara)
- Modify: `FisuEvolution/UI/HUD/HUDView.swift` (**sólo** el botón que abre el mapa)
- Modify: `FisuEvolution/Game/State/GameState.swift` (**una** línea)
- Test: `FisuEvolutionTests/FloorMapTests.swift`, `FisuEvolutionUITests/FloorMapUITests.swift`

**Interfaces:**
- Produces: en `GameState+Tower.swift`,

```swift
struct FloorMapEntry: Identifiable, Equatable {
    let id: String                  // floorId
    let ordinal: Int
    let nameKey: String
    let backgroundKey: String       // para la miniatura
    let occupied: Int
    let capacity: Int
    let isUnlocked: Bool
    let isVisible: Bool             // el piso donde estás parado
}
```

y `var floorMap: [FloorMapEntry]` (de arriba hacia abajo: Dios primero), más `func jumpToFloor(ordinal: Int)`.

⚠️ **Todo sale de `floors[]`**, nada hardcodeado. La Ola 2 pasa la torre de 11 a 10 pisos y esta vista tiene que seguir andando sin tocarla.

### Task C1: La proyección del mapa

- [ ] **Step 1: Escribir el test que falla**

```swift
@Test("el mapa lista todos los pisos, de Dios para abajo, con los bloqueados marcados")
func mapListsEveryFloor() async {
    let gameState = await makeGameState()
    let map = gameState.floorMap
    #expect(map.count == gameState.content?.economy.floors.count)
    #expect(map.first?.ordinal == map.count - 1, "Dios va primero: la torre se lee de arriba para abajo")
    #expect(map.last?.isUnlocked == true, "el callejón siempre está abierto")
    #expect(map.first?.isUnlocked == false, "en una partida nueva el último piso está cerrado")
}

@Test("saltar a un piso bloqueado no hace nada")
func lockedFloorsAreNotReachable() async {
    let gameState = await makeGameState()
    let start = gameState.visibleFloorOrdinal
    gameState.jumpToFloor(ordinal: gameState.floorMap.count - 1)
    #expect(gameState.visibleFloorOrdinal == start)
}
```

- [ ] **Step 2: Correr y verificar que falla.** Esperado: `floorMap` inexistente.
- [ ] **Step 3: Implementar `floorMap` y `jumpToFloor`.** `jumpToFloor` valida contra el mismo dato que las flechas del HUD: si el piso no está desbloqueado, no hace nada y devuelve sin efecto.
- [ ] **Step 4: Correr y verificar que pasan.**
- [ ] **Step 5: Commit.**

### Task C2: La vista de ascensor

- [ ] **Step 1: Construir `FloorMapView`**

Pisos apilados verticalmente, Dios arriba y el callejón abajo. Cada fila: miniatura del fondo real (la clave sale de `backgroundKey`), nombre, ocupación `4/10`. Los bloqueados en gris y **sin responder al toque**. Accessibility identifier por fila: `map.floor.<id>`.

- [ ] **Step 2: El botón en el HUD**

Un `hudIconButton` más, con `identifier: "hud.map"`. ⚠️ El frente F también toca `HUDView`: **agregá sólo tu botón**, no reordenes ni reformatees nada más del archivo, o el merge se vuelve un conflicto de verdad en vez de dos inserciones.

- [ ] **Step 3: Test de UI**

```swift
func testElMapaLlevaAlPisoMasAlto() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitest-reset", "--uitest-unlock-tower"]
    app.launch()
    app.buttons["hud.map"].tap()
    app.buttons["map.floor.moon"].tap()
    XCTAssertTrue(app.staticTexts["tower.pill"].label.contains("Luna"))
}
```

⚠️ Trampa 4 del HANDOFF: *"Failed to scroll to visible" casi nunca es el botón, es algo modal tapándolo.* Exportá los attachments del xcresult y mirá la captura antes de culpar al selector.

- [ ] **Step 4: Correr, commitear.**

### Task C3: El vuelo de cámara

- [ ] **Step 1: Implementar el recorrido**

La cámara pasa por los pisos intermedios en ~0,6–0,9 s, cargando y descargando el rango visible ±1 sin tirones. Con `UIAccessibility.isReduceMotionEnabled`, corta directo.

⚠️ Trampa 8 del HANDOFF: **la multitud y los fondos comparten espacio de `zPosition` y eso ya rompió una vez.** `CrowdDepthTests` es el que avisa. Si el vuelo toca `zPosition` de algo, corré ese test.

- [ ] **Step 2: Verificarlo a ojo en el simulador.** Un test no ve un tirón.
- [ ] **Step 3: Commit.**

---

## Frente D — Bonus, boosts y carrera

Cierra **RF-11**, **RF-12**, **RF-06** (boosts) y **RF-15**.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift`, `GameState+Actions.swift` (sólo `chooseCareer`)
- Modify: `FisuEvolution/UI/Store/BonusView.swift`, `FisuEvolution/UI/Popups/CareerChoiceView.swift`
- Modify: `FisuEvolution/Resources/Config/boosts.json`, `rewarded_ads.json`
- Modify: `FisuEvolution/Game/State/GameState.swift` (**una** línea)
- Test: `FisuEvolutionTests/BonusCooldownTests.swift`, `BoostUnlockTests.swift`, `CareerRewardTests.swift`

**Interfaces** — los tipos que producís, en `GameState+Bonus.swift`:

```swift
struct BoostRow: Identifiable, Equatable {
    let id: String
    let displayName: String
    let iconKey: String
    /// "×3 a los ingresos por 90 s" — sale de EffectDescriptor + la duración.
    let effectText: String
    /// El chiste corto. Clave `bonus.flavor.<id>`.
    let flavorKey: String
    let isUnlocked: Bool
    /// Clave del nombre del piso que lo desbloquea. Nil si ya está abierto.
    let unlockFloorNameKey: String?
    let cooldownRemaining: TimeInterval
}

struct RewardRow: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let cooldownRemaining: TimeInterval
}

enum CareerRewardKind: String, Equatable, CaseIterable {
    case coinChest, freeBoost, skin, temporaryModifier
}

struct CareerReward: Equatable {
    let kind: CareerRewardKind
    /// Texto ya formateado para mostrar ANTES de elegir.
    let previewText: String
}
```

y `var boostRows: [BoostRow]`, `var rewardRows: [RewardRow]`, `var careerRewards: [String: CareerReward]`.

⚠️ `applyRewardedReward` hoy tiene la firma `applyRewardedReward(_ reward: RewardedAdsConfig.Reward)`. El cooldown necesita saber **cuándo**, así que pasa a tomar el instante. No inventes un reloj nuevo: usá el mismo que ya inyectan los boosts para sus cooldowns.

### Task D1: Un video cada 4 horas por recompensa (RF-11)

**Hoy** las 4 recompensas están siempre disponibles y sin cooldown: se pueden mirar los 4 videos seguidos y otra vez enseguida.

- [ ] **Step 1: Escribir el test que falla**, con reloj inyectado (EconomyKit ya trabaja así):

```swift
@Test("mirar un video bloquea esa recompensa 4 horas")
func rewardGoesOnCooldown() async {
    let gameState = await makeGameState()
    let id = "double_earnings"
    gameState.applyRewardedReward(rewardId: id, now: 1000)
    #expect(gameState.rewardCooldownRemaining(id: id, now: 1000) == 4 * 3600)
    #expect(gameState.rewardCooldownRemaining(id: id, now: 1000 + 4 * 3600) == 0)
}
```

- [ ] **Step 2: Correr y verificar que falla.**
- [ ] **Step 3: Agregar `cooldownSeconds: 14400` a las 4 entradas de `rewarded_ads.json`** y persistir la última activación en `meta`, **al lado de `boostActivations`**, que ya existe y ya sobrevive a la reencarnación por la misma razón (evitar el exploit de resetear cooldowns reencarnando).
- [ ] **Step 4: La fila muestra la cuenta regresiva** con el mismo `cooldownText` que ya usan los boosts, en lugar del botón.
- [ ] **Step 5: Correr, commitear.**

### Task D2: Boosts que se desbloquean por piso (RF-12) y dicen qué hacen (RF-06)

**Hoy** los 6 boosts están visibles y usables desde el primer minuto de la primera partida, y sólo muestran nombre y duración.

- [ ] **Step 1: Escribir el test que falla**

```swift
@Test("en una partida nueva sólo está disponible el primer boost")
func boostsUnlockByFloor() async {
    let gameState = await makeGameState()
    let available = gameState.boostRows.filter(\.isUnlocked)
    #expect(available.count == 1)
    #expect(available.first?.id == "mate")
}

@Test("ningún boost queda sin decir qué hace")
func everyBoostExplainsItself() async {
    let gameState = await makeGameState()
    for row in gameState.boostRows {
        #expect(!row.effectText.isEmpty, "\(row.id) no dice qué hace")
    }
}

@Test("el boost de costo se lee como descuento")
func mateReadsAsDiscount() async {
    let gameState = await makeGameState()
    let mate = try #require(gameState.boostRows.first { $0.id == "mate" })
    #expect(mate.effectText.contains("30%"), "magnitud 0,7 es −30%, no '0,7'")
}
```

- [ ] **Step 2: Correr y verificar que falla.**
- [ ] **Step 3: Agregar `unlockFloorId` a cada boost en `boosts.json`.** Repartilos para que el jugador reciba uno nuevo cada dos o tres pisos: `mate` desde el arranque (`alley`), y los otros cinco escalonados. **El mapeo vive en el JSON**, así que cambiarlo no toca código.

⚠️ La Ola 2 pasa la torre de 11 a 10 pisos y **retira `cosmic`**. No ates ningún boost a `cosmic`.

- [ ] **Step 4: La fila bloqueada se ve en gris con el requisito escrito** ("se desbloquea en la oficina"), usando `TowerNaming.floorNameKey(for:)`, que ya existe.
- [ ] **Step 5: La línea de efecto sale de la pieza compartida**, `EffectDescriptor.amount(forBoost:magnitude:)`.
- [ ] **Step 6: Correr, commitear.**

### Task D3: Elegir carrera da una recompensa distinta (RF-15)

**Hoy** son cuatro carreras (Programador, Arquitecto, Médico, Abogado), las cuatro se reabsorben en el Director y **la elección no cambia nada**.

- [ ] **Step 1: Escribir el test que falla**

```swift
@Test("cada carrera da una recompensa, y las cuatro son de tipo distinto")
func everyCareerGivesADifferentKindOfReward() async {
    let gameState = await makeGameState()
    let rewards = gameState.careerRewards          // [optionId: CareerReward]
    #expect(rewards.count == 4)
    #expect(Set(rewards.values.map(\.kind)).count == 4, "cuatro variantes del mismo premio no son una elección")
}
```

- [ ] **Step 2: Correr y verificar que falla.**
- [ ] **Step 3: Declarar las recompensas en config**, uno de estos cuatro tipos por carrera, todos ejecutables con efectos que la economía ya sabe aplicar: cofre de plata proporcional al income, boost gratis sin consumir cooldown, skin desbloqueada, modificador temporal.
- [ ] **Step 4: `CareerChoiceView` muestra la recompensa de cada opción ANTES de elegir.** Una elección a ciegas no es una elección.
- [ ] **Step 5: Correr, commitear.**

---

## Frente F — El multiplicador de reencarnar (RF-16)

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Prestige.swift`
- Modify: `FisuEvolution/UI/Popups/PrestigeView.swift`
- Modify: `FisuEvolution/UI/HUD/HUDView.swift` (**sólo** el indicador)
- Modify: `FisuEvolution/Game/State/GameState.swift` (**una** línea)
- Test: `FisuEvolutionTests/PrestigePreviewTests.swift`

**Interfaces** — el tipo que producís, en `GameState+Prestige.swift`:

```swift
struct PrestigePreview: Equatable {
    let oroGained: Int
    let multiplierBefore: Double
    let multiplierAfter: Double
    /// Lo que muere: unidades en la torre, plata y mejoras de personaje.
    let unitsLost: Int
    let coinsLost: Double
}
```

y `var prestigePreview: PrestigePreview`.

**Hoy** el popup dice cuánto ORO ganás pero no que cada ORO vale **+12%** de multiplicador global (`economy.oro.globalMultiplierPerOro = 0.12`). El jugador ve "ganás 14" y no tiene forma de saber qué compra.

### Task F1: El antes y el después

- [ ] **Step 1: Escribir el test que falla**

```swift
@Test("el multiplicador que promete el popup es el que queda después de confirmar")
func previewMatchesReality() async {
    let gameState = await makeGameState()
    gameState.giveLifetimeEarningsForTesting(50_000_000)
    let preview = gameState.prestigePreview
    gameState.confirmPrestige()
    let real = try #require(gameState.player?.meta.globalMultiplier)
    #expect(abs(real - preview.multiplierAfter) < 0.001,
            "si el popup miente, el jugador aprende a no creerle")
}
```

⚠️ `giveLifetimeEarningsForTesting` va en `GameState+Debug.swift` detrás de `#if DEBUG`, igual que `giveCoinsForTesting` del frente B. **Los dos frentes tocan ese archivo**: agregá sólo tu helper y no reordenes el resto.

- [ ] **Step 2: Correr y verificar que falla.**
- [ ] **Step 3: Implementar `prestigePreview`**, con `oroGained`, `multiplierBefore` y `multiplierAfter`. `multiplierAfter` **reusa `economy.globalMultiplier(oroEarnedLifetime:prestigeBonus:)`**, que es la misma función que aplica la reencarnación de verdad. Calcularlo aparte es cómo el popup termina mintiendo.
- [ ] **Step 4: El popup muestra "ganás 14 ORO → tu multiplicador pasa de ×2,3 a ×3,9"**, y en números qué se borra y qué sobrevive.
- [ ] **Step 5: Correr, commitear.**

### Task F2: El indicador permanente del HUD

- [ ] **Step 1: Agregar el indicador**, alimentado por la misma proyección, refrescado por `refreshProjections` a 8 Hz. **No observa `PlayerState`** — es la regla que sostiene toda la arquitectura.
- [ ] **Step 2: Verificar a ojo que crece mientras jugás y que no recompone de más.** Con el overlay de DEBUG, mirá `draws`.
- [ ] **Step 3: Commit.**

⚠️ El frente C también toca `HUDView`. Agregá sólo tu indicador; no reordenes el resto.

---

## Frente G1a — La tienda, contra el StoreKit local (RF-02b)

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Store.swift`, `FisuEvolution/UI/Store/StoreView.swift`
- Modify: `FisuEvolution/Resources/Config/products.json`, `StoreKitConfig/FisuEvolution.storekit`
- Test: `FisuEvolutionTests/StoreProductsTests.swift`

**Lo que ya se diagnosticó** (RF-02a, cerrado): **no había ningún bug.** `FisuEvolution.storekit` declara **un solo producto** (`remove_ads`), mientras `products.json` todavía declara cuatro — los otros tres son las skins de tinte retiradas. El jugador vio una tienda con una fila.

### Task G1: Limpiar los productos muertos y el estado vacío

- [ ] **Step 1: Escribir el test que falla**

```swift
@Test("todo producto declarado existe en el StoreKit local")
func noPhantomProducts() async throws {
    // ⚠️ Verificá la API real de ProductCatalog.swift (44 líneas) antes de escribir esto:
    // lo que importa es comparar los ids declarados contra los que resuelve StoreKit.
    let declared = Set(ProductCatalog.load().products.map(\.id))
    let session = try SKTestSession(configurationFileNamed: "FisuEvolution")
    let available = Set(try await Product.products(for: declared).map(\.id))
    #expect(declared == available, "declarados sin contraparte: \(declared.subtracting(available))")
}
```

- [ ] **Step 2: Correr y verificar que falla** con los tres productos de skin retirados.
- [ ] **Step 3: Sacar los tres muertos de `products.json`.**
- [ ] **Step 4: Arreglar el estado vacío de `StoreView`.** Hoy, si `store.products` viene vacío, la sección **no se dibuja** y una carga fallida de StoreKit se ve idéntica a una tienda sin nada. Tiene que decir que no se pudieron cargar las compras.
- [ ] **Step 5: Correr, commitear.**

### Task G2: Los productos nuevos

- [ ] **Step 1: Declarar los consumibles** — packs de monedas y un starter pack (monedas + quitar ads + una skin) — en `products.json` y en `FisuEvolution.storekit`.

⚠️ **Los packs de ORO van pero sin montos definitivos.** El rebalance de la Ola 3 (RF-07) cambia el exponente del ORO de 0,50 a 0,40, o sea que cambia cuánto vale un ORO. Dejá el monto como un valor de config con un `[TUNEABLE]` al lado, para que fijarlo después sea tocar un número y no rehacer el producto.

- [ ] **Step 2: Un test de `SKTestSession` por producto**, verificando que la compra acredita su efecto.
- [ ] **Step 3: Probarlo en el simulador.** El esquema ya arranca con `storeKitConfiguration: StoreKitConfig/FisuEvolution.storekit`.
- [ ] **Step 4: Commit.**

⚠️ **Lo que este frente NO hace**: dar de alta nada en App Store Connect. Eso es RF-02c y necesita la cuenta de Apple Developer. Todo lo de acá queda terminado y verificable en el simulador antes de ese gate.

---

## Qué queda para después de esta ola

| Ola | Qué |
|---|---|
| **2** | Integrar el arte (atlas, manifest, `generate-tiers`, `floors[]` de 11 a 10) · **RF-01**, el tutorial, que va después porque ilumina los controles que esta ola acaba de cambiar |
| **3** | **RF-07 + RF-10** en una sola corrida de `pacing-sim` · vender las 2 skins contra el StoreKit local |
| **4** | **RF-02c**: alta de productos en App Store Connect. Lo único bloqueado por la cuenta de Apple |
