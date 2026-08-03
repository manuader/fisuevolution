# Plan final — F7 "La Torre" (commit del prompt + implementación completa)

## Context

Un jugador real terminó FisuEvolution (fisura→dios) en ~20 min; la fase struggling es cortísima y el passive income es inútil (evolucionás y perdés la inversión). El dueño aprobó el rediseño **F7 "La Torre"** especificado en `Docs/PROMPT-F7-torre-de-escenarios.md` (sin commitear): torre de N pisos data-driven y simultáneos, merge con ascenso, ORO permanente vs mejoras de plata por personaje, skins por tipo persistentes con ficha en long-press, split Run/Meta, saves por TIPO reconciliados contra config, y simulación de pacing obligatoria.

Exploración completa hecha (3 agentes) + diseño de arquitectura (Plan agent). Decisiones cerradas con el usuario.

## Decisiones cerradas (usuario)

1. **Ejecución: todo de corrido** — 6 fases en esta sesión; cada fase: build verde (warnings-as-errors) + tests + verificación en simulador + commit.
2. **ORO solo en menús** (tab [Permanentes] + popup Reencarnación). HUD no se toca.
3. **Pacing idle exigente**: fisura ≥20-30 min activos; piso ~1.5-2× el anterior; 1ª reencarnación ~piso 5-6 (4-6 h); Dios ≥30-50 h y varias reencarnaciones. Asserts de sim ±30%.
4. **Puente de progresión** (el merge puro es inviable: T30 = 2²⁹ fisuras): **contratar el TIER BASE del piso donde estás parado, a precio PUNITIVO** — recién rentable cuando tu frontera está varios pisos arriba. Piso 1 = fisuras (caso base barato). NADA de "pagar para subir de tier" (rechazado).
5. Defaults ⚠️ del prompt confirmados: merge bloqueado si piso destino lleno; soul→ORO 1:1; charUpgrades ×2/nivel sin tope; specials = inventario sin slot (anclaje visual por piso); unlockTier = firstTier salvo override; persistencia por TIPO + reconciliación en cada load; una skin activa por tipo; textura `<baseKey>__<skinId>`; skins IAP (tintes golden/galaxy/god) migran como tint-skins `characterType:"*"`.
6. Consecuencia necesaria del pacing aprobado: **gate de reencarnación = `oroGained ≥ 1`** (hoy: Dios en el board — incompatible con reencarnar en piso 5). Multiplicador global desde `meta.oroEarnedLifetime` (monótono; gastar ORO no nerfea).
7. El popup proactivo de PassiveUnlock se retira; la ficha es el único entry point (menos interrupciones).

## Arquitectura clave (del diseño, verificada contra el código)

### PlayerState v4 = sobre con dos secciones (mínimo disruptivo)
```swift
struct PlayerState { var schemaVersion: Int; var run: RunState; var meta: MetaState }  // v4
```
- Conserva intactos: blob único CoreData+snapshot, `SaveMigrator.migrate(Data)`, `CloudSaveSync`, repo. Reencarnar = `run = RunState.fresh(...)`.
- **RunState**: coins, `units: [String:Int]` (por TIPO — lo canónico), passiveUnlocked, chosenCareerPath, `hireCounts: [String:Int]` (por PISO, para la curva de hire), maxTierReached (sigue gateando events/specials/asado/daily), `charUpgradeLevels: [String:Int]`, `unlockedFloors: [String]` (re-propósito del muerto `unlockedBackgrounds`; por id), activeModifiers.
- **MetaState**: lifetimeEarnings, `oro` + `oroEarnedLifetime`, prestigeLevel, `oroUpgradeLevels` (ex upgradeLevels 1:1), derivedEffects (UpgradeState), globalMultiplier, ownedSpecials + specialAnchors, ownedSkins (IAP cache) + `milestoneSkins` (separado: StoreKit reescribe ownedSkins y no debe pisar milestones), `activeSkinByType: [String:String]` (legacy activeSkin → aplicado a tipos presentes), boostActivations, daily, sharesCompleted, removedAds, lastSeenTimestamp, stats.
- `migrateV3toV4` por diccionario (patrón v1→v2/v2→v3) con la tabla campo-a-campo del diseño; board→units por count; spawnPurchases→hireCounts vacío (curva fresca); `unlockedFloors=[]` y el reconciliador la puebla. **`CloudSaveSync.fetch` migra el payload remoto ANTES de resolver** (device v3 vs v4). `SaveConflictResolver` v4: max(oroEarnedLifetime), merge de activeSkinByType, uniones existentes.

### Torre (EconomyKit, archivos nuevos)
- `FloorTable` (validada estilo TierRepository): `FloorDef {id, background, firstTier, lastTier, capacity, incomeMultiplier, unlockTier?}`; cobertura exacta 1...maxTier sin solapes.
- `TowerState` en memoria (`floors[].slots: [String?]`; invariante `unitCounts == run.units`); NO se serializa.
- `TowerReconciler.build(run:floorTable:tiers:)` corre en **cada load**: coloca por tipo→piso (desc por tier), overflow → auto-merge de pares (saltea choice sin carrera) → descarta menor tier con log; sincroniza unlockedFloors (unidades ⇒ desbloqueado; unlockTier ≤ maxTierReached; nunca quita). Esto ES el drill de remapeo.
- `TowerActions` (reemplaza BoardActions+applySpawn): `hireQuote(floorOrdinal:)` / `hire` (**tier base DEL PISO**; piso 1 = fisura; cost punitivo por piso, ver Balance; throws floorFull/insufficient/floorLocked), `move`, `applyMerge(floorOrdinal:...)` → `MergeOutcome.stayed/.promoted(toFloorOrdinal:unlockedFloorId:)` / throws `.destinationFloorFull`, `removeUnit`.
- `IncomeTicker.passivePerSecond` v2: Σ run.units passiveUnlocked × yield × count × `2^charUpgradeLevel(type)` × `floor.incomeMultiplier` × meta.globalMultiplier × derivedEffects × modifiers. `applyTap` con los mismos per-type/per-floor.
- `PrestigeCalculator` → `oroGained = max(0, floor((lifetime/K)^e) − meta.oroEarnedLifetime)`; `canReincarnate = oroGained ≥ 1`; `applyReincarnation`.
- `PacingSimulator` público y puro + `Tools/pacing-sim` (CSV a Docs/): reloj por salto de evento (t = (costo−coins)/rate — 50 h simuladas corren en CI), humano = 3 taps/s, 4 sesiones×20 min/día + offline; política greedy (merge legal → hire del piso si <25% coins O backfill rentable → passive payback<20min → charUpgrade payback<30min → mejora ORO → reencarnar cuando oroGained ≥ max(1, 0.5×oroEarnedLifetime)); carrera fija `programmer`; RNG seed fijo.

### Escena (F7.2)
- `SKCameraNode` (no existe hoy) + `FloorNode` apilados a `(0, i×size.height)`: bg aspect-fill ×1.18 anclado al piso i + fieldNode 5×2 (cellSize ≈ 71.6pt; personajes ~20% más chicos — validar legibilidad con screenshot; fallback: subir realArtScale/rowDepth por piso).
- Lazy ±1: fuera de rango → sin textura de bg + `isPaused = true` (mata wander); relayout confinado al rango vivo.
- **Reveal/flash/labels re-parenteados a la cámara** (hoy van a `self` en coords de escena — romperían).
- Gestos: personaje → pipeline actual (tap <10pt / drag intra-piso / long-press 0.45s = ficha); vacío → swipe (|dy|>48pt y >1.5×|dx|) al piso adyacente; clamp a 1 piso bloqueado (scrim+candado+hint). Flechas SwiftUI siempre disponibles.
- Ascenso animado: clon + fx_evolution_flash + vuelo ~0.7s; cámara sigue SOLO el primer unlock de cada piso; si no, indicador "subió ↑".
- UI→escena: `requestFloorChange` vía proyección versionada (patrón boardVersion).

### UI (F7.2-F7.5)
- Flechas borde derecho estilo hudIconButton + pill de piso "Callejón · 1/11 · 7/10" (CurrencyPill-like). A11y: `tower.arrow.up/down`, `tower.pill`.
- `UpgradesView` 2 tabs vectoriales [Personajes | Permanentes]; Personajes = tipos con units>0 o nivel>0, retrato + "×2ᴺ" + costo; Permanentes = 7 líneas en ORO + balance ORO en header.
- `PrestigeView` → Reencarnación: "Vas a ganar X ORO", pierde/conserva (Run/Meta literal), CTA por canReincarnate. Botón HUD aparece con canReincarnate.
- `CharacterSheetView` (nuevo; ELIMINA PassiveUnlockView): secciones componibles — (1) banner nombre + retrato con skin + flechas ‹ › "2/4" + silueta ink no-equipable con condición/precio; (2) passive (compra + badge); (3) despedir destructivo CON confirmación.
- `UIArt` extendido: atlas parametrizable + cache clave compuesta `"atlas/key"` + `characterImage(atlas:key:)`; silueta = `.template` + PaletteInk.
- `skins.json` (nuevo, GameContent #14; modelo en EconomyKit): entradas tint `characterType:"*"` (3 IAP) + texture per-type; milestones `floorReached/reincarnations` evaluados por `SkinMilestones` puro tras unlock/reencarnación; celebración gateada por tutorial. `SkinResolver` reescrito → `.base/.tint/.texture` (muere el switch hardcodeado).
- `OroIcon` vectorial (gemelo de CoinIcon); PNG del pipeline recién en F7.6.

## Fases (commit por fase; cada una build verde + tests + simulador)

### F7.0 — Commits de arranque
1. `Docs/PROMPT-F7-torre-de-escenarios.md` **actualizado primero**: §3.3 y ⚠️#1 pasan del default "hire cae al piso 1" al puente elegido (hire contextual del tier base del piso, precio punitivo); §3.10 sin sección de ascenso pagado. Commit del prompt + `Docs/PLAN-F7-torre.md` (este plan).

### F7.1 — EconomyKit v2 (3 commits internos compilables)
- **1a config**: `economy.json` v2 con `floors[]` (11 pisos espejando stageThresholds: alley 1-2, urban 3-5, corporate 6-9, luxury 10-13, island 14-17, moon 18-21, mars 22-23, solar 24-25, galaxy 26-27, cosmic 28-29, god_realm 30), `hire{...}` por piso, `charUpgrades{...}`, `oro{...}`; sin spawn/tierOffset/prestige/board viejos. `EconomyConfig` espejo. Regenerar `tiers.json` (`swift run generate-tiers`; growth 3.8→2.6) + anti-drift.
- **1b estado**: PlayerState v4 + RunState/MetaState; FloorTable/TowerState/TowerActions/TowerReconciler/CharUpgrades nuevos; IncomeTicker/OfflineCalculator/PrestigeCalculator/SaveConflictResolver v2; `migrateV3toV4` + CloudSync migra remoto; GameState recableado mínimo (torre + piso visible provisional; BoardScene mono-piso 5×2; selector de piso en DebugPanel); borrar spawn progresivo y `soulPointsText`. Rename mecánico `run./meta.` en commit separado del cambio de lógica.
- **1c simulador**: PacingSimulator + Tools/pacing-sim + PacingTests con los 4 asserts (urban 14-39 min activos; ratio 1.15-2.6; 1ª reencarnación 2.8-7.8 h; dios 21-65 h con ≥3 reencarnaciones). Calibración inicial hasta que pasen.
- Tests: FloorTableTests, TowerActionsTests (hire por piso: barato piso 1 / punitivo frontera / rentable backfill; merge+promoción; bloqueos; invariante unitCounts==units), PrestigeCalculatorTests (ORO), IncomeTickerTests (multi-piso, per-type, per-floor), SaveMigratorTests (fixture v3 real→v4 campo a campo; cadena v1→v4), drill de remapeo, ConflictResolver v4. Migrar Persistence/GameState/GameLoopWiring/ContentSystems tests.

### F7.2 — Torre en escena
- FloorNode + cámara + lazy ±1 + reveal re-parenteado + arbitraje de gestos + ascenso animado + flechas/pill SwiftUI + nombres de piso ×11 en xcstrings (+fix `hud.settings.label` faltante). income/sec total en HUD (`towerIncomePerSecText`).
- Done: 60fps con 5 pisos poblados (overlay DEBUG), navegación swipe+flechas verificada con screenshots, sin leaks (una pasada de Instruments).

### F7.3 — Contratación por piso + desbloqueo
- SpawnButtonView contextual: "Contratar <TierBase del piso>" + costo del quote del piso; piso bloqueado/lleno → patrón legible (ink+desaturación); toast al mergear contra piso lleno; celebración de unlock (reveal + cámara); tutorial +2 pasos (torre y ascenso); borrar stageThresholds/stageFallbackColors; migrar strings hardcodeados del tutorial a xcstrings.
- Done: flujo fisura→T3→unlock piso 2 verificado con screenshots en install limpio.

### F7.4 — ORO + mejoras
- `upgrades.json` v2 (`currency:"oro"`, costos 1-5 ORO, growth 1.9-3.0; `decodeIfPresent` default .coins), UpgradeManager debita meta.oro; UpgradesView 2 tabs; PrestigeView→Reencarnación; proyecciones oroText/oroGainPreview/canReincarnate; buyCharUpgrade per-type (multiplicador entra en los caminos de income, NO en recomputeDerivedEffects — UpgradeState queda global y chico).
- Done: ciclo jugar→reencarnar→ganar ORO→comprar permanente→sobrevive / plata muere. Screenshots.

### F7.5 — Skins + ficha
- skins.json + SkinsConfig (EconomyKit) + SkinMilestones + SkinResolver nuevo + CharacterNode por tratamiento + UIArt retratos + CharacterSheetView (elimina PassiveUnlockView) + celebración milestone + specials anclados visualmente.
- Done: checklist skins end-to-end del §7 del prompt con screenshots (milestone, compra, equipar en tablero+retrato, reencarnar, fallback sin arte, silueta no equipable).

### F7.6 — Balance + drills + polish
- Grid del sim sobre 6 knobs → `Docs/balance-run-f7.csv` → config final (margen ≥15% en asserts) + tiers.json regenerado + GameContentValidationTests re-pineado.
- Drill de extensibilidad (piso 12 + personaje + skin dummy, cero código) y drill de remapeo como tests permanentes.
- Icono ORO por pipeline (único asset); haptics/SFX de ascenso/unlock/ORO; Reduce Motion en cámara; ESTADO.md + bitácora.

## Balance seeds v2 (calibra el sim; el usuario pidió backfill "muy caro")

| Knob | Seed | Nota |
|---|---|---|
| yieldGrowthPerTier | 2.6 (de 3.8) | el ramp por piso absorbe la diferencia |
| floors[].incomeMultiplier | 1→40 (~×1.45/piso) | todos los pisos siguen importando |
| passiveRatio / unlockCostMult | 0.5 / 60 | passive protagonista temprano |
| hire piso 1 (fisura) | base 25 × 3.0^hireCounts["alley"] | fase struggling |
| **hire piso k>1 (PUNITIVO)** | `hireFloorMultiplier` ≈ **600 × tapYield(firstTier(k))** × 1.6^hireCounts[k] | en frontera ≈ horas de income (no conviene); con frontera k+2/k+3 ≈ minutos (backfill rentable). Knob principal del puente; el sim lo calibra para que "recién rentable varios pisos arriba" se cumpla y Dios caiga en 21-65 h |
| charUpgrades | costo 50×tapYield(t)×7^nivel; ×2/nivel | válvula de la fase struggling |
| oro | divisor 5e9, exp 0.5, 0.02/oro (sobre earnedLifetime) | K ≈ lifetime@piso5 |
| mejoras ORO | 1-5 base, growth 1.9-3.0 | 1ª reencarnación compra 1-2 |
| offlineCapHours | 10 | juego largo, cap amable |

## Riesgos (mitigaciones en fase)
1. 5 usos de maxTierReached: spawn (muere), fondo (muere), events/specials/asado/daily (siguen con run.maxTierReached, misma semántica per-run) — auditado con grep + wiring test en F7.1.
2. Teardown total de escena ×11 pisos → relayout confinado al rango vivo; fps gate en F7.2.
3. Swift 6 strict: todo lo nuevo value-type Sendable; SkinsConfig sin @MainActor.
4. Warnings-as-errors: cada fase borra TODO lo que huerfanea (PassiveUnlockView, SkinResolver switch, stageThresholds, soulPointsText).
5. xcstrings: ~35 claves nuevas es+en en el mismo commit que su vista.
6. CloudKit v3 remoto vs v4 local: fetch migra antes de resolver + test.
7. F7.1 gigante: 3 commits internos; rename mecánico separado.
8. Capacidad 10 (5×2) achica personajes ~20%: decisión visual con screenshot en F7.2.

## Verificación end-to-end (gate final)
- Suite completa verde (EconomyKit + app + PacingTests + drills) con warnings-as-errors.
- Simulador: install limpio → tutorial (7 pasos) → struggling ≥20 min simulados (time-warp DEBUG) → unlock piso 2 con celebración → navegación completa de la torre → backfill caro vs rentable → reencarnación → ORO → skins end-to-end → save v3 real migrado y jugable. Screenshots en cada hito.
- `pacing-sim` reporta los 4 hitos dentro de targets con margen ≥15%.
- Commit por fase sobre `main` (7-9 commits).
