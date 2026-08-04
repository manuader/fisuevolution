# HANDOFF — F7 "La Torre": estado de implementación

> ## ✅ ACTUALIZACIÓN 2026-08-03 (tarde): F7.1 CERRADO
>
> Todo lo que este doc describe como pendiente en §5 se COMPLETÓ y está
> commiteado en `432e6a5` ("temp commit", subsume los commits A y B del §5.3):
> - Tests del paquete migrados + 2 suites nuevas: **126 tests verdes** (`swift test`).
> - Tests de app migrados (8 suites + SaveMigratorTests propio + PacingTests):
>   **61 tests verdes**, UI tests compilan, cero warnings.
> - `Tools/pacing-sim` creado; **calibración inicial hecha** (16 iteraciones):
>   los 4 targets de §4/PLAN §F7.1c pasan — urban 16.2 min activos, 1ª
>   reencarnación 4.0 h, dios 48.2 h con 14 reencarnaciones. Detalle de knobs,
>   decisiones de diseño del assert de gradiente y un fix al PacingSimulator
>   (regla «hire si <25% del wallet» del plan, que faltaba) en
>   `Docs/balance-log.md §F7.1`.
> - `yieldGrowthPerTier` quedó en **2.8** (no 2.6) y tiers.json regenerado.
> - El §4 (problema de balance) y el §5 quedan como registro histórico.
>
> **Lo que sigue: F7.2** (torre en escena — ver §6 y `Docs/PLAN-F7-torre.md`).

> ## ✅ ACTUALIZACIÓN 2026-08-04 (madrugada): F7.2 CERRADO
>
> La torre ya vive en la escena: `SKCameraNode`, `FloorNode` apilados y lazy
> visible ±1, overlay de reveal fijado a cámara, navegación por flechas y swipe
> en espacio vacío, pill accesible con income total y ascenso visual pooled.
> `TowerNavigation` es la única proyección que consume la UI; los nombres de los
> 11 pisos y a11y están localizados en es/en. Se agregó un fixture sólo DEBUG
> (`--uitest-unlock-tower`) para validar navegación determinista sin un save.
>
> Verificación final: **126 tests EconomyKit + 66 tests app, todos verdes**;
> `GameLoopWiringTests` 11/11, smoke UI 3/3 (flecha y drag vertical reales),
> build Debug con warnings-as-errors y captura persistente
> `scratchpad/qa-shots/F7.2-navigator.png` a **60 fps**. `graphify` sigue sin
> instalar en este entorno. Se regeneró el proyecto con `xcodegen generate`
> porque el nuevo archivo no aparecía en el build generado.
>
> **Lo que sigue: F7.3** — UX de contratación contextual/bloqueos, celebración
> del unlock con cámara y tutorial de torre/ascenso. Bitácora de esta sesión:
> `Docs/SESION-2026-08-03-f7-torre.md`.

> ## 🟡 ACTUALIZACIÓN 2026-08-04: F7.3 EN CURSO
>
> Implementados y listos para commit: proyecciones de piso lleno/bloqueado, toast
> tipado para destino lleno, estado legible del botón de contratación, celebración
> + foco de cámara al primer unlock, preview de exactamente un piso bloqueado
> (scrim+candado) y tutorial localizado de 7 pasos. Wiring **13/13** y smoke UI
> **4/4**; captura estable de preview en `scratchpad/qa-shots/F7.3-locked-floor-preview.png`.
> El ascenso T2→Urban está cubierto en GameState, pero su drag visual no se dejó
> automatizado porque las coordenadas SpriteKit del runner resultaron frágiles.
> La suite completa de app había dado **67/67 verdes** antes del ajuste de balance
> posterior. El ajuste pedido en `99af8dd` baja el primer Fisura a **50**: el
> test de contenido pasa, pero el simulador deja urban (5.8 min) y la primera
> reencarnación (0.26 h) fuera de los targets F7.1. Se preserva la decisión del
> dueño y se deja la recalibración para F7.6. No interpretar el fallo de esos
> targets como regresión accidental. Dejar commit aislado antes de F7.4.

> **Para el agente que retoma:** este doc te deja arrancar DE CERO. Leelo entero,
> después leé `Docs/PROMPT-F7-torre-de-escenarios.md` (spec funcional aprobada) y
> `Docs/PLAN-F7-torre.md` (plan de implementación aprobado, con arquitectura,
> fases, balance seeds y riesgos). Los tres docs están commiteados en `d7cf370`.
> Fecha de este handoff: 2026-08-03.

---

## 0. Cómo trabajar en este repo (no negociable)

- **Proyecto Xcode**: el `.xcodeproj` NO se versiona; se regenera con `xcodegen generate`
  desde `project.yml` (globbea `FisuEvolution/` — archivos Swift nuevos entran solos;
  si agregás un archivo y el build no lo ve, corré xcodegen).
- **Cero warnings**: `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`, Swift 6,
  `SWIFT_STRICT_CONCURRENCY: complete`. Todo lo nuevo de EconomyKit = value types `Sendable`.
- **Grafo de código (graphify)**: usá `graphify explain "<Símbolo>"` y
  `graphify path "<A>" "<B>"` en vez de grepear (lee `graphify-out/graph.json`).
  ⚠️ **El grafo está STALE**: fue generado en el commit `9ad541d`, ANTES de todo F7.
  Primer paso recomendado: `graphify update .` (gratis, local, ~1 min) para que
  refleje TowerActions/FloorTable/etc. `graphify-out/` está gitignoreado.
- **Builds**:
  ```bash
  # paquete (rápido, para iterar en EconomyKit):
  cd Packages/EconomyKit && swift build && swift test
  # app (sim iPhone 16):
  xcodebuild -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD build
  # tests de app:
  xcodebuild ... -derivedDataPath build/DD test -only-testing:FisuEvolutionTests
  ```
- **Regenerar tiers** (si cambia `yieldGrowthPerTier` u otra fórmula):
  `cd Tools/generate-tiers && swift run generate-tiers --economy ../../FisuEvolution/Resources/Data/economy.json --output ../../FisuEvolution/Resources/Data/tiers.json`
- Commits: atómicos por fase, mensaje en español, footer `Co-Authored-By: Claude ...`.
- Idioma con el usuario: **español** (rioplatense). Strings de UI en `Localizable.xcstrings` (es base + en).

## 1. Qué es F7 y decisiones CERRADAS con el dueño (no re-litigar)

Problema: un jugador terminó el juego (fisura→dios) en 20 min; fase struggling
cortísima; passive income inútil. F7 = rediseño "La Torre".

1. **Torre de N pisos** fijos y simultáneos (hoy 11, data-driven en `economy.json → floors[]`),
   navegable con swipe + flechas. Cada piso aloja los tiers de su rango, capacity 10.
2. **Contratación contextual al piso** (⚠️ decisión clave, reemplaza al default viejo):
   el botón contrata el TIER BASE del piso visible. Piso 1 = fisura barato; pisos
   superiores = **precio PUNITIVO** (backfill recién rentable con la frontera 2-3
   pisos arriba). El "ascenso directo pagado" fue **RECHAZADO** por el dueño.
   (Razón matemática: merge puro ⇒ T30 = 2²⁹ fisuras, inviable.)
3. **Merge confinado al piso**; si el resultado pertenece al piso siguiente,
   **asciende** (animación); piso destino lleno ⇒ merge BLOQUEADO (toast).
4. **Gate de reencarnación = `oroGained ≥ 1`** (ya NO "Dios en el tablero").
   ORO = ex soul points (migración 1:1). Multiplicador global sobre
   `meta.oroEarnedLifetime` (monótono — gastar ORO no nerfea).
5. **Mejoras con plata por personaje** (`charUpgradeLevels`, ×2/nivel sin tope,
   mueren al reencarnar) + **mejoras permanentes con ORO** (las 7 líneas actuales,
   F7.4 las flipea a currency oro). ORO **solo en menús** (tab Permanentes +
   PrestigeView) — NO agregar pill al HUD.
6. **Skins por tipo** persistentes (MetaState), ficha de personaje en long-press
   (F7.5). Skins IAP existentes (tintes golden/galaxy/god) migran como tint-skins.
7. **Pacing idle exigente** (confirmado): fase fisura ≥20-30 min ACTIVOS; cada piso
   ~1.5-2× el anterior; 1ª reencarnación ~piso 5-6 (4-6 h); Dios ≥30-50 h con
   varias reencarnaciones. Asserts de simulación con tolerancia ±30%.
8. Popup proactivo de PassiveUnlock se retira en F7.5 (la ficha es el entry point).
9. Ejecución: fase por fase, cada una = build verde + tests + verificación en
   simulador con screenshots + commit.

## 2. Estado por fase

| Fase | Estado |
|---|---|
| **F7.0** docs (prompt+plan) | ✅ COMMITEADO (`d7cf370`) |
| **F7.1** EconomyKit v2 + estado v4 + migración | ✅ cerrado (`432e6a5`; el §5 es histórico) |
| **F7.2** Torre en escena (cámara/FloorNodes/navegación) | ✅ cerrado (ver actualización 2026-08-04) |
| F7.3 Contratación por piso + desbloqueo + tutorial | 🟡 implementación lista; falta commit (captura de preview sí, ascenso cubierto por test) |
| F7.4 ORO UI + upgrades currency + PrestigeView | ⬜ pendiente |
| F7.5 Skins + ficha | ⬜ pendiente |
| F7.6 Balance (grid sim) + drills + polish + docs | ⬜ pendiente |

F7.1 y F7.2 ya están commiteadas (`432e6a5`, `3b27416`). Al retomar, revisar
`git status`: sólo deben existir cambios de la fase activa, documentados en la
bitácora de sesión.

## 3. Lo implementado en F7.1 (todo compila; smoke test en vivo PASÓ)

### EconomyKit (`Packages/EconomyKit/Sources/EconomyKit/`)

**Archivos NUEVOS:**
- `FloorTable.swift` — `FloorDef {id, background, firstTier, lastTier, capacity,
  incomeMultiplier, hireCostMultiplier?/hireCostGrowth? (overrides), unlockTier?}` +
  `FloorTable(floors:maxTier:)` validada (cobertura exacta 1...maxTier, sin solapes,
  `FloorValidationError` tipado) + `ordinal(forTier:)`/`floor(forTier:)`/`ordinal(of:)`.
- `TowerState.swift` — `TowerPlacement {floorOrdinal, slot, typeId}`; `TowerState`
  en memoria (`floors[].slots: [String?]`, `unitCounts`, `placements(onFloor:)`).
  NO se serializa.
- `TowerActions.swift` — `HireQuote`, `TowerError {floorLocked, floorFull,
  destinationFloorFull(floorId), insufficientCoins, invalidSlot, noHireableType}`,
  `TowerMergeResult {stayed, promoted(toFloorOrdinal:slot:newTypeId:unlockedFloorId:),
  requiresCareerChoice}`. `hireQuote(floorOrdinal:...)` (cost = multEfectivo(piso) ×
  tapYield(firstTier) × growthEfectivo(piso)^hireCounts[floorId] × costMultiplier ×
  modifier(spawnCost) × (1−spawnDiscount)); `hire` (solo tier base del piso, piso
  desbloqueado, slot libre, saldo); `move`; `applyMerge` (ascenso cross-piso,
  destino lleno THROWS sin mutar, setea unlockedFloorId al desbloquear); `removeUnit`
  (false si última unidad de la torre).
- `TowerReconciler.swift` — `reconcile(run:floorTable:tiers:) → {tower, autoMerged,
  discarded}`. Corre en CADA load: coloca `run.units` por piso según config VIGENTE,
  overflow → auto-merge de pares (respeta carrera vía MergeRules) → descarta menor
  tier con log; sincroniza `unlockedFloors` (por id, nunca quita) y maxTierReached.
  Esto ES el mecanismo de remapeo intercambiable (spec §3.1).
- `CharUpgrades.swift` — `multiplier(typeId:levels:config:)` = effectFactor^nivel;
  `nextLevelCost`; `purchase` (debita run.coins).
- `PacingSimulator.swift` — bot greedy determinístico, reloj por salto de evento,
  modelo humano (3 taps/s, 4 sesiones×20min/día + offline), política: merges →
  passive payback<30min → charUpgrade → hire piso1 → backfill rentable → reencarnar
  cuando `oroGained ≥ max(1, oroEarnedLifetime)`. `run(maxDays:) → Report
  {floorUnlockActive/WallSeconds, firstReincarnationWall, godWall, reincarnations}`.
  COMPILA pero **NUNCA SE CORRIÓ** — correrlo es lo próximo (ver §5.2).

**Archivos REESCRITOS:**
- `PlayerState.swift` — **v4** (`currentSchemaVersion = 4`): sobre
  `{schemaVersion, run: RunState, meta: MetaState}`.
  - `RunState`: coins, `units:[String:Int]` (POR TIPO — ya no existe board/BoardPlacement),
    passiveUnlocked, chosenCareerPath, `hireCounts:[String:Int]` (por floorId),
    maxTierReached, `charUpgradeLevels`, `unlockedFloors:[String]`, activeModifiers.
    `RunState.fresh(startTypeId:startFloorId:)`, `totalUnits`.
  - `MetaState`: lifetimeEarnings, `oro`, `oroEarnedLifetime`, prestigeLevel,
    `oroUpgradeLevels` (ex upgradeLevels, incluye key `_milanesa`), `derivedEffects:
    UpgradeState` (ex upgrades), globalMultiplier, ownedSpecials, `specialAnchors`,
    ownedSkins (cache IAP), `milestoneSkins` (separadas — StoreKit no las pisa),
    `activeSkinByType:[String:String]`, removedAds, boostActivations, daily,
    sharesCompleted, lastSeenTimestamp, `stats {maxFloorOrdinalEver}`.
    `MetaState.fresh(...)`, `allOwnedSkins`.
  - `PlayerState.newGame(startTypeId:startFloorId:offlineEfficiencyBase:critChanceBase:now:)`.
- `EconomyConfig.swift` — v2: murieron `spawn/prestige/board`; nuevos `hire
  {defaultCostMultiplier, defaultCostGrowth}`, `charUpgrades {baseCostMultiplier,
  costGrowth, effectFactorPerLevel}`, `oro {divisor, exponent, globalMultiplierPerOro}`,
  `floors: [FloorDef]`; helpers `hireCostMultiplier(for:)/hireCostGrowth(for:)`.
- `EconomyEngine.swift` — quedan tapYield/passiveYield/passiveUnlockCost +
  `oroTotal(lifetimeEarnings:)` + `globalMultiplier(oroEarnedLifetime:prestigeBonus:)`
  + `clampedFloor`. Murieron spawnTier/spawnCost/soulPoints.
- `GameActions.swift` — quedan `applyTap(type:state:floorTable:now:)` (multiplica
  CharUpgrades + floor.incomeMultiplier + derivedEffects + global + modifiers) y
  `applyPassiveUnlock`. Murieron SpawnQuote/spawnQuote/applySpawn/SpawnError.
- `BoardActions.swift` — **ELIMINADO** (git rm; reemplazado por TowerActions).
- `IncomeTicker.swift` — `passivePerSecond/tick(state:tiers:floorTable:config:...)`:
  Σ run.units passiveUnlocked × yield × count × charUpgrade × floorMult × global ×
  incomeMult × modifiers. Clamp de delta 2.0s intacto.
- `OfflineCalculator.swift` — firmas + floorTable; usa meta.lastSeenTimestamp y
  meta.derivedEffects.offlineEfficiency.
- `PrestigeCalculator.swift` — `oroGained`, `canReincarnate` (≥1),
  `applyReincarnation` (= `run = .fresh(...)` + acredita oro + multiplier).
  `PrestigeUnlocks` intacto (descuento de hire por nivel).
- `SaveConflictResolver.swift` — v4: gana meta.lifetimeEarnings; uniones
  ownedSkins/milestoneSkins/ownedSpecials/removedAds; `oroEarnedLifetime` max con
  crédito de la diferencia a `oro`; merge de activeSkinByType (winner manda,
  completa keys faltantes).
- `ActiveModifier.swift` — solo `prune` → run.activeModifiers.
- `MergeRules.swift` / `TierRepository.swift` / `CharacterType.swift` — SIN CAMBIOS.

### Config/data
- `FisuEvolution/Resources/Data/economy.json` — **v2 completo** (schemaVersion 2):
  growth 2.6 (era 3.8), passiveRatio 0.5, unlockMult 60, hire default 600/1.6,
  charUpgrades 50/7.0/2.0, oro 5e9/0.5/0.02, offlineCap 10h, `floors[]` = 11 pisos
  espejando la vieja tabla stageThresholds (alley 1-2 con override hire 25/3.0,
  urban 3-5, corporate 6-9, luxury 10-13, island 14-17, moon 18-21, mars 22-23,
  solar 24-25, galaxy 26-27, cosmic 28-29, god_realm 30; capacity 10; incomeMultiplier
  1.0→40.0).
- `FisuEvolution/Resources/Data/tiers.json` — REGENERADO con growth 2.6 (37 tipos,
  T5 tap = 45.6976 verificado).

### App target (todo compila verde)
- `Managers/GameContentLoader.swift` — `GameContent.floorTable: FloorTable` nueva,
  validada al cargar + valida que cada floor.background exista en manifest.backgrounds.
- `Game/State/GameState.swift` — REESCRITO para la torre:
  - Nuevos: `tower: TowerState?` (@ObservationIgnored), `visibleFloorOrdinal`
    (proyección), `setVisibleFloor` (clamp a desbloqueados), `visiblePlacements`,
    `visibleFloorDef`, `visibleFloorOccupancy`, `floorTable`, `oroText`,
    `reconcileTower()` (bootstrap; setea piso visible = máx desbloqueado),
    `resyncTower()` (sin mover cámara), `updateMaxFloorStat()`, `placeGrantedUnit`.
  - `spawnQuote` ahora es `HireQuote?` (misma forma para las vistas: .type/.cost);
    `buySpawn()` = hire del piso visible; `handleDrop` → TowerActions con
    `DropResolution.merged(targetCell:evolvedTo:promotedToFloor:unlockedFloorId:)`
    (destino lleno → .snapBack + haptic error, toast llega en F7.3);
    `registerTap/presentPassivePrompt/dismissCharacter/chooseCareer` operan sobre
    slots del PISO VISIBLE; `confirmPrestige` → applyReincarnation + reconcileTower.
  - `soulPointsText` MURIÓ; `prestigeSoulPointsGained` ahora devuelve ORO (rename
    de UI en F7.4); `prestigeAvailable` = canReincarnate.
  - Skins puente F7.1: `setActiveSkin` aplica a TODOS los tipos poseídos;
    proyección `activeSkin` = skin del baseType (F7.5 lo reemplaza).
  - `reconcileBoardCapacity` MURIÓ (lo reemplaza TowerReconciler).
- `Managers/ContentSystems.swift` — paths run/meta en todos los managers.
  `EventManager.fireRandomEvent(...floorTable:...)` → `Roll {event, active,
  grantedUnitTypeId, unitsChanged}`: freeHighTier YA NO coloca (devuelve typeId,
  GameState lo coloca vía torre o lo pierde con log si el piso está lleno);
  instantEvolution muta run.units + unitsChanged=true (GameState hace resyncTower).
- `Persistence/SaveMigrator.swift` — `migrateV3toV4` por diccionario (cadenas
  v1/v2/v3 → v4): board→units por count; soulPoints→oro Y oroEarnedLifetime (1:1);
  upgradeLevels→oroUpgradeLevels; upgrades→derivedEffects; activeSkin global→
  activeSkinByType sobre tipos presentes; spawnPurchases y unlockedBackgrounds
  DESCARTADOS (hireCounts vacío = curva fresca; unlockedFloors lo puebla el
  reconciliador); chosenCareerPath solo si es String (evitar NSNull).
- `Persistence/CloudSaveSync.swift` — push usa meta.*; fetch YA migraba con
  SaveMigrator (requisito v3-remoto-vs-v4-local cubierto).
- `Scenes/BoardScene.swift` — mínimo F7.1: renderiza SOLO el piso visible.
  `layoutBoard` deriva grilla del piso (rows 2, cols = ceil(capacity/2) = 5;
  cellSize ≈ 71.6pt); `rebuildAnchors(capacity:)`; `renderFieldBackground(content:floorDef:)`
  usa floorDef.background (la tabla `stageThresholds` MURIÓ; `stageFallbackColors`
  sigue para el fallback); `renderPlacements(content:)` itera
  gameState.visiblePlacements (slot = cellIndex del nodo); skinTint desde
  gameState.activeSkin; FTUE hint sobre visiblePlacements; touchesEnded matchea el
  nuevo `.merged` (promotedToFloor ⇒ feedback en dropPoint; animación de vuelo en F7.2).
- `UI/Store/UpgradesView.swift` — `player.run.coins` (1 línea).

### Verificación ya hecha
- `swift build` del paquete: verde (con PacingSimulator).
- `xcodebuild` app target: **BUILD SUCCEEDED**.
- **Smoke test EN VIVO en sim iPhone 16**: el save v3 real migró a v4, el
  reconciliador colocó las unidades, el piso visible arrancó en god_realm (piso 11,
  el save tenía maxTier 30 de tests previos), y el offline v2 acreditó +19,1ab.
  Screenshot: scratchpad qa-shots/f7-smoke1.png.

## 4. ⚠️ Problema CONOCIDO de balance (resolver con la simulación)

Con los seeds actuales, la fase fisura dura ~2-4 min activos (target: 20-30):
T3 requiere solo 3 hires extra (25+75+225 = 325 coins a ~4/s). **El knob es la
curva del alley** (`hireCostMultiplier`/`hireCostGrowth` del piso 1). Candidato
analizado: multiplier 40 / growth 12 (→ hires 40, 480, 5760 ≈ 15-20 min con
passive+charUpgrade). También revisar el punitivo default (600/1.6): el payback
de backfill en frontera da ~13 min (demasiado atractivo — el dueño pidió "muy
caro"); candidato: subirlo (ej. 3000-10000 × tapYield, growth 1.35-1.6) hasta que
el payback en frontera sea horas. **NO tunear a mano: correr PacingSimulator,
mirar el reporte, iterar los knobs de economy.json y (si cambia growth) regenerar
tiers.json.** Los targets con tolerancia están en `Docs/PLAN-F7-torre.md` §F7.1c:
urban 14-39 min activos; ratio entre pisos 1.15-2.6; 1ª reencarnación 2.8-7.8 h
wall; dios 21-65 h wall con ≥3 reencarnaciones.

## 5. QUÉ FALTA para cerrar F7.1 (en orden)

### 5.1 Migrar los tests — ESTADO PARCIAL (actualizado 2026-08-03, segunda pasada)

**Ya migrado (escrito, TODAVÍA SIN COMPILAR — el target de tests no compila hasta
que TODAS las suites estén migradas, así que no se pudo verificar):**
- `Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift` (NUEVO) — fixtures
  compartidas v2: `fxConfig()` (2 pisos: f1 {T1-2, hire override 15/1.15 — mismos
  números que la curva de spawn vieja} y f2 {T3-4, hire default punitivo 100/2.0},
  capacity 5, incomeMultiplier 1.0 para no esconder multiplicadores), `fxTiers()`
  (escalera a→b→[choice]c_prog/c_law→d, idéntica a la vieja), `fxState(units:)`,
  `fxStateAndTower(...)` (reconcilia la torre), `fxSlot/fxSlots`.
- `Packages/EconomyKit/Tests/EconomyKitTests/GameLoopTests.swift` (REESCRITO) —
  MergeRules (intacta), **TowerActionsTests** (move, merge intra-piso + invariante
  `tower.unitCounts == run.units`, ascenso `.promoted` con `unlockedFloorId`,
  destino lleno THROWS sin mutar nada, removeUnit nunca saca la última),
  PassiveTests (+ floorMultiplier ×3 y charUpgrade ×2), IncomeTickTests,
  OfflineTests (meta.derivedEffects/lastSeenTimestamp), **ReincarnationTests**
  (gate por ORO, delta sin doble-cobro, reset run campo a campo + meta preservada,
  gastar ORO no baja el multiplicador, PrestigeUnlocks intacto).

**Falta migrar (siguen en API v3, NO COMPILAN):**
`EconomyEngineTests.swift` (90 líneas — fórmulas que quedan + oroTotal/globalMultiplier
+ curva de hireQuote: f1 barato 15/17.25/19.8375, f2 punitivo 100×tapYield(3), growth
por hireCounts del piso), `GameActionsTests.swift` (176 — tap con floor/charUpgrade
mult; hire cobra/floorLocked/floorFull/insufficient/incrementa hireCounts),
`ActiveModifierTests.swift` (107 — paths run/meta; spawnCostMultiplier afecta
hireQuote), `SaveConflictResolverTests.swift` (52 — v4 + crédito de oroEarnedLifetime
+ merge activeSkinByType), `TierRepositoryTests.swift` (probablemente compila sin
cambios — verificar). NUEVOS a crear: `FloorTableTests.swift` (todas las
validaciones de FloorValidationError + lookups) y `TowerReconcilerTests.swift`
(colocación por tipo→piso, overflow→auto-merge, descarte menor-tier, sync de
unlockedFloors, drill de remapeo). Después: las suites de la app (spec abajo).
Loop de verificación: `cd Packages/EconomyKit && swift test`.

Especificación completa de intención por suite: **§ "Qué hacer con cada suite"
del plan (`Docs/PLAN-F7-torre.md`)** y resumido acá:
- **Package** (`Packages/EconomyKit/Tests/EconomyKitTests/`): EconomyEngineTests
  (fórmulas + oro + hire barato/punitivo/growth por piso), GameActionsTests (tap
  con floor/charUpgrade mult; hire cobra/floorLocked/floorFull/insufficient),
  GameLoopTests (fixture propia con choice node T3 — AGREGARLE floors[] a la
  fixture; TowerActions move/merge/ascenso/.promoted+unlockedFloorId/destino lleno
  no muta/removeUnit última false; Passive/IncomeTick/Offline firmas nuevas;
  Prestige → oroGained/canReincarnate/applyReincarnation reset run + conserva meta
  + no doble-cobro), ActiveModifierTests (paths nuevos; spawnCostMultiplier afecta
  hireQuote), TierRepositoryTests (sin cambios), SaveConflictResolverTests (v4 +
  oroEarnedLifetime max con crédito + merge activeSkinByType).
  NUEVOS: FloorTableTests (todas las validaciones), TowerReconcilerTests
  (colocación, overflow→auto-merge, descarte, unlockedFloors, **drill de remapeo**).
- **App** (`FisuEvolutionTests/`): GameContentValidationTests REESCRITO contra el
  contenido real v2 (37/36/30/homeless/god igual; anti-drift growth 2.6; floors[]
  11 pisos cobertura 1..30 capacity 10 backgrounds existentes; pins de config
  nuevos — OJO: pinear los valores FINALES post-calibración, no los seeds);
  ContentSystemsTests (paths + EventManager Roll nuevo); GameLoopWiringTests
  (HireQuote, slots del piso visible, career T8 con setup adecuado, prestige con
  lifetime ≥ 5e9 para el gate); SaveMigratorTests (+fixture v3 realista → v4
  asserteado campo a campo; cadena v1→v4); GameStateTests (newGame firma nueva);
  PersistenceTests (fixtures v4); StoreManagerTests (meta.ownedSkins + puente
  activeSkin); CoinFormatterTests sin cambios. UI tests: que compilen.
- Regla: si un test revela un bug real de producción, REPORTARLO (no parchearlo en el test).

### 5.2 Pacing: correr, calibrar, testear
1. `Tools/pacing-sim/` — ejecutable SPM chico (depende de EconomyKit por path,
   copiar el patrón de `Tools/generate-tiers/Package.swift`) que carga
   economy.json + tiers.json por path, corre `PacingSimulator(config:tiers:).run()`
   e imprime el Report (y CSV opcional a Docs/).
2. Iterar knobs de economy.json hasta acercarse a targets (ver §4). Si cambia
   `yieldGrowthPerTier` → regenerar tiers.json.
3. `PacingTests` en **FisuEvolutionTests** (carga el bundle real, como
   GameContentValidationTests) con los 4 asserts ±30%. Nota: el sim corre 50+ h
   simuladas en milisegundos (reloj por salto de evento) — apto CI.

### 5.3 Commits de cierre de F7.1
- Commit A: todo el working tree actual + tests migrados verdes
  (`feat(f7.1): economía v2 — torre, PlayerState v4 run/meta, migración, hire por piso`).
- Commit B: pacing-sim + PacingTests + calibración
  (`feat(f7.1): simulador de pacing + calibración inicial`).
- Después de commitear: `graphify update .`.

## 6. Fases siguientes (el detalle vive en `Docs/PLAN-F7-torre.md`)

- **F7.2**: SKCameraNode + FloorNode apilados (offset = alto de pantalla), lazy ±1
  (isPaused + descarga de texturas), reveal/flash/labels re-parenteados a la
  cámara (hoy van a `self` — con cámara quedarían fuera de pantalla), arbitraje
  de gestos (personaje = pipeline actual; vacío = swipe |dy|>48 y >1.5|dx|; clamp
  asomarse 1 piso bloqueado con scrim+candado), ascenso animado (clon + vuelo
  0.7s; cámara sigue solo el 1er unlock), flechas SwiftUI estilo hudIconButton +
  pill "Callejón · 1/11 · 7/10", `requestFloorChange` con proyección versionada,
  nombres de piso ×11 en xcstrings (+fix key faltante `hud.settings.label`),
  income/sec total en HUD. Gate: 60fps con 5 pisos poblados.
- **F7.3**: SpawnButton contextual ("Contratar <TierBase>"), toast merge bloqueado,
  celebración de unlock, tutorial +2 pasos, borrar stageFallbackColors si se desea
  (o dejar fallback), strings hardcodeados del tutorial a xcstrings.
- **F7.4**: upgrades.json currency "oro" (decodeIfPresent default .coins),
  UpgradeManager debita meta.oro, UpgradesView 2 tabs [Personajes|Permanentes]
  (vectoriales), PrestigeView→Reencarnación con ORO, proyecciones
  oroGainPreview/canReincarnate renombradas, buyCharUpgrade(typeId:), OroIcon
  vectorial en GameArt.swift.
- **F7.5**: skins.json (catálogo: 3 tintes IAP characterType:"*" + texture per-type
  `<baseKey>__<skinId>`), SkinsConfig en EconomyKit, SkinMilestones
  (floorReached/reincarnations), SkinResolver reescrito (.base/.tint/.texture),
  UIArt con atlas parametrizable + cache clave compuesta + characterImage +
  silueta .template PaletteInk, CharacterSheetView (ELIMINA PassiveUnlockView;
  retrato+flechas skins+siluetas no equipables+passive+despedir CON confirmación),
  celebración milestone gateada por tutorial.
- **F7.6**: grid del sim sobre 6 knobs → Docs/balance-run-f7.csv → config final +
  re-pin GameContentValidationTests; drill de extensibilidad (piso 12 + personaje
  + skin dummy, cero código) como test permanente; icono ORO por pipeline
  (Tools/asset-pipeline, prompt basado en ui_coin — ÚNICO asset a generar);
  haptics/SFX; Reduce Motion en cámara; ESTADO.md + bitácora de sesión.

## 7. Gotchas conocidas (ahorrate los tropiezos)

1. `GameContentValidationTests` y TODAS las suites viejas NO COMPILAN hasta migrarlas
   — no corras `xcodebuild test` esperando verde antes de eso.
2. `SpawnButtonView`/`RootView`/`PrestigeView` usan los NOMBRES viejos
   (spawnQuote/canAffordSpawn/prestigeAvailable/prestigeSoulPointsGained) a
   propósito — el rename de cara al usuario es de F7.4. No "arreglarlos" antes.
3. El `.merged` de `DropResolution` tiene 4 campos con labels — al hacer switch,
   matchear con labels o `_`.
4. `chosenCareerPath` en migración: solo insertar si es String (NSNull rompe
   JSONSerialization).
5. El puente de skins (setActiveSkin aplica a todos los tipos) es INTENCIONAL
   hasta F7.5.
6. La escena renderiza un piso: `characterNodes` está keyed por SLOT del piso
   visible. `cellIndex(at:)`/hit-testing sin cambios (operan en slots).
7. En el sim iPhone 16 hay un save v4 YA migrado de un v3 con maxTier 30 — útil
   para probar late-game; para probar early-game usar `--uitest-reset` o
   `xcrun simctl uninstall`/DebugPanel "Resetear partida".
8. El agente anterior de tests murió por **límite de sesión de API** (resets 3pm
   America/Buenos_Aires) — si delegás a subagentes y fallan con ese error,
   trabajá inline.
9. `Tools/generate-tiers` decodifica `EconomyConfig` completo del paquete — si
   cambiás el config, la tool sigue compilando sola (depende por path).
10. DebugPanel todavía no tiene selector de piso (planeado en F7.1, no crítico:
    `setVisibleFloor` existe en GameState; agregarlo es 5 líneas en DebugPanelView).

## 8. Tracking de tasks de la sesión (para reconstruir el tablero)

Completadas: build+QA visual inicial, auditoría de arte end-to-end (artifact
"FisuEvolution — Auditoría visual end-to-end"), fixes P0/P1/P2 de UI (commits
previos a F7 en working tree... NO: esos fixes SÍ están commiteados? — verificar:
los fixes de UI de la sesión anterior estaban sin commitear ANTES de F7.0; el
commit `d7cf370` solo incluyó los docs. **Los fixes de UI visual (HUD unificado,
GameToggle, CurrencyPill, PanelTitleBanner, splash, gating de tutorial, etc.)
están MEZCLADOS en el working tree con F7.1** — al commitear F7.1 van a entrar
juntos; si se quiere separarlos, hacer primero un commit de los archivos de UI
puros (GameArt.swift, RootView.swift, HUDView.swift, SpawnButtonView.swift,
ConfigView.swift, popups, StoreView/BonusView) y después el resto).
Pendientes: F7.1 tests+sim+commits → F7.2 → F7.3 → F7.4 → F7.5 → F7.6.

## 9. Contexto de producto (por qué esto importa)

El dueño quiere un juego MUCHO más largo y difícil, con acabado high-end,
consistencia visual hand-made (paleta #FFD93D/#FF6B35/#FF4D6D/#4D96FF/#6BCB77 +
crema #FFF8E7/ink #2C2C2C, SF Rounded pesada en títulos/números, iconos círculo
crema + borde ink 3pt, UI chica = vector nativo, PNG solo para lo ilustrativo).
La auditoría visual completa y sus pendientes de arte viven en el artifact
publicado y en los P1 de arte (piso unificado entre fondos, poses del mascota,
fuente de marca) — NO son parte de F7 pero no romperlos.
