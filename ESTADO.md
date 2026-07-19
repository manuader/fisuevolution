# ESTADO DEL PROYECTO — FisuEvolution (Hobo Evolution)

> Documento de handoff para continuar en otra sesión de Claude.
> Última actualización: 2026-07-19.

## Qué es

Merge-idle iOS con humor argentino: 30 tiers (El Fisura → Dios), tap/merge/pasivo/spawn/prestige, estilo **Cow Evolution** (personajes de figura completa parados sobre un campo con fondo, SIN grilla visible). Todo data-driven por JSON.

**Documentos rectores** (raíz del repo — leerlos antes de tocar nada):
- `FisuEvolution-plan.md` — el build bible (gameplay, data model, economía, cultura).
- `IOS-developing-skill.md` — estándares de código obligatorios.
- `Asset-generation.md` — pipeline de arte (parcialmente superado, ver "Saga del arte").
- **Plan aprobado**: `/Users/manuader/.claude/plans/lee-todos-los-archivos-splendid-quokka.md` (F0–F6 con fixes de críticos adversariales).
- `tasks.md` (raíz) — checklist vivo de tareas.

## Estado por fase

| Fase | Estado |
|---|---|
| F0 Scaffold | ✅ completa |
| F1 Economía (tap/spawn) | ✅ completa |
| F2 Loop (merge/pasivo/offline/prestige/carrera) + balance | ✅ completa, gate aprobado |
| F3 Arte | 🔶 pipeline listo; generación migrada a **API Gemini** (en curso) |
| F4 Monetización (StoreKit local + ads stub) | ✅ completa |
| F5 Pulido (contenido, game feel, campo, GC/CloudKit) | ✅ código completo; falta pass perf/VoiceOver final |
| F5.5 AdMob real | ⏸ esperando cuenta AdMob del usuario (o rama B sin ads) |
| F6 Ship | ⏸ esperando cuenta Apple Developer (USD 99); ship-prep ya hecho |

**121 tests en verde** (71 EconomyKit + 48 app + 2 UI). ~14 commits en `main` (sin remoto todavía).

## Arquitectura (decisiones clave)

- **XcodeGen** (`project.yml`) genera el `.xcodeproj` (no versionado). Regenerar: `xcodegen generate`. Si el Xcode del usuario abierto muestra "Missing package product": File → Packages → Reset Package Caches.
- **`Packages/EconomyKit`**: TODA la lógica pura (Codables, fórmulas, merge, tick, offline, prestige, modifiers, conflictos). Testeable con `swift test --package-path Packages/EconomyKit` sin simulador. El app target NUNCA duplica estos tipos.
- **`GameState`** (`FisuEvolution/Game/State/`): `@Observable @MainActor`, única fuente de verdad. `player: PlayerState` es `@ObservationIgnored` (el tick por frame NO invalida SwiftUI); la UI observa proyecciones (`coinsText`, `boardVersion`, `effectsVersion`, prompts) refrescadas en eventos discretos + flush 8 Hz por conteo de frames desde `BoardScene.update`.
- **Swift 6 strict concurrency + warnings-as-errors**. Convenciones en `Docs/concurrency-conventions.md` (nada de Timer para frame-work; CoreData en actor con modelo programático + blob JSON; MainActor.assumeIsolated para callbacks legacy).
- **Save**: `PlayerState` Codable **schema v3** (CoreData `SaveRecord` blob + snapshot JSON de respaldo). Migraciones encadenadas v1→v2→v3 en `SaveMigrator` (v2: `activeModifiers`; v3: `upgradeLevels`, `boostActivations`, `daily`, `sharesCompleted`, campos derivados en `UpgradeState`).
- **ActiveModifier**: sistema único de efectos temporales (rewarded/eventos/boosts) persistido en el save con expiry absoluto.
- **Derivación única de efectos**: `UpgradeManager.recomputeDerivedEffects` = f(niveles de upgrade, specials poseídos, shares, milanesa) → cachea en `UpgradeState`. Llamar tras CUALQUIER cambio de esas fuentes.
- **Campo (no grilla)**: `BoardScene` renderiza fondo por etapa (11 stages, colores fallback hasta el arte; umbrales en `stageThresholds`), anclas orgánicas (grilla lógica + jitter determinístico por hash de cellIndex — el modelo de celdas PERSISTE igual), deambulación idle, profundidad por Y, drop = ancla más cercana. `CharacterNode` tiene modo `hasRealArt` (figura completa sin placa) y sombra elíptica.
- **Manifest** (`Resources/Data/assets_manifest.json`): sin entrada → placeholder programático; con entrada → arte real. El swap de arte NUNCA toca código.
- **Audio**: 100% sintetizado por código (`Tools/audio-synth/generate_audio.py`, stdlib, determinístico, seeds fijas) → 10 SFX + 2 loops perfectos en `Resources/Audio/*.caf`. `AudioManager` degrada en silencio si falta un archivo.
- **Game Center/CloudKit**: codeados (`GameCenterManager`, `CloudSaveSync`, `SaveConflictResolver` — gana mayor lifetimeEarnings, unión de compras/drops, **clamp Int64 obligatorio**: `Int64(Double)` grande trapea) detrás de `feature_flags.json` apagados. F6 solo flipea.
- **Boosts review-safe**: `buildVariant` en feature_flags ("dev"/"store") elige los textos de `boosts.json.reviewSafe` (Guideline 2.3.1).

## Economía (números actuales, gate aprobado)

`economy.json`: yieldGrowth 3.8 · **spawn: baseCost 50, costGrowth 1.022, tierOffset 4, costBasis "total"** · offline cap 8h/0.5.
- **Spawn progresivo** (extensión aprobada al bible §2.3.4): el shop ofrece tier `max(1, maxTier−4)` — sin esto God requiere 2^29 unidades.
- **costBasis "total"** (exponente = spawns totales): el "perType" del bible colapsaba todo el pacing en una pared única. Curva actual validada con `Tools/balance-sim` (check duro de alcanzabilidad): primer merge 16s, carrera ~2min, T21 24min, prestige ~7.8h activas. Historia completa en `Docs/balance-log.md`.
- `tiers.json` (37 entradas: 8 + nodo junior + 4 jr + 4 sr + 20; SIN "senior" genérico) se genera con `Tools/generate-tiers` — nunca editar números a mano (test anti-drift).

## Saga del arte (LEER antes de tocar generación)

1. SD 1.5 local (ComfyUI, M1): **inutilizable** — anatomía incoherente. 25 imgs de evidencia en `Tools/asset-pipeline/state/prompt-search/`.
2. SDXL (DreamShaper XL Turbo, descargado, 7GB): **nunca llegó a probarse** (matriz abortada con 0 imágenes cuando el usuario decidió migrar). OJO: las imgs "buenas" hoboevo_00026-28 eran SD1.5 — no atribuirlas a SDXL. Matriz SDXL lista como fallback (~40 min): ver `state/sdxl-search/ABORTED.txt`.
3. **DECISIÓN VIGENTE: API Gemini (nano banana, `gemini-2.5-flash-image`)** — pedido explícito del usuario por calidad. Key en `Tools/asset-pipeline/.secrets/gemini.key` (gitignored). Cliente: `scripts/gemini_batch.py` (stdlib puro; `--test` 4 muestras / `--tanda N` / `--asset X`; usa `heroes/approved/*.png` como referencias de estilo para consistencia).
4. **Flujo**: generar sobre fondo blanco → `rembg` (isnet-general-use) recorta a **PNG transparente** (requisito del usuario: integración con el ambiente) → QA con `scripts/style_score.py` (scorer v2: CLIP anti-foto/sketch/duo, single-blob, paleta, edge_touch) → `organize_atlases.py` exporta @2x/@3x a atlas lowercase → `update_manifest.py` (con `--verify`).
5. **Dirección de arte**: figura COMPLETA de pie (pies apoyados, manos visibles, pose idle con personalidad — 46 poses únicas en `scripts/cultural_dict.py`); backgrounds = playfield (tercio inferior transitable despejado). Prompts: `prompts/prompts.json` (93 assets, seeds deterministas).
6. El humano ya NO es gate: el juez estético es Claude MIRANDO las imágenes (tiene visión — usar Read sobre los PNG) + scorer automático.
7. ComfyUI local queda instalado (~13GB) apagado. Relanzar: `cd Tools/asset-pipeline/ComfyUI && ../.venv/bin/python main.py --force-fp16 --use-split-cross-attention`.
8. **En vuelo al escribir esto**: `gemini_batch.py --test` corriendo (4 muestras → `state/gemini-test/`), pendiente de review visual.

## Problemas resueltos (no re-tropezar)

| Problema | Solución |
|---|---|
| God matemáticamente inalcanzable (2^29 merges) | Spawn progresivo [aprobado por usuario] |
| Balance 50× rápido (God en 7 min) | costBasis "total" + barrido con balance-sim |
| `xcodebuild test` colgado eterno (waitForBuild/CFRunLoop) | Causa raíz: `xcode-select` global apuntaba a CommandLineTools — los subprocesos de xcodebuild no heredan DEVELOPER_DIR y `xcrun simctl` fallaba. **Fix: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (YA APLICADO)**. Ya no hace falta DEVELOPER_DIR |
| Builds GUI vs CLI pisándose | Simulador dedicado **"CI iPhone"** para CLI; el "iPhone 16" es del usuario. DerivedData CLI: `build-ci/` |
| Tasks en background muertos misteriosamente | Correr procesos largos con `nohup ... & disown` + log a scratchpad + Monitor con until-loop |
| Test colgado infinito en ContentSystemsTests | RNG "determinístico" de valor constante cuelga `Int.random` (rechazo de Lemire). Usar SplitMix64 seedeado (ya está) |
| UI tests rotos por save persistido | Launch arg `--uitest-reset` (solo DEBUG) fuerza partida nueva |
| SKTestSession "file not found" | El `.storekit` va como resource del target de tests + `sdk: StoreKitTest.framework` (en project.yml) |
| Daily reward rompía tests de bootstrap | Fresh install NO reclama daily día 1 (marca el día como reclamado) — decisión de diseño (no compite con FTUE) |
| Doble contabilización al volver de background | Clamp de delta en IncomeTicker (>2s = 0); offline lo cubre |
| appintentsmetadataprocessor "warning" ensuciaba grep | `ENABLE_APP_INTENTS_METADATA: NO` en settings base |
| "Missing package product EconomyKit" en Xcode GUI | Estado viejo tras regenerar el proyecto: Reset Package Caches / reabrir |
| Sueño de la máquina mata generación nocturna | Envolver generación con `caffeinate -is`; tapa abierta + enchufada |

## Cómo compilar/testear (comandos canónicos)

```bash
xcodegen generate
xcodebuild -project FisuEvolution.xcodeproj -scheme FisuEvolution \
  -destination 'platform=iOS Simulator,name=CI iPhone' -derivedDataPath build-ci build
# tests (si algo cuelga, separar build-for-testing / test-without-building):
xcodebuild ... -derivedDataPath build-ci test -parallel-testing-enabled NO
swift test --package-path Packages/EconomyKit          # motor puro, segundos
swift run --package-path Tools/balance-sim balance-sim --economy FisuEvolution/Resources/Data/economy.json --tiers FisuEvolution/Resources/Data/tiers.json --max-hours 36
```
Criterio de warnings: `xcodebuild ... build 2>&1 | grep -cE " warning:"` == 0.

## Mapa de carpetas no obvias

- `Tools/asset-pipeline/` — pipeline de arte: `scripts/` (gemini_batch, cultural_dict, gen_prompts, cutout_batch, style_score/qa_clip, regen_loop, organize_atlases, update_manifest, comfy_batch), `prompts/`, `state/` (test, prompt-search, gemini-test), `.secrets/gemini.key`, `ComfyUI/` (fallback apagado).
- `Tools/audio-synth/` — generador de audio determinístico.
- `Docs/` — balance-log, concurrency-conventions, feedback-matrix, ads-integration, screenshots de gates.
- `Distribution/` — ExportOptions.plist, store-metadata.md (ASO + Review Notes), site/ (privacy/support).
- `Resources/Config/*.json` — events, specials, upgrades, daily_rewards, boosts (con reviewSafe), viral, gamecenter, prestige_unlocks, products, rewarded_ads, feature_flags. Strings de contenido: 122 keys en `Localizable.xcstrings` (base `es` rioplatense).

## Gates que SOLO el usuario puede hacer

1. (Si ads v1) Cuenta AdMob gratuita → App ID + 2 ad unit IDs (`Docs/ads-integration.md`).
2. F6: USD 99 Apple Developer Program, nombre comercial (propuesta: "Fisura: Evolución Idle"), clicks de App Store Connect, TestFlight en su iPhone, Submit.
3. Ya NO hay gates de arte ni audio (automatizados por decisión explícita del usuario).
