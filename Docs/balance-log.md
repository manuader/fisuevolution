# Balance log — gate de F2

Registro de iteraciones de `economy.json` con `Tools/balance-sim` (bots: tap-only,
merge-greedy, passive-first; 3 taps/s y 2 acciones de board/s como techo humano).
El check duro exige que merge-greedy llegue a T30 dentro del tope de horas activas.

**Targets [TUNEABLE] del plan:** primer merge <1 min · T9 (carrera) en la sesión 1 ·
primer prestige ≈ día 2–5 (~4–10 h activas + offline) · curva sin paredes.

## Iteración 1 — valores literales del bible §3

`baseCost 15 · costGrowth 1.15 · tierOffset 4 · basis perType`

| bot | T9 | T21 | T30/prestige |
|---|---|---|---|
| merge-greedy | 1.5m | 4.8m | **7.2m** |
| passive-first | 2.2m | 5.5m | 8.0m |

❌ **50× demasiado rápido.** El costo por tipo se resetea cuando la ventana de
spawn avanza → cero fricción acumulada.

## Iteración 2 — knobs de a uno sobre basis perType

| cambio | resultado | veredicto |
|---|---|---|
| tierOffset 6 u 8 | atascado en T7 a las 24h | ❌ pared infranqueable: los costos del tipo base nunca resetean y explotan |
| costGrowth 1.25 | T30 en 8.7m | ❌ casi no mueve |
| baseCost 40 | T30 en 7.8m | ❌ ídem |
| costGrowth 1.5 | T5 en 2m → T9 en 3.5h → T30 en 3.66h | ❌ TODA la dificultad en una sola pared (T5→T9); después trivial |
| costGrowth 1.7 | atascado en T5 | ❌ pared |

**Conclusión estructural:** con el exponente por tipo, el pacing colapsa en una
única pared donde la ventana de spawn se estanca. La forma correcta necesita
inflación global.

## Iteración 3 — `costBasis: total` (exponente = spawns totales de la vida)

| growth | base | T9 | T21 | T25 | T30 greedy | T30 passive |
|---|---|---|---|---|---|---|
| 1.02 | 15 | 1.5m | 7m | 18m | 1.28h | 3.24h |
| 1.035 | 15 | 1.5m | 2h | — | ❌ >36h | — |
| 1.025 | 50 | 1.8m | 45m | 3.3h | 22.6h | — |
| 1.024 | 50 | 1.8m | 36m | 2.5h | 15.8h | — |
| **1.022** | **50** | **1.8m** | **24m** | **1.5h** | **7.77h** | 19.3h |
| 1.023 | 40 | 1.7m | 24m | 1.6h | 8.9h | 22h |

## Propuesta v1 (aplicada, pendiente de gate humano)

`baseCost 50 · costGrowth 1.022 · tierOffset 4 · costBasis total`

- Primer merge: 16 s ✓ · T5: 42 s · **T9 (elección de carrera): ~2–3 min** ·
  T15: 4.5 m · T21: 24 m · T25: 1.5 h · **T30/prestige: 7.8 h activas (greedy)**.
- Curva geométrica pareja: cada tier tarda más que el anterior, sin paredes.
- Nota de diseño: T9 llega antes que el target original (20–40 m) — el momento
  meme de la carrera cae temprano en la sesión 1 y engancha. Si lo querés más
  tarde, subir `baseCost` (80 → T9 ≈ 4–5 m) o `costGrowth` (mueve todo el tail).

## Cómo re-correr

```bash
swift run --package-path Tools/balance-sim balance-sim \
  --economy FisuEvolution/Resources/Data/economy.json \
  --tiers FisuEvolution/Resources/Data/tiers.json --max-hours 36
```

**Aprobación del gate:** ✅ aprobado por el usuario el 2026-07-18 tras playtest
en Simulador ("el juego parece funcionar bien"). economy.json v1 queda congelado
como base; próxima revisión de números recién con feedback de TestFlight.

---

# F7.1 — Calibración inicial de "La Torre" (2026-08-03)

Primera corrida real de `PacingSimulator` (16 iteraciones de knobs). Config
congelada en economy.json v2; targets del PLAN §F7.1c (±30% ya aplicado).

## Resultado final del sim (bot greedy, 4 sesiones×20 min/día)

| Hito | Valor | Target | |
|---|---|---|---|
| urban (piso 2) activo | 16.2 min | 14–39 min | ✅ |
| gradiente urban→island (geomean) | ×1.92/piso | 1.15–2.6 | ✅ |
| 1ª reencarnación (pared) | 4.0 h | 2.8–7.8 h | ✅ |
| Dios (pared) | 48.3 h | 21–65 h | ✅ |
| Reencarnaciones al llegar | 15 | ≥3 | ✅ |

## Knobs que movió la calibración (seed → final)

- `yieldGrowthPerTier` 2.6 → **2.8** (tiers.json regenerado): el income de
  frontera tiene que ganarle al costo del backfill para que las cadenas de
  merge profundas (16×T6 → T10) sean pagables. ERA el cuello del mid-game.
- `hire.defaultCostMultiplier/Growth` 600/1.6 → **3000/1.15**: entrada punitiva
  más cara (×5) pero growth suave — lo caro es ENTRAR; el growth alto mataba
  las cadenas largas.
- Overrides por piso: alley **450/15** (fase fisura 15-20 min), corporate
  **1800** (abarata la cadena de T10), luxury **9000** (separa island de luxury).
- `oro.divisor` 5e9 → **3e6** (1ª reencarnación en el día 1, sesión 2) y
  `globalMultiplierPerOro` 0.02 → **0.12** (la escalera de duplicaciones
  comprime el late game: dios en ~2 días).
- `charUpgrades.costGrowth` 7.0 → **4.0** (runs más profundas antes del techo
  de payback).
- `offlineEfficiencyBase` 0.5 → **0.35**.

## Notas de diseño (para el dueño)

1. **"1ª reencarnación ~piso 5-6" del plan quedó descartado por inconsistente**:
   con 80 min activos/día, el piso 5 está a días de distancia — imposible junto
   con "1ª reencarnación 2.8–7.8 h pared". Se calibró al assert duro (pared);
   la 1ª reencarnación cae con frontera en corporate (piso 3).
2. **El assert de ratio se implementa como gradiente geomean del arco
   urban→island + guarda anti-acantilado (≤4.0 por paso)**: los unlocks se
   pegan a los inicios de sesión del modelo humano (el offline paga la cadena
   durante el gap), así que los ratios individuales son discretos/lumpy por
   estructura, no por curva. Post-island los ratios tienden a 1.0 POR DISEÑO
   (sweep de prestigio).
3. **Fix al simulador (desviación vs plan aprobado)**: `hireAction` no
   implementaba la regla «hire si <25% del wallet» del plan — sin ella el bot
   nunca compra material de merge y la progresión muere en T5-T8. Se agregó
   (PacingSimulator.swift). Sin cambios de gameplay real: es el modelo de
   jugador.

## Cómo re-correr

```bash
swift run --package-path Tools/pacing-sim pacing-sim \
  --economy FisuEvolution/Resources/Data/economy.json \
  --tiers FisuEvolution/Resources/Data/tiers.json
```

La grid search fina sobre los 6 knobs (margen ≥15%) queda para F7.6.

## Ajuste pedido — 2026-08-04: primer Fisura a 50

Por pedido explícito del dueño, el override de contratación de `alley` baja de
**450** a **50** (growth se conserva en 15). Se mantiene aunque descalibra los
targets históricos: es la nueva decisión de producto, no un accidente.

Corrida inmediata de `Tools/pacing-sim` (90 días, mismos seeds): urban **5.8 min
activos** (antes 16.2), primera reencarnación **0.26 h pared** (antes 4.0), dios
**33.20 h** con 13 reencarnaciones. Urban, gradiente y primera reencarnación
quedan fuera de banda; dios y cantidad de reencarnaciones siguen en banda.

La recalibración integral queda deliberadamente para F7.6: no modificar otros
knobs sin una nueva decisión del dueño, porque compensar el arranque barato con
otra pared cambiaría la intención recién aprobada.

---

# F7.6 — Re-pineo de targets (2026-08-04)

**Decisión del dueño en esta sesión:** conservar el primer Fisura a **50**
(commit `99af8dd`) y **bajar los targets** a la conducta real, en vez de
recalibrar los otros knobs. Por lo tanto el grid search de 6 knobs que pedía el
plan F7.6 **no se hizo**: `economy.json` y `tiers.json` quedan intactos.

## Lo que esto cuesta (medido, no estimado)

| Hito | Diseño original (§4 spec) | Calibrado F7.1 (Fisura 450) | **Hoy (Fisura 50)** |
|---|---|---|---|
| Fase fisura (piso 2) | ≥ 20-30 min activos | 16.2 min | **5.8 min** |
| 1ª reencarnación | 4-6 h | 4.0 h | **0.26 h** (~16 min) |
| Dios | 30-50 h | 48.3 h | 33.2 h ✅ |
| Reencarnaciones | varias | 15 | 13 ✅ |

El early game quedó **~3× más corto** que el calibrado y **~4-5× más corto** que
el objetivo de diseño. La primera reencarnación pasó de ser un hito de la tarde
a caer dentro de la primera sesión. El late game (dios, reencarnaciones) sigue
en banda: el Fisura barato acelera el arranque, no el juego entero.

Esto **no es una mejora de pacing**: es un intercambio deliberado de duración por
sensación de arranque. Queda registrado para que una recalibración futura sepa
exactamente qué se cambió y cuánto costó.

## Qué se re-pineó

`FisuEvolutionTests/PacingTests.swift`, con ±30% sobre la corrida real:
- fase fisura: 14-39 min → **4-8 min**
- 1ª reencarnación: 2.8-7.8 h → **0.15-0.40 h**
- gradiente (geomean urban→island) y dios/reencarnaciones: **sin cambios**, ya
  pasaban (×2.43 y 33.2 h).

Los asserts ahora fijan la conducta ACTUAL para detectar regresiones; no
representan el pacing que el spec pedía. `pacing-sim` sigue imprimiendo los
targets de DISEÑO en su semáforo, a propósito, para que la brecha quede visible
cada vez que se corre.

## Corrida completa

`Docs/balance-run-f7.csv` (generado con `--csv`, incluye pisos, hitos y los
knobs vigentes).

```bash
swift run --package-path Tools/pacing-sim pacing-sim \
  --economy FisuEvolution/Resources/Data/economy.json \
  --tiers FisuEvolution/Resources/Data/tiers.json \
  --csv Docs/balance-run-f7.csv
```

---

# Regla de precios de contratación (2026-08-04, decisión del dueño)

Reemplaza a los multiplicadores por piso que venían de la calibración F7.1.
**Una sola regla para toda la torre:**

- Contratar el tier base de un piso cuesta **300 × lo que rinde un click de ese
  mismo personaje EN ESE PISO** — o sea `tapYield(tier) × incomeMultiplier(piso)`,
  no el tapYield pelado (elegido explícitamente por el dueño entre las dos
  lecturas posibles).
- **Cada compra sube el precio un 20%** (`growth = 1.2`), en todos los pisos.
- **Excepción única**: el piso 1 usa multiplicador 50 en vez de 300. Contratar un
  Fisura tiene que ser siempre barato — el callejón queda fuera de la regla cara
  a propósito, no por falta de calibración.

Implementación: `EconomyConfig.hireCost(floor:tapYield:purchases:)`, una sola
función que usan `TowerActions.hireQuote` y `PacingSimulator`. Antes la fórmula
estaba duplicada en los dos lugares; unificarla evita que el simulador cotice
distinto que el juego.

Precios de arranque por piso (primera compra):

| piso | tier base | rinde el click | primer precio (×300) |
|---|---|---|---|
| alley | 1 | 1 | **50** (excepción, ×50) |
| urban | 3 | 15.7 | 4.7k |
| corporate | 6 | 620 | 186k |
| luxury | 10 | 74k | 22.2M |
| island | 14 | 8.5M | 2.5G |
| moon | 18 | 1.0G | 300G |
| god_realm | 30 | 5.8P | 1.7P |

Curva del alley: 50, 60, 72, 86, 104, 124, 149, 179, 215, 258… (el n°20 sale
1.597 y el n°30, 9.891).

## Efecto en el pacing (medido, no estimado)

| Hito | Diseño (§4 spec) | Calibrado F7.1 | Fisura 50 (F7.6) | **Regla nueva** |
|---|---|---|---|---|
| Fase fisura | ≥20-30 min | 16.2 min | 5.8 min | **0.8 min** |
| 1ª reencarnación | 4-6 h | 4.0 h | 0.26 h | **0.14 h** |
| Dios | 30-50 h | 48.3 h | 33.2 h | 38.3 h ✅ |
| Reencarnaciones | varias | 15 | 13 | 16 ✅ |

**Ajuste posterior del mismo día**: el multiplicador de pisos superiores pasó de
100 a **300** (el callejón sigue en 50). Sube el peso del backfill sin tocar el
arranque: Dios pasa de 33.2 a 38.3 h con 17 reencarnaciones, y el arco medio se
empina (geomean ×4.2 por piso, con un escalón en luxury ×7.1). La fase fisura no
se mueve —la fija la curva del callejón, que quedó intacta a propósito—.
Se probó también ×400: mismo tiempo a Dios y un escalón más brusco en luxury
(×10.5), así que ×300 quedó como el punto más parejo.

El crecimiento del 20% es MUCHO más suave que el 15× que tenía el alley, así que
la fase fisura pasó de 5.8 min a **48 segundos**: el jugador compra 10 Fisuras
con 1.400 monedas. El arco medio (urban→island) sigue teniendo pendiente sana
(×2 a ×5 por piso) y el late game no se movió: Dios sigue a 33 h con 16
reencarnaciones.

O sea: el juego largo se mantiene, lo que se comprimió casi por completo es el
arranque. `PacingTests` se re-pineó otra vez a esta conducta; los targets de
DISEÑO siguen mostrándose en el semáforo de `pacing-sim` para que la brecha no
se olvide.

---

# Gate de contratación (2026-08-04, decisión del dueño)

Contratar en un piso pasa a exigir **el piso de arriba desbloqueado**. El
callejón queda exento (siempre se puede contratar un Fisura) y el último piso se
habilita a sí mismo al abrirse, porque no tiene ninguno por encima.

## El pedido original era DOS pisos y rompe el juego

Medido, no estimado. Tres corridas de `pacing-sim`, misma config, mismo seed:

| | sin gate | **+1 (elegido)** | +2 (pedido original) |
|---|---|---|---|
| urban (piso 2) activo | 0.8 min | 0.8 min | 0.8 min |
| corporate (piso 3) | — | 4.2 min | 4.2 min |
| luxury (piso 4) | 25.7 min | 200.8 min | 977.9 min |
| island (piso 5) | 58.0 min | 403.5 min | **nunca** |
| **Dios (pared)** | **38.2 h** | **264.2 h** | **nunca** (traba en tier 12) |
| reencarnaciones | 17 | 50 | 49 |

**Por qué +2 no funciona, y no es cuestión de calibrar**: el §3.3 del prompt de
F7 dice que el merge puro es matemáticamente inviable (T30 = 2²⁹ fisuras) y que
el backfill es el puente que lo hace posible. Exigir dos pisos saca ese puente
justo donde hace falta —no podés comprar material en el piso que estás
atravesando— y queda un huevo-y-gallina, porque la frontera avanza GRACIAS al
backfill. El bot entra a luxury a las 288 h y se queda ahí reencarnando 49 veces
sin avanzar.

## Lo que cuesta la opción elegida

El dueño eligió +1 sabiendo que **el juego se alarga ~7×**: Dios pasa de 38.2 h a
264.2 h de pared. El early game no se mueve (la fase fisura la fija la curva del
callejón, que quedó intacta).

**Consecuencia derivada que NO estaba en la decisión**: apareció un acantilado de
**×47.8 en luxury** (antes ×7.1). El backfill de corporate se habilita recién al
abrir luxury, así que atravesar corporate pasó a depender casi sólo del merge
desde abajo. El gradiente geomean del arco urban→island subió de ×2.43 a ×7.96.

## Qué se re-pineó

`FisuEvolutionTests/PacingTests.swift`, tercera vez, con ±30% sobre la corrida
real:

- gradiente geomean: 3.0–6.0 → **5.6–10.3**
- guarda anti-acantilado por paso: ≤9.0 → **≤62.0**
- dios: 21–65 h → **185–343 h**
- fase fisura y 1ª reencarnación: **sin cambios**, no se movieron

⚠️ La guarda anti-acantilado quedó **vestigial**: con el tope en 62 ya casi no
puede saltar. Si algún día se recalibra el balance, eso es lo primero que hay que
volver a bajar.

`pacing-sim` sigue imprimiendo los targets de DISEÑO en su semáforo, así que la
brecha queda visible cada vez que se corre.
