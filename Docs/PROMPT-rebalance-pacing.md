# PROMPT — Rebalance del pacing: que ganarlo al máximo cueste 20-30 h

> **Para el agente que lo tome**: esto es un pedido del dueño con investigación
> ya hecha (2026-08-20). Los números de abajo están MEDIDOS, no estimados, y
> cada uno dice con qué comando se reprodujo. Antes de tocar un knob, leé
> `Docs/HANDOFF.md` (§0 protocolo, §5 decisiones que no se re-litigan, §6 cómo
> verificar, §7 trampas) y `Docs/balance-log.md` completo — esa bitácora es la
> memoria de cinco calibraciones y documenta knobs que hacen lo CONTRARIO de lo
> que parece.

---

## 1. Lo que pidió el dueño, textual

> "siento que el pacing del juego es muy rapido. en total me lo gane en 3 horas
> (consegui las skins doradas, por lo que tuve que maxear todos los upgrades) y
> es un tiempo muy corto para llegar a esa instancia. los multiplicadores estan
> mal al reencarnar. tambien llega un punto en donde la cantidad de oro que te
> da es tanta que es muy facil ganarse todo el juego."
>
> "hace que el shortcut de comprar personaje en la ui solo te deje comprar al
> personaje inicial de cada piso, para fomentar mas el merging. mantene que se
> pueda comprar todos los personajes desbloqueados desde fisujobs."
>
> "tambien siento que los personajes mas altos dan mucha plata al clickearlos,
> si te pones un minuto entero a clickear ganas mucha plata que te permite subir
> de piso o comprar muchos upgrades rapidamente haciendo que se progrese muy
> rapido."
>
> "deberias dedicarle 20/30hs para ganarlo al maximo."

**El objetivo, hecho métrica** (confirmado por el dueño, ver §7):

1. Maxear las **siete líneas permanentes** —lo que desbloquea las skins de oro y
   lo que él llama "ganarlo al máximo"— cuesta **20-30 horas de juego ACTIVO**
   (dedo en la pantalla, no calendario). Hoy cuesta **3 h activas**, medidas
   jugando.
2. Llegar a **Dios (tier 37)** queda **más lejos todavía**: es el viaje del que
   sigue jugando después de ganar, no el mismo hito.
3. Ese recorrido entero se hace con **8 reencarnaciones COMO MÁXIMO**. El dueño
   ganó el juego con **3 o 4**; el simulador hace **47**. O sea: una
   reencarnación cada 2,5-4 h de juego activo, cada una un hito que se prepara y
   se nota — no una rutina.
4. El **offline se queda como está** (35 %, tope 10 h) o incluso más generoso:
   sirve para volver y encontrar plata, no para ganar durmiendo. Las 20-30 h son
   de juego activo y el idle no las paga.

---

## 2. El estado real, medido hoy (esto es lo que hay que arreglar)

### 2.1 El guardián del pacing está EN ROJO y hace dos días que nadie lo mira

`FisuEvolutionTests/PacingTests.swift` — **3 de 4 tests fallan** en el árbol
actual (`2b3d23f`):

```
✘ la fase fisura dura 1.7-3.1 min activos      → mide 1.3 min
✘ el gradiente del arco pre-prestigio          → island nunca se desbloquea (nil)
✔ la 1ª reencarnación cae entre 0.05 y 0.25 h
✘ dios llega entre 242 y 449 h de pared        → godWall = nil (maxTier final: 12)
```

En 90 días simulados el bot **ni siquiera sale de corporativo**. Reproducir:

```bash
xcodebuild test -project FisuEvolution.xcodeproj -scheme FisuEvolution \
  -destination "platform=iOS Simulator,id=<UDID>" \
  -only-testing:FisuEvolutionTests/PacingTests -parallel-testing-enabled NO
```

**Cuándo se rompió**: entre `4ba35db` (2026-08-17, última corrida verde
documentada: unit 381/381) y hoy se movieron **exactamente dos knobs**:

| Knob | Cambio | Quién |
|---|---|---|
| `charUpgrades.maxLevel` | no existía → **20** | sesión del dueño, 2026-08-19 |
| `floors[alley].hireCostMultiplier` | 50 → **25** | pedido del dueño, 2026-08-19 |

El tope de 20 le sacó al bot su motor de late game (las mejoras por personaje
eran un exponencial sin techo), y el sim pasó de **345 h a 3432 h** de pared.

### 2.2 El simulador ya no modela al jugador real — y por eso mide cualquier cosa

Corrida de hoy (`swift run -c release pacing-sim --economy … --tiers … --max-days 400`,
log completo en la bitácora que escribas):

```
dios: 3432.26 h de pared · 11455 min ACTIVOS (=191 h) · 47 reencarnaciones
lifetimeEarnings final: 4.74e+40
ratios activos: corporate ×42.9 · luxury ×109.4 · island ×1.5 · resto ~×1.0
```

El sim dice **191 h activas**; el dueño lo ganó en **3 h activas**. La brecha es
de ×60 y **no es un misterio, es el modelo del bot**. `PacingSimulator.nextAction`
sólo compra: passive unlocks con payback < 30 min, char upgrades con payback
< 30 min, y contrataciones del **tier base** del piso. O sea:

1. **El bot NUNCA compra las siete mejoras permanentes con ORO.** Todo
   `derivedEffects` queda en cero durante la simulación entera: sin `income`
   (+0,1/nivel ×20 = **+2,0**), sin `tap` (+0,25/nivel ×20 = **+5,0**), sin
   `crit`, sin `golden`, sin `offline`, sin `prestigeBonus`, sin
   `spawnCostDiscount`. El jugador real las maxea — de hecho maxearlas ES ganar.
2. **El bot no conoce el atajo de contratación del HUD** (`QuickHireButton` →
   `GameState.bestHire`), que vende el tier MÁS ALTO pagable y por lo tanto
   saltea profundidad de merge. Ese atajo se agregó el 2026-08-17, **después**
   de la última calibración: es una aceleración que nadie midió. (Y el dueño ya
   pidió acotarlo — ver §4.5.)
3. **El bot tapea 3 veces por segundo, 80 min por día.** Un jugador real tapea
   más rápido, en ráfagas, y siempre sobre el tier más alto.
4. El bot reencarna sólo cuando el ORO ganado **duplica** el histórico. Un
   jugador que persigue las skins doradas reencarna mucho más seguido.

⚠️ **Consecuencia de método, y es la más importante de todo este documento:**
recalibrar knobs contra el simulador tal como está hoy es tunear contra una
ficción. **El primer trabajo es arreglar el instrumento**, no la economía.

### 2.3 El defecto estructural: los costos son absolutos, los ingresos son multiplicados

Esto es lo que hay detrás de "llega un punto en donde es muy fácil ganarse todo
el juego", y es de arquitectura, no de calibración.

**Todo lo que se compra** está anclado a `tapYield(tier)`, que es una constante
de la config (`EconomyConfig.hireCost`, `StandardEconomy.passiveUnlockCost`,
`CharUpgrades.nextLevelCost`):

```
hire       = hireCostMultiplier(piso) × tapYield(tier) × tierPremium^(tier−firstTier) × growth^compras
passive    = 60 × tapYield(tier)
charUpgrade= 50 × tapYield(tier) × 4^nivel
```

**Todo lo que se gana** pasa por multiplicadores sin techo
(`GameActions.applyTap`, `IncomeTicker.passivePerSecond`):

```
tap = tapYield(tier) × charUpgrades(2^nivel, tope 2^20 = 1.048.576)
                     × floors[].incomeMultiplier (1 → 620)
                     × derivedEffects.tap (hasta ×6) × derivedEffects.income (hasta ×3)
                     × meta.globalMultiplier  ← 1 + oro × 0,18, SIN TECHO
```

Ninguna fórmula de costo ve `globalMultiplier`. Medido:

| lifetimeEarnings | ORO | multiplicador global | un tap T37 paga… |
|---|---|---|---|
| 1e12 | 306 | ×56 | 58 contrataciones del tier 37 |
| 1e20 | 1,2e6 | ×2,2e5 | 227.000 contrataciones |
| **1,8e29** (maxear todo) | **1,8e10** | **×3,2e9** | **3.310 millones** |
| 4,7e40 (fin del contenido) | 1,3e15 | ×2,3e14 | 2,4e14 |

Un solo click al tier más alto, con el multiplicador que tenés cuando maxeaste,
paga **más de tres mil millones** de contrataciones del personaje más caro del
juego. Eso es exactamente la queja del dueño sobre los clicks, y la del oro: son
el mismo defecto visto desde dos lados.

### 2.4 La condición de victoria está dominada por UNA línea

Maxear las siete cuesta **1,78e10 de ORO**, y el reparto es absurdo
(`FisuEvolution/Resources/Config/upgrades.json`):

| línea | costo de maxearla | % del total |
|---|---:|---:|
| **crit** (base 3, growth 2,5, 25 niveles) | **1,776e10** | **99,99 %** |
| prestige | 147.620 | 0,0008 % |
| golden | 48.443 | — |
| income | 1.048.575 | 0,006 % |
| tap | 1.048.575 | 0,006 % |
| offline | 6.372 | — |
| spawn | 2.212 | — |

Seis de las siete líneas son gratis al lado de `crit`. "Maxear todo" es, en la
práctica, "maxear crit" — y como el ORO crece con `earnings^0,45` sin techo, el
muro de crit se atraviesa de golpe cuando las ganancias explotan.

### 2.5 Mapa de knobs (todo es data-driven; el código no tiene números mágicos)

`FisuEvolution/Resources/Data/economy.json`:

```
baseTapYieldTier1: 1 · yieldGrowthPerTier: 2.8   → tapYield(T37) = 1,25e16
passiveRatio: 0.5 · passiveUnlockCostMultiplier: 60
hire: { defaultCostMultiplier: 600, defaultCostGrowth: 1.2, tierPremium: 1.8 }
charUpgrades: { baseCostMultiplier: 50, costGrowth: 4.0, effectFactorPerLevel: 2.0, maxLevel: 20 }
oro: { divisor: 3e6, exponent: 0.45, globalMultiplierPerOro: 0.18 }   ← multiplicador LINEAL en oro
offlineEfficiencyBase: 0.35 · offlineCapHours: 10
floors[]: incomeMultiplier 1 → 2 → 4,2 → 8,5 → 17 → 35 → 72 → 150 → 305 → 620  (≈×2 por piso)
          alley hireCostMultiplier 25 · urban hireGateExempt: true · resto 600
```

`FisuEvolution/Resources/Config/upgrades.json`: las 7 líneas de arriba.
`FisuEvolution/Resources/Data/tiers.json`: 37 tiers en 10 pisos, 10 slots por piso.

### 2.6 Por qué el jugador reencarna 3 veces y no 47: reencarnar NO CONVIENE

Observación del dueño, y es el mecanismo que faltaba para explicar todo lo demás:

> "como es muy facil avanzar en el juego (mergear y clickear y comprar mas
> personajes), casi nunca es worth reencarnar hasta estar muy avanzado en la
> partida. de manera que te da un monton de oro ya que tenes muchisimos earnings."

Reencarnar cuesta **la run entera** (`run = .fresh(...)`: unidades, pisos,
passives y char upgrades mueren) y paga **`1 + oro × 0,18`**. Como subir es
barato y rápido —merge + click + comprar el tier alto por el atajo del HUD—,
volver a empezar es pura pérdida hasta que la run se choca contra una pared. Y
cuando eso pasa, `lifetimeEarnings` ya es astronómico y `oro = (earnings/3e6)^0,45`
entrega una montaña de una sola vez.

O sea: **el prestigio no es una decisión, es un trámite de final de partida**. Las
dos quejas del dueño —"los multiplicadores al reencarnar están mal" y "el oro que
da es tanto que es muy fácil ganar"— son este defecto visto desde los dos lados,
y explican por qué él hizo 3-4 reencarnaciones donde el bot hace 47: el bot
reencarna cuando DUPLICA el oro histórico (regla de sim), el humano cuando ya no
le queda otra.

⚠️ Esto sube el listón de §4.2: no alcanza con aplanar el ORO. Hay que hacer que
reencarnar **convenga temprano** —que el multiplicador de UNA reencarnación pague
el re-ascenso— y que la run tenga un techo que se sienta antes. Si después del
rebalance sigue sin convenir hasta el final, el jugador va a seguir haciendo 3
reencarnaciones gigantes y el problema queda igual con otros números.

### 2.7 Dos fuentes de plata que nadie calibró contra el progreso

**Los logros pagan un múltiplo de un COSTO, no de lo que producís.**
`GameState+Achievements.swift:262` da
`passiveUnlockCost(tierDeReferencia) × factor` = `60 × tapYield(tier) × factor`,
con factores de 2 a 40 repartidos en 27 logros de monedas (los otros 12 dan ORO
fijo, 20-120). Ese ancla no ve el `globalMultiplier` ni las char upgrades ni el
multiplicador de piso, así que el premio **no guarda relación con la plata que
tenés en ese momento**: es un lingote temprano y es polvo tarde.

Lo pidió el dueño así: *"los achievements te dan bastante plata. hace que sea mas
acorde a la cantidad de plata que podes tener en el momento en el que ganaste"*.

**Y el juego ya tiene la fórmula correcta, a dos archivos de distancia**: el
evento Aguinaldo (`ContentSystems.swift:201`) paga
`IncomeTicker.passivePerSecond(...) × magnitude`, o sea **segundos de tu producción
actual**. Ese es el molde para los 27 logros de monedas — con el número de
segundos calibrado, no heredado (hoy el aguinaldo regala 900 s = 15 minutos de
producción, que también hay que mirar).

**Los banners de evento aparecen cada 2 a 8 minutos.**
`events.json`: `baseIntervalSeconds: 300`, `intervalJitterSeconds: 180`, 8 eventos
con cooldowns de 900-3600 s. En una partida de 3 h eso son ~35 apariciones. Y los
que más pesan son los que aceleran: `plan_platita` (peso 20, **×5 de income** por
60 s), `inversion_alienigena` (**×10** por 30 s), `aguinaldo` (peso 12, 15 min de
producción de regalo), `blanqueo` (un personaje gratis N tiers por encima del tuyo — su `magnitude` es ese OFFSET, no una cantidad).

Queja del dueño: *"lo mismo con los banners (tipo plan platita, o app payment
down). aparecen muy seguido"*. Los knobs son `baseIntervalSeconds`, el jitter, el
`weight` y el `cooldownSeconds` de cada evento, y sus `magnitude`/`durationSeconds`.
Ojo: los eventos también son el color del juego (el humor argentino vive ahí), así
que la respuesta no es apagarlos sino espaciarlos y dosificar los que regalan.

---

## 3. Lo que NO se toca (decisiones cerradas del dueño — `HANDOFF.md` §5)

- **La profundidad del gate de contratación sigue siendo de UN piso.** Con dos,
  el juego deja de poder terminarse (medido: el bot se traba en tier 12). La
  COBERTURA (`hireGateExempt` del urbano) sí es tuneable.
- **El primer Fisura cuesta 25** y `hire.defaultCostMultiplier` es 600 salvo que
  el rebalance demuestre con números que hay que moverlos — y si los movés,
  pedile al dueño que lo confirme antes de commitear.
- **La torre es de 37 tiers en 10 pisos con 10 slots.** El rebalance es de
  curvas, no de contenido.
- **FisuJobs sigue vendiendo todos los personajes desbloqueados.** Lo único que
  se acota es el atajo del HUD (§4.5).
- Ojo con la intuición: esta bitácora ya documentó dos veces que **subir un
  precio ACORTÓ el juego** (300→600 lo bajó de 264 h a 196 h). Ningún knob se
  mueve sin correr el simulador antes y después.

---

## 4. El trabajo, en orden obligatorio

### 4.1 PRIMERO: que el simulador modele al jugador real

Sin esto, todo lo demás es tunear a ciegas. En `PacingSimulator`:

- **Comprar las siete mejoras permanentes con ORO** con una política explícita y
  documentada (la del jugador que persigue las skins doradas: comprar la más
  barata disponible mientras el ORO alcance, o la de mejor payback — elegí una,
  justificála en el docstring, y dejá el knob a la vista).
- **Aplicar `derivedEffects`** en las fórmulas del bot: hoy `tapMultiplier`,
  `incomeMultiplier`, `offlineEfficiency`, `critChance` y `prestigeBonus` viajan
  en cero. `UpgradeManager.recomputeDerivedEffects` ya existe y es la fuente
  única — usala, no la reimplementes.
- **Modelar el atajo del HUD** como acción disponible (después de §4.5, o sea:
  comprando el tier base del piso más alto contratable), y **subir el modelo de
  tapeo** a algo defendible (5-8 taps/s en ráfaga; el dueño tapea rápido).
- **Publicar la métrica que importa**: horas ACTIVAS hasta maxear las siete
  líneas (= skins doradas). Hoy el `Report` no la tiene y es el número que el
  dueño quiere en 20-30 h.

Entregable de este paso: una corrida "antes" con el modelo nuevo contra la
economía actual. Ese número —no el 191 h de hoy— es la línea de base real.

### 4.2 Cerrar la divergencia costos-vs-ingresos

Es el arreglo de fondo (§2.3). Opciones, con su costo — **elegí una, medila, y
escribí por qué descartaste las otras**:

- **Anclar los costos al multiplicador**: que `hireCost`/`passiveUnlockCost`/
  `charUpgrade` escalen con `globalMultiplier` (total o parcialmente, ej.
  `M^0,8`). Es el arreglo estándar de los idle: el prestigio te hace más rápido,
  no infinitamente rico. Toca EconomyKit puro y sus tests pineados.
- **Aplanar el ORO**: bajar `exponent` (0,45 → ~0,30) y/o hacer el multiplicador
  global **sublineal** en oro (hoy es `1 + oro×0,18`, o sea lineal sin techo;
  `1 + k·oro^0,7` o un logarítmico cambian el late game entero).
- **Techo blando**: rendimientos decrecientes por encima de cierto multiplicador.

**Criterio de aceptación de este punto** (sale de §2.6): reencarnar tiene que
**convenir antes de la pared**. Medilo explícitamente — en qué momento de la run
el multiplicador que te llevás supera lo que cuesta re-ascender— y dejá ese número
en la bitácora. Si el óptimo sigue siendo "reencarnar recién cuando no podés
avanzar más", el arreglo no funcionó por más que el ORO sea más chico.

⚠️ El dueño dijo "los multiplicadores al reencarnar están mal" **y** "el oro que
da es tanto que es muy fácil ganar": son las dos caras de esto. Un arreglo que
sólo baje el ORO sin tocar la relación costo/ingreso deja el defecto vivo y hace
el arranque más lento — el peor de los dos mundos (la bitácora ya cometió ese
error una vez: ver "primero el muro, después el ORO").

### 4.3 El click del tier alto

`GameActions.applyTap` da `tapYield(tier)` completo por toque, con todos los
multiplicadores. Un minuto de clicks al tier más alto financia el piso siguiente.
Candidatos (medir, no adivinar):

- Bajar `yieldGrowthPerTier` (2,8) **sólo para el tap**, separando el yield de
  tap del de passive (hoy `passiveYield = tapYield × 0,5`: un solo botón para dos
  curvas que el diseño necesita distintas).
- Que el tap NO reciba el multiplicador de piso o el de char upgrades (hoy recibe
  los dos, y el passive también).
- Rendimientos decrecientes por ráfaga (tapear 300 veces seguidas rinde menos que
  300 taps espaciados). Cuidado: es el verbo principal del juego, no lo mates.

Restricción de diseño del dueño: el tap tiene que seguir siendo útil en el early
game — el tutorial lo enseña y la primera contratación sale de ahí.

### 4.4 La curva de las siete líneas

`crit` es el 99,99 % del costo de ganar (§2.4). Rebalanceá el catálogo para que
las siete líneas cuesten algo comparable entre sí y que el total case con el
objetivo de 20-30 h activas. Es `upgrades.json` puro (`baseCost`, `costGrowth`,
`maxLevel`) — sin código.

### 4.5 El atajo del HUD: sólo el personaje inicial de cada piso

Pedido explícito, y además es una regresión de pacing que entró el 2026-08-17 sin
medirse (el `QuickHireButton` vende el tier MÁS ALTO pagable, que es justo lo que
saltea el merge).

- Tocar `GameState.computeBestHire()` (`FisuEvolution/Game/State/GameState+Hiring.swift`):
  el candidato ya no es "el tier más alto pagable **entre todos los contratables**"
  sino "**entre los tier base de piso** (`type.tier == floor.firstTier`) pagables".
  El resto de la regla —empates, meta de ahorro cuando no alcanza, `nil` cuando no
  hay nada— se conserva.
- `FisuJobsView` **no se toca**: sigue vendiendo todo lo desbloqueado.
- Los tests de `BestHireTests` que pinean "el tier más alto pagable" cambian de
  significado: re-escribilos para la regla nueva, con un caso que pruebe que un
  tier NO-base pagable y contratable **no** es la oferta.
- Actualizá el docstring de `BestHire` y el del botón: hoy dicen "el mejor
  contratable que la plata alcanza" y pasarían a mentir.

### 4.6 Los logros pagan segundos de producción, no un múltiplo de un costo

Migrar los 27 logros de monedas al molde del Aguinaldo: el premio es **N segundos
de tu `passivePerSecond` actual** (o de tap+passive, decidilo y documentalo), con
N calibrado por familia de logro en vez del `factor` sobre `passiveUnlockCost` de
hoy. Con eso el premio queda "acorde a la plata que podés tener en ese momento",
que es el pedido textual.

- Es `achievements.json` + `GameState+Achievements.swift:262`.
- Revisá de paso los 12 logros que dan ORO fijo (20-120): si §4.2 achica la escala
  del ORO, esos montos pasan de decorativos a decisivos y hay que re-mirarlos.
- Y mirá el propio Aguinaldo (900 s de producción de regalo, peso 12): con la
  misma vara, 15 minutos gratis cada vez que sale es mucho.

### 4.7 Los eventos, más espaciados y menos regaladores

`events.json`: subir `baseIntervalSeconds` (hoy 300 con jitter 180 → uno cada 2-8
min), subir los `cooldownSeconds` de los que aceleran, y bajar `weight`/`magnitude`
de `plan_platita` (×5), `inversion_alienigena` (×10), `aguinaldo` y `blanqueo`.

⚠️ **No los apagues**: los eventos son el humor del juego y el dueño los quiere
—se queja de la FRECUENCIA, no de que existan—. Y son la única fuente de tensión
negativa (devaluación, corralito, cayó Mercado Pago): si al espaciarlos se caen
sólo los malos, el juego queda más fácil todavía. Mantené la proporción entre
buenos y malos, o mejorala a favor de los malos.

---

## 5. Cómo verificar (protocolo de la casa — `HANDOFF.md` §6)

1. **Loop de calibración**: `swift run -c release pacing-sim --economy … --tiers …
   --max-days N` después de CADA knob. Guardá el CSV (`--csv`) de las corridas que
   defiendan una decisión.
2. **Re-pinear `PacingTests`** a la conducta nueva: hoy está 3/4 en rojo contra
   una conducta que ya no existe. Los rangos nuevos van con el número medido ±30 %
   y un comentario que diga qué corrida los produjo (así se hizo las cuatro veces
   anteriores; ver el docstring del archivo).
3. **Suites**: EconomyKit (`swift test`, 205) → unit (`FisuEvolutionTests`, ~381)
   → UI (46) en simulador PROPIO por UDID, unit ANTES que UI,
   `-parallel-testing-enabled NO`, borrar el simulador al terminar. Cero warnings.
4. **Playtest real**: el simulador no reemplaza jugar. Antes de dar el trabajo por
   cerrado, pedile al dueño una pasada — es el único que puede decir si las 20-30 h
   se sienten bien o se sienten un castigo.
5. ⚠️ **Trampa de máquina** (`HANDOFF.md` §7): el checkout es compartido con otras
   sesiones del dueño que commitean con `git add -A`. Trabajá en worktree propio,
   stageá sólo tus paths, commiteá apenas esté verde.

---

## 6. Definición de hecho

- [ ] El simulador modela mejoras permanentes, `derivedEffects`, el atajo acotado
      y un tapeo defendible; publica **horas activas hasta maxear las siete**.
- [ ] Esa métrica cae en **20-30 h activas**, y Dios queda más lejos que eso.
- [ ] La relación costo/ingreso ya no diverge sin techo: hay un número que lo
      demuestra a lo largo de toda la partida (no sólo al final).
- [ ] Las siete líneas cuestan algo comparable entre sí; ninguna es el 99 %.
- [ ] El atajo del HUD vende sólo tier base de piso; FisuJobs sigue igual.
- [ ] **Reencarnar conviene antes de la pared**, con el momento medido y escrito.
- [ ] El bot reencarna un número parecido al del humano (≤8), no decenas.
- [ ] Los logros pagan segundos de producción actual; los eventos se espacian sin
      perder su cara mala.
- [ ] `PacingTests` verde y re-pineado con los números de la corrida nueva.
- [ ] EconomyKit + unit + UI verdes, cero warnings.
- [ ] `Docs/balance-log.md` con una entrada nueva: qué se movió, qué se descartó
      **con su número**, y la tabla piso por piso antes/después.
- [ ] Cierre según el sistema de handoffs (`~/Desktop/skills/documentation`):
      doc de sesión + handoff efímero + entrada nueva en `Docs/HANDOFF.md`.

---

## 7. Decisiones del dueño — ya respondidas, no volver a preguntar

Las tres dudas que este prompt tenía abiertas se preguntaron el 2026-08-20 y
están cerradas. Van acá con sus palabras para que nadie las re-litigue:

| Pregunta | Respuesta |
|---|---|
| ¿Las 20-30 h son hasta maxear las siete, o hasta Dios? | **Hasta maxear las siete.** Dios queda más lejos, como viaje aparte. |
| ¿Horas activas o de calendario? ¿Qué pasa con el offline? | **Activas**, con el **offline como está** (35 %, tope 10 h) o más generoso. |
| ¿Cuántas reencarnaciones por partida? | **"8 como mucho. yo cuando gane el juego reencarne 3 o 4 veces nada mas."** |

⚠️ **La tercera es la que más cambia el trabajo, y es también un dato de
medición**: el dueño ganó con 3-4 reencarnaciones y el simulador hace 47. Con un
techo de 8 para un recorrido de 20-30 h activas, el ORO ya no puede llegar en
goteo: tiene que venir en **pocas entregas grandes**, y la curva
`oro = (earnings / 3e6)^0,45` con multiplicador **lineal** (`1 + oro × 0,18`) es
justo la forma que produce lo contrario. Cualquier arreglo de §4.2 tiene que
hacer que el ORO de UNA reencarnación valga mucho y que haya pocas, en vez de
muchas que valen poco cada una pero infinito en conjunto.

Es también la prueba más dura de que el bot no representa al jugador: **47 contra
3-4** en la misma partida. Si después de §4.1 el bot sigue reencarnando decenas
de veces, el modelo todavía está mal y los knobs que se calibren contra él van a
seguir mintiendo.
