# Sesión 2026-08-22 — El multiplicador deja de ser exponencial, y no reencarnar deja de ser el atajo

Rama `fix/rebalance-pacing`, segunda ronda de balance. El dueño jugó la rama ya
rebalanceada y pidió dos cosas: que las mejoras por personaje sean **secuenciales**
y que **subir de piso sea más difícil**.

El registro DURABLE de la calibración —cada barrido, cada A/B y cada descarte con
su número— es **`Docs/balance-log.md`**, sección "Segunda ronda (2026-08-22)".
Este documento es el porqué.

---

## Lo que pidió

> "en menos de una hora llegue de fisura a dios sin reiniciar. es muy facil
> porque cuando subis de piso tenes tanta plata que te podes comprar un monton
> de personajes del piso de abajo y subir mas pisos super rapidos. hace que sea
> mas dificil subir de piso."
>
> "por otra parte, los multiplacadores estan muy op. en lugar de multiplicar x2
> (hasta llegar a 2^20) cada vez, hace que sea secuencial. (ej: x2 -> x3 -> x4
> -> x5 -> ... -> x20)"

Restricción heredada de la ronda 1, textual: *"no introduzcas ningun bug al
hacer el refactor"*.

---

## Las cuatro métricas, antes y después

| | ronda 1 | ronda 2 |
|---|---:|---:|
| **maxear las siete (h ACTIVAS)** | 24,00 | **24,67** |
| **reencarnaciones al maxear** | 8 | **8** |
| **dios (h ACTIVAS)** | 26,59 | **33,23** |
| **dios SIN REENCARNAR (h ACTIVAS)** | **10,47** | **66,34** |

Las tres primeras son el contrato que no se podía perder (`theOwnersTargetsAreMet`,
que no es una banda re-pineable) y siguen verdes **sin tocar el test**. La cuarta
es nueva: no existía como número hasta esta sesión.

---

## Primero el instrumento, porque la queja no se podía medir

La partida del dueño —de fisura a dios **sin reencarnar**— era **inexpresable**
para el simulador. La única palanca era `reincarnationThresholdMultiple`, un
múltiplo sobre el ORO ganado histórico, y ese arranca en CERO: `N × 0 = 0` para
cualquier N finito, así que la primera reencarnación caía igual con umbral 1 que
con 1.000. "Nunca" no era ningún número, y el bug era **silencioso** — parecía
que un umbral gigante alcanzaba.

Se cambió el Double por un enum (`PacingSimulator.ReincarnationPolicy`), y dios
ganó su tiempo ACTIVO (`godActive`) al lado del de pared, porque el dueño mide en
horas de dedo. El activo se podía derivar de `floorUnlockActiveSeconds["god_realm"]`,
pero SÓLO porque ese piso va del tier 37 al 37: un piso final con varios tiers
abre antes de que se llegue a dios.

**La línea de base que apareció** (contra el árbol de la ronda 1): dios en
**10,47 h activas** sin reencarnar contra **26,59 h** reencarnando. No reencarnar
era **2,5× más rápido**. Ése era el atajo, y estaba invisible.

Verificado que el bot sí hace lo que hace él —comprar en masa abajo para subir—:
3.919 contrataciones repartidas en los ocho tiers base contratables (homeless
785 · mantero 660 · oficinista 589 · director 518 · ceo 448 · magnate_petrolero
377 · dueno_marte 306 · rentista_soles 236).

⚠️ **El bot no llega a la hora que midió el dueño y hay que decir por qué**: no
tiene logros, ni eventos, ni crits, ni golden touch, y sólo compra el tier BASE
de cada piso mientras la pantalla de laburos le vende al jugador cualquier tipo
desbloqueado. El número que vale acá es la RELACIÓN entre las dos políticas, no
el absoluto.

---

## El cambio de fórmula

`CharUpgrades.multiplier` pasó de `effectFactorPerLevel ^ nivel` a
`1 + nivel × effectStepPerLevel`. El knob se **renombró** porque el viejo mentiría:
dejó de ser la base de una potencia y pasó a ser lo que suma cada nivel.

**El tope: `maxLevel` 20 → 19.** El dueño escribió la serie terminando en ×20 y
`1 + 19 × 1 = 20` la clava; con 20 niveles el tope sería ×21, que nadie pidió. Y
el tope ya no existe para frenar un overflow —que era el motivo de la decisión de
2026-08-19 con el `2^nivel`—: una recta no desborda.

### Las dos copias de la fórmula que había que juntar ANTES de tocarla

Es la clase de bug que esta rama ya produjo tres veces, y esta vez se buscó
primero:

- **`GameState+Upgrades.characterUpgradeRows`** armaba el texto de la fila con su
  propio `pow(factor, nivel)`. Mientras el efecto fue una potencia las dos
  expresiones daban lo mismo; con la recta la pantalla habría prometido ×2^n
  mientras la economía pagaba ×(1+n). Ahora llama a `CharUpgrades.multiplier`, y
  su test compara la fila contra la función que COBRA en vez de contra la config
  —que es exactamente lo que dejaba verde a la copia—.
- **El bot del simulador** estimaba la ganancia del próximo nivel como
  `effectFactorPerLevel − 1`, una constante. Con la recta la ganancia marginal se
  ACHICA (el primer nivel duplica, el último suma 5,3 %), así que el bot habría
  creído que el nivel 19 rinde tanto como el 1. Sale de
  `CharUpgrades.nextLevelGainFactor`, la misma fuente que el efecto que se cobra.

### Lo que costó, medido solo

Sin tocar ningún otro knob: maxear las siete pasó de **24,00 h a 322,00 h**. El
efecto al tope pasó de ×1.048.576 a ×20, o sea **52.000× menos**. Todo lo que
sigue es recuperar el contrato.

---

## La calibración: dos knobs, uno por vez

### `charUpgrades.costGrowth` 4,0 → 1,5 — la línea estaba muerta

Contra un efecto LINEAL, un costo ×4 por nivel hace que los niveles altos sean
pésima compra. Medido con los niveles finales de la partida sin reencarnar (la
única donde no los borra la reencarnación):

| costGrowth | niveles comprados de 19 | mediana | maxear |
|---:|---|---:|---:|
| 4,0 | 2 – 7 | **4** | 322,00 h |
| 2,0 | 4 – 13 | 7 | 195,33 h |
| **1,5** | **6 – 19** | **11** | **122,00 h** |
| 1,2 | 16 – 19 | 19 | 81,33 h |

Con 4,0 **doce de los diecinueve niveles no los compra nadie** y el ×20 del pedido
no lo ve ningún personaje: el tope real es ×8. Con 1,2 los compra todos y la
línea deja de tener decisión. Con **1,5** la mediana queda a mitad de camino y los
tipos mejor puestos (`deidad`, `coleccionista_galaxias`) sí llegan al ×20.

La cuenta que lo explica: una mejora gana contra una contratación mientras
`50 × growth^n / 600 < unidades del tipo`. Con 10 unidades y growth 1,5 el cruce
cae en el nivel 11,8 — exactamente la mediana medida.

### `oro.divisor` 3e12 → 1e9 — recuperar las 20-30 h

`costGrowth` solo no alcanza: ni con 1,0 (todos los niveles regalados) baja de
75 h. El tope de ×20 no se compensa con precio.

Con 1e9: maxear 24,67 h —lo más cerca de las 24,00 h que el dueño ya aprobó— con
8 reencarnaciones y margen a los dos lados de la banda.

**Y las dos mitades del pedido no se pisan**: la partida sin reencarnar no toca
el ORO, así que el divisor **no la mueve ni un minuto** (66,34 h para cualquier
divisor del barrido). Lo que el divisor baja es el camino que SÍ reencarna.

---

## La queja 2, contestada con un número

El atajo se dio vuelta. Y el barrido de política, que en la ronda 1 **no era
monótono** (con umbral ×8 se maxeaba en 15,29 h, o sea guardarse las
reencarnaciones GANABA), ahora lo es de punta a punta:

| política | maxear (h activas) | dios (h activas) |
|---|---:|---:|
| **×1 (duplicar — el default)** | **24,67** | **33,23** |
| ×8 | 30,54 | 33,42 |
| ×1000 (contra la pared) | 50,51 | 52,15 |
| **nunca reencarnar** | **no maxea** (no hay ORO) | **66,34** |

Cuanto más se posterga la reencarnación, peor: en las DOS métricas, en las cuatro
políticas. Subir de piso es más difícil **y** reencarnar sigue siendo lo que
conviene, que eran las dos mitades del pedido.

---

## Lo que se descartó, con su número

- **`hire.defaultCostGrowth`** — la sospecha fuerte del prompt (1,06 es justo lo
  que abarata comprar en masa). Re-medido sobre el árbol nuevo: **es un
  acantilado, no un dial**. 1,06 → 24,67 h · 1,08 → **482,00 h** · 1,10, 1,12 y
  1,15 → **la partida no se puede terminar**, el bot no pasa de corporativo. No
  hay ningún valor entre "el atajo existe" y "el juego es injugable". La sospecha
  era correcta sobre la CAUSA y equivocada sobre el REMEDIO.
- **La curva de `incomeMultiplier` de `floors[]`** — no toca lo que venía a
  tocar. Aplanarla a ×1,85/piso lleva maxear a 30,00 h, a ×1,7 a 37,67 h y a ×1,4
  a 60,48 h, y la serie "entrar al piso" queda **idéntica** en las cuatro. Alarga
  el juego sin mover la divergencia.
- **`oro.exponent`** (subirlo en vez de bajar el divisor, para no abaratar el ORO
  temprano): el mejor caso deja maxear en **99,63 h** y la primera reencarnación
  en 25,67 h ACTIVAS.
- **`tierPremium`** (1,8): el simulador es **ciego** a este knob —el bot sólo
  compra tiers base— así que no se puede calibrar con él. Queda declarado.

---

## Lo que quedó declarado en vez de tapado

- **La primera reencarnación volvió a caer temprano**: 4,07 h de pared (0,41 h
  activas) contra las 62,00 h de la ronda 1. Es el precio del divisor; con el de
  la ronda 1 el hito se iba a las 25,67 h ACTIVAS y maxear a 122 h. Lo que sí se
  conservó es el objetivo real de aquel cambio —que reencarnar temprano
  convenga—, y ahora se cumple mejor (la tabla de arriba es monótona; la de la
  ronda 1 no lo era).
- **El acantilado corporate → luxury pasó de ×24,80 a ×90,86** (de 3,2 h activas
  a 13,3 h). Vive donde el gate de un piso muerde: corporativo no se puede
  contratar hasta que lujo abra, así que ese cruce se hace mergeando 256 unidades
  del piso de abajo. Es literalmente "más difícil subir de piso" concentrado en
  un paso; queda medido, no aprobado.
- **La serie "entrar al piso" se desploma un piso antes** (100 · 100 · 48 · 8 · 2
  · 0,1 · 0,1 · 0,0 · 0,0 contra 100 · 100 · 100 · 73 · 48 · 4,8 · 1,5 · 0,1 ·
  0,0). Misma causa que la ronda 1 ya diagnosticó y descartó arreglar con número:
  el `globalMultiplier` multiplica el ingreso y no el precio de contratar. **En
  la partida SIN reencarnar la serie se queda en ~99-100 s hasta dios**, que es
  la prueba de que la divergencia la produce el ORO y nada más.
- **Un save anterior al 2026-08-22 con `charUpgradeLevels` en 20** se clampea a
  19 y pierde un nivel. Son mejoras de RUN (mueren al reencarnar), así que no
  hace falta migración; el clamp ya estaba y lo cubre `multiplierClampsDoctoredSaves`.

---

## Cómo se corre

```bash
cd Tools/pacing-sim && swift run -c release pacing-sim \
  --economy ../../FisuEvolution/Resources/Data/economy.json \
  --tiers ../../FisuEvolution/Resources/Data/tiers.json \
  --max-days 90 [--csv salida.csv] \
  [--prestige-threshold X | --no-reincarnation]
```

`--no-reincarnation` es la política de la queja del dueño y **no** es lo mismo
que un `--prestige-threshold` grande: el umbral se calcula sobre el ORO
histórico, que arranca en cero.

---

## Cómo terminó

**EconomyKit 238 · unit 411 · UI 46**, sin un solo `-skip-testing:`, cero
warnings de compilador, simulador propio por UDID y `-parallel-testing-enabled NO`.

Las cuatro bandas de `PacingTests` se re-derivaron a mano de la corrida nueva
(CSV commiteado en `Docs/balance-run-t7-secuencial.csv`) y **`theOwnersTargetsAreMet`
—que no es una banda— siguió verde sin tocar un solo assert**.
