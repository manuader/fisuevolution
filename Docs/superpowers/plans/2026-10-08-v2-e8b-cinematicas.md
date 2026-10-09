# E8b — Las cinemáticas y los retratos animados: del master de Higgsfield a la pantalla · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal).

**Goal:** que los videos que ya generó la sesión del dueño entren al juego y se vean en su
momento: los **18 retratos en loop** (HEVC con alfa, 512², mudos) en el popup de quien llega, y
las **tres cinemáticas** (720×1280, opacas, con sonido) en sus tres momentos: la de
**reencarnación** al confirmar, antes del cofre; la del **arresto** las dos primeras veces; la de
**Dios** una vez por cuenta, y la tarjeta del nombre de E12 recién después. Un solo `AVPlayer`
activo a la vez.

**Architecture:** el pipeline (`video_assets.py`) convierte los masters y escribe
`Resources/Data/loops_manifest.json`, el contrato que pinean un test en Python y otro en Swift.
En la app, `LoopsManifest` lo lee; `VideoSlot` asegura que un solo video corre; `LoopingPortraitView`
es el retrato (con respaldo a la foto quieta). La cinemática **es un ítem de la cola de
celebraciones** (`CelebrationKind.cinematic`): así el "de a una", el no pisarse con el reveal, el
watchdog y el momento calmo que espera E12 salen del árbitro que ya existe. El payload
(`GameState.cinematic`) se suelta en `releasePayload`, que es el único lugar por el que pasan las
tres salidas, y ahí se anota `meta.engagement.seenCinematics` (EK, `decodeIfPresent`, sin subir
el schema v6). Lo que se dibuja es un overlay a pantalla completa montado en `RootView`, como el
cofre (no un `sheet`).

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · SwiftUI ·
AVFoundation · EconomyKit (SPM puro, `Sendable`) · Swift Testing · XCUITest · XcodeGen (el
`.xcodeproj` no se versiona) · Python 3 + `unittest` + `ffmpeg` con `hevc_videotoolbox`
(`Tools/asset-pipeline`) · `Tools/v2/catalogo.py`.

**Fuente:** `Docs/PLAN-v2.md` E8 ("Higgsfield", "Pipeline de video", "Cuándo se reproducen"), E4
(`LoopingPortraitView`, "Nuevos kinds en `CelebrationQueue`") y E12 ("Al llegar a Dios, después
de la cinemática"); `tasks.md` §3, §4.2 #9 y §5 E8 (fila Higgsfield); `DUENO.md` del run, "Videos
de Higgsfield LISTOS"; los planes de E4b (T2, T3, T8 y su duda 3), E12 (T11, T14), E7b-a (duda 6),
E9a (T1) y E9b (T7). Lo que la spec deja abierto o el código contradice está en "Para el dueño /
dudas", con un default que no frena.

**Rama de la épica:** `v2/e8-video`, desde `version-2`. Cada tarea sale de su punta en un
worktree propio (manual, en `.claude/worktrees.nosync/v2i-e8b-tN`, mientras `.claude/worktrees`
sea un symlink: `tasks.md` §4.2) y el controlador integra de a una.

**Fuera de este plan:** las puertas de la cabina del ascensor (`ascensor/puertas_*.mp4`) son de
**P-E13b**; la cadena animada de "Fusionar todo" no tiene video. El popup del visitante, que es
donde más se ve un retrato, lo arma **E4b T3** con las piezas de este plan.

## ⚠️ Lo que se midió al planificar (2026-10-08, ~19:20) y cambia el brief

`DUENO.md` dice que los 18 masters de `video/loops/` vienen sobre **verde croma** (tres sobre
magenta). **Ya no**: a las 19:05 la sesión del dueño dejó en `loops/` una tanda nueva sobre
**blanco liso** (las dos esquinas de arriba de los 18 miden `#FEFEFE`–`#FFFFFF`; abajo, en 8, tocan la ropa) y
movió la de croma a `video/loops-croma-descartados/` (ésa sí: verde `#02FE03` y, en
`sp_alien_investor`, `sp_lizard` y `sp_zombie_ceo`, magenta `#FD04FC`; abajo, en 10 de 18, tocan
los hombros). Medido también:

| Prueba | Resultado |
|---|---|
| `whitebg_cutout.cutout` cuadro por cuadro sobre `loops/npc_vecina.mp4` a 960², escalado a 512² → HEVC-alfa (`-alpha_quality 0.6 -q:v 50`) | **0,27 MB**; ojos, anteojos y brillos blancos intactos (son islas: no tocan el borde); 10 % del cuadro transparente, 89 % opaco |
| lo que tardó ese recorte | 270 s por loop (2,2 s por cuadro): 18 loops ≈ 81 min. Escalar ANTES de recortar debería bajarlo ~3,5× (estimado por píxeles, sin medir: lo mide la T2) |
| las tres cinemáticas con `--sin-key` (`encode` actual) | `reencarnacion` 1,30 MB · `dios` 1,29 MB · `arresto` 0,92 MB |
| `chromakey` sobre blanco | no se probó: se comería todo blanco del dibujo (ojos, dientes, papeles), que es por qué existe `whitebg_cutout` |

**Default:** se integra la tanda de `loops/` (blanco). Por eso la **T1** hace los dos ajustes de
croma que pidió el dueño (siguen sirviendo para la tanda descartada y para cualquier master
futuro con croma) y la **T2** suma el camino del fondo blanco. Si el dueño prefiere la de croma,
la T3 corre sobre `loops-croma-descartados/` y la T2 queda como soporte (duda 1).

**Peso estimado en el bundle:** 18 × ~0,27 MB + 3,5 MB ≈ **8,5 MB** (los `Resources` hoy pesan
139 MB). La T3 lo mide de verdad y lo anota.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning rompe
  el build. Nada de `Timer` para lógica de juego (regla 2 del HANDOFF).
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate`** al agregar o borrar un
  archivo Swift, un recurso nuevo (las carpetas `Resources/Loops/` y `Resources/Cinematics/`) o un
  test, en el mismo paso en que se crea. Un archivo nuevo de EconomyKit no lo pide.
- **Xcode aplana los recursos en la raíz del bundle**: los videos se buscan por nombre
  (`loop_<id>.mov`, `cine_<id>.mov`), nunca por carpeta. El prefijo lo pone `video_assets.py`.
- **`ffprobe` no ve el alfa del HEVC de Apple** (trampa del cofre, `ChestCinematicPlayer.swift`):
  si un mov tiene alfa se sabe por el encoder (`-alpha_quality`) y por el manifest, no por el
  probe. Y la vista del video lleva **`isOpaque = false`** siempre (la pantalla en negro del
  2026-09-06).
- **Strings nuevos, es + en, por `Tools/v2/catalogo.py`** (formato canónico, trampa 29). La tarea
  escribe sus claves en `Tools/v2/claves-pendientes/e8b-tN.json`; para correr sus tests aplica en
  su worktree y, si el despacho no la hace dueña del catálogo, **commitea sólo el `.json`** y
  descarta el catálogo (`git checkout -- FisuEvolution/Resources/Localizable.xcstrings`). Sólo
  la T9 tiene claves (4).
- **`accessibilityIdentifier` en cada control nuevo, jamás en un contenedor con hijos** (trampa
  9a-bis). Los UI tests asertan por id, nunca por texto (trampa 6: el runner corre en inglés).
- **Nada nuevo corre bajo XCTest ni bajo `--uitest*` salvo que el test lo pida**:
  `GameState.cinematicsAutorun` (patrón `tutorialLessonsAutorun`) arranca falso en los dos; un UI
  test que la quiere pasa `--uitest-cinematics` o `--uitest-cinematic=<id>`.
- **EconomyKit no conoce UI, `Bundle` ni `Date()`.** `seenCinematics` guarda ids como `String`;
  el enum `CinematicID` vive en la app.
- **El cofre no se toca** (`ChestCinematicPlayer`, `ChestOpeningView`): su preroll y su congelón
  están medidos (HANDOFF §7). La duda 3 de E4b ya lo decidió; este plan la respeta.
- **FisuJobs es la referencia visual**; el botón "Saltar" de la cinemática es una cápsula de la
  casa (`Tokens`, `PaletteInk`), no un botón del sistema.
- Código nuevo limpio y con pocos comentarios (regla del dueño); el comentario que miente se
  corrige en el commit que lo vuelve mentira (el docstring de `CelebrationKind` dice "Quedan afuera
  … la reencarnación": la T8 lo ajusta).
- **Commits en español, estilo de la casa** (`feat(video): …`, `feat(cinematicas): …`,
  `fix(…)`), **SIN `Co-Authored-By`**. Staging selectivo por archivo y `git diff --cached --stat`
  antes de cada commit.
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración, ledger,
  journal y `tasks.md`. Ningún subagente toca `Docs/`, `handoffs/`, el journal, `tasks.md` ni
  `Tools/v2/rojos-declarados.txt`.

## Verificación (vale para toda tarea)

```bash
# App: EconomyKit entero + build + esas clases de FisuEvolutionTests
Tools/v2/oraculo.sh tarea <Clases>

# Pipeline (un worktree no tiene .venv: se usa el del checkout principal, como hace oraculo.sh)
PY=/Users/manuader/Desktop/projects/FisuEvolution/Tools/asset-pipeline/.venv/bin/python
(cd Tools/asset-pipeline && "$PY" -m unittest tests.test_video_assets -v)
(cd Tools/asset-pipeline && "$PY" -m unittest discover -s tests -q)   # el pipeline entero
```

- Los **UI tests** que una tarea agrega se corren aislados con la **Receta R** de
  `Docs/superpowers/plans/2026-10-07-v2-e4a-visitantes-eventos.md`
  (`-only-testing:FisuEvolutionUITests/<Clase>`, simulador propio por UDID que se apaga y borra).
- ⚠️ "0 tests" con éxito no prueba nada: la salida tiene que nombrar las clases. Ante un rojo en
  masa, `uptime` y `ps aux | grep '[x]codebuild'` antes de culpar al código.
- Los tests del pipeline que codifican se saltean sin `hevc_videotoolbox` + `libx264`
  (`PUEDE_CODIFICAR`): en esta Mac están; un "skipped" en `DePuntaAPunta` es un rojo.

## Las referencias, verificadas contra el árbol (`8eec356`)

| Lo que cita el plan | Dónde está hoy | Qué significa para E8b |
|---|---|---|
| `scripts/video_assets.py` "reusa `chest_video_frames.py`" | existe (E8 pipeline, `4ea0678`): `KINDS`, `CINEMATIC_IDS`, `measure_key_color` (4 esquinas × 3 cuadros), `key_color_from_patches` (exige verde: `MIN_GREEN_LEAD`), `encode`, `process`, `register` | T1: esquinas por clase + magenta; T2: fondo blanco |
| `loops_manifest.json` "pineado por tests en Swift y Python" | `Resources/Data/loops_manifest.json` vacío (`schemaVersion 1`); `tests/test_video_assets.py` (`ManifestVersionado`, `DePuntaAPunta`); **no hay test en Swift** | T3 pinea los 18 + 3 en Python; T4 crea `LoopsManifestTests` |
| `Resources/Loops/`, `Resources/Cinematics/` | no existen | las crea T3 (`process` hace `mkdir`) |
| los masters en `Tools/asset-pipeline/video/` | sólo `chest-animation.mp4` (versionado) | T3 copia `loops/` y `cinematicas/` (duda 2: se versionan, ≈ 41 MB) |
| `whitebg_cutout.cutout` | `scripts/whitebg_cutout.py:201` (conectividad: fondo = blanco que toca el borde; matting de 3 px) | T2 lo usa cuadro por cuadro |
| `LoopingPortraitView` "que generaliza `ChestCinematicPlayer`" | no existe; **E4b T3 (⛔) lo planea crear** junto con `LoopsManifest` y `LoopsManifestTests`, aparte del cofre (su duda 3) | **T4 y T5 los crean con la misma API** que dejó escrita E4b T3 (`LoopsManifest.load(from:)`, `.main`, `portraitURL(for:in:)`; `LoopingPortraitView(url:fallback:)`); E4b T3 los consume (carry) |
| `CelebrationQueue` "nuevo kind `cinematic`" | `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` (11 kinds; `isSkippable == (timeout != nil)` pineado en `CelebrationQueueTests.skippableMatchesSelfClosing`) | T8: `.cinematic`, prioridad 2, timeout 12 s |
| las tres salidas de un ítem | `GameState+Celebrations.swift`: `celebrationFinished`, `skipCurrentCelebration`, `advanceCelebrations` → las tres llaman `releasePayload(for:)` | T8 anota `seenCinematics` ahí |
| `isCalmMoment` | `GameState+Rewards.swift:22` (incluye `celebrations.current == nil`) | la cinemática con el turno ya no es momento calmo: la tarjeta de E12 T14 sale después sin tocarla |
| `meta.engagement` / `seenCinematics` | `EngagementState.swift` (EK) **vacío**; `SaveConflictResolver` ya delega en `EngagementState.resolve` (`:80`); save v6 (E1 T4 ✅) | T7: el campo, su `decodeIfPresent` y su regla (`max` por id). **No sube el schema** |
| la reencarnación | `GameState+Prestige.confirmPrestige()` (`:139-182`): aplica, `awardChest(minRarity: .epica)`, `audio?.play(.prestige)`, intersticial en `Task` | T10: la cinemática se pide entre `self.player = player` y el cofre |
| el cofre de la reencarnación | `prestigeChestsPending += 1`; se abre a mano desde Regalos (`openChest()`), entra a la cola como `.chestOpening` (prioridad 4) | "antes del cofre" = la cinemática toma el turno al confirmar; un cofre que se abra mientras espera detrás |
| la llegada a Dios | no hay evento propio: el reveal del tier tope llama `markRevealed(tier:)` (`GameState+BoardChanges.swift:123`) al ARRANCAR; `tiers.maxTier` es el tope | T10: `markRevealed(tier: godTier)` pide la de Dios; E12 T11 engancha ahí también (`ranking?.reachedGod()`) |
| `godTier` | lo pide el protocolo `RankingStateHost` de E12 (`var godTier: Int? { get }`, plan E12 `:1000`) | T8 lo define en `GameState+Cinematics` con esa firma: el conformance de E12 T11 queda satisfecho (carry) |
| el arresto | no existe: lo trae E4b T2 (`chooseVisitOption`, opción `.release` de `comisario_arresto` y `arca_paraiso`, en `GameState+Visitors.swift`) | T11, detrás de E4b T2 |
| retratos de especiales hoy | `SpecialDropView.portrait` (`:93-108`): la canónica de `manifest.characters[special.id]` sobre el plato de 168 pt | T6 le pone el loop con la foto de respaldo |
| `--uitest*` y el autorun | `applyLaunchArgumentDefaults` (`GameState+Debug.swift:25-80`), fixtures en `GameState+Bootstrap.swift` (`#if DEBUG`, `:159`, `:268`) | T8: `--uitest-cinematics`, `--uitest-cinematic=<id>` |
| el overlay del cofre | `RootView.swift:218-228` (`ZStack` propio, `.transition(.opacity)`, no `sheet`) | T9 monta la cinemática al lado, con el mismo patrón |
| volumen de la cinemática | el cofre usa `audio?.sfxVolume` (`ChestOpeningView.swift:606`); la música va por `AudioManager.floorPlayers` (`:37-46`, `:152-206`) | T9: volumen de efectos y la música baja (`setMusicDucked`) mientras dura |

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Tools/asset-pipeline/scripts/video_assets.py` | esquinas por clase y key magenta (T1); fondo blanco por conectividad (T2) | 1, 2 |
| `Tools/asset-pipeline/tests/test_video_assets.py` | los tests de los dos ajustes (T1), del blanco (T2) y el pin de los 18 + 3 (T3) | 1, 2, 3 |
| `Tools/asset-pipeline/video/loops/*.mp4`, `video/cinematicas/{reencarnacion,dios,arresto}.mp4` | los masters (nuevos) | 3 |
| `FisuEvolution/Resources/Loops/loop_<id>.mov` (18), `Resources/Cinematics/cine_<id>.mov` (3), `Resources/Data/loops_manifest.json` | las piezas y el contrato (nuevos / regenerado) | 3 |
| `FisuEvolution/Managers/LoopsManifest.swift` | **nuevo** — el manifest leído, `CinematicID` | 4 |
| `FisuEvolutionTests/LoopsManifestTests.swift` | **nuevo** — el lado Swift del contrato | 4 |
| `FisuEvolution/UI/Art/VideoSlot.swift`, `FisuEvolution/UI/Art/LoopingPortraitView.swift` | **nuevos** — un solo video a la vez; el retrato en loop | 5 |
| `FisuEvolutionTests/VideoSlotTests.swift` | **nuevo** | 5 |
| `FisuEvolution/UI/Popups/SpecialDropView.swift` | el especial que te cayó, animado | 6 |
| `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift` | `seenCinematics`, `recordCinematic`, `decodeIfPresent`, `resolve` | 7 |
| `Packages/EconomyKit/Tests/EconomyKitTests/SeenCinematicsTests.swift` | **nuevo** | 7 |
| `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` (tibio) | `CelebrationKind.cinematic` | 8 |
| `FisuEvolution/Game/State/GameState.swift` 🔥 | `cinematic` y `cinematicsAutorun` (dos propiedades) | 8 |
| `FisuEvolution/Game/State/GameState+Cinematics.swift` | **nuevo** — `godTier`, `isCinematicDue`, `playCinematicIfDue`, `recordCinematicSeen`, `reconcileCinematics` | 8, 10 |
| `FisuEvolution/Game/State/GameState+Celebrations.swift` (tibio) | sync, release y el UI apagado | 8 |
| `FisuEvolution/Game/State/GameState+Debug.swift`, `+Bootstrap.swift` (tibios) | autorun bajo `--uitest*`, fixture `--uitest-cinematic=<id>` (T8); `reconcileCinematics()` al arrancar (T10) | 8, 10 |
| `FisuEvolutionTests/CinematicWiringTests.swift` | **nuevo** — el turno | 8 |
| `FisuEvolutionTests/CelebrationWiringTests.swift`, `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift` | el `switch` exhaustivo; prioridad y tope | 8 |
| `FisuEvolution/UI/Popups/CinematicOverlay.swift` | **nuevo** — la cinemática a pantalla completa (`CinematicPlayer`, `CinematicVideoView`) | 9 |
| `FisuEvolution/App/RootView.swift` 🔥 | el overlay montado | 9 |
| `FisuEvolution/Audio/AudioManager.swift`, `FisuEvolutionTests/AudioManagerTests.swift` | `setMusicDucked(_:)` | 9 |
| `FisuEvolution/UI/DebugPanelView.swift` (tibio) | tres botones "Cinemática: …" | 9 |
| `FisuEvolutionUITests/CinematicUITests.swift` | **nuevo** | 9 |
| `Tools/v2/claves-pendientes/e8b-t9.json` | 4 claves | 9 |
| `FisuEvolution/Game/State/GameState+Prestige.swift`, `+BoardChanges.swift` (tibio) | los disparadores de reencarnación y Dios | 10 |
| `FisuEvolutionTests/CinematicTriggerTests.swift` | **nuevo** (T10), + el arresto (T11) | 10, 11 |
| `FisuEvolution/Game/State/GameState+Visitors.swift` (lo crea E4b T2) | el disparador del arresto | 11 |

## Orden, olas y paralelismo

**Archivos calientes** (`tasks.md` §3.1, un dueño por ola): E8b toma `GameState.swift` (T8, dos
propiedades), `RootView.swift` (T9) y el catálogo (T9, por snapshot). Tibios: `CelebrationQueue`
(T8), `+Celebrations` (T8), `+Debug`/`+Bootstrap` (T8, T10), `EngagementState` (T7),
`+BoardChanges` (T10), `DebugPanelView` (T9). **No toca** `PlayerState.swift`,
`SaveConflictResolver.swift`, `BoardScene.swift`, `ContentSystems.swift`, `+Bonus`,
`SettingsView.swift` ni `project.yml`.

| T | Qué | 🔥 / tibios | Depende de | Save | Revisión · modelo |
|---|---|---|---|---|---|
| 1 | `video_assets.py`: esquinas de arriba en el retrato, key magenta | — · `video_assets.py`, `test_video_assets.py` | — | no | ninguna · sonnet |
| 2 | `video_assets.py`: fondo blanco por conectividad | — · ídem | T1 | no | sonnet · sonnet |
| 3 | los 18 retratos y las 3 cinemáticas, integrados y pesados | — · `Resources/Loops`, `Resources/Cinematics`, `loops_manifest.json`, masters | T2 | no | el controlador mira la hoja de contacto · sonnet |
| 4 | `LoopsManifest` + `CinematicID` + `LoopsManifestTests` | — | T3 | no | ninguna · sonnet |
| 5 | `VideoSlot` + `LoopingPortraitView` | — | — | no | sonnet · sonnet |
| 6 | el especial que te cayó, animado | — · `SpecialDropView` | T4, T5 | no | ninguna · sonnet |
| 7 | `seenCinematics` en `meta.engagement` | — · `EngagementState` (EK) | E1-T4 ✅ | **sí** | **opus** · sonnet |
| 8 | el turno de la cinemática | 🔥 `GameState.swift` · `CelebrationQueue`, `+Celebrations`, `+Debug`, `+Bootstrap` | T4, T7 | **sí** (escribe `meta`) | **opus** · sonnet |
| 9 | la cinemática en pantalla | 🔥 `RootView`, catálogo (snapshot) · `AudioManager`, `DebugPanelView` | T5, T8 | no | sonnet · sonnet |
| 10 | reencarnación y Dios | — · `+Prestige`, `+BoardChanges`, `+Bootstrap` | T8, T9 | sí (vía T8) | **opus** · sonnet |
| 11 | el arresto | — · `+Visitors` | T10; **E4b-T2** | no | sonnet · sonnet |
| 12 | cierre | `Docs/` (controlador) | T1–T11 | — | — |

```
Ya, sin compilar (pipeline)            T1 → T2 → T3
Ya, compilando (≤ 3 en el run)         T5 ║ T7
tras T3                                T4
tras T4 y T5                           T6
tras T4 y T7 + ventana de GameState    T8
tras T5, T8 + ventana de RootView      T9
tras T9                                T10
tras T10 y E4b T2                      T11
cierre                                 T12
```

**Reglas del paralelismo:**

1. **El pipeline no compila la app**: T1–T3 no cuentan para el tope de 3 compilando; T3 sí corre
   ~25 min de `ffmpeg` + recorte (en background, `run_in_background`).
2. **De a una sobre el mismo archivo**: T1 → T2 → T3 (`video_assets.py`, `test_video_assets.py`);
   T8 → T10 (`+Bootstrap`, `GameState+Cinematics`); T10 → T11 (`CinematicTriggerTests`).
3. **`EngagementState` (T7)**: la cadena de `tasks.md` §3.2 es E3b T9 → E4a T3 → E5a T4 → E6a T1,
   todas ⛔. La T7 entra **primera** si se despacha antes de que arranque E3b T9; si no, va al final
   de la cadena. El que llega segundo suma su parámetro al mismo `init` y su línea al mismo
   `init(from:)` y `resolve` (conflicto textual, sin lógica cruzada).
4. **`CelebrationQueue` (T8)**: la cadena del tibio es E4b T1, T4 → E6a T12 → **E9a T1** ("último
   en `CelebrationQueue`"). La T8 puede ir antes que todas (ninguna arrancó); E9a T1 la encuentra
   adentro y la cuenta en su `isSkippable` explícito (carry).
5. **`GameState.swift` (T8) y `RootView.swift` (T9)** esperan ventana libre del 🔥. Son dos
   propiedades y un `ZStack`: si no hay ventana, el controlador las aplica al integrar (precedente
   E12 T11).
6. **T10 no se integra antes que T9**: sin el overlay, la cinemática tomaría el turno sin nadie que
   la dibuje y la cola quedaría muda hasta el watchdog (12 s).

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| `GameState` arrancado con el contenido real | `await makeGameState()` | `FisuEvolutionTests/Support/GameStateFixture.swift` |
| contenido real | `try GameContentLoader.load(from: .main)` (`specials.specials`, `tiers.maxTier`) | `GameContentLoader.swift` |
| reencarnar en un test | `giveEarningsForPrestigeTesting(oro:)` + `confirmPrestige()` | `ChestSourcesTests.prestigeResetsTheCounterAndKeepsPendingChests` |
| frontera y pisos | `debugSetMaxTier(_:)`, `debugUnlockFloors(throughTier:)` | `GameState+Debug.swift` |
| vaciar la cola | `while let s = gameState.showing { gameState.celebrationFinished(s) }` con tope | `CelebrationWiringTests` (helper privado `drain`) |
| EK sintético | `fxSave(lifetime:lastSeen:)` | `SaveConflictResolverTests.swift` |
| JSON de un save | `JSONEncoder().encode(state)` → `JSONSerialization` → mutar → `JSONDecoder().decode` | patrón de `SaveCompatibilityTests` |
| un master sintético | `DePuntaAPunta.master(width, height)` (lavfi `color` + `drawbox` + `sine`) | `tests/test_video_assets.py` |

---

### Task 1: `video_assets.py` — el retrato mide arriba y el key acepta magenta

**Objetivo:** los dos ajustes que pidió el dueño para los masters de croma. Un retrato es un busto:
los hombros tocan las dos esquinas de abajo (10 de los 18 de croma), así que **para `retrato` se
miden sólo las dos de arriba** (en los tres cuadros); la cinemática sigue con las cuatro. Y el key
puede ser **verde o magenta** (`#FF00FF`, para los personajes de piel verde); el magenta va **sin
`despill`** (ffmpeg sólo lo conoce para verde y azul, y uno verde se comería al personaje).

**Files:**
- Modify: `Tools/asset-pipeline/scripts/video_assets.py`
- Modify: `Tools/asset-pipeline/tests/test_video_assets.py`

**Oráculo:** `(cd Tools/asset-pipeline && "$PY" -m unittest tests.test_video_assets -v)` VERDE con
los tests nuevos nombrados, y `discover -s tests -q` sin rojos nuevos.
**Revisión:** ninguna (el controlador lee el diff) · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo.** En `MedicionDelVerde` (renombrar la clase a
  `MedicionDelFondo`):

```python
    def test_un_magenta_liso_da_su_hex(self):
        parches = [parche((253, 4, 252), ruido=2) for _ in range(6)]
        medido = rgb(key_color_from_patches(parches))
        self.assertLessEqual(np.abs(medido - (253, 4, 252)).max(), 1)
        self.assertEqual(video_assets.key_family("0xFD04FC"), "magenta")

    def test_la_familia_del_key_sale_del_color(self):
        self.assertEqual(video_assets.key_family("0x22924A"), "green")
        self.assertIsNone(video_assets.key_family("0x283CC8"))

    def test_el_magenta_va_sin_despill_y_el_verde_con(self):
        self.assertIn("despill=type=green", video_assets.keying("0x22924A", 0.11, 0.04))
        self.assertNotIn("despill", video_assets.keying("0xFD04FC", 0.11, 0.04))

    def test_cada_clase_mide_sus_esquinas(self):
        self.assertEqual(video_assets.CORNER_ROWS["retrato"], ("top",))
        self.assertEqual(video_assets.CORNER_ROWS["cinematica"], ("top", "bottom"))
```

  El de azul (`test_un_fondo_que_no_es_verde_se_rechaza`) sigue y pasa a llamarse
  `test_un_fondo_que_no_es_ni_verde_ni_magenta_se_rechaza`. En `DePuntaAPunta`, `master` gana dos
  parámetros y dos tests:

```python
    def master(self, width: int, height: int, fondo: str = VERDE,
               personaje: str = "0xC83C28", hombros: bool = False) -> Path:
        path = self.root / f"master_{width}x{height}_{fondo}_{hombros}.mp4"
        cajas = [f"drawbox=x={width // 3}:y={height // 4}:w={width // 3}:h={height // 2}"
                 f":color={personaje}:t=fill"]
        if hombros:
            # Un busto: los hombros llegan a las dos esquinas de abajo.
            cajas.append(f"drawbox=x=0:y={height - height // 6}:w={width}:h={height // 6}"
                         f":color={personaje}:t=fill")
        subprocess.run(
            ["ffmpeg", "-v", "error",
             "-f", "lavfi", "-i", f"color=c={fondo}:s={width}x{height}:r=24:d=1",
             "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
             "-vf", ",".join(cajas),
             "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest",
             "-y", str(path)],
            check=True,
        )
        return path

    def test_un_busto_se_mide_por_arriba_y_sale(self):
        master = self.master(640, 640, hombros=True)
        with self.assertRaises(MasterError, msg="con las cuatro esquinas, los hombros lo tapan"):
            video_assets.measure_key_color(master, rows=("top", "bottom"))
        entry = video_assets.process("retrato", "npc_prueba", master)
        self.assertLessEqual(np.abs(rgb(entry["keyColor"]) - rgb(self.VERDE)).max(), 4)

    def test_un_retrato_verde_sobre_magenta_conserva_su_verde(self):
        master = self.master(640, 640, fondo="0xFF00FF", personaje="0x2CA02C")
        entry = video_assets.process("retrato", "sp_prueba", master)
        self.assertEqual(video_assets.key_family(entry["keyColor"]), "magenta")
        frame = self.cuadro(self.resources / "Loops" / "loop_sp_prueba.mov")
        h, w = frame.shape[:2]
        self.assertLessEqual(frame[4, 4, :3].max(), 8, "el fondo magenta se fue")
        self.assertGreater(frame[h // 2, w // 2, 1], 120, "y el personaje sigue verde")
```

  Correr: falla por `key_family`, `keying`, `CORNER_ROWS` y el `rows=` de `measure_key_color`.

- [ ] **Step 2: La implementación.** En `video_assets.py`:

```python
# Las esquinas que se miden por clase. Un retrato es un busto: los hombros tocan
# las dos de abajo (10 de los 18 masters de croma), así que se miden las de
# arriba; en la cinemática las cuatro son fondo.
CORNER_ROWS = {"retrato": ("top",), "cinematica": ("top", "bottom")}

# Cuánto le gana el canal del key a los otros dos: verde (G sobre R y B) o
# magenta (R y B sobre G), para los personajes de piel verde.
MIN_KEY_LEAD = 40


def key_family(color: str) -> str | None:
    r, g, b = (int(color[i:i + 2], 16) for i in (2, 4, 6))
    if g - max(r, b) >= MIN_KEY_LEAD:
        return "green"
    if min(r, b) - g >= MIN_KEY_LEAD:
        return "magenta"
    return None


def keying(color: str, similarity: float, blend: float) -> str:
    """El filtro del key. El magenta va sin `despill`: ffmpeg sólo lo conoce para
    verde y azul, y uno verde se comería a quien está sobre magenta por ser verde."""
    if key_family(color) == "green":
        return key_filter(color, similarity, blend)
    return f"chromakey={color}:{similarity}:{blend}"
```

  - `key_color_from_patches`: el chequeo final pasa a `if key_family(hex) is None: raise
    MasterError(f"el fondo no es verde ni magenta: mide …")` (se borra `MIN_GREEN_LEAD`; el
    docstring dice "verde o magenta").
  - `measure_key_color(video, rows=("top", "bottom"))`: los parches salen de
    `for y in [{"top": 0, "bottom": height - p}[r] for r in rows]`.
  - `process`: `measure_key_color(master, rows=CORNER_ROWS[kind])`; `encode` usa
    `keying(key_color, similarity, blend)` en lugar de `key_filter(...)`.
  - El docstring del módulo: "pantalla verde **o magenta**" y "en las esquinas de arriba si es un
    retrato".

- [ ] **Step 3:** oráculo del pipeline VERDE (el test del cofre,
  `test_el_master_del_cofre_mide_el_verde_que_se_calibro_a_mano`, sigue verde: mide las cuatro).
  Commit: `feat(video): el retrato se mide por arriba y el key acepta magenta`.

---

### Task 2: `video_assets.py` — el retrato sobre fondo blanco, por conectividad

**Objetivo:** la tanda vigente de `loops/` viene sobre **blanco liso**. `chromakey` sobre blanco
se come los ojos y los brillos; el recorte que ya usa el pipeline de imágenes
(`whitebg_cutout.cutout`: fondo = blanco que toca el borde, matting de 3 px) no. El retrato con
fondo blanco se recorta **cuadro por cuadro**, escalado primero a 512² (medido: a 960² son 270 s
por loop), premultiplicado y codificado HEVC con alfa desde la secuencia de PNG.

**Files:**
- Modify: `Tools/asset-pipeline/scripts/video_assets.py`
- Modify: `Tools/asset-pipeline/tests/test_video_assets.py`

**Oráculo:** el del pipeline, como en T1.
**Revisión:** sonnet (un recorte malo se ve en los 18 retratos) · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo.**

```python
class FondoBlanco(unittest.TestCase):
    def test_el_blanco_se_reconoce_como_familia(self):
        self.assertEqual(video_assets.key_family("0xFEFEFE"), "white")
        self.assertEqual(rgb(key_color_from_patches([parche((254, 254, 254), ruido=1)] * 6)).min() >= 252, True)
```

  y en `DePuntaAPunta` (el master blanco lleva un "ojo": un anillo negro con blanco adentro):

```python
    def master_blanco(self, side: int = 640) -> Path:
        path = self.root / "master_blanco.mp4"
        c, r = side // 2, side // 8
        subprocess.run(
            ["ffmpeg", "-v", "error",
             "-f", "lavfi", "-i", f"color=c=white:s={side}x{side}:r=24:d=1",
             "-vf", (f"drawbox=x={side // 4}:y={side // 4}:w={side // 2}:h={side // 2}:color=0xC83C28:t=fill,"
                     f"drawbox=x={c - r}:y={c - r}:w={2 * r}:h={2 * r}:color=black:t=fill,"
                     f"drawbox=x={c - r + 6}:y={c - r + 6}:w={2 * r - 12}:h={2 * r - 12}:color=white:t=fill"),
             "-c:v", "libx264", "-pix_fmt", "yuv420p", "-an", "-y", str(path)],
            check=True,
        )
        return path

    def test_un_retrato_sobre_blanco_recorta_el_fondo_y_no_el_ojo(self):
        entry = video_assets.process("retrato", "npc_prueba", self.master_blanco())
        self.assertEqual(video_assets.key_family(entry["keyColor"]), "white")
        self.assertTrue(entry["alpha"])
        self.assertEqual((entry["frames"], entry["fps"]), (24, 24))
        frame = self.cuadro(self.resources / "Loops" / "loop_npc_prueba.mov")
        self.assertLessEqual(frame[4, 4, :3].max(), 8, "el fondo blanco se fue (premultiplicado)")
        self.assertGreater(frame[256, 256, :3].min(), 230, "el blanco encerrado es dibujo y queda")
        if alfa_decodificable():
            self.assertEqual(frame[4, 4, 3], 0)
            self.assertEqual(frame[256, 256, 3], 255)

    def test_una_cinematica_sobre_blanco_se_rechaza(self):
        with self.assertRaises(MasterError):
            video_assets.process("cinematica", "dios", self.master_blanco())
```

- [ ] **Step 2: La implementación.**
  - `key_family`: antes del verde, `if min(r, g, b) >= 255 - WHITE_TOLERANCE: return "white"`
    (`WHITE_TOLERANCE` importado de `whitebg_cutout`, 14).
  - `process`: si `kind == "cinematica"` y la familia es `white`, `MasterError("una cinemática con
    alfa va sobre croma; si trae su fondo, --sin-key")`. Si es `retrato` y `white`, en lugar de
    `encode` llama a `encode_white_portrait(master, output)`; el `keyColor` del manifest es el
    blanco medido (así `alpha == (keyColor is not None)` sigue valiendo y el schema no cambia).

```python
def encode_white_portrait(master: Path, output: Path) -> None:
    """Fondo blanco: el recorte por conectividad de las imágenes (`whitebg_cutout`),
    cuadro por cuadro. `chromakey` sobre blanco se come los ojos y los brillos;
    acá el fondo es sólo el blanco que toca el borde. Se escala ANTES de recortar:
    a 960² son 270 s por loop, a 512² ~3,5 veces menos, y el matting de 3 px no
    se nota a ese tamaño."""
    stream = video_stream(probe(master))
    fps = stream["r_frame_rate"]
    framing = framing_filter("retrato", int(stream["width"]), int(stream["height"]))
    with tempfile.TemporaryDirectory() as tmp:
        frames = Path(tmp)
        subprocess.run(
            ["ffmpeg", "-v", "error", "-i", str(master), "-vf", framing,
             "-fps_mode", "passthrough", str(frames / "f%04d.png")],
            check=True,
        )
        for png in sorted(frames.glob("f*.png")):
            with Image.open(png) as raw:
                rgba = np.asarray(cutout(raw.convert("RGB"))).astype(np.float32)
            # Premultiplicado, como el del cofre: `AVPlayerLayer` lo compone así.
            rgba[..., :3] *= rgba[..., 3:4] / 255.0
            Image.fromarray(np.round(rgba).astype(np.uint8), "RGBA").save(png)
        output.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["ffmpeg", "-v", "error", "-framerate", fps, "-i", str(frames / "f%04d.png"),
             "-vf", "format=bgra", "-c:v", "hevc_videotoolbox",
             "-alpha_quality", HEVC_ALPHA_QUALITY, "-q:v", HEVC_QUALITY,
             "-tag:v", "hvc1", "-an", "-y", str(output)],
            check=True,
        )
```

  (imports: `tempfile`, `from PIL import Image`, `from whitebg_cutout import WHITE_TOLERANCE,
  cutout`). El docstring del módulo suma el párrafo del fondo blanco.

- [ ] **Step 3:** oráculo VERDE. Medir a mano el costo real sobre un master de verdad
  (`time "$PY" scripts/video_assets.py retrato npc_vecina --video ~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2/video/loops/npc_vecina.mp4`)
  en un worktree descartable o con `RESOURCES` apuntando a un temporal, y **no commitear** esa
  pieza (es de la T3). Anotar los segundos en el reporte. Commit:
  `feat(video): los retratos sobre blanco se recortan por conectividad`.

---

### Task 3: Los 18 retratos y las 3 cinemáticas, integrados y pesados

**Objetivo:** los masters adentro del repo, las 21 piezas en `Resources/`, el manifest escrito por
el script y pineado por el test de Python con la lista exacta, y el peso del bundle anotado.

**Files:**
- Create: `Tools/asset-pipeline/video/loops/<id>.mp4` (18), `Tools/asset-pipeline/video/cinematicas/{reencarnacion,dios,arresto}.mp4`
- Create: `FisuEvolution/Resources/Loops/loop_<id>.mov` (18), `FisuEvolution/Resources/Cinematics/cine_<id>.mov` (3)
- Modify: `FisuEvolution/Resources/Data/loops_manifest.json` (lo escribe el script; no se edita a mano)
- Modify: `Tools/asset-pipeline/tests/test_video_assets.py`

**Oráculo:** el del pipeline (`ManifestVersionado` deja de pasar en vacío) + la hoja de contacto
mirada por el controlador.
**Revisión:** el controlador mira la hoja · **Modelo:** sonnet.

- [ ] **Step 1: El pin, en rojo.** En `ManifestVersionado`:

```python
    # Los 18 de la tanda de Higgsfield (PLAN-v2 E8): 8 visitantes y los 10 especiales.
    # El gemelo en Swift es `LoopsManifestTests.portraits`.
    RETRATOS = {
        "npc_comisario", "npc_conductor", "npc_ministro", "npc_puntero",
        "npc_sindicalista", "npc_turista", "npc_vecina", "npc_vendedor",
        "sp_alien_investor", "sp_arbolito", "sp_bug_simulacion", "sp_coach",
        "sp_contador_dios", "sp_cryptobro", "sp_demonio_arca", "sp_influencer",
        "sp_lizard", "sp_zombie_ceo",
    }

    def test_estan_los_18_retratos(self):
        self.assertEqual(set(self.manifest["portraits"]), self.RETRATOS)

    def test_las_tres_cinematicas_son_opacas_y_suenan(self):
        # Subconjunto y no igualdad: P-E13b suma las puertas de la cabina a esta sección.
        for piece_id in CINEMATIC_IDS:
            with self.subTest(id=piece_id):
                entry = self.manifest["cinematics"][piece_id]
                self.assertFalse(entry["alpha"], "la escena trae su propio fondo: --sin-key")
                self.assertTrue(entry["audio"], "Seedance la entregó con sonido")
```

  Correr: rojo (el manifest está vacío).

- [ ] **Step 2: Los masters.** Paso 0, **mirar antes de copiar**: las esquinas de arriba de
  `~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2/video/loops/*.mp4`
  tienen que medir blanco (`"$PY" scripts/video_assets.py medir …` no sirve para blanco antes de la
  T2: usar `measure_key_color(master, rows=("top",))` desde un `-c`). Si en `loops/` volvió a haber
  croma, usar ésa (la T1 la cubre) y avisarlo en el reporte. Después:

```bash
SRC=~/Desktop/projects/automatic-image-generation/projects/fisu-evolution-v2/video
mkdir -p Tools/asset-pipeline/video/loops Tools/asset-pipeline/video/cinematicas
cp "$SRC"/loops/*.mp4 Tools/asset-pipeline/video/loops/
cp "$SRC"/cinematicas/{reencarnacion,dios,arresto}.mp4 Tools/asset-pipeline/video/cinematicas/
ls Tools/asset-pipeline/video/loops | wc -l    # 18
```

  ⚠️ `arresto.mp4` es la toma 2, sin texto en la libreta; **no** `arresto_v1_con_texto.mp4`.

- [ ] **Step 3: Las piezas** (en background: ~25 min el lote de retratos):

```bash
cd Tools/asset-pipeline
for m in video/loops/*.mp4; do "$PY" scripts/video_assets.py retrato "$(basename "$m" .mp4)" || echo "FALLÓ $m"; done
for c in reencarnacion dios arresto; do "$PY" scripts/video_assets.py cinematica "$c" --sin-key; done
```

  Un `[ERROR]` no se tapa con `--video` ni con otro umbral: se reporta con el id y el mensaje.

- [ ] **Step 4: La hoja de contacto** (no se commitea; va al reporte con su ruta): cuatro cuadros
  (0, 40, 80, 120) de cada retrato compuestos sobre magenta, más la costura del loop (la
  diferencia media entre el cuadro 0 y el último, que tiene que ser chica: "primer cuadro =
  último"):

```bash
OUT="$TMPDIR/e8b-contacto"; mkdir -p "$OUT"
for m in ../../FisuEvolution/Resources/Loops/*.mov; do
  ffmpeg -v error -y -f lavfi -i color=c=0xFF00FF:s=512x512 -i "$m" \
    -filter_complex "[1:v]select='eq(n\,0)+eq(n\,40)+eq(n\,80)+eq(n\,120)',setpts=N/TB[f];[0:v][f]overlay=shortest=1,tile=4x1" \
    -frames:v 1 "$OUT/$(basename "$m" .mov).png"
done
```

  (Si este ffmpeg no decodifica el alfa —`alfa_decodificable()`—, la hoja sale con fondo negro
  premultiplicado: alcanza para ver el recorte.)

- [ ] **Step 5: El peso.**

```bash
du -ch FisuEvolution/Resources/Loops FisuEvolution/Resources/Cinematics | tail -1
du -sh FisuEvolution/Resources Tools/asset-pipeline/video
```

  Estimado ≈ 8,5 MB de bundle (18 × ~0,27 + 3,5) y ≈ 41 MB de masters en el repo. Los dos
  números van en el mensaje del commit y en el reporte (los recoge E8 T10, la vara de los 60 MB).

- [ ] **Step 6:** oráculo del pipeline VERDE (incluido `test_no_hay_piezas_huerfanas` y
  `test_cada_entrada_apunta_a_su_pieza_con_su_tamano`). Commit (staging por carpeta, revisado con
  `git diff --cached --stat`):
  `feat(video): los 18 retratos en loop y las tres cinemáticas, integrados (+X,X MB)`.

---

### Task 4: `LoopsManifest` y el contrato del lado de Swift

**Objetivo:** la app lee `loops_manifest.json` y un test pinea lo mismo que el de Python. La API es
**la que dejó escrita E4b T3** (para que esa tarea la consuma sin cambios) más `CinematicID` y
`cinematicURL(for:)`.

**Files:**
- Create: `FisuEvolution/Managers/LoopsManifest.swift`
- Create: `FisuEvolutionTests/LoopsManifestTests.swift`

**Oráculo:** `Tools/v2/oraculo.sh tarea LoopsManifestTests`
**Revisión:** ninguna · **Modelo:** sonnet.

- [ ] **Step 1: El test, en rojo** (y `xcodegen generate`):

```swift
import Foundation
import Testing
@testable import FisuEvolution

@Suite("loops_manifest.json: los retratos y las cinemáticas")
@MainActor
struct LoopsManifestTests {
    /// El gemelo de `ManifestVersionado.RETRATOS` en `test_video_assets.py`.
    static let portraits: Set<String> = [
        "npc_comisario", "npc_conductor", "npc_ministro", "npc_puntero",
        "npc_sindicalista", "npc_turista", "npc_vecina", "npc_vendedor",
        "sp_alien_investor", "sp_arbolito", "sp_bug_simulacion", "sp_coach",
        "sp_contador_dios", "sp_cryptobro", "sp_demonio_arca", "sp_influencer",
        "sp_lizard", "sp_zombie_ceo",
    ]

    @Test("los 18 retratos: 512², con alfa, mudos y en el bundle")
    func theEighteenPortraits() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(manifest.schemaVersion == 1)
        #expect(Set(manifest.portraits.keys) == Self.portraits)
        for (id, entry) in manifest.portraits {
            #expect(entry.file == "loop_\(id).mov", "\(id): el prefijo evita que Xcode pise archivos al aplanar")
            #expect(entry.width == 512 && entry.height == 512, "\(id)")
            #expect(entry.alpha && !entry.audio, "\(id): un retrato va con alfa y sin sonido")
            #expect(manifest.portraitURL(for: id) != nil, "\(id): está en el manifest pero no en el bundle")
        }
    }

    @Test("cada retrato de especial es de un especial que existe")
    func specialPortraitsBelongToSpecials() throws {
        let specials = Set(try GameContentLoader.load(from: .main).specials.specials.map(\.id))
        let manifest = try LoopsManifest.load(from: .main)
        for id in manifest.portraits.keys where id.hasPrefix("sp_") {
            #expect(specials.contains(id), "\(id): un loop que nadie pide")
        }
    }

    @Test("las tres cinemáticas: 720×1280, opacas, con sonido y en el bundle")
    func theThreeCinematics() throws {
        let manifest = try LoopsManifest.load(from: .main)
        for id in CinematicID.allCases {
            let entry = try #require(manifest.cinematics[id.rawValue], "\(id.rawValue)")
            #expect(entry.file == "cine_\(id.rawValue).mov")
            #expect(entry.width == 720 && entry.height == 1280)
            #expect(!entry.alpha && entry.audio)
            #expect(manifest.cinematicURL(for: id) != nil)
        }
    }

    @Test("sin entrada no hay video: se cae a la foto quieta")
    func noEntryNoVideo() throws {
        let manifest = try LoopsManifest.load(from: .main)
        #expect(manifest.portraitURL(for: "npc_que_no_existe") == nil)
        let empty = LoopsManifest(schemaVersion: 1, portraits: [:], cinematics: [:])
        #expect(empty.cinematicURL(for: .dios) == nil)
    }
}
```

- [ ] **Step 2: La implementación** (`FisuEvolution/Managers/LoopsManifest.swift`):

```swift
import Foundation

/// Las tres cinemáticas de Higgsfield (PLAN-v2 E8), por el id con el que las
/// registra `video_assets.py`.
enum CinematicID: String, CaseIterable, Sendable {
    case reencarnacion
    case arresto
    case dios

    /// Cuántas veces por cuenta; `nil` = cada vez.
    var maxPlays: Int? {
        switch self {
        case .reencarnacion: nil
        case .arresto: 2
        case .dios: 1
        }
    }
}

/// `loops_manifest.json`: los loops de retrato y las cinemáticas. Lo escribe
/// `video_assets.py`; acá sólo se lee. Una pieza sin entrada no se reproduce:
/// el retrato cae a la foto quieta y la cinemática no pide turno.
struct LoopsManifest: Decodable, Sendable, Equatable {
    struct Entry: Decodable, Sendable, Equatable {
        let file: String
        let width: Int
        let height: Int
        let alpha: Bool
        let audio: Bool
    }

    let schemaVersion: Int
    let portraits: [String: Entry]
    let cinematics: [String: Entry]

    static func load(from bundle: Bundle) throws -> LoopsManifest {
        guard let url = bundle.url(forResource: "loops_manifest", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(LoopsManifest.self, from: Data(contentsOf: url))
    }

    /// El del bundle, leído una vez. Sin archivo o roto, vacío: ningún flujo
    /// depende de que haya videos.
    static let main: LoopsManifest = (try? load(from: .main))
        ?? LoopsManifest(schemaVersion: 1, portraits: [:], cinematics: [:])

    func portraitURL(for visitorId: String, in bundle: Bundle = .main) -> URL? {
        portraits[visitorId].flatMap { Self.url(of: $0, in: bundle) }
    }

    func cinematicURL(for id: CinematicID, in bundle: Bundle = .main) -> URL? {
        cinematics[id.rawValue].flatMap { Self.url(of: $0, in: bundle) }
    }

    /// Xcode aplana los recursos en la raíz del bundle: se busca por nombre.
    private static func url(of entry: Entry, in bundle: Bundle) -> URL? {
        let file = entry.file as NSString
        return bundle.url(forResource: file.deletingPathExtension, withExtension: file.pathExtension)
    }
}
```

- [ ] **Step 3:** oráculo VERDE (la salida nombra las 4). Commit:
  `feat(video): el manifest de los loops del lado del juego, pineado`.

---

### Task 5: Un solo video a la vez y el retrato en loop

**Objetivo:** `VideoSlot` es el "un solo `AVPlayer` activo a la vez" de PLAN-v2 E8: el que pide
el turno pausa al que lo tenía. `LoopingPortraitView` es el retrato de E4 (la API de E4b T3) que se
anota en el slot; sin loop, con Reduce Motion o con la reproducción automática de video apagada
(Accesibilidad), la foto quieta. El cofre no entra al slot (no se toca; nunca convive con otro
video porque es un ítem de la cola, igual que la cinemática y el especial).

**Files:**
- Create: `FisuEvolution/UI/Art/VideoSlot.swift`
- Create: `FisuEvolution/UI/Art/LoopingPortraitView.swift`
- Create: `FisuEvolutionTests/VideoSlotTests.swift`

**Oráculo:** `Tools/v2/oraculo.sh tarea VideoSlotTests`
**Revisión:** sonnet · **Modelo:** sonnet.

- [ ] **Step 1: El test, en rojo** (`xcodegen generate`):

```swift
import Testing
@testable import FisuEvolution

@Suite("Un solo video a la vez")
@MainActor
struct VideoSlotTests {
    final class Owner {}

    @Test("el que pide el turno pausa al que lo tenía")
    func claimingPausesTheHolder() {
        let slot = VideoSlot()
        let a = Owner(), b = Owner()
        var paused: [String] = []
        slot.claim(a) { paused.append("a") }
        slot.claim(b) { paused.append("b") }
        #expect(paused == ["a"])
        #expect(slot.isHeld(by: b))
    }

    @Test("soltar sólo libera al que lo tiene; volver a pedirlo no se pausa a sí mismo")
    func releaseIsOwnerScoped() {
        let slot = VideoSlot()
        let a = Owner(), b = Owner()
        var paused = 0
        slot.claim(a) { paused += 1 }
        slot.claim(a) { paused += 1 }
        #expect(paused == 0)
        slot.claim(b) {}
        slot.release(a)
        #expect(slot.isHeld(by: b), "el viejo no suelta el turno del nuevo")
        slot.release(b)
        #expect(!slot.isHeld(by: b))
    }
}
```

- [ ] **Step 2: `VideoSlot.swift`:**

```swift
/// Un solo video sonando a la vez (PLAN-v2 E8): el que pide el turno pausa al
/// que lo tenía. Lo usan el retrato en loop y la cinemática; el cofre no (es un
/// ítem de la cola: nunca convive con otro video).
@MainActor
final class VideoSlot {
    static let shared = VideoSlot()

    private var holder: ObjectIdentifier?
    private var pauseHolder: (() -> Void)?

    func claim(_ owner: AnyObject, pause: @escaping () -> Void) {
        let id = ObjectIdentifier(owner)
        if holder != id { pauseHolder?() }
        holder = id
        pauseHolder = pause
    }

    func release(_ owner: AnyObject) {
        guard holder == ObjectIdentifier(owner) else { return }
        holder = nil
        pauseHolder = nil
    }

    func isHeld(by owner: AnyObject) -> Bool { holder == ObjectIdentifier(owner) }
}
```

- [ ] **Step 3: `LoopingPortraitView.swift`** (la de E4b T3 con el slot y la vista no opaca):

```swift
import AVFoundation
import SwiftUI
import UIKit

/// El retrato animado (PLAN-v2 E4/E8): su loop HEVC con alfa, mudo, mientras la
/// vista está en pantalla. Sin loop, con Reduce Motion o sin reproducción
/// automática de video (Accesibilidad), la foto quieta.
///
/// Va aparte de `ChestCinematicPlayer` a propósito: el cofre tiene su preroll y
/// su congelón en el último cuadro (HANDOFF §7), y un loop no tiene ninguno.
struct LoopingPortraitView<Fallback: View>: View {
    let url: URL?
    @ViewBuilder let fallback: () -> Fallback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let url, !reduceMotion, UIAccessibility.isVideoAutoplayEnabled {
            LoopPlayerView(url: url)
                .accessibilityHidden(true)
        } else {
            fallback()
        }
    }
}

private struct LoopPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopPlayerUIView { LoopPlayerUIView(url: url) }

    func updateUIView(_ uiView: LoopPlayerUIView, context: Context) {}

    static func dismantleUIView(_ uiView: LoopPlayerUIView, coordinator: ()) { uiView.stop() }
}

/// `AVPlayerLooper` repite sin costura: el primer cuadro y el último son el mismo.
/// ⚠️ `isOpaque = false`, como `ChestCinematicView`: con `true` el alfa sale negro.
final class LoopPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        (layer as? AVPlayerLayer)?.player = player
        (layer as? AVPlayerLayer)?.videoGravity = .resizeAspect
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        VideoSlot.shared.claim(self) { [weak self] in self?.player.pause() }
        player.play()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("LoopPlayerUIView is never decoded") }

    func stop() {
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        VideoSlot.shared.release(self)
    }
}
```

- [ ] **Step 4:** oráculo VERDE. Commit: `feat(video): un solo video a la vez y el retrato en loop`.

---

### Task 6: El especial que te cayó, animado

**Objetivo:** `SpecialDropView` (el drop y el recap) muestra el loop del especial en el plato de
168 pt; la canónica quieta queda de respaldo y la estrella, de respaldo del respaldo. Es el primer
lugar del juego donde se ve un retrato vivo (el popup del visitante llega con E4b T3).

**Files:**
- Modify: `FisuEvolution/UI/Popups/SpecialDropView.swift`

**Oráculo:** `Tools/v2/oraculo.sh tarea LoopsManifestTests` (compila la vista) + captura del
simulador con el panel de debug ("special" → `debugDropFirstSpecial()`): el retrato se mueve, el
plato no cambia de tamaño, el fondo amarillo se ve a través del alfa (no un cuadrado negro).
**Revisión:** ninguna (el controlador mira la captura) · **Modelo:** sonnet.

- [ ] **Step 1:** `portrait` pasa a envolver lo de hoy:

```swift
    @ViewBuilder private var portrait: some View {
        LoopingPortraitView(url: LoopsManifest.main.portraitURL(for: special.id)) {
            stillPortrait
        }
        .frame(width: Self.portraitSide, height: Self.portraitSide)
        .background(Color("PaletteYellow").opacity(0.3))
        .clipShape(Self.plateShape)
        .overlay(Self.plateShape.strokeBorder(Color("PaletteBrown").opacity(0.7), lineWidth: 2))
        .accessibilityHidden(true)
    }

    /// La skin del personaje especial, por el mismo camino que la dibuja el
    /// tablero; sin arte, la estrella de "sorpresa" de siempre.
    @ViewBuilder private var stillPortrait: some View {
        if let asset = gameState.content?.manifest.characters[special.id],
           let image = UIArt.characterImage(atlas: asset.atlas, key: asset.key) {
            image.resizable().scaledToFit().padding(Tokens.s8)
        } else {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(Color("PaletteYellow"))
        }
    }
```

  El docstring del struct suma una línea: "con su loop, si lo tiene (`loops_manifest.json`)".
- [ ] **Step 2:** oráculo + captura (SE y 16 Pro). Commit:
  `feat(especiales): el especial que te cayó se mueve`.

---

### Task 7: `seenCinematics` en `meta.engagement` (revisión opus)

**Objetivo:** cuántas veces vio la cuenta cada cinemática, en el save, sin subir el schema: un
save sin la clave decodifica a `[:]`, y entre dispositivos gana el **máximo por id** (idempotente:
el resolver corre en cada sync).

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EngagementState.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/SeenCinematicsTests.swift`

**Oráculo:** `Tools/v2/oraculo.sh tarea SaveMigratorTests PersistenceTests` (EK entero + build +
los dos que leen saves reales). Receta R para EK:
`swift test --package-path Packages/EconomyKit --filter "SeenCinematicsTests"`.
**Revisión:** **opus** (save) · **Modelo:** sonnet.

- [ ] **Step 1: El test, en rojo:**

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Las cinemáticas vistas, en el save")
struct SeenCinematicsTests {
    @Test("un save de antes, sin la clave, decodifica vacío")
    func missingKeyDecodesEmpty() throws {
        let decoded = try JSONDecoder().decode(EngagementState.self, from: Data("{}".utf8))
        #expect(decoded.seenCinematics.isEmpty)
        #expect(decoded == .initial)
    }

    @Test("anotar suma y sobrevive la ida y vuelta")
    func recordRoundTrips() throws {
        var state = EngagementState.initial
        state.recordCinematic("arresto")
        state.recordCinematic("arresto")
        state.recordCinematic("dios")
        let back = try JSONDecoder().decode(EngagementState.self, from: JSONEncoder().encode(state))
        #expect(back.seenCinematics == ["arresto": 2, "dios": 1])
    }

    @Test("entre dispositivos gana el máximo por id, en los dos sentidos")
    func resolveTakesTheMaxPerId() {
        let a = EngagementState(seenCinematics: ["arresto": 2, "reencarnacion": 1])
        let b = EngagementState(seenCinematics: ["arresto": 1, "dios": 1])
        let expected = ["arresto": 2, "reencarnacion": 1, "dios": 1]
        #expect(EngagementState.resolve(winner: a, loser: b).seenCinematics == expected)
        #expect(EngagementState.resolve(winner: b, loser: a).seenCinematics == expected)
        let twice = EngagementState.resolve(winner: EngagementState.resolve(winner: a, loser: b), loser: b)
        #expect(twice.seenCinematics == expected, "idempotente: el resolver corre en cada sync")
    }

    @Test("el resolver del save la respeta")
    func saveResolverKeepsIt() {
        var winner = fxSave(lifetime: 100, lastSeen: 1)
        var loser = fxSave(lifetime: 10, lastSeen: 2)
        loser.meta.engagement.recordCinematic("dios")
        winner.meta.engagement.recordCinematic("arresto")
        let resolved = SaveConflictResolver.resolve(local: winner, remote: loser)
        #expect(resolved.meta.engagement.seenCinematics == ["arresto": 1, "dios": 1])
    }
}
```

  (`fxSave` es un método `private` de `SaveConflictResolverTests`: se copia su armado como helper
  privado de esta suite, sin tocar aquélla.)

- [ ] **Step 2: La implementación:**

```swift
public struct EngagementState: Codable, Sendable, Equatable {
    public static let initial = EngagementState()

    /// Cuántas veces vio la cuenta cada cinemática (PLAN-v2 E8), por su id
    /// (`reencarnacion`, `arresto`, `dios`). Es de la cuenta: reencarnar no la
    /// toca. La app decide cuántas veces se muestra cada una.
    public var seenCinematics: [String: Int]

    public init(seenCinematics: [String: Int] = [:]) {
        self.seenCinematics = seenCinematics
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seenCinematics = try container.decodeIfPresent([String: Int].self, forKey: .seenCinematics) ?? [:]
    }

    public mutating func recordCinematic(_ id: String) {
        seenCinematics[id, default: 0] += 1
    }

    /// Lo visto no se des-ve: el máximo por id. Un `+` contaría dos veces la misma
    /// función en cada sync.
    public static func resolve(winner: EngagementState, loser: EngagementState) -> EngagementState {
        var resolved = winner
        resolved.seenCinematics.merge(loser.seenCinematics, uniquingKeysWith: max)
        return resolved
    }
}
```

  El docstring del struct ("Nace vacío", "Crece campo a campo…") se conserva.
- [ ] **Step 3:** oráculo VERDE (EK nombra `SeenCinematicsTests` y sigue verde
  `engagementResolvesThroughItsOwnRule`). Commit:
  `feat(save): las cinemáticas vistas viven en meta.engagement`.

---

### Task 8: El turno de la cinemática (revisión opus)

**Objetivo:** la cinemática es un ítem de la cola. `CelebrationKind.cinematic` (prioridad **2**:
antes que el tablero, así el arresto se ve antes de que el empleado se vaya; la de Dios, como se
pide DURANTE el reveal, sale después de él), con tope de **12 s** (5 s de video + la espera de la
hoja + margen). El payload es `GameState.cinematic`; las tres salidas pasan por `releasePayload`,
que anota `seenCinematics` y guarda. Apaga el HUD como el cofre. No corre bajo XCTest ni
`--uitest*` salvo que se pida.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/CelebrationQueue.swift` (tibio)
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/CelebrationQueueTests.swift`
- Modify: `FisuEvolution/Game/State/GameState.swift` 🔥 (dos propiedades)
- Create: `FisuEvolution/Game/State/GameState+Cinematics.swift`
- Modify: `FisuEvolution/Game/State/GameState+Celebrations.swift`
- Modify: `FisuEvolution/Game/State/GameState+Debug.swift` (`applyLaunchArgumentDefaults`, `debugPlayCinematic`)
- Modify: `FisuEvolution/Game/State/GameState+Bootstrap.swift` (fixture `--uitest-cinematic=<id>`, dentro del `#if DEBUG` de las otras)
- Create: `FisuEvolutionTests/CinematicWiringTests.swift`
- Modify: `FisuEvolutionTests/CelebrationWiringTests.swift` (el `switch` de `assertPayloadExists`)

**Oráculo:** `Tools/v2/oraculo.sh tarea CinematicWiringTests CelebrationWiringTests
GameLoopWiringTests ChestSourcesTests`
**Revisión:** **opus** (escribe `meta` y toca el árbitro de todas las celebraciones) · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo.** `CelebrationQueueTests`:

```swift
    @Test("la cinemática pasa antes que el tablero y espera al que está en pantalla")
    func cinematicOutranksTheBoard() {
        var queue = CelebrationQueue()
        queue.enqueue(.boardCelebration)       // el reveal de Dios ya está en pantalla
        queue.enqueue(.towerNotice)
        queue.enqueue(.cinematic)
        #expect(queue.current == .boardCelebration, "no corta el reveal que se está viendo")
        queue.finish(.boardCelebration)
        #expect(queue.current == .cinematic)
        queue.enqueue(.boardCelebration)       // la salida del arrestado, detrás
        queue.finish(.cinematic)
        #expect(queue.current == .boardCelebration)
    }

    @Test("la cinemática tiene tope: un video que no avisa no congela la cola")
    func cinematicHasAWatchdog() {
        #expect(CelebrationKind.cinematic.timeout == 12)
        var queue = CelebrationQueue()
        queue.enqueue(.cinematic)
        #expect(queue.tick(12) == .cinematic)
        #expect(queue.current == nil)
    }
```

  `FisuEvolutionTests/CinematicWiringTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("El turno de la cinemática")
@MainActor
struct CinematicWiringTests {
    private func world() async -> GameState {
        let gameState = await makeGameState()
        gameState.cinematicsAutorun = true
        return gameState
    }

    @Test("bajo XCTest no corre sola")
    func offUnderTests() async {
        let gameState = await makeGameState()
        #expect(!gameState.cinematicsAutorun)
        #expect(!gameState.playCinematicIfDue(.dios))
        #expect(gameState.showing == nil)
    }

    @Test("pide turno, apaga el HUD y al cerrar se anota vista")
    func takesTheTurnAndRecords() async throws {
        let gameState = await world()
        #expect(gameState.playCinematicIfDue(.reencarnacion))
        #expect(gameState.showing == .cinematic)
        #expect(gameState.cinematic == .reencarnacion)
        #expect(gameState.celebrationHidesUI)
        #expect(!gameState.isCalmMoment)
        gameState.celebrationFinished(.cinematic)
        #expect(gameState.cinematic == nil)
        #expect(gameState.showing == nil)
        #expect(!gameState.celebrationHidesUI)
        #expect(gameState.player?.meta.engagement.seenCinematics["reencarnacion"] == 1)
    }

    @Test("Dios una vez, el arresto dos, la reencarnación siempre")
    func playLimits() async {
        let gameState = await world()
        for (id, plays) in [(CinematicID.dios, 1), (.arresto, 2), (.reencarnacion, 5)] {
            for _ in 0..<plays {
                #expect(gameState.playCinematicIfDue(id), "\(id.rawValue)")
                gameState.celebrationFinished(.cinematic)
            }
        }
        #expect(!gameState.playCinematicIfDue(.dios))
        #expect(!gameState.playCinematicIfDue(.arresto))
        #expect(gameState.playCinematicIfDue(.reencarnacion))
    }

    @Test("el watchdog también la cuenta vista")
    func watchdogRecords() async {
        let gameState = await world()
        #expect(gameState.playCinematicIfDue(.dios))
        gameState.advanceCelebrations(delta: 12.5)
        #expect(gameState.showing == nil)
        #expect(gameState.player?.meta.engagement.seenCinematics["dios"] == 1)
    }

    @Test("una segunda pedida mientras otra espera se descarta, no se pisa")
    func oneAtATime() async {
        let gameState = await world()
        #expect(gameState.playCinematicIfDue(.arresto))
        #expect(!gameState.playCinematicIfDue(.reencarnacion))
        #expect(gameState.cinematic == .arresto)
    }

    @Test("godTier es el tier tope del contenido")
    func godTierIsTheTop() async throws {
        let gameState = await makeGameState()
        #expect(gameState.godTier == gameState.content?.tiers.maxTier)
    }
}
```

  `CelebrationWiringTests.assertPayloadExists`: `case .cinematic: #expect(gameState.cinematic != nil)`.

- [ ] **Step 2: EK.** `CelebrationKind`: `case cinematic` con su docstring ("Una cinemática de
  Higgsfield —reencarnación, arresto, Dios— a pantalla completa. Pide turno como cualquier
  celebración: así no pisa el reveal y la tarjeta de Dios espera a que termine"); `priority`:
  `case .careerChoice, .cinematic: 2`; `timeout`: `case .cinematic: 12` (con la línea "5 s de
  video, la hoja que se va y margen"). El docstring del enum: "Quedan afuera … y la reencarnación,
  que sale de un botón" pasa a "…: ésas no compiten por atención. La reencarnación sí entra, por su
  cinemática". `isSkippable` no se toca (sigue derivado: E9a T1 lo vuelve explícito, carry).

- [ ] **Step 3: `GameState.swift` 🔥** (dos propiedades, junto a `chestReward` y a
  `tutorialLessonsAutorun`):

```swift
    /// La cinemática que pidió turno (E8b). La suelta `releasePayload`, que la anota vista.
    var cinematic: CinematicID?

    /// Bajo XCTest y `--uitest*` las cinemáticas no corren solas (patrón
    /// `tutorialLessonsAutorun`): una de 5 s en medio de un test ajeno le tapa la pantalla.
    @ObservationIgnored var cinematicsAutorun =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
```

- [ ] **Step 4: `GameState+Cinematics.swift`:**

```swift
import EconomyKit
import Foundation

/// Cuándo se reproduce una cinemática (PLAN-v2 E8): la de reencarnación cada vez,
/// la del arresto las dos primeras, la de Dios una por cuenta. El turno lo da la
/// cola (`CelebrationKind.cinematic`); acá sólo se pide y se anota.
extension GameState {
    /// El tier de Dios: el tope del contenido. Es también el `godTier` que pide
    /// `RankingStateHost` (E12).
    var godTier: Int? { content?.tiers.maxTier }

    func timesSeen(_ id: CinematicID) -> Int {
        player?.meta.engagement.seenCinematics[id.rawValue] ?? 0
    }

    func isCinematicDue(_ id: CinematicID) -> Bool {
        guard cinematicsAutorun, LoopsManifest.main.cinematicURL(for: id) != nil else { return false }
        return id.maxPlays.map { timesSeen(id) < $0 } ?? true
    }

    /// Pide el turno si le toca. Una sola a la vez: la que llega mientras otra
    /// espera se descarta (no hay dos momentos así en el mismo segundo).
    @discardableResult
    func playCinematicIfDue(_ id: CinematicID) -> Bool {
        guard cinematic == nil, isCinematicDue(id) else { return false }
        cinematic = id
        syncCelebrations()
        return true
    }

    /// La llama `releasePayload(.cinematic)`: el fin del video, "Saltar" y el
    /// watchdog cuentan igual — la pantalla ya fue suya.
    func recordCinematicSeen() {
        guard let id = cinematic else { return }
        cinematic = nil
        guard var player else { return }
        player.meta.engagement.recordCinematic(id.rawValue)
        self.player = player
        scheduleSave()
    }
}
```

- [ ] **Step 5: `+Celebrations`.** `syncCelebrations`: `if cinematic != nil {
  celebrations.enqueue(.cinematic) }` (después del cofre). `releasePayload`: `case .cinematic:
  recordCinematicSeen()`. `publishCelebration`: `|| kind == .cinematic` en `hides`, con el
  comentario del cofre extendido ("El cofre y la cinemática apagan la UI SIEMPRE…").

- [ ] **Step 6: Debug.** En `applyLaunchArgumentDefaults`, después del bloque de las lecciones:

```swift
        // Las cinemáticas, lo mismo: bajo `--uitest*` no corren salvo que el test
        // las pida (`--uitest-cinematics` o `--uitest-cinematic=<id>`).
        if arguments.contains(where: { $0.hasPrefix("--uitest") }) {
            cinematicsAutorun = arguments.contains("--uitest-cinematics")
                || arguments.contains(where: { $0.hasPrefix("--uitest-cinematic=") })
        }
```

  `debugPlayCinematic(_ id: CinematicID)` (para el panel de la T9): pone `cinematic = id` y
  `syncCelebrations()` sin mirar `isCinematicDue` (el dueño quiere verlas todas las veces que
  quiera; igual se anotan al cerrar). En `+Bootstrap`, dentro del `#if DEBUG` de los fixtures:

```swift
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--uitest-cinematic=") }),
           let id = CinematicID(rawValue: String(argument.dropFirst("--uitest-cinematic=".count))) {
            debugPlayCinematic(id)
        }
```

- [ ] **Step 7:** `xcodegen generate`; oráculo VERDE. Commit:
  `feat(cinematicas): la cinemática pide turno en la cola y se anota vista`.

---

### Task 9: La cinemática en pantalla

**Objetivo:** con el turno de la cinemática, `RootView` muestra `CinematicOverlay`: negro a
pantalla completa, el video (relleno en iPhone, entero con franjas en iPad), su sonido al volumen
de **efectos**, la música abajo mientras dura, y un "Saltar" que aparece al segundo. El overlay se
come los toques (el tablero de abajo no los recibe, así un tap no la saltea por la cola). Sin
reproducción automática de video (Accesibilidad) o sin el archivo, se cierra en el acto (y cuenta
vista). Arranca 0,35 s después de aparecer: la hoja que la abrió (reencarnar, el popup del
visitante) termina de bajar.

**Files:**
- Create: `FisuEvolution/UI/Popups/CinematicOverlay.swift`
- Modify: `FisuEvolution/App/RootView.swift` 🔥
- Modify: `FisuEvolution/Audio/AudioManager.swift`, `FisuEvolutionTests/AudioManagerTests.swift`
- Modify: `FisuEvolution/UI/DebugPanelView.swift` (tres botones, en la sección de celebraciones)
- Create: `FisuEvolutionUITests/CinematicUITests.swift`
- Strings: `Tools/v2/claves-pendientes/e8b-t9.json` (4)

**Oráculo:** `Tools/v2/oraculo.sh tarea AudioManagerTests CinematicWiringTests
LocalizationCompletenessTests` + Receta R `-only-testing:FisuEvolutionUITests/CinematicUITests` +
captura en el SE y en el iPad de la de Dios a mitad de video.
**Revisión:** sonnet · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo.** `AudioManagerTests`:

```swift
    @Test("con la música bajada, el volumen efectivo es una fracción; al soltar, vuelve")
    func duckingLowersAndRestores() {
        let audio = AudioManager()
        audio.musicVolume = 0.8
        audio.setMusicDucked(true)
        #expect(abs(audio.effectiveMusicVolume - 0.8 * AudioManager.duckFactor) < 0.0001)
        audio.setMusicDucked(false)
        #expect(audio.effectiveMusicVolume == 0.8)
    }
```

  (seguir el `init` que ya usan los otros tests de esa suite.) `CinematicUITests`:

```swift
import XCTest

final class CinematicUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLaCinematicaTapaLaPantallaYSeSaltea() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-cinematic=dios"]
        app.launch()
        let video = app.otherElements["cinematic.player"]
        XCTAssertTrue(video.waitForExistence(timeout: 6))
        let skip = app.buttons["cinematic.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 4))
        skip.tap()
        XCTAssertTrue(video.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["hud.debug"].waitForExistence(timeout: 3), "el HUD vuelve")
    }

    func testSinTocarNadaTerminaSola() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-skip-tutorial", "--uitest-cinematic=arresto"]
        app.launch()
        let video = app.otherElements["cinematic.player"]
        XCTAssertTrue(video.waitForExistence(timeout: 6))
        XCTAssertTrue(video.waitForNonExistence(timeout: 12))
    }
}
```

  (`hud.debug` es el botón de debug de `RootView.swift:616`; se esconde con `celebrationHidesUI`,
  por eso sirve de "el HUD volvió".)

- [ ] **Step 2: `AudioManager`:**

```swift
    /// Cuánto queda la música mientras suena una cinemática: se oye, no compite.
    static let duckFactor: Float = 0.25
    private static let duckFade: TimeInterval = 0.4
    @ObservationIgnored private var musicDucked = false

    var effectiveMusicVolume: Float { Float(musicVolume) * (musicDucked ? Self.duckFactor : 1) }

    func setMusicDucked(_ ducked: Bool) {
        guard musicDucked != ducked else { return }
        musicDucked = ducked
        musicPlayer?.setVolume(effectiveMusicVolume, fadeDuration: Self.duckFade)
        if let lead = floorMusic.lead {
            floorPlayers[lead]?.setVolume(effectiveMusicVolume, fadeDuration: Self.duckFade)
        }
    }
```

  y los tres lugares que hoy ponen `Float(musicVolume)` en el tema que manda (`didSet` de
  `musicVolume`, `.restore`, `fadeIn`) pasan a `effectiveMusicVolume`.

- [ ] **Step 3: `CinematicOverlay.swift`:**

```swift
import AVFoundation
import SwiftUI
import UIKit

/// La cinemática a pantalla completa (PLAN-v2 E8): opaca, con su sonido al volumen
/// de efectos y la música abajo. Es el ítem `.cinematic` de la cola: cerrarla
/// (fin, "Saltar") es `celebrationFinished(.cinematic)`, que la anota vista.
///
/// No es un `sheet`, por lo mismo que el cofre: el arrastre de una hoja la
/// cortaría a la mitad. Y se come los toques: un tap no la saltea por la cola.
struct CinematicOverlay: View {
    @Environment(GameState.self) private var gameState
    @Environment(\.horizontalSizeClass) private var sizeClass
    let id: CinematicID

    @State private var cinematic: CinematicPlayer?
    @State private var canSkip = false
    @State private var finished = false

    /// La hoja que la abrió (reencarnar, el popup del visitante) termina de bajar.
    static let sheetSettle: Duration = .milliseconds(350)
    static let skipDelay: Duration = .seconds(1)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let cinematic {
                CinematicVideoView(player: cinematic.player, fills: sizeClass != .regular)
                    .ignoresSafeArea()
                    .accessibilityElement()
                    .accessibilityLabel(Text(LocalizedStringKey("cinematic.\(id.rawValue).a11y")))
                    .accessibilityIdentifier("cinematic.player")
            }
            if canSkip {
                Button(action: finish) {
                    Text("cinematic.skip")
                        .font(Tokens.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Tokens.s16)
                        .padding(.vertical, Tokens.s8)
                        .background(Capsule().fill(Color("PaletteInk").opacity(0.55)))
                }
                .accessibilityIdentifier("cinematic.skip")
                .padding(Tokens.s16)
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {}
        .task { await run() }
    }

    private func run() async {
        guard UIAccessibility.isVideoAutoplayEnabled,
              let url = LoopsManifest.main.cinematicURL(for: id)
        else { return finish() }
        let cinematic = CinematicPlayer(url: url)
        self.cinematic = cinematic
        VideoSlot.shared.claim(cinematic) { cinematic.player.pause() }
        gameState.audio?.setMusicDucked(true)
        try? await Task.sleep(for: Self.sheetSettle)
        await cinematic.prepare()
        guard !Task.isCancelled else { return }
        cinematic.play(volume: Float(gameState.audio?.sfxVolume ?? 1))
        Task {
            try? await Task.sleep(for: Self.skipDelay)
            withAnimation(.easeInOut(duration: 0.2)) { canSkip = true }
        }
        await cinematic.awaitEnd(timeout: 9)
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        cinematic?.stop()
        if let cinematic { VideoSlot.shared.release(cinematic) }
        gameState.audio?.setMusicDucked(false)
        gameState.celebrationFinished(.cinematic)
    }
}

/// Un `AVPlayer` local, sin buffering "inteligente" (archivo del bundle), que
/// termina pausado en su último cuadro.
@MainActor
final class CinematicPlayer {
    let player: AVPlayer

    init(url: URL) {
        player = AVPlayer(playerItem: AVPlayerItem(url: url))
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = false
    }

    /// Espera `readyToPlay` con un sondeo barato (KVO mete un closure `@Sendable`
    /// que no convive con AVPlayer bajo strict concurrency; mismo criterio que el
    /// cofre) y prerrolea. Con tope: un item que nunca está listo no cuelga nada.
    func prepare() async {
        for _ in 0..<40 where player.currentItem?.status != .readyToPlay {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard player.currentItem?.status == .readyToPlay else { return }
        _ = await player.preroll(atRate: 1)
    }

    func play(volume: Float) {
        player.volume = volume
        player.playImmediately(atRate: 1)
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func awaitEnd(timeout: Double) async {
        guard let item = player.currentItem else { return }
        let ended = NotificationCenter.default.notifications(
            named: AVPlayerItem.didPlayToEndTimeNotification, object: item
        )
        let deadline = ContinuousClock.now + .seconds(timeout)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { for await _ in ended { break } }
            group.addTask { try? await Task.sleep(until: deadline) }
            await group.next()
            group.cancelAll()
        }
    }
}

/// ⚠️ `isOpaque = false` aunque el video sea opaco: la regla de `ChestCinematicView`
/// (con `true`, la pantalla entera en negro el 2026-09-06).
private struct CinematicVideoView: UIViewRepresentable {
    let player: AVPlayer
    let fills: Bool

    final class Container: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> Container {
        let view = Container()
        view.isOpaque = false
        view.backgroundColor = .clear
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: Container, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
        view.playerLayer.videoGravity = fills ? .resizeAspectFill : .resizeAspect
    }
}
```


- [ ] **Step 4: `RootView` 🔥**, en un `ZStack` propio al lado del del cofre (por la misma razón
  que él: la `.animation` del externo teñiría el resto):

```swift
            ZStack {
                if let cinematic = gameState.cinematic, gameState.showing == .cinematic {
                    CinematicOverlay(id: cinematic)
                        .id(cinematic)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: gameState.showing == .cinematic)
```

- [ ] **Step 5: Panel de debug.** Tres botones (`debug.cinematic.reencarnacion`, `.arresto`,
  `.dios`) que llaman `gameState.debugPlayCinematic(_:)` y cierran el panel, con el estilo de los
  de su sección. Texto literal sin catálogo, como el resto del panel.

- [ ] **Step 6: Claves** (`Tools/v2/claves-pendientes/e8b-t9.json`):

```json
{
  "cinematic.skip": {"es": "Saltar", "en": "Skip"},
  "cinematic.reencarnacion.a11y": {"es": "Reencarnación: el Fisura sube entre monedas de oro.", "en": "Reincarnation: the Hobo rises through a storm of gold coins."},
  "cinematic.arresto.a11y": {"es": "El comisario toca el silbato y labra el acta.", "en": "The police chief blows the whistle and writes up the ticket."},
  "cinematic.dios.a11y": {"es": "Se abren las puertas del cielo: Dios te recibe en su trono.", "en": "Heaven's gates open: God welcomes you from the throne."}
}
```

- [ ] **Step 7:** `xcodegen generate`; aplicar las claves en el worktree; oráculo + Receta R
  VERDES; capturas (SE: relleno sin franjas; iPad: entero con franjas negras; el "Saltar" no tapa
  el notch). Descartar el catálogo si no es dueña. Commit:
  `feat(cinematicas): la cinemática a pantalla completa, con su sonido y Saltar`.

---

### Task 10: Reencarnación y Dios (revisión opus)

**Objetivo:** los dos disparadores que ya existen en el juego. **Reencarnar** pide la suya al
confirmar, antes del cofre de la reencarnación (que queda pendiente en Regalos; si se abre
mientras la cinemática tiene el turno, espera detrás) y, cuando la cinemática va a sonar, el SFX de
prestigio no se dispara encima. **Dios** pide la suya en `markRevealed(tier: godTier)`, que la
escena llama al ARRANCAR el reveal: la cinemática queda pendiente detrás del reveal y toma el turno
en el acto al terminar, sin un solo momento calmo en el medio — así la tarjeta del nombre de
**E12 T14** (que sale con `isCalmMoment`) aparece recién al cerrar la cinemática, sin que E12 cambie
nada. Al arrancar, si la partida ya está en Dios y la cuenta no la vio (se cerró la app a mitad, o
un veterano que llega a la 2.0 parado en Dios), se pide igual.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Prestige.swift` (`confirmPrestige`)
- Modify: `FisuEvolution/Game/State/GameState+BoardChanges.swift` (`markRevealed`)
- Modify: `FisuEvolution/Game/State/GameState+Cinematics.swift` (`reconcileCinematics`)
- Modify: `FisuEvolution/Game/State/GameState+Bootstrap.swift` (la llamada, al final del arranque bueno)
- Create: `FisuEvolutionTests/CinematicTriggerTests.swift`

**Oráculo:** `Tools/v2/oraculo.sh tarea CinematicTriggerTests CinematicWiringTests
ChestSourcesTests PrestigePreviewTests BoardChangeWiringTests CelebrationWiringTests
GameLoopWiringTests`
**Revisión:** **opus** (el flujo de reencarnar y el arranque) · **Modelo:** sonnet.

- [ ] **Step 1: Los tests, en rojo:**

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

@Suite("Cuándo suena cada cinemática")
@MainActor
struct CinematicTriggerTests {
    private func world() async -> GameState {
        let gameState = await makeGameState()
        gameState.cinematicsAutorun = true
        return gameState
    }

    @Test("reencarnar la pide antes del cofre, que espera detrás")
    func reincarnationBeforeTheChest() async throws {
        let gameState = await world()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        gameState.confirmPrestige()
        #expect(gameState.showing == .cinematic)
        #expect(gameState.cinematic == .reencarnacion)
        #expect(gameState.player?.meta.prestigeChestsPending == 1, "el cofre se ganó igual")
        gameState.openChest()
        #expect(gameState.showing == .cinematic, "el cofre no la corta")
        gameState.celebrationFinished(.cinematic)
        #expect(gameState.showing == .chestOpening)
    }

    @Test("sin cinemáticas, reencarnar es lo de siempre")
    func reincarnationWithoutCinematics() async {
        let gameState = await makeGameState()
        gameState.giveEarningsForPrestigeTesting(oro: 3)
        gameState.confirmPrestige()
        #expect(gameState.showing == nil)
    }

    @Test("Dios: después del reveal, sin un momento calmo en el medio, y una sola vez")
    func godAfterTheRevealOnce() async throws {
        let gameState = await world()
        let god = try #require(gameState.godTier)
        gameState.debugSetMaxTier(god)
        gameState.celebrations.enqueue(.boardCelebration)       // el reveal en pantalla
        gameState.markRevealed(tier: god)
        #expect(gameState.showing == .boardCelebration)
        #expect(gameState.cinematic == .dios)
        gameState.celebrationFinished(.boardCelebration)
        #expect(gameState.showing == .cinematic, "toma el turno en el acto")
        #expect(!gameState.isCalmMoment, "la tarjeta de E12 todavía no")
        gameState.celebrationFinished(.cinematic)
        #expect(gameState.player?.meta.engagement.seenCinematics["dios"] == 1)

        // Otra run que vuelve a llegar a Dios: ya no.
        gameState.player?.run.revealedTier = god - 1
        gameState.markRevealed(tier: god)
        #expect(gameState.cinematic == nil)
    }

    @Test("un tier que no es el tope no la pide")
    func notGodNoCinematic() async throws {
        let gameState = await world()
        let god = try #require(gameState.godTier)
        gameState.markRevealed(tier: god - 1)
        #expect(gameState.cinematic == nil)
    }

    @Test("al arrancar parado en Dios sin haberla visto, se pide")
    func reconcileOnBoot() async throws {
        let gameState = await world()
        let god = try #require(gameState.godTier)
        gameState.player?.run.revealedTier = god
        gameState.reconcileCinematics()
        #expect(gameState.cinematic == .dios)
        gameState.celebrationFinished(.cinematic)
        gameState.reconcileCinematics()
        #expect(gameState.cinematic == nil)
    }
}
```

  (`run.revealedTier` es `public var`: el test lo escribe directo. Si `giveEarningsForPrestigeTesting(oro: 3)` no alcanza la pared del piso móvil en esta
  punta, copiar el armado de `ChestSourcesTests.prestigeResetsTheCounterAndKeepsPendingChests`.)

- [ ] **Step 2: La implementación.**
  - `confirmPrestige`, después de `self.player = player` y antes de `awardChest(minRarity:
    .epica)`:

```swift
        // La cinemática de la reencarnación va antes del cofre (PLAN-v2 E8), y trae
        // su propio sonido: el SFX de prestigio sólo suena si ella no.
        if !playCinematicIfDue(.reencarnacion) { audio?.play(.prestige) }
```

    y se borra el `audio?.play(.prestige)` de más abajo. El comentario del intersticial ("la cola
    de celebraciones puede tener su turno pedido") suma "—la cinemática, desde E8b—": con ella en
    pantalla `showInterstitialIfAppropriate` se niega (duda 7).
  - `markRevealed(tier:)`, después de `scheduleSave()`:

```swift
        if tier == godTier { playCinematicIfDue(.dios) }
```

  - `GameState+Cinematics.swift`:

```swift
    /// Al arrancar: una partida parada en Dios que la cuenta todavía no vio (la app
    /// se cerró a mitad, o un veterano que llega a la 2.0 en el tope).
    func reconcileCinematics() {
        guard let godTier, let player, player.run.revealedTier >= godTier else { return }
        playCinematicIfDue(.dios)
    }
```

  - `+Bootstrap`: `reconcileCinematics()` al final del arranque bueno, **después** de
    `beginTutorialPhase()` (si la fase está activa, la restricción la deja esperando, no se pierde).

- [ ] **Step 3:** oráculo VERDE (los de reencarnar de `ChestSourcesTests`,
  `PrestigePreviewTests` y `GameLoopWiringTests` siguen verdes porque bajo XCTest el autorun está
  apagado). Commit: `feat(cinematicas): reencarnar y llegar a Dios tienen su cinemática`.

---

### Task 11: El arresto

**Objetivo:** dejar ir al arrestado (`.release`, la opción que se lleva al empleado, de
`comisario_arresto` y de `arca_paraiso`) pide la cinemática del arresto **las dos primeras
veces**. Con prioridad 2, sale antes de que el tablero muestre la salida del empleado (prioridad
3), que es el orden del cuento: el comisario labra el acta, después se lo lleva.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Visitors.swift` (lo crea E4b T2: `chooseVisitOption`)
- Modify: `FisuEvolutionTests/CinematicTriggerTests.swift`

**Oráculo:** `Tools/v2/oraculo.sh tarea CinematicTriggerTests VisitorRuntimeTests`
**Revisión:** sonnet · **Modelo:** sonnet.

- [ ] **Step 1: El test, en rojo** (con el armado de `VisitorRuntimeTests`: su `world()` y su
  `arrive(_:_:)`, que esta tarea copia como privados o reusa si E4b los dejó en `Support/`):

```swift
    @Test("dejar ir al arrestado la pide las dos primeras veces, antes de la salida")
    func arrestTwiceBeforeTheDeparture() async throws {
        for vez in 1...3 {
            let gameState = await visitorWorld()
            gameState.cinematicsAutorun = true
            gameState.player?.meta.engagement.seenCinematics["arresto"] = vez - 1
            try arrive(gameState, "comisario_arresto")
            #expect(gameState.chooseVisitOption("release"))
            if vez <= 2 {
                #expect(gameState.showing == .cinematic, "vez \(vez)")
                gameState.celebrationFinished(.cinematic)
            } else {
                #expect(gameState.cinematic == nil, "la tercera ya no")
            }
            #expect(!gameState.pendingBoardChanges.isEmpty || gameState.showing == .boardCelebration,
                    "la salida sigue en su turno")
        }
    }

    @Test("pagar la fianza no la pide")
    func bailNoCinematic() async throws {
        let gameState = await visitorWorld()
        gameState.cinematicsAutorun = true
        try arrive(gameState, "comisario_arresto")
        #expect(gameState.chooseVisitOption("bail"))
        #expect(gameState.cinematic == nil)
    }
```

- [ ] **Step 2:** en `chooseVisitOption`, en la rama de `.accept, …, .release, …`, antes del
  `for change in checked.departures`:

```swift
            // El comisario labra el acta antes de llevárselo (PLAN-v2 E8): la cinemática
            // tiene más prioridad que la salida del tablero.
            if checked.kind == .release { playCinematicIfDue(.arresto) }
```

- [ ] **Step 3:** oráculo VERDE. Commit: `feat(cinematicas): el arresto tiene su cinemática las dos primeras veces`.

---

### Task 12: Cierre de E8b (controlador)

- [ ] **Step 1:** `Tools/v2/oraculo.sh completo` sobre la punta de `v2/e8-video` con `version-2`
  mergeada → VERDE, con `LoopsManifestTests`, `VideoSlotTests`, `CinematicWiringTests`,
  `CinematicTriggerTests`, `SeenCinematicsTests` y `CinematicUITests` en la salida, y el pipeline
  con `test_estan_los_18_retratos`.
- [ ] **Step 2: A mano, en un iPhone de verdad** (el HEVC con alfa se decodifica por hardware en
  el dispositivo y por software en el simulador: lo que se ve en el sim no es la vara): las tres
  cinemáticas desde el panel de debug (sonido con el volumen de efectos, la música abajo, Saltar);
  el especial animado; reencarnar de verdad (cinemática → Regalos con el cofre épico); Instruments
  "Allocations" con la de Dios: el pico de memoria anotado en la sesión.
- [ ] **Step 3: El peso.** El `.ipa` de Release contra el de la punta anterior (`du` de
  `Resources/Loops` + `Resources/Cinematics`, y el tamaño del `.app` de `release_build`): va a E8
  T10 (vara de los 60 MB).
- [ ] **Step 4: Docs.** `Docs/SESION-<fecha>-v2-e8b.md` (tabla por tarea con su commit y el porqué
  de cada default de abajo); `Docs/HANDOFF.md` §4 (E8b), §5 (cuándo suena cada cinemática;
  `seenCinematics` por cuenta; un solo video a la vez), §7 (trampas nuevas: "los masters de
  Higgsfield cambian de fondo entre tandas: medir antes de procesar"; "un retrato sobre blanco va
  por conectividad, nunca por `chromakey`"), §9. `tasks.md`: filas, carries y la fila Higgsfield de
  §5 E8 a ✅. `DUENO.md`: los ítems de "Videos de Higgsfield LISTOS" que esto cierra (retratos y
  cinemáticas; las puertas siguen de P-E13b). Journal y `LOCK`.

---

## Lo que E8b le deja a otras épicas

- **E4b T3** (el popup del visitante): `LoopsManifest`, `LoopsManifestTests`, `VideoSlot` y
  `LoopingPortraitView` **ya existen** (E8b T4, T5) con la API que su plan escribió: **no los
  crea**; los saca de su lista de Create, usa `LoopingPortraitView(url:
  LoopsManifest.main.portraitURL(for: visitor.id)) { … }` tal cual, y suma a `LoopsManifestTests`
  su test "cada retrato es de un visitante" (contra `visitors.visitors`, que llega con E4a T7).
- **E4b T8** (el Álbum): "tocar uno reabre su ficha" es `SpecialDropView` en modo recap: el retrato
  ya viene animado (E8b T6).
- **E12 T11**: `GameState.godTier` **ya existe** (E8b T8) con la firma de `RankingStateHost`: el
  conformance no lo vuelve a declarar. En `markRevealed` su línea (`ranking?.reachedGod()`) va al
  lado de la de E8b; el orden no importa.
- **E12 T14**: no cambia nada. La tarjeta sale con `isCalmMoment`, y `CinematicTriggerTests.
  godAfterTheRevealOnce` pinea que entre el reveal de Dios y el cierre de la cinemática no hay un
  momento calmo. Sus UI tests (`--uitest-ranking-god`) corren con las cinemáticas apagadas.
- **E9a T1** (el `isSkippable` explícito): `.cinematic` → `false` (la saltea su botón, no el tap
  del tablero; el overlay igual se come los toques). Es un kind más de la lista "último en
  `CelebrationQueue`".
- **E9b T7** (`ResetPlan`): `result.meta.engagement.seenCinematics = old.engagement.seenCinematics`
  (por cuenta: la Zona de peligro no vuelve a mostrar la de Dios; duda 8).
- **E3b T9 / E4a T3 / E5a T4 / E6a T1** (`EngagementState`): si E8b T7 entró antes, cada una suma
  su parámetro al `init(seenCinematics:)` y su línea al `init(from:)` y al `resolve`.
- **E7b-a T2** (los cortes naturales): `.cinematic` **sí** es corte (su duda 6 ya lo dice); con eso
  vuelve el intersticial de la reencarnación, que desde E8b T10 se niega mientras la cinemática
  tiene el turno (duda 7).
- **P-E13b** (las puertas de la cabina): `video_assets.py cinematica <id>` con key mide **las
  cuatro esquinas** (`CORNER_ROWS["cinematica"]`) y acepta verde o magenta; `CINEMATIC_IDS` y
  `validate_id` hay que extenderlos para sus ids (el pin de Python ya es "las tres están", no
  "son sólo tres"); el `CinematicID` de Swift es de las tres de la cola: las puertas no son un ítem
  de la cola y no van ahí.
- **E8 T10** (peso y memoria): suma los ≈ 8,5 MB de E8b T3 y el pico de memoria de E8b T12.
- **E10**: las capturas del App Store pueden mostrar la de Dios con `--uitest-cinematic=dios`.

## Para el dueño / dudas

Ninguna frena: la ejecución sigue con el default.

1. **¿Qué tanda de retratos?** `loops/` está sobre blanco (19:05) y la de croma quedó en
   `loops-croma-descartados/`, al revés de lo que dice `DUENO.md`. **Default:** la de blanco, por
   conectividad (T2); la T1 hace igual los dos ajustes de croma que pediste.
2. **Los masters se versionan** en `Tools/asset-pipeline/video/` (≈ 41 MB), como
   `chest-animation.mp4`: el pipeline se puede volver a correr desde el repo. **Default:** sí; si
   pesa, van a `.gitignore` y el docstring apunta a `automatic-image-generation`.
3. **El especial que te cayó pasa a mostrar su loop** (una cara que habla) en lugar de la skin
   entera, que es lo que pediste el 2026-08-21 para "apreciar a quién te ganaste". **Default:** el
   loop (los especiales de la 2.0 son visitantes y ése es su retrato); la foto entera queda de
   respaldo. Volver atrás es borrar el envoltorio de la T6.
4. **La de reencarnación suena cada vez** (4–6+ por partida, 5 s, salteable al segundo).
   **Default:** cada vez; PLAN-v2 sólo limita el arresto y Dios.
5. **El arresto suena al dejarlo ir** (`.release`), no al llegar el comisario ni al abrir su
   popup: así lo dejó acordado E4b. Quien paga la fianza no la ve nunca. **Default:** al dejarlo
   ir; cambiarlo a "al abrir el popup del arresto" es mover una línea de `chooseVisitOption` a
   `openVisitorPopup` y abrir el popup al cerrar la cinemática.
6. **Sin reproducción automática de video (Accesibilidad) la cinemática no se muestra y cuenta
   vista**; el retrato cae a la foto. **Default:** así (es lo que pide ese ajuste).
7. **El intersticial de la reencarnación se pierde** mientras la cinemática tiene el turno
   (`showInterstitialIfAppropriate` se niega con una celebración en pantalla) hasta que E7b-a T2
   lo vuelva un corte natural después de la cinemática. **Default:** se acepta ese hueco.
8. **El reset de la Zona de peligro conserva `seenCinematics`** ("una vez por cuenta"): un
   jugador que resetea para el ranking no vuelve a ver la de Dios. **Default:** se conserva
   (carry a E9b T7).
9. **iPad:** la cinemática 9:16 va entera con franjas negras (rellenar recortaría arriba y abajo);
   en iPhone, rellena. **Default:** así.
10. **La música baja al 25 % durante la cinemática**, no se corta. **Default:** así.
11. **El watchdog y "Saltar" cuentan como vista.** Una de Dios salteada al segundo no vuelve.
    **Default:** así (la pantalla ya fue suya; volver a mostrarla sería un castigo).

## Filas para `tasks.md`

Para reemplazar la fila "Higgsfield" de §5 E8 (queda ✅ con el cierre de E8b T12) y sumar una
sección "E8b — Cinemáticas y retratos animados (`2026-10-08-v2-e8b-cinematicas.md`)". La rama de la
épica, `v2/e8-video`, va a la tabla "Ramas de épica" de §1. En §3.1 suma: `GameState.swift` (E8b
T8), `RootView.swift` (E8b T9). En §3.2: `CelebrationQueue.swift` (E8b T8, antes de E9a T1),
`+Celebrations` (T8), `EngagementState.swift` (E8b T7, ver la regla 3 del paralelismo),
`+BoardChanges` (T10), `+Debug`/`+Bootstrap` (T8, T10), `DebugPanelView` (T9). En §4.2 #9, la
mitad "lado Swift de las cinemáticas" queda planificada. Carries a E4b T3, E4b T8, E12 T11, E9a T1,
E9b T7, E7b-a T2, P-E13b y E8 T10 (arriba).

| ID | Título | Estado | Depende de | 🔥 / tibios | Commit / rama | Nota |
|---|---|---|---|---|---|---|
| P-E8b | Plan de E8b: cinemáticas y retratos animados | ✅ | — | — | (el commit de este plan) | 12 tareas; `2026-10-08-v2-e8b-cinematicas.md`; 11 dudas con default; ⚠️ `loops/` hoy es blanco, no croma |
| E8b-T1 | `video_assets.py`: el retrato mide arriba y el key acepta magenta | ⏳ | — | video_assets.py, test_video_assets.py | | pipeline, no compila; los dos ajustes de `DUENO.md` |
| E8b-T2 | `video_assets.py`: retratos sobre blanco por conectividad | ⛔ | T1 | video_assets.py, test_video_assets.py | | pipeline; `whitebg_cutout` cuadro por cuadro a 512²; revisión sonnet |
| E8b-T3 | Los 18 retratos y las 3 cinemáticas, integrados y pesados | ⛔ | T2 | Resources/Loops, Resources/Cinematics, loops_manifest.json, masters | | pipeline (~25 min en background); hoja de contacto al controlador; estimado +8,5 MB de bundle, ≈ 41 MB de masters |
| E8b-T4 | `LoopsManifest`, `CinematicID` y `LoopsManifestTests` | ⛔ | T3 | — | | la API de E4b T3 (carry: E4b T3 no los crea) |
| E8b-T5 | `VideoSlot` y `LoopingPortraitView` | ⏳ | — | — | | archivos nuevos; ∥ T1–T4, T7 |
| E8b-T6 | El especial que te cayó, animado | ⛔ | T4, T5 | SpecialDropView | | revisión ninguna; captura SE/16 Pro (duda 3) |
| E8b-T7 | `seenCinematics` en `meta.engagement` | ⏳ | E1-T4 ✅ | EngagementState (EK) | | sonnet, **rev. opus** (save); antes de E3b T9 o al final de su cadena |
| E8b-T8 | El turno de la cinemática (`.cinematic`, payload, autorun) | ⛔ | T4, T7 | 🔥 GameState (dos propiedades); CelebrationQueue, +Celebrations, +Debug, +Bootstrap | | sonnet, **rev. opus**; ventana libre de GameState.swift; antes de E9a T1 |
| E8b-T9 | La cinemática en pantalla (overlay, sonido, Saltar) | ⛔ | T5, T8 | 🔥 RootView, catálogo (snapshot, 4 claves); AudioManager, DebugPanelView | | sonnet; `CinematicUITests` por Receta R; capturas SE + iPad |
| E8b-T10 | Reencarnación y Dios | ⛔ | T8, T9 | +Prestige, +BoardChanges, +Bootstrap | | sonnet, **rev. opus**; pinea el momento calmo que espera E12 T14; carry `godTier` a E12 T11 |
| E8b-T11 | El arresto | ⛔ | T10; E4b-T2 | +Visitors | | sonnet; al dejarlo ir (duda 5) |
| E8b-T12 | Cierre de E8b (controlador) | ⛔ | T1–T11 | `Docs/` | | `completo`; en un iPhone real (HEVC-alfa por hardware) y la memoria a E8 T10 |
