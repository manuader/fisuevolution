# E8e T10 — El tablero animado con los videos base · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Pedido del dueño (2026-10-10, bandeja, textual):** «usar los videos que hay, los de los 53 personajes
base, en TODO lugar donde aparezca el personaje sin skin. Sumar a E8e una tarea T10 — el tablero animado
con los videos base: extraer de cada `.mov` base una secuencia corta de cuadros (≈12–16, 256 px, con
alfa) a un atlas por tipo y animar los `CharacterNode` sin skin con `SKAction.animate` (no video: el
tablero tiene decenas), cargando sólo los tipos del piso visible; Reduce Motion / bajo consumo / térmica
→ estático; gate de memoria y fps en el SE antes de integrar (si no entra, bajar cuadros/tamaño o limitar
a los N más cercanos). Planificador opus para T10 (spike con medición primero).»

**Reglas del dueño que mandan acá:** el asset en movimiento antes que el estático donde se pueda; **una
pinta nunca usa el video base** (ni sus cuadros).

**Goal:** que cada personaje **sin pinta** parado en el tablero respire con los cuadros de su propio
clip base, sin video, sin romper los 60 fps del SE y sin que la memoria crezca más de lo que el gate
permite. Con pinta, sin arte real, con Reduce Motion / bajo consumo / térmica / `--uitest*`, o si los
cuadros no llegaron: **la textura quieta de siempre**.

**Architecture:** el pipeline saca de cada `char_<tipo>.mov` una **hoja de cuadros** (`idle_<tipo>.png`,
grilla de N cuadros de L px con alfa) que viaja **en el mismo pack ODR del clip** (`anim-piso-<n>`: cero
cambios a `project.yml`), más un contrato chico en el paquete base (`Resources/Data/idle_frames.json`).
En el juego, un **`BoardIdleAnimator`** nuevo (fuera de `BoardScene`) recibe los nodos del piso visible,
pide sólo los packs de esos tipos, decodifica las hojas **fuera del hilo principal**, las precarga
(`SKTexture.preload`) y recién entonces le da a cada `CharacterNode` sin pinta su
`SKAction.animate(…, restore: true)` en loop, con la fase corrida por celda. La política es la de los
videos (`VideoPlayerPool.policy.allowsLoops`), escuchada con un observador nuevo del pool. `BoardScene`
🔥 gana **tres líneas** (la propiedad, su `init` y un `sync` al final de `renderPlacements`).

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SpriteKit · ImageIO ·
Swift Testing · XcodeGen · Python 3 + ffmpeg 8.1 (decodifica el HEVC con alfa: verificado, ver abajo).

**Fuente:** el pedido de arriba; el plan de E8e `2026-10-10-v2-e8e-videos-al-juego.md` (formato, Global
Constraints, helpers); la spec `Docs/superpowers/specs/2026-10-08-v2-e8-animaciones-design.md` ("el
tablero no usa video para los personajes": T10 la respeta, son cuadros); los gates G1/G4/G5 de
`2026-10-08-v2-e8d-animaciones-swift.md`; el precedente de cuadros en el juego
(`Tools/asset-pipeline/scripts/chest_video_frames.py` → `ChestAnim/`, "secuencia cuantizada") y la trampa
del warm síncrono (`Docs/SESION-2026-09-03-cofre-arranque.md`, commit `97cb618`). Código en `2dcf084`.

**Rama:** cada tarea sale de la punta de `v2/e8e-videos` (o de la base que diga el despacho) en un
worktree propio (`.claude/worktrees.nosync/v2i-e8e-t10<x>`); el spike, en `v2i/e8e-t10a-spike`, que
**no se integra nunca** (sólo su reporte y los parámetros que fija).

**Fuera de este plan:** clips o cuadros de pintas (`<tipo>__<pinta>`, E8e T8); los especiales (`sp_*`)
**ya no están en el tablero** (E4b T9, `0fc9ea9`): en el escenario los anima E8e T2 con su clip
`talking`; la ficha, la revelación, el Álbum y el drop del especial ya usan video (E8d / E8e T7). Los
otros lugares SwiftUI con el personaje base quieto van en la duda 11 (T10f).

## Las referencias, verificadas contra el árbol (`2dcf084`)

| Lo que usa el plan | Dónde está hoy | Qué significa para T10 |
|---|---|---|
| Los clips base | `loops_manifest.json` (`Resources/Data/`) `characters`: 53 claves = 43 tipos + 10 `sp_*`; cada uno `char_<id>.mov`, **512², 24 fps, 121 cuadros (5,04 s), HEVC `hvc1` con alfa**, `odrTag` `anim-piso-<n>` (piso 3: 10 tipos; los demás 4; piso 10: 1) / `anim-especiales` | T10 usa los **43 tipos**; los `sp_*` no pisan el tablero |
| Decodificar el alfa | `ffmpeg 8.1` (`/opt/homebrew/bin`) decodifica el alfa del HEVC: medido sobre `char_homeless.mov` → RGBA, alfa 0 en la esquina, 255 en el cuerpo | la extracción sale del `.mov` que ya viaja; **no** hacen falta los masters |
| El clip cierra el loop | cuadros 0, 8, …, 120 de `homeless`/`administrativo`: diferencia media cuadro→cuadro 1,2 / 2,5 (sobre 255), último→primero 0,9 / 1,3 | muestrear **uniforme sobre el loop** (sin repetir el 120 ≈ 0) cierra sin salto |
| Póster = primer cuadro | bbox del alfa del cuadro 0 escalado a 256 == bbox de `<tipo>_idle@3x.png` escalado a 256, al píxel (`homeless` `(76,18,186,243)`, `administrativo` `(33,9,223,243)`) | arrancar o cortar la animación **no corre** al personaje |
| Peso medido de una hoja | 16 cuadros × 256² en grilla 4×4 (1024²): PNG RGBA 773 KB / 1095 KB; **PNG8 cuantizado (FASTOCTREE) 140 / 197 KB**; WebP q80 152 / 242 KB (`homeless` / `administrativo`) | presupuesto ODR (abajo) con PNG8 |
| `CharacterNode` | `Scenes/Nodes/CharacterNode.swift`: `sprite` hijo privado (espejado en el sprite, `setFacing`); `configure(type:texture:cellIndex:cellSize:skinTint:hasRealArt:earnsPassive:)`; arte real = `sprite` de `plateSize * 2.2` | T10c suma la animación **en el sprite** (convive con el espejado) |
| El pool de nodos | `CharacterNodePool.obtain()` hace `node.removeAllActions()` **sobre el nodo, no sobre el sprite** | ⚠️ trampa: una animación del sprite sobreviviría al reciclado → `obtain` la corta (T10c) |
| La pinta en el tablero | `BoardScene.renderPlacements` (`:2016-2071`): `RenderedUnit.skinID = gameState.activeSkinID(forCharacterType:)`; `SkinResolver.treatment` → textura `<tipo>_idle__<pinta>` o tinte | "sin pinta" = `skinID == nil`. Tinte también es pinta → quieto |
| Los nodos del tablero | `characterNodes: [Int: CharacterNode]` (privado), sólo los de `gameState.visiblePlacements` (el piso visible) | el animador recibe ese diccionario en cada `renderPlacements` |
| Vuelo del ascenso | `BoardScene.swift:1872-1886` configura un `CharacterNode` de vuelo | queda quieto (duda 8) |
| Packs ODR | `Managers/ArtPacks.swift`: `request(_:urgent:)`/`prefetch`/`release` con conteo de usuarios, `whenAvailable(_:_:)`/`cancelWait`, `ArtPacks(source:)` para tests; `project.yml:76-121` una carpeta `Resources/AnimPacks/<tag>` por tag; **Xcode aplana**: los nombres de archivo tienen que ser únicos | `idle_<tipo>.png` en la carpeta del pack del clip; sin tocar `project.yml` 🔥 |
| Prefetch del reveal | `BoardScene.swift:1714-1722` ya pide `odrTag(for: .character(próximo tier))` | comparte packs con el animador: `ArtPacks` cuenta usuarios, no se pisan |
| La política | `UI/Art/Video/VideoPlaybackPolicy.swift`: `allowsLoops` falso con `reduceMotion`, `lowPower`, `thermal` (≥ `.serious`), `background`, `videoAutoplayOff`, `forcedStill` (XCTest y `--uitest*` sin `--uitest-video`); `VideoPlayerPool.policy` (`private(set)`), `update(policy:)`; **no hay forma de escuchar el cambio sin un lease** | T10c suma `VideoPlayerPool.observePolicy` |
| `AtlasCache` | `Scenes/AtlasCache.swift`: caché de `SKTextureAtlas` por nombre, para los atlas del paquete base | las hojas **no** pasan por ahí (viven en ODR y se sueltan) |
| Calentar texturas sin trabar | `UIArt.warmCharacterImage` (`97cb618`): `SKTexture.preload` en background, la textura se usa en el completion | el animador aplica los cuadros sólo tras el `preload` |
| La sonda | `Debug/FrameRateProbe.swift` (DEBUG): fps promedio, cuadros > 25 ms, peor cuadro, `phys_footprint` en MB; se ve en `DebugPanelView` y se loguea cada 10 s (`fps-probe …`); `--uitest-anim-stress` (`GameState+Bootstrap.swift:251`, `GameState+Debug.swift:293`) | el spike y el gate final la usan; T10d suma `--uitest-idle-bench` |
| Cuadros en el juego (precedente) | `chest_video_frames.py` → `Resources/ChestAnim/` + `chest_anim.json` pineado de los dos lados (`ChestAnimationTests` / `test_chest_video_frames`) | mismo patrón: script + contrato JSON + tests en Python y Swift |
| `video_assets.py` | `odr_tag()` (`:611-621`), `floor_of_character()` (`:598`), `load_manifest()` (`:581`), `RESOURCES`/`MANIFEST` (`:105-107`) | `idle_frames.py` los **importa** (no los duplica) para el tag y la lista de tipos; no edita ese archivo (es de E8e T8) |

## Global Constraints

Las del plan de E8e valen enteras ("Global Constraints" de `2026-10-10-v2-e8e-videos-al-juego.md`). Las
que más pesan acá, y las propias:

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`. **Nada de `Timer`**: la
  animación es una `SKAction`; la política llega por observador.
- **La textura quieta primero, siempre.** Un `CharacterNode` sin cuadros es exactamente el de hoy. La
  animación se monta sólo con la hoja decodificada **y precargada**; se saca con `restore: true` (vuelve
  la textura del `configure`).
- **Una pinta nunca anima con cuadros base** (pinta de textura o de tinte). Sin arte real (placa de
  color), tampoco.
- **Nada de decodificar ni subir texturas en el hilo principal.** Decodificar en una `Task.detached`
  (ImageIO) y aplicar tras `SKTexture.preload`. El gate mide el peor bloqueo del main al cambiar de piso.
- **Sólo los tipos del piso visible** tienen hojas en memoria. Un tipo que sale del piso suelta su hoja y,
  si nadie más usa el tag, su pack.
- **No cuenta para el tope de 3 videos** (`VideoPlayerPool.maxLive`): no es video. Pero el gate se mide
  **con** el fondo del piso vivo y el visitante del escenario hablando.
- **Bajo `--uitest*` (sin `--uitest-video`) y bajo XCTest todo queda quieto** (`forcedStill`): los UI
  tests de siempre no cambian. Con `--uitest-video`, anima (capturas).
- **Un dueño por archivo 🔥.** `BoardScene.swift` sólo en T10d, tres líneas, en una ventana libre (ver
  choques); si no hay ventana, el controlador las aplica al integrar (precedente E12 T11).
  `project.yml` 🔥 **no se toca** (las hojas van en las carpetas de pack que ya existen).
- **Ids:** la clave de cada hoja es el id del tipo de `tiers.json` (= clave de `characters`). No se
  renombra nada.
- **Strings nuevos:** ninguno.
- **Prohibido `find /`** y toda búsqueda fuera del worktree. Protocolo:
  `/Users/manuader/Desktop/projects/FisuEvolution/.claude/worktrees/version-2/.superpowers/sdd/v2-agente-protocolo.md`.
- **Commits en español, estilo de la casa** (`feat(tablero): …`, `feat(pipeline): …`, `test(…)`), **SIN
  `Co-Authored-By`**. Staging selectivo, `git diff --cached --stat`, un comando git por llamada.
- **Al cerrar cada tarea** (el controlador): integración, ledger, journal, `tasks.md`. Ningún subagente
  toca `Docs/`, `handoffs/`, el journal ni `tasks.md`: el reporte del spike va a
  `.superpowers/sdd/e8e/task-10a-report.md` (gitignoreado) y el controlador lo pasa a `Docs/`.

## Verificación (vale para toda tarea)

```bash
# App: EconomyKit entero + build + esas clases de FisuEvolutionTests
Tools/v2/oraculo.sh tarea <Clases>

# Pipeline (T10b)
PY=/Users/manuader/Desktop/projects/FisuEvolution/Tools/asset-pipeline/.venv/bin/python
(cd Tools/asset-pipeline && "$PY" -m unittest discover -s tests)   # sin salteados
```

- UI tests que una tarea toca: **Receta R** de `Docs/superpowers/plans/2026-10-07-v2-e4a-visitantes-eventos.md`.
- ⚠️ "0 tests" con éxito no prueba nada: la salida nombra las clases. Ante un rojo en masa, `uptime` y
  `ps aux | grep '[x]codebuild'` antes de culpar al código.
- ⚠️ **El simulador no mide fps** (GPU del Mac). En el simulador se mide: memoria **relativa** (quieto vs
  animado, `phys_footprint` de la sonda), tiempo de decodificación y el **peor bloqueo del main** al
  cambiar de piso. Los fps y la memoria absoluta los mide el dueño en el SE (🔒).

## Presupuesto de peso (bundle y ODR)

| Qué | Dónde | Presupuesto | Medido / estimado |
|---|---|---|---|
| `idle_frames.json` | paquete base (`Resources/Data/`) | ≤ 20 KB | ~6 KB (43 entradas) |
| 43 hojas `idle_<tipo>.png` | packs ODR `anim-piso-1…10` | **≤ 10 MB en total**; ninguna hoja > 300 KB; ningún pack > +2,5 MB (el piso 3, con 10 tipos) | PNG8 16 × 256²: 140–200 KB → **≈ 6–9 MB** |
| Paquete base | — | **+0** (G5: base ≤ +60 MB, intacto) | — |
| Repo git | binarios versionados | ≈ lo mismo que las hojas | — |
| Memoria en uso (RGBA en GPU) | por tipo cargado | 16 × 256² × 4 B = **4 MiB**; 12 cuadros 3 MiB; 192 px 2,25 MiB; ASTC 4×4 ≈ 1 MiB | el peor piso (3) con 10 tipos distintos: **40 MiB** RGBA → el gate decide el escalón |

Si el spike elige ASTC (vía catálogo, escalón C), el peso de disco lo vuelve a medir y la tabla se
reescribe en su reporte.

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| (rama `v2i/e8e-t10a-spike`, desechable) | prototipos de extracción y de animación, el banco de medición | 10a |
| `Tools/asset-pipeline/scripts/idle_frames.py` | **nuevo** — `.mov` base → hoja `idle_<tipo>.png` + `idle_frames.json` | 10b |
| `Tools/asset-pipeline/tests/test_idle_frames.py` | **nuevo** | 10b |
| `FisuEvolution/Resources/AnimPacks/anim-piso-<n>/idle_<tipo>.png` (43) | **nuevos** (generados) | 10b |
| `FisuEvolution/Resources/Data/idle_frames.json` | **nuevo** (generado) — el contrato | 10b |
| `FisuEvolution/Managers/IdleFrames.swift` | **nuevo** — `IdleFramesManifest` (decodable, puro) | 10c |
| `FisuEvolution/Scenes/BoardIdleAnimator.swift` | **nuevo** — qué tipos se cargan, cuándo animan, los packs, la política, la memoria | 10c |
| `FisuEvolution/Scenes/Nodes/CharacterNode.swift` | `setIdleFrames`, `isIdleAnimating`, `showsRealArt`; `CharacterNodePool.obtain` corta la animación | 10c |
| `FisuEvolution/UI/Art/Video/VideoPlayerPool.swift` | `observePolicy` / `cancelPolicyObservation` | 10c |
| `FisuEvolutionTests/IdleFramesManifestTests.swift`, `BoardIdleAnimatorTests.swift`, `CharacterNodeIdleTests.swift` | **nuevos** | 10c |
| `FisuEvolutionTests/CharacterNodePoolTests.swift`, `VideoPlayerPoolTests.swift` | casos nuevos | 10c |
| `FisuEvolution/Scenes/BoardScene.swift` 🔥 | **tres líneas** | 10d |
| `FisuEvolutionTests/BoardIdleWiringTests.swift` | **nuevo** | 10d |
| `FisuEvolution/Game/State/GameState+Debug.swift`, `GameState+Bootstrap.swift` (tibios) | `--uitest-idle-bench` (DEBUG) | 10d |
| `Docs/` | sesión, HANDOFF, `tasks.md` | 10e (controlador) |

## Orden, olas y paralelismo

| T | Qué | 🔥 / tibios | Depende de | Revisión · modelo |
|---|---|---|---|---|
| 10a | **Spike con medición** + 🔒 gate del dueño en el SE | rama desechable (puede tocar todo, no se integra) | — | **opus** (ejecuta y decide los parámetros) |
| 10b | Pipeline: hojas + contrato | — (nuevos) + 43 PNG en `AnimPacks/` | 10a 🔒 | ninguna · sonnet |
| 10c | El runtime sin `BoardScene` | `CharacterNode` (E6b T5 también), `VideoPlayerPool` | 10b | controlador lee el diff · sonnet |
| 10d | El cableado: tres líneas de `BoardScene` + banco | 🔥 `BoardScene`; `+Debug`, `+Bootstrap` (tibios) | 10c; **ventana de `BoardScene`** | controlador lee el diff + capturas · sonnet |
| 10e | Cierre: gate final en el SE del dueño + docs (controlador) | `Docs/` | 10d | 🔒 |
| 10f | (opcional, duda 11) la carta base de Personalización animada | `CustomizationView` | **E6b T5** | capturas · sonnet |

```
Ya                          T10a (spike, compila: cuenta para el tope de 3)
Tras el 🔒 de T10a          T10b   (∥ con cualquier cosa: archivos nuevos y PNG en AnimPacks)
Tras T10b                   T10c   (no ∥ E6b T5: CharacterNode)
Tras T10c + ventana         T10d   (no ∥ E5b T3, E6b T5, E8e T8: BoardScene; o lo aplica el controlador)
Tras T10d                   T10e   (🔒 dueño)
Tras E6b T5 (opcional)      T10f
```

**Choques con la cola (`tasks.md` §3 y §4.2):**

1. **E5b T3** (⏳, 🔥 `BoardScene`): T10d va **después** (es la que sigue en `BoardScene` según §3.1).
2. **E6b T5** (⛔ tras E5b T3; 🔥 `BoardScene`, `CharacterNode.configure(…, skinShaderID:)`,
   `CustomizationView`): T10c y T10d **no ∥** con E6b T5. Quien vaya segunda rebasa: E6b T5 suma un
   parámetro al final de `configure` y el shader va en el sprite **sólo con pinta**; T10 anima el sprite
   **sólo sin pinta** → no se pisan en comportamiento, sí en el archivo. T10f, después de E6b T5.
3. **E8e T8** (⛔, dos líneas de `BoardScene`: el reveal): ventana distinta de T10d; o el controlador
   aplica las dos de T8 y las tres de T10d juntas al integrar.
4. **E8e T6** (⛔ tras E5b T3, toca `LoopingVideoNode`): sin choque (T10 no toca ese nodo).
5. **E8e T1** (en vuelo, `LoopsManifestTests`/`ArtClips`): sin choque. T10 **no** suma secciones a
   `loops_manifest.json` (contrato aparte, `idle_frames.json`) para no tocar el contrato de T1.
6. **E8d T15** (⏳, gates G1–G5 del dueño): el gate de T10e **suma** su escena al G1/G4 del dueño; si
   E8d T15 se mide antes, se mide de nuevo con el tablero animado (es lo que hace T10e).
7. **Tibios** `GameState+Debug.swift` y `+Bootstrap.swift` (T10d, sólo DEBUG): secuenciar con quien los
   tenga en la ola (§3.2).
8. **Regenerar packs:** quien corra `video_assets.py` sobre un personaje (E8e T8 si mete clips de
   pinta) no pisa `idle_*.png`; pero si el dueño **reemplaza** un `char_<tipo>.mov`, hay que volver a
   correr `idle_frames.py` (lo pinea el test de frescura de T10b).

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` | `FisuEvolutionTests/Support/GameStateFixture.swift` |
| contenido real | `try GameContentLoader.load(from: .main)` | `GameContentLoader.swift` |
| el manifest de loops real / de fixture | `try LoopsManifest.load(from: .main)` / el `init` con secciones | `LoopsManifest.swift`, `LoopsManifestTests.swift:19-34` |
| un pool con política forzada | `VideoPlayerPool(policy:)`, `.allowAll.with(.reduceMotion)` | `VideoPlayerPoolTests.swift` |
| packs que no llegan / que llegan cuando el test quiere | `ArtPacks(source:)` con un `ArtPackSource` de prueba | `ArtPacksTests.swift` |
| una escena con el contenido real | el patrón de `RevealVideoTests` (`BoardScene(gameState:loops:videoPool:)`) | `RevealVideoTests.swift:21` |
| nodos reciclados | el patrón de `CharacterNodePoolTests` | `CharacterNodePoolTests.swift` |
| contrato JSON pineado de los dos lados | `ChestAnimationTests` ↔ `test_chest_video_frames.py` | precedente |

---

### Task 10a: Spike con medición (🔒 gate del dueño en el SE)

**Objetivo:** fijar con números **los parámetros** que usan T10b–T10d: cuadros por tipo, lado en px,
formato (PNG8 en la carpeta del pack, o atlas ASTC del catálogo con tag ODR), ritmo de reproducción, y si
hace falta el tope de "los N más cercanos". Nada de esto se integra: el entregable es el reporte con la
tabla de parámetros y la medición, y una build para el SE del dueño.

**Rama:** `v2i/e8e-t10a-spike` (desechable: puede tocar `BoardScene`, `CharacterNode` y lo que haga
falta, **no se mergea**). Compila: cuenta para el tope de 3.

**Files (en la rama del spike):** un script de prototipo en `Tools/asset-pipeline/scripts/` (luego
`idle_frames.py` lo reescribe con tests), hojas generadas, un parche mínimo de animación en
`CharacterNode`/`BoardScene` y un argumento DEBUG `--uitest-idle-bench`.

- [ ] **Step 1: extraer las variantes** (los 43 tipos) del `.mov` que viaja en el pack (ffmpeg 8.1
  decodifica el alfa; `-pix_fmt rgba`, `scale=L:L:flags=lanczos`), muestreo **uniforme sobre el loop**
  sin el último cuadro (≈ el primero): índices `int(i * 120 / N + 0.5)`, `i = 0…N-1` (no `round`: Python
  redondea al par). Variantes:
  `A16·256`, `A12·256`, `A16·192`, `A12·192` en hoja PNG8 (grilla `ceil(sqrt(N))`); y **C**: las mismas
  como `.spriteatlas` dentro de un `.xcassets` con `on-demand-resource-tags` y compresión
  `gpu-optimized-best` (ASTC) — verificar con `assetutil --info` sobre el `Assets.car` compilado que la
  compresión y el tag existen; si XcodeGen/Xcode no los honra, C queda descartada (anotarlo).
  Tabla de disco por variante (total y peor pack).
- [ ] **Step 2: el ritmo.** Para 4 tipos (uno por familia de movimiento: `homeless`, `administrativo`,
  el más movido del piso 3 y `god`), GIFs y una captura del tablero con: (a) el ritmo del clip original
  (N cuadros en 5,04 s ≈ 3,2 fps con N = 16); (b) 6 fps; (c) 8 fps. Medir el cierre del loop (diferencia
  media último→primero, como en la tabla de referencias). Default propuesto: (a), el movimiento es el del
  video; el dueño lo ve en el Step 5.
- [ ] **Step 3: el prototipo en el juego.** Hoja → `CGImageSource` en `Task.detached` → `SKTexture(cgImage:)`
  → subtexturas `SKTexture(rect:in:)` → `SKTexture.preload` → `sprite.run(.repeatForever(.animate(with:
  timePerFrame: restore: true)))` con la fase corrida por celda. Banco `--uitest-idle-bench` (DEBUG): el
  piso 3 desbloqueado con **sus 10 tipos distintos en el tablero** (el peor caso de memoria), el fondo del
  piso vivo y el visitante del escenario hablando (con `--uitest-video`), `FrameRateProbe` corriendo; un
  segundo modo `--uitest-idle-bench-still` igual pero sin cuadros (la línea de base).
- [ ] **Step 4: medir en el simulador** (iPhone SE 3ª gen, iOS del target), 60 s por variante y modo, la
  línea `fps-probe` del log:
  - `phys_footprint` animado − quieto (MB) por variante → la memoria **relativa**;
  - tiempo de decodificar una hoja (ms, fuera del main) y **peor cuadro** al cambiar del piso 2 al 3 ida y
    vuelta 10 veces (el main no se traba: el peor cuadro ≤ 50 ms y ninguno de > 25 ms atribuible a la
    carga, mirado con `os_signpost` alrededor del `apply`);
  - memoria tras 10 cambios de piso (sin crecer: las hojas se sueltan);
  - con el simulador en "Simulate Memory Warning": todo vuelve a quieto y la memoria baja.
- [ ] **Step 5: 🔒 el dueño en su SE** (build Debug del spike instalada desde Xcode, porque la sonda es
  DEBUG; el día a día de G1 se mide en Release con Instruments, acá alcanza la sonda). Le dejamos en el
  reporte un instructivo de 6 líneas:
  1. Abrir la app con `--uitest-idle-bench-still --uitest-video` (scheme del spike), esperar 60 s, anotar
     la línea de la sonda del panel DEBUG (fps · peor · > 25 ms · MB).
  2. Lo mismo con `--uitest-idle-bench --uitest-video` para la variante elegida por el spike (y la de un
     escalón abajo).
  3. Cambiar de piso 2 ↔ 3 diez veces: ¿algún tirón?
  4. Mirar el tablero: ¿se ve bien el ritmo? ¿algún personaje "salta" al arrancar?
  **Vara (la de G1/G4 de E8d):** promedio ≥ 59 fps; ≤ 1 % de cuadros > 25 ms; **animado − quieto ≤ 20 MB**
  en el peor piso y el total con los videos ≤ el quieto + 40 MB; ningún tirón visible al cambiar de piso.
  **Si no entra, la escalera, en orden:** (1) 12 cuadros; (2) 192 px; (3) ASTC (variante C, si el Step 1
  la validó); (4) los **N más cercanos** al centro del piso visible (N = 6, después 4); (5) quieto en los
  equipos de < 3 GB (`ProcessInfo.physicalMemory`). Se anota el escalón que quedó.
- [ ] **Step 6: el reporte** (`.superpowers/sdd/e8e/task-10a-report.md`): la tabla de disco, la de
  memoria/tiempos del simulador, los números del dueño (los pega él en `DUENO.md` o en el chat), y la
  tabla **"Parámetros fijados"** que consumen T10b–T10d:

  | Parámetro | Default si todo pasa |
  |---|---|
  | `frames` | 16 |
  | `cell` (px) | 256 |
  | `format` | `png8-sheet` (en la carpeta del pack) |
  | `fps` | 16 / 5,04 s ≈ 3,17 (el ritmo del clip) |
  | `maxAnimated` | `nil` (todos) |
  | `minPhysicalMemoryGB` | `nil` |

  Commit en la rama del spike: `spike(tablero): los cuadros de los clips base, medidos` (sólo para que
  quede rastro; no se integra). Push de la rama.

**No se hace:** integrar nada del spike; tocar `tasks.md` o `Docs/`.

---

### Task 10b: El pipeline — hojas de cuadros y su contrato

> ⛔ Depende del 🔒 de T10a (usa la tabla "Parámetros fijados").

**Objetivo:** un script reproducible que, de cada clip base de un tipo del tablero, saca su hoja de
cuadros a la carpeta de su pack y escribe el contrato. Idempotente: misma entrada, mismos bytes.

**Files:**
- Create: `Tools/asset-pipeline/scripts/idle_frames.py`
- Create: `Tools/asset-pipeline/tests/test_idle_frames.py`, `Tools/asset-pipeline/tests/fixtures/idle_fixture.mov`
  (la carpeta `fixtures/` no existe hoy)
- Create (generados): `FisuEvolution/Resources/AnimPacks/anim-piso-<n>/idle_<tipo>.png` (43),
  `FisuEvolution/Resources/Data/idle_frames.json`

**Interfaces:**
- Consumes: `video_assets.load_manifest()`, `video_assets.odr_tag("personaje", id)`, `RESOURCES`
  (importados, no copiados); ffmpeg 8.1; PIL (el `.venv` del pipeline).
- Produces — el contrato (`schemaVersion` 1; los números, los del spike):

```json
{
  "schemaVersion": 1,
  "frames": 16,
  "cell": 256,
  "columns": 4,
  "fps": 3.17,
  "types": {
    "homeless": { "file": "idle_homeless.png", "odrTag": "anim-piso-1", "source": "char_homeless.mov", "sourceFrames": 121 }
  }
}
```

  - `python idle_frames.py` (todos) / `python idle_frames.py homeless cartonero` (algunos) /
    `python idle_frames.py --check` (no escribe: sale ≠ 0 si una hoja falta o el contrato no coincide con
    el manifest).
  - Reglas: sólo claves de `characters` **sin** `sp_` y **sin** `__` (pinta: nunca cuadros base); la hoja
    va a `AnimPacks/<odrTag>/`; PNG cuantizado (`Image.quantize(256, method=FASTOCTREE)` sobre RGBA, como
    los cuadros del cofre), `optimize=True`, sin metadatos con fecha (idempotencia).

**Oráculo:** pipeline sin salteados (`unittest discover`) + `python idle_frames.py --check` en verde.

- [ ] **Step 1: RED — `test_idle_frames.py`** (fixture: un `.mov` HEVC con alfa de 9 cuadros, 64²,
  esquinas transparentes y centro opaco, generado una vez con `hevc_videotoolbox -alpha_quality` como
  `video_assets.encode` y **versionado** en `tests/fixtures/idle_fixture.mov`, < 50 KB; nada de
  `skipTest`):
  - `test_indices_uniformes_sin_repetir_el_cierre`: `sample_indices(121, 16) == [0, 8, 15, 23, 30, 38,
    45, 53, 60, 68, 75, 83, 90, 98, 105, 113]` (`int(i * 120 / 16 + 0.5)`), nunca el 120.
  - `test_hoja_tiene_la_grilla_y_el_alfa`: la hoja de 16 × 256 es 1024²; un cuadro transparente en la
    esquina queda con alfa 0; el centro opaco, 255.
  - `test_excluye_especiales_y_pintas`: con un manifest de fixture con `homeless`, `sp_coach`,
    `homeless__pijama` → sólo `homeless`.
  - `test_va_a_la_carpeta_del_pack`: `homeless` → `AnimPacks/anim-piso-1/idle_homeless.png`.
  - `test_es_idempotente`: dos corridas → mismos bytes (hash).
  - `test_check_detecta_faltantes_y_desfasajes`: borrar una hoja o cambiar `sourceFrames` → `--check` ≠ 0.
  - `test_contrato_real_coincide` (sobre el árbol real): cada tipo de `characters` sin `sp_`/`__` tiene
    entrada; cada entrada tiene su PNG en la carpeta de su `odrTag`; ninguna hoja pesa > 300 KB; el total
    ≤ 10 MB.
- [ ] **Step 2: GREEN** — `idle_frames.py` (docstring con el porqué, como `chest_video_frames.py`).
- [ ] **Step 3: correr** sobre los 43, `--check` verde, anotar en el reporte el total y el peor pack.
  Mirar 4 hojas a ojo (las del Step 2 del spike).
- [ ] **Step 4:** commits: `feat(pipeline): las hojas de cuadros de los clips base` (script + tests) y
  `feat(arte): los cuadros de los 43 personajes del tablero` (PNG + JSON).

**No se hace:** tocar `video_assets.py` (E8e T8) ni `project.yml`; cuadros de `sp_*` o de pintas.

---

### Task 10c: El runtime, sin `BoardScene`

> ⛔ Depende de T10b (el contrato real). No ∥ con E6b T5 (`CharacterNode`).

**Objetivo:** todo lo que hace falta para animar el tablero, probado, sin tocar `BoardScene`.

**Files:**
- Create: `FisuEvolution/Managers/IdleFrames.swift`, `FisuEvolution/Scenes/BoardIdleAnimator.swift`
- Modify: `FisuEvolution/Scenes/Nodes/CharacterNode.swift`, `FisuEvolution/UI/Art/Video/VideoPlayerPool.swift`
- Create: `FisuEvolutionTests/IdleFramesManifestTests.swift`, `FisuEvolutionTests/BoardIdleAnimatorTests.swift`,
  `FisuEvolutionTests/CharacterNodeIdleTests.swift`
- Modify: `FisuEvolutionTests/CharacterNodePoolTests.swift`, `FisuEvolutionTests/VideoPlayerPoolTests.swift`
- `/opt/homebrew/bin/xcodegen generate` (archivos nuevos)

**Interfaces:**

```swift
/// El contrato de `idle_frames.json` (T10b). Puro.
struct IdleFramesManifest: Decodable, Sendable, Equatable {
    struct Entry: Decodable, Sendable, Equatable { let file: String; let odrTag: String? }
    let schemaVersion: Int
    let frames: Int
    let cell: Int
    let columns: Int
    let fps: Double
    let types: [String: Entry]
    static let empty: IdleFramesManifest
    static func load(from bundle: Bundle) throws -> IdleFramesManifest
    static let main: IdleFramesManifest          // sin archivo o roto → .empty (nada depende de él)
    /// Los rects normalizados de cada cuadro en la hoja (origen abajo-izquierda, el de SpriteKit).
    func frameRects() -> [CGRect]
}

/// Decodifica una hoja fuera del hilo principal. Los tests inyectan una que devuelve una imagen hecha
/// en memoria, o `nil`.
protocol IdleSheetLoader: Sendable {
    func decode(url: URL) async -> CGImage?
}

@MainActor
final class BoardIdleAnimator {
    init(manifest: IdleFramesManifest = .main, packs: ArtPacks = .shared,
         pool: VideoPlayerPool = .shared, loader: any IdleSheetLoader = ImageIOIdleSheetLoader(),
         bundle: Bundle = .main, maxAnimated: Int? = nil)
    /// Lo llama `BoardScene` al final de cada `renderPlacements`: los nodos del piso visible por celda y
    /// las celdas con pinta. Pide los packs de los tipos nuevos, suelta los que salieron, y anima o
    /// aquieta cada nodo según la regla. Idempotente.
    func sync(nodes: [Int: CharacterNode], skinnedSlots: Set<Int>)
    /// Suelta hojas y packs (deinit también).
    func stop()
    // Para tests:
    var loadedTypes: Set<String> { get }
    var requestedTags: Set<String> { get }
    var animatedSlots: Set<Int> { get }
}
```

- **La regla de "anima"**: `!skinnedSlots.contains(slot) && node.showsRealArt && hoja cargada y
  precargada && pool.policy.allowsLoops && !degradado por memoria && (maxAnimated == nil || la celda está
  entre los maxAnimated más cercanos al centro del piso)`. Si no: `node.setIdleFrames(nil, …)`.
- **Fase:** el arreglo de cuadros rotado `slot % frames` (determinista; dos del mismo tipo no van en
  espejo).
- **Memoria:** escucha `UIApplication.didReceiveMemoryWarningNotification` (con `Task` + `notifications(named:)`,
  como `VideoPlaybackObserver`): suelta todas las hojas, aquieta todo y queda **degradado hasta el próximo
  cambio de tipos** (no recarga en el acto).
- **Packs:** `packs.request(tag, urgent: false)` por tag nuevo y `whenAvailable` → decodificar; al salir
  un tipo, `cancelWait` + `release` si ningún otro tipo cargado comparte el tag.

```swift
// CharacterNode
private(set) var showsRealArt: Bool          // lo fija configure(hasRealArt:)
var isIdleAnimating: Bool { get }            // hay acción "idle" en el sprite
/// `nil` corta la animación y deja la textura del configure. Mismo arreglo y misma fase → no re-monta.
func setIdleFrames(_ frames: [SKTexture]?, timePerFrame: TimeInterval, phase: Int)

// VideoPlayerPool
@discardableResult func observePolicy(_ handler: @escaping @MainActor (VideoPlaybackPolicy) -> Void) -> UUID
func cancelPolicyObservation(_ token: UUID)
```

**Oráculo:** `Tools/v2/oraculo.sh tarea IdleFramesManifestTests BoardIdleAnimatorTests
CharacterNodeIdleTests CharacterNodePoolTests CharacterFacingTests VideoPlayerPoolTests`

- [ ] **Step 1: RED — `CharacterNodeIdleTests`** (`CharacterNode` pelado, texturas de 4×4 hechas en el test):
  - `framesRunOnTheSprite`: `setIdleFrames([a,b,c], …)` → `isIdleAnimating`.
  - `nilRestoresTheConfiguredTexture`: tras `nil`, la textura del sprite es la del `configure`.
  - `configureStopsTheIdle`: un `configure` nuevo (otro tipo) corta la animación.
  - `sameFramesDoNotRemount`: dos llamadas iguales → la misma acción (no reinicia la fase).
  - `facingSurvivesTheIdle`: `setFacing(left: true)` + animación → `isFacingLeft` sigue `true`.
  - `placeholderHasNoRealArt`: `configure(hasRealArt: false)` → `showsRealArt == false`.
- [ ] **Step 2: RED — `CharacterNodePoolTests.recycledNodeStopsIdle`**: un nodo animado reciclado y
  vuelto a pedir sale con `isIdleAnimating == false` (la trampa de `removeAllActions` sobre el nodo).
- [ ] **Step 3: RED — `VideoPlayerPoolTests`**: `observePolicyFiresOnChangeOnly` (dos `update` iguales →
  un aviso); `cancelledObserverIsSilent`.
- [ ] **Step 4: RED — `IdleFramesManifestTests`**:
  - `decodesTheRealFile` (`load(from: .main)`): `frames`, `cell`, `columns` > 0; `fps` > 0.
  - `everyEntryIsABoardTypeWithClip`: cada clave es un tipo de `tiers.json` **y** clave de
    `LoopsManifest.main.characters`; ninguna `sp_*` ni `__`; su `odrTag` == el del clip.
  - `everyBoardTypeWithClipHasFrames`: al revés (los 43).
  - `frameRectsTileTheSheet`: `frames` rects, disjuntos, dentro de `[0,1]²`, el primero arriba-izquierda
    de la hoja (origen de SpriteKit abajo-izquierda: `y` del primero = `1 - 1/rows`).
- [ ] **Step 5: RED — `BoardIdleAnimatorTests`** (manifest de fixture con dos tipos en dos tags,
  `ArtPacks(source:)` de prueba que completa cuando el test dice, loader que devuelve una `CGImage` de
  `cell * columns` hecha en memoria, `VideoPlayerPool(policy: .allowAll)`; esperar con `await` a que el
  loader y el `preload` terminen — un `await animator.settled()` interno de test o sondeo con
  `Task.yield` acotado):
  - `requestsOnlyVisibleTypes`: `sync` con nodos de `homeless` → `requestedTags == ["anim-piso-1"]`,
    nada del otro tag.
  - `stillUntilPackArrives`: pack sin llegar → `animatedSlots` vacío; llega → la celda anima.
  - `skinnedSlotStaysStill`: celda en `skinnedSlots` → no anima aunque el tipo esté cargado.
  - `placeholderStaysStill`: nodo con `showsRealArt == false` → no anima.
  - `policyStopsAndResumes`: `pool.update(policy: .allowAll.with(.reduceMotion))` → nada anima;
    vuelta a `.allowAll` → vuelve. Lo mismo con `.lowPower` y `.thermal`.
  - `forcedStillNeverLoads`: con `.forcedStill` desde el arranque no anima (y no hace falta decodificar:
    `loadedTypes` puede llenarse, pero `animatedSlots` queda vacío).
  - `leavingTypeReleasesItsPack`: `sync` sin `homeless` → `loadedTypes` sin él y el `ArtPackRequest` de
    prueba recibió `end()`; otro tipo del mismo tag lo retiene.
  - `memoryWarningDegradesUntilTypesChange`: postear la notificación → todo quieto, `loadedTypes` vacío;
    `sync` con los mismos tipos → sigue quieto; `sync` con otro conjunto → vuelve a cargar.
  - `maxAnimatedPicksTheNearest`: con `maxAnimated: 2` y 4 celdas → animan las 2 más cercanas al centro.
  - `phaseDependsOnSlot`: dos celdas del mismo tipo arrancan en cuadros distintos.
  - `brokenSheetStaysStill`: loader devuelve `nil` → quieto, sin reintento en lazo.
- [ ] **Step 6: GREEN** — `IdleFrames.swift`, `BoardIdleAnimator.swift` (con `ImageIOIdleSheetLoader`:
  `CGImageSourceCreateWithURL` + `CGImageSourceCreateImageAtIndex` con `kCGImageSourceShouldCacheImmediately`
  en `Task.detached`; si `CGImage` no cruza el borde de concurrencia en Swift 6, el plan B es
  `SKTexture(imageNamed:)` sobre la URL + `SKTexture.preload` como `UIArt.warmCharacterImage`), los
  cambios de `CharacterNode` (acción con clave `"idle"` en el **sprite**; `configure` la corta) y
  `CharacterNodePool.obtain` (`node.setIdleFrames(nil, …)`), `VideoPlayerPool.observePolicy`.
- [ ] **Step 7:** oráculo. Commits: `feat(tablero): el nodo del personaje sabe respirar con cuadros`,
  `feat(tablero): el animador carga sólo los tipos del piso que mirás`.

**No se hace:** tocar `BoardScene`; animar el vuelo del ascenso; leer `activeSkinID` (lo pasa la escena).

---

### Task 10d: El cableado (tres líneas de `BoardScene`) y el banco

> ⛔ Depende de T10c y de una **ventana de `BoardScene`** (después de E5b T3; no ∥ E6b T5 ni E8e T8).
> Si la ventana no existe al despachar: el subagente hace todo lo demás, **para con `NEEDS_CONTEXT`** y
> deja las tres líneas escritas en el reporte; las aplica el controlador.

**Objetivo:** el tablero real anima; el banco de medición queda en DEBUG para el gate final y para G1.

**Files:**
- Modify: `FisuEvolution/Scenes/BoardScene.swift` 🔥 — **exactamente** estas tres líneas:

```swift
// propiedades (junto a `revealVideo`)
let idleAnimator: BoardIdleAnimator
// init, después de `self.packs = packs`
idleAnimator = BoardIdleAnimator(packs: packs, pool: videoPool)
// final de renderPlacements(content:), después de `renderedUnits = wanted`
idleAnimator.sync(nodes: characterNodes, skinnedSlots: Set(wanted.filter { $0.value.skinID != nil }.keys))
```

  (`deinit` no cambia: el animador suelta sus packs en su propio `deinit`.)
- Create: `FisuEvolutionTests/BoardIdleWiringTests.swift`
- Modify (tibios, DEBUG): `FisuEvolution/Game/State/GameState+Debug.swift` (`debugStartIdleBench(still:)`:
  piso 3 desbloqueado con sus 10 tipos sin pinta en el tablero + `FrameRateProbe.shared.start()`),
  `FisuEvolution/Game/State/GameState+Bootstrap.swift` (`--uitest-idle-bench`, `--uitest-idle-bench-still`
  al lado de `--uitest-anim-stress`)

**Oráculo:** `Tools/v2/oraculo.sh tarea BoardIdleWiringTests BoardIdleAnimatorTests RevealVideoTests
CharacterNodePoolTests` + Receta R `BoardGestureUITests`, `BoardChangeUITests`, `MergeAllChainUITests`
(bajo `--uitest*` todo quieto: nada cambia) + **capturas con `--uitest-video`** en el SE y el 16 Pro
(piso 1 y piso 3: se mueven; un tipo con pinta puesta: quieto; Reduce Motion del simulador: quieto).

- [ ] **Step 1: RED — `BoardIdleWiringTests`** (patrón de `RevealVideoTests`: escena con
  `makeGameState()`, `layoutBoard()`):
  - `syncReceivesTheVisibleNodes`: tras `layoutBoard`, las celdas del animador (`animatedSlots ∪` las
    quietas que recibió — exponer `syncedSlots` para test) == las celdas de `gameState.visiblePlacements`.
  - `skinnedSlotIsPassedAsSkinned`: con una pinta activa para un tipo del piso (`debugEquipSkin` o el
    helper que exista en `+Debug`), su celda llega en `skinnedSlots`.
  - `floorChangeResyncs`: cambiar de piso → el animador recibe las celdas del piso nuevo.
- [ ] **Step 2: GREEN** — las tres líneas; el banco DEBUG.
- [ ] **Step 3:** oráculo + UI + capturas. Commits: `feat(tablero): los personajes sin pinta respiran
  con su clip`, `feat(debug): el banco del tablero animado`.

**No se hace:** cambiar la reconciliación, el paseo ni el volteo; el vuelo del ascenso.

---

### Task 10e: Cierre de T10 (controlador; 🔒 gate final del dueño)

- [ ] **Step 1:** `Tools/v2/oraculo.sh completo` sobre la punta con T10d integrada → VERDE.
- [ ] **Step 2: 🔒 el dueño en su SE**, con la partida real (no el banco): Debug con la sonda, 60 s en
  el piso 3 con el fondo vivo + visitante hablando; 10 min de partida cambiando de piso (sin jetsam, la
  memoria no crece); Reduce Motion y bajo consumo (todo quieto, sin hueco); primera entrada a un piso con
  el pack sin bajar (quieto y después respira); modo avión (quieto para siempre, sin error). Vara: la de
  T10a Step 5. Si no pasa, el escalón siguiente de la escalera de T10a es **una línea**
  (`maxAnimated:` o `minPhysicalMemoryGB` en el `init` del animador) o volver a correr T10b con otros
  parámetros.
- [ ] **Step 3: docs.** `Docs/SESION-<fecha>-v2-e8e-t10.md`; `Docs/HANDOFF.md` §4/§5 (el tablero anima
  con cuadros, no video; `idle_frames.json`; "una pinta nunca usa cuadros base"), §7 (trampas:
  `removeAllActions` del pool no llega al sprite; el `.mov` reemplazado pide volver a correr
  `idle_frames.py`; Xcode aplana los packs); `tasks.md` (filas, §3.1 suma T10d a `BoardScene`). Journal.

---

### Task 10f (opcional): La carta base de Personalización, animada

> ⛔ Tras **E6b T5** (toca `CustomizationView`). Sólo si el dueño confirma la duda 11.

**Objetivo:** en Personalización, la carta de la **base** del tipo (sin pinta) muestra el cuerpo entero
en movimiento con su clip (`AnimatedArtView(.character(tipo), role: .icon)`): es una sola por grilla
(regla de E8e); las cartas de pinta, su PNG.

- [ ] RED (test de la función estática que decide qué carta lleva clip) → GREEN → Receta R de los UI de
  Personalización (póster bajo `--uitest*`) → captura con `--uitest-video`. Commit:
  `feat(video): la base se mueve en Personalización`.

---

## Dudas con default

Ninguna frena: la ejecución sigue con el default.

1. **16 cuadros de 256 px en PNG8**, muestreados uniforme sobre el loop. **Default:** así; el spike puede
   bajar por la escalera. 256 px queda **por debajo** del PNG quieto en pantalla (`@2x` 384, `@3x` 512;
   el arte real mide `cellSize · 0,92 · 2,2` pt): el personaje animado se ve un poco más blando que el
   quieto. Si el dueño lo nota en el SE, la alternativa es 320 px (≈ +56 % de memoria).
2. **El ritmo del clip** (16 cuadros en 5,04 s ≈ 3,2 fps, "stop motion" con el movimiento real) vs más
   rápido (6–8 fps, el movimiento se acelera). **Default:** el del clip; el dueño lo ve en T10a Step 5.
3. **Los 53 son 43 en el tablero**: los 10 `sp_*` salieron del tablero (E4b T9); en el escenario los
   mueve E8e T2. **Default:** sin hojas para `sp_*`.
4. **Una pinta (de textura o de tinte) queda quieta** en el tablero, siempre. Cuando existan clips de
   pinta (E8e T8), `idle_frames.py` podría sacarles hoja; **no** está en este plan.
5. **Las hojas viajan en el pack del clip** (`anim-piso-<n>`): entrar a un piso baja también sus `.mov`
   (0,2–1,7 MB por pack). Un tag aparte (`idle-piso-<n>`) ahorraría eso pero toca `project.yml` 🔥.
   **Default:** el pack del clip.
6. **La política es la de los videos** (`allowsLoops`): también aquieta con "reproducción automática de
   video" apagada y en segundo plano. **Default:** así (es "movimiento", como un loop).
7. **Aviso de memoria → todo quieto hasta el próximo cambio de piso** (no recarga solo). **Default:** así.
8. **El vuelo del ascenso y el nodo que entra al contratar quedan quietos** hasta el próximo
   `renderPlacements` (el vuelo dura ~1 s y lo sigue la revelación en video). **Default:** así.
9. **"Los N más cercanos"** = al centro del piso visible (no al dedo). Sólo si el gate lo pide.
10. **La animación sigue durante el swipe y el vuelo del mapa** (no se suspende como los videos con
    `.scrolling`): son texturas ya subidas, no decodifican. **Default:** así; si el banco muestra
    tirones en el vuelo, el animador escucha la misma suspensión.
11. **"En TODO lugar donde aparezca el personaje sin skin"**: además del tablero, el barrido sobre
    `2dcf084` encuentra quieta sólo **la carta base de Personalización** (`CustomizationView`); la ficha,
    la revelación, el drop del especial y el Álbum ya usan video (E8d / E8e T7); Mejoras usa la cara
    (`faceKey`, sin clip de busto para los tipos); el cofre, el premio de pinta y la vista previa de la
    tienda muestran **pintas** (nunca video base). **Default:** T10f opcional tras E6b T5.
12. **El gate del dueño se mide con la build Debug** (la sonda es DEBUG), como el banco de E8d; el G1
    formal en Release + Instruments sigue siendo de E8d T15. **Default:** así.

## Filas para `tasks.md` §5

Al final de la sección "E8e — Videos al juego", después de `E8e-T9`:

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E8e-T10 | Plan de E8e T10: el tablero animado con los videos base | ✅ | — | — | (el commit de este plan) | `2026-10-10-v2-e8e-t10-tablero-animado.md`; 6 tareas (10a–10f); 12 dudas con default; gate 🔒 en el SE antes de integrar |
| E8e-T10a | Spike con medición: cuadros, tamaño, formato, ritmo | ⏳ | — | rama desechable `v2i/e8e-t10a-spike` (no se integra) | | **opus**; compila (cuenta para el tope de 3); reporte en `.superpowers/sdd/e8e/task-10a-report.md` con "Parámetros fijados"; **🔒 el dueño mide en su SE** (`--uitest-idle-bench[-still] --uitest-video`, sonda DEBUG): ≥ 59 fps, ≤ 1 % > 25 ms, animado − quieto ≤ 20 MB; si no entra, escalera 12 cuadros → 192 px → ASTC → N más cercanos → quieto < 3 GB |
| E8e-T10b | Pipeline: las hojas de cuadros y `idle_frames.json` | ⛔ | T10a 🔒 | nuevos; 43 PNG en `AnimPacks/anim-piso-*` | | sonnet, revisión ninguna; `idle_frames.py` importa `odr_tag` de `video_assets.py` (no lo edita: es de T8); sin `sp_` ni `__`; ≤ 10 MB ODR, base +0; sin `project.yml` |
| E8e-T10c | El runtime sin `BoardScene`: `BoardIdleAnimator`, `CharacterNode.setIdleFrames`, `observePolicy` | ⛔ | T10b | CharacterNode, VideoPlayerPool | | sonnet, el controlador lee el diff; no ∥ E6b T5 (CharacterNode); decodifica fuera del main y aplica tras `preload`; el pool de nodos corta la animación del sprite |
| E8e-T10d | El cableado: tres líneas de `BoardScene` + banco DEBUG | ⛔ | T10c; ventana de BoardScene | 🔥 BoardScene (3 líneas); +Debug, +Bootstrap (tibios) | | sonnet, controlador lee el diff + capturas; después de E5b T3, no ∥ E6b T5 ni E8e T8; sin ventana → `NEEDS_CONTEXT` y las aplica el controlador |
| E8e-T10e | Cierre de T10 (controlador) | ⛔ | T10d | `Docs/` | | `completo`; **🔒 el dueño en su SE con la partida real** (piso 3, 10 min, Reduce Motion, bajo consumo, ODR, modo avión); docs y trampas |
| E8e-T10f | La carta base de Personalización, animada (opcional) | ⛔ | E6b-T5; duda 11 | CustomizationView | | sonnet, capturas; una sola `AnimatedArtView` por grilla, la base |

Y en §3.1, la fila de `BoardScene.swift` suma **E8e T8, T10d**.
