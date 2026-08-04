# HANDOFF — Optimización de fluidez

> Para el agente que retoma. Fecha: 2026-08-04. Leé también
> `Docs/HANDOFF-F7-estado.md` (estado del juego) y
> `Docs/HANDOFF-arte-gemini.md` (pipeline de arte).

> ## ✅ EL PLAN DE FLUIDEZ ESTÁ CERRADO
>
> Las fases 0, 1 y 2 se hicieron en `081f6b7`. Después se midió Release —lo que
> la Fase 0 dejaba pendiente— y **esa medición cambió el alcance del resto**: de
> las fases 3, 4 y 5 se hicieron sólo las dos partes que arreglan un problema
> perceptible, y las otras tres se descartaron con el número que las descarta.
> El detalle está en §4. No re-litigar sin volver a medir.

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

Segundo hallazgo: se sospechaba que **una parte del lag era artefacto de Debug**
(`-Onone` + `SWIFT_STRICT_CONCURRENCY: complete` conserva chequeos de
aislamiento en runtime) y del simulador. **Se midió, y esa sospecha no se
sostuvo**: no quedaba lag residual que atribuirle. Ver §2 bis.

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

> **Sobre los 112 MB**: re-medido el 2026-08-04 sobre un build Debug LIMPIO da
> **135 MB**, y Release **115 MB** (la diferencia son el dylib de debug y los
> Frameworks). No es una regresión: el número original debe venir de otro tipo de
> build. Lo que importa del desglose es que **los 11 fondos solos son ~81 MB** —
> 5,1 MB cada `@3x` más su `@2x`—, o sea más de la mitad del `.app`. Son el único
> grupo que la Fase 2 dejó sin tocar, a propósito (§3). El resto se reparte entre
> `earth.atlasc` 20 MB, Frameworks 16 MB, `cosmic.atlasc` 9,5 MB y
> `ui.atlasc` 8,7 MB.
>
> Eso deja una consecuencia que conviene tener presente: **reautorar los fondos a
> proporción vertical (~768×1664) sigue siendo la única ganancia grande que queda
> en peso de app**, y hoy ~54% de sus píxeles no se ven nunca. Venía dentro de la
> Fase 3.1, que se descartó porque no mueve fps — y eso sigue siendo cierto—,
> pero **el peso del `.app` es otra métrica y sí la movería**. Si algún día
> importa el tamaño de descarga en la App Store, es por ahí y no por el
> `SKCropNode`.

Captura después del cambio: `scratchpad/qa-shots/perf-after-resize.png`.
Comparada contra el baseline: **el arte se ve indistinguible**.

### ⚠️ Gotcha que costó tiempo

**El build incremental NO recompila los atlas** cuando cambian los PNG fuente:
el primer build tras el reescalado seguía produciendo páginas de 1538² y el
`.app` creció a 355 MB. Hay que borrar `build/DD` y rebuildear. Si medís páginas
de atlas y no cierran, es esto.

---

## 3 bis. La medición de Release (lo que cerró el plan)

Build de Release en el simulador con `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG`
para conservar el overlay de fps y los fixtures `--uitest-*`. El compilador sí
corrió optimizado (`-O` en la app, `-Owholemodule` en EconomyKit).

| | reposo (17 nodos) | poblado (65 nodos) |
|---|---|---|
| Debug (`-Onone`) | 60,0 fps | 60,0 fps |
| Release (`-O`) | 59,0 fps | 60,0 fps |

**Los fps están saturados en el techo en las dos configuraciones.** La métrica no
discrimina: la Fase 2 ya sacó el cuello de botella y el optimizador no compra
nada medible encima. Capturas: `scratchpad/qa-shots/perf-debug-poblado.png` y
`perf-release-poblado.png`.

Como fps no servía para dimensionar nada más, se agregó `.showsDrawCount` al
overlay de DEBUG (`RootView.swift`, una línea, ya gateada). **Dejalo ahí**: es el
instrumento que contestó la pregunta central, y §6 ya advierte que mirar sólo fps
engaña.

| tablero | nodos | draws |
|---|---|---|
| 1 personaje | 17 | **8** |
| 9 personajes | 65 | **48** |

**5 draw calls por personaje, cero batching entre ellos** aunque compartan página
de atlas. Capturas: `perf-draws-1-personaje.png` y `perf-draws-9-personajes.png`.

### ⚠️ Por qué no batchean (esto corrige el plan)

`BoardScene.depthZ(for:)` le da a **cada personaje un `zPosition` único**,
derivado de su `y`, para que se solapen como multitud. Con `ignoresSiblingOrder`
SpriteKit ordena por z y sólo puede fusionar nodos que comparten z. Como cada
personaje ocupa su propio escalón de profundidad, **el batching entre personajes
es imposible por construcción** — no es culpa de los shape nodes.

Eso invalida el dimensionamiento de la Fase 3.3 del plan, que prometía que pasar
la sombra a `SKTexture` compartida fusionaría "las 10 sombras en 1 draw call". No
lo hace: el orden de profundidad lo prohíbe. Se ahorraría la rasterización del
path del `SKShapeNode` (real, pero chico), no 9 draw calls.

---

## 4. Qué se hizo del resto, y qué NO

Con fps en el techo y 48 draw calls en el peor caso, **ninguna de las fases 3, 4
y 5 se justificaba por las métricas que el plan mismo puso como criterio**
("si alguna fase no mueve la aguja medida contra el baseline, se revierte en vez
de acumularse como complejidad sin beneficio").

Lo que esas métricas NO ven son los *hitches*: caídas de un frame suelto en
acciones puntuales, que un promedio corriendo a 60 esconde por completo. De la
lista pendiente, dos ítems son hitches reales y se hicieron. Los otros tres se
descartaron.

### ✅ Hecho — Fase 5 (audio)

`AudioManager.preloadSFX()` construye los diez players y les llama
`prepareToPlay()` al arrancar, en vez de hacerlo en el primer `play` de cada uno
—que eran diez tirones repartidos por la partida, cada uno justo encima de la
acción que lo dispara—. La lectura del disco va a una tarea aparte
(`AVAudioPlayer` no es `Sendable`; lo que cruza es el `Data`, que sí lo es) y se
cede el hilo principal entre SFX, así que la precarga convive con el bootstrap en
lugar de bloquearlo.

**Se extendió a la música**, que el plan no mencionaba: `music_earth_loop.caf`
son 1,7 MB y se leían en main durante el arranque — el archivo más pesado del
bundle y el stall de audio más grande que había. `startMusic` es `async` ahora.

Tests: `FisuEvolutionTests/AudioManagerTests.swift` (2).

### ✅ Hecho — Fase 3.2 (`renderPlacements` reconciliador)

Se hizo **por el defecto visible, no por los fps**: reconstruir los diez
personajes en cada contratación reiniciaba el wander de toda la multitud, así que
el tablero entero pegaba un salto de vuelta a sus anclas en la acción más
repetida del juego.

La decisión vive en `FisuEvolution/Scenes/BoardReconciliation.swift`, un tipo
puro, porque ahí está el riesgo real del cambio: **dejar quieto un nodo que en
realidad tenía que rearmarse**. La clave de identidad es
`RenderedUnit {typeId, skinID, cellSize, columns}` — todo lo que consume
`CharacterNode.configure`. Un nodo que sobrevive no se reconfigura, no se
reposiciona y no se le reinicia el wander.

Dos cosas que hacen que esto sea seguro y conviene no romper:
- El wander usa `.move(to:)` **absoluto contra el ancla**, no movimientos
  relativos, así que un nodo que sobrevive muchos relayouts no deriva.
- `characterNodes` sólo se muta en `renderPlacements`; nadie más vacía
  `fieldNode`. `renderedUnits` se mantiene en paralelo ahí mismo. Si eso cambia,
  los dos diccionarios se desincronizan.

Los nodos se devuelven al pool **antes** de pedir los nuevos, para que `obtain()`
reutilice en vez de alocar de más en cada merge.

Tests: `FisuEvolutionTests/BoardReconciliationTests.swift` (5).

### ❌ Descartado — Fase 3.1 (sacar el `SKCropNode` de `FloorNode`)

3× de overdraw que el stencil descarta, sí, pero con fps en el techo no compra
nada medible, y toca el bug de fondos arreglado en `b167c57` que protege
`testEachFloorRendersOnlyItsOwnBackground`. Riesgo real contra beneficio no
medible. Si alguna vez se retoma, la alternativa buena sigue siendo aspect-fill
por coordenadas de textura con `SKTexture(rect:in:)` y el sprite del tamaño
exacto del slot: cero overdraw, cero stencil, y la invasión entre pisos se vuelve
imposible *por construcción* en vez de por recorte. `definition.backgroundOffset`
pasaría a ser un desplazamiento dentro del subrect normalizado.

### ❌ Descartado — Fase 3.3 (sombra a sprite compartido)

Su premisa es falsa: ver §3 bis. El depth sorting por personaje impide la fusión
que la fase prometía.

### ❌ Descartado — Fase 4 (invalidaciones de SwiftUI)

`HUDView` se recompone ~7,5 veces por segundo y hay trabajo redundante en
`refreshProjections`, pero nada de eso mueve una métrica hoy. Queda anotado acá
por si algún día aparece un síntoma que lo justifique: `HUDView.swift:72` usa
`Text(_:)` con interpolación (construye una `LocalizedStringKey` con 5 argumentos
boxeados y hace un lookup de bundle que falla y cae al fallback) más ~10
`Color("...")` por string; `refreshProjections` recalcula
`IncomeTicker.passivePerSecond` que ya se calculó ese frame dentro de `tick`,
llama `visibleFloorOccupancy` tres veces por pasada y hace
`Set(...).union(...).sorted()` sobre las 39 skins; `CoinFormatter.swift:31`
construye un `FloatingPointFormatStyle` en cada llamada.

**El único de esa lista que no es optimización sino bug latente** son los timers
como propiedades almacenadas (`EventBannerView.swift:9`, `BonusView.swift:13`):
el struct se re-inicializa con cada evaluación del padre, creando y
autoconectando un `Timer` nuevo cada vez. Ese sí conviene arreglarlo cuando se
toque esa zona.

---

## 5. Cómo verificar (obligatorio en cada fase)

```bash
cd Packages/EconomyKit && swift test                     # 134 tests
cd - && xcodegen generate                                # si agregaste/borraste Swift
xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD test
cd Tools/asset-pipeline && .venv/bin/python -m unittest discover -s tests -q
```

Estado actual, todo verde: **EconomyKit 134/134, app 82/82, UI 10/10,
pipeline 20/20.**

Dos tests de UI son guardianes de bugs viejos y **no se pueden dejar caer**:
- `testEachFloorRendersOnlyItsOwnBackground` — protege el bug del fondo que
  invadía el piso vecino. **Crítico si alguna vez se retoma la Fase 3.1.**
- `testCharactersStayVisibleAfterTheFirstAscent` — protege el bug de personajes
  invisibles pero clickeables (el pool devolvía nodos con `alpha = 0`).

⚠️ **El segundo estaba roto desde antes y nadie se enteró.** F7.5 (`05a3e24`)
agregó la celebración de skin de milestone, que es un **sheet modal**, y el
ascenso a Urban que este test recorre acredita `urban_trailblazer`: el sheet
tapaba el tablero —del que el test da veredicto mirando la captura— y dejaba
`tower.arrow.down` inalcanzable. Se verificó stasheando los cambios y corriendo
el test contra HEAD pelado: fallaba idéntico. Ahora el test cierra la
celebración como la cierra el jugador (`dismissSkinAward`).

**Lección para el próximo**: la celebración depende de `fisuTutorialDone`, un
`@AppStorage` que `--uitest-reset` **NO** toca y que el propio test puede
terminar de avanzar a fuerza de taps. Cualquier test de UI que pase por un
ascenso tiene que tolerar las dos ramas en vez de asumir una.

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
5. **Los fps son una métrica saturada acá: no discriminan nada.** Todo da 60,
   en Debug y en Release, vacío y poblado. Si querés dimensionar un cambio de
   render, mirá `draws` (el overlay ya lo muestra); si lo que sospechás es un
   hitch, los fps no te lo van a mostrar nunca y hace falta otra herramienta.
6. **Manejar el simulador a mano contamina la suite de UI.** Escribir
   `fisuTutorialDone` con `simctl spawn defaults write` para saltear el tutorial
   cambia qué popups aparecen en los tests. Fue lo primero que sospeché cuando
   falló el test de UI — y **estaba equivocado**: el test fallaba igual con el
   flag invertido y también contra HEAD sin ningún cambio. Vale la pena aislar
   la variable con `git stash` antes de acusar al código propio.
7. **Un test de UI que falla por `kAXErrorCannotComplete` /
   "Failed to scroll to visible" casi nunca es un problema del botón**: es algo
   modal tapándolo. La forma rápida de verlo es exportar los attachments del
   xcresult y mirar la captura y el `App UI hierarchy`, que lista los elementos
   del sheet que está encima.

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
