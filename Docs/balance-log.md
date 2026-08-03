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
