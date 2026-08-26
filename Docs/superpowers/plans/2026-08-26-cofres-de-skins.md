# Cofres de skins — plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: usar `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans` para ejecutar tarea por tarea. Los pasos
> usan checkbox (`- [ ]`) para seguimiento.

**Goal:** que las 41 skins de piso se ganen abriendo cofres con premio aleatorio, con una
animación interactiva de cuatro toques.

**Architecture:** el sorteo es un tipo **puro en EconomyKit** con RNG inyectado
(`ChestRoller`), el turno lo arbitra la `CelebrationQueue` que ya existe, la oferta de
cofres cuelga de cuatro fuentes de las cuales tres ya tienen maquinaria, y la vista es un
overlay del `ZStack` de `RootView` — no un `sheet`.

**Tech Stack:** Swift 6 strict concurrency · SwiftUI (HUD/menús) · SpriteKit (tablero) ·
EconomyKit (SPM puro, `Sendable`, sin UI) · iOS 17+.

**Spec:** `Docs/superpowers/specs/2026-08-26-cofres-de-skins-design.md`. Ante cualquier
duda de comportamiento, el spec manda.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` — **cero warnings**, un warning rompe el build.
- El `.xcodeproj` **no se versiona**: después de crear o borrar archivos, `xcodegen generate`.
  ⚠️ Si `project.yml` queda con un bloque de puros comentarios, el YAML se vuelve inválido y
  **xcodegen falla en silencio** dejando el `.pbxproj` viejo.
- Los strings van a `Localizable.xcstrings` en **es y en**, **a mano, NUNCA con scripts**.
- `accessibilityIdentifier` en **todo control** y **jamás en un contenedor** (trampa 9a-bis:
  un id en un `HStack`/`VStack` pisa el de sus hijos).
- Contenido 100 % data-driven: ningún id de skin, rareza ni probabilidad hardcodeado en Swift.
- EconomyKit **no conoce UI ni `upgrades.json`**: lo que necesite ya resuelto se le pasa.
- Sin `Timer` para lógica de juego (regla 2 de concurrencia): se usa el tick por frame.
- Sin `repeatForever` incondicional; toda animación de pulido se apaga con
  `accessibilityReduceMotion` y **apagada queda en su estado FINAL**, no en el inicial.
- Commits en **español**, sin `Co-Authored-By`.
- Paleta lockeada: `#FFD93D` `#FF6B35` `#FF4D6D` `#4D96FF` `#6BCB77` `#FFF8E7` `#2C2C2C`.
- **Rama**: `feat/cofres-de-skins`, worktree `/Users/manuader/Desktop/projects/fisu-wt-cofres`.
  Staging **selectivo** siempre (nunca `git add -A`): hay otras sesiones en el mismo repo.

### ⚠️ Los helpers de test que EXISTEN (usar éstos, no inventar)

Este plan inventó nombres de fixture dos veces y las dos costaron una corrección. **No hay
ningún `enum Fixtures` en el target de la app.** El mapa real:

| Necesidad | Qué usar | Dónde vive |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` — es `async` pero **no** `throws`: nada de `try` | `FisuEvolutionTests/Support/GameStateFixture.swift:11` (global, no `private`) |
| RNG determinista, app | `FixedRNG(seed:)` — SplitMix64 real, **no** un generador constante (un valor fijo cuelga `Int.random` con rechazo infinito; el comentario del archivo lo dice de un bug propio) | `FisuEvolutionTests/ContentSystemsTests.swift:9` — `private` a esa suite: si lo necesitás desde otra, movelo a `Support/` |
| `PlayerState` nuevo, app | `makeState(maxTier:coins:)` | `FisuEvolutionTests/ContentSystemsTests.swift:41` — también `private` |
| RNG determinista, EconomyKit | `SeededRNG` | `Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift:134` |
| Save viejo para migrar | un `[String: Any]` + `JSONSerialization.data(withJSONObject:)` | patrón de `SaveMigratorTests.v3Fixture()`, `FisuEvolutionTests/SaveMigratorTests.swift:17` |
| Config/estado puro, EconomyKit | `fxConfig`, `fxState`, `fxEconomy`, `fxFloorTable`, `fxStateAndTower` | `EconomyKitTests/Fixtures.swift` |
| Contenido real en un test de la app | la propiedad `content` de la suite (`GameContentLoader.load(from: .main)` en su `init`) | `GameContentValidationTests.swift:11` |

⚠️ **`EconomyKitTests` no tiene recursos** (`Package.swift`, `testTarget` sin `resources:`):
desde ahí **no se puede leer ningún JSON del bundle**. Todo test de EconomyKit va con datos
sintéticos; los hechos de los JSON que se shippean se pinean del lado de la app.

## Verificación (vale para toda tarea)

```bash
# EconomyKit (rápido, sin simulador)
swift test --package-path Packages/EconomyKit
```

```bash
# App: unit ANTES que UI, con simulador propio apuntado por UDID
xcodebuild test -scheme FisuEvolution -destination "id=$UDID" -derivedDataPath /abs/path/dd -only-testing:FisuEvolutionTests
```

⚠️ **Rojos declarados que ya existen y NO son tuyos**: 11 de StoreKit en runtime 26 y
`PacingTests.theOwnersTargetsAreMet`. Cualquier otro rojo es tuyo.

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/SkinsConfig.swift` | suma `chestRarity` a `Entry` y su validación | 1 |
| `FisuEvolution/Resources/Config/skins.json` | las 41 entradas cambian de criterio | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/ChestsConfig.swift` | **nuevo** — espejo Codable de `chests.json` | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/ChestRoller.swift` | **nuevo** — el sorteo, puro y con RNG inyectado | 2 |
| `FisuEvolution/Resources/Config/chests.json` | **nuevo** — pesos, pagos y fuentes | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift` | tres campos nuevos, `currentSchemaVersion` a 5 | 3 |
| `FisuEvolution/Persistence/SaveMigrator.swift` | `migrateV4toV5` + el arreglo de las doradas | 3 |
| `FisuEvolution/Game/State/GameState+Chests.swift` | **nuevo** — otorgar, abrir y acreditar | 4, 5 |
| `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` | el kind `.chestOpening` | 5 |
| `FisuEvolution/Game/State/GameState+Celebrations.swift` | payload y apagado de UI | 5 |
| `FisuEvolution/Managers/ContentConfigs.swift` | `periodicChest` → `periodicPayout` | 6 |
| `FisuEvolution/UI/Popups/ChestOpeningView.swift` | **nuevo** — los siete latidos | 8 |
| `FisuEvolution/UI/Gifts/GiftsView.swift` | tarjeta del cofre + puntito | 9 |
| `FisuEvolution/UI/Skins/CustomizationView.swift` | el carrusel deja de perder pintas | 10 |
| `FisuEvolution/Game/State/GameState+TutorialTips.swift` | la lección `.skins` cambia de gatillo | 11 |

---

### Task 1: El catálogo — las 41 dejan de ser milestone

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/SkinsConfig.swift`
- Modify: `FisuEvolution/Resources/Config/skins.json` (41 entradas)
- Test (mecanismo): `Packages/EconomyKit/Tests/EconomyKitTests/SkinMilestonesTests.swift`
- Test (datos): `FisuEvolutionTests/GameContentValidationTests.swift`

⚠️ **El test va partido en dos targets y no es capricho.** `EconomyKitTests` **no tiene
recursos** (`Package.swift` declara el testTarget sin `resources:`), así que no puede abrir
`skins.json`: ahí se prueba el MECANISMO con un config sintético, como ya hacen los tests
que viven en ese archivo. Los hechos del catálogo real se pinean del lado de la app, en
`GameContentValidationTests`, que es donde ya viven `skinCatalogReferencesBundledTypesAndFloors`
y `everyCharacterHasACataloguedSkinWithAName`.

**Interfaces:**
- Produces: `SkinsConfig.Entry.chestRarity: String?` y `SkinsConfig.Rarity` (enum con
  `comun`, `rara`, `epica`, `legendaria`, `String`-raw, `Codable`, `CaseIterable`,
  `Comparable` por orden de declaración).
- Produces: `SkinsConfig.chestPool: [Entry]` — las entradas con `chestRarity != nil`.

- [ ] **Step 1a: El test del MECANISMO, en `SkinMilestonesTests.swift`**

Config sintético, como los tests que ya están en ese archivo:

```swift
@Test("una entrada con chestRarity no la propone nunca el evaluador de milestones")
func chestEntriesAreNeverMilestones() throws {
    let config = SkinsConfig(schemaVersion: 1, skins: [
        // La de cofre: mismo personaje y mismo piso que la de milestone de abajo,
        // así lo único que las distingue es el campo que decide.
        .init(id: "naranjita", characterType: "b", treatment: .texture,
              textureKey: "b__naranjita", chestRarity: .comun),
        .init(id: "second_life", characterType: "a", treatment: .texture,
              textureKey: "a__second_life", reincarnations: 1),
    ])
    var state = fxPlayerState()
    state.run.unlockedFloors = ["f1", "f2"]
    state.meta.prestigeLevel = 9

    let unlocked = SkinMilestones.newlyUnlocked(state: state, config: config, allUpgradesMaxed: true)

    #expect(unlocked == ["second_life"])              // la de milestone sí
    #expect(config.chestPool.map(\.id) == ["naranjita"])
}

@Test("una entrada no puede ser de cofre y de milestone a la vez")
func chestAndMilestoneAreMutuallyExclusive() {
    let config = SkinsConfig(schemaVersion: 1, skins: [
        .init(id: "confusa", characterType: "a", treatment: .texture,
              textureKey: "a__confusa", floorReached: "f2", chestRarity: .rara),
    ])
    #expect(throws: SkinsConfig.ValidationError.chestAndMilestone("confusa")) {
        try config.validate(characterTypeIDs: ["a"], floorIDs: ["f1", "f2"])
    }
}
```

- [ ] **Step 1b: El test de los DATOS, en `GameContentValidationTests.swift`**

Acá sí se lee el catálogo real, y se pinean los números del spec:

```swift
@Test("las 41 pintas de piso son de cofre, con la rareza del piso donde vive el personaje")
func chestPoolMatchesTheDesignedRarities() throws {
    let content = try GameContentLoader.loadForTests()
    let pool = content.skins.chestPool

    #expect(pool.count == 41)
    // Ninguna quedó con el criterio viejo: si una se escapa, se regalaría por
    // las DOS vías y el cofre repartiría algo que ya tenías.
    #expect(content.skins.skins.allSatisfy { $0.floorReached == nil || $0.chestRarity == nil })
    #expect(pool.allSatisfy { !$0.isMilestone })

    let esperado: [SkinsConfig.Rarity: Int] = [.comun: 7, .rara: 14, .epica: 12, .legendaria: 8]
    for (rareza, cuantas) in esperado {
        #expect(pool.filter { $0.chestRarity == rareza }.count == cuantas, "\(rareza)")
    }

    // Y la rareza se corresponde con el piso de casa del personaje, no con un
    // valor tipeado a mano: sin esto, una entrada mal clasificada pasa igual
    // mientras los totales cierren.
    let porPiso: [String: SkinsConfig.Rarity] = [
        "alley": .comun, "urban": .comun,
        "corporate": .rara, "luxury": .rara,
        "island": .epica, "moon": .epica, "mars": .epica,
        "solar": .legendaria, "galaxy": .legendaria,
    ]
    for skin in pool {
        let tier = content.tiers.type(id: skin.characterType)!.tier
        let piso = content.floorTable.floors.first { $0.firstTier <= tier && tier <= $0.lastTier }!
        #expect(skin.chestRarity == porPiso[piso.id], "\(skin.characterType) (T\(tier), \(piso.id))")
    }
}
```

⚠️ Si no existe un helper que cargue el contenido en tests, usar el que ya usan los otros
tests de ese archivo — **no inventar uno nuevo**.

- [ ] **Step 2: Correr y verificar que fallan los tres**

Run: `swift test --package-path Packages/EconomyKit --filter SkinMilestones`
Expected: FAIL — `chestRarity` y `chestPool` no existen (error de compilación).

- [ ] **Step 3: Agregar `Rarity`, `chestRarity` y `chestPool` a `SkinsConfig`**

En `SkinsConfig`, antes de `Entry`:

```swift
/// Rareza de una skin de cofre. El orden de declaración es el de escalada:
/// `ChestRoller` promociona hacia el siguiente caso cuando el sorteado se agota.
public enum Rarity: String, Codable, Sendable, CaseIterable, Comparable {
    case comun, rara, epica, legendaria

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
```

En `Entry`, junto a los otros criterios (y en el `init`, con default `nil`):

```swift
/// Rareza si esta skin sale de un cofre. Excluyente con los tres criterios de
/// milestone: con `chestRarity` puesto, `isMilestone` cae a `false` solo y
/// `SkinMilestones` deja de proponerla sin tener que conocerla.
public let chestRarity: Rarity?
```

Y en `SkinsConfig`:

```swift
/// Las skins que reparten los cofres, en orden de catálogo.
public var chestPool: [Entry] { skins.filter { $0.chestRarity != nil } }
```

- [ ] **Step 4: Validar la exclusión mutua**

En `ValidationError` agregar `case chestAndMilestone(String)`, y en `validate`, dentro del
`for skin in skins`:

```swift
if skin.chestRarity != nil, skin.isMilestone {
    throw ValidationError.chestAndMilestone(skin.id)
}
```

- [ ] **Step 5: Migrar las 41 entradas de `skins.json`**

Cambiar `"floorReached": "<piso>"` por `"chestRarity": "<rareza>"` **sólo** en las 41
entradas que hoy tienen `floorReached`. El mapeo es por el piso **donde vive el personaje**
(no por el `floorReached`, que apunta uno más arriba):

| Piso del personaje | Rareza | Cuántas |
|---|---|---:|
| `alley`, `urban` | `comun` | 7 |
| `corporate`, `luxury` | `rara` | 14 |
| `island`, `moon`, `mars` | `epica` | 12 |
| `solar`, `galaxy` | `legendaria` | 8 |

⚠️ **No tocar** las entradas de `oro` (43), `diamante` (43), `second_life`, `genesis`,
`mundialista` ni `parrillero`. Después del cambio, `grep -c floorReached skins.json` debe
dar **0**.

- [ ] **Step 6: Correr y verificar que pasa**

Run: `swift test --package-path Packages/EconomyKit` y
`xcodebuild test ... -only-testing:FisuEvolutionTests/GameContentValidationTests`
Expected: PASS los dos. Los tests viejos de milestone siguen verdes —`oro`, `diamante` y
las de reencarnación no se tocaron—, y `everyCharacterHasACataloguedSkinWithAName` también:
las 41 siguen en el catálogo, sólo cambiaron de criterio.

- [ ] **Step 7: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/SkinsConfig.swift Packages/EconomyKit/Tests/EconomyKitTests/SkinMilestonesTests.swift FisuEvolutionTests/GameContentValidationTests.swift FisuEvolution/Resources/Config/skins.json
git commit -m "feat(cofres): las 41 pintas de piso salen del evaluador de milestones y entran a la bolsa"
```

---

### Task 2: El sorteo — `ChestsConfig` y `ChestRoller`

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/ChestsConfig.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/ChestRoller.swift`
- Create: `FisuEvolution/Resources/Config/chests.json`
- Test: `Packages/EconomyKit/Tests/EconomyKitTests/ChestRollerTests.swift`

**Interfaces:**
- Consumes: `SkinsConfig.Rarity`, `SkinsConfig.chestPool` (Task 1).
- Produces:

```swift
public enum ChestOutcome: Sendable, Equatable {
    case skin(id: String, characterType: String, rarity: SkinsConfig.Rarity)
    case coins(rarity: SkinsConfig.Rarity)
}

public enum ChestRoller {
    public static func roll(
        owned: Set<String>,
        skins: SkinsConfig,
        config: ChestsConfig,
        minRarity: SkinsConfig.Rarity? = nil,
        using rng: inout some RandomNumberGenerator
    ) -> ChestOutcome
}
```

- [ ] **Step 0: El fixture, sintético**

⚠️ **`EconomyKitTests` NO tiene recursos** (`Package.swift` declara el `testTarget` sin
`resources:`), así que **no existe ni puede existir un fixture que lea `skins.json`**. La
bolsa de los tests se construye a mano, con la MISMA FORMA que la real —7/14/12/8— para que
las cuentas del sorteo signifiquen lo mismo. Los hechos del `chests.json` real se pinean del
lado de la app, en el Step 6.

En `Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift`, siguiendo el prefijo `fx` que
ya usan `fxConfig`, `fxEconomy`, `fxFloorTable` y `fxState`:

```swift
/// Una bolsa de cofre con la forma de la real: 7 comunes, 14 raras, 12 épicas y 8
/// legendarias. Los ids son `<rareza>_<n>` para que un fallo diga de una qué salió.
func fxChestSkins(
    comun: Int = 7, rara: Int = 14, epica: Int = 12, legendaria: Int = 8
) -> SkinsConfig {
    var entradas: [SkinsConfig.Entry] = []
    for (rareza, cuantas) in [(SkinsConfig.Rarity.comun, comun), (.rara, rara),
                              (.epica, epica), (.legendaria, legendaria)] {
        for n in 0..<cuantas {
            entradas.append(.init(
                id: "\(rareza.rawValue)_\(n)", characterType: "t\(entradas.count)",
                treatment: .texture, textureKey: "t\(entradas.count)__\(rareza.rawValue)_\(n)",
                chestRarity: rareza
            ))
        }
    }
    return SkinsConfig(schemaVersion: 1, skins: entradas)
}

func fxChests(
    comun: Int = 55, rara: Int = 28, epica: Int = 12, legendaria: Int = 5
) -> ChestsConfig {
    ChestsConfig(
        schemaVersion: 1,
        weights: [.init(rarity: .comun, weight: comun), .init(rarity: .rara, weight: rara),
                  .init(rarity: .epica, weight: epica), .init(rarity: .legendaria, weight: legendaria)],
        floorsPerChest: 2, completedPayoutFactor: 6, prestigePayoutFactor: 12,
        welcomeSkinId: "comun_0"
    )
}
```

Esto obliga a que `ChestsConfig` y `ChestsConfig.RarityWeight` tengan **`init` público
memberwise** — no alcanza con `Codable`.

⚠️ `SeededRNG`: si no existe ya en el target, agregarlo acá — un `RandomNumberGenerator`
determinista sembrado. Es lo que hace que estos tests sean reproducibles y no "casi siempre
verdes".

- [ ] **Step 1: Escribir los seis tests que fallan**

En `Packages/EconomyKit/Tests/EconomyKitTests/ChestRollerTests.swift`:

```swift
@Test("sortea una skin de la rareza que salió, y nunca una que ya tenés")
func rollsUnownedOfDrawnRarity() {
    let skins = fxChestSkins()
    var rng: any RandomNumberGenerator = SeededRNG(seed: 7)
    // Una ya tomada: si el sorteo la devolviera, el cofre repartiría algo que el
    // jugador ya tiene, que es el modo de fallar más caro del sistema.
    let owned: Set<String> = ["comun_0"]
    for _ in 0..<200 {
        guard case let .skin(id, _, rarity) = ChestRoller.roll(
            owned: owned, skins: skins, config: fxChests(), using: &rng
        ) else { Issue.record("esperaba skin"); return }
        #expect(!owned.contains(id))
        #expect(skins.chestPool.first { $0.id == id }?.chestRarity == rarity)
    }
}

@Test("con la rareza sorteada agotada, promociona hacia ARRIBA")
func promotesUpwardWhenExhausted() {
    let skins = fxChestSkins()
    // Todas las comunes tomadas. Con peso 55 sobre 100, sin promoción más de la
    // mitad de estas 200 tiradas no daría skin.
    let owned = Set(skins.chestPool.filter { $0.chestRarity == .comun }.map(\.id))
    var rng: any RandomNumberGenerator = SeededRNG(seed: 11)
    for _ in 0..<200 {
        guard case let .skin(_, _, rarity) = ChestRoller.roll(
            owned: owned, skins: skins, config: fxChests(), using: &rng
        ) else { Issue.record("esperaba skin"); return }
        #expect(rarity != .comun)
    }
}

@Test("sin nada arriba, baja")
func fallsDownWhenNothingAbove() {
    let skins = fxChestSkins()
    let owned = Set(skins.chestPool.filter { $0.chestRarity != .comun }.map(\.id))
    var rng: any RandomNumberGenerator = SeededRNG(seed: 3)
    guard case let .skin(_, _, rarity) = ChestRoller.roll(
        owned: owned, skins: skins, config: fxChests(), minRarity: .legendaria, using: &rng
    ) else { Issue.record("esperaba skin"); return }
    #expect(rarity == .comun)
}

@Test("con la colección completa paga plata")
func paysCoinsWhenCollectionIsComplete() {
    let skins = fxChestSkins()
    let owned = Set(skins.chestPool.map(\.id))
    var rng: any RandomNumberGenerator = SeededRNG(seed: 5)
    guard case .coins = ChestRoller.roll(
        owned: owned, skins: skins, config: fxChests(), using: &rng
    ) else { Issue.record("esperaba plata"); return }
}

@Test("el piso de rareza no deja salir nada por debajo mientras haya stock")
func floorKeepsRarityAtOrAbove() {
    let skins = fxChestSkins()
    var rng: any RandomNumberGenerator = SeededRNG(seed: 13)
    for _ in 0..<200 {
        guard case let .skin(_, _, rarity) = ChestRoller.roll(
            owned: [], skins: skins, config: fxChests(), minRarity: .epica, using: &rng
        ) else { Issue.record("esperaba skin"); return }
        #expect(rarity >= .epica)
    }
}

@Test("41 cofres seguidos vacían la bolsa entera, sin una sola repetida")
func fortyOneChestsCompleteTheCollection() {
    let skins = fxChestSkins()
    var owned: Set<String> = []
    var rng: any RandomNumberGenerator = SeededRNG(seed: 21)
    for n in 0..<skins.chestPool.count {
        guard case let .skin(id, _, _) = ChestRoller.roll(
            owned: owned, skins: skins, config: fxChests(), using: &rng
        ) else { Issue.record("cofre \(n): esperaba skin, la bolsa no estaba vacía"); return }
        #expect(owned.insert(id).inserted, "cofre \(n) repitió \(id)")
    }
    #expect(owned.count == 41)
}
```

⚠️ **El último es el test que justifica todo el diseño de promoción**: si la promoción no
funcionara, la bolsa se estancaría antes de las 41 y ese `#expect` lo diría en el cofre
exacto donde ocurre.

- [ ] **Step 2: Correr y verificar que fallan**

Run: `swift test --package-path Packages/EconomyKit --filter ChestRoller`
Expected: FAIL — `ChestRoller` no existe.

- [ ] **Step 3: Escribir `ChestsConfig`**

```swift
import Foundation

/// Espejo Codable de `chests.json`. Los pesos y los pagos son datos: cambiar el
/// ritmo del sistema no debe pedir un rebuild de lógica.
public struct ChestsConfig: Codable, Sendable, Equatable {
    public struct RarityWeight: Codable, Sendable, Equatable {
        public let rarity: SkinsConfig.Rarity
        public let weight: Int
    }

    public let schemaVersion: Int
    public let weights: [RarityWeight]
    /// Cada cuántos pisos desbloqueados cae un cofre de la torre.
    public let floorsPerChest: Int
    /// Multiplicador sobre `passiveUnlockCost(forTier:)` cuando ya no queda skin.
    public let completedPayoutFactor: Double
    /// Lo mismo para el cofre de la reencarnación, que paga más.
    public let prestigePayoutFactor: Double
    /// Qué pinta trae el cofre del tutorial. Es FIJA y no una tirada —es un
    /// momento guionado— pero vive acá y no en Swift: la constraint global dice
    /// que ningún id de skin se hardcodea, y esta es la única que el código
    /// necesitaría nombrar.
    public let welcomeSkinId: String

    public func weight(for rarity: SkinsConfig.Rarity) -> Int {
        weights.first { $0.rarity == rarity }?.weight ?? 0
    }
}
```

Y `FisuEvolution/Resources/Config/chests.json`:

```json
{
  "schemaVersion": 1,
  "weights": [
    { "rarity": "comun", "weight": 55 },
    { "rarity": "rara", "weight": 28 },
    { "rarity": "epica", "weight": 12 },
    { "rarity": "legendaria", "weight": 5 }
  ],
  "floorsPerChest": 2,
  "completedPayoutFactor": 6.0,
  "prestigePayoutFactor": 12.0,
  "welcomeSkinId": "urban_trailblazer"
}
```

- [ ] **Step 4: Escribir `ChestRoller`**

```swift
import Foundation

/// Qué salió de un cofre. `coins` lleva rareza igual porque la animación ya
/// pintó su color antes de saber el resultado: si el pago viniera sin rareza,
/// el latido del estallido tendría que elegir un color al azar.
public enum ChestOutcome: Sendable, Equatable {
    case skin(id: String, characterType: String, rarity: SkinsConfig.Rarity)
    case coins(rarity: SkinsConfig.Rarity)
}

/// El sorteo de un cofre. Puro y con RNG inyectado, como `special_roll`: los
/// tests fijan la semilla y el resultado es reproducible.
public enum ChestRoller {
    public static func roll(
        owned: Set<String>,
        skins: SkinsConfig,
        config: ChestsConfig,
        minRarity: SkinsConfig.Rarity? = nil,
        using rng: inout some RandomNumberGenerator
    ) -> ChestOutcome {
        let candidatas = SkinsConfig.Rarity.allCases.filter { $0 >= (floor ?? .comun) }
        let sorteada = weightedPick(candidatas, config: config, using: &rng) ?? .comun
        guard let resuelta = firstWithStock(from: sorteada, owned: owned, skins: skins) else {
            return .coins(rarity: sorteada)
        }
        let disponibles = stock(of: resuelta, owned: owned, skins: skins)
        // `randomElement(using:)` sobre un array ordenado por catálogo: el orden
        // de `chestPool` es estable, así que la semilla reproduce la tirada.
        let elegida = disponibles.randomElement(using: &rng)!
        return .skin(id: elegida.id, characterType: elegida.characterType, rarity: resuelta)
    }

    /// Sube a la primera rareza con stock; si arriba no hay ninguna, baja.
    ///
    /// Sube antes que bajar porque promocionar se lee como un regalo y degradar
    /// como un recorte, y porque deja las legendarias para el final: son las
    /// únicas que no reciben promociones de más arriba.
    private static func firstWithStock(
        from rarity: SkinsConfig.Rarity, owned: Set<String>, skins: SkinsConfig
    ) -> SkinsConfig.Rarity? {
        let arriba = SkinsConfig.Rarity.allCases.filter { $0 >= rarity }
        let abajo = SkinsConfig.Rarity.allCases.filter { $0 < rarity }.reversed()
        return (arriba + abajo).first { !stock(of: $0, owned: owned, skins: skins).isEmpty }
    }

    private static func stock(
        of rarity: SkinsConfig.Rarity, owned: Set<String>, skins: SkinsConfig
    ) -> [SkinsConfig.Entry] {
        skins.chestPool.filter { $0.chestRarity == rarity && !owned.contains($0.id) }
    }

    private static func weightedPick(
        _ rarities: [SkinsConfig.Rarity], config: ChestsConfig, using rng: inout some RandomNumberGenerator
    ) -> SkinsConfig.Rarity? {
        let total = rarities.reduce(0) { $0 + config.weight(for: $1) }
        guard total > 0 else { return rarities.first }
        var corte = Int.random(in: 0..<total, using: &rng)
        for rarity in rarities {
            corte -= config.weight(for: rarity)
            if corte < 0 { return rarity }
        }
        return rarities.last
    }
}
```

- [ ] **Step 5: Cargar `chests.json`**

Dar de alta `chests.json` en `GameContentLoader` junto a los otros trece configs y exponerlo
como `content.chests`. Seguir el patrón exacto de los que ya están.

- [ ] **Step 6: Pinear el config REAL, del lado de la app**

El Step 1 prueba el mecanismo sobre una bolsa sintética; que el `chests.json` que se shippea
tenga los números del spec se pinea donde se puede leer el bundle, en
`FisuEvolutionTests/GameContentValidationTests.swift`:

```swift
@Test("chests.json trae los pesos y los factores del spec")
func chestConfigMatchesTunedValues() {
    let chests = content.chests
    #expect(chests.weight(for: .comun) == 55)
    #expect(chests.weight(for: .rara) == 28)
    #expect(chests.weight(for: .epica) == 12)
    #expect(chests.weight(for: .legendaria) == 5)
    #expect(chests.floorsPerChest == 2)
    #expect(chests.completedPayoutFactor == 6)
    #expect(chests.prestigePayoutFactor == 12)
    // La pinta del cofre de bienvenida tiene que existir en la bolsa: un id mal
    // escrito acá deja el cofre del tutorial sin premio y nada más lo diría.
    #expect(content.skins.chestPool.contains { $0.id == chests.welcomeSkinId })
}
```

- [ ] **Step 7: Correr y verificar**

Run: `swift test --package-path Packages/EconomyKit --filter ChestRoller` → PASS 6/6, y
`xcodebuild test ... -only-testing:FisuEvolutionTests/GameContentValidationTests` → PASS.

- [ ] **Step 8: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/ChestsConfig.swift Packages/EconomyKit/Sources/EconomyKit/ChestRoller.swift Packages/EconomyKit/Tests/EconomyKitTests/ChestRollerTests.swift Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift FisuEvolutionTests/GameContentValidationTests.swift FisuEvolution/Resources/Config/chests.json FisuEvolution/Managers/GameContentLoader.swift
git commit -m "feat(cofres): el sorteo con promoción de rareza — 41 cofres vacían la bolsa sin repetir"
```

---

### Task 3: Estado y save v5

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift`
- Modify: `FisuEvolution/Persistence/SaveMigrator.swift`
- Test: `FisuEvolutionTests/SaveMigratorTests.swift` ⚠️ **acá, no en `PersistenceTests`**:
  es donde vive toda la cobertura de `SaveMigrator` y donde está el patrón de fixture
- Test: `Packages/EconomyKit/Tests/EconomyKitTests/SaveCompatibilityTests.swift`

**Interfaces:**
- Produces: `MetaState.chestsPending: Int`, `MetaState.prestigeChestsPending: Int`,
  `MetaState.welcomeChestGiven: Bool`, `RunState.floorChestsAwarded: Int`,
  `PlayerState.currentSchemaVersion == 5`.

- [ ] **Step 1: Escribir los tests que fallan**

En `SaveMigratorTests.swift`. ⚠️ **No existe `Fixtures.saveJSON`**: el patrón del archivo es
un diccionario privado más `JSONSerialization` (ver `v3Fixture()`, `:17`). Hace falta un
`v4Fixture()` hermano — un save v4 completo y válido, que es lo que hoy no existe porque
hasta ahora v4 era la versión corriente y se decodificaba directo.

```swift
@Test("un save v4 se migra a v5 con los campos del cofre en cero")
func v4MigratesToV5WithEmptyChestState() throws {
    let data = try JSONSerialization.data(withJSONObject: v4Fixture())
    let state = try SaveMigrator.migrate(data)
    #expect(state.meta.chestsPending == 0)
    #expect(state.meta.prestigeChestsPending == 0)
    #expect(state.meta.welcomeChestGiven == false)
    #expect(state.run.floorChestsAwarded == 0)
}

@Test("un v4 pre-rebalance con niveles arriba del tope de hoy se reescala y NO cuenta como maxeado")
func preRebalanceV4LosesTheFakeMaxOut() throws {
    // `crit` 24 sólo existe con el tope viejo de 25: es la huella de un save
    // pre-rebalance. ⚠️ 24 y no 25: el tope exacto reescala a 10 igual y el test
    // no distinguiría el clamp del reescalado proporcional.
    var levels = ["income": 20, "tap": 20, "crit": 24]
    var fixture = v4Fixture()
    fixture["meta"] = (fixture["meta"] as! [String: Any]).merging(["oroUpgradeLevels": levels]) { _, n in n }
    let state = try SaveMigrator.migrate(try JSONSerialization.data(withJSONObject: fixture))
    #expect(state.meta.oroUpgradeLevels["crit"] == 10)   // 24/25 × 10 ≈ 10
    #expect(state.meta.oroUpgradeLevels["income"] == 10) // 20/20 × 10 = 10
    // El que SÍ tenía poco no se lleva nada regalado:
    levels["crit"] = 12
    fixture["meta"] = (fixture["meta"] as! [String: Any]).merging(["oroUpgradeLevels": levels]) { _, n in n }
    let flojo = try SaveMigrator.migrate(try JSONSerialization.data(withJSONObject: fixture))
    #expect(flojo.meta.oroUpgradeLevels["crit"] == 5)    // 12/25 × 10 = 4,8 → 5
}
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `xcodebuild test ... -only-testing:FisuEvolutionTests/SaveMigratorTests`
Expected: FAIL — los campos no existen.

- [ ] **Step 3: Agregar los tres campos y subir la versión**

En `MetaState` (con su `init` y su `decode`; el `decode` usa
`decodeIfPresent(...) ?? 0` para que un v5 futuro con el campo ausente no rompa):

```swift
/// Cofres ganados y todavía sin abrir. Vive en `meta` y no en `run`: un cofre
/// ganado en la partida anterior sigue siendo tuyo después de reencarnar.
public var chestsPending: Int
/// Los de la reencarnación, aparte de los comunes porque garantizan **épica o
/// mejor**. Dos contadores y no una cola de `[Rarity?]`: hay una sola fuente con
/// piso, así que la cola sería estructura para un caso que no existe — y encima
/// obligaría a serializar un enum opcional en el save.
public var prestigeChestsPending: Int
/// El cofre del tutorial se da UNA vez por save, no una por partida.
public var welcomeChestGiven: Bool
```

En `RunState`:

```swift
/// Cuántos cofres dio la torre en ESTA partida. Muere con la run a propósito:
/// volver a subir la torre vuelve a pagar, que es lo que empuja a reencarnar.
public var floorChestsAwarded: Int
```

Y `PlayerState.currentSchemaVersion = 5`.

- [ ] **Step 4: Escribir `migrateV4toV5`**

```swift
/// v4 → v5: alta de los campos del cofre, y la corrección de las skins doradas.
///
/// ⚠️ **Lo que arregla y lo que no.** Hasta v4 no había forma de distinguir un
/// save escrito ANTES del rebalance de pacing de uno escrito después, así que
/// uno pre-rebalance con `crit` entre 10 y 24 pasaba el `nivel >= maxLevel` de
/// `awardEligibleMilestoneSkins` y se llevaba las 43 skins de oro sin haberlas
/// ganado (deuda declarada en el HANDOFF, aceptada justamente a la espera de
/// este bump). La huella detectable es tener un nivel POR ENCIMA del tope de
/// hoy —imposible en un save post-rebalance—, y a esos se les aplica el mismo
/// reescalado proporcional que v3 → v4.
///
/// Lo que NO alcanza a distinguir: una línea parada EXACTAMENTE en el tope
/// nuevo. `crit 10/25` (no maxeado, pre-rebalance) y `crit 10/10` (maxeado,
/// post-rebalance) son idénticos en disco. Queda un solo valor por línea sin
/// cubrir en vez de quince, y taparlo pediría un campo que los saves viejos no
/// tienen.
private static func migrateV4toV5(_ data: Data) throws -> Data {
    guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          var meta = object["meta"] as? [String: Any],
          var run = object["run"] as? [String: Any]
    else { throw SaveMigrationError.unsupportedVersion(4) }

    let levels = meta["oroUpgradeLevels"] as? [String: Int] ?? [:]
    // ⚠️ El closure externo va NOMBRADO: con `$0` adentro y afuera, Swift tira
    // "anonymous closure arguments cannot be used inside a closure that has
    // explicit arguments".
    if levels.contains(where: { linea in
        guard let cap = rebalanceLevelCaps[linea.key] else { return false }
        return linea.value > cap.actual
    }) {
        meta["oroUpgradeLevels"] = rescaleUpgradeLevelsForRebalance(levels)
    }
    meta["chestsPending"] = 0
    meta["prestigeChestsPending"] = 0
    meta["welcomeChestGiven"] = false
    run["floorChestsAwarded"] = 0

    object["meta"] = meta
    object["run"] = run
    object["schemaVersion"] = 5
    return try JSONSerialization.data(withJSONObject: object)
}
```

Y encadenarla en `migrate`: el `case 4` nuevo aplica `migrateV4toV5(data)`, y los casos 1,
2 y 3 la suman al final de su cadena.

- [ ] **Step 5: Correr y verificar que pasan**

Run: `xcodebuild test ... -only-testing:FisuEvolutionTests/SaveMigratorTests` y
`swift test --package-path Packages/EconomyKit --filter SaveCompatibility`
Expected: PASS. ⚠️ Si `SaveCompatibilityTests` pinea la versión, actualizar el número **y
leer el test**: si sólo comparaba contra `currentSchemaVersion`, no probaba nada y hay que
darle un literal.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift FisuEvolution/Persistence/SaveMigrator.swift FisuEvolutionTests/SaveMigratorTests.swift Packages/EconomyKit/Tests/EconomyKitTests/SaveCompatibilityTests.swift
git commit -m "feat(cofres): save v5 — los tres campos del cofre y el reescalado que le quita las doradas al que no las ganó"
```

---

### Task 4: Las cuatro fuentes

**Files:**
- Create: `FisuEvolution/Game/State/GameState+Chests.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` (`updateMaxFloorStat`)
- Modify: `FisuEvolution/Game/State/GameState+Prestige.swift`
- Modify: `FisuEvolution/Managers/ContentSystems.swift` (día 7)
- Modify: `FisuEvolution/Resources/Config/rewarded_ads.json`
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` (dos `switch`)
- Test: `FisuEvolutionTests/ChestSourcesTests.swift` (nuevo) — las tres primeras
- Test: `FisuEvolutionTests/ContentSystemsTests.swift` — la del día 7, **acá**: es donde vive
  `DailyRewardManager.claimIfAvailable` y donde ya está el `FixedRNG` que hace falta

**Interfaces:**
- Consumes: `ChestRoller.roll(...)`, `ChestOutcome`, `meta.chestsPending`,
  `run.floorChestsAwarded` (Tasks 2 y 3).
- Produces: `GameState.awardChest(minRarity: SkinsConfig.Rarity?)`,
  `GameState.awardFloorChestsIfDue()`, `GameState.pendingChestCount: Int`.

- [ ] **Step 1: Escribir los tests que fallan**

```swift
@MainActor
@Test("la torre da un cofre cada dos pisos, y no lo repite al re-desbloquear el mismo")
func towerGivesOneChestEveryTwoFloors() async throws {
    let state = await makeGameState()
    let pisos = state.content!.floorTable.floors.map(\.id)

    // Piso 1: todavía nada (1 / 2 == 0).
    state.player!.run.unlockedFloors = Array(pisos.prefix(1))
    state.awardFloorChestsIfDue()
    #expect(state.pendingChestCount == 0)

    // Piso 2: el primer cofre.
    state.player!.run.unlockedFloors = Array(pisos.prefix(2))
    state.awardFloorChestsIfDue()
    #expect(state.pendingChestCount == 1)

    // ⚠️ El caso negativo, que es el que importa: llamar de nuevo con los MISMOS
    // pisos no puede pagar otra vez. Sin el contador, este método corre en cada
    // merge (cuelga de `updateMaxFloorStat`) y regalaría un cofre por fusión.
    state.awardFloorChestsIfDue()
    state.awardFloorChestsIfDue()
    #expect(state.pendingChestCount == 1)

    // La torre entera: 10 pisos / 2 == 5.
    state.player!.run.unlockedFloors = pisos
    state.awardFloorChestsIfDue()
    #expect(state.pendingChestCount == 5)
}

@MainActor
@Test("reencarnar reinicia el contador de la torre pero conserva los cofres sin abrir")
func prestigeResetsTheCounterAndKeepsPendingChests() async throws {
    let state = await makeGameState()
    state.player!.run.unlockedFloors = state.content!.floorTable.floors.map(\.id)
    state.awardFloorChestsIfDue()
    #expect(state.pendingChestCount == 5)

    state.confirmPrestige()

    // Los 5 de la partida anterior siguen ahí (viven en `meta`), más el de la
    // reencarnación, que es el que garantiza épica.
    #expect(state.player!.run.floorChestsAwarded == 0)
    #expect(state.player!.meta.chestsPending == 5)
    #expect(state.player!.meta.prestigeChestsPending == 1)

    // Y volver a subir vuelve a pagar los cinco.
    state.player!.run.unlockedFloors = state.content!.floorTable.floors.map(\.id)
    state.awardFloorChestsIfDue()
    #expect(state.player!.meta.chestsPending == 10)
}

@MainActor
@Test("el cofre de bienvenida se da una sola vez por save")
func welcomeChestIsGrantedOnlyOnce() async throws {
    let state = await makeGameState()
    state.beginTutorialPhase()
    state.tutorialPhaseFinished()
    #expect(state.pendingChestCount == 1)
    #expect(state.player!.meta.welcomeChestGiven)

    // Segunda vuelta del tutorial (o un `tutorialPhaseFinished` repetido, que es
    // idempotente por su propio guard): no vuelve a regalar.
    state.beginTutorialPhase()
    state.tutorialPhaseFinished()
    #expect(state.pendingChestCount == 1)
}

// ⚠️ Este va en `ContentSystemsTests.swift`, no en el archivo nuevo: `DailyRewardManager.claimIfAvailable` es
// una función pura de `ContentSystems` y su suite ya tiene el `FixedRNG` y el
// armado de estado que hace falta. Copiá el setup de los tests de daily que ya
// están ahí en vez de inventar uno.
@Test("el día 7 da cofre sólo cuando ya están los diez specials")
func daySevenFallsThroughSpecialThenChest() throws {
    // `makeState()` es el helper privado de ESA suite (`ContentSystemsTests.swift:41`):
    // arma un `PlayerState.newGame` con los ids sacados de la data, nunca
    // hardcodeados. `fxState()` es de EconomyKitTests y acá no existe.
    var state = makeState()
    state.meta.daily.cycleDay = 7
    var rng: any RandomNumberGenerator = FixedRNG(seed: 2)

    // Con specials pendientes, el día 7 NO da cofre: sigue dando special.
    let conSpecials = DailyRewardManager.claimIfAvailable(state: &state, rng: &rng, /* … */)
    #expect(conSpecials?.specialGranted != nil)
    #expect(conSpecials?.chestGranted == false)

    // Con los diez specials tomados y skins por sacar, da cofre.
    state.meta.ownedSpecials = content.specials.specials.map(\.id)
    state.meta.daily.cycleDay = 7
    state.meta.daily.lastClaimDay = nil
    let sinSpecials = DailyRewardManager.claimIfAvailable(state: &state, rng: &rng, /* … */)
    #expect(sinSpecials?.chestGranted == true)
}
```

⚠️ Los cuatro llevan su **caso negativo** y no es decoración: los dos bugs que este
sistema puede tener son "paga de más" (el contador de la torre corriendo en cada merge) y
"le pisa el premio a otro" (el cofre comiéndose el special del día 7).

- [ ] **Step 2: Correr y verificar que fallan**

Run: `xcodebuild test ... -only-testing:FisuEvolutionTests/ChestSourcesTests`
Expected: FAIL — los métodos no existen.

- [ ] **Step 3: Escribir `GameState+Chests.swift`**

```swift
/// La torre paga cada `floorsPerChest` pisos. El contador vive en `run` y
/// cuenta CUÁNTOS pagó, no cuáles: así re-desbloquear un piso que ya viste no
/// vuelve a pagar, y volver a subir la torre después de reencarnar sí.
func awardFloorChestsIfDue() {
    guard let content, var player else { return }
    let debidos = player.run.unlockedFloors.count / content.chests.floorsPerChest
    guard debidos > player.run.floorChestsAwarded else { return }
    let nuevos = debidos - player.run.floorChestsAwarded
    player.run.floorChestsAwarded = debidos
    player.meta.chestsPending += nuevos
    self.player = player
    syncCelebrations()
}
```

Y el otorgamiento suelto, que usan el video, el día 7, la reencarnación y el tutorial:

```swift
/// Suma un cofre. `minRarity` no se guarda por cofre: hay una sola fuente con piso
/// —la reencarnación— así que alcanza con el segundo contador, y los dos se
/// gastan de a uno con el de prestigio primero (el mejor premio se cobra antes).
func awardChest(minRarity: SkinsConfig.Rarity? = nil) {
    guard var player else { return }
    if minRarity == nil { player.meta.chestsPending += 1 } else { player.meta.prestigeChestsPending += 1 }
    self.player = player
    syncCelebrations()
}

/// Lo que muestran el puntito y la tarjeta de Regalos.
var pendingChestCount: Int {
    (player?.meta.chestsPending ?? 0) + (player?.meta.prestigeChestsPending ?? 0)
}
```

`awardFloorChestsIfDue()` se llama desde `updateMaxFloorStat()`, que ya es el embudo de
merges, ascensos y pisos nuevos — el mismo lugar donde cuelga
`awardEligibleMilestoneSkins()`.

- [ ] **Step 4: El video**

En `rewarded_ads.json`, un quinto reward:

```json
{
  "id": "skin_chest",
  "effectType": "skinChest",
  "cooldownSeconds": 14400,
  "titleKey": "ads.reward.chest"
}
```

Agregar `case skinChest` a `RewardedAdsConfig.EffectType` (vive en `Managers/Ads/AdsProvider.swift`, **no** en `ContentConfigs.swift`) y el `case` correspondiente en
`applyRewardedReward` (llama a `awardChest(minRarity: nil)`) y en `rewardText`. Los dos `switch`
son exhaustivos: el compilador señala si falta uno.

- [ ] **Step 5: El día 7 y la reencarnación**

`DailyRewardManager.Claim` suma `let chestGranted: Bool` (los tres call sites lo pasan; el
compilador los señala). En `DailyRewardManager.claimIfAvailable` (`ContentSystems.swift:362` — **no** se llama `claimDaily`), el `else` del `special_roll` —el que hoy va derecho
a la plata cuando ya tenés los diez specials— pasa a tener un escalón intermedio:

```swift
} else if state.meta.allOwnedSkins.isSuperset(of: skins.chestPool.map(\.id)) == false {
    // Segundo escalón: ya tenés los diez specials pero te faltan pintas.
    // NO se toca el camino del special: el día 7 sigue siendo, primero, su día.
    state.meta.chestsPending += 1
    chest = true
} else {
    coins = economy.passiveUnlockCost(forTier: state.run.maxTierReached) * 6.0
    state.run.coins += coins
    state.meta.lifetimeEarnings += coins
}
```

⚠️ Esa función es **pura sobre `inout PlayerState`**: acredita el cofre
tocando el estado, no llamando a `GameState.awardChest`, que no existe en esa capa.

En `GameState+Prestige.confirmPrestige()` (`:92` — **no** existe `state.reincarnate()`), después de `PrestigeCalculator.reincarnate(...)`:
`awardChest(minRarity: .epica)`. ⚠️ **Después y no antes**: `reincarnate` hace
`run = .fresh(...)`, así que un cofre otorgado antes se perdería si algún día el contador
se mudara a `run`.

- [ ] **Step 6: Correr y verificar que pasan**

Run: `xcodebuild test ... -only-testing:FisuEvolutionTests` — la suite entera, no sólo la
clase nueva: esto toca el embudo de `updateMaxFloorStat` y el daily.
Expected: PASS salvo los rojos declarados.

- [ ] **Step 7: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Chests.swift FisuEvolution/Game/State/GameState.swift FisuEvolution/Game/State/GameState+Prestige.swift FisuEvolution/Game/State/GameState+Bonus.swift FisuEvolution/Managers/ContentSystems.swift FisuEvolution/Managers/ContentConfigs.swift FisuEvolution/Resources/Config/rewarded_ads.json FisuEvolutionTests/ChestSourcesTests.swift
git commit -m "feat(cofres): las cuatro fuentes — la torre cada dos pisos, el video, el día 7 y la reencarnación"
```

---

### Task 5: El turno — `.chestOpening` en la cola

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift`
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` (payload `chestReward`)
- Test: `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift`
- Test: `FisuEvolutionTests/CelebrationWiringTests.swift`

**Interfaces:**
- Produces: `CelebrationKind.chestOpening` (priority 4, `timeout: nil`),
  `GameState.chestReward: ChestReward?` con
  `struct ChestReward: Identifiable { let id: String; let outcome: ChestOutcome }`.

- [ ] **Step 1: Escribir los tests que fallan**

```swift
@Test("el cofre espera a que termine el reveal del tablero")
func chestWaitsForTheBoardReveal() {
    var queue = CelebrationQueue()
    queue.enqueue(.chestOpening)
    queue.enqueue(.boardCelebration)
    #expect(queue.current == .boardCelebration)   // prioridad 3 < 4
}

@Test("el cofre no se cierra solo")
func chestHasNoTimeout() {
    #expect(CelebrationKind.chestOpening.timeout == nil)
    #expect(CelebrationKind.chestOpening.isSkippable == false)
}

@Test("el cofre apaga la UI mientras está en pantalla")
func chestHidesTheHUD() { /* GameState: encolar y leer celebrationHidesUI */ }
```

- [ ] **Step 2: Correr y verificar que fallan**

Run: `swift test --package-path Packages/EconomyKit --filter Celebration`
Expected: FAIL — el caso no existe.

- [ ] **Step 3: Agregar el kind**

En `CelebrationKind`:

```swift
/// El cofre que el jugador abrió. Es un ítem más de la cola: el "de a una" y el
/// no pisarse con el reveal del tablero salen del árbitro que ya existe.
case chestOpening
```

`priority`: junto a `.skinAward, .specialDrop` → `4`.
`timeout`: junto a los que espera el jugador → `nil`.

- [ ] **Step 4: Cablear el payload y el apagado**

En `syncCelebrations()`: `if chestReward != nil { celebrations.enqueue(.chestOpening) }`.
En `releasePayload(for:)`: `case .chestOpening: break` (lo limpia el dismiss del jugador,
como `skinAward`).
En `publishCelebration()`:

```swift
// El cofre apaga la UI SIEMPRE: su animación ocupa la pantalla entera y el HUD
// asomando por debajo rompe el telón.
let hides = (kind == .boardCelebration && boardCelebrationShowsSomethingNew)
    || kind == .chestOpening
```

- [ ] **Step 5: Correr y verificar que pasan**

Run: `swift test --package-path Packages/EconomyKit --filter Celebration` y
`xcodebuild test ... -only-testing:FisuEvolutionTests/CelebrationWiringTests`
Expected: PASS. ⚠️ `CelebrationKind` es `CaseIterable` y hay tests que recorren TODOS los
casos: si alguno se queda sin cubrir, es un rojo legítimo, no un test a aflojar.

- [ ] **Step 6: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift FisuEvolution/Game/State/GameState+Celebrations.swift FisuEvolution/Game/State/GameState.swift FisuEvolutionTests/CelebrationWiringTests.swift
git commit -m "feat(cofres): el cofre pide turno como cualquier celebración y apaga la UI"
```

---

### Task 6: El renombre de "cofre"

**Files:**
- Modify: `FisuEvolution/Managers/ContentConfigs.swift:134`
- Modify: `FisuEvolution/Resources/Config/boosts.json`
- Modify: `FisuEvolution/Resources/Localizable.xcstrings`
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift`, `FisuEvolution/UI/Gifts/GiftsView.swift`
- Test: `FisuEvolutionTests/EffectDescriptorTests.swift`

- [ ] **Step 1: Renombrar el caso del enum**

`BoostsConfig.EffectType.periodicChest` → `periodicPayout`, y el `"periodicChest"` de
`boosts.json` (boost `asado`) → `"periodicPayout"`. El enum es `CaseIterable` y
`EffectDescriptorTests` recorre los siete tipos, así que el rojo aparece solo si falta algo.

- [ ] **Step 2: Renombrar las cuatro claves, a mano, en `Localizable.xcstrings`**

| Vieja | Nueva | es | en |
|---|---|---|---|
| `bonus.effect.chest %@` | `bonus.effect.payout %@` | "Una picada de plata %@, cada vez" | "A %@ coin platter, every time" |
| `gifts.chest %@` | `gifts.payout %@` | "¡Picada! +%@" | "Payout! +%@" |
| `career.reward.chest %@` | `career.reward.welcome %@` | "Bienvenida: %@ de plata" | "Welcome bonus: %@ coins" |
| `gifts.daily.chest` | `gifts.daily.surprise` | "Sorpresa" | "Surprise" |

⚠️ **A mano, nunca con script** (regla del repo). Borrar la entrada vieja, no dejar las dos.

- [ ] **Step 3: Verificar que no quedó ninguna referencia**

```bash
grep -rn 'periodicChest\|bonus\.effect\.chest \|gifts\.chest %\|career\.reward\.chest \|gifts\.daily\.chest"' --include="*.swift" --include="*.json" --include="*.xcstrings" FisuEvolution
```

Expected: **cero líneas**. ⚠️ El patrón lleva los sufijos (` `, ` %`, `"`) a propósito: la
tarea 9 agrega `gifts.chest.count` y `gifts.chest.open`, que SÍ hablan del cofre de pintas
y no deben aparecer acá.

- [ ] **Step 4: Correr la suite y commitear**

```bash
git add FisuEvolution/Managers/ContentConfigs.swift FisuEvolution/Resources/Config/boosts.json FisuEvolution/Resources/Localizable.xcstrings FisuEvolution/Game/State/GameState+Bonus.swift FisuEvolution/UI/Gifts/GiftsView.swift
git commit -m "refactor(regalos): la palabra cofre queda para las pintas — el asado ahora paga una picada"
```

---

### Task 7: Integrar los 7 assets

**Files:**
- Add: `FisuEvolution/Resources/ui.atlas/{ui_chest_closed,ui_chest_cracked,ui_chest_open,ui_chest_lid,fx_star,fx_sparkle,fx_burst_rays}@{2x,3x}.png`
- Modify: `FisuEvolution/Resources/Data/assets_manifest.json`
- Add: `Tools/asset-pipeline/dropbox/procesadas/*.png`

⚠️ **Bloqueada por la generación de arte.** Los 7 prompts ya están dados de alta
(`fb5ce2b`).

- [ ] **Step 1: Generar** (ver "Generación de arte" al final del plan)
- [ ] **Step 2: Elegir el recorte a ojo, asset por asset**

Los cuatro del cofre son naranja saturado sobre blanco: **saliencia (`rembg`)** sale limpia.
Los tres FX son **crema `#FFF8E7`, a un pelo del blanco**: la saliencia se los come. Van con
**conectividad**, que conserva lo encerrado por el contorno. Se comparan las dos versiones
con `scripts/elegir_recorte.py` y se mira cada una — no se decide por la regla, se decide
mirando (decisión 6 del HANDOFF).

- [ ] **Step 3: Verificar el manifest y que el atlas no se rompió**

Run: `xcodebuild build -scheme FisuEvolution` y `AssetsManifestTests` si existe.

- [ ] **Step 4: Commit — LOS DOS LUGARES**

⚠️ Marcar el `.md` como `hecho` **no versiona el PNG**. Van el atlas **y**
`dropbox/procesadas/`. Un commit que stageó sólo los `.md` dejó `origin/main` con 84 de 86
skins, y se detectó recién al verificar el push.

---

### Task 8: La animación — `ChestOpeningView`

**Files:**
- Create: `FisuEvolution/UI/Popups/ChestOpeningView.swift`
- Modify: `FisuEvolution/App/RootView.swift` (overlay en el `ZStack`, junto a `towerNotice`)
- Test: `FisuEvolutionUITests/ChestOpeningUITests.swift`

**Interfaces:**
- Consumes: `gameState.showing == .chestOpening`, `gameState.chestReward` (Task 5).
- Produces: identifiers `chest.tap`, `chest.card`, `chest.equip`, `chest.dismiss`.

- [ ] **Step 1: La máquina de estados de los siete latidos**

```swift
private enum Beat: Int, Comparable {
    case arriving, waiting, forced1, forced2, forced3, bursting, flying, flipping, resting
    static func < (a: Beat, b: Beat) -> Bool { a.rawValue < b.rawValue }
}
```

El avance es **por completion y por tap**, nunca por `delay` encadenado (mismo criterio que
`runBoardCelebration` en `BoardScene`). Cada latido que se auto-avanza usa un `Task` con
`try? await Task.sleep(for: .seconds(1.2))` cancelable, cancelado si el jugador toca antes.

- [ ] **Step 2: Los latidos, con sus números del spec**

Sacudidas ±5° / ±9° / ±14° con `keyframeAnimator` y `SpringKeyframe(spring: .bouncy)`
(mismo vocabulario que el bounce de `GameTabButton:1202-1204`). Flash de 80 ms. Flip de
0,45 s con `rotation3DEffect(.degrees(...), axis: (0, 1, 0))`. Haptics por
`HapticsManager`: `.light`, `.medium`, `.heavy`, `.success`.

- [ ] **Step 3: Reduce Motion**

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Con Reduce Motion: **un solo tap** lleva de `arriving` a `resting` (estado FINAL: carta dada
vuelta, sin sacudidas, sin partículas). Nunca deja la pantalla en el estado inicial.

- [ ] **Step 4: El tinte de rareza**

Las estrellas, las chispitas y los rayos son crema con contorno negro y se tiñen con
`.colorMultiply(rarityColor)`: el negro multiplicado sigue negro y sólo el relleno toma
color. Es el mismo mecanismo que `SkinAwardPortrait` ya usa para los tintes.

- [ ] **Step 5: Identifiers y AX**

`accessibilityIdentifier` en el área tappable del cofre (`chest.tap`), la carta
(`chest.card`) y los dos botones. **Ningún contenedor lo lleva.** El overlay entero declara
`.accessibilityAddTraits(.isModal)` para que VoiceOver no se vaya al HUD apagado.

- [ ] **Step 6: UI test de humo**

Abrir un cofre por la puerta de debug, tapear cuatro veces, verificar que aparece
`chest.equip`. (Igual que el smoke del special: el gesto fino queda manual.)

- [ ] **Step 7: Commit**

---

### Task 9: Regalos — la tarjeta del cofre y el puntito

**Files:**
- Modify: `FisuEvolution/UI/Gifts/GiftsView.swift`
- Modify: la barra de pestañas (`GameTabBar` ya soporta `showsBadge`)
- Test: `FisuEvolutionUITests/BonusHUDUITests.swift`

- [ ] **Step 1**: `GameCard(style: .highlighted(Color("PaletteYellow")))` como **primera**
  sección, con `GameIcon(artKey: "ui_chest_closed", size: 44)`, el contador y un `ActionPill`
  con identifier `gifts.chest.open`. Sólo visible con `pendingChestCount > 0`.
- [ ] **Step 2**: `showsBadge` de la pestaña de Regalos pasa a incluir `pendingChestCount > 0`.
- [ ] **Step 3**: strings `gifts.section.chests`, `gifts.chest.count %lld`, `gifts.chest.open`
  a mano en es+en.
- [ ] **Step 4**: correr `BonusHUDUITests` (la fila del video se movió hacia abajo) y commitear.

---

### Task 10: Pintas — el carrusel deja de perder pintas

**Files:**
- Modify: `FisuEvolution/UI/Skins/CustomizationView.swift`
- Modify: `FisuEvolution/Game/State/GameState+Upgrades.swift` o `+Store.swift`
- Test: `FisuEvolutionTests/SkinCatalogRowsTests.swift`

- [ ] **Step 1: El test que falla**

```swift
@Test("un personaje que no viste en esta partida aparece igual si tenés una pinta suya")
func carouselShowsCharactersWithOwnedSkins() {
    // seenTypes = [homeless] (recién reencarnado), milestoneSkins = ["oraculo"] (deidad)
    // → la lista tiene que traer a `deidad`.
}
```

- [ ] **Step 2**: una proyección nueva `skinnableTypes` = `seenTypes ∪ {tipos con skin
  poseída}`, ordenada por tier como la de hoy. `CustomizationView` la usa en lugar de
  `characterUpgradeTypes`. ⚠️ **No cambiar `characterUpgradeTypes`**: la pantalla de mejoras
  sí tiene que mostrar sólo lo visto, porque ahí se compra.
- [ ] **Step 3**: correr `CustomizationUITests` y commitear.

---

### Task 11: El cofre de bienvenida y el tutorial

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift` (`tutorialPhaseFinished`)
- Modify: `FisuEvolution/Game/State/GameState+TutorialTips.swift`
- Modify: `FisuEvolution/Game/State/GameState+Chests.swift`
- Test: `FisuEvolutionTests/ChestSourcesTests.swift`, `FisuEvolutionUITests/TutorialUITests.swift`

- [ ] **Step 1**: en `tutorialPhaseFinished()`, si `!meta.welcomeChestGiven`, otorgar el
  cofre de bienvenida y marcar la bandera. Su premio es **fijo**: `content.chests.welcomeSkinId`
  —hoy la pinta del Cartonero, el personaje que el jugador acaba de fusionar—, no una tirada.
  ⚠️ **Se lee del config, no se escribe el id en Swift**: es la constraint global de
  data-driven, y esta es la única skin que el código tendría motivo para nombrar. Se abre
  solo porque la cola lo promueve apenas cae la restricción.
- [ ] **Step 2**: la lección `.skins` cambia de gatillo — de "hay una skin de milestone
  ganada" a "hay un cofre abierto" (o sea, `!meta.milestoneSkins.isEmpty ||
  meta.welcomeChestGiven`). ⚠️ La regla de oro del tutorial es del dueño y es criterio de
  aceptación: **ninguna lección manda a una pantalla donde en ese momento no hay nada que
  hacer**.
- [ ] **Step 3**: correr `TutorialUITests` completo y commitear.

---

### Task 12: Cierre — verificación y documentación

- [ ] **Step 1**: `xcodegen generate` y build limpio, **cero warnings**.
- [ ] **Step 2**: `swift test --package-path Packages/EconomyKit` — todo verde.
- [ ] **Step 3**: unit de la app — sólo los rojos declarados (11 StoreKit + `PacingTests`).
- [ ] **Step 4**: suite de UI completa.
- [ ] **Step 5**: correr el juego en el simulador y **abrir un cofre de verdad**, con
  captura. Ningún sistema de animación se da por bueno sin haberlo mirado.
- [ ] **Step 5b — decidir qué pasa con `floorReached`.** Desde la Task 1 quedó soportado en
  `SkinsConfig` pero **sin un solo dato que lo ejerza**, y con él quedaron sin alcanzar dos
  ramas de producción: `GameState+Store.swift:119-122` (`skins.unlock.floor`) y
  `CharacterSheetView.swift:245-246` (`character.skin.reach-floor`). El mecanismo sigue
  cubierto en EconomyKit con configs sintéticos, así que **no es un bug**: es una decisión.
  Las dos salidas son sacarlo (con su bump de validación y sus dos claves de i18n) o dejarlo
  documentado como criterio disponible para contenido futuro. **Elegir una y anotarla**;
  dejarlo sin decidir es cómo el código junta ramas muertas.
- [ ] **Step 5c — verificar los dos logros de skins.** `ach_skins_5` y `ach_skins_20`
  (`achievements.json`, trigger `skinsOwned`) perdieron su fuente principal cuando las 41
  dejaron de darse por piso, y **ningún test se pone rojo por eso**: `AchievementEngineTests`
  siembra `milestoneSkins` sintéticamente. Con los cofres andando tienen que volver a ser
  alcanzables — jugando, no leyendo el JSON.
- [ ] **Step 6**: los tres documentos del sistema de handoffs — `Docs/SESION-2026-08-26-…`,
  `handoffs/HANDOFF-…` y las **cuatro** ediciones de `Docs/HANDOFF.md` (§4 arriba, §5 si
  algo quedó decidido, §7 si hubo trampa, §9 el mapa).

---

## Generación de arte

Los 7 prompts están dados de alta en `Tools/asset-pipeline/prompts/gemini_pro/` (324-330) y
en `prompts.json` (commit `fb5ce2b`). Para generarlos:

```bash
cd /Users/manuader/Desktop/projects/fisu-wt-cofres/Tools/asset-pipeline && .venv/bin/python scripts/batch_uno_por_uno.py --filtro _chest_
```

```bash
cd /Users/manuader/Desktop/projects/fisu-wt-cofres/Tools/asset-pipeline && .venv/bin/python scripts/batch_uno_por_uno.py --filtro fx_
```

Dos corridas porque `--filtro` toma **una** subcadena. Antes hay que tener el Chrome
dedicado en `:9222` (`scripts/launch_gemini_chrome.py` del checkout **principal**, que es el
que tiene el perfil logueado).

⚠️ **Hay dos assets pendientes que NO son de esta tarea** (`117_fisura_point`,
`118_fisura_explain`). Por eso los filtros, y por eso no se corre el batch pelado.

⚠️ **Un agente no puede correr el batch y seguir trabajando**: el runner tipea con
keystrokes de macOS y necesita el foco; la propia app de Claude se lo roba y la corrida
aborta. O lo corre el dueño con los frontends cerrados, o la sesión queda muda mientras dura.

⚠️ **Debe correrse desde `Terminal.app`** (o con un `.command` lanzado con `open`): el
permiso de Accesibilidad de `osascript` está otorgado a Terminal, y desde el shell de un
agente falla con "osascript is not allowed to send keystrokes (1002)".
