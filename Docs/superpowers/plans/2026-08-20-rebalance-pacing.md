# Rebalance del pacing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** que maxear las siete líneas permanentes (skins doradas) cueste **20-30 h de juego ACTIVO** con **≤8 reencarnaciones**, y que Dios quede más lejos todavía — sin introducir un solo bug.

**Spec completa:** `Docs/PROMPT-rebalance-pacing.md` (evidencia medida, knobs, decisiones del dueño). Este plan la parte en tareas verificables.

**Arquitectura:** todo lo de economía es data-driven (`economy.json`, `upgrades.json`, `achievements.json`, `events.json`) y las fórmulas viven en EconomyKit (puro, `Sendable`, testeado). El simulador (`PacingSimulator` + `Tools/pacing-sim`) es el instrumento de medición y se arregla ANTES de tocar un solo knob.

## Global Constraints

- Cero warnings (`SWIFT_TREAT_WARNINGS_AS_ERRORS`). Swift 6 strict concurrency.
- EconomyKit es PURO y `Sendable`: no conoce UI. La UI no duplica fórmulas.
- El `.xcodeproj` no se versiona; `xcodegen generate` al agregar/borrar `.swift`.
- Strings nuevos a `Localizable.xcstrings` (es+en) en el mismo commit; catálogo a mano, NUNCA con scripts.
- `accessibilityIdentifier` en todo control; jamás en contenedores.
- Commits en español, atómicos.
- **NO se re-litiga** (HANDOFF §5): profundidad del gate = 1 piso; 37 tiers/10 pisos/10 slots; FisuJobs vende todo lo desbloqueado; el primer Fisura vale 25.
- **Trabajo en worktree propio** (`/Users/manuader/Desktop/projects/fisu-wt-pacing`, rama `fix/rebalance-pacing`): el checkout principal lo usa otra sesión del dueño que commitea con `git add -A`.
- Verificación: simulador PROPIO por UDID, unit ANTES que UI, `-parallel-testing-enabled NO`, borrar el simulador al terminar.
- **Regla anti-bug de esta rama**: ningún cambio de comportamiento sin un test que lo pinee ANTES (TDD). Si un test viejo cambia de significado, se reescribe explicándolo en el commit — nunca se borra.

---

### Task 1: El simulador vuelve a modelar al jugador

**Files:** `Packages/EconomyKit/Sources/EconomyKit/PacingSimulator.swift`, `Tools/pacing-sim/Sources/main.swift`, `Packages/EconomyKit/Tests/EconomyKitTests/` (tests nuevos)

**Por qué primero:** hoy el bot no compra NINGUNA de las siete mejoras permanentes (todo `derivedEffects` en cero), no conoce el atajo del HUD y tapea 3/s. Dice 191 h activas donde el dueño puso 3. Calibrar contra eso es tunear contra una ficción.

- [ ] **1.1** `HumanModel` gana `tapsPerSecond` defendible (5-8, documentado) y el `Report` gana **`maxedUpgradesActiveSeconds`** (segundos ACTIVOS hasta tener las 7 líneas al tope) más `maxedUpgradesWall`.
- [ ] **1.2** El bot compra mejoras permanentes con ORO. `UpgradesConfig` no vive en EconomyKit (está en el app target): pasarlo al simulador como parámetro nuevo del `init` (`upgrades: UpgradesConfig?`) o como una abstracción mínima `PermanentUpgradeLine { baseCost, costGrowth, maxLevel, effect, magnitudePerLevel }` declarada en EconomyKit. **Elegí la que NO obligue a mover código de la app a EconomyKit**; si hay que mover `UpgradesConfig` entero, PARÁ y reportá antes.
- [ ] **1.3** Los efectos comprados entran en las fórmulas del bot: `derivedEffects.tapMultiplier`, `.incomeMultiplier`, `.offlineEfficiency`, `.prestigeBonus`, `.spawnCostDiscount` (crit/golden pueden quedar fuera si el sim es determinístico — documentalo).
- [ ] **1.4** Tests nuevos en EconomyKit: (a) el bot compra al menos una línea permanente en una corrida corta; (b) con líneas compradas, el income del bot es mayor que sin ellas; (c) `maxedUpgradesActiveSeconds` es `nil` si nunca maxea y un número si maxea.
- [ ] **1.5** La CLI imprime la métrica nueva y el conteo de reencarnaciones al maxear.
- [ ] **1.6** Correr la línea de base NUEVA (`swift run -c release pacing-sim … --max-days 400`) y guardarla en `Docs/balance-log.md` como "antes" del rebalance. **Este número reemplaza al 191 h.**
- [ ] **1.7** Commit: `fix(sim): el bot compra las mejoras permanentes y mide cuándo maxea`

---

### Task 2: El atajo del HUD vende sólo el tier base de cada piso

**Files:** `FisuEvolution/Game/State/GameState+Hiring.swift`, `FisuEvolutionTests/BestHireTests.swift`, docstrings de `QuickHireButton.swift`

- [ ] **2.1** Test primero: un tier NO-base pagable y contratable **no** es la oferta; el tier base del piso más alto contratable **sí**. Los tests viejos que pinean "el tier más alto pagable" se reescriben (cambian de significado, no se borran).
- [ ] **2.2** `computeBestHire()` filtra candidatos a `type.tier == floorTable[quote.floorOrdinal].firstTier`. El resto de la regla (empates, meta de ahorro, `nil`) se conserva.
- [ ] **2.3** Docstrings de `BestHire`, `computeBestHire` y `QuickHireButton` dejan de decir "el mejor contratable que la plata alcanza".
- [ ] **2.4** Suite unit + `BottomMenuUITests`. Commit: `fix(atajo): el botón del HUD vende sólo el tier base de cada piso`

---

### Task 3: Los logros pagan segundos de producción

**Files:** `FisuEvolution/Game/State/GameState+Achievements.swift`, `FisuEvolution/Resources/Config/achievements.json`, tests

- [ ] **3.1** Test primero: el premio de un logro de monedas escala con la producción del jugador (dos estados con distinta producción → distinto premio) y NO con un costo fijo.
- [ ] **3.2** Migrar el cálculo al molde del Aguinaldo (`ContentSystems.swift:201`): `IncomeTicker.passivePerSecond(...) × segundos`. El campo del JSON pasa de `factor` a segundos (renombrarlo o reinterpretarlo — decidí y documentá; si cambia el nombre, migrar los 27 logros).
- [ ] **3.3** Calibrar los segundos por familia (piso / merges / hires / tiers / varios) para que el premio se sienta pero no salte etapas: rango sugerido 30-300 s, el de `ach_floor_*` creciendo con el piso.
- [ ] **3.4** Los 12 logros de ORO fijo (20-120) se re-miran DESPUÉS de la Task 5 (la escala del ORO cambia). Anotarlo, no tocarlo acá.
- [ ] **3.5** Suite unit. Commit: `feat(logros): el premio son segundos de tu producción, no un múltiplo de un costo`

---

### Task 4: Los eventos, más espaciados y menos regaladores

**Files:** `FisuEvolution/Resources/Config/events.json`, tests que pineen la config

- [ ] **4.1** `baseIntervalSeconds` 300 → **900** y jitter 180 → **300** (uno cada 10-20 min en vez de 2-8).
- [ ] **4.2** Subir `cooldownSeconds` de los que aceleran y bajar `magnitude`/`weight`: `plan_platita` (×5 → ×3), `inversion_alienigena` (×10 → ×5), `aguinaldo` (900 s → 300 s de producción), `blanqueo` (2 personajes → 1).
- [ ] **4.3** **Mantener o mejorar la proporción de eventos malos** (devaluación, corralito, cayó Mercado Pago): son la única tensión negativa. Verificar la suma de `weight` buenos vs malos antes y después y dejarla escrita en el commit.
- [ ] **4.4** Test que pinee la nueva cadencia y la proporción. Commit: `balance(eventos): más espaciados y menos regaladores, sin perder la cara mala`

---

### Task 5: El rebalance de fondo (costos vs ingresos, ORO, tap, las 7 líneas)

**Files:** `FisuEvolution/Resources/Data/economy.json`, `FisuEvolution/Resources/Config/upgrades.json`, posiblemente `EconomyConfig.swift` / `EconomyEngine.swift` / `GameActions.swift`

Es el corazón y va con el simulador en la mano: **un knob por vez, corrida antes y después, y el número que lo justifica a la bitácora**.

- [ ] **5.1 Divergencia costos-vs-ingresos.** Hoy los costos están anclados a `tapYield(tier)` (constante) y los ingresos pasan por `globalMultiplier` sin techo. Elegí UNA salida, medila y escribí por qué descartaste las otras: (a) los costos escalan con el multiplicador (total o `M^0,8`); (b) el multiplicador global pasa a ser sublineal en ORO (hoy `1 + oro×0,18`); (c) techo blando con rendimientos decrecientes.
- [ ] **5.2 Que reencarnar CONVENGA temprano** (criterio de aceptación de §2.6 del prompt): medí en qué momento de la run el multiplicador que te llevás supera lo que cuesta re-ascender. Si el óptimo sigue siendo "reencarnar recién contra la pared", el arreglo no sirvió.
- [ ] **5.3 ≤8 reencarnaciones** hasta maxear las siete, con el bot arreglado.
- [ ] **5.4 El click del tier alto**: separar la curva de tap de la de passive (hoy `passiveYield = tapYield × 0,5`, un solo knob para dos curvas), y/o sacarle al tap algún multiplicador. **El tap tiene que seguir siendo útil en el early game** — el tutorial lo enseña y la primera contratación sale de ahí.
- [ ] **5.5 Las siete líneas**: hoy `crit` es el 99,99 % del costo de ganar (1,776e10 de 1,778e10). Rebalancear `upgrades.json` para que las siete cuesten algo comparable y el total case con 20-30 h.
- [ ] **5.6** Objetivo final medido: **maxear las 7 en 20-30 h activas**, Dios más lejos, ≤8 reencarnaciones.
- [ ] **5.7** Commits atómicos por knob o por grupo coherente, cada uno con su número en el mensaje.

---

### Task 6: Re-pinear PacingTests, verificación integral y documentación

- [ ] **6.1** `FisuEvolutionTests/PacingTests.swift` está **3/4 EN ROJO** hoy. Re-pinear las cuatro bandas a la conducta nueva (±30 % del medido) + assert nuevo de "maxear las 7 en 20-30 h activas" y de "≤8 reencarnaciones". Cada banda con el comentario de qué corrida la produjo.
- [ ] **6.2** EconomyKit (`swift test`) → unit (`FisuEvolutionTests`) → UI completa, todo verde, cero warnings.
- [ ] **6.3** `Docs/balance-log.md`: entrada nueva con la tabla piso por piso antes/después, los knobs movidos, y **lo descartado con su número**.
- [ ] **6.4** Cierre según el sistema de handoffs: `Docs/SESION-2026-08-20-rebalance-pacing.md` + `handoffs/HANDOFF-2026-08-20-rebalance-pacing.md` + entrada nueva en `Docs/HANDOFF.md`.
- [ ] **6.5** Commit de docs.
