# HANDOFF — Optimización de fluidez

> Para el agente que retoma. Fecha: 2026-08-04. Último commit de este trabajo:
> `081f6b7`. Leé también `Docs/HANDOFF-F7-estado.md` (estado del juego) y
> `Docs/HANDOFF-arte-gemini.md` (pipeline de arte).

---

## 0. Qué se pidió

El dueño reportó que el juego "va un poco laggeado (por lo menos en el
simulador)" y pidió optimizar la fluidez, **especialmente de la interfaz
gráfica**, con dos restricciones explícitas: **no romper nada** y **no cambiar
la funcionalidad**.

El plan completo (5 fases) está aprobado y vive en
`~/.claude/plans/lee-docs-handoff-f7-estado-md-y-todo-zany-quiche.md`.
**Fases 0, 1 y 2 están HECHAS y commiteadas. Faltan 3, 4 y 5.**

---

## 1. La causa raíz (esto es lo importante de entender)

No era el código: **todos los PNG del juego medían 1024² (@2x) o 1536² (@3x),
sin una sola excepción**. Un ícono de moneda de 26 pt pesaba exactamente lo
mismo que un fondo de pantalla completa.

Eso **rompía el texture atlas**, que es lo que no era obvio: el límite de página
de un atlas es 2048 px, así que **dos imágenes de 1536 no entran juntas** y el
packer terminaba poniendo **una imagen por página**. Verificado leyendo el
`.atlasc` compilado: 42 páginas para 42 personajes. Con una imagen por página el
atlas no agrupa nada, cada sprite en pantalla es su propio draw call
irreducible, y cada uno arrastra ~9,5 MB de VRAM.

Segundo hallazgo importante: **una parte del lag es artefacto de Debug**
(`-Onone` + `SWIFT_STRICT_CONCURRENCY: complete` conserva chequeos de
aislamiento en runtime) **y del simulador**, que no tiene render por tiles ni
memoria unificada. **Nunca se llegó a medir en Release sobre device.** Eso sigue
pendiente y conviene hacerlo antes de invertir en las fases que quedan, para no
optimizar lo que ya se arregla solo.

---

## 2. Baseline medido (antes de tocar nada)

| Métrica | Valor |
|---|---|
| fps en reposo (17 nodos) | 58 |
| fps con tablero poblado (65 nodos) | 56 |
| Peso del `.app` (Debug) | 278 MB |
| Assets en disco | 230 MB |
| Páginas `earth.atlasc` @3x | 42 (una por personaje) |
| Páginas `ui.atlasc` @3x | 58 |

Capturas del baseline: `scratchpad/qa-shots/perf-baseline-debug.png`.

---

## 3. Lo que YA SE HIZO (commit `081f6b7`)

### Fase 2 — Reescalado de assets (la que más rindió)

`Tools/asset-pipeline/scripts/rightsize_assets.py` **(nuevo)**. Reescala in-place
según el uso real:

| Grupo | Antes | Ahora |
|---|---|---|
| Personajes, specials, skins | 1024/1536 | **384/512** |
| Íconos y botones de UI | 1024/1536 | **192/256** |
| Paneles, retratos de tutorial, logo | 1024/1536 | **448/640** |
| **Fondos** | 1024/1536 | **SIN TOCAR** |

**Por qué los fondos no se tocan:** son el único grupo **sub-muestreado** — se
dibujan magnificados ~1,9× (fuente de 512 pt estirada a 1005 pt), así que
reducirlos los empeoraría visualmente. Su problema es la **proporción**: son
cuadrados 1:1 para una pantalla 9:19.5, o sea ~54% de los píxeles nunca se ven.
Eso se trata en la Fase 3, junto con el cambio de `FloorNode`.

`Tools/asset-pipeline/scripts/process_dropbox.py` aprendió los mismos tamaños en
`export_size(category, asset_key)`. **Esto era imprescindible**: sin eso, las 32
skins que faltan generar volvían a entrar en 1536 y reintroducían todo el
problema. Si tocás un tamaño, tocá los dos archivos o los assets nuevos
desentonan con los integrados.

### Fase 1 — Podas de trabajo repetido (ninguna cambia comportamiento)

- **`FisuEvolution/App/RootView.swift`**: la `SpriteView` ahora pasa
  `options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]`. Sin
  `ignoresSiblingOrder` SpriteKit debe respetar el orden del árbol y **no puede
  fusionar draw calls**. Es seguro porque el orden ya lo fija `zPosition`
  explícito en todos lados (`depthZ` para personajes, ordinal para pisos, z fijo
  para overlays).
- **`FisuEvolution/Scenes/BoardScene.swift`** (`updateFTUEHint`): pedía
  `gameState.visiblePlacements` **en cada frame** —una allocation por frame para
  siempre, incluso con el tutorial terminado— antes de mirar si había hint
  activo. Ahora se pide sólo dentro de la rama que lo usa.
- **`FisuEvolution/Scenes/Nodes/CharacterNode.swift`**: reasignaba
  `text`/`fontSize` de sus `SKLabelNode` sin comparar, y eso los marca sucios y
  rehace layout de Core Text + re-sube la textura. Corría sobre los 10
  personajes en cada relayout. Ahora pasa por `setLabel(_:text:fontSize:)`, que
  compara antes de escribir.
- **`FisuEvolution/Scenes/AtlasCache.swift` (nuevo)**: `SKTextureAtlas(named:)`
  se instanciaba dentro del bucle de specials (en cada relayout), en cada
  ascenso y por cada retrato de la ficha. Ahora hay una caché única. Su helper
  `texture(named:inAtlas:)` convierte el placeholder 1×1 de SpriteKit en el
  `nil` que uno espera.
- **`FisuEvolution/UI/HUD/SpawnButtonView.swift`**: `pulsing` se encendía en
  `onAppear` y **nunca se apagaba**, así que un `repeatForever` de SwiftUI
  mantenía su display link corriendo toda la sesión en paralelo al de SpriteKit,
  aunque el hint estuviera oculto. Ahora está atado a `showSpawnHint`.

### Resultado medido

| Métrica | Antes | Después |
|---|---|---|
| Páginas `earth.atlasc` @3x | 42 | **4** |
| Páginas `ui.atlasc` @3x | 58 | **2** |
| Peso del `.app` | 278 MB | **112 MB** |
| Assets en disco | 230 MB | **36 MB** |
| fps en reposo | 58 | **60** |

Captura después del cambio: `scratchpad/qa-shots/perf-after-resize.png`.
Comparada contra el baseline: **el arte se ve indistinguible**.

### ⚠️ Gotcha que costó tiempo

**El build incremental NO recompila los atlas** cuando cambian los PNG fuente:
el primer build tras el reescalado seguía produciendo páginas de 1538² y el
`.app` creció a 355 MB. Hay que borrar `build/DD` y rebuildear. Si medís páginas
de atlas y no cierran, es esto.

---

## 4. Lo que FALTA (fases 3, 4 y 5)

### Fase 3 — Camino de render

1. **Sacar el `SKCropNode` de `FloorNode`**
   (`FisuEvolution/Scenes/Nodes/FloorNode.swift`). Se agregó hoy en `b167c57`
   para arreglar un bug real (el fondo de un piso invadía al vecino), pero
   cuesta un pase de stencil por piso vivo (hasta 3) y encima el fondo se dibuja
   a 1005×1005 pt dentro de un slot de 393×852 → **3,0× de overdraw** que el
   stencil después descarta.
   **Alternativa recomendada**: aspect-fill por **coordenadas de textura** con
   `SKTexture(rect:in:)` y el sprite del tamaño **exacto** del slot. Da cero
   overdraw, cero stencil, y el bug de invasión entre pisos se vuelve imposible
   *por construcción* en vez de por recorte. `definition.backgroundOffset` pasa
   a ser un desplazamiento dentro del subrect normalizado (hoy mueve el sprite y
   se clampea contra el sobrante).
   **Junto con esto** conviene reautorar los fondos a proporción vertical
   (~768×1664) en vez de cuadrados: ahí sí se puede bajar su memoria sin perder
   nitidez, porque se dejan de guardar los píxeles laterales que nunca se ven.
2. **`renderPlacements` reconciliador** (`BoardScene.swift`): hoy recicla y
   reconstruye **los 10 personajes** en cada spawn, merge, movida y cambio de
   piso — y el tap de contratar es la acción más repetida del juego. En un merge
   cambian 2 de 10 slots. Comparar contra `characterNodes` por `slot`+`typeId` y
   tocar sólo lo que cambió. Beneficio extra: el wander deja de reiniciarse.
   Hay 13 sitios que llaman `bumpBoard()`; el más caliente es `buySpawn`.
3. **Sombra a sprite compartido** (`CharacterNode.swift`): la sombra elíptica es
   un `SKShapeNode` idéntico en los 10 personajes, y los shape nodes **nunca
   batchean**. Con una `SKTexture` compartida (patrón de
   `ParticlePool.particleTexture`) las 10 sombras se fusionan en 1 draw call.

### Fase 4 — Invalidaciones de SwiftUI

`refreshProjections` **ya compara antes de escribir** en sus 15 asignaciones —
eso está bien y no hay que tocarlo. El problema es lo que cuesta *llegar* a esa
comparación, y quién la escucha:

- **`HUDView` se recompone ~7,5 veces por segundo**, siempre, porque lee
  `coinsText`. En cada pasada: `HUDView.swift:72` usa `Text(_:)` con
  interpolación, o sea construye una `LocalizedStringKey` con 5 argumentos
  boxeados y hace un lookup de bundle **que falla** y cae al fallback; más ~10
  `Color("...")` por string. → `Text(verbatim:)` y colores a `static let`.
- **Trabajo redundante en `refreshProjections`** (`GameState.swift`): recalcula
  `IncomeTicker.passivePerSecond` que **ya se calculó ese mismo frame** dentro
  de `tick` y se descartó; llama `visibleFloorOccupancy` **tres veces** por
  pasada; y hace `Set(...).union(...).sorted()` sobre las 39 skins para producir
  casi siempre el mismo array.
- **`CoinFormatter.swift:31`** construye un `FloatingPointFormatStyle` en cada
  llamada (2× por flush más una por fila de varias listas).
- **`GameBoardView` se re-evalúa entero en cada spawn/merge** por
  `RootView.swift:212`, un `accessibilityValue(unitCount)` que existe **sólo
  para los UI tests** y arrastra el re-diff de la `SpriteView` y de 13 `.sheet`.
- **Timers como propiedades almacenadas** (`EventBannerView.swift:9`,
  `BonusView.swift:13`): el struct se re-inicializa con cada evaluación del
  padre, creando y autoconectando un `Timer` nuevo cada vez.

### Fase 5 — Audio (menor pero real)

`FisuEvolution/Audio/AudioManager.swift` **no sintetiza nada** (son `.caf` PCM),
pero crea el `AVAudioPlayer` **sincrónicamente en el hilo principal en el primer
uso de cada SFX** y no llama `prepareToPlay()` en ningún lado: son ~10 tirones,
uno por sonido nuevo. Precargar y preparar fuera de main.

---

## 5. Cómo verificar (obligatorio en cada fase)

```bash
cd Packages/EconomyKit && swift test                     # 134 tests
cd - && xcodegen generate                                # si agregaste/borraste Swift
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD test
cd Tools/asset-pipeline && .venv/bin/python -m unittest discover -s tests -q
```

Estado actual, todo verde: **EconomyKit 134/134, app 75/75, UI 10/10,
pipeline 20/20.**

Dos tests de UI son guardianes de bugs arreglados hoy y **no se pueden dejar
caer**:
- `testEachFloorRendersOnlyItsOwnBackground` — protege el bug del fondo que
  invadía el piso vecino. **Crítico si tocás `FloorNode` en la Fase 3.**
- `testCharactersStayVisibleAfterTheFirstAscent` — protege el bug de personajes
  invisibles pero clickeables (el pool devolvía nodos con `alpha = 0`).

También hay `testPerfBaselinePopulatedBoard`, que puebla el tablero y deja
capturas con el overlay de fps para comparar. Las capturas salen del xcresult:

```bash
xcrun xcresulttool export attachments --path /tmp/perf.xcresult --output-path /tmp/pshots
```

**Gotcha de los tests de UI**: el label accesible de `tower.pill` es el **nombre
del piso** ("Alley", "City"), no el contador "2/11". Un assert contra el
contador pasa en falso o falla sin motivo.

---

## 6. Trampas en las que ya caí (no repetirlas)

1. **El build incremental no recompila atlas.** Ver §3.
2. **Un test de UI puede pasar sin probar nada.** El smoke del ascenso arrastraba
   un cartonero sobre un Fisura suelto (tipos distintos → snap-back), así que
   nunca ascendía y daba verde igual. Lo detecté mirando la **captura**, no el
   resultado. Si automatizás gestos sobre SpriteKit, **asertá el efecto**, no
   sólo que el gesto no crashee.
3. **`osascript`/System Events no funciona desde el shell del agente** (error
   1002, falta Accesibilidad; el proceso responsable es un bundle anidado y
   versionado). El batch de arte hay que correrlo **desde Terminal.app**.
4. **Medir fps con builds corriendo en paralelo da números basura.** En una
   captura temprana salió 4,5 fps sólo porque había un `xcodebuild` compilando.

---

## 7. Contexto que conviene tener a mano

- **El juego en sí está completo (F7 cerrado)**; lo único pendiente ahí es
  generar el arte de **32 skins** con el batch de Gemini, desde Terminal:
  `bash Tools/asset-pipeline/scripts/run_skins_batch.sh`. Ya hay 5 generadas y
  verificadas. Detalle en `Docs/HANDOFF-F7-estado.md`.
- **Balance**: hay dos decisiones del dueño que NO hay que re-litigar — el primer
  Fisura cuesta 50 y es deliberadamente barato, y los pisos superiores cuestan
  300× lo que rinde un click de su personaje base. Registro en
  `Docs/balance-log.md`.
- **Reglas del repo**: `.xcodeproj` se regenera con `xcodegen generate` (es
  obligatorio al agregar o borrar archivos Swift); cero warnings
  (`SWIFT_TREAT_WARNINGS_AS_ERRORS`); commits en español.
