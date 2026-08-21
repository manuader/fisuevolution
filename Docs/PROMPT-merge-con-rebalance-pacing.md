# PROMPT — Mergear tu trabajo con la rama `fix/rebalance-pacing`

> Para el agente que tiene otra rama en vuelo y tiene que integrarla con ésta.
> Escrito el 2026-08-21 por el agente que hizo el rebalance. **Todo lo que dice
> acá está medido y verificado**; lo que no pude verificar lo digo.

---

## 1. Qué es esta rama y dónde está

- **Rama**: `fix/rebalance-pacing`, HEAD `9ac8e0d`.
- **Worktree**: `/Users/manuader/Desktop/projects/fisu-wt-pacing` (NO trabajes ahí adentro; cloná/mergeá desde el tuyo).
- **32 commits propios** sobre `8a2c3fb`, más tres merges `--no-ff` que ya trajo adentro:
  - `fix/atajo-tier-base` (el atajo del HUD),
  - `fix/premios-y-eventos` (logros y eventos),
  - **`main` al día** (`dc4c7ae`, el tutorial high-end): **ya está integrado y verde**, no lo mergees de nuevo.
- **Verificación del árbol mergeado**: EconomyKit **234/234** · unit **411/411** · UI **46/46 en una sola corrida sin un solo `-skip-testing:`** · cero warnings.
- Documentación: `Docs/SESION-2026-08-21-rebalance-pacing.md` (el porqué), `Docs/balance-log.md` (la calibración corrida por corrida), `Docs/HANDOFF.md` §4/§5/§7/§9, y `Docs/PROMPT-rebalance-pacing.md` (el pedido original con la evidencia).

---

## 2. LO QUE EL DUEÑO PIDIÓ — esto NO se pierde en el merge

Son sus palabras. Si tu merge rompe cualquiera de estas, el merge está mal.

### 2.1 "me lo gané en 3 horas y es muy poco" → **20-30 h ACTIVAS**

**Ganarlo al máximo** = maxear las siete líneas permanentes (lo que desbloquea las skins doradas). Números finales, medidos con el simulador:

| métrica | antes | **ahora (NO BAJAR)** |
|---|---|---|
| maxear las 7 (activo) | 15,49 h (y 3 h reales del dueño) | **24,00 h** |
| reencarnaciones al maxear | 34 | **8** (techo del dueño: 8) |
| Dios (activo) | 32,0 h — ANTES que maxear | **26,59 h — DESPUÉS** |

Cadencia de las 8 reencarnaciones: 3,7 · 8,0 · 12,7 · 16,4 · 19,3 · 21,2 · 22,9 · 24,0 h activas.

**Lo pinea `FisuEvolutionTests/PacingTests.swift`** — y ojo: los asserts del objetivo del dueño (`theOwnersTargetsAreMet`) **no son bandas re-pineables**, son el contrato. Si tu merge los pone en rojo, el problema es tu merge.

### 2.2 "los multiplicadores al reencarnar están mal" + "el oro que da es tanto que es fácil ganar"

- `oro.divisor` **3e12** (era 3e6) y `oro.exponent` **0,25** (era 0,45).
- Los 12 logros que dan ORO fijo se re-escalaron: sumaban **620 ORO** cuando maxear cuesta **193** (ganaban el juego 3,2 veces). Ahora suman **33 = 17,1 %** del camino. Regla usada: monto viejo ÷ 20, techo, piso 1. Lo pinea `fixedOroAchievementsFundAFifthOfTheRun`, con la proporción **derivada de `upgrades.json`**, no un literal.
- Las siete líneas se aplanaron a `maxLevel: 10` todas, con growths 1,1/1,15/1,15/1,1/1,2/1,2/1,25 y base 1: total **193 ORO**. Antes `crit` sola era el 99,99 % del costo (1,776e10 de 1,778e10).

⚠️ **Los 193 ORO y el techo de 8 reencarnaciones están atados por log₂** (reencarnaciones ≈ log₂(193) = 7,6). Si tocás `upgrades.json`, movés las dos cosas.

### 2.3 "los personajes más altos dan mucha plata al clickearlos"

- `tapFloorMultiplierExponent: 0` — **el click dejó de cobrar el multiplicador de piso**.
- **Y el precio también** (decisión del dueño, salida "(a)"): `EconomyConfig.hireCost` multiplica por `tapFloorMultiplier(for:)`, **la MISMA función** que usa `GameActions.applyTap`. Están atadas por construcción, no por coincidencia.
- **Por qué importa**: la regla del dueño es *"el tier base de un piso superior cuesta 600 veces lo que rinde un click suyo ahí"*. Si separás esas dos puntas, en god_realm el tier base pasa a costar **372.000 clicks** en vez de 600. Lo pinea `hirePricesFollowTheOwnersRule`, que mide EN CLICKS y deja el 372.000 como centinela.

### 2.4 "el shortcut sólo debe dejar comprar al personaje inicial de cada piso"

- `GameState.computeBestHire()` filtra a `type.tier == floorTable[quote.floorOrdinal].firstTier`.
- **FisuJobs NO se tocó**: sigue vendiendo todos los personajes desbloqueados. Es decisión cerrada del dueño; si tu merge la rompe, la rompiste vos.
- Lo pinean 5 tests de `BestHireTests`, y cada uno de los de exclusión asserta primero que el excluido **estaba pagado y contratable** (si no, probarían nada).

### 2.5 "los achievements dan bastante plata" → segundos de TU producción

- Los 27 logros de monedas pagan `IncomeTicker.passivePerSecond(...) × seconds` (el molde del Aguinaldo), con el campo del JSON renombrado `factor` → **`seconds`** (30-300 s).
- Los modificadores temporales **no cotizan**: cerraba un farm (guardarse los logros para un Plan Platita ×5).
- Piso anti-cero = `passiveYield(tier)` PELADO. La razón piso/molde-viejo es `seconds/(120×factor)`, **constante en el tier**, peor caso 1/8: el piso nunca paga más que el molde viejo y nunca paga cero.

### 2.6 "los banners aparecen muy seguido"

- `baseIntervalSeconds` 300 → **900**, jitter 180 → **300**: de uno cada 2-8 min a uno cada **15-20 min**.
- Dosis bajadas: `plan_platita` ×5→**×3**, `inversion_alienigena` ×10→**×5**, `aguinaldo` 900→**300 s** de producción, `blanqueo` 2→**3** (su `magnitude` es un **OFFSET DE TIER**: subirla lo hace MENOS generoso — el plan lo decía al revés y casi lo rompemos).
- **La cara mala pasó a ser mayoría**: pesos buenos/malos 51/38 (57,3 %) → **35/38 (52,1 % malos)**. Ninguno de los 8 se apagó.
- ⚠️ **Los banners y su copy tienen que decir el mismo número que aplica el juego.** Ya nos pasó: quedaron diciendo ×5 y ×10 cuando el juego aplicaba ×3 y ×5, y fue el único bug user-visible que la rama introdujo (cazado y corregido). Si movés una magnitud, grepeá `Localizable.xcstrings` **y el código**.

---

## 3. Los archivos que más probablemente te conflictúen

| archivo | qué le hizo esta rama | cómo resolver |
|---|---|---|
| `FisuEvolution/Resources/Data/economy.json` | `defaultCostGrowth` 1,2→**1,06**; `oro.divisor` **3e12**; `oro.exponent` **0,25**; `tapFloorMultiplierExponent: 0` | conservar TODOS; están pineados por `economyConfigMatchesTunedValues` |
| `FisuEvolution/Resources/Config/upgrades.json` | las 7 líneas a `maxLevel: 10` + growths nuevos (total 193 ORO) | conservar; lo pinea `upgradeCatalogMatchesTunedValues` |
| `FisuEvolution/Resources/Config/achievements.json` | `factor`→`seconds` en 27; los 12 de ORO ÷20 | conservar |
| `FisuEvolution/Resources/Config/events.json` | 900/300 + dosis | conservar |
| `Packages/EconomyKit/.../EconomyConfig.swift` | `tapFloorMultiplier(for:)` + `hireCost` la usa | conservar; es la atadura de la regla de 600 clicks |
| `Packages/EconomyKit/.../GameActions.swift` | `applyTap` usa la misma función | conservar |
| `Packages/EconomyKit/.../PacingSimulator.swift` | el bot compra mejoras permanentes, aplica `derivedEffects`, tapea 6/s, mide `maxedUpgradesActiveSeconds` | conservar entero |
| `Packages/EconomyKit/.../PermanentUpgrades.swift` | **archivo nuevo** (espejo puro de `UpgradeManager`) | conservar |
| `FisuEvolution/Game/State/GameState+Hiring.swift` | el filtro de tier base del atajo | conservar |
| `FisuEvolution/Game/State/GameState+Achievements.swift` | el premio en segundos de producción | conservar |
| `FisuEvolution/Managers/SaveMigrator.swift` | **migración de saves** (reescalado proporcional de niveles al bajar los topes) | conservar; ver §4 |
| `FisuEvolutionTests/PacingTests.swift` | re-pineado entero + los asserts del objetivo | conservar |
| `Docs/HANDOFF.md` | entradas §4/§5/§7/§9 | **conservar AMBOS lados** (yo ya resolví así el merge con main) |

**Regla de oro del conflicto**: si tu lado y el mío tocan el mismo test por razones distintas, **combiná las dos intenciones**, no elijas una. Ya pasó con `BestHireTests` (una rama cambió *qué* se ofrece, la otra *cuánto* cuesta) y la resolución correcta fue quedarse con la semántica nueva **y** los montos derivados de la config.

---

## 4. La parte peligrosa: la migración de saves

`SaveMigrator` reescala proporcionalmente los niveles guardados cuando los topes bajaron (income 20→10, tap 20→10, crit 25→10). **El dueño tiene un save donde ganó el juego** y no se le puede romper.

- Un solo call site (dentro de `migrateV3toV4`), despacho por versión: v1/v2/v3 pasan exactamente una vez, v4 nunca.
- **NO es idempotente** (`crit 25 → 10 → 4 → 2 → 1 → 0`): es segura por el cableado, no por la función. Está pineado.
- El fixture de test **no puede** usar un nivel que sea punto fijo del reescalado: con `tap: 1` (1→1) se podía borrar la llamada entera y la suite quedaba verde. Hoy usa `tap: 3` (→2).
- Si tu merge toca `SaveMigrator` o los topes de `upgrades.json`, re-verificá los dos tests end-to-end.

---

## 5. Cómo verificar el merge (no lo des por bueno sin esto)

Worktree propio, simulador PROPIO por UDID (guardá el UDID **dentro de tu worktree**, no en el scratchpad de sesión — es compartido entre agentes y ya hubo un pisotón), `-derivedDataPath` absoluto, `pwd` antes de cada tanda.

```bash
cd Packages/EconomyKit && swift test                      # 234 esperados
xcodegen generate
xcodebuild test -project FisuEvolution.xcodeproj -scheme FisuEvolution \
  -destination "platform=iOS Simulator,id=<UDID>" \
  -only-testing:FisuEvolutionTests -parallel-testing-enabled NO   # 411 esperados
# y la suite de UI COMPLETA en UNA corrida, sin skips: 46 esperados
```

Y el simulador de pacing, que es el que dice si el objetivo del dueño sobrevivió:

```bash
cd Tools/pacing-sim && swift run -c release pacing-sim \
  --economy ../../FisuEvolution/Resources/Data/economy.json \
  --tiers ../../FisuEvolution/Resources/Data/tiers.json \
  --upgrades ../../FisuEvolution/Resources/Config/upgrades.json --max-days 1500
```
Tiene que seguir dando **24,00 h activas para maxear · 8 reencarnaciones · Dios 26,59 h**.

---

## 6. Deuda declarada — NO la arregles en el merge, sólo no la empeores

- 8 call sites siguen con el molde viejo de cofre (`passiveUnlockCost × factor`): packs, Asado, diario ×2, cofre de bonus, premio de carrera. Conviven dos idiomas.
- Un save **v4** pre-rebalance con `crit` 10-24 cuenta como "al tope" y se lleva las skins doradas (distinguirlo pide schema v5).
- El redondeo de la migración puede regalar (19→10) o destruir (crit 1→0) un nivel en los bordes.
- El simulador no modela logros, eventos ni daily: la aceleración residual real-vs-bot está declarada y acotada, y crit/golden se pagan pero no se cobran (o sea que las 24 h son un **techo pesimista**).
- La fase fisura dura 28 s contra los 20-30 min del spec §4: es consecuencia de la decisión del dueño (primer Fisura a 25), declarada.
- `ach.skins_all.desc` dice "45 skins" y el catálogo tiene 131 — **ajeno a esta rama** (viene del frente de arte).

---

## 7. Lo que esta rama aprendió y te conviene no volver a pagar

1. **Un test que cambia de significado y queda verde es peor que uno rojo.** Pasó tres veces: el literal `9.000.000` que pasó a medir lo contrario de su nombre, dos tests de EconomyKit que pineaban una propiedad que el juego ya no tiene, y el fixture de la migración que era punto fijo. En todos, el test seguía en verde.
2. **Cuando cambiás un knob, grepeá también el CÓDIGO y el COPY**, no sólo la config: el único bug user-visible de la rama fueron dos banners que prometían ×5 y ×10.
3. **La documentación que afirma lo que el código ya no hace cuesta dos rondas.** La bitácora publicó números de un árbol descartado como si fueran los embarcados, y hubo que re-correr las tablas.
4. **Medí antes de atribuir.** La evidencia que defendía el knob de precios cotizaba con `purchases: 0`, o sea que era matemáticamente ciega a ese knob. El diagnóstico correcto apareció recién al re-medir: la divergencia la cierra la curva de ORO, y el `growth` decide otra cosa — **con 1,2 la partida no se puede terminar** (la run se traba en tier 11).
