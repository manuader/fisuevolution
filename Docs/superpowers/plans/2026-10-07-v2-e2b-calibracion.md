# E2b — Calibración final y contrato de pacing · plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: `superpowers:subagent-driven-development`
> (recomendada) o `superpowers:executing-plans`, tarea por tarea. Los pasos usan checkbox
> (`- [ ]`). Cada tarea con oráculo corre además el bucle del harness AVO (journal del run en
> `FisuEvolution/.claude/avo/2026-10-06-fisu-v2/journal.md`, en el checkout principal); **T13
> (la búsqueda) es un run AVO en sí misma**.

**Goal:** que el rojo declarado `PacingTests.theOwnersTargetsAreMet` deje de existir porque lo
reemplaza **el contrato de pacing de la 2.0, en verde**: Dios en 31–35 h activas con un bot que
reencarna al multiplicar ×5 su ORO, 5–6 reencarnaciones, las 7 líneas (a 348 ORO) al máximo
después de la 5ª reencarnación y antes del 80 % del camino, cada run más lejos y más rápida, y
los tiempos por piso del dueño; medido con un simulador que juega con las mismas fuentes de
economía que el jugador gratis, el que mira anuncios y el que paga.

**Architecture:** dos fases. **A — el instrumento** (T1–T11): EconomyKit suma la escalada por
bandas, la curva por piso y la herencia de pasivos **detrás de perillas que valen la v1**; el
`PacingSimulator` pasa a cobrar con las funciones del juego (pasivo, offline, descuento de
prestigio), aprende la política de pisos en marcha y juega **perfiles** (`.bare`, `.free`,
`.ads`, `.max`) alimentados por un `PacingSources` puro que arma el llamador desde el contenido
real; el CLI expone cada perilla; la suite del contrato nace con sus asserts apagados. Con todo
en v1 el simulador sigue reproduciendo la línea de base exacta. **B — la calibración** (T12–T14):
se mide cada mecánica en el orden de PLAN-v2, se busca la configuración que cumple el contrato, y
una sola tarea la declara en los JSON, re-pinea lo que se mueve, prende el contrato y retira
`theOwnersTargetsAreMet`.

**Tech Stack:** Swift 6 (strict concurrency `complete`, warnings como errores) · EconomyKit
(SPM puro, `Sendable`) · Swift Testing · `Tools/pacing-sim` (SPM ejecutable) · XcodeGen (el
`.xcodeproj` no se versiona).

**Fuente:** `Docs/PLAN-v2.md` §4 "E2 — Economía y pacing", **la parte E2b**, y §2 (decisiones del
dueño: **no se re-litigan**). Insumos: "Lo que E2a le deja a otras épicas" y la tabla de perillas
del plan de E2a; las bullets "E2b" de los planes de E4a, E4b, E5a, E6a, E6b y E7b-b; la nota de
E1 T16 ("el offline del simulador no pasa por `OfflineCalculator`"); `tasks.md` §5 E2b y el punto
4 de "Inconsistencias"; `Docs/balance-log.md` (cuarta y quinta ronda); `Docs/HANDOFF.md` §5 (las
diez decisiones de balance numeradas, y las de la 2.0 que las reemplazan). Lo que el código o
los planes contradicen está en "Para el dueño / dudas", con un default que no frena.

**Rama de la épica:** `v2/e2b-calibracion`, desde `version-2` **con E2a cerrada (E2a T15)**. Cada
tarea sale de su punta en un worktree propio (`Agent(isolation: "worktree")`, PLAN-v2 §0.1) y el
controlador integra de a una.

## Global Constraints

- `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` y `SWIFT_STRICT_CONCURRENCY: complete`: un warning rompe
  el build (una `var` que no se muta, también).
- **Fase A no cambia el juego.** Toda perilla nueva se lee con `decodeIfPresent ?? <valor v1>`,
  `economy.json` no la declara hasta T14, y el `pacing-sim` del oráculo (que corre con el perfil
  `.bare` y la política de siempre hasta T14) sigue imprimiendo **la línea de base vigente al
  cerrar E2a** (`Dios en 30,73 h · 13 reencarnaciones`, o la que E2a T15 dejó anotada en
  `Docs/HANDOFF.md` §6). Un número distinto en fase A es una perilla que se coló: se busca antes
  de integrar.
- **El simulador no reimplementa nada** (trampa "duplicar la fórmula fue lo que llevó a que el
  simulador cotizara distinto que el juego"): cotiza con `TowerActions.hireQuote`, compra con
  `registerHire`, fusiona con `refundMergeCounts`/`raiseFrontier(to:cushion:)`, cobra el pasivo
  con `IncomeTicker.basePassivePerSecond`, el offline con `OfflineCalculator.earnings`, los premios
  con `RewardScale.coinPayout`, reencarna con `PrestigeCalculator`. Lo que no puede reusar (no
  tiene torre) lo pinea un test contra la función del juego.
- **Ningún campo nuevo en `run` ni en `meta`** (plan de E1: uno más es save v7). La herencia de
  pasivos viaja en `run.passiveUnlocked` de una run a la siguiente (duda 11).
- **Un parámetro que es una garantía va sin default** (HANDOFF §7). Los parámetros nuevos del
  simulador que **son** la v1 cuando faltan (`prestigeUnlocks: nil`, `profile: .bare`,
  `sources: .none`) sí llevan default: es lo que mantiene a los llamadores de hoy midiendo lo mismo.
- **Determinístico.** El simulador no tira dados: lo que en el juego es azar (paquete, ruleta,
  colchón) entra por **valor esperado con acumuladores fraccionarios**, arrancando en
  `seedFraction` (default 0,5). Dos corridas con la misma entrada dan el mismo reporte.
- **El contrato se mide en el reloj del simulador**, con el perfil `.free` y la política
  `.whenOroMultiplies(4)` (×5 por reencarnación, PLAN-v2 §2). Las bandas viejas de `PacingTests`
  (±30 % de la conducta) se re-pinean recién en T14.
- **`EconomyKitTests` no tiene recursos**: sus tests van con `fx*`/`up*`; los hechos de los JSON
  reales se pinean del lado de la app (`GameContentValidationTests`, `PacingContractTests`).
- **El `.xcodeproj` no se versiona: `/opt/homebrew/bin/xcodegen generate`** al agregar o borrar
  un archivo Swift de la app o de sus tests, en el mismo paso. Un archivo nuevo del paquete o de
  `Tools/pacing-sim` no lo pide.
- **Strings nuevos, es + en, por snapshot** `Tools/v2/claves-pendientes/e2b-tN.json` y
  `Tools/v2/catalogo.py aplicar` (formato canónico, trampa 29). Sólo T11 tiene strings.
- **Siempre `--upgrades` explícito** al correr `pacing-sim` sobre un `economy.json` que no está en
  `Resources/Data` (trampa 39), y **siempre la línea de base primero** (trampa 40: el sanity check
  es lo que destapa una corrida mal armada). Desde T8 también `--sources` explícito.
- Código nuevo limpio y con pocos comentarios (regla del dueño); los heredados no se borran por
  deporte, pero **el que deja de ser verdad se reescribe en el mismo commit** (los docstrings de
  `PacingTests` y de `hireCost` que hablan de "8 reencarnaciones", "1,6 desde el tier 7" y "193").
- **Commits en español, estilo `feat(pacing): …` / `test(pacing): …` / `chore(balance): …`, SIN
  `Co-Authored-By`.** Staging selectivo por archivo y `git diff --cached --stat` antes de cada
  commit.
- **Al cerrar cada tarea** (lo hace el controlador, nunca un subagente): integración →
  `Tools/v2/oraculo.sh rapido` (o `completo` donde la tarea lo dice) →
  `Docs/SESION-<fecha>-v2-e2b.md` → las cuatro ediciones de `Docs/HANDOFF.md` → journal AVO y latido
  del `LOCK`. Ningún subagente toca `Docs/HANDOFF.md`, `Docs/SESION-*`, `Docs/balance-log.md`,
  `handoffs/`, el journal ni `Tools/v2/rojos-declarados.txt`. Las corridas de calibración sí
  commitean su CSV en `Docs/balance-run-v2-e2b-*.csv` (archivos nuevos, como las rondas de la v1).

## Verificación (vale para toda tarea)

**El oráculo del run** juzga cada commit integrado:

```bash
Tools/v2/oraculo.sh rapido            # EconomyKit + xcodegen + build + unit (iOS 26.5) + Release
Tools/v2/oraculo.sh completo          # + Store (18.6) + UI en la matriz + pipeline + pacing-sim
```

- Termina en 0 (`VERDE`) sólo si todo está verde salvo `Tools/v2/rojos-declarados.txt`, que hasta
  T14 tiene la línea `unit theOwnersTargetsAreMet`. **E2b no declara rojos nuevos.** En T14 ese rojo
  desaparece (el test se borra); el controlador saca la línea al integrar.
- Un VERDE con la misma cuenta de tests que antes de sumar tests no probó nada (HANDOFF §6).
- `rapido` al cerrar T1–T8 y T10. `completo` al cerrar T9 (suma una suite cara a unit), T11 (UI),
  T14 (cambia la capacidad de los pisos: la escena y los UI tests) y T15.
- **El paso `pacing-sim` del `completo` es el juez de "la fase A no mueve el juego"**: hasta T14
  imprime la línea de base vigente. Desde T14 imprime el contrato (`.free`, ×5).

**Receta R — correr UNA suite para ver el rojo y el verde:**

```bash
# EconomyKit: --filter matchea el NOMBRE DEL TIPO, no el @Suite("…")
swift test --package-path Packages/EconomyKit --filter "EscalationBandsTests|EconomyKnobsTests"
```

```bash
# App: simulador propio por UDID, DerivedData absoluto, filtro por SUITE
WT="$(git rev-parse --show-toplevel)"
UDID=$(xcrun simctl create "e2b-$(basename "$WT")" "iPhone 16 Pro" com.apple.CoreSimulator.SimRuntime.iOS-26-5)
/opt/homebrew/bin/xcodegen generate
xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e2b" \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator \
  -destination "id=$UDID" -derivedDataPath "$WT/build/DD-e2b" -parallel-testing-enabled NO \
  -only-testing:FisuEvolutionTests/PacingContractTests
xcrun simctl shutdown "$UDID"; xcrun simctl delete "$UDID"
```

**Receta P — una corrida del simulador** (desde T8; antes, sin los flags nuevos):

```bash
R=FisuEvolution/Resources
swift run -c release --package-path Tools/pacing-sim pacing-sim \
  --economy $R/Data/economy.json --tiers $R/Data/tiers.json \
  --upgrades $R/Config/upgrades.json --sources $R/Config \
  --profile free --prestige-threshold 4 --max-days 400 --csv build/e2b/<nombre>.csv
```

⚠️ **Una corrida que no nombra los tests esperados no probó nada** ("0 tests" con éxito es el
modo de falla de `--filter` y de `-only-testing:`). Ante un rojo en masa, antes de culpar al
código: `uptime`, `ps aux | grep '[x]codebuild'` y qué árbol compiló (trampas 16, 33 y 44).

## Las referencias, verificadas contra el árbol (`32d1300`)

Las líneas son de `32d1300`; E2a mueve casi todas. **El paso 0 de cada tarea las busca con
`grep`**, nunca por número.

| Lo que cita PLAN-v2 o un plan hermano | Dónde está hoy | Qué significa para E2b |
|---|---|---|
| el rojo `theOwnersTargetsAreMet` | `FisuEvolutionTests/PacingTests.swift:437-452`; declarado en `Tools/v2/rojos-declarados.txt` (`unit theOwnersTargetsAreMet`) | T14 lo borra junto con su docstring; el contrato nuevo vive en `PacingContractTests` (T9) |
| `PacingTests` corre una simulación entera **por test** | su `init` (`:128-137`): swift-testing construye una instancia por test, ocho simulaciones | T9 la reemplaza por un caché `static` (`PacingReports`), "el reporte cacheado" de PLAN-v2 |
| la escalada (`frontierEscalationPerTier` 1,6 desde 7) | `EconomyConfig.swift:440-450` (`hireCost`), y **duplicada** en `PriceCushion.jump` (E2a T3, plan E2a `:1142-1147`) | T1: una sola función `HireConfig.escalation(atFrontier:)` para las dos |
| el pin de la escalada | `GameContentValidationTests.swift:166-167` y `hirePricesFollowTheOwnersRule` (`:405-450`, que recalcula la escalada a mano) | T14 los re-pinea a las bandas, con el literal de las bandas (no con la función: trampa 24) |
| "g +0,01 por piso desde luxury" | `hireCostGrowth(for:)` `EconomyConfig.swift:365-367` = override ?? default; `floorHireOverridesMatchTunedValues` dice que **los únicos overrides legítimos son los dos del callejón** | T1 lo hace perilla de config (`costGrowthStepPerFloor`), no overrides por piso |
| el descuento de prestigio | `prestige_unlocks.json` (5 %/5 %/5 %/10 %/10 %, tope 0,5), aplicado por la app en `GameState+Hiring.swift:314` y `GameState.swift:992` (`costMultiplier: 1 − descuento`) | **el simulador no lo cobra** (`PacingSimulator.swift:576-579` cotiza sin `costMultiplier`): T3 lo suma detrás de `prestigeUnlocks: nil` |
| el offline del simulador | `PacingSimulator.swift:890-895`, fórmula propia (nota de E1 T16) | T3: `OfflineCalculator.earnings` |
| el pasivo del simulador | `PacingSimulator.swift:785-794`, copia de `IncomeTicker.basePassivePerSecond` (`IncomeTicker.swift:14-29`) | T3: la función del juego (E2a T4 ya le suma `StaffedFloors`) |
| `floorUnlockHireSeconds`, `peakHire` | `PacingSimulator.swift:917-966`, con `config.hireCost` pelado | T3: por `TowerActions.hireQuote` (aviso 7 de E2a) |
| reencarnar | `PrestigeCalculator.applyReincarnation` (`PrestigeCalculator.swift:17-35`): `run = .fresh` | T2: la herencia de pasivos, ahí (lo comparten app y simulador) |
| `run.passiveUnlocked` de una run nueva | `RunState.fresh` (`PlayerState.swift:~188`: `passiveUnlocked: [:]`) | T2 lo llena **después** de `.fresh` |
| los boosts gratis con cooldown | `boosts.json`: mate (contratar ×0,7 · 60 s · 30 min), café (toque ×2 · 45 s · 45 min), fernet (×3 · 90 s · 1 h), milanesa (offline +0,05 permanente · 1 día), asado (picada · 6 h), turbo (×5 · 30 s · 2 h); se activan **sin video** (`GameState+Bonus.activateBoost`); el video sólo saltea el cooldown (`+AdOffers.activateBoostFromAd`) | **el simulador no modela ninguno**: T5 los suma al perfil `.free` (duda 6) |
| el tope del offline | `EffectCaps.offline = 1.0` (`EffectDescriptor.swift:16-21`, app) | lo pasa el llamador en `PacingSources` (la milanesa topea ahí) |
| capacidad 10 | `economy.json` diez pisos; pin `GameContentValidationTests.swift:594` | T14 la pasa a 15 (E2a duda 2, E5a, E6b duda 1) |
| las 7 líneas, 193 ORO | `upgrades.json` (`baseCost` 1); pin `upgradeCatalogMatchesTunedValues` (`:250-292`, `total == 193`) | T14: `baseCost` 2 = **348** (verificado: Σ⌈2·g^l⌉ sobre los diez niveles de las siete = 348) |
| los 12 logros de ORO | `fixedOroAchievementsFundAFifthOfTheRun` (`:303-327`): suman 33 **y** son el 15–20 % de maxear | con 348, 33 es el 9,5 %: T14 los duplica (66 = 19,0 %, duda 5) |
| el CLI | `Tools/pacing-sim/Sources/main.swift`: `--economy --tiers --upgrades --max-days --csv --prestige-threshold --no-reincarnation`; imprime los targets de F7.1c | T8 suma los perfiles, las fuentes y las perillas; imprime el contrato 2.0 |
| el oráculo lee del reporte | `Tools/v2/oraculo.sh:114-124` (`grep '^  dios:'`, `'^  reencarnaciones:'`) | T8 conserva el formato de esas dos líneas: el oráculo no se toca |

## Lo que E2b consume de otras épicas (todavía NO está en el árbol)

Se citan como los "Produces" de sus planes. **El paso 0 de cada tarea comprueba con `grep` que lo
que usa existe**; si falta, para con `NEEDS_CONTEXT` y no inventa la API.

| Épica · tarea | API | La usan |
|---|---|---|
| **E2a T1** | `RewardScale.coinPayout(seconds:state:tiers:floorTable:config:)`, `coinPayout(minutes:…)`, `productionPerSecond(…)` | T5, T6 |
| **E2a T2–T5** | `EconomyKnobs` (5 campos) + `EconomyConfig.tuned(_:)`; `hire.mergeRefundCounts`, `hire.priceReliefPurchases`, `staffedFloorBonus`/`staffedBonusPerFloor`, `oro.requiresLastRunWall`/`requiresWall`; `RunState.refundMergeCounts`; `PriceCushion` (con `jump(from:to:)`); `StaffedFloors.ordinals/multiplier`; `PrestigeCalculator.lastRunWallGoal`; `PacingSimulator.wantsToReincarnate`, `Report.maxTierPerRun`; helper privado `fingerprint(_:)` y `upConfig(maxTier:gateTierDistance:capacity:)` en `PacingSimulatorTests.swift` | T1–T4, T8 |
| **E2a T8** | `PrestigeButton`/`PrestigeView` con la meta del piso móvil; `PrestigePreviewTests` | T11 |
| **E2a T11** | `DailyRewardsConfig.Day.minutes`; `RewardBudgetTests` (con `productionMinutesPerDay`, `asadoClaimsPerDay`, privados) | T5 (mapeo), T10 |
| **E2a T12** | `ActiveModifier.Effect.freeHire`; `hireQuote(…now:)` cotiza 0 mientras vive; `careers.json` `junior_programmer` `{ "rewardKind": "freeHires", "durationSeconds": 120 }` | T5 |
| **E2a T14** | el panel de debug con las variantes (g, r) y el amortiguador → **el playtest del dueño** (gate) | T12 |
| **E2a T15** | la tabla de perillas medidas una por una | T12 (primer punto) |
| **E4a T1** | `RewardSpec` (12 casos) y `validate()` | T6 |
| **E4a T7, T9** | `GameContent.visitors: VisitorsConfig` (`coinsSecondsScale`, `intervalMinSeconds`, `intervalMaxSeconds`, `scripts[].weight`, `scripts[].mechanic.rewards`); `events.json` v2 (`EventCatalog`: `intervalSeconds`, `events[].weight/polarity/effects`) | T10 |
| **E5a T1–T3, T5** | `PackagesConfig` (`spawnIntervalSeconds`, `firstPackageAfterSeconds`, `maxWaiting`, `windowTiers`, `tierRatio(bestSupplierLevel:)`), `PackageRoller.odds(eligible:windowTiers:ratio:)`, `PackageRoller.eligibleTypes(state:tower:tiers:floorTable:config:)`; `TreasuresConfig` (`spawnIntervalSeconds`, `extraOpensPerTreasure`, `prizes`, `odds`); `WheelConfig` (`videoSpinsPerDay`, `effectiveSegments(chestHasSomethingToGive:)`, `odds(…)`); `GameContent.packages/.treasures/.wheel` | T5, T6, T9 |
| **E4a T8** | `grant(.oro)` en `GameState+Rewards.swift`: **qué campos** toca (`meta.oro` sólo, o también `oroEarnedLifetime`) | T6 (el simulador hace lo mismo) |
| **E6a T2, T4** | `OroShop.extraSlots(levels:catalog:)`, `bestSupplierLevel(levels:catalog:)`, `bonusDailyWheelSpins(levels:catalog:)`; `GameContent.oroShop`; los precios de los consumibles | T7, T9, T10 |
| **E6b T6** | `FloorTable.expanded(by:)` | T7 |
| **E7b-a T3** | `RewardedAdsConfig.AdBreak` (`prizes: [RewardSpec]`), la cadencia de cortes de `ads.json` | T6, T9 |
| **E7b-b T1, T2** | `RewardedAdsConfig.SideRail` (`mergeAllCooldownSeconds`, `packageRainCooldownSeconds`, `packageRain: RewardSpec`); diario ×2 y carrera ×2 por video (T6) | T6, T9 |

## Las perillas de E2b en una página

Todas nacen apagadas (= v1). T14 las declara con el valor que salga de T13; la columna "punto de
partida" es lo que PLAN-v2 propone y de donde arranca la búsqueda.

| Perilla | Dónde (`economy.json`) | v1 = default | Qué hace | Punto de partida (PLAN-v2) | T |
|---|---|---|---|---|---|
| `hire.escalationBands` | `hire` | ausente (= `frontierEscalationPerTier` desde `frontierEscalationFromTier`) | cada tier de frontera `t` encarece por el factor de su banda | `[{8: 1,45}, {13: 1,6}, {25: 1,7}]` | 1 |
| `hire.costGrowthStepPerFloor` + `costGrowthStepFromFloorId` | `hire` | ausente (0) | suma a la curva por compra de cada piso desde el indicado (sin tocar los overrides) | 0,01 desde `luxury` | 1 |
| `oro.inheritsPassiveUnlocks` | `oro` | ausente (`false`) | reencarnar conserva los pasivos desbloqueados | `true` (decisión del dueño) | 2 |
| `floors[].capacity` | `floors` | 10 | lugares por piso | 15 | 14 |
| `staffedFloorBonus` | raíz (E2a) | ausente (0) | pisos en marcha | 0,05 | 14 |
| `oro.requiresLastRunWall` | `oro` (E2a) | ausente (`false`) | piso móvil | `true` | 14 |
| `hire.priceReliefPurchases` | `hire` (E2a) | ausente (0) | el amortiguador | 24 (o lo del playtest) | 14 |
| `hire.defaultCostGrowth` + `hire.mergeRefundCounts` | `hire` (E2a) | 1,06 · 0 | la curva y el reintegro, en par | el par del playtest; si no hay, (1,12 · 1) | 14 |
| `oro.divisor`, `oro.exponent` | `oro` | 1e10 · 0,25 | cuánto ORO da la run | lo que dé la ley de diseño (abajo) | 14 |
| `upgrades.json` `baseCost` | las siete | 1 (193 ORO) | lo que cuesta maxear | 2 (348) | 14 |

Del lado del simulador (no son del juego): `PacingSimulator(…, prestigeUnlocks:, profile:,
sources:, seedFraction:)` y los flags del CLI (T8).

## El contrato en una página

Reloj del simulador, perfil `.free`, política `.whenOroMultiplies(4)`. Cada número es de PLAN-v2
E2b; lo que se interpreta está en la duda que lo nombra.

| # | Assert | Serie del reporte |
|---|---|---|
| 1 | Dios entre **1.900 y 2.100 min activos** (31,7–35 h; la intersección con el punto 7, duda 3) | `godActive` |
| 2 | **5 o 6** reencarnaciones (4–6 de PLAN-v2 ∩ el punto 3, duda 2) | `reincarnations` |
| 3 | las 7 líneas al tope **antes del 80 %** del tiempo de Dios **y no antes de la 5ª** reencarnación | `maxedUpgradesActiveSeconds`, `reincarnationsAtMaxedUpgrades` |
| 4 | 1ª reencarnación entre **0,75 y 1,5 h activas** | `firstReincarnationActive` |
| 5 | cada run llega **al menos un tier más lejos**, y llega **antes** a cada tier que la anterior ya vio | `maxTierPerRun`, `tierReachedPerRun` |
| 6 | reencarnar paga **≥ 65 %** de la run 2 en adelante (duda 1: el techo) | `prestigePayoffPerRun` |
| 7 | primera llegada por piso (min activos): urban ≤ 1,5 · corporate 6–10 · luxury 35–60 · island 200–300 · moon 520–680 · mars 900–1.100 · solar 1.350–1.550 · galaxy 1.650–1.850 · Dios 1.900–2.100 | `floorUnlockActiveSeconds` |
| 8 | sin reencarnar no se llega a Dios (400 días) | `godActive` de `.never` |
| 9 | `.ads` tarda ≥ 55 % de lo que tarda `.free`; `.max` ≥ 50 % | `godActive` de los tres perfiles |
| — | guarda de la escala del ORO (§2: "un jugador gratis junta ~12.000 hasta Dios"): **5.000–12.000** | `oroAtGod` |

**La ley de diseño** (PLAN-v2): `R ≈ ln(ORO_dios / ORO₁) / ln(1 + m)`, con `m = 4`. Con ORO₁ ≈ 1–2
(el mínimo para reencarnar es 1) y ORO_dios ≈ 5–12k, `R ≈ 5–6`. Y el ORO acumulado tras la
k-ésima reencarnación es ≈ `ORO₁ · 5^(k−1)`: 1 · 5 · 25 · 125 · **625** → con las líneas a **348**
la quinta es la primera que alcanza a maxear, que es exactamente el punto 3. Los 66 de los logros
(duda 5) no cambian la cuenta (125 + 66 < 348). Es la aritmética que T13 tiene que ver confirmada
por el simulador, no un sustituto de él.

## Los perfiles en una página

| Perfil | Qué juega | Para qué |
|---|---|---|
| `.bare` | el bot de siempre, sin fuentes | la línea de base (el default hasta T14) |
| `.free` | + lo que el juego da **sin video ni compra**: el Paquete de la Aduana (cada 2 min de juego), el diario base, los boosts gratis con cooldown (fernet, turbo, café, asado, milanesa), el premio de la carrera (Programador: contrataciones gratis 120 s) | **el contrato** |
| `.ads` | `.free` + los videos: offline ×2, diario ×2, ruleta (6/día + "repetir premio"), colchón (+ "otro colchón"), pausa publicitaria (premio rotativo), "Fusionar todo" por video, lluvia de paquetes, carrera ×2. Cada video cuesta `videoSeconds` (30) de sesión | guarda 9 |
| `.max` | `.ads` + los permanentes de la tienda al tope desde el arranque: lugares extra (+5), mejor proveedor (nivel 3), +3 giros diarios | guarda 9 |

**Fuera del simulador, con presupuesto analítico (T10):** visitantes, eventos, consumibles de ORO
y el ORO de los logros. **Fuera de todo (declarado):** los especiales y su efecto pasivo, el bono
de compartir, el crítico y el toque dorado (el bot no tira dados), los cofres de pintas (sólo
skins), el Mate (descuento de 60 s) y el cofre de la ruleta.

Un premio que en el juego es un modificador temporal de ingresos (×k por T s) entra al simulador
como **una suma de producción** `(k − 1) · T` segundos por `RewardScale.coinPayout(seconds:)`
(la misma unidad en que la 2.0 paga los premios); uno de toque, como `(k − 1) · T` segundos del
ingreso por toque del momento. Es la única aproximación de modelado de E2b y está declarada (duda
9): el reloj del bot salta por evento y no puede integrar un multiplicador que vence en el medio
de una espera.

## Estructura de archivos

| Archivo | Responsabilidad | T |
|---|---|---|
| `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` | `EscalationBand`, `escalationBands`, `costGrowthStepPerFloor`, `costGrowthStepFromFloorId`, `HireConfig.escalation(atFrontier:)`; `OroConfig.inheritsPassiveUnlocks` | 1, 2 |
| `Packages/EconomyKit/Sources/EconomyKit/PriceCushion.swift` (E2a) | `jump` por `escalation(atFrontier:)` | 1 |
| `Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift` (E2a) | las perillas nuevas; T8: `floorCapacity`, `oroDivisor`, `oroExponent` | 1, 2, 8 |
| `Packages/EconomyKit/Sources/EconomyKit/PrestigeCalculator.swift` | `inheritedPassiveUnlocks(state:economy:)` y su uso en `applyReincarnation` | 2 |
| `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` | fidelidad (T3), política de pisos (T4), fuentes (T5–T7) | 2–7 |
| `Packages/EconomyKit/Sources/EconomyKit/PacingProfile.swift` | **nuevo** — `PacingProfile`, `PacingSources` y sus tipos | 5–7 |
| `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator+Sources.swift` | **nuevo** — el reloj de las fuentes y `ExpectedRewards` (acumuladores) | 5–7 |
| archivo de `PackageRoller` (E5a T1) | `eligibleTypes(state:tiers:floorTable:config:occupancy:)` sin torre | 5 |
| tests EK | `EscalationBandsTests`, `PassiveInheritanceTests`, `SimulatorFidelityTests`, `StaffingPolicyTests`, `PacingProfileTests` (nuevos) + `EconomyKnobsTests`, `PriceCushionTests`, `PacingSimulatorTests` | 1–7 |
| `Tools/pacing-sim/Sources/main.swift` | perfiles, fuentes, perillas, el contrato impreso | 8 |
| `FisuEvolutionTests/Support/PacingFixture.swift` | **nuevo** — `PacingFixture.sources(_:)`, `.simulator(…)`, `PacingReports` (el caché) | 9 |
| `FisuEvolutionTests/PacingContractTests.swift` | **nuevo** — el contrato (apagado hasta T14) | 9, 14 |
| `FisuEvolutionTests/RewardBudgetTests.swift` (E2a) | suite `EngagementBudgetTests` | 10 |
| `Resources/Config/visitors.json` (E4a) | `coinsSecondsScale` calibrado | 10 |
| `FisuEvolution/Game/State/GameState+Prestige.swift`, `UI/Popups/PrestigeView.swift` | "Se conservan los pasivos de N personajes" | 11 |
| `Docs/balance-run-v2-e2b-*.csv` | las corridas | 12, 13 |
| `Resources/Data/economy.json`, `Resources/Config/upgrades.json`, `achievements.json` (+ los que T13 mueva) | la calibración | 14 |
| `FisuEvolutionTests/PacingTests.swift`, `GameContentValidationTests.swift`, `AchievementEngineTests.swift` | re-pin; `theOwnersTargetsAreMet` se va | 14 |

## Orden, olas y paralelismo

**Archivos por tarea** (🔥 = caliente según PLAN-v2 §0.1 / `tasks.md` §3.1; ♨️ = tibio según
`tasks.md` §3.2 o porque otra épica lo toca en la misma ventana):

| T | Qué | Archivos | 🔥 / ♨️ | Depende de | Modelo |
|---|---|---|---|---|---|
| T1 | bandas y curva por piso (EK) | `EconomyConfig.swift`, `PriceCushion.swift`, `EconomyKnobs.swift`, `EscalationBandsTests.swift`, `EconomyKnobsTests.swift`, `PriceCushionTests.swift` | — | **E2a-T3, E2a-T5** | sonnet |
| T2 | herencia de pasivos (EK) | `EconomyConfig.swift`, `PrestigeCalculator.swift`, `EconomyKnobs.swift`, `PacingSimulator.swift`, `PassiveInheritanceTests.swift`, `EconomyKnobsTests.swift`, `PacingSimulatorTests.swift` | — | T1; **E2a-T5**, **E1-T4** | sonnet |
| T3 | el simulador cobra como el juego (EK) | `PacingSimulator.swift`, `SimulatorFidelityTests.swift`, `PacingSimulatorTests.swift` | — | T2; **E2a-T3, E2a-T4, E2a-T5** | sonnet |
| T4 | la política de pisos en marcha (EK) | `PacingSimulator.swift`, `StaffingPolicyTests.swift`, `PacingSimulatorTests.swift` | — | T3; **E2a-T4** | **opus** (regla del bot) |
| T5 | perfiles y fuentes gratis (EK) | `PacingProfile.swift`, `PacingSimulator+Sources.swift`, `PacingSimulator.swift`, archivo de `PackageRoller`, `PacingProfileTests.swift` | ♨️ el archivo de `PackageRoller` (E5a T6 lo usa) | T4; **E2a-T1, E2a-T12, E5a-T1** | sonnet (revisión opus) |
| T6 | el perfil `.ads` (EK) | `PacingProfile.swift`, `PacingSimulator+Sources.swift`, `PacingSimulator.swift`, `PacingProfileTests.swift` | — | T5; **E4a-T1, E5a-T2, E5a-T3**; **E4a-T8** (qué toca `grant(.oro)`) | sonnet |
| T7 | el perfil `.max` (EK) | `PacingProfile.swift`, `PacingSimulator.swift`, `PacingProfileTests.swift` | — | T6; **E6a-T2, E6b-T6** | sonnet |
| T8 | el CLI | `Tools/pacing-sim/Sources/main.swift`, `EconomyKnobs.swift`, `EconomyKnobsTests.swift` | — | T7 | sonnet |
| T9 | la suite del contrato (apagada) | `Support/PacingFixture.swift`, `PacingContractTests.swift` | — | T8; **E5a-T5, E6a-T4, E7b-a-T3, E7b-b-T2, E2a-T11, E2a-T12** | sonnet |
| T10 | presupuestos analíticos | `RewardBudgetTests.swift`, `visitors.json` | ♨️ `visitors.json` (E4a/E4b) | **E2a-T11, E4a-T7, E4a-T9, E6a-T4** | sonnet |
| T11 | la herencia en pantalla | `GameState+Prestige.swift`, `PrestigeView.swift`, `PrestigePreviewTests.swift`, `claves-pendientes/e2b-t11.json` | catálogo (snapshot) | T2; **E2a-T8** | sonnet |
| T12 | medir cada mecánica, en orden | `Docs/balance-run-v2-e2b-mecanicas.csv` | — | T9; 🔒 **playtest E2a-T14** | sonnet |
| T13 | la búsqueda (run AVO) | `Docs/balance-run-v2-e2b-candidata.csv` | — | T12; **E4a-T10, E5a-T9, E6a-T13, E6b-T7, E7b-b-T8** | **opus** |
| T14 | declarar la calibración y prender el contrato | `economy.json`, `upgrades.json`, `achievements.json` (+ lo que T13 mueva), `PacingTests.swift`, `PacingContractTests.swift`, `GameContentValidationTests.swift`, `AchievementEngineTests.swift`, `main.swift` | ♨️ `GameContentValidationTests.swift` (E2a T7, E6b) | T13, T10, T11 | sonnet (revisión opus) |
| T15 | cierre | `Docs/` (controlador) | — | T1–T14 | controlador |

E2b **no toca** `GameState.swift`, `RootView.swift`, `BoardScene.swift`, `ContentSystems.swift`,
`GameState+Bonus.swift`, `TowerActions.swift`, `PlayerState.swift`, `SettingsView.swift`,
`project.yml` ni `Localizable.xcstrings` directo (sólo snapshot).

**Las olas:**

```
Tras E2a T15     T1 → T2 → T3 → T4                      EK puro; ∥ con E4–E7 (archivos disjuntos)
Con E5a T1 + E2a T12   T5 → T6 (con E5a T3 + E4a T1) → T7 (con E6a T2 + E6b T6) → T8
                 T11 (en cualquier hueco tras T2)       ∥ con lo anterior (app, sin 🔥)
Con E5a T5, E6a T4, E7b-b T2   T9                      completo
Con E4a T9, E6a T4   T10                                ∥ T9
🔒 playtest E2a T14   T12                               mediciones
Con E4–E7b cerradas   T13 → T14                         la calibración
Cierre           T15 (controlador)
```

**Reglas del paralelismo:**

1. T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 van en serie: comparten `PacingSimulator.swift`,
   `EconomyKnobs.swift` o `PacingProfile.swift`.
2. T1–T4 **no esperan a E4–E7**: sólo tocan lo que E2a dejó y nadie más edita en esa ventana.
   Pueden correr al lado de cualquier tarea de E4–E7 respetando el tope de compilación (≤ 3).
3. T5 toca el archivo de `PackageRoller` (E5a T1): no en paralelo con una tarea de E5a que lo
   edite.
4. T11 es app pura sin 🔥; va en cualquier hueco después de T2, de a una con otra tarea que toque
   `PrestigeView` o `+Prestige`.
5. T12–T14 son la calibración: T13 corre **con todas las fuentes integradas** (si una épica de
   fuentes reabre después de T14, el controlador corre T12 otra vez y, si el contrato se rompe, la
   arregla esa épica, no E2b).

### E2b antes o después de E9 (`tasks.md`, "Inconsistencias", punto 4)

**Propuesta: la fase A (T1–T11) corre apenas cierra E2a, en paralelo con E4–E7; la fase B
(T12–T14) corre cuando E7b-b cerró, en paralelo con E9, y T14 se integra antes del cierre de E9.**
E10 espera a las dos.

- **Por qué no "después de E9"** (el árbol de PLAN-v2 §4): E9 no suma ninguna fuente de economía
  (tutorial, Tour, Ajustes y reset: su watchdog libera "sin premio"), así que esperar a E9 no
  cambia una sola corrida. Y al revés sí: E2b cambia lo que el tutorial y el Tour enseñan (pisos de
  15, la herencia de pasivos, el piso móvil, las líneas a 348) y la capacidad que ven los UI tests.
  Calibrar antes de que E9 cierre deja que sus lecciones y su `completo` final corran sobre los
  datos de verdad.
- **Por qué no antes de E4–E7** (lo que pide el texto de E2b, "después de E4–E6"): la calibración
  necesita todas las fuentes. Pero el instrumento no: T1–T11 son mecánicas apagadas, el simulador
  y tests, y adelantarlos saca del camino crítico ~9 tareas.
- **Por qué no chocan con E9**: E2b no toca ningún archivo de E9 (tutorial, `SettingsView`, Tour,
  `ResetPlan`) y E9 no toca datos de economía ni el simulador. El único compartido es el catálogo
  de strings, por snapshot.

## Helpers de test que EXISTEN (usar éstos, no inventar)

| Necesidad | Qué usar | Dónde |
|---|---|---|
| Config/estado sintético, EK | `fxConfig(…frontierEscalationPerTier:frontierEscalationFromTier:)`, `fxEconomy`, `fxTiers`, `fxType`, `fxFloorTable`, `fxState`, `fxStateAndTower` | `Packages/EconomyKit/Tests/EconomyKitTests/Fixtures.swift` |
| La escalera del simulador | `upTiers(maxTier:)`, `upConfig(maxTier:gateTierDistance:capacity:)` (E2a T4), `upSimulator`, `upCheapLines`, `fingerprint(_:)` (E2a T2) — **privados: los tests nuevos del simulador van en `PacingSimulatorTests.swift`** o el helper se promueve a `internal` en el mismo commit | `PacingSimulatorTests.swift` |
| Las perillas | `EconomyKnobs` + `config.tuned(_:)` | E2a T2–T5 |
| Contenido real | `try GameContentLoader.load(from: .main)` | `GameContentLoader.swift` |
| El catálogo de líneas para el bot | `PacingTests.permanentLines(from:)` (`static`) | `PacingTests.swift:154` |
| El día del jugador del simulador | `PacingSimulator.HumanModel()` (sesiones de 20 min a las 0, 4, 9 y 14 h) | `PacingSimulator.swift:19-72` |

La escalera sintética de `fx*`: `a(1) → b(2) → choice (3: c_prog/c_law) → d(4)`; pisos `f1 {1–2}`
(curva propia 1,15) y `f2 {3–4}`, capacidad 5. La de `up*`: `t1…t20`, cinco pisos de cuatro tiers
(`f1`…`f5`), capacidad 10 (o la de `upConfig(capacity:)`), `oro.divisor` 1000.

---

### Task 1: La escalada por bandas y la curva que sube por piso

**Objetivo:** las dos perillas de "dificultad tardía" (PLAN-v2 E2b): la escalada de la frontera
por **bandas** (T8–12 ×1,45 · T13–24 ×1,6 · T25–37 ×1,7 como punto de partida) y la curva por
compra que **sube 0,01 por piso desde luxury**. Una sola función de escalada para `hireCost` y
para el amortiguador (hoy la fórmula está escrita dos veces). Apagadas, la v1 exacta.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` (`HireConfig`: `EscalationBand`, dos propiedades, `escalation(atFrontier:)`, decoder; `hireCost`; `hireCostGrowth(for:)`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PriceCushion.swift` (`jump`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/EscalationBandsTests.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift`, `PriceCushionTests.swift`

**Interfaces:**
- Consumes: `PriceCushion` (E2a T3), `EconomyKnobs` + `tuned` (E2a T2–T5).
- Produces: `EconomyConfig.HireConfig.EscalationBand: Codable, Sendable, Equatable` (`fromTier: Int`, `factor: Double`, `init(fromTier:factor:)`).
- Produces: `HireConfig.escalationBands: [EscalationBand]?`, `HireConfig.costGrowthStepPerFloor: Double?`, `HireConfig.costGrowthStepFromFloorId: String?`.
- Produces: `HireConfig.escalation(atFrontier: Int) -> Double` (la única fórmula de la escalada).
- Produces: `EconomyKnobs.escalationBands`, `.costGrowthStepPerFloor`, `.costGrowthStepFromFloorId`.

- [ ] **Step 0: Pararse en la base**

`grep -n "struct PriceCushion" Packages/EconomyKit/Sources/EconomyKit/PriceCushion.swift`,
`grep -n "requiresLastRunWall" Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift` (E2a T5:
`EconomyKnobs` completo) y `grep -n "escalationPerTier\|frontierEscalation" -r Packages/EconomyKit/Sources`
(los lugares que leen la escalada: tienen que ser `EconomyConfig.swift` y `PriceCushion.swift`; si
aparece un tercero, entra a esta tarea). Si falta E2a T3 o T5, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/EscalationBandsTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("La escalada por bandas y la curva por piso")
struct EscalationBandsTests {
    private typealias Band = EconomyConfig.HireConfig.EscalationBand

    private func v1() -> EconomyConfig {
        fxConfig(frontierEscalationPerTier: 1.6, frontierEscalationFromTier: 7)
    }

    @Test("sin bandas, la escalada es la de la v1 en los 37 tiers")
    func noBandsIsV1() {
        let hire = v1().hire
        for frontier in 1...37 {
            let expected = pow(1.6, Double(max(0, frontier - 7)))
            #expect(abs(hire.escalation(atFrontier: frontier) / expected - 1) < 1e-12, "T\(frontier)")
        }
    }

    @Test("una banda desde el tier siguiente al umbral reproduce la v1 exacta")
    func oneBandIsV1() throws {
        let banded = try v1().tuned(EconomyKnobs(escalationBands: [Band(fromTier: 8, factor: 1.6)]))
        for frontier in 1...37 {
            #expect(abs(banded.hire.escalation(atFrontier: frontier) / v1().hire.escalation(atFrontier: frontier) - 1) < 1e-12)
        }
    }

    @Test("cada tier de frontera paga el factor de SU banda")
    func eachTierPaysItsBand() throws {
        let bands = [Band(fromTier: 8, factor: 1.45), Band(fromTier: 13, factor: 1.6), Band(fromTier: 25, factor: 1.7)]
        let hire = try v1().tuned(EconomyKnobs(escalationBands: bands)).hire
        #expect(hire.escalation(atFrontier: 7) == 1)
        #expect(abs(hire.escalation(atFrontier: 12) - pow(1.45, 5)) < 1e-9)
        #expect(abs(hire.escalation(atFrontier: 13) - pow(1.45, 5) * 1.6) < 1e-9)
        #expect(abs(hire.escalation(atFrontier: 25) / (pow(1.45, 5) * pow(1.6, 12) * 1.7) - 1) < 1e-12)
    }

    @Test("hireCost cobra la escalada de las bandas, y comprar hondo sigue sin ser atajo")
    func hireCostUsesTheBands() throws {
        let bands = [Band(fromTier: 2, factor: 1.45), Band(fromTier: 4, factor: 1.7)]
        let config = try fxConfig().tuned(EconomyKnobs(escalationBands: bands))
        let floor = try fxFloorTable()[1]
        let at3 = config.hireCost(floor: floor, tier: 3, frontierTier: 3, purchases: 0)
        let at4 = config.hireCost(floor: floor, tier: 3, frontierTier: 4, purchases: 0)
        let yieldOverPrice = config.yieldGrowthPerTier / config.hire.priceGrowthPerTier
        #expect(abs(at4 / at3 / (yieldOverPrice * 1.7) - 1) < 1e-12)
        // A frontera fija, bajar un tier sigue descontando sólo priceGrowthPerTier.
        let deeper = config.hireCost(floor: floor, tier: 3, frontierTier: 4, purchases: 0)
        let top = config.hireCost(floor: floor, tier: 4, frontierTier: 4, purchases: 0)
        #expect(abs(top / deeper - config.hire.priceGrowthPerTier) < 1e-12)
    }

    @Test("el amortiguador salta exactamente lo que salta el precio")
    func cushionJumpIsThePriceJump() throws {
        let bands = [Band(fromTier: 2, factor: 1.45), Band(fromTier: 4, factor: 1.7)]
        let config = try fxConfig().tuned(EconomyKnobs(priceReliefPurchases: 24, escalationBands: bands))
        let floor = try fxFloorTable()[1]
        for frontier in 2...4 {
            let before = config.hireCost(floor: floor, tier: 3, frontierTier: frontier - 1, purchases: 0)
            let after = config.hireCost(floor: floor, tier: 3, frontierTier: frontier, purchases: 0)
            #expect(abs(config.priceCushion.jump(from: frontier - 1, to: frontier) / (after / before) - 1) < 1e-12)
        }
    }

    @Test("unas bandas desordenadas o con un factor bajo 1 no cargan")
    func badBandsDoNotDecode() throws {
        for bands in [[Band(fromTier: 13, factor: 1.6), Band(fromTier: 8, factor: 1.45)],
                      [Band(fromTier: 8, factor: 0.9)],
                      [Band(fromTier: 1, factor: 1.2)]] {
            #expect(throws: (any Error).self) { try fxConfig().tuned(EconomyKnobs(escalationBands: bands)) }
        }
    }

    @Test("la curva sube un escalón por piso desde el indicado, y los overrides no se tocan")
    func growthStepsByFloor() throws {
        let table = try fxFloorTable()
        let base = fxConfig()
        let fromSecond = try base.tuned(EconomyKnobs(costGrowthStepPerFloor: 0.01, costGrowthStepFromFloorId: "f2"))
        #expect(fromSecond.hireCostGrowth(for: table[0]) == base.hireCostGrowth(for: table[0]))
        #expect(abs(fromSecond.hireCostGrowth(for: table[1]) - (base.hire.defaultCostGrowth + 0.01)) < 1e-12)
        let fromFirst = try base.tuned(EconomyKnobs(costGrowthStepPerFloor: 0.01, costGrowthStepFromFloorId: "f1"))
        // f1 tiene curva propia (1,15): el escalón no la toca.
        #expect(fromFirst.hireCostGrowth(for: table[0]) == table[0].hireCostGrowthOverride)
        #expect(abs(fromFirst.hireCostGrowth(for: table[1]) - (base.hire.defaultCostGrowth + 0.02)) < 1e-12)
    }
}
```

En `EconomyKnobsTests` (suite de E2a), un test más:

```swift
    @Test("las perillas de E2b llegan por el decoder")
    func e2bKnobsLand() throws {
        let band = EconomyConfig.HireConfig.EscalationBand(fromTier: 8, factor: 1.45)
        let tuned = try fxConfig().tuned(EconomyKnobs(
            escalationBands: [band], costGrowthStepPerFloor: 0.01, costGrowthStepFromFloorId: "f2"
        ))
        #expect(tuned.hire.escalationBands == [band])
        #expect(tuned.hire.costGrowthStepPerFloor == 0.01)
        #expect(tuned.hire.costGrowthStepFromFloorId == "f2")
        #expect(try fxConfig().tuned(EconomyKnobs()) == fxConfig())
    }
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "EscalationBandsTests|EconomyKnobsTests"`
Expected: no compila (`EscalationBand`, `escalation(atFrontier:)`, los campos de `EconomyKnobs`).

- [ ] **Step 3: La implementación**

`EconomyConfig.swift`, dentro de `HireConfig`, después de `frontierEscalationFromTier`:

```swift
        /// Un tramo de la escalada: desde `fromTier` (inclusive) hasta el
        /// `fromTier` del siguiente, cada tier de frontera encarece `factor`.
        public struct EscalationBand: Codable, Sendable, Equatable {
            public let fromTier: Int
            public let factor: Double

            public init(fromTier: Int, factor: Double) {
                self.fromTier = fromTier
                self.factor = factor
            }
        }

        /// La escalada por bandas (PLAN-v2 E2b, "dificultad tardía"): reemplaza a
        /// `frontierEscalationPerTier` desde `frontierEscalationFromTier` cuando
        /// está. `[{8: 1,6}]` es exactamente la v1. Sin la clave, la v1. [TUNEABLE]
        public let escalationBands: [EscalationBand]?
        /// Cuánto sube la curva por compra en cada piso desde
        /// `costGrowthStepFromFloorId` (ése incluido): el piso indicado suma un
        /// escalón, el siguiente dos. No toca los pisos con curva propia. [TUNEABLE]
        public let costGrowthStepPerFloor: Double?
        public let costGrowthStepFromFloorId: String?

        /// LA escalada de tu frontera: el producto del factor de cada tier de 2
        /// a `frontier`. La cobran `hireCost` y el amortiguador; no hay otra copia.
        public func escalation(atFrontier frontier: Int) -> Double {
            guard let bands = escalationBands else {
                return pow(frontierEscalationPerTier, Double(max(0, frontier - frontierEscalationFromTier)))
            }
            guard frontier >= 2 else { return 1 }
            return (2...frontier).reduce(1.0) { product, tier in
                product * (bands.last { $0.fromTier <= tier }?.factor ?? 1)
            }
        }
```

El `init` suma al final `escalationBands: [EscalationBand]? = nil, costGrowthStepPerFloor: Double? = nil,
costGrowthStepFromFloorId: String? = nil` y los asigna. En `init(from:)`, después de
`frontierEscalationFromTier` (y de lo que sumó E2a):

```swift
            // Las tres con `decodeIfPresent`: sin la clave, la v1.
            escalationBands = try container.decodeIfPresent([EscalationBand].self, forKey: .escalationBands)
            costGrowthStepPerFloor = try container.decodeIfPresent(Double.self, forKey: .costGrowthStepPerFloor)
            costGrowthStepFromFloorId = try container.decodeIfPresent(String.self, forKey: .costGrowthStepFromFloorId)
            if let bands = escalationBands {
                let ordered = zip(bands, bands.dropFirst()).allSatisfy { $0.fromTier < $1.fromTier }
                guard ordered, bands.allSatisfy({ $0.fromTier >= 2 && $0.factor >= 1 }) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .escalationBands, in: container,
                        debugDescription: "bandas en orden creciente, desde el tier 2 y con factor ≥ 1"
                    )
                }
            }
```

`CodingKeys` suma `case escalationBands, costGrowthStepPerFloor, costGrowthStepFromFloorId`.

`hireCost`: el factor `pow(hire.frontierEscalationPerTier, Double(max(0, frontierTier −
hire.frontierEscalationFromTier)))` pasa a `hire.escalation(atFrontier: frontierTier)`, y el
docstring de la función suma una línea al renglón (c): "con `escalationBands`, el factor de cada
tier es el de su banda".

`hireCostGrowth(for:)`:

```swift
    public func hireCostGrowth(for floor: FloorDef) -> Double {
        if let override = floor.hireCostGrowthOverride { return override }
        guard let step = hire.costGrowthStepPerFloor, step != 0,
              let fromId = hire.costGrowthStepFromFloorId,
              let from = floors.firstIndex(where: { $0.id == fromId }),
              let ordinal = floors.firstIndex(where: { $0.id == floor.id }),
              ordinal >= from
        else { return hire.defaultCostGrowth }
        return hire.defaultCostGrowth + step * Double(ordinal - from + 1)
    }
```

`PriceCushion.swift`: las propiedades `escalationPerTier` y `escalationFromTier` se reemplazan
por `private let hire: EconomyConfig.HireConfig` (asignada en `init(config:)`), y `jump`:

```swift
    public func jump(from: Int, to: Int) -> Double {
        guard to > from else { return 1 }
        return pow(yieldGrowthPerTier / priceGrowthPerTier, Double(to - from))
            * hire.escalation(atFrontier: to) / hire.escalation(atFrontier: from)
    }
```

`EconomyKnobs.swift`: tres campos (`escalationBands: [EconomyConfig.HireConfig.EscalationBand]?`,
`costGrowthStepPerFloor: Double?`, `costGrowthStepFromFloorId: String?`), sus parámetros en el
`init` (con default `nil`, **al final** de la lista para no romper las llamadas de E2a) y en
`tuned`, dentro del bloque de `hire`:

```swift
        if let bands = knobs.escalationBands {
            hire["escalationBands"] = bands.map { ["fromTier": $0.fromTier, "factor": $0.factor] }
        }
        if let value = knobs.costGrowthStepPerFloor { hire["costGrowthStepPerFloor"] = value }
        if let value = knobs.costGrowthStepFromFloorId { hire["costGrowthStepFromFloorId"] = value }
```

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS, nombrando `EscalationBandsTests`,
`EconomyKnobsTests`, `PriceCushionTests` y `FrontierEscalationTests` (el invariante de profundidad
de la v1 sigue en pie). `Tools/v2/oraculo.sh rapido` → `VERDE` (`hirePricesFollowTheOwnersRule` sigue
verde: el dato no cambió).

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift Packages/EconomyKit/Sources/EconomyKit/PriceCushion.swift \
  Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift Packages/EconomyKit/Tests/EconomyKitTests/EscalationBandsTests.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift
git diff --cached --stat
git commit -m "feat(economia): la escalada por bandas y la curva que sube por piso, apagadas"
```

---

### Task 2: La herencia de pasivos al reencarnar

**Objetivo:** la decisión del dueño (§2): **al reencarnar sólo se recuerdan los pasivos
desbloqueados**. Vive en `PrestigeCalculator.applyReincarnation`, el único lugar donde nace una
run, que comparten la app y el simulador; detrás de `oro.inheritsPassiveUnlocks` (apagada = v1)
hasta que T14 la declare. Sin campo nuevo en el save: la run nueva hereda los de la anterior, que
ya traía los de las previas (duda 11). Nace la función que la pantalla de T11 muestra.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` (`OroConfig.inheritsPassiveUnlocks`, `inheritsPassives`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PrestigeCalculator.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` (`Report.passiveUnlocksPerRun`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/PassiveInheritanceTests.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift`, `PacingSimulatorTests.swift`

**Interfaces:**
- Produces: `EconomyConfig.OroConfig.inheritsPassiveUnlocks: Bool?` y `var inheritsPassives: Bool` (`?? false`).
- Produces: `PrestigeCalculator.inheritedPassiveUnlocks(state: PlayerState, economy: StandardEconomy) -> [String: Bool]` (vacío con la perilla apagada).
- Produces: `EconomyKnobs.inheritsPassiveUnlocks: Bool?`.
- Produces: `PacingSimulator.Report.passiveUnlocksPerRun: [Int]` (cuántos pasivos COMPRÓ el bot en cada run; la última es la abierta).

- [ ] **Step 0: Pararse en la base**

`grep -n "requiresLastRunWall" Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift` (el
patrón de `OroConfig` de E2a T5) y `grep -n "passiveUnlocked" Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift`
(que `RunState.fresh` lo arranque vacío). Si `fresh` ya trae pasivos, el `merge` de abajo los
conserva igual.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/PassiveInheritanceTests.swift`:

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("La herencia de pasivos al reencarnar")
struct PassiveInheritanceTests {
    private func reincarnate(_ state: inout PlayerState, inherits: Bool) throws {
        let config = try fxConfig().tuned(EconomyKnobs(inheritsPassiveUnlocks: inherits))
        let economy = StandardEconomy(config: config)
        state.meta.lifetimeEarnings = 1e30
        PrestigeCalculator.applyReincarnation(
            state: &state, economy: economy, tiers: try fxTiers(), floorTable: try fxFloorTable(), now: 0
        )
    }

    @Test("apagada, la run nueva arranca sin pasivos: la v1")
    func offIsV1() throws {
        var state = fxState()
        state.run.passiveUnlocked = ["a": true, "b": true]
        try reincarnate(&state, inherits: false)
        #expect(state.run.passiveUnlocked.values.allSatisfy { !$0 })
    }

    @Test("prendida, la run nueva conserva los pasivos y nada más de la run")
    func onKeepsOnlyPassives() throws {
        var state = fxState()
        state.run.passiveUnlocked = ["a": true, "b": true, "d": false]
        state.run.units = ["a": 3, "b": 2]
        state.run.charUpgradeLevels = ["a": 4]
        try reincarnate(&state, inherits: true)
        #expect(state.run.passiveUnlocked.filter(\.value).keys.sorted() == ["a", "b"])
        #expect(state.run.charUpgradeLevels.isEmpty)
        #expect(state.run.units["b"] == nil)
    }

    @Test("se acumulan: un pasivo de la run 1 sigue en la 3 aunque la 2 nunca llegó a ese tipo")
    func theyAccumulate() throws {
        var state = fxState()
        state.run.passiveUnlocked = ["d": true]
        try reincarnate(&state, inherits: true)
        state.run.passiveUnlocked["a"] = true
        try reincarnate(&state, inherits: true)
        #expect(state.run.passiveUnlocked["d"] == true)
        #expect(state.run.passiveUnlocked["a"] == true)
    }

    @Test("lo que muestra la pantalla es lo que aplica la reencarnación")
    func previewIsWhatApplies() throws {
        var state = fxState()
        state.run.passiveUnlocked = ["a": true, "c_prog": true, "b": false]
        let economy = StandardEconomy(config: try fxConfig().tuned(EconomyKnobs(inheritsPassiveUnlocks: true)))
        let preview = PrestigeCalculator.inheritedPassiveUnlocks(state: state, economy: economy)
        try reincarnate(&state, inherits: true)
        #expect(state.run.passiveUnlocked.filter(\.value) == preview)
    }
}
```

En `EconomyKnobsTests`: `#expect(try fxConfig().tuned(EconomyKnobs(inheritsPassiveUnlocks: true)).oro.inheritsPassives)`
y `#expect(!fxConfig().oro.inheritsPassives)`.

En `PacingSimulatorTests.swift`, en `PacingSimulatorKnobTests` (E2a):

```swift
    @Test("el simulador lee la herencia: el bot compra menos pasivos desde la run 2")
    func theSimulatorReadsTheInheritance() throws {
        let off = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        let on = try PacingSimulator(
            config: upConfig().tuned(EconomyKnobs(inheritsPassiveUnlocks: true)),
            tiers: upTiers(), upgrades: upCheapLines()
        ).run(maxDays: 5)
        #expect(off.reincarnations > 0)
        #expect(fingerprint(on) != fingerprint(off))
        #expect(off.passiveUnlocksPerRun.count == off.reincarnations + 1)
        let bought = on.passiveUnlocksPerRun.dropFirst().reduce(0, +)
        let boughtOff = off.passiveUnlocksPerRun.dropFirst().reduce(0, +)
        #expect(bought < boughtOff, "con herencia \(bought), sin \(boughtOff)")
    }
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "PassiveInheritanceTests|EconomyKnobsTests|PacingSimulatorKnobTests"`
Expected: no compila (`inheritsPassiveUnlocks`, `inheritedPassiveUnlocks`, `passiveUnlocksPerRun`).

- [ ] **Step 3: La implementación**

`EconomyConfig.swift`, en `OroConfig`, después de `requiresLastRunWall` (E2a T5):

```swift
        /// Herencia (PLAN-v2 §2): al reencarnar se conservan los pasivos
        /// desbloqueados, nada más. Sin la clave, false: la v1. [TUNEABLE]
        public let inheritsPassiveUnlocks: Bool?

        public var inheritsPassives: Bool { inheritsPassiveUnlocks ?? false }
```

(el `init` de `OroConfig` suma `inheritsPassiveUnlocks: Bool? = nil` al final y lo asigna; si
`OroConfig` decodifica a mano, `decodeIfPresent`).

`PrestigeCalculator.swift`:

```swift
    /// Los pasivos que la run nueva conserva: los desbloqueados de ésta, que ya
    /// traen los de las anteriores. Vacío con la herencia apagada. La pantalla
    /// de reencarnar muestra esto mismo.
    public static func inheritedPassiveUnlocks(state: PlayerState, economy: StandardEconomy) -> [String: Bool] {
        guard economy.config.oro.inheritsPassives else { return [:] }
        return state.run.passiveUnlocked.filter(\.value)
    }
```

y en `applyReincarnation`, antes de `state.run = .fresh(…)`, `let inherited =
inheritedPassiveUnlocks(state: state, economy: economy)`; después, `state.run.passiveUnlocked.merge(inherited)
{ _, kept in kept }`. El docstring de la función suma: "salvo los pasivos, si la herencia está
prendida".

`EconomyKnobs.swift`: `public var inheritsPassiveUnlocks: Bool?`, su parámetro al final del `init`
y en `tuned`, dentro del bloque de `oro` (el que abrió E2a T5): `if let value =
knobs.inheritsPassiveUnlocks { oro["inheritsPassiveUnlocks"] = value }`.

`PacingSimulator.swift`: en `Report`, junto a `maxTierPerRun`:

```swift
        /// Cuántos pasivos compró el bot en cada run (la última es la abierta).
        /// Con la herencia, de la segunda en adelante tiene que bajar.
        public var passiveUnlocksPerRun: [Int] = [0]
```

En la `Action` del pasivo (`nextAction`, paso 1) no se puede tocar el reporte (es un cierre sobre
`PlayerState`); por eso el conteo va en `playSession`: después de `action.perform(&state)`, si
`state.run.passiveUnlocked.filter(\.value).count` creció, `report.passiveUnlocksPerRun[report.passiveUnlocksPerRun.count − 1] += 1`;
y en `maybeReincarnate`, después de `applyReincarnation`, `report.passiveUnlocksPerRun.append(0)`.

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (nombra `PassiveInheritanceTests` y
el test nuevo de `PacingSimulatorKnobTests`). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/EconomyConfig.swift Packages/EconomyKit/Sources/EconomyKit/PrestigeCalculator.swift \
  Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/PassiveInheritanceTests.swift Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/PacingSimulatorTests.swift
git diff --cached --stat
git commit -m "feat(prestigio): reencarnar conserva los pasivos, detrás de una perilla apagada"
```

---

### Task 3: El simulador cobra como el juego, y mide lo que el contrato pide

**Objetivo:** cerrar las tres costuras por las que el bot cobra distinto que el jugador, y sumar
las series que el contrato necesita.

1. **El pasivo** por `IncomeTicker.basePassivePerSecond` (hoy es una copia; desde E2a T4 la copia
   además tiene el bono de pisos en marcha pegado a mano).
2. **El offline** por `OfflineCalculator.earnings` (la nota de E1 T16).
3. **El descuento de prestigio** (`prestige_unlocks.json`): la app lo cobra en cada cotización y el
   bot nunca lo vio. Entra como `prestigeUnlocks: PrestigeUnlocks?`, **`nil` = la v1 del bot**:
   así el oráculo sigue imprimiendo la línea de base y la diferencia se mide en T12.
4. **Las métricas de costo** (`floorUnlockHireSeconds`, `peakHire`) por `TowerActions.hireQuote`
   (aviso 7 de E2a: con el amortiguador prendido medían el precio de catálogo).
5. **Las series del contrato**: a qué tier llegó cada run y cuándo (`tierReachedPerRun`, punto 5),
   cuánto de la vuelta a la pared es **acción** (botón) y cuánto espera
   (`actionSecondsBackToPreviousWall`, el techo del prestigio de `balance-log`), el ORO de cada
   reencarnación y el ORO al llegar a Dios.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift`
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/SimulatorFidelityTests.swift`
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/PacingSimulatorTests.swift` (si hace falta promover `upConfig`/`upTiers`/`upSimulator`/`fingerprint` a `internal` para la suite nueva)

**Interfaces:**
- Produces: `PacingSimulator.init(config:tiers:human:maxPaybackSeconds:careerPath:upgrades:prestigeUnlocks:)` con `prestigeUnlocks: PrestigeUnlocks? = nil`.
- Produces (internal, para los tests): `PacingSimulator.offlineCredit(state: PlayerState, from: Double, to: Double) -> Double`, `PacingSimulator.passiveRate(state: PlayerState) -> Double`, `PacingSimulator.activeIncomeRate(state: PlayerState) -> Double`, `PacingSimulator.quote(typeId: String, state: PlayerState, now: Double) -> HireQuote?`.
- Produces: `Report.tierReachedPerRun: [[Int: Double]]` (segundos activos desde el inicio de cada run; la última es la abierta), `Report.actionSecondsBackToPreviousWall: [Double]` (alineada con `secondsBackToPreviousWall`), `Report.prestigeCeilingPerRun: [Double]` (calculada: `1 − acción/primera_vez`), `Report.oroGainedPerReincarnation: [Int]`, `Report.oroAtGod: Int?` (`oroEarnedLifetime` + el ORO por reencarnar en ese momento).

- [ ] **Step 0: Pararse en la base**

`grep -n "StaffedFloors" Packages/EconomyKit/Sources/EconomyKit/IncomeTicker.swift` (E2a T4: el
pasivo del juego ya tiene el bono) y `grep -n "func passivePerSecond\|func applyOffline\|func hireSeconds\|func peakHire" Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift`
(los cuatro lugares que se reemplazan). Anotá el `fingerprint` y el reporte de `pacing-sim` de la
línea de base **antes de tocar nada** (Receta P sin flags nuevos, `--max-days 90`): son el juez del
paso 4.

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/SimulatorFidelityTests.swift` (usa las fixtures `up*`:
si son `private` en `PacingSimulatorTests.swift`, se promueven a `internal` en este commit):

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("El simulador cobra con las funciones del juego")
struct SimulatorFidelityTests {
    private func midGame() throws -> (PacingSimulator, PlayerState) {
        let simulator = try upSimulator()
        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "f1", offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 0
        )
        state.run.units = ["t1": 3, "t5": 2, "t6": 1]
        state.run.passiveUnlocked = ["t1": true, "t5": true]
        state.run.raiseFrontier(to: 6, cushion: upConfig().priceCushion)
        state.meta.prestigeLevel = 3
        return (simulator, state)
    }

    @Test("el offline del bot es OfflineCalculator.earnings")
    func offlineIsTheGames() throws {
        let (simulator, state) = try midGame()
        var stamped = state
        stamped.meta.lastSeenTimestamp = 1000
        let expected = OfflineCalculator.earnings(
            state: stamped, tiers: try upTiers(), floorTable: try FloorTable(floors: upConfig().floors, maxTier: 20),
            config: upConfig(), now: 1000 + 7200
        )
        #expect(abs(simulator.offlineCredit(state: state, from: 1000, to: 1000 + 7200) - expected) < 1e-9)
    }

    @Test("el pasivo del bot es IncomeTicker.basePassivePerSecond")
    func passiveIsTheGames() throws {
        let (simulator, state) = try midGame()
        let passive = IncomeTicker.basePassivePerSecond(
            state: state, tiers: try upTiers(), floorTable: try FloorTable(floors: upConfig().floors, maxTier: 20),
            config: upConfig()
        )
        #expect(simulator.activeIncomeRate(state: state) > passive)
        #expect(abs(simulator.passiveRate(state: state) - passive) < 1e-12)
    }

    @Test("con el descuento de prestigio, el bot cotiza lo que cotiza FisuJobs")
    func prestigeDiscountIsTheGames() throws {
        let unlocks = PrestigeUnlocks(schemaVersion: 1, spawnDiscountCap: 0.5, levels: [
            .init(level: 1, spawnCostDiscount: 0.05), .init(level: 3, spawnCostDiscount: 0.1),
        ])
        let (_, state) = try midGame()
        let simulator = try PacingSimulator(config: upConfig(), tiers: upTiers(), prestigeUnlocks: unlocks)
        let game = try #require(TowerActions.hireQuote(
            typeId: "t1", state: state, config: upConfig(),
            floorTable: try FloorTable(floors: upConfig().floors, maxTier: 20), tiers: try upTiers(),
            costMultiplier: 1 - unlocks.cumulativeSpawnDiscount(atPrestigeLevel: 3), now: 0
        ))
        #expect(simulator.quote(typeId: "t1", state: state, now: 0)?.cost == game.cost)
    }

    @Test("sin descuento de prestigio el bot juega igual que antes, y con uno vacío también")
    func nilUnlocksIsTheBaseline() throws {
        let empty = PrestigeUnlocks(schemaVersion: 1, spawnDiscountCap: 0, levels: [])
        let base = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        let withEmpty = try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                                            prestigeUnlocks: empty).run(maxDays: 5)
        #expect(fingerprint(withEmpty) == fingerprint(base))
    }

    @Test("el reporte trae las series del contrato")
    func contractSeries() throws {
        let report = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        #expect(report.reincarnations > 1)
        #expect(report.tierReachedPerRun.count == report.reincarnations + 1)
        #expect(report.oroGainedPerReincarnation.count == report.reincarnations)
        #expect(report.actionSecondsBackToPreviousWall.count == report.secondsBackToPreviousWall.count)
        for (action, back) in zip(report.actionSecondsBackToPreviousWall, report.secondsBackToPreviousWall) {
            #expect(action > 0 && action <= back, "acción \(action) contra vuelta \(back)")
        }
        for (ceiling, payoff) in zip(report.prestigeCeilingPerRun, report.prestigePayoffPerRun) {
            #expect(payoff <= ceiling + 1e-12, "el pago no puede pasar su techo")
        }
        for run in report.tierReachedPerRun {
            #expect(run[1] == 0)
        }
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "SimulatorFidelityTests"`
Expected: no compila (`offlineCredit`, `activeIncomeRate`, `passiveRate`, `quote`, `prestigeUnlocks:`, las series).

- [ ] **Step 3: La implementación**

`PacingSimulator.swift`:

1. `let prestigeUnlocks: PrestigeUnlocks?` y su parámetro `prestigeUnlocks: PrestigeUnlocks? = nil`
   **al final** del `init`.
2. `passivePerSecond(state:)` desaparece; en su lugar:

```swift
    func passiveRate(state: PlayerState) -> Double {
        IncomeTicker.basePassivePerSecond(state: state, tiers: tiers, floorTable: floorTable, config: config)
    }
```

   y `incomeRate(state:active:)` pasa a llamarse `activeIncomeRate(state:)` cuando `active` es
   true (el único llamador con `false` no existe: si aparece, `passiveRate`). El término del toque
   no cambia (sigue multiplicando por `StaffedFloors.multiplier`, de E2a T4).
3. El offline:

```swift
    /// Lo que el jugador cobra al volver de una ausencia de `from` a `to`: la
    /// misma cuenta que el popup offline.
    func offlineCredit(state: PlayerState, from: Double, to: Double) -> Double {
        var stamped = state
        stamped.meta.lastSeenTimestamp = from
        return OfflineCalculator.earnings(state: stamped, tiers: tiers, floorTable: floorTable, config: config, now: to)
    }
```

   y `applyOffline(state:elapsed:)` pasa a `applyOffline(state:from:to:)` (los tres llamadores de
   `run` pasan `wall` y el destino) con `earn(state: &state, amount: offlineCredit(state: state, from: from, to: to))`.
4. La cotización:

```swift
    func quote(typeId: String, state: PlayerState, now: Double) -> HireQuote? {
        let discount = prestigeUnlocks?.cumulativeSpawnDiscount(atPrestigeLevel: state.meta.prestigeLevel) ?? 0
        return TowerActions.hireQuote(
            typeId: typeId, state: state, config: config, floorTable: floorTable, tiers: tiers,
            costMultiplier: 1 - discount, now: now
        )
    }
```

   `hireAction` cotiza por acá (con `now: 0` hasta T5, que le pasa el reloj), y `hireSeconds` /
   `peakHire` cotizan con `quote(typeId:state:now: 0)?.cost` en vez de `config.hireCost(…)`. Sus
   docstrings cambian "cotiza por `config.hireCost`" por "cotiza lo que cobra el juego, con
   amortiguador y descuentos".
5. Las series. En `RunTracker` suman `var actionSeconds: Double = 0` y
   `var actionsAtTier: [Int: Double] = [1: 0]`. Cada compra (`playSession`, después de
   `action.perform`) suma `human.hireSeconds` a `tracker.actionSeconds`; cada fusión (`doAllMerges`)
   suma `human.mergeSeconds`; y donde hoy se anota `tracker.tierReached[newType.tier]`, también
   `tracker.actionsAtTier[newType.tier] = tracker.actionSeconds`. En `closeRun`, junto al
   `append` de `secondsBackToPreviousWall`, `report.actionSecondsBackToPreviousWall.append(tracker.actionsAtTier[anterior] ?? vuelta)`;
   y siempre `report.tierReachedPerRun.append(tracker.tierReached)`. En `Report`:

```swift
        /// A qué tier llegó cada run y en cuántos segundos activos desde su
        /// inicio. La serie del contrato 5 ("más rápida en cada tier ya visto").
        public var tierReachedPerRun: [[Int: Double]] = []
        /// De `secondsBackToPreviousWall`, cuánto fue apretar el botón (una
        /// compra o una fusión cuestan su segundo) y no esperar plata.
        public var actionSecondsBackToPreviousWall: [Double] = []
        /// El techo del prestigio (balance-log, "el techo del prestigio"):
        /// `1 − acción/primera_vez`. Ningún knob de precio lo cruza.
        public var prestigeCeilingPerRun: [Double] {
            zip(actionSecondsBackToPreviousWall, secondsToOwnWallFirstTime).map { action, first in
                first > 0 ? 1 - action / first : 0
            }
        }
        public var oroGainedPerReincarnation: [Int] = []
        /// El ORO de la cuenta al llegar a Dios, contando el que había por reencarnar.
        public var oroAtGod: Int?
```

   `maybeReincarnate` anota `report.oroGainedPerReincarnation.append(PrestigeCalculator.oroGained(state: state, economy: economy))`
   antes de `applyReincarnation`; `playSession`, donde anota `godWall`, también
   `report.oroAtGod = state.meta.oroEarnedLifetime + PrestigeCalculator.oroGained(state: state, economy: economy)`.

- [ ] **Step 4: Verde, y la base no se movió**

Run: `swift test --package-path Packages/EconomyKit` → PASS (nombra `SimulatorFidelityTests`;
`PacingSimulatorTests` entera verde). Después la Receta P **sin flags nuevos** → tiene que dar
**exactamente** los números anotados en el paso 0 en `dios:` y `reencarnaciones:` y la serie de
la pared (las columnas de costo `entrar`/`más comprado` pueden cambiar: ahora cotizan con el
descuento de las líneas, y se anota en el reporte). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/SimulatorFidelityTests.swift Packages/EconomyKit/Tests/EconomyKitTests/PacingSimulatorTests.swift
git diff --cached --stat
git commit -m "feat(pacing): el simulador cobra el pasivo, el offline y el descuento de prestigio como el juego"
```

---

### Task 4: La política de pisos en marcha — el bot llena un piso cuando el bono paga

**Objetivo:** lo que E2a dejó explícitamente para E2b ("el bot no llena pisos a propósito"):
con `staffedFloorBonus > 0`, el bot **completa** un piso cuando lo que cuesta llenarlo se paga con
el bono en `maxPaybackSeconds`, y **no lo desarma** fusionando, salvo una fusión que sube la
frontera. Con el bono en 0 el bot juega exactamente igual que antes.

⚠️ Es una regla del bot, de las que ya se desincronizaron dos veces sin que nadie lo viera
(docstrings de `bestHire` y `bestCharUpgrade`). Por eso va con opus, con tests de la regla y con
la huella de la base.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` (`nextAction`, `doAllMerges`, `Report`)
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/StaffingPolicyTests.swift`

**Interfaces:**
- Consumes: `StaffedFloors.ordinals(state:tiers:floorTable:)`, `config.staffedBonusPerFloor` (E2a T4).
- Produces (internal): `PacingSimulator.staffingTarget(state: PlayerState) -> Int?` (el ordinal del piso que conviene completar, o nil), `PacingSimulator.frozenFloors(state: PlayerState) -> Set<Int>` (los pisos en marcha que el bot no desarma).
- Produces: `Report.staffedFloorsAtGod: Int?`, `Report.maxStaffedFloors: Int`.

La regla, en tres renglones:

```
objetivo   = el piso abierto más bajo que no está en marcha y cuyo llenado se paga:
             costo(faltan m) = Σ_{i<m} quote(tipo más barato contratable del piso) · g^i
             ganancia        = staffedBonusPerFloor · ingreso activo de hoy
             costo / ganancia ≤ maxPaybackSeconds
compra     = mientras haya objetivo, su contratación más barata compite en `nextAction` como
             un candidato más (gana la más barata, la regla de siempre)
congelado  = un piso en marcha por debajo del piso donde el bot compra
             (floor(forTier: frontera − gateTierDistance)) no se fusiona, salvo que la fusión
             suba la frontera
```

- [ ] **Step 0: Pararse en la base**

`grep -n "enum StaffedFloors" -r Packages/EconomyKit/Sources` y
`grep -n "capacity: Int = 10" Packages/EconomyKit/Tests/EconomyKitTests/PacingSimulatorTests.swift` (E2a T4).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/StaffingPolicyTests.swift` (con las fixtures `up*`
promovidas en T3):

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("La política de pisos en marcha del bot")
struct StaffingPolicyTests {
    private func simulator(bonus: Double, capacity: Int = 4) throws -> PacingSimulator {
        try PacingSimulator(
            config: upConfig(capacity: capacity).tuned(EconomyKnobs(staffedFloorBonus: bonus)),
            tiers: upTiers(), upgrades: upCheapLines()
        )
    }

    private func state(units: [String: Int], frontier: Int) -> PlayerState {
        var state = PlayerState.newGame(
            startTypeId: "t1", startFloorId: "f1", offlineEfficiencyBase: 0.35, critChanceBase: 0, now: 0
        )
        state.run.units = units
        state.run.passiveUnlocked = Dictionary(uniqueKeysWithValues: units.keys.map { ($0, true) })
        state.run.raiseFrontier(to: frontier, cushion: upConfig().priceCushion)
        state.run.coins = 1e30
        return state
    }

    @Test("sin bono no hay objetivo ni pisos congelados: el bot de siempre")
    func noBonusNoPolicy() throws {
        let sim = try simulator(bonus: 0)
        let s = state(units: ["t1": 2, "t2": 1], frontier: 12)
        #expect(sim.staffingTarget(state: s) == nil)
        #expect(sim.frozenFloors(state: s).isEmpty)
    }

    @Test("con bono, el piso bajo y barato es el objetivo")
    func cheapLowFloorIsTheTarget() throws {
        let sim = try simulator(bonus: 0.5)
        let s = state(units: ["t1": 2, "t9": 4, "t10": 2], frontier: 12)
        #expect(sim.staffingTarget(state: s) == 0)
    }

    @Test("un piso en marcha bajo el piso de compra no se desarma fusionando")
    func staffedFloorIsFrozen() throws {
        let sim = try simulator(bonus: 0.5)
        let s = state(units: ["t1": 2, "t2": 2, "t13": 1], frontier: 13)
        #expect(sim.frozenFloors(state: s) == [0])
    }

    @Test("con el bono en cero, la partida es la de la base exacta")
    func zeroBonusIsTheBaseline() throws {
        let base = try PacingSimulator(config: upConfig(capacity: 4), tiers: upTiers(), upgrades: upCheapLines()).run(maxDays: 5)
        let zero = try simulator(bonus: 0).run(maxDays: 5)
        #expect(fingerprint(zero) == fingerprint(base))
    }

    @Test("con bono, el bot llega a tener pisos en marcha y le rinde")
    func theBonusIsUsed() throws {
        let off = try simulator(bonus: 0).run(maxDays: 5)
        let on = try simulator(bonus: 0.5).run(maxDays: 5)
        #expect(on.maxStaffedFloors >= 1)
        #expect(on.finalLifetimeEarnings > off.finalLifetimeEarnings)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "StaffingPolicyTests"`
Expected: no compila (`staffingTarget`, `frozenFloors`, `maxStaffedFloors`).

- [ ] **Step 3: La implementación**

En `PacingSimulator.swift`, una sección `// MARK: - Pisos en marcha` con:

```swift
    /// El piso que conviene completar: el abierto más bajo que no está en
    /// marcha y cuyo llenado se paga con el bono en `maxPaybackSeconds`.
    func staffingTarget(state: PlayerState) -> Int? {
        let bonus = config.staffedBonusPerFloor
        guard bonus > 0 else { return nil }
        let staffed = Set(StaffedFloors.ordinals(state: state, tiers: tiers, floorTable: floorTable))
        let gain = bonus * activeIncomeRate(state: state)
        guard gain > 0 else { return nil }
        for ordinal in 0..<floorTable.count where !staffed.contains(ordinal)
            && state.run.unlockedFloors.contains(floorTable[ordinal].id) {
            let floor = floorTable[ordinal]
            let missing = floor.capacity - floorCount(ordinal, state: state)
            guard missing > 0, let cheapest = cheapestHire(onFloor: ordinal, state: state) else { continue }
            let growth = config.hireCostGrowth(for: floor)
            let cost = growth == 1
                ? cheapest.cost * Double(missing)
                : cheapest.cost * (pow(growth, Double(missing)) - 1) / (growth - 1)
            if cost / gain <= maxPaybackSeconds { return ordinal }
        }
        return nil
    }

    /// Los pisos en marcha que el bot no fusiona: los que están por debajo del
    /// piso donde compra (desarmar uno de ésos le saca el bono a cambio de nada).
    func frozenFloors(state: PlayerState) -> Set<Int> {
        guard config.staffedBonusPerFloor > 0 else { return [] }
        let buyingTier = max(1, state.run.maxTierReached - config.hire.gateTierDistance)
        let buyingFloor = floorTable.ordinal(forTier: buyingTier)
        return Set(StaffedFloors.ordinals(state: state, tiers: tiers, floorTable: floorTable).filter { $0 < buyingFloor })
    }
```

`cheapestHire(onFloor:state:)` es la `HireCandidate` de menor `action.cost` entre
`hireActions(floorOrdinal:state:requireProfit: false)` (la misma cotización que el resto).

- `nextAction`: si hay `staffingTarget`, suma `cheapestHire(onFloor: target, state:)?.action` a
  `candidates` (compite por precio, como el pasivo y la mejora).
- `doAllMerges`: antes de consumir el par, `if frozenFloors(state: state).contains(srcOrdinal),
  newType.tier <= state.run.maxTierReached { continue }` (calculado una vez por vuelta del `while`).
- `Report`: `public var staffedFloorsAtGod: Int?` y `public var maxStaffedFloors = 0`; `recordUnlocks`
  actualiza el máximo y `playSession`, al llegar a Dios, anota el actual.

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (`StaffingPolicyTests`,
`PacingSimulatorTests` entera). Receta P sin flags → la línea de base exacta (el `economy.json` no
declara el bono). `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/StaffingPolicyTests.swift Packages/EconomyKit/Tests/EconomyKitTests/PacingSimulatorTests.swift
git diff --cached --stat
git commit -m "feat(pacing): el bot llena un piso cuando el bono paga y no lo desarma"
```

---

### Task 5: Los perfiles del simulador, y lo que el jugador gratis recibe sin video

**Objetivo:** que el simulador juegue **perfiles** (`PacingProfile`) con **fuentes** que arma el
llamador (`PacingSources`, datos puros: EconomyKit no lee JSON de la app), y el perfil `.free`
completo: el Paquete de la Aduana, el diario base, los boosts gratis con cooldown y el premio del
Programador. Con `.bare` (el default) y `PacingSources.none`, el bot de siempre.

**Files:**
- Create: `Packages/EconomyKit/Sources/EconomyKit/PacingProfile.swift`
- Create: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator+Sources.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` (init, `playSession`, `run`, `hireAction` con reloj, `doAllMerges` con la carrera)
- Modify: el archivo de `PackageRoller` (E5a T1): `eligibleTypes` sin torre
- Create: `Packages/EconomyKit/Tests/EconomyKitTests/PacingProfileTests.swift`

**Interfaces:**
- Consumes: `PackagesConfig`, `PackageRoller.odds(eligible:windowTiers:ratio:)`, `PackageRoller.eligibleTypes(state:tower:tiers:floorTable:config:)` (**E5a T1**); `RewardScale.coinPayout(seconds:…)`/`(minutes:…)` (**E2a T1**); `ActiveModifier.Effect.freeHire` y `hireQuote(…now:)` gratis mientras vive (**E2a T12**).
- Produces: `public struct PacingProfile: Sendable, Equatable` (`usesFreeGifts`, `watchesVideos`, `ownsShopPermanents`; `static let bare, free, ads, max`).
- Produces: `public struct PacingSources: Sendable, Equatable` (`packages: PackagesConfig?`, `dailyMinutes: [Double]`, `freeBoosts: [FreeBoost]`, `freeHireSeconds: Double`; T6 suma `ads`, T7 `shop`; `static let none`) y `PacingSources.FreeBoost` (`id`, `cooldownSeconds`, `effect: Effect`) con `Effect`: `incomeBurst(multiplier:seconds:)`, `tapBurst(multiplier:seconds:)`, `payoutMinutes(Double)`, `offlineStep(step:cap:)`.
- Produces: `PacingSimulator.init(…, prestigeUnlocks:, profile: PacingProfile = .bare, sources: PacingSources = .none, seedFraction: Double = 0.5)`.
- Produces: `PackageRoller.eligibleTypes(state:tiers:floorTable:config:occupancy: [Int])` (la de torre llama a ésta).
- Produces: `Report.sourceTotals: [String: Double]` (monedas por fuente, `"packages.opened"`, `"oro.fromSources"`, `"videos"`).

- [ ] **Step 0: Pararse en la base**

`grep -n "enum PackageRoller" -r Packages/EconomyKit/Sources` (anotá el archivo),
`grep -n "func eligibleTypes\|func odds" <ese archivo>`, `grep -n "enum RewardScale" -r Packages/EconomyKit/Sources`,
`grep -n "case freeHire" Packages/EconomyKit/Sources/EconomyKit/ActiveModifier.swift`. Si falta
alguno, `NEEDS_CONTEXT`. Leé `eligibleTypes`: lo único que le pide a la torre tiene que ser "hay
lugar en el piso del tipo" (si pide otra cosa, la variante sin torre lo recibe como parámetro).

- [ ] **Step 1: Los tests, en rojo**

`Packages/EconomyKit/Tests/EconomyKitTests/PacingProfileTests.swift` (fixtures `up*`; el
`PackagesConfig` se arma con su `init` memberwise de E5a T1):

```swift
import Foundation
import Testing
@testable import EconomyKit

@Suite("Los perfiles del simulador: lo que se da sin video")
struct PacingProfileTests {
    private func packages(interval: Double = 120) -> PackagesConfig {
        PackagesConfig(schemaVersion: 1, spawnIntervalSeconds: interval, firstPackageAfterSeconds: interval,
                       maxWaiting: 2, windowTiers: 4, tierRatioByBestSupplierLevel: [2, 1.8, 1.6, 1.4])
    }

    private func sources() -> PacingSources {
        PacingSources(
            packages: packages(),
            dailyMinutes: [5, 8, 12, 18, 25, 40, 15],
            freeBoosts: [
                .init(id: "fernet", cooldownSeconds: 3600, effect: .incomeBurst(multiplier: 3, seconds: 90)),
                .init(id: "asado", cooldownSeconds: 21600, effect: .payoutMinutes(10)),
                .init(id: "milanesa", cooldownSeconds: 86400, effect: .offlineStep(step: 0.05, cap: 1.0)),
            ],
            freeHireSeconds: 120
        )
    }

    private func run(_ profile: PacingProfile, _ sources: PacingSources, seed: Double = 0.5) throws -> PacingSimulator.Report {
        try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                            profile: profile, sources: sources, seedFraction: seed).run(maxDays: 5)
    }

    @Test(".bare con fuentes es la base: las fuentes sólo se juegan con su perfil")
    func bareIgnoresSources() throws {
        let base = try upSimulator(upgrades: upCheapLines()).run(maxDays: 5)
        #expect(fingerprint(try run(.bare, sources())) == fingerprint(base))
        #expect(fingerprint(try run(.free, .none)) == fingerprint(base))
    }

    @Test(".free cobra sus fuentes y llega antes")
    func freeUsesItsSources() throws {
        let base = try run(.bare, .none)
        let free = try run(.free, sources())
        #expect((free.sourceTotals["packages.opened"] ?? 0) > 0)
        #expect((free.sourceTotals["coins.daily"] ?? 0) > 0)
        #expect((free.sourceTotals["coins.boosts"] ?? 0) > 0)
        #expect(free.finalLifetimeEarnings > base.finalLifetimeEarnings)
    }

    @Test("el paquete sigue su reloj de juego: con la mitad del intervalo caen casi el doble")
    func packageCadence() throws {
        func opened(_ interval: Double) throws -> Double {
            let report = try run(.free, PacingSources(packages: packages(interval: interval), dailyMinutes: [],
                                                      freeBoosts: [], freeHireSeconds: 0))
            return report.sourceTotals["packages.opened"] ?? 0
        }
        let slow = try opened(240)
        let fast = try opened(120)
        #expect(slow > 0)
        #expect(fast >= 1.6 * slow, "120 s: \(fast) · 240 s: \(slow)")
    }

    @Test("es determinístico, y la semilla sólo mueve el orden de los sorteos")
    func deterministic() throws {
        #expect(fingerprint(try run(.free, sources())) == fingerprint(try run(.free, sources())))
        let a = try run(.free, sources(), seed: 0.1)
        let b = try run(.free, sources(), seed: 0.9)
        #expect(abs((a.sourceTotals["packages.opened"] ?? 0) - (b.sourceTotals["packages.opened"] ?? 0)) <= 2)
    }

    @Test("el sorteo del paquete sin torre es el de la torre")
    func eligibleWithoutTowerIsTheGames() throws {
        var fx = try fxStateAndTower(units: ["a": 2, "b": 1])
        fx.state.run.raiseFrontier(to: 4, cushion: fxConfig().priceCushion)
        let occupancy = (0..<fx.floorTable.count).map { ordinal in fx.tower.floors[ordinal].slots.compactMap { $0 }.count }
        let withTower = PackageRoller.eligibleTypes(state: fx.state, tower: fx.tower, tiers: try fxTiers(),
                                                    floorTable: fx.floorTable, config: fxConfig())
        let without = PackageRoller.eligibleTypes(state: fx.state, tiers: try fxTiers(), floorTable: fx.floorTable,
                                                  config: fxConfig(), occupancy: occupancy)
        #expect(without.map(\.id) == withTower.map(\.id))
    }
}
```

(Si `TowerState.Floor` no expone `slots` con ese nombre, el paso 0 anota el real y el test usa ése.)

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "PacingProfileTests"`
Expected: no compila (`PacingProfile`, `PacingSources`, `seedFraction`, `sourceTotals`, la variante de `eligibleTypes`).

- [ ] **Step 3: La implementación**

`PacingProfile.swift`:

```swift
import Foundation

/// Qué jugador simula el bot (PLAN-v2 E2b). `.free` define el contrato: lo que
/// el juego da sin mirar un video ni pagar. Los demás son las guardas.
public struct PacingProfile: Sendable, Equatable {
    public var usesFreeGifts: Bool
    public var watchesVideos: Bool
    public var ownsShopPermanents: Bool

    public static let bare = PacingProfile(usesFreeGifts: false, watchesVideos: false, ownsShopPermanents: false)
    public static let free = PacingProfile(usesFreeGifts: true, watchesVideos: false, ownsShopPermanents: false)
    public static let ads = PacingProfile(usesFreeGifts: true, watchesVideos: true, ownsShopPermanents: false)
    public static let max = PacingProfile(usesFreeGifts: true, watchesVideos: true, ownsShopPermanents: true)
}

/// Las fuentes de economía que no son comprar y fusionar, como datos. Las arma
/// el llamador desde el contenido real (`PacingFixture` en la app, el CLI desde
/// los JSON): EconomyKit no conoce la app.
public struct PacingSources: Sendable, Equatable {
    public struct FreeBoost: Sendable, Equatable {
        public enum Effect: Sendable, Equatable {
            case incomeBurst(multiplier: Double, seconds: Double)
            case tapBurst(multiplier: Double, seconds: Double)
            case payoutMinutes(Double)
            case offlineStep(step: Double, cap: Double)
        }

        public let id: String
        public let cooldownSeconds: Double
        public let effect: Effect

        public init(id: String, cooldownSeconds: Double, effect: Effect) {
            self.id = id
            self.cooldownSeconds = cooldownSeconds
            self.effect = effect
        }
    }

    public var packages: PackagesConfig?
    /// Minutos de producción del diario, del día 1 al 7 del ciclo.
    public var dailyMinutes: [Double]
    public var freeBoosts: [FreeBoost]
    /// Las contrataciones gratis del Programador al elegir carrera.
    public var freeHireSeconds: Double

    public init(packages: PackagesConfig?, dailyMinutes: [Double], freeBoosts: [FreeBoost], freeHireSeconds: Double) {
        self.packages = packages
        self.dailyMinutes = dailyMinutes
        self.freeBoosts = freeBoosts
        self.freeHireSeconds = freeHireSeconds
    }

    public static let none = PacingSources(packages: nil, dailyMinutes: [], freeBoosts: [], freeHireSeconds: 0)
}
```

`PacingSimulator+Sources.swift` — el reloj de las fuentes y los acumuladores:

```swift
import Foundation

extension PacingSimulator {
    /// Lo que en el juego es azar entra por valor esperado: cada sorteo suma su
    /// probabilidad a un acumulador por resultado, y cuando uno pasa de 1 sale
    /// ese resultado. Arranca en `seedFraction`: determinístico y sin sesgo.
    struct ExpectedDraws {
        private var buckets: [String: Double] = [:]
        let seed: Double

        init(seed: Double) { self.seed = seed }

        /// Suma `probability` al resultado `id` y devuelve cuántas veces salió.
        mutating func add(_ probability: Double, to id: String) -> Int {
            let total = buckets[id, default: seed] + probability
            let whole = Int(total.rounded(.down))
            buckets[id] = total - Double(whole)
            return whole
        }
    }

    /// Los relojes de las fuentes, en segundos ACTIVOS (de juego, como los del
    /// juego), y lo que se cobró.
    struct SourceClocks {
        var nextPackageAt: Double
        var lastBoostAt: [String: Double] = [:]
        var lastDailyDay = -1
        var cycleDay = 0
        var freeHireUntilWall = -Double.infinity
        var draws: ExpectedDraws
    }
}
```

Y en el mismo archivo, las funciones que `playSession` llama (todas `mutating`-libres, reciben
`inout PlayerState`, `inout SourceClocks`, `inout Report`):

- `startSession(state:clocks:report:wall:day:)` — sólo con `profile.usesFreeGifts`: el diario
  (si `day != lastDailyDay`: `RewardScale.coinPayout(minutes: dailyMinutes[cycleDay % count], …)`,
  `cycleDay += 1`) y cada boost cuyo cooldown venció desde `lastBoostAt` (en reloj de PARED, como
  en el juego): `incomeBurst` → `coinPayout(seconds: (k − 1) · T)`; `tapBurst` → `(k − 1) · T ·
  (activeIncomeRate − passiveRate)`; `payoutMinutes` → `coinPayout(minutes:)`; `offlineStep` →
  `state.meta.derivedEffects.offlineEfficiency = min(cap, … + step)` (la Milanesa: el mismo tope
  que la app). Cada monto suma a `report.sourceTotals["coins.daily"]` o `["coins.boosts"]`.
- `tickPackages(state:clocks:report:active:)` — mientras `active ≥ nextPackageAt`: arma la
  ocupación por piso con `floorCount`, pide `PackageRoller.eligibleTypes(state:tiers:floorTable:config:occupancy:)`
  y `PackageRoller.odds(eligible:windowTiers:ratio: packages.tierRatio(bestSupplierLevel: 0))`
  (T7 cambia el 0); por cada `Odds`, `draws.add(odds.probability, to: "pkg.T\(tier)")`; las
  unidades que salen entran como **llegada** (`state.run.units[type] += 1` respetando la
  capacidad, **sin** `registerHire`: no cuentan para la curva), con el tipo de la carrera del bot
  si el tier se bifurca. Abrir uno cuesta `human.hireSeconds` de sesión (un toque).
  `nextPackageAt += spawnIntervalSeconds`. Sin lugar, el paquete espera (hasta `maxWaiting`) y se
  reintenta después de las fusiones.
- La carrera: en `doAllMerges`, donde hoy se fija `state.run.chosenCareerPath = careerPath`, con
  `usesFreeGifts` y `freeHireSeconds > 0` se agrega
  `ActiveModifier(effect: .freeHire, magnitude: 1, expiresAt: wallNow + freeHireSeconds, sourceKey: "career.junior_programmer")`
  a `state.run.activeModifiers`; para eso `doAllMerges` recibe el reloj de pared, y `hireAction`
  cotiza con `quote(typeId:state:now: wallNow)` y, cuando la cotización es 0, la `Action` no llama
  a `registerHire` (la regla de la app: `countsAsPurchase: quote.cost > 0`). Los modificadores
  vencidos se purgan al empezar cada sesión.

`PacingSimulator.swift`: `init` suma `profile: PacingProfile = .bare, sources: PacingSources =
.none, seedFraction: Double = 0.5` al final; `run` crea un `SourceClocks(nextPackageAt:
sources.packages?.firstPackageAfterSeconds ?? .infinity, draws: ExpectedDraws(seed: seedFraction))`
y se lo pasa a `playSession`, que llama a `startSession` al empezar y a `tickPackages` en cada
vuelta del `while` (antes de `doAllMerges`). **La espera** (`wait = (costo − monedas)/rate`) se
recorta al próximo paquete (`min(wait, nextPackageAt − active)`) para que un paquete no se cobre
tarde. `Report` suma `public var sourceTotals: [String: Double] = [:]`.

El archivo de `PackageRoller`: la lógica de `eligibleTypes(state:tower:…)` se muda a la variante
con `occupancy: [Int]` (un `Int` por piso), y la de torre la llama con
`tower.floors.map { $0.slots.compactMap { $0 }.count }` (o el accesor real). Sin cambio de conducta:
lo pinea `eligibleWithoutTowerIsTheGames` y siguen verdes los tests de E5a.

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS (`PacingProfileTests`, los tests de
`PackageRoller` de E5a, `PacingSimulatorTests`). Receta P sin flags → la base exacta.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PacingProfile.swift Packages/EconomyKit/Sources/EconomyKit/PacingSimulator+Sources.swift \
  Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift <archivo de PackageRoller> \
  Packages/EconomyKit/Tests/EconomyKitTests/PacingProfileTests.swift
git diff --cached --stat
git commit -m "feat(pacing): perfiles del simulador y lo que el jugador gratis recibe sin video"
```

---

### Task 6: El perfil `.ads` — lo que da mirar videos

**Objetivo:** las fuentes de video de PLAN-v2 E2b y de E7b-b, con el tiempo que cuesta mirarlas:
offline ×2, diario ×2, ruleta (6 giros por video por día + "repetir premio"), colchón (+ "otro
colchón"), pausa publicitaria (su premio rota), "Fusionar todo" por video, lluvia de paquetes y
carrera ×2. Cada premio pasa por un solo traductor de `RewardSpec` a la economía del bot.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingProfile.swift` (`PacingSources.ads`, `AdsSources`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator+Sources.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` (offline, carrera, fusiones)
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/PacingProfileTests.swift`

**Interfaces:**
- Consumes: `RewardSpec` (**E4a T1**); `TreasuresConfig` (`spawnIntervalSeconds`, `extraOpensPerTreasure`, `odds`, `prizes`), `WheelConfig` (`videoSpinsPerDay`, `effectiveSegments(chestHasSomethingToGive:)`, `odds(chestHasSomethingToGive:)`) (**E5a T2, T3**).
- Produces: `PacingSources.ads: AdsSources?` y `public struct AdsSources: Sendable, Equatable` (`videoSeconds`, `offlineMultiplier`, `dailyMultiplier`, `careerMultiplier`, `wheel: WheelConfig?`, `wheelRepeats: Bool`, `treasures: TreasuresConfig?`, `adBreakIntervalSeconds`, `adBreakPrizes: [RewardSpec]`, `mergeAllCooldownSeconds`, `packageRainCooldownSeconds`, `packageRain: RewardSpec?`), con `init` memberwise público.
- Produces (internal): `PacingSimulator.apply(_ reward: RewardSpec, probability: Double, source: String, state: inout PlayerState, clocks: inout SourceClocks, report: inout Report)`.

**El traductor de premios** (el único lugar donde un `RewardSpec` toca al bot):

| `RewardSpec` | En el bot |
|---|---|
| `.coinsSeconds(s)` | `coinPayout(seconds: s · probability)` (valor esperado directo) |
| `.modifier(effect: .incomeMultiplier \| .passiveMultiplier, magnitude: k, seconds: T)` | `coinPayout(seconds: (k − 1) · T · probability)` |
| `.modifier(effect: .tapMultiplier, k, T)` | `(k − 1) · T · ingreso por toque · probability` |
| `.oro(n)` | `draws.add(n · probability, to: "oro")` → lo que sale va a los campos que toca `grant(.oro)` en la app (paso 0), y el bot compra líneas en el acto |
| `.package(n)` | `draws.add(n · probability, to: "pkg.extra")` → se suman a la cola de paquetes |
| `.nextOfflineMultiplier(k)` | el próximo offline × k |
| `.nextDailyMultiplier(k)` | el próximo diario × k |
| `.wheelSpin(n)` | `n · probability` giros más hoy |
| `.skinChest`, `.clearBoostCooldowns`, `.autoTap`, `.extraSlots`, `.eventImmunity`, otros modificadores | **se ignoran** (declarado: no mueven la economía del bot o la mueven por otra vía) |

- [ ] **Step 0: Pararse en la base**

`grep -n "public enum RewardSpec" -r Packages/EconomyKit/Sources`, `grep -n "struct TreasuresConfig\|struct WheelConfig" -r Packages/EconomyKit/Sources`
y **`grep -n "case .oro" FisuEvolution/Game/State/GameState+Rewards.swift`**: anotá si `grant(.oro)`
suma sólo a `meta.oro` o también a `meta.oroEarnedLifetime` (el bot hace exactamente lo mismo; si
la app toca `oroEarnedLifetime`, el umbral ×5 del bot lo ve). Si falta algo, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

En `PacingProfileTests.swift`, una suite más:

```swift
@Suite("El perfil .ads")
struct PacingAdsProfileTests {
    private func ads(_ change: (inout AdsSources) -> Void = { _ in }) -> AdsSources {
        var ads = AdsSources(
            videoSeconds: 30, offlineMultiplier: 2, dailyMultiplier: 2, careerMultiplier: 2,
            wheel: nil, wheelRepeats: true, treasures: nil,
            adBreakIntervalSeconds: 240,
            adBreakPrizes: [.coinsSeconds(600), .modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 300), .package(1)],
            mergeAllCooldownSeconds: 600, packageRainCooldownSeconds: 1800, packageRain: .package(10)
        )
        change(&ads)
        return ads
    }

    private func run(_ profile: PacingProfile, ads: AdsSources?) throws -> PacingSimulator.Report {
        var sources = PacingSources.none
        sources.dailyMinutes = [5, 8, 12, 18, 25, 40, 15]
        sources.ads = ads
        return try PacingSimulator(config: upConfig(), tiers: upTiers(), upgrades: upCheapLines(),
                                   profile: profile, sources: sources).run(maxDays: 5)
    }

    @Test(".free ignora las fuentes de video")
    func freeIgnoresAds() throws {
        #expect(fingerprint(try run(.free, ads: ads())) == fingerprint(try run(.free, ads: nil)))
    }

    @Test(".ads cobra más y mira videos")
    func adsEarnsMore() throws {
        let free = try run(.free, ads: ads())
        let withAds = try run(.ads, ads: ads())
        #expect((withAds.sourceTotals["videos"] ?? 0) > 0)
        #expect((withAds.sourceTotals["coins.adBreak"] ?? 0) > 0)
        #expect(withAds.finalLifetimeEarnings > free.finalLifetimeEarnings)
    }

    @Test("mirar un video cuesta tiempo de sesión: con videos de 10 minutos, .ads pierde")
    func videosCostTime() throws {
        let slow = try run(.ads, ads: ads { $0.videoSeconds = 600 })
        let fast = try run(.ads, ads: ads())
        #expect(slow.finalLifetimeEarnings < fast.finalLifetimeEarnings)
    }

    @Test("el offline ×2 duplica lo que cobra al volver")
    func offlineDoubles() throws {
        let base = try run(.ads, ads: ads { $0.offlineMultiplier = 1 })
        let doubled = try run(.ads, ads: ads())
        #expect((doubled.sourceTotals["coins.offline"] ?? 0) > 1.5 * (base.sourceTotals["coins.offline"] ?? 0))
    }

    @Test("un premio ignorado no mueve nada")
    func ignoredRewardsDoNothing() throws {
        let chest = try run(.ads, ads: ads { $0.adBreakPrizes = [.skinChest(1)] })
        let none = try run(.ads, ads: ads { $0.adBreakPrizes = [] ; $0.adBreakIntervalSeconds = .infinity })
        #expect(chest.finalLifetimeEarnings <= none.finalLifetimeEarnings)
    }
}
```

(Para que `coins.offline` exista, `applyOffline` suma lo que cobra a `report.sourceTotals["coins.offline"]`
en todos los perfiles.)

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "PacingAdsProfileTests"`
Expected: no compila (`AdsSources`, `sources.ads`).

- [ ] **Step 3: La implementación**

`PacingProfile.swift`: `AdsSources` con sus doce campos y su `init` público; `PacingSources`
suma `public var ads: AdsSources?` (default `nil` en `none` y en el `init`, al final).

`PacingSimulator+Sources.swift`, todo bajo `profile.watchesVideos && sources.ads != nil`, y cada
video suma `ads.videoSeconds` al `elapsed` de la sesión y 1 a `sourceTotals["videos"]`:

- **Offline ×2**: en `applyOffline`, el crédito por `offlineMultiplier` (un video al volver; en el
  juego el popup sale desde 30 s y los huecos del bot son de horas).
- **Diario ×2**: en `startSession`, el diario por `dailyMultiplier` (un video).
- **Ruleta**: en la primera sesión de cada día, `wheel.videoSpinsPerDay` giros (+ los de T7); cada
  uno aplica cada `effectiveSegments(chestHasSomethingToGive: false)` con su probabilidad de
  `odds(chestHasSomethingToGive: false)`, y con `wheelRepeats` otra vez (el "repetir premio" es otro
  video).
- **Colchón**: cada `treasures.spawnIntervalSeconds` activos, un video lo abre y aplica cada premio
  con su probabilidad; `extraOpensPerTreasure` veces más con otro video ("otro colchón").
- **Pausa publicitaria**: cada `adBreakIntervalSeconds` activos, aplica
  `adBreakPrizes[índice % count]` con probabilidad 1 y avanza el índice (la rotación de E7b-a).
- **Fusionar todo**: cada `mergeAllCooldownSeconds` activos queda una ficha; la próxima tanda de
  `doAllMerges` con ≥ 2 fusiones **no cobra `mergeSeconds`** (las hace de una) y cuesta un video.
- **Lluvia de paquetes**: cada `packageRainCooldownSeconds`, aplica `packageRain` (un video).
- **Carrera ×2**: el `freeHireSeconds` de T5 por `careerMultiplier` (un video).

`apply(_:probability:source:state:clocks:report:)` es la tabla de arriba; suma lo cobrado a
`sourceTotals["coins.<source>"]` y el ORO a `sourceTotals["oro.fromSources"]`. El ORO que sale se
gasta en líneas en el acto (`buyPermanentUpgrades`, que hoy sólo corre al reencarnar).

Los relojes nuevos (`nextMattressAt`, `nextAdBreakAt`, `mergeAllTokens`, `nextRainAt`,
`adBreakIndex`, `pendingOfflineMultiplier`, `pendingDailyMultiplier`, `wheelDay`) van en
`SourceClocks`, y la espera del bot se recorta al próximo de todos (como el paquete en T5).

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS. Receta P sin flags → la base exacta.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PacingProfile.swift Packages/EconomyKit/Sources/EconomyKit/PacingSimulator+Sources.swift \
  Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift Packages/EconomyKit/Tests/EconomyKitTests/PacingProfileTests.swift
git diff --cached --stat
git commit -m "feat(pacing): el perfil .ads — ruleta, colchón, pausa, Fusionar todo y los ×2, con su tiempo de video"
```

---

### Task 7: El perfil `.max` — los permanentes de la tienda

**Objetivo:** el jugador que paga, con los tres permanentes de la tienda de ORO al tope desde el
arranque: lugares extra (la tabla de pisos agrandada en un solo lugar, como en el juego), mejor
proveedor (el `r` del paquete) y los giros diarios de más.

**Files:**
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingProfile.swift` (`ShopPermanents`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift` (`floorTable` en el `init`)
- Modify: `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator+Sources.swift` (el `r` y los giros)
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/PacingProfileTests.swift`

**Interfaces:**
- Consumes: `FloorTable.expanded(by:)` (**E6b T6**); los niveles los calcula el llamador con `OroShop.extraSlots/bestSupplierLevel/bonusDailyWheelSpins` (**E6a T2**).
- Produces: `PacingSources.shop: ShopPermanents?` y `public struct ShopPermanents: Sendable, Equatable` (`extraSlots: Int`, `bestSupplierLevel: Int`, `bonusDailyWheelSpins: Int`, `init`).

- [ ] **Step 0: Pararse en la base**

`grep -n "func expanded" -r Packages/EconomyKit/Sources` (E6b T6). Sin ella, `NEEDS_CONTEXT`.

- [ ] **Step 1: Los tests, en rojo**

En `PacingProfileTests.swift`:

```swift
@Suite("El perfil .max")
struct PacingMaxProfileTests {
    @Test(".max agranda los pisos y sólo .max lo hace")
    func maxExpandsFloors() throws {
        var sources = PacingSources.none
        sources.shop = ShopPermanents(extraSlots: 5, bestSupplierLevel: 3, bonusDailyWheelSpins: 3)
        let maxed = try PacingSimulator(config: upConfig(capacity: 4), tiers: upTiers(), profile: .max, sources: sources)
        let ads = try PacingSimulator(config: upConfig(capacity: 4), tiers: upTiers(), profile: .ads, sources: sources)
        #expect(maxed.floorTable[0].capacity == 9)
        #expect(ads.floorTable[0].capacity == 4)
    }

    @Test("con lugares extra el bot llega más lejos en el mismo tiempo")
    func maxIsFaster() throws {
        var sources = PacingSources.none
        sources.shop = ShopPermanents(extraSlots: 5, bestSupplierLevel: 0, bonusDailyWheelSpins: 0)
        let ads = try PacingSimulator(config: upConfig(capacity: 4), tiers: upTiers(), upgrades: upCheapLines(),
                                      profile: .ads, sources: sources).run(maxDays: 5)
        let maxed = try PacingSimulator(config: upConfig(capacity: 4), tiers: upTiers(), upgrades: upCheapLines(),
                                        profile: .max, sources: sources).run(maxDays: 5)
        #expect(maxed.finalLifetimeEarnings > ads.finalLifetimeEarnings)
    }
}
```

- [ ] **Step 2: Verlos fallar**

Run: `swift test --package-path Packages/EconomyKit --filter "PacingMaxProfileTests"` → no compila.

- [ ] **Step 3: La implementación**

`ShopPermanents` en `PacingProfile.swift`; `PacingSources` suma `public var shop: ShopPermanents?`.
En `PacingSimulator.init`: `let base = try FloorTable(floors: config.floors, maxTier: tiers.maxTier)`
y `floorTable = profile.ownsShopPermanents ? base.expanded(by: sources.shop?.extraSlots ?? 0) : base`.
En `tickPackages`, el `r` sale de `tierRatio(bestSupplierLevel: profile.ownsShopPermanents ?
(sources.shop?.bestSupplierLevel ?? 0) : 0)`; en la ruleta, los giros suman
`bonusDailyWheelSpins` con `.max`.

- [ ] **Step 4: Verde y oráculo**

Run: `swift test --package-path Packages/EconomyKit` → PASS. Receta P sin flags → la base exacta.
`Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Packages/EconomyKit/Sources/EconomyKit/PacingProfile.swift Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift \
  Packages/EconomyKit/Sources/EconomyKit/PacingSimulator+Sources.swift Packages/EconomyKit/Tests/EconomyKitTests/PacingProfileTests.swift
git diff --cached --stat
git commit -m "feat(pacing): el perfil .max con los permanentes de la tienda"
```

---

### Task 8: El CLI — perfiles, fuentes, perillas y el contrato 2.0

**Objetivo:** el loop de calibración de T12–T13 en una línea por corrida: `--profile`, las
fuentes leídas de `Resources/Config`, cada perilla como flag (sin escribir JSONs temporales), el
descuento de prestigio, la semilla, y un semáforo que imprime **el contrato de la 2.0** en lugar de
los targets de F7.1c. Con los flags de siempre, la salida de siempre (el oráculo no se toca).

**Files:**
- Modify: `Tools/pacing-sim/Sources/main.swift`
- Modify: `Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift` (`floorCapacity`, `oroDivisor`, `oroExponent`)
- Modify: `Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift`

**Interfaces:**
- Produces: `EconomyKnobs.floorCapacity: Int?` (todos los pisos), `.oroDivisor: Double?`, `.oroExponent: Double?`.
- Produces (CLI): `--profile bare|free|ads|max` (default `bare` hasta T14), `--sources <dir>` (sin él, busca `../Config/` al lado de `--economy`, como `--upgrades`, y **lo avisa en la segunda línea** si no lo encuentra), `--seed-fraction x` (0,5), `--merge-refund r`, `--growth g`, `--price-relief K`, `--staffed x`, `--wall`, `--inherit`, `--capacity n`, `--bands "8:1.45,13:1.6,25:1.7"`, `--growth-step "0.01@luxury"`, `--oro-divisor d`, `--oro-exponent e`, `--prestige-discount` / `--no-prestige-discount` (cobrar o no el descuento de `prestige_unlocks.json`; default **no** hasta T14).

- [ ] **Step 1: El test de las perillas nuevas, en rojo**

En `EconomyKnobsTests`:

```swift
    @Test("la capacidad llega a los diez pisos y el ORO a su bloque")
    func capacityAndOroLand() throws {
        let tuned = try fxConfig().tuned(EconomyKnobs(floorCapacity: 15, oroDivisor: 5e9, oroExponent: 0.3))
        #expect(tuned.floors.allSatisfy { $0.capacity == 15 })
        #expect(tuned.oro.divisor == 5e9)
        #expect(tuned.oro.exponent == 0.3)
        #expect(tuned.floors.map(\.id) == fxConfig().floors.map(\.id))
    }
```

Run: `swift test --package-path Packages/EconomyKit --filter "EconomyKnobsTests"` → no compila.

- [ ] **Step 2: Las perillas**

`EconomyKnobs`: los tres campos al final del `init`; en `tuned`:

```swift
        if let capacity = knobs.floorCapacity, let floors = root["floors"] as? [[String: Any]] {
            root["floors"] = floors.map { floor in
                var floor = floor
                floor["capacity"] = capacity
                return floor
            }
        }
        if let value = knobs.oroDivisor { oro["divisor"] = value }
        if let value = knobs.oroExponent { oro["exponent"] = value }
```

Run: el mismo filtro → PASS.

- [ ] **Step 3: El CLI**

`main.swift`:

1. **`SimArguments`** suma `profile: PacingProfile`, `sourcesURL: URL?`, `seedFraction: Double`,
   `knobs: EconomyKnobs`, `prestigeDiscount: Bool`. `parseArguments` lee cada flag; `--bands` se
   parte por `,` y `:`; `--growth-step` por `@`; `--wall` e `--inherit` ponen `true`. Un flag
   desconocido sigue siendo un error.
2. **Las fuentes** (`loadSources(from: URL, profile:) throws -> PacingSources`): decodifica con los
   tipos de EconomyKit `packages.json` (`PackagesConfig`), `treasures.json` (`TreasuresConfig`),
   `wheel.json` (`WheelConfig`), `oro_shop.json` (`OroShopCatalog`, para `ShopPermanents` con los
   niveles al tope por `OroShop.extraSlots/bestSupplierLevel/bonusDailyWheelSpins`) y
   `prestige_unlocks.json` (`PrestigeUnlocks`); y con **espejos mínimos** (como `UpgradesFile`) lo
   que es de la app: `daily_rewards.json` (`days[].minutes`), `boosts.json` (`id`, `effectType`,
   `magnitude`, `durationSeconds`, `cooldownSeconds` → `FreeBoost`: `incomeMultiplier` →
   `incomeBurst`, `tapMultiplier` → `tapBurst`, `periodicPayout` → `payoutMinutes`,
   `offlineEfficiencyPermanent` → `offlineStep(cap: 1.0)` con el `EffectCaps.offline` de la app
   anotado en un comentario; `spawnCostMultiplier` se ignora, declarado), `careers.json`
   (`junior_programmer.durationSeconds`), `rewarded_ads.json` (`sideRail`, `adBreak.prizes`) y la
   cadencia de cortes de `ads.json`. **Si un archivo falta, la fuente queda vacía y se imprime una
   línea `⚠️ sin <archivo>`** (la trampa 39 en versión fuentes).
3. **La corrida**: `config.tuned(arguments.knobs)`; `PacingSimulator(…, prestigeUnlocks:
   prestigeDiscount ? unlocks : nil, profile:, sources:, seedFraction:)`. ⚠️ **Hasta T14 el default
   de `prestigeDiscount` es `false`** (el bot de la base); T14 lo invierte junto con el perfil y la
   política.
4. **La salida**: conserva **tal cual** los renglones `  reencarnaciones: N  (…)` y
   `  dios: X ACTIVAS  (…)` (los lee `oraculo.sh`). Suma la línea `   perfil: free · fuentes: …` en
   el encabezado, `oro al llegar a dios`, `ORO por reencarnación`, `pasivos comprados por run`,
   `pisos en marcha (máx / en dios)`, `el techo del prestigio por run` y `lo que dieron las fuentes`
   (`sourceTotals`). La sección "-- Targets (±30 % ya aplicado) --" se reemplaza por
   **"-- El contrato de la 2.0 --"**: los nueve puntos y la guarda del ORO de "El contrato en una
   página", con ✅/❌ (el 8 y el 9 dicen "lo mide PacingContractTests": piden otras corridas). El
   CSV suma las series nuevas y las perillas.

- [ ] **Step 4: Verificación**

1. Receta P **sin flags nuevos** (`--economy --tiers --upgrades --max-days 90`) → `dios:` y
   `reencarnaciones:` de la base exacta (y el `⚠️ sin fuentes` no aparece porque `.bare` no las pide).
2. `… --profile free --sources $R/Config --prestige-threshold 4 --max-days 400` → corre, imprime el
   contrato y la línea `perfil: free`; las fuentes que existan en el árbol aparecen sin `⚠️`.
3. `… --merge-refund 0 --price-relief 0 --staffed 0` → idéntico al punto 1 (las perillas en v1).
4. `swift test --package-path Packages/EconomyKit` → PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 5: Commit**

```bash
git add Tools/pacing-sim/Sources/main.swift Packages/EconomyKit/Sources/EconomyKit/EconomyKnobs.swift \
  Packages/EconomyKit/Tests/EconomyKitTests/EconomyKnobsTests.swift
git diff --cached --stat
git commit -m "feat(pacing-sim): perfiles, fuentes y perillas por flag, y el contrato de la 2.0 en el semáforo"
```

---

### Task 9: La suite del contrato, con el reporte cacheado y los asserts apagados

**Objetivo:** el contrato de PLAN-v2 E2b como código, contra el **contenido real**, en una suite
que simula **una vez por perfil** (no una vez por test como `PacingTests`). Los asserts del contrato
nacen **apagados** (`.disabled`): con los datos de hoy no se cumplen y prenderlos es el trabajo de
T14. Lo que sí corre desde ya: que las fuentes del contenido llegan al simulador sin perder nada.

**Files:**
- Create: `FisuEvolutionTests/Support/PacingFixture.swift` (+ `xcodegen generate`)
- Create: `FisuEvolutionTests/PacingContractTests.swift` (+ `xcodegen generate`)

**Interfaces:**
- Consumes: `GameContent.packages/.treasures/.wheel` (**E5a T5**), `.oroShop` (**E6a T4**), `.rewardedAds.sideRail` (**E7b-b T1**) y `.adBreak` (**E7b-a T3**), `.dailyRewards.days[].minutes` (**E2a T11**), `.careers` (**E2a T12**), `.boosts`, `.prestigeUnlocks`, `.upgradesConfig`; `PacingTests.permanentLines(from:)`; `EffectCaps.offline`.
- Produces: `enum PacingFixture` con `static func sources(_ content: GameContent) throws -> PacingSources`, `static func simulator(_ content: GameContent, profile: PacingProfile, policy: PacingSimulator.ReincarnationPolicy) throws -> PacingSimulator`, `static let contractPolicy = PacingSimulator.ReincarnationPolicy.whenOroMultiplies(4)`.
- Produces: `enum PacingReports` con `static let free, ads, max, never: Result<PacingSimulator.Report, any Error>` (cada uno se calcula una sola vez por proceso de test).

- [ ] **Step 0: Pararse en la base**

`grep -n "let packages\|let treasures\|let wheel\|let oroShop\|let rewardedAds" FisuEvolution/Managers/GameContentLoader.swift`
y `grep -n "sideRail\|adBreak" FisuEvolution/Managers/*.swift`. Si falta alguna, `NEEDS_CONTEXT`
(o, si el controlador lo autoriza, el mapeo deja esa fuente vacía con un `Issue.record` que lo diga
y la tarea sigue: el contrato está apagado igual).

- [ ] **Step 1: Los tests, en rojo**

`FisuEvolutionTests/Support/PacingFixture.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El contenido real traducido a lo que el simulador entiende. Es el único
/// lugar donde la app arma `PacingSources`; el CLI tiene su espejo y T14
/// compara las dos salidas.
enum PacingFixture {
    static let contractPolicy = PacingSimulator.ReincarnationPolicy.whenOroMultiplies(4)

    static func sources(_ content: GameContent) throws -> PacingSources {
        var sources = PacingSources(
            packages: content.packages,
            dailyMinutes: content.dailyRewards.days.sorted { $0.day < $1.day }.compactMap(\.minutes),
            freeBoosts: content.boosts.boosts.compactMap(freeBoost),
            freeHireSeconds: content.careers.careers.first { $0.id == "junior_programmer" }?.durationSeconds ?? 0
        )
        let rail = content.rewardedAds.sideRail
        sources.ads = AdsSources(
            videoSeconds: 30, offlineMultiplier: 2, dailyMultiplier: 2, careerMultiplier: 2,
            wheel: content.wheel, wheelRepeats: true, treasures: content.treasures,
            // La pausa bonificada alterna 1:1 con el común: sale cada dos cortes.
            adBreakIntervalSeconds: 2 * (try forcedCadence()),
            adBreakPrizes: content.rewardedAds.adBreak?.prizes ?? [],
            mergeAllCooldownSeconds: rail?.mergeAllCooldownSeconds ?? .infinity,
            packageRainCooldownSeconds: rail?.packageRainCooldownSeconds ?? .infinity,
            packageRain: rail?.packageRain
        )
        let maxLevels = Dictionary(uniqueKeysWithValues: content.oroShop.items.filter(\.isPermanent).map { ($0.id, $0.levels.count) })
        sources.shop = ShopPermanents(
            extraSlots: OroShop.extraSlots(levels: maxLevels, catalog: content.oroShop),
            bestSupplierLevel: OroShop.bestSupplierLevel(levels: maxLevels, catalog: content.oroShop),
            bonusDailyWheelSpins: OroShop.bonusDailyWheelSpins(levels: maxLevels, catalog: content.oroShop)
        )
        return sources
    }

    /// La cadencia de los forzados del `ads.json` embarcado (E7a): lo mismo que
    /// lee el pacer al arrancar sin config remota.
    private static func forcedCadence() throws -> Double {
        let url = try #require(Bundle.main.url(forResource: "ads", withExtension: "json"))
        return try AdsRemoteConfig.decodeValidated(Data(contentsOf: url), publisherID: nil).cadence.minSecondsBetweenForced
    }

    private static func freeBoost(_ boost: BoostsConfig.Boost) -> PacingSources.FreeBoost? {
        let effect: PacingSources.FreeBoost.Effect
        switch boost.effectType {
        case .incomeMultiplier: effect = .incomeBurst(multiplier: boost.magnitude, seconds: boost.durationSeconds)
        case .tapMultiplier: effect = .tapBurst(multiplier: boost.magnitude, seconds: boost.durationSeconds)
        case .periodicPayout: effect = .payoutMinutes(boost.magnitude)
        case .offlineEfficiencyPermanent: effect = .offlineStep(step: boost.magnitude, cap: EffectCaps.offline)
        default: return nil
        }
        return .init(id: boost.id, cooldownSeconds: boost.cooldownSeconds, effect: effect)
    }

    static func simulator(
        _ content: GameContent, profile: PacingProfile, policy: PacingSimulator.ReincarnationPolicy
    ) throws -> PacingSimulator {
        try PacingSimulator(
            config: content.economy,
            tiers: content.tiers,
            human: .init(reincarnation: policy),
            upgrades: try PacingTests.permanentLines(from: content.upgradesConfig),
            prestigeUnlocks: content.prestigeUnlocks,
            profile: profile,
            sources: try sources(content)
        )
    }
}

/// Las cuatro partidas del contrato, simuladas UNA vez por proceso: swift-testing
/// construye una instancia de suite por test, y cada simulación entera cuesta
/// segundos (PLAN-v2: "una suite aparte con el reporte cacheado").
enum PacingReports {
    static let free = play(.free, PacingFixture.contractPolicy, days: 400)
    static let ads = play(.ads, PacingFixture.contractPolicy, days: 400)
    static let max = play(.max, PacingFixture.contractPolicy, days: 400)
    static let never = play(.free, .never, days: 400)

    private static func play(
        _ profile: PacingProfile, _ policy: PacingSimulator.ReincarnationPolicy, days: Int
    ) -> Result<PacingSimulator.Report, any Error> {
        Result {
            let content = try GameContentLoader.load(from: .main)
            return try PacingFixture.simulator(content, profile: profile, policy: policy).run(maxDays: days)
        }
    }
}
```

(Los nombres de los campos de la app —`dailyRewards.days[].minutes` (E2a T11),
`careers.careers[].durationSeconds` (E2a T12), `AdsRemoteConfig.decodeValidated(_:publisherID:)` y
`cadence.minSecondsBetweenForced` (E7a, `AdsRemoteConfig.swift:38-160`; si `publisherID: nil` no
valida, se pasa el del `Info.plist` como hace el pacer), `oroShop.items[].isPermanent`/`levels`
(E6a T2)— se confirman en el paso 0 y se usan los reales; el que no exista se reemplaza por el
campo que la tarea de origen haya creado, nunca por un literal. `#require` en una función que no es
un test es válido: tira, y el `Result` del caché lo convierte en el rojo del test que lo lee.)

`FisuEvolutionTests/PacingContractTests.swift`:

```swift
import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El contrato de pacing de la 2.0 (PLAN-v2 E2b), en el reloj del simulador,
/// con el perfil `.free` y la política ×5. Reemplaza a `theOwnersTargetsAreMet`
/// (24 h / 8 reencarnaciones de la v1). Es CONTRATO, no banda: si se pone rojo,
/// el juego dejó de cumplir lo que el dueño pidió.
@Suite("El contrato de pacing de la 2.0")
struct PacingContractTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private func free() throws -> PacingSimulator.Report { try PacingReports.free.get() }
    private func minutes(_ seconds: Double?) -> Double { (seconds ?? .infinity) / 60 }

    // MARK: Lo que corre desde ya

    @Test("las fuentes del contenido real llegan enteras al simulador")
    func sourcesArrive() throws {
        let sources = try PacingFixture.sources(content)
        #expect(sources.packages == content.packages)
        #expect(sources.dailyMinutes.count == content.dailyRewards.days.count)
        #expect(sources.freeBoosts.map(\.id).contains("asado"))
        #expect(sources.freeHireSeconds > 0)
        #expect(sources.ads?.wheel == content.wheel)
        #expect(sources.ads?.treasures == content.treasures)
        #expect((sources.shop?.extraSlots ?? 0) > 0)
    }

    @Test("las cuatro partidas se simulan y llegan a algún lado")
    func reportsRun() throws {
        for report in [try PacingReports.free.get(), try PacingReports.ads.get(), try PacingReports.max.get()] {
            #expect(report.finalMaxTier > 1)
        }
    }

    // MARK: El contrato

    @Test("1 · Dios entre 1.900 y 2.100 minutos activos", .disabled("E2b T14 lo prende con la calibración"))
    func godTiming() throws {
        let god = minutes(try free().godActive)
        #expect(god >= 1900 && god <= 2100, "Dios a los \(god) min activos")
    }

    @Test("2 · cinco o seis reencarnaciones", .disabled("E2b T14 lo prende con la calibración"))
    func reincarnations() throws {
        #expect((5...6).contains(try free().reincarnations))
    }

    @Test("3 · las 7 líneas al tope antes del 80 % de Dios y no antes de la 5ª reencarnación", .disabled("E2b T14 lo prende con la calibración"))
    func linesMaxed() throws {
        let report = try free()
        let maxed = try #require(report.maxedUpgradesActiveSeconds, "nunca maxeó: \(report.finalPermanentUpgradeLevels)")
        let god = try #require(report.godActive)
        #expect(maxed <= 0.8 * god, "maxeó a \(maxed / 3600) h, Dios a \(god / 3600) h")
        #expect(try #require(report.reincarnationsAtMaxedUpgrades) >= 5)
    }

    @Test("4 · la 1ª reencarnación entre 0,75 y 1,5 h activas", .disabled("E2b T14 lo prende con la calibración"))
    func firstReincarnation() throws {
        let first = try #require(try free().firstReincarnationActive) / 3600
        #expect(first >= 0.75 && first <= 1.5, "\(first) h")
    }

    @Test("5 · cada run llega más lejos y antes a cada tier ya visto", .disabled("E2b T14 lo prende con la calibración"))
    func eachRunFurtherAndFaster() throws {
        let report = try free()
        for (previous, next) in zip(report.maxTierPerRun, report.maxTierPerRun.dropFirst()) {
            #expect(next >= previous + 1, "T\(previous) → T\(next)")
        }
        for index in report.tierReachedPerRun.indices.dropLast() {
            let before = report.tierReachedPerRun[index]
            let after = report.tierReachedPerRun[index + 1]
            for tier in stride(from: 2, through: report.maxTierPerRun[index], by: 1) {
                guard let first = before[tier], let second = after[tier] else { continue }
                #expect(second <= first, "run \(index + 2), T\(tier): \(second) s contra \(first) s")
            }
        }
    }

    @Test("6 · reencarnar paga ≥ 65 % de la run 2 en adelante", .disabled("E2b T14 lo prende con la calibración"))
    func prestigePays() throws {
        let report = try free()
        #expect(!report.prestigePayoffPerRun.isEmpty)
        for (index, payoff) in report.prestigePayoffPerRun.enumerated() {
            #expect(payoff >= 0.65, "run \(index + 2): \(payoff) (techo \(report.prestigeCeilingPerRun[index]))")
        }
    }

    @Test("7 · la primera llegada a cada piso cae en su ventana", .disabled("E2b T14 lo prende con la calibración"))
    func floorWindows() throws {
        let windows: [String: ClosedRange<Double>] = [
            "urban": 0...1.5, "corporate": 6...10, "luxury": 35...60, "island": 200...300,
            "moon": 520...680, "mars": 900...1100, "solar": 1350...1550, "galaxy": 1650...1850,
            "god_realm": 1900...2100,
        ]
        let report = try free()
        for (floor, window) in windows {
            let arrived = minutes(report.floorUnlockActiveSeconds[floor])
            #expect(window.contains(arrived), "\(floor): \(arrived) min")
        }
    }

    @Test("8 · sin reencarnar no se llega a Dios", .disabled("E2b T14 lo prende con la calibración"))
    func noPrestigeNoGod() throws {
        let never = try PacingReports.never.get()
        #expect(never.godActive == nil, "llegó en \(minutes(never.godActive)) min")
    }

    @Test("9 · .ads tarda ≥ 55 % de .free y .max ≥ 50 %", .disabled("E2b T14 lo prende con la calibración"))
    func profilesGuard() throws {
        let free = try #require(try free().godActive)
        let ads = try #require(try PacingReports.ads.get().godActive)
        let max = try #require(try PacingReports.max.get().godActive)
        #expect(ads >= 0.55 * free, ".ads \(ads / free)")
        #expect(max >= 0.50 * free, ".max \(max / free)")
    }

    @Test("la escala del ORO: un jugador gratis junta 5.000–12.000 hasta Dios", .disabled("E2b T14 lo prende con la calibración"))
    func oroScale() throws {
        let oro = try #require(try free().oroAtGod)
        #expect(oro >= 5000 && oro <= 12000, "\(oro) ORO")
    }
}
```

`/opt/homebrew/bin/xcodegen generate`.

- [ ] **Step 2: Verlos fallar**

Receta R con `-only-testing:FisuEvolutionTests/PacingContractTests` antes de crear el fixture →
no compila (`PacingFixture`, `PacingReports`).

- [ ] **Step 3: Verdes los dos que corren**

Con los dos archivos creados → `sourcesArrive` y `reportsRun` PASS; los diez del contrato salen
**skipped** con el motivo (la salida tiene que nombrarlos así: un "0 tests" no sirve).

- [ ] **Step 4: Oráculo**

`Tools/v2/oraculo.sh completo` → `VERDE`, con `PacingContractTests` en la cuenta de unit. Anotá en
el reporte cuánto tarda la suite (las tres simulaciones de 400 días + la `.never`): si pasa de
~60 s en la máquina cargada, el reporte lo dice (el controlador decide si la manda a `completo`
solamente).

- [ ] **Step 5: Commit**

```bash
git add FisuEvolutionTests/Support/PacingFixture.swift FisuEvolutionTests/PacingContractTests.swift
git diff --cached --stat
git commit -m "test(pacing): el contrato de la 2.0 contra el contenido real, cacheado y apagado hasta la calibración"
```

---

### Task 10: Los presupuestos analíticos — visitantes, eventos, consumibles y logros

**Objetivo:** lo que PLAN-v2 deja fuera del simulador ("eventos, visitantes y consumibles con
tests de presupuesto analíticos"), en la suite de presupuesto que E2a ya dejó, y la calibración de
la palanca que E4a nombró (`visitors.json` `coinsSecondsScale`, su duda 1: la plata de los
visitantes rompe el presupuesto de E2a).

**Files:**
- Modify: `FisuEvolutionTests/RewardBudgetTests.swift` (una suite `EngagementBudgetTests` en el mismo archivo: los helpers de E2a son privados)
- Modify: `FisuEvolution/Resources/Config/visitors.json` (`coinsSecondsScale`) — y, sólo si el paso 2 lo pide, `events.json` (las `coinsSeconds` de los positivos)

**Interfaces:**
- Consumes: `RewardBudgetTests.budget` (0,12), `productionMinutesPerDay`, `asadoClaimsPerDay`, `dailyMinutes`, `asado` (E2a T11; si son `private`, se promueven a `fileprivate`); `VisitorsConfig` y `EventCatalog` (**E4a T5, T4, T7, T9**); `OroShopCatalog` (**E6a T4**).
- Produces: nada que otra tarea consuma; el valor calibrado de `coinsSecondsScale`.

**Las cuentas** (todas en minutos de producción por día del jugador del simulador, la unidad de
E2a):

```
visitas/día        = minutos activos/día ÷ (minutos entre visitas, el medio de [min, max])
regalo por visita  = Σ_guiones peso·(Σ coinsSeconds de mechanic.rewards de gift/challenge/gossip) ÷ Σ pesos
                     × coinsSecondsScale ÷ 60          ← bruto: los trueques (arresto, multa, venta,
                                                          cambio, take) no regalan, se cobran
eventos/día        = minutos activos/día ÷ (intervalSeconds/60)
regalo por evento  = Σ_positivos peso·coinsSeconds ÷ Σ pesos (de todos) ÷ 60
presupuesto        = 0,12 × producción/día − (diario promedio + asado/día)     ← lo que dejó E2a
```

- [ ] **Step 0: Pararse en la base**

`grep -n "struct RewardBudgetTests\|func productionMinutesPerDay" FisuEvolutionTests/RewardBudgetTests.swift`,
`grep -n "coinsSecondsScale\|intervalMinSeconds" FisuEvolution/Resources/Config/visitors.json`,
`grep -n "intervalSeconds" FisuEvolution/Resources/Config/events.json`.

- [ ] **Step 1: Los tests, en rojo (o en verde: decirlo)**

Al final de `RewardBudgetTests.swift`:

```swift
/// Lo que el simulador no juega (PLAN-v2 E2b): visitantes y eventos se miden
/// acá, contra el mismo 12 % de un día que el diario y el asado.
@Suite("Presupuesto: visitantes, eventos, consumibles y logros")
struct EngagementBudgetTests {
    let content: GameContent
    let human = PacingSimulator.HumanModel()

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private var activeMinutesPerDay: Double {
        Double(human.sessionStartOffsets.count) * human.sessionSeconds / 60
    }

    private func giftMinutesPerVisit() -> Double {
        let visitors = content.visitors
        let main = visitors.scripts.filter { $0.lane == .main && !$0.eventOnly }
        let weights = main.reduce(0.0) { $0 + Double($1.weight) }
        guard weights > 0 else { return 0 }
        let gifts = main.reduce(0.0) { sum, script in
            guard script.mechanic.isGift else { return sum }
            let seconds = script.mechanic.rewards.reduce(0.0) { total, reward in
                if case .coinsSeconds(let s) = reward { return total + s }
                return total
            }
            return sum + Double(script.weight) * seconds
        }
        return gifts / weights * visitors.coinsSecondsScale / 60
    }

    private func giftMinutesPerEvent() -> Double {
        let events = content.events.events
        let weights = events.reduce(0.0) { $0 + Double($1.weight) }
        guard weights > 0 else { return 0 }
        let gifts = events.filter { $0.polarity == .positive }.reduce(0.0) { sum, event in
            sum + Double(event.weight) * event.effects.reduce(0.0) { total, effect in
                if case .coinsSeconds(let s) = effect { return total + s }
                return total
            }
        }
        return gifts / weights / 60
    }

    @Test("visitantes y eventos entran en lo que el diario y el asado dejan del 12 %")
    func visitorsAndEventsFit() throws {
        let visitsPerDay = activeMinutesPerDay
            / ((content.visitors.intervalMinSeconds + content.visitors.intervalMaxSeconds) / 2 / 60)
        let eventsPerDay = activeMinutesPerDay / (content.events.intervalSeconds / 60)
        let spent = visitsPerDay * giftMinutesPerVisit() + eventsPerDay * giftMinutesPerEvent()
        let left = try RewardBudget.leftAfterDailyAndAsado(content: content, human: human)
        #expect(spent <= left, "visitantes y eventos regalan \(spent) min/día; quedan \(left)")
    }

    @Test("los consumibles de ORO respetan el ancla: 1 h de producción ≈ 90 ORO (±50 %)")
    func consumablesFollowTheAnchor() throws {
        for item in content.oroShop.items where !item.isPermanent {
            guard let price = item.price else { continue }
            let hours = item.rewards.reduce(0.0) { total, reward in
                switch reward {
                case .coinsSeconds(let s): return total + s / 3600
                case .modifier(let effect, let k, let seconds) where effect == .incomeMultiplier || effect == .passiveMultiplier:
                    return total + (k - 1) * seconds / 3600
                default: return total
                }
            }
            guard hours > 0 else { continue }
            let perHour = Double(price) / hours
            #expect(perHour >= 45 && perHour <= 135, "\(item.id): \(perHour) ORO por hora de producción")
        }
    }
}
```

Y en el mismo archivo, la cuenta que comparten las dos suites. Los helpers privados de E2a
(`productionMinutesPerDay`, `asadoClaimsPerDay`) **se mudan acá** sin cambiar su aritmética, y
`RewardBudgetTests` pasa a llamarlos (mecánico: la cuenta existe una sola vez):

```swift
/// El día del jugador del simulador, en minutos de producción (E2a T11).
enum RewardBudget {
    static let share = 0.12

    static func productionMinutesPerDay(content: GameContent, human: PacingSimulator.HumanModel) -> Double {
        let starts = human.sessionStartOffsets.sorted()
        let cap = content.economy.offlineCapHours * 3600
        var offline = 0.0
        for (index, start) in starts.enumerated() {
            let next = index + 1 < starts.count ? starts[index + 1] : human.daySeconds + starts[0]
            offline += min(max(0, next - (start + human.sessionSeconds)), cap)
        }
        let active = Double(starts.count) * human.sessionSeconds
        return (active + offline * content.economy.offlineEfficiencyBase) / 60
    }

    static func asadoClaimsPerDay(_ human: PacingSimulator.HumanModel, cooldown: Double) -> Double {
        let starts = human.sessionStartOffsets.sorted()
        var lastClaim = -Double.infinity
        var claims = 0
        for day in 0..<7 {
            for start in starts {
                let now = Double(day) * human.daySeconds + start
                if now - lastClaim >= cooldown {
                    claims += 1
                    lastClaim = now
                }
            }
        }
        return Double(claims) / 7
    }

    /// Lo que queda del 12 % de un día después del diario promedio y el asado.
    static func leftAfterDailyAndAsado(content: GameContent, human: PacingSimulator.HumanModel) throws -> Double {
        let minutes = content.dailyRewards.days.compactMap(\.minutes)
        let daily = minutes.reduce(0, +) / Double(max(1, minutes.count))
        let asado = try #require(content.boosts.boosts.first { $0.effectType == .periodicPayout })
        let asadoPerDay = asadoClaimsPerDay(human, cooldown: asado.cooldownSeconds) * asado.magnitude
        return share * productionMinutesPerDay(content: content, human: human) - (daily + asadoPerDay)
    }
}
```

(en `visitorsAndEventsFit`, la llamada lleva `try`). `Script.mechanic.isGift` es `true` para
`gift`, `challenge` y `gossip` (si el enum de E4a no lo tiene, se agrega en un `extension` del
test, no en la app).

El ORO de los logros **no** va acá: lo pinea `fixedOroAchievementsFundAFifthOfTheRun` contra el
costo real de maxear, y se re-pinea en T14 junto con las líneas a 348.

- [ ] **Step 2: Verlos, y calibrar la palanca**

Receta R con `-only-testing:FisuEvolutionTests/EngagementBudgetTests`. Lo esperado según E4a duda
1: `visitorsAndEventsFit` **rojo** (del orden de 2–3 h regaladas por hora contra ~29 min por día
disponibles). Entonces:

1. Bajá `visitors.json` `coinsSecondsScale` al valor que deja el test con un 10 % de margen
   (`spent ≤ 0,9 × left`), redondeado a dos decimales. **No se tocan los montos del Anexo A**: la
   palanca existe para esto (E4a).
2. Si con la escala en 0,01 todavía no entra, el exceso es de los eventos: el paso para con
   `DONE_WITH_CONCERNS` y la tabla (no se recortan eventos sin el dueño, duda 7).
3. `consumablesFollowTheAnchor` rojo en un ítem = un precio de `oro_shop.json` fuera del ancla:
   **no se corrige acá** (es la tabla aprobada de E6a): el reporte lo lista y T13 lo mira.

- [ ] **Step 3: Verde y oráculo**

Receta R → los tests nuevos PASS (o el `DONE_WITH_CONCERNS` del paso 2 con la tabla), y
`RewardBudgetTests` sigue PASS. `Tools/v2/oraculo.sh rapido` → `VERDE`.

- [ ] **Step 4: Commit**

```bash
git add FisuEvolutionTests/RewardBudgetTests.swift FisuEvolution/Resources/Config/visitors.json
git diff --cached --stat
git commit -m "test(premios): visitantes, eventos y consumibles contra el presupuesto, y la escala de los visitantes"
```

---

### Task 11: La herencia en pantalla — "Se conservan los pasivos"

**Objetivo:** lo mostrado es lo aplicado: la hoja de reencarnar dice qué se conserva, con el número
que sale de la misma función que reencarna (`PrestigeCalculator.inheritedPassiveUnlocks`, T2).
Con la herencia apagada, la hoja no cambia.

**Files:**
- Modify: `FisuEvolution/Game/State/GameState+Prestige.swift` (la vista previa suma `inheritedPassives: Int`)
- Modify: `FisuEvolution/UI/Popups/PrestigeView.swift` (una fila más, estilo FisuJobs: `StateBadge` o la fila de "lo que se pierde / se conserva" que ya tenga la hoja)
- Modify: `FisuEvolutionTests/PrestigePreviewTests.swift`
- Strings: `Tools/v2/claves-pendientes/e2b-t11.json`

**Interfaces:**
- Consumes: `PrestigeCalculator.inheritedPassiveUnlocks(state:economy:)` (T2); la vista previa de E2a T8.
- Produces: `PrestigePreview.inheritedPassives: Int` (o el nombre del struct de vista previa que exista; el paso 0 lo busca).

- [ ] **Step 0: Pararse en la base**

`grep -n "struct .*Preview\|lastRunWallGoal" FisuEvolution/Game/State/GameState+Prestige.swift`
(E2a T8) y `grep -n "accessibilityIdentifier" FisuEvolution/UI/Popups/PrestigeView.swift`.

- [ ] **Step 1: El test, en rojo**

En `PrestigePreviewTests`:

```swift
    @Test("la hoja dice cuántos pasivos se conservan, y es lo que la reencarnación conserva")
    func inheritedPassivesAreShown() async throws {
        let gameState = await makeGameState()
        let economy = try #require(gameState.content?.economy).tuned(EconomyKnobs(inheritsPassiveUnlocks: true))
        gameState.economy = StandardEconomy(config: economy)
        gameState.player?.run.passiveUnlocked = ["homeless": true, "cartonero": true]
        gameState.giveEarningsForPrestigeTesting(oro: 5)
        let preview = try #require(gameState.prestigePreview)
        #expect(preview.inheritedPassives == 2)
        gameState.reincarnate()
        #expect(gameState.player?.run.passiveUnlocked.filter(\.value).count == 2)
    }

    @Test("con la herencia apagada, la hoja no la menciona")
    func noInheritanceNoRow() async throws {
        let gameState = await makeGameState()
        gameState.player?.run.passiveUnlocked = ["homeless": true]
        gameState.giveEarningsForPrestigeTesting(oro: 5)
        #expect(try #require(gameState.prestigePreview).inheritedPassives == 0)
    }
```

(Los nombres `prestigePreview`, `reincarnate()` y el id del segundo tipo se toman del paso 0 y de
`tiers.json`; `gameState.economy` es settable desde un test, `GameState.swift:404`, sin tocar el
archivo.)

- [ ] **Step 2: Verlo fallar**

Receta R con `-only-testing:FisuEvolutionTests/PrestigePreviewTests` → no compila (`inheritedPassives`).

- [ ] **Step 3: La implementación**

La vista previa suma `inheritedPassives = PrestigeCalculator.inheritedPassiveUnlocks(state:
player, economy: economy).count`. `PrestigeView`, si es > 0, una fila "Se conservan los pasivos de
%@ personajes" / "You keep the passive income of %@ characters" (`%@` con un `String`, trampa 5;
plural con la variante del catálogo si la casa la usa), con `accessibilityIdentifier("prestige.inherited")`.
El snapshot `Tools/v2/claves-pendientes/e2b-t11.json` con la clave `prestige.inherited.passives`
(es + en) por `Tools/v2/catalogo.py` (el controlador la aplica al integrar).

- [ ] **Step 4: Verde y oráculo**

Receta R → PASS. `Tools/v2/oraculo.sh completo` → `VERDE` (la hoja es UI). A mano en el simulador,
con `--uitest-reset` y la perilla prendida desde el panel de debug si E2a T14 la expone (si no, por
el test): la fila aparece con el número.

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Game/State/GameState+Prestige.swift FisuEvolution/UI/Popups/PrestigeView.swift \
  FisuEvolutionTests/PrestigePreviewTests.swift Tools/v2/claves-pendientes/e2b-t11.json
git diff --cached --stat
git commit -m "feat(prestigio): la hoja de reencarnar dice qué pasivos se conservan"
```

---

### Task 12: Medir cada mecánica, en el orden de PLAN-v2

**Objetivo:** la tabla que la búsqueda necesita: qué mueve cada mecánica **sola**, en el orden de
PLAN-v2 E2b ("línea de base → knobs en v1 → política nueva → reintegro → amortiguador → herencia →
ORO → dificultad tardía → perfiles"), más la fidelidad nueva del simulador (descuento de
prestigio, fuentes gratis) y **el techo del prestigio** de cada configuración (el riesgo del
contrato 6, duda 1). Sin cambiar datos.

**Gate:** 🔒 el playtest de precios del dueño en el panel de debug (E2a T14) elige el par (g, r) y
si va el amortiguador. Sin respuesta, la tabla se corre con (1,12 · 1) + K = 24 **y con las otras
dos variantes del panel** ((1,08 · 0,5), (1,12 · 2)), y el reporte marca que falta el gate.

**Files:**
- Create: `Docs/balance-run-v2-e2b-mecanicas.csv` (la tabla, una fila por corrida)

- [ ] **Step 1: La base y el sanity check**

Receta P sin flags nuevos y `--max-days 90` → tiene que dar la línea de base vigente (30,73 h · 13,
o la de E2a T15). Si no, **para**: algo se coló (trampa 40).

- [ ] **Step 2: Las corridas, una por renglón, acumulando**

Con `build/e2b/` como carpeta de CSVs (gitignoreada) y siempre `--upgrades` y `--sources`:

| # | Corrida (flags que se SUMAN a la anterior) | Para qué |
|---|---|---|
| 0 | (nada) | la base |
| 1 | `--merge-refund 0 --price-relief 0 --staffed 0` | las perillas en v1 reproducen la base (tiene que ser idéntica a la 0) |
| 2 | `--prestige-threshold 4` | la política nueva (×5) |
| 3 | `--growth <g> --merge-refund <r>` | el reintegro, con el par del gate |
| 4 | `--price-relief <K>` | el amortiguador |
| 5 | `--inherit` | la herencia |
| 6 | `--capacity 15 --staffed 0.05` | la crítica de Marco: pisos de 15 y pisos en marcha |
| 7 | `--wall` | el piso móvil |
| 8 | `--prestige-discount` (el descuento que la app cobra) | la fidelidad |
| 9 | `--profile free` | las fuentes gratis |
| 10 | `--bands "8:1.45,13:1.6,25:1.7" --growth-step "0.01@luxury"` | la dificultad tardía |
| 11 | `--profile ads` y `--profile max` (dos corridas) | las guardas |
| 12 | la 10 con `--no-reincarnation --max-days 400` | el contrato 8 |
| 13 | la 10 con `--seed-fraction 0.1` y `0.9` | que el contrato no dependa de la semilla |

Por corrida, al CSV: Dios activo, reencarnaciones, 1ª reencarnación activa, las 7 al tope (h y
reencarnación), la serie de la pared y de `maxTierPerRun`, el pago y **el techo** por run, ORO por
reencarnación y en Dios, pasivos comprados por run, pisos en marcha (máx), los minutos de llegada
de cada piso, y lo que dieron las fuentes.

- [ ] **Step 3: La lectura**

En el reporte (no en `Docs/balance-log.md`, que es del cierre):

1. Cuánto movió cada renglón Dios y las reencarnaciones (la tabla delta).
2. **El techo del prestigio** en las corridas 9 y 10: si en alguna run queda **por debajo de 0,65**,
   el contrato 6 es inalcanzable con knobs de precio en esa forma (balance-log, "el techo"). El
   reporte lo dice con la run y el número: es lo primero que el controlador le lleva al dueño
   (duda 1).
3. La ley de diseño: con los `oroGainedPerReincarnation` medidos, ¿R ≈ ln(ORO_dios/ORO₁)/ln 5?
4. Qué contrato cumple ya la corrida 10 y cuál no, con la distancia.

- [ ] **Step 4: Commit**

```bash
git add Docs/balance-run-v2-e2b-mecanicas.csv
git diff --cached --stat
git commit -m "chore(balance): las mecánicas de la 2.0 medidas una por una con el simulador nuevo"
```

---

### Task 13: La búsqueda — la configuración que cumple el contrato (run AVO)

**Objetivo:** encontrar los valores de las perillas que cumplen **los nueve puntos del contrato y
la guarda del ORO** con el contenido real y todas las fuentes adentro. Es búsqueda, no
implementación: corre el bucle del harness AVO (hipótesis → variantes → corrida → evidencia),
con el CSV como oráculo, y no commitea datos.

**Files:**
- Create: `Docs/balance-run-v2-e2b-candidata.csv` (las corridas de la búsqueda y la elegida)

**El espacio** (en el orden en que conviene moverlo, del más grueso al más fino):

1. **El ORO**: `--oro-divisor` y `--oro-exponent` para que ORO₁ ≈ 1–2 y ORO en Dios ≈ 5–12k (puntos
   2, 3 y la guarda). Las líneas se miden **a 348** desde el principio: el CLI lee `--upgrades` de
   una copia en `build/e2b/upgrades-348.json` (las siete con `baseCost` 2).
2. **El largo**: las bandas (`--bands`) y el escalón de la curva (`--growth-step`) para Dios en
   1.900–2.100 min y las ventanas de los pisos altos (puntos 1 y 7).
3. **El arranque**: la 1ª reencarnación y urban/corporate/luxury (puntos 4 y 7). Si el principio
   queda "súper fácil" (PLAN-v2: "si con la herencia el principio no queda súper fácil…"), el knob
   siguiente es `prestige_unlocks.json` de la 1ª–2ª reencarnación, **no heredar unidades**.
4. **Las guardas de perfil** (punto 9): si `.ads` o `.max` bajan del 55 %/50 %, las palancas son
   las de las fuentes: `packages.json` `spawnIntervalSeconds` (E5a duda 10), las tablas de ruleta y
   colchón (E5a dudas 4–5) y los cooldowns de la columna (E7b-b). **No** se toca el contrato.
5. **La forma** (puntos 5 y 6): si la pared no corre o el pago no llega, mirar primero el techo
   (T12). Con el techo bajo 0,65 no hay knob de precio que sirva: `NEEDS_CONTEXT` al dueño (duda 1).

**Lo que no se toca** (HANDOFF §5, no se re-litigan): el primer Fisura a 25, la regla de precios
(a) y (b) (600 clicks a tu frontera, 25 en el callejón, `priceGrowthPerTier` 1,5), la compuerta
en 6, el callejón a 1,03, las mejoras por personaje secuenciales (×20, `maxLevel` 19), el precio de
contratar con el mismo factor de piso que el toque, los montos de los packs (160/550/1.400) y la
tabla del dueño de premios en minutos (E2a).

- [ ] **Step 1: Abrir el run AVO**

Carta: "Contrato 2.0 verde en `.free` ×5 con el contenido real". Oráculo: la Receta P con
`--profile free --prestige-threshold 4 --max-days 400` + las dos corridas de guarda; el semáforo
del contrato de T8. Línea de base: la corrida 10 de T12.

- [ ] **Step 2: El bucle**

Un knob por vez, la línea de base del run antes de cada tanda (trampa 40), cada corrida al CSV. El
supervisor AVO entra si tres tandas seguidas no mejoran la cantidad de puntos en verde.

- [ ] **Step 3: La candidata**

La corrida que deja los nueve puntos + la guarda en ✅, **y** las corridas con `--seed-fraction 0.1`
y `0.9` también ✅ (si una semilla rompe un punto, la candidata está en el filo: se busca margen).
En el reporte: la tabla de perillas con su valor final (la que T14 declara), la serie de la pared,
el techo, y qué fuente movió la guarda de perfiles.

Si no hay candidata: `NEEDS_CONTEXT` con las tres corridas más cercanas, qué punto falla en cada una
y por qué (con el número). No se afloja ningún punto del contrato sin el dueño.

- [ ] **Step 4: Commit**

```bash
git add Docs/balance-run-v2-e2b-candidata.csv
git diff --cached --stat
git commit -m "chore(balance): la búsqueda del contrato 2.0 y la configuración candidata"
```

---

### Task 14: Declarar la calibración, prender el contrato y retirar `theOwnersTargetsAreMet`

**Objetivo:** en un solo commit verde, el juego pasa a la 2.0: los JSON con la candidata de T13,
los pines que se mueven re-pineados con su porqué, el contrato prendido, las bandas viejas de
`PacingTests` re-pineadas a la conducta nueva y el rojo declarado reemplazado. El CLI y el
oráculo pasan a medir el contrato.

**Files:**
- Modify: `FisuEvolution/Resources/Data/economy.json` (las perillas de la tabla de T13; `capacity` 15 en los diez pisos)
- Modify: `FisuEvolution/Resources/Config/upgrades.json` (`baseCost` 2 en las siete)
- Modify: `FisuEvolution/Resources/Config/achievements.json` (los doce de ORO ×2, duda 5)
- Modify (sólo si T13 los movió): `prestige_unlocks.json`, `packages.json`, `treasures.json`, `wheel.json`, `rewarded_ads.json`
- Modify: `FisuEvolutionTests/PacingContractTests.swift` (fuera los `.disabled`)
- Modify: `FisuEvolutionTests/PacingTests.swift` (sin `theOwnersTargetsAreMet`, sin `withoutPrestigeGodIsUnreachable` —es el punto 8—, sin `strugglingPhaseLength` ni `floorGradient` —los reemplaza el punto 7—; las que quedan leen `PacingReports.free` y se re-pinean)
- Modify: `FisuEvolutionTests/GameContentValidationTests.swift` (capacidad, escalada, líneas, logros)
- Modify: `FisuEvolutionTests/AchievementEngineTests.swift` (el comentario de `:525`, si cita 33 o 193)
- Modify: `Tools/pacing-sim/Sources/main.swift` (los defaults: `--profile free`, umbral 4, descuento de prestigio prendido)

- [ ] **Step 0: Pararse en la base**

`grep -rn "193\|== 33\|capacity == 10\|frontierEscalationPerTier ==\|13 y 15\|== 13\b" FisuEvolutionTests Packages/EconomyKit/Tests`
(todo pin que la calibración mueve; los de E6b de "13/15 lugares con base 10" pasan a 18/20) y
`grep -rn "theOwnersTargetsAreMet" -r . --include=*.swift --include=*.md --include=*.sh --include=*.txt`
(quién lo nombra: los docstrings que lo citan cambian en este commit; `rojos-declarados.txt` es del
controlador).

- [ ] **Step 1: Los datos**

Los valores de la tabla de T13, tal cual, en sus JSON. `economy.json` declara **todas** las
perillas de E2a y E2b (aunque alguna quede en su valor v1, se declara: el dato es el contrato).

- [ ] **Step 2: Los pines**

1. `GameContentValidationTests`:
   - `:166-167` → las bandas literales (`escalationBands == [(8, 1.45), (13, 1.6), (25, 1.7)]` o
     las de T13) con el porqué en el comentario (PLAN-v2 E2b: dificultad tardía) y `costGrowthStep…`.
   - `hirePricesFollowTheOwnersRule` → la escalada esperada se calcula **con el literal de las
     bandas** (producto de los factores por tier), no con `hire.escalation` (trampa 24).
   - `towerFloorsMatchCalibratedLayout` → `capacity == 15`.
   - `upgradeCatalogMatchesTunedValues` → `base` 2 en las siete y `total == 348`; el docstring
     cambia "log₂(193) = 7,6 → 8 reencarnaciones" por la ley ×5 ("con 348 la 5ª reencarnación es la
     primera que maxea").
   - `fixedOroAchievementsFundAFifthOfTheRun` → `total == 66` (la banda 15–20 % no cambia: 66/348 =
     19,0 %).
   - los que el paso 0 encontró.
2. `PacingTests`: las bandas que quedan (`firstReincarnation` de pared, `godTiming` de pared,
   `noHitoJumpIsLongerThanFourActiveHours`, `theRunHitsAWallAndPrestigeMovesIt`) leen
   `try PacingReports.free.get()` (el `init` que simulaba por test se va) y se re-pinean a ±30 % de
   lo medido en la candidata, cada una con su línea "Sexta ronda (2.0): medido X". El docstring del
   encabezado suma la ronda 2.0 arriba de todo ("ACÁ SE CORTA LA COMPARACIÓN…": cambia la política
   del bot) y **el párrafo de `theOwnersTargetsAreMet` se reescribe**: lo reemplaza
   `PacingContractTests`.
3. `PacingContractTests`: los diez `.disabled("E2b T14 lo prende con la calibración")` se borran.

- [ ] **Step 3: El CLI pasa a medir el contrato**

`main.swift`: defaults `profile = .free`, `prestigeThreshold = 4`, `prestigeDiscount = true`,
`--max-days 400`. El oráculo no cambia (sigue leyendo `dios:` y `reencarnaciones:`), pero su
número pasa a ser el del contrato.

- [ ] **Step 4: Verde**

1. Receta R con `-only-testing:FisuEvolutionTests/PacingContractTests -only-testing:FisuEvolutionTests/PacingTests -only-testing:FisuEvolutionTests/GameContentValidationTests`
   → PASS, **nombrando los diez del contrato** (ninguno skipped).
2. La Receta P con los defaults nuevos → los mismos números que `PacingContractTests` (Dios,
   reencarnaciones): el espejo del CLI y el `PacingFixture` dicen lo mismo. Si no, una fuente se
   mapea distinto en los dos: se arregla antes de commitear.
3. `swift test --package-path Packages/EconomyKit` → PASS.
4. `Tools/v2/oraculo.sh completo` → `VERDE` (la capacidad 15 cambia la escena: los UI tests tienen
   que pasar en la matriz). La línea `unit theOwnersTargetsAreMet` de `rojos-declarados.txt` queda
   sin uso: **el controlador la saca al integrar** (el reporte lo pide).

- [ ] **Step 5: Commit**

```bash
git add FisuEvolution/Resources/Data/economy.json FisuEvolution/Resources/Config/upgrades.json \
  FisuEvolution/Resources/Config/achievements.json FisuEvolutionTests/PacingContractTests.swift \
  FisuEvolutionTests/PacingTests.swift FisuEvolutionTests/GameContentValidationTests.swift \
  FisuEvolutionTests/AchievementEngineTests.swift Tools/pacing-sim/Sources/main.swift
# + los JSON de fuentes que T13 haya movido, uno por uno
git diff --cached --stat
git commit -m "feat(balance): la calibración de la 2.0 — el contrato de pacing en verde y las líneas a 348"
```

---

### Task 15: Cierre de la épica

**Objetivo:** la verificación de punta a punta y la documentación. La hace el controlador.

- [ ] **Step 1: Oráculo completo, dos veces**

`Tools/v2/oraculo.sh completo --limpio` y `Tools/v2/oraculo.sh completo` → `VERDE` las dos, con
`PacingContractTests` (diez del contrato + dos estructurales) en la cuenta de unit, las suites EK
nuevas (`EscalationBandsTests`, `PassiveInheritanceTests`, `SimulatorFidelityTests`,
`StaffingPolicyTests`, `PacingProfileTests`, `PacingAdsProfileTests`, `PacingMaxProfileTests`) en la
de `economykit`, y `pacing-sim: Dios en <contrato> · <5 o 6> reencarnaciones`.
`rojos-declarados.txt` sin la línea de `theOwnersTargetsAreMet`.

- [ ] **Step 2: A mano en el simulador**

Partida nueva sin argumentos de test: un piso del callejón se llena hasta 15 y la botonera lo marca
en marcha; contratar no salta al subir de tier (amortiguador); la primera reencarnación llega
cerca de la hora activa; la segunda run arranca con los pasivos (la hoja de T11 lo dijo) y el botón
pide la pared anterior (piso móvil); la tienda de mejoras cobra el doble.

- [ ] **Step 3: Documentación (controlador)**

1. `Docs/balance-log.md`: "**Sexta ronda (2.0)**" — el contrato, la tabla de T12, la búsqueda de
   T13, la candidata, el techo medido, lo que el simulador ahora modela y lo que no.
2. `Docs/SESION-<fecha>-v2-e2b.md`: la tabla por tarea con su commit y el porqué de cada default de
   "Para el dueño".
3. `Docs/HANDOFF.md`:
   - **§4**: entrada "E2b — calibración y contrato".
   - **§5**: el 5.2 (c) re-enunciado con las bandas; el 5.5 (el contrato) reemplazado del todo por
     el de la 2.0; el 5.7 con las líneas a 348; el 5.10 con los 66 de los logros; las dudas que el
     dueño no cambió.
   - **§6**: la línea de base nueva de `pacing-sim` y la cuenta de tests.
   - **§7**: las trampas nuevas — "el bot no cobraba el descuento de prestigio"; "las fuentes se
     arman en dos lugares (`PacingFixture` y el CLI): si dan distinto, una se mapea mal"; "un premio
     modificador entra al bot como suma de producción"; "el techo del prestigio se mide, no se
     calibra"; las que aparezcan.
   - **§9**: este plan y la sesión.
4. `Tools/v2/rojos-declarados.txt` sin la línea; journal AVO al día y `LOCK` liberado;
   `handoffs/HANDOFF-<fecha>-v2-e2b.md`.

- [ ] **Step 4: Commit de docs**

```bash
git add Docs/balance-log.md Docs/SESION-*-v2-e2b.md Docs/HANDOFF.md Tools/v2/rojos-declarados.txt
git diff --cached --stat
git commit -m "docs(v2-e2b): cierre de la épica E2b — calibración final y contrato de pacing"
```

---

## Lo que E2b le deja a otras épicas

- **E9 (tutorial, Tour, Ajustes)**: la lección de reencarnar dice que **se conservan los
  pasivos** (la fila de T11 es su ancla) y que hace falta **la pared anterior**; los pisos son de
  **15**; el Tour de novedades para veteranos nombra las tres cosas y las líneas a 348. El reset de
  E9 no necesita nada nuevo: la herencia vive en `run`, que el reset borra.
- **E10 (release)**: `pacing-sim` del archive imprime el contrato; las capturas del App Store
  muestran pisos de 15. `HANDOFF-v2.md` y `balance-log.md` ya tienen la ronda 2.0 (T15).
- **Cualquier épica que sume una fuente de economía después de E2b**: la suma a `PacingSources`
  (EK), a `PacingFixture.sources` y al espejo del CLI **en el mismo commit**, y corre
  `PacingContractTests`; si el contrato se rompe, lo arregla esa épica con las palancas de su fuente
  (T13, "las guardas de perfil"), no aflojando el contrato.
- **E4a/E4b**: `coinsSecondsScale` quedó calibrado por T10; un guion nuevo con regalo entra al
  presupuesto solo (`EngagementBudgetTests` suma los guiones del JSON).
- **E6a**: si `consumablesFollowTheAnchor` marcó un precio fuera del ancla (T10 paso 2.3), la
  corrección es de E6a (la tabla aprobada), con el dueño.

## Para el dueño / dudas

Cosas que PLAN-v2 deja abiertas o que el código contradice. **Ninguna frena**: la ejecución sigue
con el default anotado hasta que el dueño diga otra cosa.

1. **El contrato 6 (reencarnar paga ≥ 65 %) choca con una decisión vieja y con un techo medido.**
   HANDOFF §5.2 dice que el dueño **aceptó** un retorno de 7–40 % y que hay un techo matemático
   (`pago ≤ 1 − acciones/primera_vez`) que ningún knob de precio cruza. Lo que la 2.0 cambia a
   favor: la política ×5 (cada run trae mucho más ORO, así que la espera se achica más), la
   herencia (saca ~15 compras por run) y "Fusionar todo" (sólo en `.ads`). **Default:** el contrato
   va con 0,65; T3 mide el techo por run y T12 lo informa **antes** de calibrar. Si con la forma
   elegida queda por debajo, T13 para con `NEEDS_CONTEXT` y el dueño elige entre bajar el punto 6 a
   lo medido o sumar contenido que reduzca acciones (descartado en la v1).
2. **4–6 reencarnaciones (punto 2) y "las líneas no antes de la 5ª" (punto 3) dejan 5 o 6.** Con 4,
   la 5ª no existe, y el bot compra líneas sólo al reencarnar (o con ORO de fuentes, que `.free`
   no tiene). **Default:** el assert es 5...6.
3. **Dios: 31–35 h (punto 1) contra 1.900–2.100 min (punto 7)** = 31,7–35 h. **Default:** la
   intersección.
4. **"Las 7 líneas en la 3ª–4ª reencarnación" (bullet del ORO en PLAN-v2 E2b) contradice el punto
   3 del contrato ("no antes de la 5ª")**, que además es lo que pidió Marco (C1). **Default:** el
   contrato. La ley ×5 con las líneas a 348 da justo la 5ª.
5. **Las líneas a 348 rompen el 15–20 % de los logros (HANDOFF §5.10, "suman 33").** Con 348, 33
   es el 9,5 %. Las dos mitades de la decisión no pueden quedar las dos: el docstring del pin dice
   que "el total es la regla de diseño" y el 15–20 % es el porqué. **Default:** los doce montos ×2
   (66 = 19,0 %), que conserva el orden y la proporción.
6. **El perfil `.free` incluye lo que no pide video** (Paquete de la Aduana, diario base, boosts
   gratis con cooldown, la carrera), aunque PLAN-v2 lista "paquetes" y "diario" en `.ads`. El
   paquete cae **gratis** cada 2 min (§2) y el diario se cobra sin video; dejarlos fuera mediría un
   jugador que no existe y el juego real duraría menos que el contrato. Los boosts gratis (fernet,
   turbo, café, asado, milanesa) **no los modelaba ni el simulador de la v1**. **Default:** así;
   `.ads` suma sólo lo que pide video (E5a duda 10 dejaba la decisión a E2b).
7. **Visitantes contra el presupuesto** (E4a duda 1): con los montos del Anexo A regalan del orden
   de horas de producción por hora de juego, contra ~29 min/día que deja el 12 % de E2a. **Default:**
   T10 baja `coinsSecondsScale` (la palanca que E4a dejó) hasta entrar con 10 % de margen; los
   montos del Anexo no se tocan. Si el dueño prefiere visitantes generosos, la alternativa es
   modelarlos en `.free` y pagar el largo con precios más duros (más trabajo en el simulador).
8. **El simulador no cobraba el descuento de prestigio** (`prestige_unlocks.json`, hasta 35 % en el
   nivel 8): la app lo aplica a cada cotización y el bot nunca lo vio, así que todo número de
   pacing de la v1 midió un juego algo más caro que el real. **Default:** T3 lo suma apagado (la
   base no se mueve), T12 mide cuánto pesa y desde T14 va prendido.
9. **Los premios modificadores entran al bot como suma de producción**: ×k por T s = `(k − 1)·T`
   segundos de `RewardScale`. El reloj del bot salta por evento y no puede integrar un
   multiplicador que vence en el medio de una espera. Es la misma equivalencia con la que la 2.0
   paga los premios; subestima un poco al que tapea durante el boost. **Default:** así, declarado.
10. **`--seed-fraction` no está definido en PLAN-v2.** **Default:** el valor inicial (0–1) de los
    acumuladores de los sorteos determinísticos (paquete, ruleta, colchón), con 0,5; T12/T13 corren
    0,1 y 0,9 para ver que el contrato no dependa de la semilla.
11. **La herencia "en `meta`" (PLAN-v2) contra "ningún campo nuevo sin save v7" (plan de E1).**
    **Default:** sin campo: la run nueva hereda `run.passiveUnlocked` de la anterior, que ya traía
    los de las previas. Lo único que se pierde es lo que un veterano desbloqueó en runs de la v1 y
    no volvió a comprar en la run en curso al actualizar.
12. **"g +0,01 por piso desde luxury" no puede ser un override por piso**: `floorHireOverridesMatchTunedValues`
    dice que los únicos legítimos son los dos del callejón. **Default:** una perilla de config
    (`costGrowthStepPerFloor` + `FromFloorId`); luxury suma el primer escalón (+0,01), island +0,02,
    … Dios +0,07; los pisos con curva propia no se tocan.
13. **Las bandas cambian el renglón (c) de la regla de precios** (HANDOFF §5.2, "aprobada tal cual"):
    "60 % por tier desde el 7" pasa a "45 % del 8 al 12, 60 % del 13 al 24, 70 % del 25 al 37". Es la
    "dificultad tardía" del plan aprobado y la forma (c) se conserva (la escalada sigue arrancando
    después del callejón). **Default:** así, y T15 re-enuncia el renglón.
14. **El bot y los pisos en marcha**: el bot de la v1 fusiona todo par apenas existe, y un piso en
    marcha necesita unidades quietas. **Default:** la regla de T4 (llenar el piso más bajo cuyo
    llenado se paga con el bono; no desarmar un piso en marcha por debajo del piso de compra salvo
    para subir la frontera). Es una política del bot, no del juego: el jugador decide igual.
15. **E2b antes o después de E9** (`tasks.md`, punto 4): ver "E2b antes o después de E9" en
    "Orden". **Default:** fase A tras E2a, fase B en paralelo con E9 y antes de su cierre.
16. **Los paquetes y el colchón que esperan sobreviven a la reencarnación** (E5a duda 3); el bot
    los abre apenas caen, así que nunca acumula. **Default:** sin efecto en el simulador, declarado.
17. **La capacidad 15 mueve pines de otras épicas** (E6b: "13/15 con base 10" pasa a 18/20).
    **Default:** T14 los re-pinea en el mismo commit (paso 0 los busca).
