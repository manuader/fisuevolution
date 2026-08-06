# Ola 2 — integrar el arte y rehacer el tutorial

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** meter al juego los 54 assets de la corrida de Gemini —8 personajes, 43 caras, 2 skins y el fondo regenerado— con la torre remapeada a 10 pisos, y rehacer el tutorial para que ilumine controles reales.

**Architecture:** dos frentes que no comparten un solo archivo. **A3** toca datos, generador y recursos; **H** toca una vista SwiftUI nueva. H va en esta ola y no antes porque ilumina los controles que la Ola 1 acaba de cambiar: hacerlo antes es hacerlo dos veces.

**Tech Stack:** Swift 6, SwiftUI + SpriteKit, EconomyKit, xcodegen, el pipeline de arte en Python.

## Precondición

**La corrida de Gemini tiene que estar hecha.** Es un gate humano: el runner usa `osascript`/System Events, que no funciona desde el shell de un agente (trampa 6 del HANDOFF). El comando, verificado contra el código del runner:

```bash
cd Tools/asset-pipeline && .venv/bin/python scripts/launch_gemini_chrome.py
```

```bash
cd Tools/asset-pipeline && .venv/bin/python scripts/gemini_selenium_runner.py --process --ref-threshold 5
```

- `--process` integra y archiva **cada asset apenas se genera**, no al final. Es **obligatorio**: 43 caras adjuntan como referencia el cuerpo de su propio personaje, y 8 de esos cuerpos se generan en la misma cola. Sin esto, esas caras salen sin referencia.
- `--ref-threshold 5` baja el filtro que descarta una imagen por "ser la referencia adjunta". El default de 12 es holgado cuando la referencia es **otro** personaje; con caras y skins la referencia es **el mismo**, y a 12 el filtro se come el resultado legítimo.
- El runner saltea los que ya están en `hecho` y lleva checkpoint en `state/selenium-run.json`, así que se puede cortar y retomar.

## Global Constraints

- El `.xcodeproj` **no se versiona**: `/opt/homebrew/bin/xcodegen generate` al agregar o borrar Swift.
- **Cero warnings**: `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`.
- **Accessibility identifier** en todo control interactivo.
- Strings a `Localizable.xcstrings` (es + en), **desde Xcode, nunca con script**. Prefijo por frente: **H** usa `tutorial.*`.
- Claves con `%@` interpoladas con un `Int` salen como la clave cruda: pasá `String(x)`.
- Commits **en español**.
- ⚠️ **El build incremental NO recompila los atlas.** Si medís páginas de atlas o peso del `.app` y no cierran, borrá `build/DD`.

---

## Frente A3 — Integrar el arte y remapear la torre

Cierra la parte de contenido de **RF-05**, **RF-10** y **RF-13**.

**La fuente de verdad de este frente es `Docs/superpowers/specs/2026-08-06-siete-personajes-y-remapeo.md`.** Tiene la cadena final, el bloque `floors[]` listo para pegar y la tabla completa de `mergesInto`. **No re-derives nada**: si algo no cierra, es un bug del documento y hay que decirlo, no improvisar.

**Files:**
- Modify: `Tools/generate-tiers/Sources/main.swift`
- Regenerate: `FisuEvolution/Resources/Data/tiers.json`
- Modify: `FisuEvolution/Resources/Data/economy.json`, `assets_manifest.json`
- Modify: `FisuEvolution/Resources/Config/skins.json`
- Delete: `FisuEvolution/Resources/Backgrounds/bg_cosmic@2x.png` y `@3x.png`
- Test: `FisuEvolutionTests/GameContentValidationTests.swift` (existe), `ExtensibilityDrillTests.swift` (existe)

### Task A3.1: La cadena nueva en el generador

⚠️ **`tiers.json` NO se edita a mano: se genera.** La cadena vive como lista de `CulturalEntry` en `Tools/generate-tiers/Sources/main.swift` (`kiosco` está en la línea 51). Editar el JSON directo lo pisa la próxima regeneración.

- [ ] **Step 1: Escribir el test que falla**

En `GameContentValidationTests.swift`:

```swift
@Test("la torre cubre 1…37 sin huecos y ningún piso no-Dios tiene menos de 4 tiers")
func towerCoverageAfterRemap() throws {
    let content = try GameContentLoader.loadBundled()
    let floors = content.economy.floors
    #expect(floors.count == 10)
    for floor in floors where floor.id != "god_realm" {
        #expect(floor.lastTier - floor.firstTier + 1 == 4, "\(floor.id) no tiene 4 tiers")
    }
    #expect(floors.first?.firstTier == 1)
    #expect(floors.last?.lastTier == 37)
    for (a, b) in zip(floors, floors.dropFirst()) {
        #expect(a.lastTier + 1 == b.firstTier, "hueco o solape entre \(a.id) y \(b.id)")
    }
}

@Test("kiosco ya no existe en ningún lado")
func kioscoIsGone() throws {
    let content = try GameContentLoader.loadBundled()
    #expect(content.tiers.types.allSatisfy { $0.id != "kiosco" })
    #expect(content.skins.skins.allSatisfy { $0.id != "kiosco__nocturno" })
    #expect(content.manifest.keys.allSatisfy { !$0.hasPrefix("kiosco") })
}
```

⚠️ Verificá la API real de `GameContentLoader` antes de escribir esto: lo que importa es cargar el contenido bundleado y asertar sobre él, no la firma exacta que puse.

- [ ] **Step 2: Correr y verificar que falla**

```bash
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test -only-testing:FisuEvolutionTests/GameContentValidationTests 2>&1 | tail -20
```

Esperado: **FALLA** — hay 11 pisos y `kiosco` sigue vivo.

- [ ] **Step 3: Editar el generador**

Tres cosas, todas contra la tabla del spec:

1. **Borrar** la `CulturalEntry` de `kiosco`.
2. **Agregar** las 8 nuevas, con su `phase` y su `spritePlaceholder` (la tabla del spec §3 los tiene).
3. **Rewirear los `mergesInto`** de la tabla del spec §5. Son 14 entradas, incluida la baja.

- [ ] **Step 4: Regenerar y mirar el diff**

```bash
cd Tools/generate-tiers && swift run generate-tiers
```

```bash
git diff --stat FisuEvolution/Resources/Data/tiers.json
```

⚠️ La curva de `passiveYieldPerInstance`, `passiveUnlockCost` y `tapYield` es geométrica de razón **×2,8** por tier. Los tiers nuevos **no se calculan a mano**: se insertan en su posición y el generador re-deriva la cadena entera con la misma razón. Si el diff muestra que la razón cambió, el generador está mal usado.

- [ ] **Step 5: Pegar el `floors[]` nuevo en `economy.json`**

El bloque está escrito y listo en el spec §5. **Copialo tal cual**: preserva `capacity`, el `hireCostMultiplier: 50` del callejón y los cuatro `backgroundOffset` (`urban` 0.135, `island` 0.18, `moon` 0.12, `mars` 0.118).

- [ ] **Step 6: Correr los tests y verificar que pasan.**
- [ ] **Step 7: Commit.**

### Task A3.2: Los assets nuevos y los que se retiran

- [ ] **Step 1: Verificar que la corrida dejó todo**

```bash
python3 -c "
import json
m=json.load(open('FisuEvolution/Resources/Data/assets_manifest.json'))
keys=set(m if isinstance(m,list) else (m.get('assets') or m).keys())
nuevos=['trapito','limpiavidrios','mantero','rey_asteroides','fondo_buitre','rentista_soles','estanciero_estelar','coleccionista_galaxias']
faltan=[k for k in nuevos if k not in keys]
sin_cara=[k for k in keys if not k.endswith('_face')]
print('cuerpos que faltan:', faltan)
print('caras en el manifest:', len([k for k in keys if k.endswith('_face')]))"
```

Esperado: **cero cuerpos faltantes** y **43 caras**. Si falta alguno, la corrida quedó incompleta: retomala antes de seguir, no integres a medias.

- [ ] **Step 2: Borrar `bg_cosmic` y sacarlo del manifest**

```bash
git rm FisuEvolution/Resources/Backgrounds/bg_cosmic@2x.png FisuEvolution/Resources/Backgrounds/bg_cosmic@3x.png
```

Y la entrada del manifest. ⚠️ Sin entrada en el manifest, el código cae a placeholder programático **sin romperse** — o sea que un fondo huérfano no falla ningún test. Por eso el borrado va explícito.

- [ ] **Step 3: Sacar el sprite de `kiosco` y su skin**

`kiosco` sale de `earth.atlas`, del manifest y de `skins.json` (la entrada `kiosco__nocturno`, que queda sin personaje al que aplicarse).

- [ ] **Step 4: Agregar las 2 skins pagas a `skins.json`**

`homeless__mundialista` y `god__parrillero`. **Sólo el catálogo**: venderlas es del frente G1b, en la Ola 3.

- [ ] **Step 5: Decidir sobre `bg_galaxy`**

La corrida regeneró el fondo hacia el registro divino. **Si salió peor que el actual, no se integra y se queda el viejo** — está escrito así en el prompt 212 y es una decisión del dueño. Mirá las dos imágenes al lado y decidí; si no está claro, preguntá.

- [ ] **Step 6: Correr todo con `build/DD` borrado**

```bash
rm -rf build/DD && xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build/DD test 2>&1 | tail -20
```

El borrado es obligatorio: **el build incremental no recompila los atlas**, así que sin eso no estás probando el arte nuevo.

- [ ] **Step 7: Medir el peso del `.app` y anotarlo**

```bash
du -sh build/DD/Build/Products/Debug-iphonesimulator/FisuEvolution.app
```

Antes de esto era **135 MB en Debug**. Suben 8 personajes y 43 caras, baja un fondo (~7 MB). Anotá el número en `Docs/HANDOFF-perf.md` junto al viejo.

- [ ] **Step 8: Commit.**

### Task A3.3: Que los saves viejos sobrevivan

- [ ] **Step 1: Escribir el test que falla**

```swift
@Test("un save con el mapeo de 11 pisos carga y reacomoda sus unidades")
func oldSaveSurvivesTheRemap() throws {
    // Save con unidades de un tipo que existe y otro que se eliminó (kiosco).
    var state = PlayerState.newGame(startTypeId: "homeless", startFloorId: "alley")
    state.run.units = ["homeless": 3, "kiosco": 2]
    let tower = TowerReconciler.rebuild(from: state, tiers: tiers, floorTable: floorTable)
    #expect(tower.totalUnits == 3, "las unidades de un tipo eliminado se descartan, no rompen la carga")
}
```

- [ ] **Step 2: Correr, verificar que falla o que ya pasa.** `TowerReconciler` se construyó exactamente para esto —recalcula la ubicación contra el mapeo vigente en cada carga—, así que puede pasar de una. **Si pasa sin tocar nada, dejá el test igual**: es la red que protege el próximo remapeo.
- [ ] **Step 3: Si falla, arreglar `TowerReconciler` para que descarte tipos desconocidos en vez de crashear.**
- [ ] **Step 4: Commit.**

---

## Frente H — El tutorial interactivo (RF-01)

**Files:**
- Rewrite: `FisuEvolution/UI/Tutorial/TutorialOverlay.swift`
- Create: `FisuEvolution/UI/Tutorial/SpotlightShape.swift`
- Modify: `FisuEvolution/Resources/Localizable.xcstrings` (prefijo `tutorial.*`)
- Test: `FisuEvolutionUITests/TutorialUITests.swift`

**Hoy** es un scrim negro al 72% + una pose del Fisura abajo a la izquierda + un globo. Se toca **en cualquier lado** para avanzar los 7 pasos. No señala ningún control real y no exige ninguna acción. El playtest lo llamó *"re villero"* y pidió que se viera *"estilo clash royale/clash of clans"*.

### Task H1: El recorte iluminado

- [ ] **Step 1: Construir `SpotlightShape`**

Un `Shape` que es la pantalla entera menos un agujero (círculo o rectángulo redondeado) sobre el control a iluminar, con `.evenOdd` como fill rule. El scrim se dibuja con esa forma, así que el agujero queda transparente.

- [ ] **Step 2: Resolver la posición del control real**

El agujero tiene que caer sobre el control **de verdad**, no sobre coordenadas escritas a mano: un botón que se mueve deja el tutorial apuntando al vacío. Usá `GeometryReader` con un `PreferenceKey` que cada control candidato publica con su frame en coordenadas globales.

⚠️ Los controles que el tutorial ilumina cambiaron en la Ola 1: el menú de mejoras tiene **dos botones por fila**, hay un **botón de mapa** nuevo en el HUD y un **indicador de prestigio**. Mirá el HUD real antes de escribir los pasos.

- [ ] **Step 3: El resto de la pantalla no responde al toque**

Sólo el agujero. Es lo que hace que el paso no se pueda saltear sin hacer la acción.

- [ ] **Step 4: Commit.**

### Task H2: Avanzar por acción, no por toque

- [ ] **Step 1: Escribir el test de UI que falla**

```swift
func testElTutorialExigeLaAccion() {
    let app = XCUIApplication()
    app.launchArguments = ["--uitest-reset"]
    app.launch()

    // Tocar fuera del recorte no avanza.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
    XCTAssertTrue(app.otherElements["tutorial.step.0"].exists, "tocar afuera no puede avanzar el paso")

    // Hacer la acción sí.
    app.buttons["spawn.button"].tap()
    XCTAssertTrue(app.otherElements["tutorial.step.1"].waitForExistence(timeout: 3))
}
```

⚠️ Trampa 2 del HANDOFF: **un test de UI puede pasar sin probar nada.** Asertá el efecto (que el paso cambió), no que el toque no crasheó. Y trampa 4: *"Failed to scroll to visible" casi nunca es el botón, es algo modal tapándolo* — exportá los attachments del xcresult y mirá la captura.

- [ ] **Step 2: Correr y verificar que falla.**
- [ ] **Step 3: Cablear cada paso a su acción.** Cada paso declara qué control ilumina y qué evento lo completa. El botón de saltear y el `AppStorage` de "ya lo vi" se conservan.
- [ ] **Step 4: Correr y verificar que pasa.**
- [ ] **Step 5: Commit.**

### Task H3: La presentación

- [ ] **Step 1: La mano que late**

Sobre el agujero, con `.repeatForever`. ⚠️ Con `UIAccessibility.isReduceMotionEnabled` **no late**, y las transiciones colapsan. El HANDOFF ya tiene el antecedente: la secuencia de celebraciones encadena por completion y no por delays justamente porque con Reduce Motion las duraciones colapsan.

- [ ] **Step 2: Rehacer globo, tipografía y transiciones** al nivel del resto del juego.
- [ ] **Step 3: Jugarlo entero en el simulador, con y sin Reduce Motion.** Un test no ve si se ve villero.

```bash
xcrun simctl install booted build/DD/Build/Products/Debug-iphonesimulator/FisuEvolution.app && xcrun simctl launch booted com.manuader.fisuevolution --uitest-reset
```

- [ ] **Step 4: Commit.**

---

## Qué queda después de esta ola

| Ola | Qué |
|---|---|
| **3** | **RF-07 + RF-10** en una sola corrida de `pacing-sim`, con `PacingTests` repineado · **G1b**: vender las 2 skins contra el StoreKit local |
| **4** | **RF-02c**: alta de productos en App Store Connect. Lo único bloqueado por la cuenta de Apple Developer |

⚠️ **El rebalance va solo y al final** porque es lo único que necesita el juego entero armado para poder medir. Alargar la torre 7 tiers multiplica el techo por `2,8^7 ≈ 1.349×`, y eso mueve el mismo número que el exponente del ORO: medidos por separado dan dos resultados que se contradicen.
