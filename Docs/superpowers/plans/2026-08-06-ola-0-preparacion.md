# Ola 0 — preparación que destraba el paralelismo

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dejar el repo en un estado donde seis frentes puedan trabajar en simultáneo sin pisarse, y de paso cerrar tres arreglos chicos que viven justo en el código que hay que tocar.

**Architecture:** cuatro frentes que **no comparten un solo archivo**. F1 parte `GameState.swift` (1.493 líneas) en extensiones por dominio y cablea los SFX huérfanos; F2 crea la pieza de descripción de efectos como archivos nuevos; F3 no toca Swift (datos y prompts); F4 no toca Swift (archivos de audio). Al terminar, cada frente de la Ola 1 tiene su propio archivo de `GameState`.

**Tech Stack:** Swift 6 (strict concurrency `complete`), SwiftUI + SpriteKit, EconomyKit (SPM), XCTest/Swift Testing, xcodegen.

## Global Constraints

Copiadas de `Docs/HANDOFF.md` §2. Aplican a **todas** las tareas de este plan.

- El `.xcodeproj` **no se versiona**. Al agregar o borrar un archivo Swift es obligatorio correr `/opt/homebrew/bin/xcodegen generate`.
- **Cero warnings**: `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`. Un warning rompe el build.
- Strings nuevos van a `FisuEvolution/Resources/Localizable.xcstrings` (es base + en), **en el mismo commit que su vista**.
- **No editar el catálogo de strings con scripts.** Xcode lo reescribe a su formato canónico en el primer build; si pasa, commitear el reformateo aparte.
- **Accessibility identifier** en todo control interactivo.
- Commits **en español**, atómicos.
- El mundo del juego es `@MainActor`. Nada de `Timer` para trabajo del frame loop. EconomyKit es puro y `Sendable`.
- Prefijo de claves de localización **por frente**, para que el catálogo mergee solo: F2 usa `effect.*`.

**Verificación de referencia** (la corrida completa, para el final de cada frente):

```bash
cd Packages/EconomyKit && swift test
```

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test
```

Estado de partida: **EconomyKit 144 · app 90 · UI 10 · pipeline 20**, todo verde. Ninguna tarea de este plan puede bajar esos números.

---

## Frente F1 — Partir GameState, cablear el audio huérfano, invertir el scroll

Un solo agente. Es el frente que destraba a los otros seis de la Ola 1.

### Task 1: Partir `GameState.swift` en extensiones por dominio

**Files:**
- Modify: `FisuEvolution/Game/State/GameState.swift` (1.493 líneas, 16 secciones `// MARK:`)
- Create: `FisuEvolution/Game/State/GameState+Tower.swift`
- Create: `FisuEvolution/Game/State/GameState+Actions.swift`
- Create: `FisuEvolution/Game/State/GameState+Prestige.swift`
- Create: `FisuEvolution/Game/State/GameState+Store.swift`
- Create: `FisuEvolution/Game/State/GameState+Bonus.swift`
- Create: `FisuEvolution/Game/State/GameState+Upgrades.swift`
- Create: `FisuEvolution/Game/State/GameState+Debug.swift`

**Interfaces:**
- Consumes: nada.
- Produces: los siete archivos de arriba. Cada frente de la Ola 1 es dueño de uno:
  `+Tower` → frente C · `+Upgrades` → frente B · `+Bonus` → frente D ·
  `+Prestige` → frente F · `+Store` → frente G1a · `+Actions` → frente D (sólo `chooseCareer`).

**Regla del corte** — qué queda y qué se va:

| Sección `// MARK:` actual | Destino |
|---|---|
| `Observed projections (UI)` | **queda** en `GameState.swift` (Swift no permite propiedades almacenadas en extensiones) |
| `Authoritative state` | **queda** |
| `Bootstrap` | **queda** |
| `Frame loop (called by BoardScene)` | **queda** |
| `Lifecycle (offline + immediate save)` | **queda** |
| `Internals` | **queda** |
| `Tower accessors (scene + views)` | `GameState+Tower.swift` |
| `Player actions` | `GameState+Actions.swift` |
| `Reencarnación` | `GameState+Prestige.swift` |
| `Store (F4)` | `GameState+Store.swift` |
| `Rewarded ads`, `Boosts`, `Eventos`, `Daily + shares` | `GameState+Bonus.swift` |
| `Upgrades` | `GameState+Upgrades.swift` |
| `Debug helpers` | `GameState+Debug.swift` |

Los tipos anidados (`CareerPrompt`, `CharacterSheet`, `HireOffer`, `TowerNavigation`, `TowerNotice`, `SkinAward`, `OfflineReward`, `Phase`) **se quedan en `GameState.swift`**: los usan las proyecciones observadas, que no se mueven.

**Este task no cambia ninguna conducta.** Es mover código entre archivos. La red que lo prueba son los 90 tests de la app y los 10 de UI que ya existen.

- [ ] **Step 1: Correr la suite entera y anotar los números de partida**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test 2>&1 | tail -20
```

Esperado: la suite pasa. Anotar cuántos tests corrieron — ese número tiene que ser idéntico al final del task.

- [ ] **Step 2: Crear los siete archivos, uno por vez, moviendo su sección**

Cada archivo arranca con este esqueleto (ejemplo con `+Tower`; repetir el patrón cambiando el nombre y el comentario):

```swift
import EconomyKit
import Foundation

/// Accesores de la torre que consumen la escena y las vistas. Separado de
/// `GameState.swift` para que el frente de navegación no comparta archivo con
/// los otros cinco dominios.
extension GameState {
    // ← acá va, textual, el contenido de la sección `// MARK: Tower accessors`
}
```

Mover **una** sección por vez y compilar entre cada una:

```bash
/opt/homebrew/bin/xcodegen generate && xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD build 2>&1 | grep -E "error:|warning:|BUILD" | head -20
```

Esperado: `BUILD SUCCEEDED`, cero `error:`, cero `warning:`.

Si una función movida usaba un `private` de `GameState.swift`, **no cambiarla a `internal` a ciegas**: mover también ese helper si pertenece al mismo dominio, y sólo si es usado por dos dominios distintos subirlo a `internal` en `GameState.swift` con un comentario que diga quién lo usa.

- [ ] **Step 3: Correr la suite entera y comparar contra el Step 1**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test 2>&1 | tail -20
```

Esperado: **exactamente el mismo número de tests, todos pasando**. Si bajó el número, un test dejó de compilarse o de descubrirse — no seguir hasta entenderlo.

- [ ] **Step 4: Verificar que `GameState.swift` quedó chico**

```bash
wc -l FisuEvolution/Game/State/GameState*.swift
```

Esperado: `GameState.swift` por debajo de 700 líneas, y ningún archivo nuevo arriba de 400.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/ project.yml
git commit -m "refactor: GameState se parte en extensiones por dominio

Eran 1.493 líneas y las tocan seis frentes a la vez. Cada dominio pasa a
su propio archivo para que el trabajo en paralelo no comparta archivo.
Las proyecciones observadas se quedan en GameState.swift porque Swift no
permite propiedades almacenadas en extensiones.

Cero cambio de conducta: mismos tests, mismo número, todos verdes."
```

---

### Task 2: Cablear los cinco SFX que existen y nunca suenan

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Actions.swift` (creado en Task 1)
- Modify: `FisuEvolution/Game/State/GameState+Upgrades.swift`
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift`
- Test: `FisuEvolutionTests/AudioWiringTests.swift` (crear)

**Interfaces:**
- Consumes: `AudioManager.SFX` (ya existe, 10 casos) y `AudioManager.play(_:)`.
- Produces: nada que otro frente consuma.

**El hallazgo**: `sfx_tap.caf`, `sfx_merge.caf`, `sfx_evolution.caf`, `sfx_coin.caf` y `sfx_error.caf` están en `FisuEvolution/Resources/Audio/` y **ningún call site los dispara**. Hoy sólo se tocan `.buy`, `.daily`, `.event`, `.prestige` y `.rare`. Además hay 14 `haptics?.play(...)` contra 9 `audio?.play(...)`: cinco acciones vibran y no suenan.

**El mapeo a cablear:**

| SFX | Cuándo suena |
|---|---|
| `.tap` | tap sobre un personaje que produce plata |
| `.merge` | merge exitoso que **no** sube de tier |
| `.evolution` | merge que sube de tier |
| `.coin` | cobrar las ganancias offline y el cofre del boost `asado` |
| `.error` | cada sitio que hoy hace `haptics?.play(.error)` sin audio |

- [ ] **Step 1: Escribir el test que falla**

`AudioManager` no es inyectable hoy, así que el test verifica el **cableado** por conteo: que ningún `haptics?.play(.error)` quede sin su `audio?.play(.error)` al lado, y que los cinco SFX huérfanos tengan al menos un call site.

```swift
import Testing
import Foundation

/// Cinco SFX venían en el bundle y no los disparaba nadie. Este test es el que
/// impide que vuelva a pasar: si alguien agrega un caso al enum y no lo cablea,
/// falla acá y no en una queja de playtest.
@Suite struct AudioWiringTests {
    private static func gameStateSources() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FisuEvolutionTests
            .deletingLastPathComponent()   // repo
            .appendingPathComponent("FisuEvolution/Game/State")
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        return try files
            .filter { $0.pathExtension == "swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    @Test("los diez SFX declarados tienen al menos un call site")
    func everySFXIsFired() throws {
        let sources = try Self.gameStateSources()
        let cases = ["tap", "merge", "evolution", "coin", "buy", "error", "rare", "prestige", "event", "daily"]
        let orphans = cases.filter { !sources.contains("audio?.play(.\($0))") }
        #expect(orphans.isEmpty, "SFX declarados que no dispara nadie: \(orphans)")
    }

    @Test("ninguna acción vibra sin sonar")
    func hapticsAndAudioAgree() throws {
        let sources = try Self.gameStateSources()
        let hapticErrors = sources.components(separatedBy: "haptics?.play(.error)").count - 1
        let audioErrors = sources.components(separatedBy: "audio?.play(.error)").count - 1
        #expect(hapticErrors == audioErrors, "\(hapticErrors) hápticas de error contra \(audioErrors) sonidos")
    }
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test -only-testing:FisuEvolutionTests/AudioWiringTests 2>&1 | tail -20
```

Esperado: **FALLA** con `SFX declarados que no dispara nadie: ["tap", "merge", "evolution", "coin", "error"]`.

- [ ] **Step 3: Cablear los cinco, siguiendo la tabla del task**

Al lado de cada `haptics?.play(...)` que corresponda, agregar su `audio?.play(...)`. Ejemplo del patrón que ya usa el código en el sitio de compra:

```swift
haptics?.play(.purchase)
audio?.play(.buy)
```

Los cuatro `haptics?.play(.error)` sin sonido quedan:

```swift
haptics?.play(.error)
audio?.play(.error)
```

Para `.tap` / `.merge` / `.evolution`, el sitio es el resultado del gesto: `.tap` en el manejo del tap sobre una unidad, y en el manejo del drop, `.evolution` cuando el merge sube de tier y `.merge` cuando no.

⚠️ `.tap` es el sonido más frecuente del juego. `AudioManager` ya tiene un throttle de 0,08 s que impide el solapamiento, así que no hace falta agregar otro. Si al probarlo resulta molesto, es el primer candidato a sacar — anotarlo en el commit, no removerlo por cuenta propia.

- [ ] **Step 4: Correr el test y verificar que pasa**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test -only-testing:FisuEvolutionTests/AudioWiringTests 2>&1 | tail -20
```

Esperado: **PASA**, los dos tests.

- [ ] **Step 5: Escuchar el juego a mano**

```bash
xcrun simctl install booted build/DD/Build/Products/Debug-iphonesimulator/FisuEvolution.app && xcrun simctl launch booted com.manuader.fisuevolution --uitest-reset
```

Tapear un personaje, mergear dos, y comprar algo sin plata. Los tres tienen que sonar distinto. Un test de conteo no prueba que el sonido correcto esté en el lugar correcto: esto sí.

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Game/State/ FisuEvolutionTests/AudioWiringTests.swift
git commit -m "fix(audio): suenan los cinco efectos que venían mudos

sfx_tap, sfx_merge, sfx_evolution, sfx_coin y sfx_error estaban en el
bundle desde el primer día y no los disparaba ningún call site: de los
diez SFX declarados sonaban cinco. Eran justo los de las acciones más
frecuentes, que es la mitad del 'agregar más efectos de sonido' del
playtest.

El test cuenta call sites por caso del enum, así que un SFX nuevo sin
cablear falla acá en vez de en la próxima queja."
```

---

### Task 3: Invertir el sentido del deslizamiento (RF-09)

**Files:**
- Modify: `FisuEvolution/Scenes/BoardScene.swift:289`
- Test: `FisuEvolutionTests/GameLoopWiringTests.swift` (existe)

**Interfaces:**
- Consumes: `GameState.moveVisibleFloor(by:) -> Bool` (existe, no cambia).
- Produces: nada.

**Hoy**, en `touchesEnded`:

```swift
if abs(deltaY) > 48, abs(deltaY) > abs(deltaX) * 1.5 {
    _ = gameState.moveVisibleFloor(by: deltaY > 0 ? 1 : -1)
}
```

`deltaY > 0` es el dedo yendo hacia **arriba** en coordenadas de escena, y hoy eso **sube** un piso: la metáfora es "deslizá hacia donde querés ir". El pedido es la metáfora de scroll de iOS: agarrás la torre y la movés, así que el dedo hacia **abajo** te **sube**.

- [ ] **Step 1: Escribir el test que falla**

Agregar a `FisuEvolutionTests/GameLoopWiringTests.swift`:

La suite `GameLoopWiringTests` ya es `@MainActor` y tiene el helper privado
`makeGameState() async -> GameState`, que hace `bootstrap()` sobre persistencia en
memoria. Para poder subir un piso hace falta que el de arriba esté desbloqueado:
el mismo archivo ya tiene tests que abren pisos (`moveVisibleFloor(by: 1)` en la
línea 41 y siguientes) — copiar de ahí la forma de dejar la torre en un estado
navegable en vez de inventar una nueva.

```swift
@Test("el deslizamiento usa la metáfora de scroll: dedo hacia abajo sube un piso")
func swipeDownGoesUp() async throws {
    let gameState = await makeGameState()
    // Dejar la torre navegable igual que los tests de navegación de este archivo.
    gameState.debugUnlockTower()
    let scene = BoardScene(gameState: gameState)   // se construye con su propio tamaño
    let startOrdinal = gameState.visibleFloorOrdinal

    scene.simulateSwipe(deltaY: -120)   // dedo hacia ABAJO
    #expect(gameState.visibleFloorOrdinal == startOrdinal + 1, "hacia abajo tiene que subir")

    scene.simulateSwipe(deltaY: 120)    // dedo hacia ARRIBA
    #expect(gameState.visibleFloorOrdinal == startOrdinal, "hacia arriba tiene que bajar")
}
```

⚠️ `debugUnlockTower()` es el nombre que usa el fixture `--uitest-unlock-tower`;
verificar cómo se llama de verdad en `GameState+Debug.swift` (creado en el Task 1)
antes de escribir el test, y usar ese. Si los tests de navegación existentes abren
la torre de otra forma, usar la de ellos.

Y en `BoardScene`, un punto de entrada testeable que ejecuta **la misma decisión** que el gesto (no una copia — si se duplica la regla, el test deja de proteger nada):

```swift
/// Decide a qué piso lleva un deslizamiento. Extraída de `touchesEnded` para
/// que el test pruebe la regla y no una copia de la regla.
func floorDelta(deltaX: CGFloat, deltaY: CGFloat) -> Int? {
    guard abs(deltaY) > 48, abs(deltaY) > abs(deltaX) * 1.5 else { return nil }
    // Metáfora de scroll: se agarra la torre y se la mueve. Dedo hacia abajo
    // (deltaY < 0 en coordenadas de escena) = subir.
    return deltaY > 0 ? -1 : 1
}

#if DEBUG
func simulateSwipe(deltaY: CGFloat) {
    if let delta = floorDelta(deltaX: 0, deltaY: deltaY) {
        _ = gameState.moveVisibleFloor(by: delta)
    }
}
#endif
```

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test -only-testing:FisuEvolutionTests/GameLoopWiringTests 2>&1 | tail -20
```

Esperado: **FALLA** en `swipeDownGoesUp` (hoy hace lo contrario).

- [ ] **Step 3: Reemplazar el cuerpo de `touchesEnded` para que use `floorDelta`**

```swift
if let delta = floorDelta(deltaX: deltaX, deltaY: deltaY) {
    _ = gameState.moveVisibleFloor(by: delta)
}
```

- [ ] **Step 4: Correr el test y verificar que pasa**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test -only-testing:FisuEvolutionTests/GameLoopWiringTests 2>&1 | tail -20
```

Esperado: **PASA**.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Scenes/BoardScene.swift FisuEvolutionTests/GameLoopWiringTests.swift
git commit -m "fix(torre): el deslizamiento usa la metáfora de scroll

Se deslizaba hacia donde uno quería ir; ahora se agarra la torre y se la
mueve, que es lo que hace cualquier lista de iOS. Dedo hacia abajo, subís.

La regla sale de touchesEnded a floorDelta(deltaX:deltaY:) para que el
test pruebe la decisión y no una copia de la decisión."
```

---

## Frente F2 — La pieza compartida de descripción de efectos

Un solo agente. **Archivos nuevos únicamente**: no toca ninguno de F1.

### Task 4: `EffectDescriptor` y su formateador

**Files:**
- Create: `FisuEvolution/Managers/EffectDescriptor.swift`
- Modify: `FisuEvolution/Managers/ContentSystems.swift` (extraer los caps a constantes con nombre)
- Modify: `FisuEvolution/Managers/ContentConfigs.swift` (agregar `CaseIterable` a los dos `EffectType`)
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (claves con prefijo `effect.*`)
- Test: `FisuEvolutionTests/EffectDescriptorTests.swift` (crear)

**Interfaces:**
- Consumes: `UpgradesConfig.EffectType`, `UpgradesConfig.Line`, `BoostsConfig.EffectType` y `BoostsConfig.Boost` — **los cuatro anidados** en `FisuEvolution/Managers/ContentConfigs.swift`. Ojo con esto: son dos enums `EffectType` **distintos**, uno por config, y ninguno de los dos es `CaseIterable` hoy.
- Produces — **esta es la firma que consumen los frentes B, D y F de la Ola 1**:

```swift
enum EffectUnit: Equatable { case percentBonus, percentDiscount, chance, multiplier }

struct EffectAmount: Equatable {
    let unit: EffectUnit
    /// 0,30 significa 30%. Para `.multiplier`, 2,5 significa ×2,5.
    let value: Double
    /// El cap de ContentSystems ya recortó este valor.
    let isCapped: Bool
}

enum EffectDescriptor {
    /// Mejoras permanentes: el efecto es aditivo por nivel.
    static func amount(for effectType: UpgradesConfig.EffectType, level: Int, magnitudePerLevel: Double) -> EffectAmount
    /// Boosts: el efecto es la magnitud sola, no depende de ningún nivel.
    static func amount(forBoost effectType: BoostsConfig.EffectType, magnitude: Double) -> EffectAmount
}

enum EffectFormatter {
    /// "+30%", "−9%", "3%", "×2,5"
    static func text(_ amount: EffectAmount) -> String
    /// "+30% → +40%", o sólo "+30%" cuando `next` es nil (nivel máximo).
    static func progression(current: EffectAmount, next: EffectAmount?) -> String
}
```

**Las dos tablas de traducción.** Mejoras (7 casos, aditivos por nivel):

| `UpgradesConfig.EffectType` | Unidad | Tope |
|---|---|---|
| `incomeMultiplier`, `tapMultiplier`, `prestigeBonusPerSoulPoint` | `.percentBonus` | — |
| `offlineEfficiency` | `.percentBonus` | 1,00 |
| `critChance` | `.chance` | 0,50 |
| `goldenTouchChance` | `.chance` | 0,10 |
| `spawnCostDiscount` | `.percentDiscount` | 0,60 |

Boosts (5 casos, magnitud directa). ⚠️ `spawnCostMultiplier` es un **factor de
costo**, no un descuento: el mate tiene magnitud 0,7, que hay que mostrar como
**−30%**, no como "0,7". Convertirlo con `1 − magnitud`.

| `BoostsConfig.EffectType` | Unidad | Valor a mostrar |
|---|---|---|
| `incomeMultiplier`, `tapMultiplier`, `periodicChest` | `.multiplier` | la magnitud tal cual |
| `spawnCostMultiplier` | `.percentDiscount` | `1 − magnitud` |
| `offlineEfficiencyPermanent` | `.percentBonus` | la magnitud tal cual |

**Por qué en la capa de app y no en EconomyKit**: `UpgradeEffectType` y los caps viven hoy en `ContentSystems.swift`/`ContentConfigs.swift`, que son de la app. Meter el descriptor en EconomyKit obligaría a mudar el enum y a que el paquete puro conozca el formato de presentación — justo lo que la regla de capas del HANDOFF prohíbe.

**La regla de acumulación, verificada en `ContentSystems.swift:67-102`**: los efectos son **aditivos por nivel** (`level × magnitudePerLevel`), con estos topes:

| Efecto | Tope |
|---|---|
| `critChance` | 0,50 |
| `offlineEfficiency` | 1,00 |
| `goldenTouchChance` | 0,10 |
| `spawnCostDiscount` | 0,60 |
| `incomeMultiplier`, `tapMultiplier`, `prestigeBonusPerSoulPoint` | sin tope |

- [ ] **Step 1: Escribir los tests que fallan**

```swift
import Testing
@testable import FisuEvolution

@Suite struct EffectDescriptorTests {
    @Test("nivel 0 no da efecto")
    func levelZeroIsNeutral() {
        let amount = EffectDescriptor.amount(for: UpgradesConfig.EffectType.incomeMultiplier, level: 0, magnitudePerLevel: 0.1)
        #expect(amount.value == 0)
        #expect(amount.isCapped == false)
    }

    @Test("los efectos se acumulan sumando por nivel")
    func levelsAddUp() {
        let amount = EffectDescriptor.amount(for: .incomeMultiplier, level: 3, magnitudePerLevel: 0.1)
        #expect(abs(amount.value - 0.3) < 0.0001)
        #expect(amount.unit == .percentBonus)
    }

    @Test("el descuento de contratación se muestra como descuento, no como bonus")
    func discountHasItsOwnUnit() {
        let amount = EffectDescriptor.amount(for: .spawnCostDiscount, level: 3, magnitudePerLevel: 0.03)
        #expect(amount.unit == .percentDiscount)
        #expect(abs(amount.value - 0.09) < 0.0001)
    }

    @Test("el tope de crítico recorta y lo declara")
    func critIsCapped() {
        // 25 niveles × 0,01 = 0,25; con magnitud inflada se pasa del tope de 0,50.
        let amount = EffectDescriptor.amount(for: .critChance, level: 25, magnitudePerLevel: 0.05)
        #expect(amount.value == 0.5)
        #expect(amount.isCapped, "pasarse del tope tiene que quedar declarado o la fila miente")
    }

    @Test("el formato usa el signo y el símbolo de cada unidad")
    func formatting() {
        #expect(EffectFormatter.text(EffectAmount(unit: .percentBonus, value: 0.3, isCapped: false)) == "+30%")
        #expect(EffectFormatter.text(EffectAmount(unit: .percentDiscount, value: 0.09, isCapped: false)) == "−9%")
        #expect(EffectFormatter.text(EffectAmount(unit: .chance, value: 0.03, isCapped: false)) == "3%")
    }

    @Test("la progresión muestra el salto, y al máximo muestra sólo el actual")
    func progression() {
        let current = EffectAmount(unit: .percentBonus, value: 0.3, isCapped: false)
        let next = EffectAmount(unit: .percentBonus, value: 0.4, isCapped: false)
        #expect(EffectFormatter.progression(current: current, next: next) == "+30% → +40%")
        #expect(EffectFormatter.progression(current: current, next: nil) == "+30%")
    }

    @Test("los siete tipos de mejora tienen unidad, ninguno cae en un default")
    func everyUpgradeEffectIsCovered() {
        for type in UpgradesConfig.EffectType.allCases {
            let amount = EffectDescriptor.amount(for: type, level: 1, magnitudePerLevel: 0.1)
            #expect(amount.value > 0, "\(type) no describe nada")
        }
    }

    @Test("los cinco tipos de boost tienen unidad")
    func everyBoostEffectIsCovered() {
        for type in BoostsConfig.EffectType.allCases {
            let amount = EffectDescriptor.amount(forBoost: type, magnitude: 2.0)
            #expect(amount.value != 0, "\(type) no describe nada")
        }
    }

    @Test("el boost de costo se muestra como descuento y no como factor")
    func boostCostMultiplierReadsAsDiscount() {
        // El mate tiene magnitud 0,7: contratar cuesta 0,7×, o sea 30% menos.
        let amount = EffectDescriptor.amount(forBoost: .spawnCostMultiplier, magnitude: 0.7)
        #expect(amount.unit == .percentDiscount)
        #expect(abs(amount.value - 0.3) < 0.0001, "0,7 tiene que leerse como −30%")
    }
}
```

⚠️ `UpgradesConfig.EffectType.allCases` y `BoostsConfig.EffectType.allCases` **no
existen todavía**: los dos enums son `String, Codable, Sendable` y les falta
`CaseIterable`. Agregárselo en `ContentConfigs.swift` es parte de este task — es
lo que convierte "cubrimos todos los casos" en algo que el compilador verifica en
vez de una promesa.

- [ ] **Step 2: Correr y verificar que fallan por no compilar**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test -only-testing:FisuEvolutionTests/EffectDescriptorTests 2>&1 | grep -E "error:|Testing" | head -10
```

Esperado: **FALLA** con `cannot find 'EffectDescriptor' in scope`.

- [ ] **Step 3: Extraer los caps de `ContentSystems.swift` a constantes con nombre**

Hoy los topes están escritos como literales sueltos en las líneas 99-102. Que el descriptor los duplique es la forma más fácil de que la fila mienta después de un cambio de balance. Crear en `EffectDescriptor.swift`:

```swift
/// Topes de los efectos acumulados. Son la MISMA fuente que usa
/// `ContentSystems.recomputeDerivedEffects`: si se duplican, la fila de la UI
/// termina prometiendo un efecto que la economía recorta.
enum EffectCaps {
    static let crit = 0.5
    static let offline = 1.0
    static let golden = 0.1
    static let spawnDiscount = 0.6
}
```

Y reemplazar los literales en `ContentSystems.swift`:

```swift
state.meta.derivedEffects.critChance = min(crit, EffectCaps.crit)
state.meta.derivedEffects.offlineEfficiency = min(offline, EffectCaps.offline)
state.meta.derivedEffects.goldenChance = min(golden, EffectCaps.golden)
state.meta.derivedEffects.spawnDiscount = min(spawnDiscount, EffectCaps.spawnDiscount)
```

- [ ] **Step 4: Implementar `EffectDescriptor` y `EffectFormatter`**

```swift
enum EffectUnit: Equatable { case percentBonus, percentDiscount, chance, multiplier }

struct EffectAmount: Equatable {
    let unit: EffectUnit
    let value: Double
    let isCapped: Bool
}

enum EffectDescriptor {
    static func amount(for effectType: UpgradesConfig.EffectType, level: Int, magnitudePerLevel: Double) -> EffectAmount {
        let raw = Double(level) * magnitudePerLevel
        switch effectType {
        case .incomeMultiplier, .tapMultiplier, .prestigeBonusPerSoulPoint:
            return EffectAmount(unit: .percentBonus, value: raw, isCapped: false)
        case .critChance:
            return EffectAmount(unit: .chance, value: min(raw, EffectCaps.crit), isCapped: raw > EffectCaps.crit)
        case .goldenTouchChance:
            return EffectAmount(unit: .chance, value: min(raw, EffectCaps.golden), isCapped: raw > EffectCaps.golden)
        case .offlineEfficiency:
            return EffectAmount(unit: .percentBonus, value: min(raw, EffectCaps.offline), isCapped: raw > EffectCaps.offline)
        case .spawnCostDiscount:
            return EffectAmount(unit: .percentDiscount, value: min(raw, EffectCaps.spawnDiscount), isCapped: raw > EffectCaps.spawnDiscount)
        }
    }

    static func amount(forBoost effectType: BoostsConfig.EffectType, magnitude: Double) -> EffectAmount {
        switch effectType {
        case .incomeMultiplier, .tapMultiplier, .periodicChest:
            return EffectAmount(unit: .multiplier, value: magnitude, isCapped: false)
        case .spawnCostMultiplier:
            // La magnitud es un FACTOR de costo (0,7 = cuesta 0,7×). Mostrarla
            // cruda deja al jugador leyendo "0,7" y adivinando si es bueno.
            return EffectAmount(unit: .percentDiscount, value: 1 - magnitude, isCapped: false)
        case .offlineEfficiencyPermanent:
            return EffectAmount(unit: .percentBonus, value: magnitude, isCapped: false)
        }
    }
}

enum EffectFormatter {
    static func text(_ amount: EffectAmount) -> String {
        let percent = Int((amount.value * 100).rounded())
        switch amount.unit {
        case .percentBonus: return "+\(percent)%"
        case .percentDiscount: return "−\(percent)%"   // menos tipográfico, no guion
        case .chance: return "\(percent)%"
        case .multiplier:
            let formatted = amount.value.formatted(.number.precision(.fractionLength(0...1)))
            return "×\(formatted)"
        }
    }

    static func progression(current: EffectAmount, next: EffectAmount?) -> String {
        guard let next else { return text(current) }
        return "\(text(current)) → \(text(next))"
    }
}
```

⚠️ Ninguno de los dos `switch` lleva `default`. Es a propósito: cuando alguien agregue un tipo de efecto nuevo, el compilador lo va a mandar acá en vez de dejarlo salir a pantalla sin descripción.

- [ ] **Step 5: Correr los tests y verificar que pasan**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test -only-testing:FisuEvolutionTests/EffectDescriptorTests 2>&1 | tail -20
```

Esperado: **PASAN los 7**.

- [ ] **Step 6: Agregar las claves `effect.*` al catálogo**

Abrir `FisuEvolution/Resources/Localizable.xcstrings` **desde Xcode** (no con un script — regla del HANDOFF) y agregar, con su traducción `es` y `en`:

| Clave | es | en |
|---|---|---|
| `effect.capped` | "al máximo" | "maxed out" |
| `effect.progression %@ %@` | "%1$@ → %2$@" | "%1$@ → %2$@" |

⚠️ Si alguna clave lleva un número, pasarlo como `String(x)`, **nunca como `Int`**: Swift manda `%lld`, el lookup falla y sale la clave cruda en pantalla. Ya pasó dos veces en este repo.

- [ ] **Step 7: Correr la suite entera y commitear**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test 2>&1 | tail -20
```

```bash
git add FisuEvolution/Managers/EffectDescriptor.swift FisuEvolution/Managers/ContentSystems.swift FisuEvolution/Managers/ContentConfigs.swift FisuEvolution/Resources/Localizable.xcstrings FisuEvolutionTests/EffectDescriptorTests.swift
git commit -m "feat(mejoras): pieza única que traduce un efecto a texto

Las mejoras, los boosts y el prestigio tienen que decir qué hacen y con
qué número. Sin una pieza compartida, tres frentes escriben tres
traducciones distintas del mismo efecto.

Los topes salen de ContentSystems a EffectCaps para que la fila de la UI
no prometa un efecto que la economía después recorta. El switch no lleva
default: un tipo de efecto nuevo tiene que romper el build acá."
```

---

## Frente F3 — Contenido: los 7 personajes y el remapeo de la torre

Un solo agente. **No toca Swift.**

### Task 5: Definir los 7 personajes nuevos y el remapeo 11 → 10 pisos

**Files:**
- Create: `Docs/superpowers/specs/2026-08-06-siete-personajes-y-remapeo.md`
- No modifica `tiers.json` ni `economy.json` todavía — eso es la Ola 2, después de que el arte exista.

**Interfaces:**
- Consumes: `FisuEvolution/Resources/Data/tiers.json` (37 tipos, 30 tiers), `FisuEvolution/Resources/Data/economy.json` (`floors[]`, 11 pisos).
- Produces: el documento de arriba, que la Ola 2 usa para tocar los JSON y el pipeline usa para generar el arte.

**La aritmética, ya cerrada en el spec** (`Docs/superpowers/specs/2026-08-06-correcciones-de-playtest-design.md` §3 RF-10):

- Zona terrenal (alley, urban, corporate, luxury, island): 17 tiers en 5 pisos → **+3 personajes** para llegar a 20.
- moon: ya tiene 4, no se toca.
- Zona cósmica (mars, solar, galaxy, cosmic): 8 tiers en 4 pisos → **+4 personajes** y **se retira 1 fondo**, para quedar en 12 tiers en 3 pisos.
- Resultado: 36 tiers no-Dios + Dios = **37 tiers en 10 pisos**, todos de 4 salvo el de Dios.

- [ ] **Step 1: Leer la cadena de evolución actual entera**

```bash
python3 -c "
import json
t=json.load(open('FisuEvolution/Resources/Data/tiers.json'))['types']
for x in sorted(t,key=lambda y:(y['tier'],y['id'])):
    print(f\"{x['tier']:>2} {x['id']:<22} {x['displayName']:<24} -> {x.get('mergesInto')}\")"
```

Hay que entender el humor y el arco antes de proponer nada: el juego va de El Fisura a Dios con humor argentino, y los 7 nuevos tienen que sonar como escritos por la misma persona.

- [ ] **Step 2: Escribir el documento con las tres decisiones**

El documento tiene que cerrar, sin dejar nada abierto:

1. **Los 7 personajes**: id, `displayName`, tier donde entra, en qué se mergea, y una línea de por qué es gracioso. Tres en la zona terrenal, cuatro en la cósmica.
2. **Qué fondo se retira** de los cuatro cósmicos (mars, solar, galaxy, cosmic) y por qué ése. Criterio sugerido: el que menos aporte al arco narrativo, sabiendo que son ~7 MB del `.app` cada uno.
3. **La tabla del mapeo final**: los 10 pisos con su rango `firstTier`–`lastTier` y su `incomeMultiplier`. Los multiplicadores de los pisos que absorben tiers nuevos hay que interpolarlos contra la curva actual — **no inventarlos**: la tabla vieja va de 1,0 a 620,0 en 11 escalones y la nueva tiene que ir de 1,0 a 620,0 en 10 sin saltos raros.

- [ ] **Step 3: Verificar la aritmética del mapeo propuesto**

```bash
python3 -c "
# Pegar acá la tabla propuesta como lista de (id, first, last)
pisos = [('alley',1,4), ('urban',5,8)]  # ← completar con los 10
noGod = [p for p in pisos if p[0] != 'god_realm']
assert all(p[2]-p[1]+1 == 4 for p in noGod), [p for p in noGod if p[2]-p[1]+1 != 4]
assert all(pisos[i][2]+1 == pisos[i+1][1] for i in range(len(pisos)-1)), 'hay un hueco o un solape'
assert pisos[0][1] == 1 and pisos[-1][2] == 37, 'la cobertura no es 1..37'
print('mapeo válido:', len(pisos), 'pisos')"
```

Esperado: `mapeo válido: 10 pisos`. Si tira `AssertionError`, la tabla está mal y **no** se pasa al siguiente step.

- [ ] **Step 4: Escribir los 52 prompts de Gemini**

En `Tools/asset-pipeline/prompts/gemini_pro/`, siguiendo el formato de los 93 que ya existen (cada `.md` con **archivo**, **estado**, **referencia**, **destino** y la sección `## Prompt`). Leer primero `Docs/HANDOFF-arte-gemini.md` y **tres prompts ya aprobados** para copiar el registro, y `Tools/asset-pipeline/scripts/cultural_dict.py`, que es la fuente del subject/props/expresión de cada asset.

Son:
- **7** de personaje de cuerpo entero, con `heroes/approved/fisura.png` como referencia de estilo.
- **43** de cara: primer plano con gesto gracioso, uno por tipo concreto (los **36** de hoy + los 7 nuevos), destino `<id>_face`. ⚠️ Son 36 y no 37 porque `junior` es el nodo de elección de carrera: `isChoiceNode: true`, sin sprite, y `TierRepository.concreteTypes` lo filtra.
- **2** de skin: una del Fisura y una de Dios, **outfit distinto, no un tinte de color** — es exactamente por lo que se retiraron las tres skins pagas anteriores.

- [ ] **Step 5: Contar los prompts y commitear**

```bash
ls Tools/asset-pipeline/prompts/gemini_pro/ | wc -l
```

Esperado: 52 archivos más que antes (los `.md` nuevos), más el `00_INDICE.md` actualizado.

```bash
git add Docs/superpowers/specs/2026-08-06-siete-personajes-y-remapeo.md Tools/asset-pipeline/prompts/
git commit -m "docs(contenido): los 7 personajes nuevos y el remapeo a 10 pisos

El playtest pidió mínimo 4 personajes por piso. La aritmética cierra con
7 tiers nuevos: 3 en la zona terrenal y 4 en la cósmica, que además
absorbe un fondo menos. Quedan 37 tiers en 10 pisos, todos de 4 salvo el
de Dios.

52 prompts nuevos para una sola corrida del runner: 7 personajes, 43
caras y 2 skins. Los JSON del juego NO se tocan todavía: eso es la Ola 2,
cuando el arte exista."
```

**Gate humano al terminar este task**: los nombres y el humor de los 7 los aprueba el dueño **antes** de que se genere una sola imagen.

---

## Frente F4 — Audio

Un solo agente. **No toca Swift.** Trabaja sólo sobre `FisuEvolution/Resources/Audio/`.

### Task 6: Dos loops de música nuevos y revisión de los diez efectos

**Files:**
- Modify: `FisuEvolution/Resources/Audio/music_earth_loop.caf`
- Modify: `FisuEvolution/Resources/Audio/music_cosmic_loop.caf`
- Modify (los que hagan falta): los diez `sfx_*.caf`

**Interfaces:**
- Consumes: los nombres de archivo que `AudioManager` busca. **Son contrato**: `music_earth_loop`, `music_cosmic_loop`, y `sfx_` + el `rawValue` de cada uno de los diez casos del enum. `AudioManager.url(forResource:)` prueba las extensiones `caf`, `m4a` y `wav`, en ese orden.
- Produces: nada de código.

⚠️ **No agregar casos al enum `AudioManager.SFX`.** Los diez que hay alcanzan, y el frente F1 los está cableando en paralelo: tocar ese archivo genera el único conflicto evitable de esta ola.

- [ ] **Step 1: Escuchar lo que hay y anotar qué está mal**

```bash
afplay FisuEvolution/Resources/Audio/music_earth_loop.caf
```

Los diez SFX están sintetizados por código (`Tools/audio-synth/generate_audio.py`) y suenan a eso. La música son dos loops de 1,7 y 2,3 MB. Anotar, archivo por archivo, qué falla: ¿es corto, es chillón, no loopea limpio, no pega con el tono del juego?

- [ ] **Step 2: Generar los dos loops nuevos**

El juego es un merge-idle con humor argentino que va del callejón a Dios. `music_earth_loop` acompaña la parte terrenal y `music_cosmic_loop` la cósmica. Requisitos duros:

- **Loopea sin costura**: el final tiene que empalmar con el principio. `AVAudioPlayer` con `numberOfLoops = -1` no hace crossfade.
- **Se escucha por horas**: es un idle. Sin ganchos que cansen en la décima repetición.
- **Peso**: no más de lo que pesa hoy (1,7 y 2,3 MB). Los fondos ya se comen 81 MB del `.app`.

- [ ] **Step 3: Reemplazar y verificar que el juego los levanta**

```bash
/opt/homebrew/bin/xcodegen generate && xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD build 2>&1 | grep -E "error:|BUILD" | head
```

```bash
xcrun simctl install booted build/DD/Build/Products/Debug-iphonesimulator/FisuEvolution.app && xcrun simctl launch booted com.manuader.fisuevolution --uitest-reset
```

Esperado: suena la música nueva. Si el juego quedó **en silencio**, el archivo tiene un nombre o un formato que `AudioManager` no encuentra: revisar el log, que imprime `audio asset missing (esperando gate de audio): <nombre>` una vez por clave faltante.

- [ ] **Step 4: Rehacer los SFX que lo necesiten**

Mismos nombres, mismas extensiones. Cortos (bajo 400 ms salvo `evolution` y `prestige`, que son celebraciones), y **distinguibles entre sí**: `merge` y `evolution` suenan uno detrás del otro cuando un merge asciende, así que no pueden confundirse.

- [ ] **Step 5: Verificar el peso y correr la suite**

```bash
du -sh FisuEvolution/Resources/Audio/ && ls -la FisuEvolution/Resources/Audio/
```

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test 2>&1 | tail -20
```

Esperado: la carpeta no creció de forma significativa, y la suite sigue verde (ningún test mira el audio, pero el bundle tiene que armarse).

- [ ] **Step 6: Commit**

```bash
git add FisuEvolution/Resources/Audio/
git commit -m "feat(audio): música nueva y efectos rehechos

Los dos loops eran los del gate de audio original y los diez efectos
estaban sintetizados por código. El playtest pidió cambiar la música y
que suene más cosa.

Mismos nombres de archivo: AudioManager los busca por rawValue del enum,
así que el contrato es el nombre y no se toca ni una línea de Swift."
```

---

## Qué queda listo al terminar la Ola 0

| Frente de la Ola 1 | Su archivo, ya creado |
|---|---|
| B · Menú de mejoras | `GameState+Upgrades.swift` + `EffectDescriptor` |
| C · Mapa de pisos | `GameState+Tower.swift` |
| D · Bonus y carrera | `GameState+Bonus.swift`, `GameState+Actions.swift` + `EffectDescriptor` |
| F · Prestigio | `GameState+Prestige.swift` + `EffectDescriptor` |
| G1a · Tienda | `GameState+Store.swift` |
| A2 · Arte | los 52 prompts, listos para una sola corrida |

Y cerrados, de paso: **RF-09** (el scroll), **RF-02a** (el diagnóstico de la tienda: no había bug, el `.storekit` declara un solo producto) y la mitad de **RF-14** (los cinco efectos que estaban mudos).
