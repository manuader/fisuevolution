# E8d — Todo el juego animado, el lado Swift: pool, componentes, lugares, sonido y ODR · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que los videos de Higgsfield se vean en todo el juego sin bajar de 60 fps en el iPhone SE
ni en el iPad (spec del dueño `Docs/superpowers/specs/2026-10-08-v2-e8-animaciones-design.md`):
**un pool de reproductores** con tope de 3 decodificadores vivos, **un componente para SwiftUI**
(`AnimatedArtView`) y **uno para SpriteKit** (`LoopingVideoNode`) con póster instantáneo y
fundido de 0,15 s, cada lugar del inventario cableado (o dejado como contrato para la épica que
arma la pantalla), los **efectos de sonido nuevos**, **On-Demand Resources** para lo pesado, y la
**medición de fps como gate**. La primera tanda (18 retratos, 4 objetos, cabina, 3 cinemáticas)
está aprobada y en el bundle; **la segunda tanda (cuerpo entero, visitantes en acción y hablando,
eventos, fondos, íconos de la tienda, intro) espera el gate 🔒 del dueño**, y el código queda listo
para que entre **por manifest, sin tocar Swift**.

**Architecture:** `loops_manifest.json` es el único contrato entre el pipeline y el juego.
`LoopsManifest` lo lee entero (las cuatro secciones de hoy y las seis de la segunda tanda, que
decodifican vacías mientras no existan) y resuelve un `ArtClip` (`.portrait(id)`, `.object(id)`,
`.character(id)`, `.talking(id)`, `.visitorAction(id)`, `.event(id)`, `.shopIcon(id)`,
`.floor(id)`, `.cinematic(CinematicID)`) a una URL del bundle o de un pack ODR. Sin entrada o sin
archivo, `nil`, y quien dibuja muestra **el PNG quieto de siempre** (regla de oro del pipeline).
`VideoPlayerPool` decide **quién está vivo**: un rol por lugar (`background`, `popup`, `icon`,
`fullscreen`), el más nuevo de cada rol, tope 3; `fullscreen` (la cinemática) suspende a todos; la
política (`VideoPlaybackPolicy`: Reduce Motion, Modo de bajo consumo, reproducción automática de
video, térmica `serious`, app en segundo plano, `--uitest*`) apaga todo a póster. Cada lugar es un
**holder** que crea su `AVQueuePlayer` + `AVPlayerLooper` cuando el pool lo pone vivo y lo suelta
cuando lo baja; el póster está siempre dibujado debajo, así nunca hay hueco ni parpadeo. El tablero
**no** usa video para los personajes (spec): sólo el fondo del piso visible y la revelación de un
tier nuevo.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
SpriteKit (`SKVideoNode`) · AVFoundation (`AVQueuePlayer`, `AVPlayerLooper`, `AVPlayerLayer`) ·
Foundation `NSBundleResourceRequest` (ODR) · `CADisplayLink` (sonda de fps, sólo DEBUG) · Swift
Testing · XCUITest · XcodeGen (el `.xcodeproj` no se versiona) · Python 3
(`Tools/audio-synth/generate_audio.py`, `Tools/asset-pipeline/scripts/video_assets.py`,
`Tools/v2/catalogo.py`).

**Fuente:** la spec del dueño (manda); `Docs/PLAN-v2.md` E8 ("Cuándo se reproducen", "un solo
`AVPlayer` activo a la vez; Reduce Motion muestra el cuadro final quieto"); el reporte de la
reconciliación (`version-2/.superpowers/sdd/2026-10-08-v2-e13b/reconciliar-videos-report.md`:
esquema `portraits/objects/cabin/cinematics`, la cabina con alfa, el tope ×5); los planes
`2026-10-08-v2-e8b-cinematicas.md` (T4–T12 pendientes), `2026-10-08-v2-e13b-ascensor-barra.md`
(T5 ✅, T6 ⏳), `2026-10-08-v2-e8c-fusionar-todo.md` (no se re-planifica: sólo se evita chocar);
`tasks.md` §3, §4.2 y §5 E8/E8b/E8c/E13b. El código en `5e3b707`.

**Rama de la épica:** `v2/e8-anim`, desde `version-2`. Cada tarea sale de su punta en un worktree
propio (manual, `.claude/worktrees.nosync/v2i-e8d-tN`) y el controlador integra de a una.

**Fuera de este plan:** el pipeline de la segunda tanda (kinds nuevos de `video_assets.py`, recorte,
regeneración de lo que el dueño marque `regenerar`) es de la sesión del dueño (spec, "Orden" 1); este
plan fija **el contrato** que ese pipeline tiene que escribir (sección "El manifest de la segunda
tanda") y la tarea que lo integra (T14). La cadena de "Fusionar todo" es de E8c. El cofre
(`ChestCinematicPlayer`, `ChestOpeningView`) no se toca (HANDOFF §7).

## Qué reemplaza (decisión explícita)

| Tarea previa | Queda | Por qué |
|---|---|---|
| **E8b T4** `LoopsManifest` + `CinematicID` | **Reemplazada por E8d T1** | El esquema ya no es `portraits/cinematics`: es `portraits/objects/cabin/cinematics` + las seis secciones de la segunda tanda. La API pública que E8b T4 prometía (`LoopsManifest.load(from:)`, `.main`, `portraitURL(for:in:)`, `cinematicURL(for:in:)`, `CinematicID`) **se conserva** (superset), así E8b T8–T11 y E4b T3 no cambian sus llamadas. `CinematicID` suma `.intro` |
| **E8b T5** `VideoSlot` + `LoopingPortraitView` | **Reemplazada por E8d T2 + T3** | "Un solo video a la vez" pasa a "≤ 3 vivos por rol" (spec). `VideoSlot` no se crea; `LoopingPortraitView` no se crea: su lugar es `AnimatedArtView(.portrait(id)) { foto }` |
| **E8b T6** El especial que te cayó, animado | **Reemplazada por E8d T5** | Mismo lugar (`SpecialDropView`), con el componente nuevo; suma la ficha (`CharacterSheetView`, cuerpo entero) |
| E8b T7 `seenCinematics` | ✅ queda | ya integrada (`4714671`) |
| **E8b T8** El turno de la cinemática | **Queda, con dos cambios** | (1) depende de **E8d T1** (no de E8b T4); (2) `CinematicID.intro` existe con `maxPlays == 1`, y `isCinematicDue` además pide `VideoPlaybackPolicy.allowsCinematics` (Reduce Motion / sin reproducción automática → no pide turno y **no** cuenta vista; ver duda 2). Lo demás, igual (prioridad 2, tope 12 s, `releasePayload`, `--uitest-cinematic=<id>`) |
| **E8b T9** La cinemática en pantalla | **Queda, con tres cambios** | (1) depende de **E8d T2** (no de E8b T5); (2) `VideoSlot.shared.claim(...)` se reemplaza por un lease `fullscreen` del pool (`VideoPlayerPool.shared.acquire(holder, role: .fullscreen)`, que suspende a los demás) y su `release` en `finish()`; (3) en el mismo `RootView` 🔥 suma **una línea**: el overlay del cofre lleva `.suspendsVideoPool()` (E8d T2) para que el fondo animado no decodifique debajo del cofre (sin tocar `ChestOpeningView`) |
| E8b T10 Reencarnación y Dios | queda igual | — |
| E8b T11 El arresto | queda igual | — |
| **E8b T12** Cierre de E8b | **Reemplazada por E8d T15** | El cierre de E8d absorbe sus pasos de dispositivo (HEVC-alfa por hardware, memoria, peso) dentro de los gates |
| **E13b T6** El viaje montado | **Queda igual** (no espera a E8d) | La cabina sigue con `ElevatorCabinWarmup` (un player por vez, revisión opus aprobada, medido): **no** se migra al pool. Lo que el pool necesita del viaje (suspender los demás videos durante el viaje y reservar un decodificador mientras la cabina calienta) lo suma **E8d T10** después de E13b T6/T8, en `ElevatorRideOverlay` y `ElevatorCabinWarmup`. Así la prioridad alta del dueño (E13b T6) no se frena |
| E8c (todo) | sin cambios | E8d evita chocar: `AudioManager` (E8c T4 ↔ E8d T6), `CelebrationQueue` (E8c T2 ↔ E8b T8), `BoardScene` (E8c T7/T8 ↔ E8d T8/T9), de a una |

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning rompe el
  build. Nada de `Timer` para lógica de juego (regla 2 del HANDOFF). Todo lo de AVFoundation vive en
  `@MainActor`; esperar `readyToPlay`/`isReadyForDisplay` con **sondeo barato** (50 ms, con tope),
  no con KVO (closure `@Sendable` que no convive con AVPlayer: el criterio del cofre).
- **AVFoundation siempre con revisión opus y con respaldo estático/vectorial**: toda vista o nodo
  con video dibuja el póster primero y queda en póster si el video no carga, falla o el pool no la
  pone viva.
- **El `body` de una vista no crea objetos con efectos.** El `AVQueuePlayer` nace en la `UIView`
  (`makeUIView`) cuando el pool la pone viva, nunca en el `body` ni en un `@State` inicializado en la
  declaración. El manifest se lee una vez (`static let main`) o llega por `Environment`.
- **`isOpaque = false`** en toda vista de video (la pantalla en negro del 2026-09-06), también en las
  opacas. `ffprobe` no ve el alfa del HEVC de Apple: el alfa se sabe por el manifest (`alpha`).
- **Xcode aplana los recursos**: los videos se buscan por nombre (`loop_<id>.mov`, `obj_<id>.mov`,
  …), nunca por carpeta.
- **El `.xcodeproj` no se versiona**: `/opt/homebrew/bin/xcodegen generate` al agregar o borrar un
  archivo Swift, un test o un recurso, en el mismo paso.
- **Nada nuevo corre bajo XCTest ni bajo `--uitest*`**: la política del pool arranca en `forcedStill`
  en los dos (todo póster); un UI test que quiera video pasa `--uitest-video`. Los UI tests de
  siempre ven el póster y siguen pasando sin cambios.
- **Reduce Motion muestra el cuadro final quieto**: un loop muestra su póster (primer cuadro = último,
  por construcción); un clip de una vez (`.once`, p. ej. `paquete_abre`) llama a su `onEnd` en el acto
  y quien lo usa dibuja el estado final.
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos** (trampa
  9a-bis); la capa de video es `accessibilityHidden(true)` y lleva su id sólo en la `UIView` hoja
  (`art.video`), para que un UI test pueda asertar que **no** hay video bajo `--uitest*`. Los UI tests
  asertan por id, nunca por texto.
- **Strings nuevos, es + en, por `Tools/v2/catalogo.py`**: la tarea escribe
  `Tools/v2/claves-pendientes/e8d-tN.json`; si no es dueña del catálogo en la ola, commitea sólo el
  `.json` y descarta `Localizable.xcstrings`. Sólo la T11 tiene claves (1). Los textos del panel de
  debug siguen la convención del panel (literales).
- **Un dueño por archivo 🔥** (`GameState.swift`, `RootView.swift`, `BoardScene.swift`,
  `HUDView.swift`, `PlayerState.swift`, `+Bonus`, `project.yml`). Una tarea que necesita un 🔥 ajeno
  para con `NEEDS_CONTEXT`.
- **Sonidos**: todo efecto nuevo se sintetiza con `Tools/audio-synth/generate_audio.py` en el carácter
  de los de hoy, sale a `.caf` y entra a `AudioManager.SFX`. Ambiente (espera, zumbido) a **−18 dB**
  respecto de la acción; acción a −6 dB. Todo respeta los volúmenes de Ajustes y el Silencio de iOS
  (`AVAudioSession` `.ambient` de hoy). El crossfade de música por piso no se toca.
- **FisuJobs es la referencia visual.** Código limpio y con pocos comentarios (regla del dueño); el
  comentario que miente se corrige en el commit que lo vuelve mentira.
- **Commits en español, estilo de la casa** (`feat(video): …`, `feat(sonido): …`, `fix(…)`), **SIN
  `Co-Authored-By`**. Staging selectivo por archivo y `git diff --cached --stat` antes de cada commit.
  Un comando git por llamada.
- **Al cerrar cada tarea** (el controlador, nunca un subagente): integración, ledger, journal y
  `tasks.md`. Ningún subagente toca `Docs/`, `handoffs/`, el journal, `tasks.md` ni
  `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

```bash
# App: EconomyKit entero + build + esas clases de FisuEvolutionTests
Tools/v2/oraculo.sh tarea <Clases>

# Sonido (T6, T7)
PY=/Users/manuader/Desktop/projects/FisuEvolution/Tools/asset-pipeline/.venv/bin/python
"$PY" Tools/audio-synth/generate_audio.py sfx_<nombre> [sfx_<otro> …]   # sólo esos (registrados en SFX)
```

- Los **UI tests** que una tarea agrega se corren aislados con la **Receta R** de
  `Docs/superpowers/plans/2026-10-07-v2-e4a-visitantes-eventos.md` (`-only-testing:…/<Clase>`,
  simulador propio por UDID que se apaga y borra).
- ⚠️ "0 tests" con éxito no prueba nada: la salida tiene que nombrar las clases. Ante un rojo en
  masa, `uptime` y `ps aux | grep '[x]codebuild'` antes de culpar al código.
- ⚠️ **El simulador decodifica el HEVC con alfa por software**: los fps y el primer cuadro del
  simulador **no** son la vara. La vara son los gates en dispositivo (sección "Gates").

## Las referencias, verificadas contra el árbol (`5e3b707`)

| Lo que usa el plan | Dónde está hoy | Qué significa para E8d |
|---|---|---|
| `loops_manifest.json` | `Resources/Data/loops_manifest.json`: `schemaVersion 1`, `portraits` (18), `objects` (4), `cabin` (2), `cinematics` (3); campos `file, width, height, fps, frames, alpha, audio, matte, keyColor` | T1 lo lee entero; las secciones nuevas con `decodeIfPresent ?? [:]` |
| `video_assets.py` `KINDS` | `retrato → portraits`, `objeto → objects`, `cabina → cabin`, `cinematica → cinematics`; `register` escribe **todas** las secciones de `KINDS` | la segunda tanda suma kinds; T14 los integra |
| Lector Swift del manifest | **no existe** (E8b T4 nunca corrió); `ElevatorCabinArt.resolve` busca la cabina por nombre | T1 lo crea; la cabina **sigue** por nombre (no se toca) |
| `ChestCinematicPlayer` | `UI/Popups/ChestCinematicPlayer.swift`: preroll + "calentado mudo" medido | no se toca; T3 copia su criterio de espera (sondeo 50 ms ×40) |
| `ElevatorCabinWarmup` | `UI/Elevator/ElevatorCabin.swift`: un `ChestCinematicPlayer` por vez, `prepare/release` | T10 le suma una reserva del pool |
| `ElevatorRideOverlay` | **no existe**: lo crea E13b T6 (en `FisuEvolutionApp.swift`) | T10 va después de E13b T6 y T8 |
| `seenCinematics` | `EngagementState.swift` (EK) ✅ E8b T7 | la usa E8b T8 y T11 (`intro`) |
| `SpecialDropView.portrait` | `UI/Popups/SpecialDropView.swift`, plato de 168 pt; RootView `:329-336` | T5 |
| `CharacterSheetView` | `UI/Popups/CharacterSheetView.swift`: `CharacterPortrait` (`:304`), `portraitMaxSide 248` | T5 (`.character(typeId)`) |
| Fondo del piso | `Scenes/Nodes/FloorNode.swift`: `background: SKCropNode`, sprite del `manifest.backgrounds[definition.background]` | T8 cuelga un `LoopingVideoNode` sobre ese sprite |
| Reveal del tier | `BoardScene.swift` (`RevealLayout`, `revealLayout(size:)`, `:176-258`) 🔥 | T9 |
| `AudioManager.SFX` | 17 casos; `play(_:)`, `stop(_:)`; ascensor ya tiene `spring/click/doors/motor/ding` (E13b T3) | T6 suma los nuevos; el ascensor sólo suma `cable` (duda 10) |
| `AudioWiringTests` | lista `declaredCases` escrita a mano; exige un `audio?.play(...)` en `Game/State` o `UI/Popups` | cada tarea suma a `declaredCases` **sólo** lo que cablea; T6 suma `pendingWiring` con dueño |
| El acento del evento | `GameState+Bonus.swift:326` `audio?.play(.event)` 🔥 | T7 (una línea) o E4a T9 si ya lo mudó a `+Events` |
| Panel de debug | `UI/DebugPanelView.swift` (tibio) | T13 (la sonda de fps) |
| ODR | **nada**: ni `ENABLE_ON_DEMAND_RESOURCES` ni `resourceTags` en `project.yml` | T12 (cargador), T14 (etiquetas, 🔥 `project.yml`) |

## El manifest de la segunda tanda (contrato que fija este plan)

Las secciones nuevas, todas con la misma `Entry` de hoy más **`odrTag`** opcional (sin la clave =
paquete base). El pipeline las escribe; Swift las lee desde T1 aunque vengan vacías.

| Sección | Id (la clave) | Archivo | Tamaño | Alfa | Dónde se ve | Rol del pool | ODR (default) |
|---|---|---|---|---|---|---|---|
| `characters` | el `typeId` del personaje o el id del especial (la misma clave que `assets_manifest.characters`) | `char_<id>.mov` | 384² o 512² | sí | ficha, revelación, Álbum | `popup` | `anim-piso-<n>` por piso; los especiales `anim-especiales` |
| `talking` | id del visitante o especial (`npc_*`, `sp_*`) | `talk_<id>.mov` | 512² | sí | globo abierto | `popup` | `anim-visitantes` |
| `visitorActions` | id del visitante (`npc_*`) | `act_<id>.mov` | 512² | sí | pedido / multa / chisme | `popup` | `anim-visitantes` |
| `events` | id del evento (`events.json`) | `ev_<id>.mov` | 512² | sí | popup y chip del evento | `popup` | `anim-eventos` |
| `shopIcons` | id del ítem de `oro_shop.json` | `shop_<id>.mov` | 384² | sí | tarjeta centrada de la tienda | `icon` | `anim-tienda` |
| `floors` | la clave de fondo del piso (`FloorDefinition.background`) | `floor_<id>.mov` | 1024² | no | el piso visible | `background` | base (spec: fondos en el paquete base) |
| `cinematics.intro` | `intro` | `cine_intro.mov` | 720×1280 | no, con audio | primera vez | `fullscreen` | base |

---

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `FisuEvolution/Managers/LoopsManifest.swift` | **nuevo** — el manifest entero, `ArtClip`, `CinematicID` (+`.intro`) | 1 |
| `FisuEvolutionTests/LoopsManifestTests.swift` | **nuevo** — gemelo Swift del pin de Python + secciones nuevas | 1 |
| `FisuEvolution/UI/Art/Video/VideoPlayerPool.swift` | **nuevo** — leases, roles, tope 3, suspensiones, reservas | 2 |
| `FisuEvolution/UI/Art/Video/VideoPlaybackPolicy.swift` | **nuevo** — la política pura y su observador del sistema | 2 |
| `FisuEvolutionTests/VideoPlayerPoolTests.swift` | **nuevo** | 2 |
| `FisuEvolution/UI/Art/Video/AnimatedArtView.swift` | **nuevo** — SwiftUI: póster + video con fundido, loop o una vez | 3 |
| `FisuEvolutionTests/AnimatedArtViewTests.swift` | **nuevo** | 3 |
| `FisuEvolution/Scenes/Nodes/LoopingVideoNode.swift` | **nuevo** — SpriteKit: póster + `SKVideoNode` | 4 |
| `FisuEvolutionTests/LoopingVideoNodeTests.swift` | **nuevo** | 4 |
| `FisuEvolution/UI/Popups/SpecialDropView.swift`, `CharacterSheetView.swift` | el especial y la ficha, animados | 5 |
| `Tools/audio-synth/generate_audio.py`, `FisuEvolution/Resources/Audio/*.caf` (11), `Audio/AudioManager.swift`, `FisuEvolutionTests/AudioWiringTests.swift`, `FisuEvolutionTests/AudioManagerTests.swift` | efectos nuevos A + `play(_:gain:pitch:)` + ambiente en loop | 6 |
| ídem + `GameState+Bonus.swift` 🔥 (una línea) | los 8 acentos de evento | 7 |
| `FisuEvolution/Scenes/Nodes/FloorNode.swift`, `BoardScene.swift` 🔥 | el fondo del piso visible, animado | 8 |
| `BoardScene.swift` 🔥 | la revelación con el cuerpo entero | 9 |
| `UI/Elevator/ElevatorCabin.swift`, `ElevatorRideOverlay.swift` (de E13b T6) | el viaje suspende el pool; reserva de la cabina; `sfx_elevator_cable` | 10 |
| `Game/State/GameState+Cinematics.swift`, `+Bootstrap.swift` (tibio) | la intro, la primera vez | 11 |
| `FisuEvolution/Managers/ArtPacks.swift`, `FisuEvolutionTests/ArtPacksTests.swift` | **nuevos** — ODR por etiqueta; `LoopsManifest.url` lo consulta | 12 |
| `FisuEvolution/Debug/FrameRateProbe.swift` (DEBUG), `UI/DebugPanelView.swift` (tibio), `+Bootstrap` (fixture `--uitest-anim-stress`) | la sonda de fps y memoria | 13 |
| `Resources/Loops/…`, `Resources/Cinematics/…`, `Resources/AnimPacks/<tag>/…`, `loops_manifest.json`, `project.yml` 🔥 | 🔒 la segunda tanda entra | 14 |
| `FisuEvolutionTests/AnimatedPlacesTests.swift` | **nuevo** — cada sección del manifest tiene quien la pida | 15 |

## Orden, olas y paralelismo

| T | Qué | 🔥 / tibios | Depende de | Revisión · modelo |
|---|---|---|---|---|
| 1 | `LoopsManifest` entero + `ArtClip` + `CinematicID.intro` | — (nuevos) | — | ninguna · sonnet |
| 2 | `VideoPlayerPool` + `VideoPlaybackPolicy` | — (nuevos) | — | **opus** · sonnet |
| 3 | `AnimatedArtView` | — (nuevos) | T1, T2 | **opus** · sonnet |
| 4 | `LoopingVideoNode` (+ medir alfa en `SKVideoNode`) | — (nuevos) | T1, T2 | **opus** · sonnet |
| 5 | El especial y la ficha, animados | `SpecialDropView`, `CharacterSheetView` (tibio: E13 T9) | T3 | ninguna (captura) · sonnet |
| 6 | Sonidos A (paquete, colchón, visitante, tienda, revelación, cable) | `AudioManager` (tibio: E8c T4, E8b T9), `generate_audio.py`, `AudioWiringTests` | — | ninguna (🔒 oído del dueño, no frena) · sonnet |
| 7 | Los 8 acentos de evento | 🔥 `+Bonus` (una línea) o `+Events` (si E4a T9 entró); `AudioManager`, `generate_audio.py` | T6 | ninguna · sonnet |
| 8 | El fondo del piso visible, animado | 🔥 `BoardScene`; `FloorNode` | T4 | **opus** · sonnet |
| 9 | La revelación con el cuerpo entero | 🔥 `BoardScene` | T8 | **opus** · sonnet |
| 10 | El viaje suspende los videos; reserva de la cabina; cable | `ElevatorCabin.swift`, `ElevatorRideOverlay` | T2, T6; **E13b T6, T8** | **opus** · sonnet |
| 11 | La intro, la primera vez | `+Cinematics`, `+Bootstrap` (tibio); catálogo (snapshot, 1 clave) | **E8b T10** | sonnet · sonnet |
| 12 | ODR: `ArtPacks` y el pedido por familia | — (nuevos) + `LoopsManifest`, `AnimatedArtView`, `LoopingVideoNode` | T1, T3, T4 | sonnet · sonnet |
| 13 | La sonda de fps y memoria (DEBUG) + fixture de estrés | `DebugPanelView`, `+Bootstrap`, `+Debug` (tibios) | T3, T4 | ninguna · sonnet |
| 14 | 🔒 La segunda tanda entra (pipeline + manifest + ODR + peso) | 🔥 `project.yml`; `Resources/…`, `loops_manifest.json` | **🔒 revisión del dueño**, T12; pipeline del dueño | controlador mira la hoja de contacto · sonnet |
| 15 | Cierre: gates en dispositivo + barrido de lugares | `Docs/` (controlador) | T1–T14, E8b T8–T11 | — |

```
Ola 1 (ya, ≤ 3 compilando)       T1 ║ T2 ║ T6           (T13 entra cuando haya lugar)
Ola 2                             T3 ║ T4 ║ E8b T8 (tras T1; ventana de GameState)
Ola 3                             T5 ║ T12 ║ E8b T9 (tras T2 + E8b T8; ventana de RootView) ║ T13
Ola 4                             T7 (ventana de +Bonus) ║ T8 (ventana de BoardScene) ║ E8b T10 → T11, E8b T11
Tras E13b T6 y T8                 T10
Tras T8                           T9 (BoardScene, de a una)
🔒 revisión de la segunda tanda   T14
Cierre                            T15 (gates)
```

**Reglas del paralelismo:**

1. **T1, T2, T3, T4, T12, T13 son archivos nuevos** (salvo los ajustes de T12 sobre T1/T3/T4, que van
   después de ellas): paralelos entre sí y con todo el resto del run.
2. **`AudioManager.swift`**: E8c T4 → E8d T6 → E8d T7 → E8b T9 (o E8b T9 antes de T6: conflicto
   textual, sin lógica cruzada; el que llega segundo rebasa). `generate_audio.py` y `AudioWiringTests`
   siguen la misma cadena (E8c T4 también los toca).
3. **`BoardScene.swift` 🔥**: la cadena de §3.1 (E13 T11 → E8c T7 → E8c T8 → …) y después **T8 → T9**.
   T8 y T9 son chicas en `BoardScene` (un nodo y dos llamadas); si no hay ventana, el controlador las
   aplica al integrar (precedente E12 T11). E5b T3 (la escena del paquete) y E4b T1/T6/T9 también
   esperan su ventana: el que llegue después usa `LoopingVideoNode` si ya existe.
4. **`ElevatorRideOverlay`**: lo crea E13b T6 y lo toca E13b T8 → **T10 después de los dos** (no
   frena a E13b).
5. **`+Bootstrap`/`+Cinematics`**: E8b T8 → E8b T10 → **T11**; T13 suma su fixture en `+Bootstrap`
   con un bloque propio (conflicto textual con T11: de a una).
6. **`CharacterSheetView`**: T5 no ∥ E13 T9.
7. **T14 no se despacha sin el 🔒**: `revision.json` con al menos una pieza de la segunda tanda en
   `va`. Entra sólo lo `va`; lo demás sigue en póster (el manifest no lo nombra).

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` | `FisuEvolutionTests/Support/GameStateFixture.swift` |
| contenido real | `try GameContentLoader.load(from: .main)` | `GameContentLoader.swift` |
| un video real chico con alfa | `Bundle.main.url(forResource: "loop_npc_vecina", withExtension: "mov")` (≈ 0,2 MB, 512², 121 cuadros) | `Resources/Loops/` |
| un video real opaco | `cine_arresto.mov` (720×1280) | `Resources/Cinematics/` |
| vaciar la cola | `while let s = gameState.showing { gameState.celebrationFinished(s) }` con tope | `CelebrationWiringTests` |
| el parser de `audio?.play(...)` | `AudioWiringTests.playArguments`/`enumCases` | `FisuEvolutionTests/AudioWiringTests.swift` |

---

### Task 1: El manifest entero, `ArtClip` y `CinematicID`

**Objetivo:** la app lee `loops_manifest.json` con **todas** sus secciones (las cuatro de hoy y las
seis de la segunda tanda, que decodifican vacías), resuelve un `ArtClip` a URL, y un test pinea lo
mismo que el de Python. Conserva la API que E8b T8–T11 y E4b T3 ya escriben.

**Files:**
- Create: `FisuEvolution/Managers/LoopsManifest.swift`
- Create: `FisuEvolutionTests/LoopsManifestTests.swift`
- `xcodegen generate`

**Oráculo:** `Tools/v2/oraculo.sh tarea LoopsManifestTests`
**Revisión:** ninguna · **Modelo:** sonnet.

- [ ] **Step 1: El test, en rojo:**

```swift
import Foundation
import Testing
@testable import FisuEvolution

@Suite("loops_manifest.json: el contrato del lado del juego")
@MainActor
struct LoopsManifestTests {
    /// El gemelo de los retratos que pinea `test_video_assets.py`.
    static let portraits: Set<String> = [
        "npc_comisario", "npc_conductor", "npc_ministro", "npc_puntero",
        "npc_sindicalista", "npc_turista", "npc_vecina", "npc_vendedor",
        "sp_alien_investor", "sp_arbolito", "sp_bug_simulacion", "sp_coach",
        "sp_contador_dios", "sp_cryptobro", "sp_demonio_arca", "sp_influencer",
        "sp_lizard", "sp_zombie_ceo",
    ]
    static let objects: Set<String> = ["paquete_abre", "paquete_espera", "colchon_abre", "colchon_espera"]

    @Test("la primera tanda: retratos y objetos 512² con alfa, mudos y en el bundle")
    func firstBatch() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(manifest.schemaVersion == 1)
        #expect(Set(manifest.portraits.keys) == Self.portraits)
        #expect(Set(manifest.objects.keys) == Self.objects)
        for (id, entry) in manifest.portraits {
            #expect(entry.file == "loop_\(id).mov", "\(id)")
            #expect(entry.width == 512 && entry.height == 512 && entry.alpha && !entry.audio, "\(id)")
            #expect(manifest.url(for: .portrait(id)) != nil, "\(id): en el manifest pero no en el bundle")
        }
        for (id, entry) in manifest.objects {
            #expect(entry.file == "obj_\(id).mov" && entry.alpha && !entry.audio, "\(id)")
            #expect(manifest.url(for: .object(id)) != nil, "\(id)")
        }
    }

    @Test("las cinemáticas que hay: 720×1280, opacas, con sonido; la intro todavía no")
    func cinematics() throws {
        let manifest = try LoopsManifest.load(from: .main)
        for id in [CinematicID.reencarnacion, .arresto, .dios] {
            let entry = try #require(manifest.cinematics[id.rawValue], "\(id.rawValue)")
            #expect(entry.file == "cine_\(id.rawValue).mov")
            #expect(entry.width == 720 && entry.height == 1280 && !entry.alpha && entry.audio)
            #expect(manifest.cinematicURL(for: id) != nil)
        }
        #expect(manifest.cinematicURL(for: .intro) == nil, "la intro es de la segunda tanda (🔒)")
    }

    @Test("la cabina está en su sección y fuera de las cinemáticas")
    func cabinIsItsOwnSection() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(Set(manifest.cabin.keys) == ["puertas_cierran", "puertas_abren"])
        #expect(manifest.cinematics.keys.allSatisfy { !$0.hasPrefix("ascensor") })
    }

    @Test("cada retrato de especial es de un especial que existe")
    func specialPortraitsBelongToSpecials() throws {
        let specials = Set(try GameContentLoader.load(from: .main).specials.specials.map(\.id))
        let manifest = try LoopsManifest.load(from: .main)
        for id in manifest.portraits.keys where id.hasPrefix("sp_") {
            #expect(specials.contains(id), "\(id): un loop que nadie pide")
        }
    }

    @Test("las secciones de la segunda tanda decodifican: vacías si faltan, llenas si vienen")
    func secondBatchSections() throws {
        let empty = try JSONDecoder().decode(LoopsManifest.self, from: Data(#"{"schemaVersion":1}"#.utf8))
        #expect(empty.characters.isEmpty && empty.floors.isEmpty && empty.shopIcons.isEmpty)
        let json = #"""
        {"schemaVersion":1,"portraits":{},"objects":{},"cabin":{},"cinematics":{},
         "floors":{"urban":{"file":"floor_urban.mov","width":1024,"height":1024,"fps":24,"frames":120,
                            "alpha":false,"audio":false,"matte":null,"keyColor":null}},
         "characters":{"pasante":{"file":"char_pasante.mov","width":512,"height":512,"fps":24,"frames":121,
                       "alpha":true,"audio":false,"matte":"blanco","keyColor":null,"odrTag":"anim-piso-1"}},
         "algoNuevo":{}}
        """#
        let manifest = try JSONDecoder().decode(LoopsManifest.self, from: Data(json.utf8))
        #expect(manifest.entry(for: .floor("urban"))?.alpha == false)
        #expect(manifest.entry(for: .character("pasante"))?.odrTag == "anim-piso-1")
        #expect(manifest.url(for: .floor("urban")) == nil, "en el manifest pero sin archivo: póster")
    }

    @Test("sin entrada no hay video")
    func noEntryNoVideo() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(manifest.url(for: .portrait("npc_que_no_existe")) == nil)
        #expect(LoopsManifest.empty.url(for: .cinematic(.dios)) == nil)
    }
}
```

- [ ] **Step 2: La implementación** (`FisuEvolution/Managers/LoopsManifest.swift`):

```swift
import Foundation

/// Las cinemáticas a pantalla completa, por el id con el que las registra `video_assets.py`.
enum CinematicID: String, CaseIterable, Sendable {
    case intro
    case reencarnacion
    case arresto
    case dios

    /// Cuántas veces por cuenta; `nil` = cada vez.
    var maxPlays: Int? {
        switch self {
        case .reencarnacion: nil
        case .arresto: 2
        case .intro, .dios: 1
        }
    }
}

/// Una pieza animada, por sección del manifest y su id.
enum ArtClip: Hashable, Sendable {
    case portrait(String)
    case object(String)
    case character(String)
    case talking(String)
    case visitorAction(String)
    case event(String)
    case shopIcon(String)
    case floor(String)
    case cinematic(CinematicID)
}

/// `loops_manifest.json`: lo escribe `video_assets.py`; acá sólo se lee. Una pieza sin entrada,
/// o con entrada y sin archivo, no se reproduce: quien la dibuja muestra su póster.
struct LoopsManifest: Decodable, Sendable, Equatable {
    struct Entry: Decodable, Sendable, Equatable {
        let file: String
        let width: Int
        let height: Int
        let fps: Double?
        let frames: Int?
        let alpha: Bool
        let audio: Bool
        let odrTag: String?
    }

    let schemaVersion: Int
    let portraits: [String: Entry]
    let objects: [String: Entry]
    let cabin: [String: Entry]
    let cinematics: [String: Entry]
    let characters: [String: Entry]
    let talking: [String: Entry]
    let visitorActions: [String: Entry]
    let events: [String: Entry]
    let shopIcons: [String: Entry]
    let floors: [String: Entry]

    // init(from:) a mano: cada sección con `decodeIfPresent ?? [:]` (una que no vino = vacía;
    // una desconocida se ignora). `matte` y `keyColor` no se leen: son del pipeline.

    static let empty = LoopsManifest(/* todo vacío, schemaVersion 1 */)

    static func load(from bundle: Bundle) throws -> LoopsManifest { /* como E8b T4 */ }

    /// El del bundle, leído una vez. Sin archivo o roto, vacío: nada depende de que haya videos.
    static let main: LoopsManifest = (try? load(from: .main)) ?? .empty

    func entry(for clip: ArtClip) -> Entry? { /* switch por sección */ }

    /// `nil` sin entrada o sin archivo. Xcode aplana los recursos: se busca por nombre.
    func url(for clip: ArtClip, in bundle: Bundle = .main) -> URL? { … }

    // La API que ya escriben E8b T8–T11 y E4b T3:
    func portraitURL(for id: String, in bundle: Bundle = .main) -> URL? { url(for: .portrait(id), in: bundle) }
    func cinematicURL(for id: CinematicID, in bundle: Bundle = .main) -> URL? { url(for: .cinematic(id), in: bundle) }
}

/// Para inyectar otro manifest en un test o un fixture sin tocar `.main`.
extension EnvironmentValues { @Entry var loopsManifest: LoopsManifest = .main }
```

  (El `@Entry` va en un `import SwiftUI` aparte si el archivo no quiere SwiftUI; lo decide el
  implementador, el test no lo mira.)
- [ ] **Step 3:** oráculo VERDE (la salida nombra las 6). Commit:
  `feat(video): el manifest de los videos del lado del juego, entero y pineado`.

---

### Task 2: `VideoPlayerPool` y `VideoPlaybackPolicy` (revisión opus)

**Objetivo:** el pool decide quién decodifica. **Tope 3 vivos**; **un vivo por rol** (el más nuevo
gana: el popup que se abre baja al anterior); `fullscreen` suspende a todos; las **suspensiones**
(cofre, viaje, scroll) y las **reservas** (la cabina calentando) bajan el tope; la **política**
apaga todo a póster. Los holders reciben `videoLeaseDidChange(isLive:)` y ellos crean o sueltan su
player. Sin AVFoundation adentro del pool: se prueba entero con holders falsos.

**Files:**
- Create: `FisuEvolution/UI/Art/Video/VideoPlayerPool.swift`
- Create: `FisuEvolution/UI/Art/Video/VideoPlaybackPolicy.swift`
- Create: `FisuEvolutionTests/VideoPlayerPoolTests.swift`
- `xcodegen generate`

**Oráculo:** `Tools/v2/oraculo.sh tarea VideoPlayerPoolTests`
**Revisión:** **opus** (es el corazón de la fluidez) · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo:**

```swift
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El pool de videos: nunca más de 3 vivos")
@MainActor
struct VideoPlayerPoolTests {
    final class Holder: VideoLeaseHolder {
        var live = false
        func videoLeaseDidChange(isLive: Bool) { live = isLive }
    }
    private func pool(_ policy: VideoPlaybackPolicy = .allowAll) -> VideoPlayerPool {
        VideoPlayerPool(policy: policy)
    }

    @Test("fondo + popup + ícono: los tres vivos")
    func oneOfEachRole() {
        let pool = pool()
        let bg = Holder(), popup = Holder(), icon = Holder()
        _ = pool.acquire(bg, role: .background)
        _ = pool.acquire(popup, role: .popup)
        _ = pool.acquire(icon, role: .icon)
        #expect(bg.live && popup.live && icon.live)
        #expect(pool.liveCount == 3)
    }

    @Test("el popup nuevo baja al anterior a póster; al cerrarse, el anterior vuelve")
    func newestOfARoleWins() {
        let pool = pool()
        let first = Holder(), second = Holder()
        _ = pool.acquire(first, role: .popup)
        let lease = pool.acquire(second, role: .popup)
        #expect(!first.live && second.live)
        pool.release(lease)
        #expect(first.live, "devuelto el decodificador, el de abajo retoma")
    }

    @Test("la cinemática suspende a todos y al terminar vuelven")
    func fullscreenSuspendsTheRest() {
        let pool = pool()
        let bg = Holder(), popup = Holder(), cine = Holder()
        _ = pool.acquire(bg, role: .background)
        _ = pool.acquire(popup, role: .popup)
        let lease = pool.acquire(cine, role: .fullscreen)
        #expect(cine.live && !bg.live && !popup.live)
        #expect(pool.liveCount == 1)
        pool.release(lease)
        #expect(bg.live && popup.live)
    }

    @Test("una suspensión baja todo; anidadas, vuelve sólo al soltar la última")
    func suspensionsNest() {
        let pool = pool()
        let bg = Holder()
        _ = pool.acquire(bg, role: .background)
        let chest = pool.suspend(.overlay)
        let ride = pool.suspend(.elevatorRide)
        #expect(!bg.live)
        pool.resume(chest)
        #expect(!bg.live)
        pool.resume(ride)
        #expect(bg.live)
    }

    @Test("una reserva baja el tope: con la cabina calentando quedan 2")
    func reservationsLowerTheCap() {
        let pool = pool()
        let bg = Holder(), popup = Holder(), icon = Holder()
        _ = pool.acquire(bg, role: .background)
        _ = pool.acquire(popup, role: .popup)
        _ = pool.acquire(icon, role: .icon)
        let cabin = pool.reserve()
        #expect(pool.liveCount == 2)
        #expect(!icon.live, "cae primero el de menor prioridad: ícono < fondo < popup")
        pool.unreserve(cabin)
        #expect(icon.live)
    }

    @Test("la política apaga todo a póster, y la cinemática según su propia regla",
          arguments: [VideoPlaybackPolicy.Reason.reduceMotion, .lowPower, .thermal, .background,
                      .videoAutoplayOff, .forcedStill])
    func policyTurnsLoopsOff(_ reason: VideoPlaybackPolicy.Reason) {
        let pool = pool()
        let bg = Holder()
        _ = pool.acquire(bg, role: .background)
        pool.update(policy: .allowAll.with(reason))
        #expect(!bg.live && pool.liveCount == 0)
        pool.update(policy: .allowAll)
        #expect(bg.live)
    }

    @Test("la cinemática sigue con bajo consumo y térmica alta; no con Reduce Motion")
    func cinematicsPolicy() {
        #expect(VideoPlaybackPolicy.allowAll.with(.lowPower).allowsCinematics)
        #expect(VideoPlaybackPolicy.allowAll.with(.thermal).allowsCinematics)
        #expect(!VideoPlaybackPolicy.allowAll.with(.reduceMotion).allowsCinematics)
        #expect(!VideoPlaybackPolicy.allowAll.with(.videoAutoplayOff).allowsCinematics)
    }

    @Test("bajo XCTest el pool compartido arranca en póster")
    func sharedStartsStillUnderTests() {
        #expect(VideoPlaybackPolicy.launch.contains(.forcedStill))
    }

    @Test("soltar un lease ajeno o dos veces no rompe nada")
    func releaseIsIdempotent() {
        let pool = pool()
        let a = Holder()
        let lease = pool.acquire(a, role: .popup)
        pool.release(lease)
        pool.release(lease)
        #expect(pool.liveCount == 0 && !a.live)
    }
}
```

- [ ] **Step 2: `VideoPlaybackPolicy.swift`:**

```swift
import Foundation
import UIKit

/// Por qué un video se queda en póster. Pura: el observador de abajo la arma con el sistema.
struct VideoPlaybackPolicy: Equatable, Sendable {
    enum Reason: Hashable, Sendable {
        case reduceMotion, lowPower, thermal, background, videoAutoplayOff, forcedStill
    }
    private(set) var reasons: Set<Reason> = []

    static let allowAll = VideoPlaybackPolicy()
    func with(_ reason: Reason) -> VideoPlaybackPolicy { var p = self; p.reasons.insert(reason); return p }
    func contains(_ reason: Reason) -> Bool { reasons.contains(reason) }

    /// Loops y clips de una vez: cualquier razón los apaga.
    var allowsLoops: Bool { reasons.isEmpty }
    /// La cinemática es UN momento del cuento, a pantalla completa y sola: la apagan sólo lo que
    /// pide el jugador (Reduce Motion, sin reproducción automática) y el segundo plano.
    var allowsCinematics: Bool { reasons.isDisjoint(with: [.reduceMotion, .videoAutoplayOff, .background]) }

    /// La del arranque: `forcedStill` bajo XCTest y bajo `--uitest*` sin `--uitest-video`.
    static var launch: VideoPlaybackPolicy { … }
}

/// Lee el sistema y empuja la política al pool: Reduce Motion, reproducción automática de video,
/// Modo de bajo consumo, térmica (`.serious` o peor), segundo plano. Por notificaciones del sistema
/// (`UIAccessibility.reduceMotionStatusDidChangeNotification`,
/// `…videoAutoplayStatusDidChangeNotification`, `NSProcessInfoPowerStateDidChange`,
/// `ProcessInfo.thermalStateDidChangeNotification`, `UIApplication.didEnterBackground/
/// willEnterForeground`), con `for await` en un `Task` del `@MainActor`, nunca con un `Timer`.
@MainActor
final class VideoPlaybackObserver { … start(pool:) … }
```

- [ ] **Step 3: `VideoPlayerPool.swift`** — la regla, escrita una vez en `recompute()`:

```swift
@MainActor protocol VideoLeaseHolder: AnyObject {
    func videoLeaseDidChange(isLive: Bool)
}

enum VideoRole: Int, Comparable, Sendable {
    // Orden = qué cae primero cuando no alcanza el tope.
    case icon = 0, background = 1, popup = 2, fullscreen = 3
}

@MainActor
final class VideoPlayerPool {
    static let maxLive = 3
    static let shared = VideoPlayerPool(policy: .launch)

    struct Lease: Hashable { fileprivate let id: Int }
    struct Suspension: Hashable { fileprivate let id: Int }
    struct Reservation: Hashable { fileprivate let id: Int }
    enum SuspendReason: Sendable { case overlay, elevatorRide, scrolling }

    init(policy: VideoPlaybackPolicy)

    func acquire(_ holder: VideoLeaseHolder, role: VideoRole) -> Lease
    func release(_ lease: Lease)
    func suspend(_ reason: SuspendReason) -> Suspension
    func resume(_ suspension: Suspension)
    func reserve() -> Reservation
    func unreserve(_ reservation: Reservation)
    func update(policy: VideoPlaybackPolicy)
    private(set) var liveCount: Int

    /// Quién vive: con `fullscreen` (y `allowsCinematics`), sólo él. Si no, con suspensiones o
    /// sin `allowsLoops`, nadie. Si no, el más nuevo de cada rol, de mayor a menor rol, hasta
    /// `maxLive - reservas`. A cada holder que cambia se le avisa una sola vez (sin avisos
    /// repetidos: el holder no recrea el player si ya estaba vivo).
    private func recompute()
}
```

  Los holders se guardan `weak`: un holder que se va sin `release` (una vista desmontada a la
  fuerza) no retiene el cupo — `recompute` los purga.
- [ ] **Step 4: El modificador** `View.suspendsVideoPool()` (en el mismo archivo): `onAppear` →
  `suspend(.overlay)`, `onDisappear` → `resume`. Lo usan E8b T9 (cofre y cinemática) y T10.
- [ ] **Step 5:** `VideoPlaybackObserver().start(pool: .shared)` se llama una vez al arrancar la
  app — **desde `AnimatedArtView`/`LoopingVideoNode` la primera vez que piden un lease**
  (`VideoPlayerPool.shared` lo arranca perezoso), así esta tarea **no toca** `FisuEvolutionApp.swift`
  ni `RootView.swift`.
- [ ] **Step 6:** oráculo VERDE (la salida nombra `VideoPlayerPoolTests` con sus 9). Commit:
  `feat(video): el pool de reproductores, tres vivos como mucho`.

---

### Task 3: `AnimatedArtView` — póster instantáneo, video con fundido (revisión opus)

**Objetivo:** el componente de SwiftUI. Dibuja el póster que le pasa quien lo usa (el PNG de
siempre) y, encima, una capa de video **transparente** hasta que el primer cuadro está listo; ahí
funde en 0,15 s. Dos modos: `.loop` y `.once(onEnd:)` (aperturas del Paquete y el Colchón). Sin
entrada en el manifest, con la política apagada o sin lease vivo: sólo póster.

**Files:**
- Create: `FisuEvolution/UI/Art/Video/AnimatedArtView.swift`
- Create: `FisuEvolutionTests/AnimatedArtViewTests.swift`
- `xcodegen generate`

**Oráculo:** `Tools/v2/oraculo.sh tarea AnimatedArtViewTests VideoPlayerPoolTests LoopsManifestTests`
**Revisión:** **opus** (AVFoundation, memoria, el primer cuadro) · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo.** La decisión de qué dibujar es pura (`AnimatedArt.resolve`) y
  la capa se prueba con su `UIView` en una ventana de verdad:

```swift
@Suite("AnimatedArtView: póster siempre, video si se puede")
@MainActor
struct AnimatedArtViewTests {
    @Test("sin entrada, póster; con entrada, video")
    func resolve() {
        #expect(AnimatedArt.resolve(.portrait("npc_x"), manifest: .main) == nil)
        #expect(AnimatedArt.resolve(.portrait("npc_vecina"), manifest: .main) != nil)
    }

    @Test("la capa no crea player hasta que el pool la pone viva, y lo suelta al bajarla")
    func playerFollowsTheLease() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let url = try #require(LoopsManifest.main.url(for: .portrait("npc_vecina")))
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .loop, pool: pool)
        #expect(layer.player == nil, "el init no decodifica")
        let window = UIWindow(frame: .init(x: 0, y: 0, width: 200, height: 200))
        window.addSubview(layer)                       // didMoveToWindow → acquire
        #expect(layer.player != nil)
        #expect(!layer.isOpaque, "con true el alfa sale negro")
        #expect(layer.videoAlpha == 0, "transparente hasta el primer cuadro")
        layer.removeFromSuperview()                    // → release
        #expect(layer.player == nil && pool.liveCount == 0)
    }

    @Test("con la política apagada no hay player y `.once` termina en el acto")
    func stillPolicy() async throws {
        let pool = VideoPlayerPool(policy: .allowAll.with(.reduceMotion))
        let url = try #require(LoopsManifest.main.url(for: .object("paquete_abre")))
        var ended = false
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .once { ended = true }, pool: pool)
        UIWindow(frame: .init(x: 0, y: 0, width: 200, height: 200)).addSubview(layer)
        #expect(layer.player == nil)
        #expect(ended, "Reduce Motion muestra el cuadro final: quien lo usa dibuja el estado de después")
    }

    @Test("el primer cuadro llega y la capa funde (simulador: con tope generoso)")
    func fadesInWhenReady() async throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        let url = try #require(LoopsManifest.main.url(for: .portrait("npc_vecina")))
        let layer = ArtVideoUIView(url: url, role: .popup, playback: .loop, pool: pool)
        UIWindow(frame: .init(x: 0, y: 0, width: 200, height: 200)).addSubview(layer)
        try await layer.waitUntilVisible(timeout: .seconds(5))
        #expect(layer.videoAlpha == 1)
    }
}
```

- [ ] **Step 2: La vista:**

```swift
/// Un arte del juego que se mueve (spec E8): el póster de siempre y, encima, su video si el
/// manifest lo tiene y el pool lo deja. El póster nunca se saca: si el video no carga o el pool
/// lo baja, se ve el póster, sin hueco ni parpadeo.
struct AnimatedArtView<Poster: View>: View {
    enum Playback { case loop, once(onEnd: @MainActor () -> Void) }

    let clip: ArtClip
    var role: VideoRole = .popup
    var playback: Playback = .loop
    @ViewBuilder let poster: () -> Poster
    @Environment(\.loopsManifest) private var manifest

    var body: some View {
        ZStack {
            poster()
            if let url = AnimatedArt.resolve(clip, manifest: manifest) {
                ArtVideoLayer(url: url, role: role, playback: playback)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
    }
}
```

  `ArtVideoLayer: UIViewRepresentable` crea `ArtVideoUIView` en `makeUIView` y llama `stop()` en
  `dismantleUIView`. `ArtVideoUIView` (`layerClass = AVPlayerLayer`, `isOpaque = false`,
  `backgroundColor = .clear`, `isUserInteractionEnabled = false`, `accessibilityIdentifier =
  "art.video"`, `videoGravity = .resizeAspect`) es el `VideoLeaseHolder`: `didMoveToWindow` pide o
  suelta el lease; `videoLeaseDidChange(true)` crea `AVQueuePlayer` mudo +
  `AVPlayerLooper` (o `AVPlayer` con `actionAtItemEnd = .pause` en `.once`),
  `automaticallyWaitsToMinimizeStalling = false`, `preventsDisplaySleepDuringVideoPlayback = false`,
  `layer.opacity = 0`, `play()`, y sondea `isReadyForDisplay` cada 50 ms (tope 2 s) para fundir con
  `UIView.animate(withDuration: 0.15)`; `false` pausa, pone opacidad 0 y suelta todo
  (`disableLooping`, `removeAllItems`). `.once` espera `didPlayToEndTime` (con tope = duración + 1 s,
  como el cofre) y llama `onEnd`; con la política apagada lo llama en el acto.
  `AVAudioSession` no se toca: los clips son mudos (`audio == false`).
- [ ] **Step 3:** oráculo VERDE. Commit: `feat(video): AnimatedArtView, el póster y el video encima`.

---

### Task 4: `LoopingVideoNode` — lo mismo en SpriteKit (revisión opus)

**Objetivo:** el par de `AnimatedArtView` para la escena: un `SKSpriteNode` póster y un
`SKVideoNode(avPlayer:)` encima en alfa 0 que funde al estar listo. `setVisible(_:)` lo maneja la
escena (sólo el piso visible y asentado anima). **Mide** si `SKVideoNode` respeta el alfa del HEVC
(la revelación de T9 lo necesita; los fondos son opacos).

**Files:**
- Create: `FisuEvolution/Scenes/Nodes/LoopingVideoNode.swift`
- Create: `FisuEvolutionTests/LoopingVideoNodeTests.swift`
- `xcodegen generate`

**Oráculo:** `Tools/v2/oraculo.sh tarea LoopingVideoNodeTests VideoPlayerPoolTests`
**Revisión:** **opus** · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo:**

```swift
@Suite("LoopingVideoNode: el póster en la escena y el video encima")
@MainActor
struct LoopingVideoNodeTests {
    @Test("sin entrada: sólo el póster, nunca un SKVideoNode")
    func noEntryOnlyPoster() {
        let node = LoopingVideoNode(clip: .floor("no_existe"), poster: SKTexture(), size: .init(width: 100, height: 100),
                                    role: .background, manifest: .main, pool: VideoPlayerPool(policy: .allowAll))
        node.setVisible(true)
        #expect(node.videoNode == nil)
    }

    @Test("visible y vivo: hay video; invisible: lo suelta y el cupo vuelve")
    func visibilityDrivesTheLease() throws {
        let pool = VideoPlayerPool(policy: .allowAll)
        // Un manifest de test que apunta un piso a un .mov real del bundle.
        let manifest = try LoopsManifestTests.fixture(floors: ["urban": "cine_arresto.mov"])
        let node = LoopingVideoNode(clip: .floor("urban"), poster: SKTexture(), size: .init(width: 100, height: 100),
                                    role: .background, manifest: manifest, pool: pool)
        node.setVisible(true)
        #expect(node.videoNode != nil && pool.liveCount == 1)
        node.setVisible(false)
        #expect(node.videoNode == nil && pool.liveCount == 0)
    }

    @Test("con la política apagada, póster aunque esté visible")
    func stillPolicy() throws { … }
}
```

  (`LoopsManifestTests.fixture(floors:)` es un helper `static` que la T4 suma a la suite de T1:
  arma el JSON en memoria. Si T1 todavía no lo tiene, la T4 lo agrega ahí: archivo de test, sin
  conflicto.)
- [ ] **Step 2: El nodo.** `LoopingVideoNode: SKNode, VideoLeaseHolder`; el póster como hijo
  `zPosition 0`; al ponerse vivo crea `AVQueuePlayer` + `AVPlayerLooper` mudo y un
  `SKVideoNode(avPlayer:)` en `alpha 0`, `zPosition 1`, `size` igual al póster; sondea
  `currentItem.status == .readyToPlay` y luego **un `currentTime() > 0`** (señal de cuadro
  decodificado; `SKVideoNode` no expone `isReadyForDisplay`) y hace `run(.fadeIn(withDuration:
  0.15))`. Bajarlo: `removeFromParent` del video, pausa y suelta. `setVisible(false)` libera el
  lease. Sin `SKAction` repetitivas ni `Timer`: el sondeo es un `Task` del `@MainActor`, cancelado al
  soltar.
- [ ] **Step 3: La medición del alfa** (anotada en el reporte; decide la T9): un test
  `alphaSurvivesInSKVideoNode` monta un `SKView` 256² fuera de pantalla con fondo rojo, un
  `LoopingVideoNode` de `loop_npc_vecina.mov` encima, espera el fundido, `view.texture(from:)` y
  lee el píxel de una esquina (el retrato tiene ~10 % transparente en los bordes): **rojo** = el alfa
  pasa; **negro** = no. Si no pasa en el simulador, el test queda como
  `.disabled("SKVideoNode no respeta el alfa del HEVC en el simulador: T9 usa el overlay SwiftUI")`
  y el reporte lo dice. La vara final es el gate G3 en dispositivo.
- [ ] **Step 4:** oráculo VERDE. Commit: `feat(video): LoopingVideoNode, el video en la escena`.

---

### Task 5: El especial que te cayó y la ficha, animados

**Objetivo:** reemplaza a E8b T6 y suma la ficha. `SpecialDropView` muestra el loop del retrato del
especial en su plato de 168 pt (la canónica quieta queda de póster); `CharacterSheetView` muestra el
**cuerpo entero** (`.character(id)`), que hoy no tiene entrada: queda en póster hasta T14, sin tocar
Swift. Suena `sfx_reveal_whoosh` al abrir la ficha **si T6 entró** (si no, queda en
`pendingWiring` de T6).

**Files:**
- Modify: `FisuEvolution/UI/Popups/SpecialDropView.swift`
- Modify: `FisuEvolution/UI/Popups/CharacterSheetView.swift` (tibio: E13 T9)
- Modify (si T6 entró): `FisuEvolutionTests/AudioWiringTests.swift` (`revealWhoosh` pasa de
  `pendingWiring` a `declaredCases`)

**Oráculo:** `Tools/v2/oraculo.sh tarea AnimatedArtViewTests AudioWiringTests` + Receta R
`CharacterSheetUITests` (el póster bajo `--uitest*`: nada cambia) + **captura con `--uitest-video`**
en el SE y el 16 Pro: el especial se mueve, el plato no cambia de tamaño, el amarillo se ve a través
del alfa (no un cuadrado negro).
**Revisión:** ninguna (el controlador mira las capturas) · **Modelo:** sonnet.

- [ ] **Step 1:** `SpecialDropView.portrait` envuelve lo de hoy:

```swift
    @ViewBuilder private var portrait: some View {
        AnimatedArtView(clip: .portrait(special.id), role: .popup) { stillPortrait }
            .frame(width: Self.portraitSide, height: Self.portraitSide)
            .background(Color("PaletteYellow").opacity(0.3))
            .clipShape(Self.plateShape)
            .overlay(Self.plateShape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
            .accessibilityHidden(true)
    }
```

  (`stillPortrait` = el cuerpo de hoy, sin cambios; ver E8b T6 Step 1.)
- [ ] **Step 2:** `CharacterSheetView`: el `CharacterPortrait` queda como póster de
  `AnimatedArtView(clip: .character(<la clave de assets_manifest.characters del tipo o especial
  mostrado>), role: .popup)`; con una pinta (skin) puesta **no** anima (el video es de la pinta
  canónica): `clip` sólo si `selectedSkin == nil`. `character.portrait` sigue en el mismo elemento
  hoja que hoy.
- [ ] **Step 3:** oráculo + capturas. Commit: `feat(video): el especial y la ficha se mueven`.

---

### Task 6: Los sonidos nuevos A — paquete, colchón, visitante, tienda, revelación, cable

**Objetivo:** sintetizar, integrar y dejar listos para cablear los efectos de la spec que no son de
eventos: `sfx_package_rattle` (ambiente, loop), `sfx_package_tape_rip`, `sfx_package_burst`,
`sfx_mattress_squeak` (ambiente, loop), `sfx_mattress_rip`, `sfx_cash_burst`,
`sfx_visitor_arrive`, `sfx_talk_blip`, `sfx_shop_shimmer`, `sfx_reveal_whoosh`,
`sfx_elevator_cable` (11). `AudioManager` gana **ganancia** (ambiente −18 dB, acción −6 dB),
**tono** (el blip por personaje) y **loop de ambiente** con corte suave.

**Files:**
- Modify: `Tools/audio-synth/generate_audio.py` (11 funciones `sfx_*` registradas en el dict `SFX`, en el carácter de las de hoy)
- Create: `FisuEvolution/Resources/Audio/sfx_*.caf` (11)
- Modify: `FisuEvolution/Audio/AudioManager.swift` (tibio)
- Modify: `FisuEvolutionTests/AudioWiringTests.swift`, `FisuEvolutionTests/AudioManagerTests.swift`

**Oráculo:** `Tools/v2/oraculo.sh tarea AudioManagerTests AudioWiringTests`
**Revisión:** ninguna · **Modelo:** sonnet. **🔒 (no frena):** el dueño los escucha; los que pida
cambiar se rehacen en el script.

- [ ] **Step 1: Los tests, en rojo.** `AudioManagerTests`:

```swift
    @Test("cada SFX tiene su archivo en el bundle")
    func everySFXHasAFile() {
        for sfx in AudioManager.SFX.allCases {
            let found = ["caf", "m4a", "wav"].contains { Bundle.main.url(forResource: sfx.rawValue, withExtension: $0) != nil }
            #expect(found, "\(sfx.rawValue)")
        }
    }

    @Test("el ambiente suena 18 dB abajo de la acción")
    func ambientGain() {
        #expect(abs(AudioManager.Gain.ambient.linear - pow(10, -18.0 / 20)) < 0.001)
        #expect(abs(AudioManager.Gain.action.linear - pow(10, -6.0 / 20)) < 0.001)
    }

    @Test("el tono del blip es estable por personaje y está en 0,8–1,25")
    func blipPitch() {
        let a = AudioManager.talkPitch(for: "npc_vecina")
        #expect(a == AudioManager.talkPitch(for: "npc_vecina"))
        #expect((0.8...1.25).contains(a))
        #expect(AudioManager.talkPitch(for: "npc_vecina") != AudioManager.talkPitch(for: "npc_comisario"))
    }
```

  `AudioWiringTests`: suma `pendingWiring: [String: String]` (caso → épica que lo cablea) y un test
  `"todo SFX está cableado o tiene dueño"`: `Set(SFX.allCases) == declaredCases ∪ pendingWiring.keys
  ∪ los del ascensor (que suenan desde UI/Elevator: se suma esa carpeta a las fuentes)`. Así un caso
  nuevo sin cablear y sin dueño pone el test en rojo. `pendingWiring` arranca con: `packageRattle,
  packageTapeRip, packageBurst → E5b T3`; `mattressSqueak, mattressRip, cashBurst → E5b T2`;
  `visitorArrive, talkBlip → E4b T3`; `shopShimmer → E6a T8`; `revealWhoosh → E8d T5/T9`;
  `elevatorCable → E8d T10`.
- [ ] **Step 2: El script.** Once funciones nuevas siguiendo el patrón de `sfx_elevator_*`
  (`render_tone`/`render_noise_lp`, `edge_fades`, `normalize_loudness`); los dos de ambiente se
  generan **loopeables** (`wrap=True`, ~2 s, sin clic en el empalme). Correr el script para esos 11
  y verificar que los `.caf` existen y que los otros no cambiaron (`git status` limpio salvo los 11).
- [ ] **Step 3: `AudioManager`:**

```swift
    enum Gain { case action, ambient
        var linear: Float { switch self { case .action: pow(10, -6 / 20); case .ambient: pow(10, -18 / 20) } } }

    /// `play` de siempre sigue igual (ganancia 1). Ésta suma ganancia y tono (`enableRate`).
    func play(_ sfx: SFX, gain: Gain, pitch: Float = 1)
    /// Un ambiente en loop (`numberOfLoops = -1`), con fundido de 0,2 s al cortar.
    func startAmbient(_ sfx: SFX)
    func stopAmbient(_ sfx: SFX)
    static func talkPitch(for speakerId: String) -> Float   // hash estable (no `hashValue`: cambia por proceso)
```

  Los 11 casos en `SFX`, con su docstring de una línea (dónde suenan).
- [ ] **Step 4:** oráculo VERDE. Commit: `feat(sonido): once efectos nuevos para los momentos animados`.

---

### Task 7: Los 8 acentos de evento

**Objetivo:** cada evento suena con su acento (`sfx_ev_plan_platita`, `sfx_ev_startup`,
`sfx_ev_devaluacion`, `sfx_ev_blanqueo`, `sfx_ev_mercado_pago`, `sfx_ev_alien`, `sfx_ev_corralito`,
`sfx_ev_aguinaldo`) en lugar del `sfx_event` genérico; un evento sin acento sigue con `sfx_event`.

**Files:**
- Modify: `Tools/audio-synth/generate_audio.py` (8), `Resources/Audio/sfx_ev_*.caf` (8)
- Modify: `FisuEvolution/Audio/AudioManager.swift` (8 casos + `static func accent(forEvent:) -> SFX`)
- Modify: `FisuEvolution/Game/State/GameState+Bonus.swift` 🔥 (una línea; si E4a T9 ya mudó los
  eventos a `+Events`, ahí)
- Modify: `FisuEvolutionTests/AudioWiringTests.swift`, `AudioManagerTests.swift`

**Oráculo:** `Tools/v2/oraculo.sh tarea AudioManagerTests AudioWiringTests EventSystemTests`
(la clase de eventos que exista; si no, `GameLoopWiringTests`)
**Revisión:** ninguna · **Modelo:** sonnet.

- [ ] **Step 1: Test, en rojo:** `accent(forEvent:)` devuelve el acento de cada uno de los 8 ids de
  `events.json` y `.event` para uno desconocido; cada id de `events.json` que tenga acento está en el
  mapa (el test lee `GameContentLoader.load(from: .main).events`).
- [ ] **Step 2:** script + `.caf`; los 8 casos; la línea pasa a
  `audio?.play(AudioManager.accent(forEvent: roll.event.id))`. Como el parser de `AudioWiringTests` no
  ve casos adentro de una función, los 8 entran a `declaredCases` por una lista
  `eventAccents` que el test cruza contra `AudioManager.accent(forEvent:)` (cubierto = cableado).
- [ ] **Step 3:** oráculo VERDE. Commit: `feat(sonido): cada evento suena con su acento`.

---

### Task 8: El fondo del piso visible, animado (revisión opus)

**Objetivo:** el piso que se ve, asentado, anima su fondo (`.floor(<clave de fondo>)`, rol
`background`); los demás pisos y **durante el scroll** se ve el póster (el sprite de hoy). Hoy
ningún piso tiene entrada (segunda tanda): el código entra inerte y se prueba con un manifest de
test. Al cambiar de piso visible, pide el pack del piso siguiente (`ArtPacks.prefetch`, si T12
entró).

**Files:**
- Modify: `FisuEvolution/Scenes/Nodes/FloorNode.swift` (el `LoopingVideoNode` sobre el sprite, dentro
  del `SKCropNode`; `setBackgroundAnimating(_:)`)
- Modify: `FisuEvolution/Scenes/BoardScene.swift` 🔥 (llamar `setBackgroundAnimating` al asentarse
  el scroll en un piso y `false` al empezar a scrollear; un `pool.suspend(.scrolling)` mientras
  dura el arrastre)
- Create: `FisuEvolutionTests/FloorBackgroundAnimationTests.swift`

**Oráculo:** `Tools/v2/oraculo.sh tarea FloorBackgroundAnimationTests LoopingVideoNodeTests BoardSceneTests`
(las clases de escena que existan) + Receta R `AscentRenderingUITests` (nada cambia bajo `--uitest*`).
**Revisión:** **opus** (🔥 BoardScene, AVFoundation, memoria del SE) · **Modelo:** sonnet.

- [ ] **Step 1: Tests, en rojo:** con un manifest de test (`floors: [<clave del piso 1>:
  "cine_arresto.mov"]`) y el pool en `.allowAll`: (a) el piso visible asentado tiene video y los
  demás no; (b) empezar a scrollear lo baja a póster (`liveCount == 0`) y asentarse en otro lo pasa
  a ése; (c) sin entrada, ningún `SKVideoNode` en la escena. Se manejan por las mismas funciones que
  usa el gesto (sin simular toques).
- [ ] **Step 2:** la implementación. El `LoopingVideoNode` usa **la misma textura** que el sprite
  de hoy como póster (no se carga otra imagen) y el mismo `size`/`offset`: el corte entre póster y
  video no se nota.
- [ ] **Step 3:** oráculo VERDE + captura con `--uitest-video` y el manifest de estrés de T13 (si
  entró) en el SE. Commit: `feat(video): el piso que mirás tiene el fondo vivo`.

---

### Task 9: La revelación con el cuerpo entero (revisión opus)

**Objetivo:** cuando el reveal de un tier nuevo se muestra, el personaje se ve con su loop de
cuerpo entero (`.character(typeId)`, rol `popup`) y suena `sfx_reveal_whoosh` junto al
`sfx_evolution` de hoy. Inerte hasta T14. Si la T4 midió que `SKVideoNode` **no** respeta el alfa,
la revelación usa la ruta B: un `AnimatedArtView` en un overlay SwiftUI alineado al
`RevealLayout` que la escena ya calcula (pantalla entera centrada), y la escena sólo publica "el
reveal de X está en pantalla en este rect".

**Files:**
- Modify: `FisuEvolution/Scenes/BoardScene.swift` 🔥
- (Ruta B) Create: `FisuEvolution/UI/RevealVideoOverlay.swift`; Modify: el lugar donde se monta el
  `SpriteView` (si es `RootView` 🔥, pedir ventana)
- Modify: `FisuEvolutionTests/AudioWiringTests.swift` (`revealWhoosh` a `declaredCases` si no lo
  hizo T5)

**Oráculo:** `Tools/v2/oraculo.sh tarea LoopingVideoNodeTests AudioWiringTests BoardCelebrationTests`
(las que existan) + grabación con `--uitest-video` y un manifest de test.
**Revisión:** **opus** · **Modelo:** sonnet.

- [ ] **Step 1:** test en rojo: con manifest de test (`characters: [<typeId del tier 2>:
  "loop_npc_vecina.mov"]`), el reveal de ese tier tiene video; sin entrada, el sprite de hoy.
- [ ] **Step 2:** implementación (ruta A o B según la T4). El video se suelta cuando el reveal
  termina (el `release` va en el mismo borde que cierra el reveal hoy: nunca queda un decodificador
  colgado después del reveal).
- [ ] **Step 3:** oráculo + grabación. Commit: `feat(video): el tier nuevo se revela en movimiento`.

---

### Task 10: El viaje suspende los videos; la cabina reserva su decodificador (revisión opus)

**Objetivo:** durante el viaje en ascensor el pool queda suspendido (los fondos se ven en póster:
spec), y mientras `ElevatorCabinWarmup` tiene un player calentado el pool **reserva** uno (así el
total nunca pasa de 3). Suena `sfx_elevator_cable` en el tramo de viaje.

**Files:**
- Modify: `FisuEvolution/UI/Elevator/ElevatorCabin.swift` (`ElevatorCabinWarmup`: `reserve()` al
  crear el primer player, `unreserve` en `release()`)
- Modify: `FisuEvolution/UI/Elevator/ElevatorRideOverlay.swift` (lo crea E13b T6:
  `.suspendsVideoPool()` sólo con `phase != .idle`; `audio?.play(.elevatorCable, gain: .action)` al
  arrancar el tramo `traveling`)
- Modify: `FisuEvolutionTests/ElevatorCabinTests.swift`, `AudioWiringTests.swift`

**Oráculo:** `Tools/v2/oraculo.sh tarea ElevatorCabinTests ElevatorRideTests VideoPlayerPoolTests AudioWiringTests`
+ Receta R `ElevatorRideUITests`.
**Revisión:** **opus** · **Modelo:** sonnet.

- [ ] **Step 1:** tests en rojo: `prepare()` con `.video` reserva uno (`pool.liveCount` baja de 3 a 2
  con tres holders); `release()` lo devuelve; `prepare()` dos veces reserva uno solo; con `.stills`
  o `.vector` no reserva.
- [ ] **Step 2:** implementación; la reserva se pide contra `VideoPlayerPool.shared` (inyectable en
  `ElevatorCabinWarmup.init` para el test).
- [ ] **Step 3:** oráculo VERDE. Commit: `feat(ascensor): el viaje apaga los videos de abajo`.

---

### Task 11: La intro, la primera vez

**Objetivo:** una cuenta nueva ve la cinemática `intro` una vez, al abrir el juego por primera vez,
**antes** de la primera lección del núcleo. Los veteranos (save previo a la 2.0) no la ven. Inerte
hasta que `cinematics.intro` exista (T14): `isCinematicDue(.intro)` es falso sin URL.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Cinematics.swift` (`reconcileCinematics` suma la
  intro: save recién creado y `timesSeen(.intro) == 0`)
- Modify: `FisuEvolution/Game/State/GameState+Bootstrap.swift` (tibio: marca "partida nueva" donde
  hoy nace el save; un veterano anota `intro` vista en la migración, sin mostrarla)
- Modify: `FisuEvolutionTests/CinematicTriggerTests.swift`
- Strings: `Tools/v2/claves-pendientes/e8d-t11.json` (`cinematic.intro.a11y`)

**Oráculo:** `Tools/v2/oraculo.sh tarea CinematicTriggerTests CinematicWiringTests TutorialTipsTests`
**Revisión:** sonnet · **Modelo:** sonnet.

- [ ] **Step 1:** tests en rojo, con un manifest de test que tenga `cinematics.intro` →
  `cine_arresto.mov`: (a) save nuevo → la intro pide turno al arrancar y la primera lección del
  núcleo espera (`isCalmMoment` falso mientras dura); (b) save veterano → no la pide y queda anotada;
  (c) sin entrada en el manifest real → no la pide.
- [ ] **Step 2:** implementación. Si la lección del núcleo no espera a la cola (lo dice el test a),
  la tarea **no** toca el tutorial: para con `NEEDS_CONTEXT` y el controlador decide con E9a.
- [ ] **Step 3:** oráculo VERDE. Commit: `feat(cinematicas): la intro, una vez por cuenta nueva`.

---

### Task 12: On-Demand Resources — `ArtPacks` y el pedido por familia

**Objetivo:** una entrada con `odrTag` se busca en su pack: si el pack está, URL; si no, `nil`
(póster) y se pide en segundo plano; cuando llega, las vistas que lo esperaban se enteran y funden.
Pedidos: al montar un `AnimatedArtView`/`LoopingVideoNode` cuyo clip tiene tag; `prefetch` al
acercarse a un piso (T8) y al abrir la tienda (carry E6a T8). Los packs se sueltan al salir de la
pantalla que los usa (`endAccessingResources`) y el sistema purga.

**Files:**
- Create: `FisuEvolution/Managers/ArtPacks.swift`, `FisuEvolutionTests/ArtPacksTests.swift`
- Modify: `FisuEvolution/Managers/LoopsManifest.swift` (`url(for:)` consulta `ArtPacks` si hay
  `odrTag`), `UI/Art/Video/AnimatedArtView.swift`, `Scenes/Nodes/LoopingVideoNode.swift`
  (re-resolver al `ArtPacks.didBecomeAvailable(tag)`)
- `xcodegen generate`

**Oráculo:** `Tools/v2/oraculo.sh tarea ArtPacksTests LoopsManifestTests AnimatedArtViewTests`
**Revisión:** sonnet · **Modelo:** sonnet.

- [ ] **Step 1:** tests en rojo con un `ArtPackSource` falso (protocolo sobre
  `NSBundleResourceRequest`): (a) tag no disponible → `url == nil` y queda un pedido; (b) el pedido
  termina → `url != nil` y avisa una vez; (c) error de red → sigue en póster, sin reintento en loop
  (reintenta al próximo montaje); (d) sin `odrTag` → no pasa por `ArtPacks`.
- [ ] **Step 2:** implementación: `@MainActor final class ArtPacks` con un
  `NSBundleResourceRequest` por tag (`loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent`
  sólo para lo que está en pantalla; `prefetch` con prioridad baja),
  `conditionallyBeginAccessingResources` primero (si ya está, sin red). `.main` del manifest no
  cambia: la consulta es en `url(for:)`.
- [ ] **Step 3:** oráculo VERDE. Commit: `feat(video): los videos pesados llegan por On-Demand Resources`.

---

### Task 13: La sonda de fps y memoria (DEBUG) y el fixture de estrés

**Objetivo:** lo que hace falta para medir los gates: `FrameRateProbe` (`CADisplayLink`: fps
promedio, cuadros > 25 ms, peor cuadro; `phys_footprint` con `task_info`), visible en el panel de
debug y volcada al log cada 10 s; y `--uitest-anim-stress`: un manifest de estrés (el piso visible
→ `cine_reencarnacion.mov`; el ícono → `loop_npc_vecina.mov`) + `--uitest-video` + el especial
abierto, para medir **el peor caso de la spec** (fondo + popup + ícono) antes de que exista la
segunda tanda.

**Files:**
- Create: `FisuEvolution/Debug/FrameRateProbe.swift` (`#if DEBUG`), `FisuEvolutionTests/FrameRateProbeTests.swift`
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (tibio: una fila "fps / ms / MB"),
  `GameState+Bootstrap.swift`, `+Debug.swift` (tibios: el fixture)

**Oráculo:** `Tools/v2/oraculo.sh tarea FrameRateProbeTests` + una corrida a mano en el simulador
con `--uitest-anim-stress` que muestre la fila y el log.
**Revisión:** ninguna · **Modelo:** sonnet.

- [ ] **Step 1:** test en rojo de la parte pura (`FrameStats.add(frameDuration:)`: promedio, conteo
  > 25 ms, peor; ventana de 600 cuadros).
- [ ] **Step 2:** implementación; nada de esto compila en Release.
- [ ] **Step 3:** oráculo VERDE. Commit: `feat(debug): la sonda de fps y memoria para medir los videos`.

---

### Task 14: 🔒 La segunda tanda entra

**Gate del dueño:** **"revisión de la segunda tanda"**: `revision.json` con piezas de la segunda tanda
en `va`. **Entra sólo lo `va`.**

**Objetivo:** con el pipeline del dueño (kinds nuevos de `video_assets.py`), procesar lo `va` a sus
secciones del manifest (contrato de arriba), con `odrTag` según la tabla; poner los archivos con tag
en `Resources/AnimPacks/<tag>/` y declararlos en `project.yml` 🔥 (`resourceTags`, y
`ENABLE_ON_DEMAND_RESOURCES: YES`; `EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE: YES` en Debug, así el
simulador y los tests los ven sin servidor); `xcodegen generate`; medir el peso del paquete base y de
cada pack. **Cero Swift.**

**Files:** `Resources/Loops/…`, `Resources/Cinematics/cine_intro.mov`, `Resources/AnimPacks/…`,
`Resources/Data/loops_manifest.json`, `project.yml` 🔥, `Tools/asset-pipeline/tests/test_video_assets.py`
(el pin de Python de lo que entró), `FisuEvolutionTests/LoopsManifestTests.swift` (el gemelo Swift).

**Oráculo:** pipeline (`python -m unittest discover -s tests`, sin salteados) + `Tools/v2/oraculo.sh
tarea LoopsManifestTests ArtPacksTests` + chequeo "cada `file` del manifest existe en el bundle o
en su pack; cada `.mov` está en el manifest" (el de la reconciliación).
**Revisión:** el controlador mira la hoja de contacto (cada 15 cuadros) · **Modelo:** sonnet.

- [ ] **Step 1:** leer `revision.json`; listar `va`; correr el pipeline sólo sobre eso.
- [ ] **Step 2:** paquete base ≤ +60 MB sobre el de hoy (regla de E6b); si no, bajar a 384² lo que
  la spec deja elegir y anotar.
- [ ] **Step 3:** commit por familia (`feat(video): los personajes de cuerpo entero entran`, …).

---

### Task 15: Cierre de E8d (controlador)

- [ ] **Step 1: `AnimatedPlacesTests`** (nuevo, el barrido): para cada sección del manifest con
  entradas, hay al menos un call site que pide ese `ArtClip` en `FisuEvolution/` (mismo parser de
  texto que `AudioWiringTests`); una sección llena sin quien la pida es rojo. Lo que una épica no
  cableó (carry de abajo), lo cablea esta tarea o queda con dueño en una lista `pendingPlaces`.
- [ ] **Step 2:** `Tools/v2/oraculo.sh completo` sobre la punta de `v2/e8-anim` con `version-2`
  mergeada → VERDE con todas las clases de E8d.
- [ ] **Step 3: Los gates** (abajo), en dispositivo, anotados con números en la sesión.
- [ ] **Step 4: Docs.** `Docs/SESION-<fecha>-v2-e8d.md`; `Docs/HANDOFF.md` §4/§5 (el pool y sus
  roles; cuándo suena cada efecto), §7 (trampas: "el simulador decodifica HEVC-alfa por software:
  los fps se miden en el dispositivo"; lo que dé la medición de `SKVideoNode`); `tasks.md` (filas y
  carries; E8b T4/T5/T6/T12 reemplazadas). Journal y `LOCK`.

---

## Gates

| # | Gate | Cómo se mide | Vara | Si no pasa |
|---|---|---|---|---|
| G1 | **fps en el iPhone SE** (el más chico que soporta el juego) | Release en el dispositivo, `--uitest-anim-stress` (fondo animado + popup + ícono, 3 vivos) **y** la partida real con un piso animado + el popup de un visitante; 60 s cada uno con `FrameRateProbe` + Instruments "Animation Hitches" | promedio ≥ 59 fps; ≤ 1 % de cuadros > 25 ms; ningún toque demorado (el tap al tablero sigue respondiendo en el mismo cuadro) | escalera, en orden: (1) el ícono baja a póster en el SE (rol `icon` fuera con `maxLive = 2` por modelo de dispositivo); (2) retratos/personajes a 384²; (3) fondos a 768²; (4) fondos sólo en póster en el SE. Se anota cuál quedó |
| G2 | **fps en el iPad** (el de base que soporta el juego) | ídem; fondo a 1024² estirado | ídem | ídem (2)–(4) |
| G3 | **HEVC con alfa en el dispositivo** | SE y iPad: cada retrato y objeto sobre amarillo (sin cuadrado negro, sin halo blanco), el póster→video sin salto visible, `SKVideoNode` con alfa (lo de T4), la cabina a ×5 (tope de `rate` de la reconciliación) termina con las puertas del todo abiertas | a ojo, con grabación de pantalla para el dueño | alfa negra en `SKVideoNode` → ruta B de T9; cabina que no alcanza ×5 → recortar el clip al movimiento en el pipeline (pide los masters) y volver el tope a 4 |
| G4 | **Memoria** | Instruments "Allocations"/`phys_footprint` de la sonda: el pico con 3 vivos + la cabina calentando, y 10 min de partida con pisos que cambian | pico ≤ el de la misma escena en póster + 40 MB en el SE; sin jetsam en 10 min; el pico de la de Dios anotado (era E8b T12) | bajar `maxLive` en el SE; soltar los packs más rápido |
| G5 | **ODR** | TestFlight: instalar limpio, entrar a un piso con personajes ODR (póster y después video), abrir la tienda, modo avión (póster para siempre, sin error ni cuelgue), purga del sistema (vuelve a pedir) | sin cuelgues; paquete base ≤ +60 MB (E6b) | pasar la familia que falle al paquete base o a póster |
| G6 🔒 | **Revisión de la segunda tanda** (dueño) | `revision.json` | sólo `va` | lo demás sigue en póster |
| G7 🔒 | **El oído del dueño** (no frena) | escucha T6/T7 en el dispositivo | sus notas | se rehace en el script |

## Dudas con default

Ninguna frena: la ejecución sigue con el default.

1. **Un vivo por rol, tope 3, el más nuevo gana.** "Fondo + popup + ícono" de la spec, leído como
   roles. Dos popups apilados: el de arriba anima, el de abajo queda en póster. **Default:** así.
2. **La cinemática no la apagan el Modo de bajo consumo ni la térmica** (es un momento del cuento, a
   pantalla completa y sola); sí Reduce Motion y "sin reproducción automática". Con ésas **no pide
   turno y no se cuenta vista** (cambia el default 6 de E8b, que la contaba): si el jugador vuelve a
   activar el video, la de Dios todavía le toca. **Default:** así.
3. **El póster es el PNG que ya dibuja cada lugar** (atlas), no un cuadro extraído del video: por
   construcción el primer cuadro del loop es esa misma imagen. **Default:** así; si el salto se nota
   en G3, el pipeline exporta `poster_<id>.png` y el manifest gana `poster`.
4. **La cabina queda fuera del pool** (`ElevatorCabinWarmup`, medido y con revisión opus) y entra
   sólo con una reserva (T10). La spec dice "HEVC opaco para … cabina" pero el clip tiene alfa
   (reconciliación): no cambia nada en Swift (la vista ya es `isOpaque = false`). **Default:** así.
5. **El tope ×5 de la cabina no se probó en un dispositivo.** **Default:** se mide en G3; el plan B es
   del pipeline.
6. **Nombres de sección e ids de la segunda tanda**: los de la tabla "El manifest de la segunda
   tanda" (ids = las claves que ya usa el juego). **Default:** así; el pipeline del dueño escribe esos
   nombres (si elige otros, T1 suma el alias en el decodificador, una línea por sección).
7. **ODR por familia** (`anim-piso-<n>`, `anim-especiales`, `anim-visitantes`, `anim-eventos`,
   `anim-tienda`); fondos, retratos, objetos, cabina y cinemáticas en el paquete base (spec).
   Precarga del piso siguiente al entrar a uno; de la tienda, al abrirla. **Default:** así.
8. **La tienda anima sólo la tarjeta centrada** (la primera entera en la vista si es una lista
   vertical). **Default:** así; el detalle lo resuelve E6a T8 con `AnimatedArtView(role: .icon)`.
9. **La intro**: cuentas nuevas, una vez, antes de `core.tap`; veteranos no (se anota vista en la
   migración). **Default:** así.
10. **Sonidos del ascensor**: los de E13b T3 cubren los de la spec (`spring` = resorte, `click` =
    botón, `doors` = puertas, `motor` = zumbido); sólo `sfx_elevator_cable` es nuevo. **Default:** así,
    sin renombrar.
11. **El blip del globo**: un `sfx_talk_blip` con tono por personaje (0,8–1,25, hash estable del
    id), uno cada dos caracteres mientras se escribe el globo. **Default:** así (E4b T3).
12. **Ambiente a −18 dB** se implementa como ganancia lineal 0,126 × volumen de efectos (no contra la
    música: la música tiene su propio volumen). **Default:** así.
13. **El reproductor no se reusa entre lugares**: cada holder crea el suyo al ponerse vivo y lo suelta
    al bajar (el pool cuenta decodificadores, no recicla `AVQueuePlayer`). El póster tapa el
    arranque. **Default:** así; si G1 muestra hitches al crear, se recicla.
14. **Bajo `--uitest*` todo es póster** salvo `--uitest-video`; los UI tests de siempre no cambian.
    **Default:** así.
15. **`sp_contador_dios` y `sp_bug_simulacion`** (🔒 de E8b T3) siguen en el bundle con la versión
    del dueño de la reconciliación. **Default:** así hasta que el dueño diga otra cosa.

## Lo que E8d le deja a otras épicas

- **E8b T8–T11**: ver "Qué reemplaza". T8 importa `CinematicID` y `LoopsManifest` de E8d T1; T9 usa
  `VideoPlayerPool.shared.acquire(_, role: .fullscreen)` y suma `.suspendsVideoPool()` al overlay
  del cofre en `RootView`.
- **E4b T3** (popup del visitante): **no crea** `LoopsManifest` ni `LoopingPortraitView`. El retrato
  es `AnimatedArtView(clip: .portrait(visitor.id), role: .popup) { foto }`; con el globo abierto,
  `.talking(visitor.id)` (mismo póster); en el momento del pedido/multa/chisme, `.visitorAction(id)`.
  Suena `sfx_visitor_arrive` al llegar y `play(.talkBlip, gain: .action, pitch: talkPitch(for:))`
  cada dos caracteres. Pasa esos casos de `pendingWiring` a `declaredCases`.
- **E4b T4** (eventos con presentador / chip): la ilustración del evento es `AnimatedArtView(clip:
  .event(event.id))`; el acento ya suena desde el disparo (E8d T7).
- **E4b T8** (Álbum): cada especial abierto, `.character(special.id)` sobre su póster.
- **E5b T2** (popup del colchón): `.object("colchon_espera")` en loop con
  `startAmbient(.mattressSqueak)`; al tocar, `.object("colchon_abre")` en `.once` + `mattressRip`, y en
  `onEnd` `cashBurst` y el premio.
- **E5b T3** (la escena del paquete): `LoopingVideoNode(clip: .object("paquete_espera"))` con
  `startAmbient(.packageRattle)`; al tocar, `paquete_abre` en una sola pasada + `packageTapeRip` →
  `packageBurst` al terminar. (El nodo de T4 suma `.once` si E5b lo necesita: una tarea chica de E8d
  si no está.)
- **E6a T8** (la tienda de ORO): `.shopIcon(item.id)` con `role: .icon`, sólo la tarjeta centrada;
  `sfx_shop_shimmer` muy bajo al pasar el brillo; `ArtPacks.prefetch("anim-tienda")` al abrir.
- **E9a / E9b**: la intro va antes de `core.tap` (T11). El reset de la Zona de peligro conserva
  `seenCinematics` (duda 8 de E8b), incluida la intro.
- **E7b-a T2**: `.cinematic` sigue siendo corte natural (también la intro).
- **E8 T10** (peso y memoria): suma lo de T14 y G4.
- **E13b T11** (cierre): la reserva de la cabina y la suspensión del viaje se miden en G4.

## Filas para `tasks.md` §5

Nueva sección "E8d — Todo el juego animado, lado Swift (`2026-10-08-v2-e8d-animaciones-swift.md`)";
rama de épica `v2/e8-anim` a §1. En §5 E8b: **T4, T5, T6 y T12 → "reemplazada por E8d-T1 / T2+T3 /
T5 / T15"**; T8 "depende de E8d-T1 (no de T4); `.intro`"; T9 "depende de E8d-T2 (no de T5); lease
`fullscreen`; `.suspendsVideoPool()` en el cofre". E13b T6 sin cambios. §3.1 suma: `BoardScene.swift`
(E8d T8, T9), `+Bonus` (E8d T7), `project.yml` (E8d T14). §3.2 suma: `AudioManager.swift` (E8c T4 →
E8d T6 → T7 → E8b T9), `CharacterSheetView` (E13 T9 ↔ E8d T5), `+Bootstrap` (E8b T8 → T10 → E8d T11,
T13), `DebugPanelView` (E8d T13), `ElevatorRideOverlay` (E13b T6 → T8 → E8d T10). §6 suma los gates
G1–G7 (G6 y G7 🔒 del dueño).

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E8d | Plan de E8d: todo el juego animado, lado Swift | ✅ | — | — | (el commit de este plan) | 15 tareas; reemplaza E8b T4/T5/T6/T12; E8b T8/T9 cambian; E13b T6 igual; 15 dudas con default; 7 gates |
| E8d-T1 | El manifest entero, `ArtClip` y `CinematicID` (+intro) | ⏳ | — | nuevos | | sonnet, revisión ninguna; reemplaza E8b T4 con su API; ola 1 |
| E8d-T2 | `VideoPlayerPool` y `VideoPlaybackPolicy` (≤ 3 vivos, roles, suspensiones, reservas) | ⏳ | — | nuevos | | sonnet, **rev. opus**; reemplaza `VideoSlot` (E8b T5); ola 1 |
| E8d-T3 | `AnimatedArtView`: póster instantáneo, video con fundido, loop o una vez | ⛔ | T1, T2 | nuevos | | sonnet, **rev. opus** (AVFoundation); reemplaza `LoopingPortraitView` (E8b T5); ∥ T4 |
| E8d-T4 | `LoopingVideoNode` (SpriteKit) y la medición del alfa en `SKVideoNode` | ⛔ | T1, T2 | nuevos | | sonnet, **rev. opus**; la medición decide la ruta de T9 |
| E8d-T5 | El especial que te cayó y la ficha, animados | ⛔ | T3 | SpecialDropView, CharacterSheetView (tibio: E13 T9) | | sonnet, revisión ninguna; capturas SE/16 Pro con `--uitest-video`; reemplaza E8b T6 |
| E8d-T6 | Sonidos nuevos A (paquete, colchón, visitante, tienda, revelación, cable) | ⏳ | — | AudioManager (tibio: E8c T4 → E8d T6 → T7 → E8b T9), generate_audio.py, AudioWiringTests | | sonnet; 11 `.caf`; `pendingWiring` con dueño; 🔒 oído del dueño (no frena); ola 1 |
| E8d-T7 | Los 8 acentos de evento | ⛔ | T6; ventana de +Bonus (o E4a T9) | 🔥 +Bonus (una línea); AudioManager, generate_audio.py | | sonnet, revisión ninguna |
| E8d-T8 | El fondo del piso visible, animado | ⛔ | T4; ventana de BoardScene | 🔥 BoardScene; FloorNode | | sonnet, **rev. opus**; inerte hasta T14; scroll y viaje = póster |
| E8d-T9 | La revelación con el cuerpo entero | ⛔ | T8 | 🔥 BoardScene | | sonnet, **rev. opus**; ruta A (`SKVideoNode`) o B (overlay) según T4 |
| E8d-T10 | El viaje suspende los videos; la cabina reserva su decodificador; `sfx_elevator_cable` | ⛔ | T2, T6; E13b T6, T8 | ElevatorCabin.swift, ElevatorRideOverlay | | sonnet, **rev. opus**; no frena a E13b T6 |
| E8d-T11 | La intro, la primera vez | ⛔ | E8b T10 | +Cinematics, +Bootstrap (tibio); catálogo (snapshot, 1 clave) | | sonnet, rev. sonnet; inerte sin `cinematics.intro` |
| E8d-T12 | On-Demand Resources: `ArtPacks` y el pedido por familia | ⛔ | T1, T3, T4 | nuevos + LoopsManifest, AnimatedArtView, LoopingVideoNode | | sonnet, rev. sonnet |
| E8d-T13 | La sonda de fps y memoria (DEBUG) y `--uitest-anim-stress` | ⛔ | T3, T4 | DebugPanelView, +Bootstrap, +Debug (tibios) | | sonnet, revisión ninguna; habilita G1/G2/G4 antes de la segunda tanda |
| E8d-T14 | 🔒 La segunda tanda entra (sólo lo `va`) | ⛔ | 🔒 revisión de la segunda tanda; T12; pipeline del dueño | 🔥 project.yml; Resources, loops_manifest.json | | cero Swift; ODR por tag; base ≤ +60 MB |
| E8d-T15 | Cierre de E8d: gates en dispositivo y barrido de lugares (controlador) | ⛔ | T1–T14; E8b T8–T11 | `Docs/` | | `completo`; G1–G5 con números; `AnimatedPlacesTests` |
