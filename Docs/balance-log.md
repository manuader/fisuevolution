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

**Aprobación del gate:** _pendiente — jugar 20 min reales + revisar esta tabla y
firmar acá con fecha._
