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

---

# Contratación ×2 más cara (2026-08-04, decisión del dueño)

`hire.defaultCostMultiplier` **300 → 600**. El callejón NO se toca: sigue con su
override de 50, así que la curva del Fisura queda igual (50, 60, 72, 86…).

O sea: contratar el tier base de cualquier piso superior pasa a costar 600× lo
que rinde un click de ese personaje ahí.

## Efecto medido (y es contraintuitivo)

| Hito | gate +1 a 300× | **gate +1 a 600×** |
|---|---|---|
| fase fisura (urban) | 0.8 min | 0.8 min |
| corporate | 4.2 min | 4.2 min |
| luxury | 200.8 min | 201.3 min |
| island | 403.5 min | 443.9 min |
| **Dios (pared)** | 264.2 h | **196.3 h** |
| reencarnaciones | 50 | 41 |

**Duplicar el precio ACORTÓ el juego** (264 h → 196 h). No es un error de
medición: el bot sólo hace backfill cuando le es rentable, así que encarecerlo no
lo hace tardar más — lo hace **dejar de hacerlo** y volcar esa plata a pasivo,
mejoras por personaje y reencarnar. El barrido de reencarnación resulta más
rápido que la molienda de backfill, y por eso llega antes con MENOS
reencarnaciones (41 vs 50).

⚠️ Eso vale para el bot greedy del simulador, que es un **modelo** de jugador.
Un jugador real que insista en rellenar pisos sí va a sentir el doble de precio.
La conclusión sólida es la del arco: el early game no se mueve y el mid game
tampoco (luxury queda igual); lo que cambia es la estrategia óptima del late
game.

## Tests

No hizo falta re-pinear nada: `PacingTests` quedó dentro de las bandas fijadas
para el gate (dios 185-343 h contiene 196.3; el gradiente geomean ×8.21 entra en
5.6-10.3). `GameContentValidationTests` sí se actualizó — es anti-drift y pinea
el 300 explícitamente.

App 83/83.

---

# Línea de base ANTES del remapeo — 2026-08-06

Medición tomada **a propósito antes** de tocar nada, porque una vez que la torre
pase de 30 tiers en 11 pisos a 37 en 10 (RF-10) este número no se puede volver a
tomar. Es contra esto que se compara el rebalance conjunto de la Ola 3.

Comando (el mismo de siempre, sin cambios en `economy.json` ni `tiers.json`):

```bash
swift run --package-path Tools/pacing-sim pacing-sim \
  --economy FisuEvolution/Resources/Data/economy.json \
  --tiers FisuEvolution/Resources/Data/tiers.json
```

## Los números

| Métrica | Valor |
|---|---|
| Dios (pared) | **196,30 h** · maxTier final 30 |
| Reencarnaciones al llegar | **41** |
| 1ª reencarnación (pared) | 0,14 h |
| `lifetimeEarnings` final | 1,830e+33 |

Desbloqueo de pisos, pared:

| Piso | Pared | Ratio contra el anterior |
|---|---|---|
| urban | 0,01 h | — |
| corporate | 0,07 h | ×5,18 |
| luxury | 57,02 h | ×47,40 |
| island | 129,06 h | ×2,21 |
| moon | 196,14 h | ×1,51 |
| mars | 196,26 h | ×1,01 |
| solar | 196,27 h | ×1,00 |
| galaxy | 196,27 h | ×1,00 |
| cosmic | 196,28 h | ×1,00 |
| god_realm | 196,30 h | ×1,00 |

## El hallazgo: el acto cósmico no se juega, se desmorona

**Los últimos cinco pisos se abren en 4 minutos**, de 196,14 h a 196,30 h. Mars,
solar, galaxy, cosmic y god_realm tienen ratio ×1,00 entre sí: para cuando el
jugador llega a la Luna ya tiene tanta plata acumulada que el resto de la torre
cae de una sola vez.

Eso reencuadra el pedido del playtest. La queja fue *"en todos los pisos deben
haber por lo menos 4 personajes"*, y es cierta — pero el problema de los pisos
cósmicos **no es sólo que tengan dos personajes**: es que el jugador pasa por
los cinco en el tiempo que tarda en leer sus nombres. Meterles 7 tiers más
(RF-10) los llena de contenido, y sin tocar la curva ese contenido se va a
consumir igual de rápido.

⚠️ **Consecuencia para el rebalance de la Ola 3.** Bajar el exponente del ORO de
0,50 a 0,40 (RF-07) endurece la reencarnación, que es la palanca del late game,
así que empuja en la dirección correcta. Pero el ×1,00 entre los cinco pisos de
arriba no lo arregla el exponente del ORO: sale de que `incomeMultiplier` crece
×2 por piso mientras las ganancias del jugador crecen mucho más rápido. Si
después de la Ola 3 esos ratios siguen en ×1,00, el knob a mirar es la curva de
`incomeMultiplier` de `floors[]`, no el ORO.

Los targets de diseño que imprime el simulador (dios 21-65 h) siguen sin
cumplirse por un factor de 3, y eso es **conocido y aceptado**: `PacingTests`
está pineado a la conducta real desde F7.6, no al pacing que el spec pedía
(decisión 5 del HANDOFF). El simulador los sigue imprimiendo para que la brecha
quede visible.

---

# Medición DESPUÉS del remapeo, antes de tocar el ORO — 2026-08-06

Segunda mitad del par de mediciones: misma corrida, mismos seeds, con la torre
de **37 tiers en 10 pisos** ya integrada y **sin haber tocado el exponente del
ORO todavía**. Aísla lo que hizo el remapeo solo.

| Métrica | Antes (30 tiers / 11 pisos) | Ahora (37 / 10) |
|---|---|---|
| Dios (pared) | 196,30 h | **436,16 h** (×2,2) |
| Reencarnaciones | 41 | 53 |
| 1ª reencarnación | 0,14 h | 0,22 h |
| `lifetimeEarnings` final | 1,83e+33 | 1,04e+44 |

## El hallazgo: se abrió un muro de ×368 antes de corporativo

| Piso | Pared | Ratio |
|---|---|---|
| urban | 0,04 h | — |
| **corporate** | **268,00 h** | **×367,88** |
| luxury | 312,03 h | ×1,16 |
| island | 336,12 h | ×1,08 |
| moon | 336,22 h | ×1,01 |
| mars | 360,29 h | ×1,07 |
| solar | 432,25 h | ×1,20 |
| galaxy | 436,04 h | ×1,00 |
| god_realm | 436,16 h | ×1,01 |

**El jugador pasa 268 horas en el piso urbano.** Es, de lejos, el problema más
grave que tiene el juego hoy — peor que cualquiera de los 16 del playtest.

### Por qué pasa, y por qué nadie lo previó

Sale de la interacción entre dos cosas que se decidieron por separado:

1. **El gate de contratación** exige el piso de arriba desbloqueado, y el
   callejón está exento. O sea: hasta que corporativo no abre, **lo único que se
   puede comprar es el tier más barato del callejón**, y todo lo demás sale de
   mergear.
2. **El remapeo empujó el primer tier de corporativo de 6 a 9.** Mergear desde el
   callejón hasta el tier 9 cuesta 2⁸ = 256 Fisuras, contra las 2⁵ = 32 de antes:
   **ocho veces más**, y cada una comprada a un precio que sube con la curva.

Ninguna de las dos decisiones estaba mal por su cuenta. El spec de RF-10 razonó
sobre "4 personajes por piso" y no sobre la profundidad de merge que eso exige
antes de que el gate se abra.

### Lo que esto le hace al plan de la Ola 3

⚠️ **Bajar el exponente del ORO (RF-07) no toca este problema.** El ORO es la
palanca del late game; el muro está en el tier 9, antes de la primera
reencarnación útil. Si se aplica RF-07 sobre esto, el juego se hace **más** largo
sobre un arranque que ya es injugable.

El orden correcto es: **primero el muro, después el ORO.** Y el muro tiene tres
knobs candidatos, ninguno medido todavía:

- La **cobertura del gate**: eximir también al piso urbano, no sólo al callejón.
- El **`hireCostMultiplier` del urbano**, hoy heredando el default de 600×.
- La **curva de `incomeMultiplier` de `floors[]`**, que sigue creciendo ×2 por
  piso mientras las ganancias crecen mucho más rápido — que es también la causa
  del ×1,00 entre los cinco pisos de arriba, ya anotado en la medición anterior y
  **todavía sin resolver**.

Vale el antecedente de esta misma bitácora: subir `hire.defaultCostMultiplier` de
300 a 600 **acortó** el juego en vez de alargarlo. En esta economía la intuición
falla seguido; ningún knob se mueve sin correr el simulador.

---

# El muro de ×368, cerrado — y RF-07 aplicado (Ola 3, frente A4, 2026-08-06)

Cierra el par de mediciones anteriores. Orden de trabajo deliberado: **primero el
muro, después el ORO**, porque el ORO es la palanca del late game y el muro
estaba antes de la primera reencarnación útil — aplicarlo al revés habría hecho
más largo un arranque ya injugable.

## Resultado

| Métrica | Antes del remapeo | Con el muro (main) | **Ahora** |
|---|---|---|---|
| Dios (pared) | 196,30 h | 436→441,16 h | **345,28 h** |
| Muro peor ratio | ×47,40 (luxury) | ×367,88 (corporate) | **×24,61 (corporate)** |
| Tramos colapsados (ratio ≤1,01) | 5 | 3 | **0** |
| Reencarnaciones | 41 | 54 | 45 |
| 1ª reencarnación | 0,14 h | 0,22 h | 0,20 h |
| `lifetimeEarnings` final | 1,83e+33 | 3,81e+46 | 1,14e+40 |

Piso por piso (activo / pared / ratio contra el anterior):

| Piso | Activo | Pared | Ratio |
|---|---|---|---|
| urban | 2,4 min | 0,04 h | — |
| corporate | 60,2 min | 14,00 h | ×24,61 |
| luxury | 382,7 min | 110,05 h | ×6,36 |
| island | 467,4 min | 134,12 h | ×1,22 ✅ |
| moon | 548,3 min | 158,14 h | ×1,17 ✅ |
| mars | 636,9 min | 182,28 h | ×1,16 ✅ |
| solar | 783,8 min | 230,06 h | ×1,23 ✅ |
| galaxy | 1042,3 min | 312,04 h | ×1,33 ✅ |
| god_realm | 1176,8 min | 345,28 h | ×1,13 |

El ✅ es la banda de DISEÑO (1,15–2,6). **Cinco de los ocho ratios entran en ella
por primera vez desde F7.1** (god_realm queda a un pelo, en 1,13), y el acto
cósmico —que se abría entero en 4 minutos— hoy se reparte en 187 h. El muro de
268 h en el piso urbano no existe más.

## Los knobs que se movieron (2 de 3 candidatos, más uno no previsto)

1. **Cobertura del gate — el que arregló el muro.** `hireGateExempt: true` en el
   piso urbano. Es un campo nuevo de `floors[]`; lo lee `TowerActions.canHire`,
   la misma función única que usan el juego y el simulador (no se duplicó nada).
   **No toca la PROFUNDIDAD del gate**, que sigue siendo de un piso: la decisión
   3 del HANDOFF queda intacta. Lo que cambia es de qué pisos se puede sacar
   material de merge mientras se atraviesa la frontera.
2. **`oro.exponent` 0,50 → 0,45** (RF-07).
3. **`oro.globalMultiplierPerOro` 0,12 → 0,18**, no previsto en el plan: sin él
   RF-07 deja el juego en 398 h. Compensa el largo sin devolver el colapso.

`hire.defaultCostMultiplier` sigue en **600** y el callejón en **50**: las
decisiones 1 y 2 del HANDOFF no se tocaron. `tiers.json` no se regeneró porque no
se tocó la cadena de yields.

## Lo que se probó y se DESCARTÓ, con su número

| # | Knob | Dios | Muro corporate | Veredicto |
|---|---|---|---|---|
| 0 | (línea de base, sin tocar nada) | 441,16 h | 268,00 h ×367,88 | referencia |
| 1 | `urban.hireCostMultiplier` 600→50, **sin** tocar el gate | 441,17 h | **268,00 h** | ❌ **inerte**: el muro no se mueve ni un minuto |
| 2 | gate urbano exento (solo) | 240,14 h | 14,01 h ×25,2 | ✅ mata el muro, pero quedan 4 tramos en ×1,01 |
| 3 | gate + `urban.hireCostMultiplier` 50 | 196,04 h | 0,12 h ×3,0 | ❌ pasa de largo: mueve el acantilado a luxury (×39) |
| 4 | gate + `incomeMultiplier` ×3/piso | 230,20 h | 9,00 h ×16,7 | ❌ **no toca el ×1,00** |
| 5 | gate + `incomeMultiplier` ×1,5/piso | 268,17 h | 24,09 h ×20,6 | ❌ **no toca el ×1,00** |
| 6 | gate + ORO 0,40 (lo que pedía RF-07) | **1094,04 h** | 4,01 h | ❌ luxury explota a 782 h (×129) |
| 7 | gate + ORO 0,40 + mult 0,20 | 657,05 h | 4,01 h | ❌ sigue larguísimo |
| 8 | gate + ORO 0,40 + mult 0,30 | 489,19 h | 9,04 h | ❌ largo y con luxury ×17,8 |
| 9 | gate + ORO 0,47 | 268,28 h | 24,09 h | ❌ vuelve el ×1,01 en island/moon/mars |
| 10 | gate + ORO 0,45 (mult 0,12) | 398,28 h | 24,00 h | ✅ forma sana, pero 398 h |
| 11 | gate + ORO 0,44 + mult 0,18 | 384,28 h | 14,27 h | ✅ sano, más largo que el elegido |
| 12 | gate + ORO 0,45 + mult 0,20 | 345,00 h | 14,00 h | ❌ reaparece island→moon ×1,01 |
| 13 | gate + ORO 0,45 + mult 0,25 | 297,28 h | 9,01 h | ❌ colapso: luxury/island/moon ×1,01 |
| 14 | gate + ORO 0,45 + mult 0,35 | 249,20 h | 9,01 h | ❌ colapso peor |
| 15 | + `offlineCapHours` 10→16 | 345,28 h | 14,00 h | ❌ **inerte**, el tope no ata |
| 16 | + `offlineEfficiencyBase` 0,35→0,50 | 326,28 h | 14,00 h | ❌ descartado: 5% de largo por un knob más |
| ✅ | **gate + ORO 0,45 + mult 0,18** | **345,28 h** | **14,00 h ×24,61** | **elegido** |

## Tres hallazgos que corrigen lo que esta bitácora daba por sentado

**1. El `incomeMultiplier` NO es la causa del ×1,00.** La medición anterior lo
señalaba como el knob a mirar. Es falso, y está medido: barrer la curva de ×1,5 a
×3 por piso —un factor 2 por piso, que compuesto sobre la torre son ~3.000×— deja
el colapso intacto en las dos puntas (corridas 4 y 5). Mueve el largo total, no
la forma.

**2. La causa real es la potencia del barrido de reencarnación.** El patrón del
colapso es siempre "un salto grande y después dos o tres pisos casi gratis": es
el jugador barriendo pisos enteros con el multiplicador global que trae de la
reencarnación anterior. Por eso lo arregla el ORO y no el income: bajar el
exponente le saca potencia al barrido. Y por eso **`globalMultiplierPerOro` es el
knob más peligroso de los tres** — a 0,25 el colapso vuelve entero (corrida 13)
aunque el exponente esté en 0,45. La nota de F7.1 que decía "post-island los
ratios tienden a 1,0 POR DISEÑO" describía un síntoma, no un diseño.

**3. RF-07 pedía 0,40 y 0,40 no sirve.** Medido: 1094 h, con luxury a 782 h. El
spec estimó el número antes de que existiera la torre de 37 tiers; el propio
RF-07 dice "calibrado con `pacing-sim`", y calibrado da **0,45**. Con 0,45 la
queja del playtest igual queda atendida —ver la tabla de abajo—.

## La tabla de ORO que pide RF-07

`ORO = (lifetimeEarnings / 3.000.000) ^ exponente`

| `lifetimeEarnings` | ORO viejo (0,50) | ORO nuevo (0,45) | queda en |
|---|---|---|---|
| 1e+07 | 2 | 2 | ×0,94 |
| 1e+09 | 18 | 14 | ×0,75 |
| 1e+12 | 577 | 306 | ×0,53 |
| 1e+15 | 18.257 | 6.844 | ×0,38 |
| 1e+20 | 5.773.503 | 1.217.014 | ×0,21 |
| 1e+25 | 1,83e+09 | 2,16e+08 | ×0,12 |
| 1e+30 | 5,77e+11 | 3,85e+10 | ×0,07 |
| 1e+35 | 1,83e+14 | 6,84e+12 | ×0,04 |
| 1e+40 | 5,77e+16 | 1,22e+15 | ×0,02 |

Es exactamente lo que pedía el requisito: **las primeras reencarnaciones quedan
casi iguales (×0,94) y las tardías rinden 50 veces menos (×0,02)**. La curva se
aplasta por la cola, que era la queja.

## Una trampa de método que casi mete un número falso en esta bitácora

Las primeras cuatro corridas del knob `hireCostMultiplier` del urbano se
escribieron en el JSON como `hireCostMultiplierOverride`, que es el nombre del
campo en Swift pero **no la clave del JSON** — `FloorDef.CodingKeys` la mapea a
`hireCostMultiplier`. El decoder ignora las claves que no conoce **sin fallar**,
así que las cuatro corridas usaron el default de 600 y salieron idénticas hasta
el último dígito. Eso *parecía* la confirmación limpia de que el knob era inerte.

Lo delató que fueran idénticas **byte a byte** con un rango de 40× en el
parámetro: un knob con efecto chico da números parecidos, no iguales. Al
re-correrlo con la clave correcta el resultado de fondo se sostuvo (el knob sí es
inerte mientras el gate está cerrado, corrida 1), pero por poco entra a la
bitácora una medición que no midió nada.

**Regla para el próximo**: si dos corridas dan un número idéntico, sospechá del
harness antes de creerle al hallazgo. Verificar con
`python3 -c "import json; print(json.load(open('variante.json'))['floors'][1])"`
cuesta cinco segundos.

## Efecto de lado del piso exento (no es sólo un número)

Declarar un piso exento le saca dos comportamientos de UI que sólo existen para
pisos con el gate cerrado, y hubo que re-apuntar dos tests que los cubrían:

- **no emite el aviso `hireUnlocked`** —nunca pasa de bloqueado a contratable—, y
- **no hace fallback al piso de abajo** al comprar, porque contrata en el suyo.

Los dos mecanismos siguen vivos y probados: hoy el primer piso que el gate cierra
es **corporativo** (lo destraba luxury), así que los tests se mudaron a ese par.
Si algún día se exime otro piso, hay que volver a correr el par un piso más
arriba.

## Lo que queda abierto

- **El ×24,61 de corporate es el peor tramo que queda.** Es mucho mejor que el
  ×367,88 que había y que el ×47,40 que la torre vieja tenía en luxury, pero
  sigue lejos de la banda de diseño. Está inflado por el denominador: el piso
  urbano se pasa en 2,4 min porque el callejón arranca a 50 (decisión 1 del
  HANDOFF). Achicarlo de verdad exige tocar esa decisión, así que no se tocó.
- **345 h contra las 196 h de la torre vieja.** El juego quedó ~1,8× más largo
  que antes del remapeo, con 7 tiers y 4 personajes por piso más. Es una decisión
  de producto pendiente: si el dueño quiere volver a ~196 h, el camino medido más
  limpio es la corrida 3 (gate + urbano a 50), que da 196,04 h — pero mueve el
  acantilado a luxury (×39) y re-litiga la decisión 2 del HANDOFF.

---

# Los packs de la tienda: por qué el ORO pago no toca el multiplicador (RF-02b, 2026-08-07)

No es una corrida de `pacing-sim`: es una decisión de monetización que **se tomó
para no tener que volver a correrlo**. Queda acá porque el que la quiera cambiar
tiene que saber contra qué choca.

## La decisión

**Comprar ORO acredita `meta.oro` y NO toca `meta.oroEarnedLifetime`.**

El multiplicador global se computa sobre `oroEarnedLifetime`, no sobre el
balance —así gastar ORO nunca nerfea—, así que la elección es exactamente si un
pack puede comprar multiplicador. No puede.

**Por qué**: la Ola 3 midió que `globalMultiplierPerOro` es el knob más peligroso
de esta economía. A 0,25 el colapso de ×1,00 vuelve entero (corridas 12–14 de la
tabla de arriba: 0,20 reabre island→moon, 0,25 y 0,35 lo empeoran). El valor
elegido, 0,18, tiene margen de menos de un tercio antes de romper la forma de la
curva. Un pack que inyectara `oroEarnedLifetime` movería ese knob por la puerta
de atrás y por una cantidad que decide el jugador con la tarjeta, no el balance.

Con la decisión tomada, el techo de lo que un pack puede hacer es **gastarse en
`upgrades.json`**, que tiene topes de nivel: acotado por construcción.

## La plata sí escala, y suma a `lifetimeEarnings`

Un pack de plata da `passiveUnlockCost(tier máximo alcanzado) × factor`, el mismo
idioma que el cofre de carrera (`coinChest`, `chestFactor` 6,0). Un monto fijo
envejece mal: a las veinte horas el pack más caro es basura.

Suma a `lifetimeEarnings` igual que el cofre, así que **sí genera ORO indirecto**
— por el camino largo y sublineal de la fórmula (exponente 0,45), no por inyección.

## Los factores, todos [TUNEABLE] en `products.json`

| Producto | Qué da | Precio |
|---|---|---|
| `starter_pack` | ×40 + quitar ads + skin `mundialista` | 4,99 |
| `coins_small` | ×15 | 0,99 |
| `coins_medium` | ×90 | 4,99 |
| `coins_large` | ×220 | 9,99 |
| `oro_small` | 250 ORO | 1,99 |
| `oro_medium` | 750 ORO | 4,99 |
| `oro_large` | 2.000 ORO | 9,99 |

Los montos de ORO se eligieron contra la tabla de arriba: la 1ª reencarnación da
14 ORO (1e9 de lifetime) y a 1e12 da 306, así que 250 es "varias reencarnaciones
tempranas" y 2.000 alcanza hasta bien entrado el juego. **No están medidos con el
simulador** —`pacing-sim` no modela compras— y ese es su límite conocido.

---

# `tierPremium`: precio de los tiers no-base (rediseño de UI, 2026-08-14)

La pantalla de laburos del rediseño vende **cualquier tipo desbloqueado**, no
sólo el tier base del piso visible. Eso abre una puerta que la torre nunca tuvo:
comprar el tier alto directo en vez de comprar dos del de abajo y mergearlos —o
sea saltear la mecánica central del juego con la billetera.

`hire.tierPremium` la cierra. La fórmula de contratación pasa a llevar un factor
`tierPremium^(tier − firstTier(piso))`, y el valor elegido es **1,8**.

## Por qué 1,8

El salto de precio por tier dentro de un piso queda en
`yieldGrowthPerTier × tierPremium = 2,8 × 1,8 ≈ **5,04×**`.

La regla que hay que cumplir es `costo(t+1) > 2 × costo(t)`: si subir un tier
costara menos que dos unidades del tier de abajo, comprar arriba sería el camino
óptimo y mergear pasaría a ser el camino de los que no leen los números.

- **Sin premium** el margen ya existía (2,8 > 2), pero es de apenas 1,4×: un
  tuneo futuro de `yieldGrowthPerTier` hacia abajo lo perfora sin que nadie se dé
  cuenta.
- **Con 1,8** el margen es 2,5×, o sea que comprar el tier alto cuesta como
  **cinco** del de abajo cuando mergear necesita dos. No conviene nunca, y el
  jugador lo ve en el precio sin tener que hacer la cuenta.
- Subirlo más volvería inalcanzables los tiers superiores de cada piso y la
  pantalla nueva mostraría tres cuartas partes de su catálogo como decoración.

**Para el tier BASE de cada piso el exponente es 0 y el premium vale 1**, así que
ningún precio de los que ya existían se movió: el primer Fisura sigue saliendo
50, el segundo 60, y la regla 600×/50× queda intacta. El premium sólo le pone
precio a lo que antes no se podía comprar.

También cambió **cuál contador alimenta la curva** en la cotización nueva: es
`run.hireCountsByType[typeId]` (por TIPO) y no `run.hireCounts[floorId]` (por
piso). Cada personaje tiene su propia curva del 20%, que es lo que la pantalla
muestra como "— N contratados". El contador por piso sigue vivo y sigue siendo el
exponente del botón viejo de la torre mientras los dos caminos convivan.

## La conducta del bot NO se movió (medido)

`PacingSimulator` migró a la cotización por tipo
(`TowerActions.hireQuote(typeId:)`, la misma función que usa el juego) en vez de
armar el precio por su cuenta con `config.hireCost`. Sigue comprando **el tier
base de cada piso**, que es donde el premium vale 1 — y comprar más arriba nunca
le conviene, que es justo lo que el premium garantiza.

`swift run pacing-sim` ANTES y DESPUÉS del cambio, mismos JSON, horizonte 90
días: **las dos salidas son idénticas byte a byte** (`diff` vacío).

| | antes | después |
|---|---|---|
| urban (activo / pared) | 2,4 min / 0,04 h | 2,4 min / 0,04 h |
| corporate | 60,2 min / 14,00 h | 60,2 min / 14,00 h |
| luxury | 382,7 min / 110,05 h | 382,7 min / 110,05 h |
| island | 467,4 min / 134,12 h | 467,4 min / 134,12 h |
| moon | 548,3 min / 158,14 h | 548,3 min / 158,14 h |
| mars | 636,9 min / 182,28 h | 636,9 min / 182,28 h |
| solar | 783,8 min / 230,06 h | 783,8 min / 230,06 h |
| galaxy | 1042,3 min / 312,04 h | 1042,3 min / 312,04 h |
| god_realm | 1176,8 min / 345,28 h | 1176,8 min / 345,28 h |
| reencarnaciones | 45 | 45 |
| 1ª reencarnación | 0,20 h | 0,20 h |
| dios (pared) | 345,28 h | 345,28 h |
| lifetimeEarnings final | 1,139e+40 | 1,139e+40 |

El semáforo de targets tampoco se movió: sigue con los mismos ❌ de diseño que
esta bitácora documenta desde F7.6 (los targets impresos son los del plan F7.1c,
no la conducta pineada — ver §F7.6).

⚠️ **Lo que esto NO mide**: `pacing-sim` compra sólo tiers base, así que **la
corrida de arriba no ejercita el premium en absoluto**. Es exactamente lo que se
quería demostrar —que la economía existente no se movió— pero significa que el
1,8 está justificado por la aritmética de la regla anti-atajo y no por una
medición de pacing. Cuando la pantalla de laburos exista y el bot pueda comprar
tiers no-base, hay que volver a correrlo.

## Cómo re-correr

```bash
cd Tools/pacing-sim && swift run pacing-sim \
  --economy ../../FisuEvolution/Resources/Data/economy.json \
  --tiers ../../FisuEvolution/Resources/Data/tiers.json
```

---

# El simulador vuelve a modelar al jugador — línea de base NUEVA (2026-08-21)

**Ningún knob de economía se movió en esta entrada.** `git diff` sobre
`FisuEvolution/Resources/` es vacío: `economy.json`, `upgrades.json` y
`tiers.json` están byte a byte como estaban. Todo lo que cambia abajo lo cambia
el **modelo del bot**, no la economía. Es la Task 1 del rebalance de pacing
(`Docs/superpowers/plans/2026-08-20-rebalance-pacing.md`), y existe porque
calibrar contra el bot viejo era tunear contra una ficción
(`Docs/PROMPT-rebalance-pacing.md` §2.2).

## Qué le faltaba al bot

1. **No compraba ninguna de las siete mejoras permanentes con ORO.** Todo
   `meta.derivedEffects` viajaba en cero durante la simulación entera: sin el
   `tap +5,0` ni el `income +3,0` que el jugador real tiene maxeados —de hecho
   maxearlas ES ganar—, sin `offline`, sin `spawnCostDiscount` y sin
   `prestigeBonus`.
2. **Tapeaba 3 veces por segundo**, el techo conservador que F2 le había
   heredado a `balance-sim`. Ahora tapea **6/s**, el medio del rango 5-8 que un
   humano sostiene en ráfaga.
3. **Al tap le faltaba un multiplicador**: `GameActions.applyTap` lleva
   `derivedEffects.incomeMultiplier` y el bot no. Con el bot viejo daba igual
   (valía 1 siempre); con mejoras compradas, no.

Y no publicaba **el número que el dueño pidió**: horas ACTIVAS hasta tener las
siete líneas al tope, o sea hasta las skins doradas.

## Las tres corridas, lado a lado

`--max-days 400`, mismos JSON. La del medio aísla cuánto pesa el tapeo solo.

| | modelo VIEJO (3 taps/s, sin mejoras) | sólo 6 taps/s | modelo NUEVO (6 taps/s + 7 mejoras) |
|---|---|---|---|
| urban (activo / pared) | 1,3 min / 0,02 h | 0,8 min / 0,01 h | 0,8 min / 0,01 h |
| corporate | 57,2 min / 9,29 h | 38,3 min / 4,31 h | 33,1 min / 4,22 h |
| luxury | 6260,1 min / 1876,00 h | 4880,1 min / 1464,00 h | 580,1 min / 172,00 h |
| island | 9420,1 min / 2822,00 h | 6940,1 min / 2078,00 h | 840,9 min / 249,01 h |
| moon | 10400,2 min / 3120,00 h | 7720,2 min / 2313,00 h | 1040,7 min / 312,01 h |
| mars | 10621,3 min / 3182,02 h | 7941,1 min / 2380,02 h | 1226,9 min / 364,11 h |
| solar | 11002,2 min / 3297,04 h | 8246,4 min / 2472,10 h | 1446,5 min / 432,11 h |
| galaxy | 11008,8 min / 3297,15 h | 8368,6 min / 2505,14 h | 1506,8 min / 446,11 h |
| god_realm | 11455,7 min / 3432,26 h | 8815,6 min / 2640,26 h | 1918,0 min / 566,30 h |
| **dios, en horas ACTIVAS** | **190,9 h** | 146,9 h | **32,0 h** |
| **las 7 al tope (activo)** | no lo medía | — (nunca compra) | **15,49 h** |
| las 7 al tope (pared) | — | — | 273,16 h |
| **reencarnaciones al maxear** | — | — | **34** |
| reencarnaciones totales | 47 | 50 | 52 |
| 1ª reencarnación (pared) | 0,17 h | 0,10 h | 0,10 h |
| lifetimeEarnings final | 4,740e+40 | 9,807e+40 | 3,320e+43 |

**El 191 h activas que citaba el prompt queda derogado.** La línea de base real,
contra la economía de hoy sin tocar, es la columna de la derecha.

## Lo que dice el número nuevo

- Maxear las siete cuesta **15,49 h ACTIVAS**. El objetivo del dueño son
  **20-30 h**: el juego está corto, que es exactamente la queja, y ahora hay un
  número con el que discutirlo. (Él lo ganó en 3 h; el bot es peor jugador que
  él, así que su 3 h y este 15,5 h son las dos puntas de la misma banda.)
- Se maxea con **34 reencarnaciones**, contra el techo de **8** que puso el
  dueño. La brecha bajó de ×12 (47 vs 3-4) a ×4, pero el defecto de fondo sigue
  vivo: reencarnar es un trámite barato y frecuente en vez de un hito.
- Dios queda a **32 h activas**, o sea **2× el costo de maxear**. La forma que
  el dueño pidió —"Dios más lejos que las skins"— ya está; lo que falta es la
  escala.
- El arco de arriba dejó de ser plano: los ratios activos de moon, mars y solar
  entran en la banda de diseño (×1,18-1,24) por primera vez desde la Ola 3, sin
  que nadie tocara un knob. Los ratios viejos ×1,02-1,10 eran del bot, no del
  juego.

## Lo que esto NO mide

- **Crit y golden siguen apagados**: el simulador es determinístico y no tira
  dados. El bot COMPRA las dos líneas (y las paga: `crit` es el 99,99 % del
  costo de ganar) pero no cobra su efecto. O sea que subestima al jugador real
  justo en la línea más cara — y por eso el 15,49 h es un techo, no un piso.
- **Los topes de `EffectCaps`** (crit 0,5 · offline 1,0 · golden 0,1 · spawn
  0,6) viven en el app target y el bot no los aplica. Con el catálogo de hoy
  ninguna línea los alcanza (offline llega a 0,85 y spawn a 0,30), así que el
  bot y el juego coinciden. **Si la Task 5 sube un `maxLevel` o una
  `magnitudePerLevel`, esto deja de ser cierto** y hay que pasarle los topes.
- **El atajo del HUD** (`QuickHireButton`) sigue sin modelarse. No hace falta
  todavía: el bot compra sólo el tier base de cada piso, que es justo la regla
  a la que la Task 2 va a acotar el atajo.
- **Eventos, logros y daily** siguen fuera del simulador, como siempre.

## Cómo re-correr

```bash
cd Tools/pacing-sim && swift run -c release pacing-sim \
  --economy ../../FisuEvolution/Resources/Data/economy.json \
  --tiers ../../FisuEvolution/Resources/Data/tiers.json \
  --max-days 400
```

Sin `--upgrades` el tool busca `Resources/Config/upgrades.json` solo y lo dice en
la primera línea de la salida; si no lo encuentra avisa fuerte que el bot está
corriendo el modelo viejo. La corrida de arriba está en
`Docs/balance-run-sim-arreglado.csv` (`--csv`).

---

# El rebalance de fondo: 20-30 h activas con 8 reencarnaciones (Task 5, 2026-08-21)

Es el corazón del rebalance de pacing
(`Docs/superpowers/plans/2026-08-20-rebalance-pacing.md`, Task 5). La línea de
base es la que dejó la Task 1 —el bot arreglado contra la economía sin tocar—,
no el 191 h derogado del prompt.

## Los tres números

`swift run -c release pacing-sim … --max-days 1500`, contra el árbol FINAL (con
la salida (a) que eligió el dueño — ver más abajo).

| | línea de base (Task 1) | después | objetivo del dueño |
|---|---|---|---|
| **maxear las 7 (activo)** | 15,49 h | **24,00 h** | 20-30 h ✅ |
| **reencarnaciones al maxear** | 34 | **8** | ≤ 8 ✅ |
| **Dios (activo)** | 32,0 h | **26,59 h** | más lejos que maxear ✅ |
| Dios (pared) | 566,30 h | 470,26 h | — |
| reencarnaciones totales | 52 | 9 | — |
| 1ª reencarnación (activo) | 0,17 h | 3,67 h | — |
| lifetimeEarnings final | 3,320e+43 | 2,440e+26 | — |

Dios queda ×1,11 más lejos que maxear en horas activas. La cadencia de las
reencarnaciones, en horas ACTIVAS de cada una:

```
antes:   0,2 · 0,3 · 0,6 · 0,7 · 1,0 · 1,2 · 1,3 · 1,5 · 1,7 · 1,8 · 2,0 · 2,1 · …  (52)
después: 3,7 · 8,0 · 12,7 · 16,4 · 19,3 · 21,2 · 22,9 · 24,0 · 25,3                 (9)
```

O sea: de una cada seis minutos a una cada 2-4 h activas, que es lo que el dueño
pidió ("cada una un hito que se prepara y se nota"). El CSV está en
`Docs/balance-run-t5-rebalance.csv`.

## Los cinco knobs, uno por vez

| knob | antes | después | qué movió (medido, sólo ese knob) |
|---|---|---|---|
| `tapFloorMultiplierExponent` | — (=1) | **0** | maxear 15,49 → **24,67 h**; el click del tier alto deja de financiar el piso siguiente |
| `EconomyConfig.hireCost`: el factor de piso | `floor.incomeMultiplier` | **`tapFloorMultiplier(for:)`** | contratar el tier base vuelve a costar **600 clicks** en los diez pisos (con el crudo eran 372.000 en el reino divino) |
| `hire.defaultCostGrowth` | 1,2 | **1,06** | **decide si la torre es escalable**: con 1,2 la run se traba en el tier 11 y la partida no se termina |
| `oro.divisor` · `oro.exponent` | 3e6 · 0,45 | **3e12 · 0,25** | **cierra la divergencia costos-vs-ingresos**: entrar a luxury pasa de 0,0 s a 100,0 s de income. Y la 1ª reencarnación de 0,17 a 3,67 h activas |
| `upgrades.json` | crit = 99,99 % | 7 líneas de 21-37 ORO | 34 → **8** reencarnaciones |

⚠️ **Corrección (fix round 1).** La primera versión de esta tabla le atribuía a
`hire.defaultCostGrowth` el "0,0 s → 720 s" y acreditaba a `oro.divisor` sólo con
la primera reencarnación. Las dos cosas estaban mal y la aritmética de más abajo
las desmiente: **la divergencia la cierra la curva de ORO** y **el growth decide
otra cosa —si la torre se puede subir—**. Están separadas arriba porque la tabla
resumen es lo que se lee primero.

## Piso por piso, antes y después

⚠️ **Corrección (fix round 1 del review).** La primera versión de esta entrada
publicaba una sola columna de costo y se la atribuía a `hire.defaultCostGrowth`.
Estaba mal por dos motivos, y los dos los encontró el review:

1. La métrica cotizaba el hire con `purchases: 0`, y `growth^0 = 1`: era
   **matemáticamente ciega al knob que decía estar midiendo**.
2. La columna "antes" venía de una corrida con el tap cobrando el ×620 del piso
   y la "después" sin él, así que los dos denominadores eran distintos.

Ahora hay DOS series, cotizadas al contador de compras real, y cada comparación
mueve **un solo knob** con el tap tratado igual en las dos columnas.

### Serie 1 — entrar a un piso (su tier base, en segundos de income)

Mide la divergencia costos-vs-ingresos, y **la explica la curva de ORO**, no el
`defaultCostGrowth`. A/B con `growth` fijo en 1,06 y `tapFloorMultiplierExponent`
en 0 en las dos columnas; lo único que cambia es `oro`:

| piso | ORO 3e6 / 0,45 (vieja) | ORO 3e11 / 0,25 (nueva) |
|---|---:|---:|
| urban | 200,0 s | 200,0 s |
| corporate | 419,7 s | 419,7 s |
| luxury | **0,0 s** | 720,1 s |
| island | 0,0 s | 823,6 s |
| moon | 0,0 s | 270,1 s |
| mars | 0,0 s | 8,0 s |
| solar | 0,0 s | 4,2 s |
| galaxy | 0,0 s | 9,8 s |
| god_realm | 0,0 s | 0,9 s |

Con la curva vieja el multiplicador se desborda y del cuarto piso en adelante
entrar es literalmente gratis; con la nueva sigue costando plata hasta galaxy.
**El arreglo de la divergencia es la curva de ORO.**

### Serie 2 — el compounding (pico de compras del mismo tipo · la siguiente)

Ésta sí ve `hire.defaultCostGrowth`. A/B con todo lo demás igual —misma curva de
ORO nueva, mismo catálogo, tap en 0 en las dos— y sólo el growth cambiando:

| piso | growth 1,2 | growth 1,06 |
|---|---|---|
| urban | 15 compras · 1,0 s | 15 compras · 0,2 s |
| corporate | 70 compras · **384,0 s** | 144 compras · 4,9 s |
| luxury | **nunca se abre** | 381 compras · 66.586 s |
| island | — | 459 compras · 58.331 s |
| moon | — | 553 compras · 36.161 s |
| mars | — | 620 compras · 420,9 s |
| solar | — | 776 compras · 15.105 s |
| galaxy | — | 787 compras · 539,1 s |
| god_realm | — | 870 compras · 47,5 s |
| **maxear las 7** | **nunca** (maxTier 11, las siete en 1/10) | 25,33 h activas |
| reencarnaciones | 4 (cadencia 2,3 · 17,0 · 177,3 · 986,7 h) | 11 |

Con el 20 % por compra la partida **no se puede terminar**. Con el 6 % la misma
economía se juega entera. El growth no explica la serie de entrada: explica **si
la torre es escalable**.

## Lo que se descartó, con su número

**(a) Que los costos escalen con el multiplicador (`M^0,8`), la opción que el
prompt llamaba "el arreglo estándar de los idle": DESCARTADA, medida.** En esta
torre la profundidad se COMPRA con el multiplicador: cada tier extra cuesta un
factor entero de `yieldGrowthPerTier`, así que `ΔT = (1−k)·log(M)/log(2,8)`. Con
k = 0,8 el multiplicador efectivo de los ×3,6e15 que hoy hacen falta para Dios
queda en ×1000, y está medido que con multiplicadores de ese orden el bot se
traba en el tier 12: la corrida `divisor 3e10 / perOro 0,18` hace 22
reencarnaciones (multiplicador ≈ 7,5e5) y termina en **T12**. O sea que anclar
los precios al multiplicador vuelve la torre inescalable y Dios inalcanzable.

**(b) Aplanar sólo el ORO, dejando la relación costo/ingreso como estaba: es la
trampa que este documento ya documentó una vez, y ahora tiene número.** Con
`defaultCostGrowth` en 1,2 y sólo el ORO tocado, el mejor punto encontrado es
`divisor 2e10 / exponente 0,45`: maxear 29,67 h ✅, pero **9** reencarnaciones,
Dios a **915,82 h activas** (×31 más lejos que maxear: contenido muerto) y la
serie de costos sigue en 200 / 419 / **0,0** / 0,0 / … O sea: pasa el titular y
deja el defecto intacto, que es exactamente lo que el prompt advertía.

**(c) Techo blando con rendimientos decrecientes sobre el multiplicador: no se
implementó** — es una variante de (b) (acota la velocidad del desborde, no lo
cierra) y habría agregado una fórmula nueva sin resolver lo que (b) no resuelve.

**La salida elegida son DOS knobs con dos efectos distintos**, y la primera
versión de esta entrada los había fundido en uno:

- **La curva de ORO (`divisor` 3e6 → 3e11, `exponent` 0,45 → 0,25) cierra la
  divergencia**: acota la escala del multiplicador global y con eso entrar a un
  piso vuelve a costar segundos de income en vez de cero (serie 1).
- **`hire.defaultCostGrowth` (1,2 → 1,06) hace la torre escalable** con un
  multiplicador acotado. Con el 20 % por compra y el ORO ya escaso, la partida
  no se termina: el bot se traba en el tier 11 (serie 2).

⚠️ **Corrección del enunciado (fix round 1).** Esta entrada decía que el gate
obliga a "~256 contrataciones del mismo tipo por piso cruzado" y que
`1,2^256 ≈ 4e20` era LA causa. Dos cosas mal:

- el número es `1,2^256 = 1,86e20` (y `1,06^256 = 3,0e6`), no 4e20;
- **256 es aritmética de la política del BOT, no del juego.** El bot compra
  siempre el tier base; un jugador real tiene FisuJobs, que vende los cuatro
  tipos del piso con un contador por tipo, y con growth 1,2 el tier de arriba
  se vuelve más barato **por unidad de yield** en cuanto `growth^n > tierPremium`,
  o sea `n = ln(1,8)/ln(1,2) = 3,22` compras hechas — entre la 4ª y la 5ª. Nadie
  llega a 256 del mismo tipo jugando.

Lo MEDIDO —y es lo que sostiene el cambio— es el pico real del bot: **70 compras
del mismo tipo al abrir corporativo, donde la siguiente ya cuesta 384 s de
income**, y ahí se traba. Con 1,06 la compra 144 cuesta 4,9 s. La dirección se
sostiene; la magnitud del argumento estaba inflada.

⚠️ **Esto toca la regla de precios del dueño** (2026-08-04: "600× y cada compra
sube el precio 20%"). El **primer Fisura sigue costando 25** —decisión cerrada,
no se movió— y `defaultCostMultiplier` sigue en **600**; lo que cambia es la
PENDIENTE de la curva: el segundo Fisura pasa de 30 a 26,5. **Necesita la
confirmación del dueño.**

## La regla de precios del dueño: las tres salidas, y cuál eligió

La regla (2026-08-04) es: **"el tier base de un piso superior cuesta 600 veces lo
que rinde un click suyo ahí"**. El rebalance la rompió **en significado, no sólo
en pendiente**, y la primera versión de esta entrada no lo declaró.

El motivo: `tapFloorMultiplierExponent: 0` le sacó al TAP el `incomeMultiplier`
del piso, pero el PRECIO lo seguía llevando crudo. Los dos habían quedado atados
por casualidad, no por construcción. Con las dos puntas sueltas:

| piso | `incomeMultiplier` | contratar el tier base, en clicks |
|---|---:|---:|
| alley | 1 | 600 |
| corporate | 4,2 | 2.520 |
| luxury | 8,5 | 5.100 |
| **god_realm** | **620** | **372.000** |

El test que debía protegerlo seguía verde porque **replicaba la fórmula VIEJA del
click**: exactamente "un test que cambió de significado y quedó verde".

### Las tres salidas, cada una corrida entera

| | maxear las 7 | reenc | Dios (activo) | la regla | serie de entrada (s de income) |
|---|---|---|---|---|---|
| **(a)** el precio usa el mismo factor de piso que el click (`tapFloorMultiplier`) + `oro.divisor` 3e12 | **24,00 h** ✅ | **8** ✅ | **26,59 h** ✅ | **vale literal**: 600 clicks en los diez pisos, para cualquier exponente futuro | 100 · 99,8 · 100,0 · 73,5 · 48,2 · 4,8 · 1,5 · 0,1 · 0,0 |
| **(b)** devolverle al tap el multiplicador de piso (exponente 1) | 15,26 h ❌ | 9 ❌ | 20,32 h | vale como siempre | 100 · 100 · 84,7 · 48,4 · 9,2 · 0,1 · 0,0 · 0,0 · 0,0 |
| **(c)** dejarlo y re-enunciar la regla | 25,33 h ✅ | 8 ✅ | 30,33 h ✅ | **cambia de significado**: 600 × `incomeMultiplier` clicks | 200 · 419,7 · 720,1 · 823,6 · 270,1 · 8,0 · 4,2 · 9,8 · 0,9 |

(a) sin el bump de divisor daba 19,00 h; con `oro.divisor` en 3e12 entra en banda.
(b) falla dos de los tres targets y necesitaría otro lever.

### 👉 El dueño eligió (a)

`EconomyConfig.hireCost` pasa a multiplicar por `tapFloorMultiplier(for: floor)`
en vez de `floor.incomeMultiplier`. Las dos puntas quedan atadas **por
construcción**: si mañana el exponente del tap cambia, el precio lo sigue solo y
la regla del dueño no se puede romper en silencio. El costo medido es 1,3 h de
largo (25,33 → 24,00) y una serie de entrada que se apaga un piso antes.

Lo pinea `hirePricesFollowTheOwnersRule`, que ahora mide **en clicks** —con el
mismo `tapFloorMultiplier` que cobra `applyTap`, no una copia de la fórmula— y
asserta 600 en los diez pisos.

## Las siete líneas

`crit` costaba 1,776e10 de un total de 1,778e10: **99,99 %**. Ahora:

| línea | niveles | magnitud/nivel | baseCost | growth | costo total | % del total |
|---|---:|---:|---:|---:|---:|---:|
| income | 10 | 0,2 | 1 | 1,10 | 21 | 10,9 % |
| tap | 10 | 0,5 | 1 | 1,10 | 21 | 10,9 % |
| offline | 10 | 0,05 | 1 | 1,15 | 26 | 13,5 % |
| spawn | 10 | 0,03 | 1 | 1,15 | 26 | 13,5 % |
| crit | 10 | 0,025 | 1 | 1,20 | 31 | 16,1 % |
| golden | 10 | 0,005 | 1 | 1,20 | 31 | 16,1 % |
| prestige | 10 | 0,005 | 1 | 1,25 | 37 | 19,2 % |

**Total 193 ORO** contra 1,778e10. La más cara cuesta 1,76× la más barata en vez
de 8.000.000×.

Los **efectos totales al tope no se movieron ni un decimal** (income +2,0 · tap
+5,0 · crit 0,25 · offline +0,50 · golden 0,05 · spawn 0,30 · prestige 0,05):
los niveles se dividieron por 2 (por 2,5 en crit) y las magnitudes se
multiplicaron por lo mismo. Es la verificación del **riesgo del ledger**:
ninguna línea se acerca más que antes a su `EffectCaps` (crit 0,25 de 0,5 ·
offline 0,85 de 1,0 · golden 0,05 de 0,1 · spawn 0,30 de 0,6), así que el espejo
de EconomyKit —que no clampea— y el juego —que sí— siguen coincidiendo. Lo
vigila el test nuevo `upgradeLinesNeverReachTheirEffectCaps`.

**Por qué 193 y no otro número**: el bot reencarna cuando DUPLICA su ORO
histórico, así que las reencarnaciones para maxear son `log₂(costo total)`.
`log₂(1,778e10) = 34,05` y el simulador medía **34** — exacto. `log₂(193) =
7,59` y mide **8**. Cualquier catálogo por encima de ~450 ORO totales rompe el
techo de 8.

## ¿Cuándo conviene reencarnar? (el criterio de aceptación de §4.2)

Medido con `--prestige-threshold N`, el knob nuevo del simulador: el bot
reencarna cuando el ORO por reencarnar supera N veces su histórico. Misma
economía en cada columna; lo único que cambia es la política del jugador.

| política | antes: maxear / reenc | después: maxear / reenc |
|---|---|---|
| ×1 (duplicar — el default) | 15,49 h / 34 | 25,33 h / 8 |
| ×2 | 14,18 h / 22 | 20,67 h / 6 |
| ×4 | — | 19,67 h / 5 |
| ×8 | **13,09 h / 12** | **17,90 h / 4** |
| ×30 | 21,40 h / 8 | 17,67 h / 3 |
| ×1000 (contra la pared) | 864,97 h / 5 | 24,00 h / 2 |

**El óptimo del jugador pasó de 12 reencarnaciones con la primera a los 0,1 h
activas —seis minutos, y 8 de las 12 dentro de las dos primeras horas: un
trámite— a 4 reencarnaciones con la primera a las 2,0 h activas**, que es
exactamente lo que hizo el dueño ("yo cuando gané el juego reencarné 3 o 4 veces
nada más").

Cadencia del bot por defecto, en horas ACTIVAS de cada reencarnación:

```
antes:    0,2 · 0,3 · 0,6 · 0,7 · 1,0 · 1,2 · 1,3 · 1,5 · 1,7 · 1,8 · 2,0 · 2,1 · …  (52 en total)
después:  2,0 · 6,9 · 12,0 · 16,7 · 20,0 · 22,7 · 24,0 · 25,3                        (8 al maxear)
```

Los huecos de la serie nueva se ACORTAN de 4,9 h a 1,3 h: cada reencarnación
hace que la siguiente llegue antes, o sea que el multiplicador que te llevás
paga el re-ascenso con ganancia. Los de la serie vieja eran de 0,1-0,3 h de
punta a punta: reencarnar no cambiaba nada.

Y el valor de la PRIMERA: antes 1 ORO sobre 1,778e10 = **6e-9 %** de la
condición de victoria. Ahora 1 ORO sobre 193 = **0,5 %**, y compra un nivel
entero de income (+20 % permanente).

⚠️ **Honestidad sobre este punto**: el óptimo medido no es "reencarnar
apenas podés" sino "cada ×4-×8", o sea 4-5 veces repartidas en la run. Es la
conducta que el dueño describió como propia y entra en el techo de 8, pero el
bot que reencarna en cuanto duplica sigue tardando 25,33 h contra las 17,90 h
del que espera un poco. Reencarnar temprano ya no es una trampa (contra la
pared costaba 864,97 h y ahora cuesta 24,00 h), pero tampoco es estrictamente
lo óptimo.

## El tap del tier alto

`tapFloorMultiplierExponent` separa la curva del tap de la del pasivo por el
único factor que crece con la ALTURA de la torre: el `incomeMultiplier` del piso
(1 → 620). Con 0 el tap cobra el tier pelado y el pasivo lo sigue cobrando
entero. **El early game no se mueve ni un peso**: en el callejón el
multiplicador es 1 y 1^x = 1 para cualquier exponente, así que el tutorial y el
primer Fisura a 25 quedan idénticos.

| exponente | maxear las 7 | Dios (activo) |
|---|---|---|
| ausente (= 1, la conducta vieja) | 15,49 h | 31,97 h |
| 0,5 | 18,98 h | 31,25 h |
| 0,25 | 23,00 h | 37,30 h |
| **0 (elegido)** | **24,67 h** | 37,64 h |

## Cómo re-correr

```bash
cd Tools/pacing-sim && swift run -c release pacing-sim \
  --economy ../../FisuEvolution/Resources/Data/economy.json \
  --tiers ../../FisuEvolution/Resources/Data/tiers.json \
  --upgrades ../../FisuEvolution/Resources/Config/upgrades.json \
  --max-days 1200 [--prestige-threshold N]
```

## Lo que este rebalance ROMPIÓ y hay que arreglar antes de cerrar

🔴 **Los 12 logros de ORO fijo regalan 620 ORO y maxear las siete cuesta 193.**
`achievements.json` paga ORO fijo en 12 logros (120 · 100 · 80 · 60 · 60 · …),
620 en total. Contra el catálogo viejo de 1,778e10 eran polvo; contra el nuevo
son **3,2× la condición de victoria entera** — o sea que un jugador maxea las
siete líneas sólo con logros. El simulador no modela logros, así que las
mediciones de arriba no están contaminadas, pero el juego sí. Es la Task 3.4 del
plan ("los 12 logros de ORO fijo se re-miran DESPUÉS de la Task 5") y con estos
números deja de ser opcional.

⚠️ **El horizonte importa**: el bot juega 80 min por día, así que 400 días son
sólo 533 h ACTIVAS. Varias corridas de este barrido decían "dios —" y en
realidad era el horizonte, no la economía: con `--max-days 3000` la misma
configuración llegaba a Dios a las 743 h activas. Cualquier conclusión de "no
llega" hay que verificarla con horizonte largo antes de escribirla.
