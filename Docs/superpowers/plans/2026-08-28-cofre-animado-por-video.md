# Plan: el cofre animado por video

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans
> (ejecución inline en esta sesión). Spec:
> `Docs/superpowers/specs/2026-08-28-cofre-animado-por-video-design.md` — las
> decisiones y los números calibrados viven ahí; este plan es el orden de
> ejecución.

**Goal:** la apertura de cofres reproduce los frames reales del video del
animador (sin pantalla verde), manteniendo la interactividad de 4 toques y el
design system intactos; el cofre nuevo reemplaza al viejo en todo el juego.

**Architecture:** pipeline Python (ffmpeg chromakey calibrado + PIL cuantizada)
→ `Resources/ChestAnim/` (frames + manifest JSON como contrato) → loader/feed
SwiftUI con TimelineView pausable y prefetch por ventana → cirugía mínima en
`ChestOpeningView`.

**Tech Stack:** ffmpeg 0x0BB427:0.11:0.04 + despill; PIL FASTOCTREE 256;
SwiftUI `TimelineView(.animation(paused:))`; `@Observable`; XcodeGen.

## Global Constraints

- Swift 6 strict concurrency, cero warnings (`SWIFT_TREAT_WARNINGS_AS_ERRORS`).
- Al agregar/borrar archivos Swift: `xcodegen generate` obligatorio.
- Cero strings nuevos; el xcstrings no se toca con scripts.
- Ningún reloj/display link incondicional; Reduce Motion deja estado FINAL.
- Commits en español, atómicos, staging selectivo (nada de `add -A`).
- Verificación con la matriz de dos runtimes de `Docs/HANDOFF.md` §6 (sims
  propios por UDID, unit antes que UI, borrarlos al final).
- Presupuesto de frames: ≤ 4 MB; medir y anotar el delta real del bundle.

---

### Task 0: limpiar el terreno

- [ ] Commitear el reformateo canónico del xcstrings que dejó flotando el
  primer build post-cofres (diff mecánico de Xcode; precedente `13def46`).
  Anotar para el dueño: Xcode detectó una clave `gifts.chest.count %@` stale
  (alguna vista formatea con String en vez de Int — revisar aparte).
- [ ] `git mv`… no aplica (está untracked): mover `chest-animation.mp4` →
  `Tools/asset-pipeline/video/chest-animation.mp4` y trackearlo.
- [ ] Commit docs: spec + este plan.

### Task 1: pipeline `chest_video_frames.py` + tests

**Files:** Create `Tools/asset-pipeline/scripts/chest_video_frames.py`,
`Tools/asset-pipeline/tests/test_chest_video_frames.py`.
**Produces:** `FisuEvolution/Resources/ChestAnim/chest_f{NNN:03d}.png` (~70),
`FisuEvolution/Resources/ChestAnim/chest_anim.json`, masters+integración de
`ui_chest_closed@{2x,3x}.png`.

- [ ] Constantes arriba: `KEY=0x0BB427, SIM=0.11, BLEND=0.04`; segmentos
  `idle=[0,0] shakeA=[7,26] shakeB=[33,47] burst=[49,82]`; crops
  `stage=(200,100,860,560) scale 1.0`, `burst=(0,0,1280,656) scale 0.8`;
  `CHEST_RECT=(431,257,407,363)`; ocupación objetivo del estático medida del
  PNG viejo antes de reemplazarlo (constante fijada en el script).
- [ ] Extracción: subprocess ffmpeg → PNGs RGBA temp (f0–f90, un solo pase).
- [ ] Por segmento: crop → resize LANCZOS si scale≠1 → `quantize(256,
  FASTOCTREE)` → save optimize. Chequeo de masa de alfa cortada por el crop
  (>0,7 % → warning con el número).
- [ ] Manifest `chest_anim.json` (schemaVersion 1, fps, canvas, chestRect,
  segments con first/last/crop/scale).
- [ ] Estático: f0 → bbox del cofre + aire hasta la ocupación objetivo,
  cuadrado, @3x 384 / @2x 256 → `FisuEvolution/Resources/ui.atlas/`.
- [ ] Tests: geometría pura + integridad de lo integrado (estilo
  `test_assets_integrados`). Correr `pytest Tools/asset-pipeline/tests/`.
- [ ] Ejecutar el pipeline de verdad; inspección visual de 4-6 frames (alfa y
  compuesto sobre oscuro); pesar el directorio. Commit (script + tests +
  frames + manifest + atlas).

### Task 2: `ChestAnimation.swift` + unit tests

**Files:** Create `FisuEvolution/UI/Popups/ChestAnimation.swift`, Test
`FisuEvolutionTests/ChestAnimationTests.swift`.
**Produces:** `struct ChestAnimation` con `static let shared:
ChestAnimation?`, `enum Segment: String { idle, shakeA, shakeB, burst }`,
`func frames(_ s: Segment) -> [URL]`, `func frameCount(_ s:) -> Int`,
`func stage(_ s: Segment, chestWidth: CGFloat) -> (size: CGSize, offset:
CGSize)` (tamaño en pt del lienzo del segmento y offset de su centro respecto
del centro del cofre), `var fps: Double`.

- [ ] Test primero: `load()` del bundle no es nil; los 4 segmentos presentes;
  cada URL referenciada existe; conteos exactos (1/20/15/34); `stage` del
  idle con chestWidth 210 da tamaño proporcional al crop y offset que deja el
  centro del cofre en (0,0) ± 0,5 pt; fps == 24.
- [ ] Implementación: Decodable + validación en `load()` (frames faltantes →
  nil, nunca crash). `xcodegen generate`. Correr la clase de tests. Commit.

### Task 3: `ChestAnimationFeed.swift` (el player)

**Files:** Create `FisuEvolution/UI/Popups/ChestAnimationFeed.swift`, tests en
`FisuEvolutionTests/ChestAnimationTests.swift` (misma clase).
**Produces:** `@MainActor @Observable final class ChestAnimationFeed` con
`init(animation: ChestAnimation?)`, `func show(_ s: Segment, frame: FramePin =
.first)` (estático), `func play(_ s: Segment, at date: Date)`,
`func index(at date: Date) -> Int` (clamp al rango), `func image(at index:
Int) -> UIImage?`, `func prefetch(around index: Int)`, `var isPaused: Bool`,
`var segment: Segment`. `enum FramePin { first, last }`.

- [ ] Tests de la parte pura (sin reloj real): `index(at:)` con fechas
  sintéticas (antes del inicio → 0; a mitad → el frame por fps; después del
  final → último y `isPaused == true`); `show(.idle)` → paused desde el
  arranque; `play` reinicia el índice.
- [ ] Implementación: caché LRU (~10) + `Task.detached` de decode con
  `preparingForDisplay()`, cancelación al cambiar de segmento, decode sync de
  rescate si el frame pedido no llegó. Correr tests. Commit.

### Task 4: cirugía en `ChestOpeningView`

**Files:** Modify `FisuEvolution/UI/Popups/ChestOpeningView.swift`.
**Consumes:** todo lo de Tasks 2–3.

- [ ] `chestArt` → `TimelineView(.animation(minimumInterval: 1.0/24, paused:
  feed.isPaused)) { Image(uiImage: feed.image(at: feed.index(at:
  $0.date))) }` con `stage()` para frame/offset; fallback al `art("ui_chest_closed")`
  si `ChestAnimation.shared == nil`. El `.onChange` del índice dispara
  `prefetch`.
- [ ] `choreograph`: `.forced1` → `play(.shakeA)`; `.forced2` →
  `play(.shakeB)`; `.forced3` → `play(.shakeA)`; `.bursting` →
  `play(.burst)`; `.arriving`/`.waiting` → `show(.idle)`. Reduce Motion: nunca
  `play` — `show(.idle)` antes del estallido, `show(.burst, frame: .last)`
  desde el estallido. Prefetch anticipado: shakeA tras `landed`, burst al
  entrar a `.forced2`.
- [ ] Retirar `ChestShake` (struct + modifier + `shakeDegrees`), `FlyingLid`
  (struct + `lid` + montaje), el switch de 3 PNG con su compensación.
  Conservar: `ChestDrop`, respiro, hinchado, stowed, rayos teñidos, flash,
  ráfagas, carta, hápticos, identifiers, `--uitest-chest-manual`.
- [ ] Verificar el welcome chest (`grantWelcomeChest`, «nace abierto») contra
  el mapeo de latidos.
- [ ] Build + `ChestOpeningUITests` en sim propio. Ajuste fino con capturas
  (tamaño del cofre vs. carta, timing del flash vs. f49–52, auto-avance de
  `.bursting`). Commit.

### Task 5: retiros y derivados

**Files:** Modify `FisuEvolution/Resources/Data/assets_manifest.json`, Delete
6 PNG de `FisuEvolution/Resources/ui.atlas/`.

- [ ] Sacar `ui_chest_cracked`, `ui_chest_open`, `ui_chest_lid` del manifest y
  borrar sus @2x/@3x del atlas (los llamadores murieron en Task 4; grep de
  confirmación primero).
- [ ] GiftsView (44 pt) y DailyRewardView (52 pt): sin cambios de código —
  verificar con captura que el cofre nuevo rinde bien a ese tamaño.
- [ ] Commit.

### Task 6: verificación de matriz + docs

- [ ] Releer `Docs/HANDOFF.md` §6 (receta vigente post-26.6). EconomyKit ·
  unit (26.5 + Store en 18.6) · UI completa (26.5 + StoreUITests en 18.6) ·
  smokes con captura de cada latido. Cero warnings. Borrar sims propios.
- [ ] Medir: peso de ChestAnim/ + delta del bundle; anotar.
- [ ] `Docs/SESION-2026-08-28-cofre-animado.md` + handoff efímero +
  actualización del general (§4 entrada, §9 mapa: ChestAnim; trampa nueva del
  keying limited-range si merece).
- [ ] Commit docs. **No pushear sin pedido del dueño.**
