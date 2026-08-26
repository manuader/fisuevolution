# Sesión 2026-08-23 (ter) — La desaceleración: la run se traba y el prestigio corre la pared

> **Lo que cerró**: los dos contratos que nunca habían cerrado en cuatro rondas.
> Maxear las siete mide **20,67 h activas** —el primer assert de
> `theOwnersTargetsAreMet` pasa por primera vez— y **el que no reencarna ya no
> llega a dios**. Lo que lo hizo no fue una constante: fue la **forma** de la
> curva.
>
> **Lo que queda abierto y es honesto**: 9 reencarnaciones contra el techo de 8
> (§3), y el total en el reloj del dueño (§4). Las dos con su número y sin forzar.

Commits: `c82ccf5` (la desaceleración) · `267bcc7` (docs y pins) · `ceeabc9`
(el build). Números: `Docs/balance-log.md`, "Cuarta ronda (ter)". Corrida:
`Docs/balance-run-t11-desaceleracion.csv`.

---

## 1. El diagnóstico, que es lo que hay que entender antes de tocar nada

Con el precio anclado a la frontera y **nada más**, el precio de avanzar crece
`yieldGrowthPerTier` por tier y tu ingreso también: **cada tier cuesta el mismo
tiempo que el anterior**. 37 tiers × constante da una duración fija y —lo que
importa— **una run que nunca se traba**. Por eso se podía ir de Fisura a Dios de
una sentada y por eso reencarnar no pagaba: se reencarna para correr una pared, y
no había pared.

El simulador lo dice ahora en un renglón, y ése es medio trabajo de la ronda:

    pared de cada run: — · — · — · — · — · — · — · — · —

**Un solo dial no podía arreglarlo**, y por eso las tres rondas anteriores se
quedaron cortas: el problema no era la constante sino la FORMA. La profundidad de
la compuerta lo mostró tirando de los contratos 2-3 y del 5 en sentidos opuestos.

---

## 2. Lo que se construyó

**`frontierEscalationPerTier` (1,6) con `frontierEscalationFromTier` (7)**: del
tier 7 para arriba, tu propia frontera se encarece un 60 % por tier **por encima**
de lo que ya sube por rendir más. El precio de avanzar pasa a crecer
`yieldGrowthPerTier × D` mientras el ingreso sigue creciendo `yieldGrowthPerTier`:
el tiempo por tier se multiplica por `D` cada vez.

**El umbral no es adorno.** Sin él la escalada es una exponencial desde el tier 1,
y una exponencial no tiene cómo ser suave abajo y densa arriba: o muerde temprano
o no muerde nunca. Medido, con `D` = 1,6 desde el tier 1 **las primeras cinco runs
se traban en el tier 7**, o sea en el callejón — la frustración que el diseño
evita. Y del tier 9 para arriba **la pared desaparece**, porque el bot reencarna
al duplicar el ORO antes de llegar a la zona con escalada: *una pared que la run
nunca alcanza no existe*.

⚠️ El primer Fisura sigue costando 25 **por construcción** (el exponente es
`max(0, F − 7)`), no por un caso especial. Y la escalada depende SÓLO de la
frontera, así que **no toca el invariante de profundidad** de la ronda anterior.

**"Trabarse" pasó a ser un número publicado**, que es la otra mitad del trabajo:
el primer tier cuyo paso al siguiente cuesta más de una SESIÓN entera de juego
activo. El umbral sale de `human.sessionSeconds` — si un solo tier te come una
sesión completa, estás trabado— y no de un literal elegido a dedo. Sin esa
métrica no se puede medir una pared, y por lo tanto no se puede calibrar una.

---

## 3. Las 9 reencarnaciones: por qué NO se forzaron

Dos knobs llegan a 8 y **los dos pagan con el contrato que se acababa de
cumplir**: `oro.exponent` 0,32 baja maxear a 14,33 h y
`oro.globalMultiplierPerOro` 0,24 a 17,67 h — los dos sacan maxear de la banda de
20-30, y el segundo además hace que **la pared retroceda** (T14 → T13).

Con la forma ya buena, mover el rojo de lugar no es arreglarlo. El test queda
rojo y declarado.

---

## 4. El total: por qué NO se escaló

20,67 h de simulador ≈ **6,9 h del dueño** contra las 20-30 suyas. **No se tocó
`oro.divisor`**, y el motivo es la incertidumbre: el ÷3 sale de UNA comparación
(su "menos de 1 h" contra las 2,97 h del bot), sin dispersión ni repetición.
Escalar contra una estimación de un punto puede pasarse por 3×.

El knob está identificado y medido (1e11 → 30,33 h de sim), listo para después
del playtest. ⚠️ Y no es gratis para la forma: 1e11 alarga pero **clava la pared**
cuatro runs en T13.

---

## 5. El build: que el dueño pueda jugarlo

Desde Xcode 26 el proyecto **no compilaba** sin flags a mano: el header de
`StoreKitTest` usa `SKPaymentTransactionState`, deprecada en iOS 18, y con
`SWIFT_TREAT_WARNINGS_AS_ERRORS` un warning de un header **ajeno** rompe el build
entero.

El arreglo es `-Xcc -Wno-deprecated-declarations`, y lo acotado está en dos
palabras: **`-Xcc`** (se lo pasa al importador de Clang, o sea sólo a headers
C/ObjC del SDK — los warnings de nuestro Swift los sigue tratando como errores
`SWIFT_TREAT_WARNINGS_AS_ERRORS`, que no se toca) y **`Debug`** (la única
configuración que importa StoreKitTest). Va en los dos targets que lo importan,
porque el módulo se compila una vez por target.

Verificado las tres cosas: **(a)** build limpio con derivedData nuevo y sin
ningún flag extra → `TEST BUILD SUCCEEDED`; **(b)** cero warnings en código
propio; **(c)** un `let sinUsar = 42` metido en `CoinFormatter.swift` **sigue
rompiendo** el build (`error: initialization of immutable value 'sinUsar' was
never used`) — la sonda se borró y el archivo quedó idéntico al commit. En la
línea de compilación se ven los dos conviviendo: `-warnings-as-errors …
-Xcc -Wno-deprecated-declarations`.

---

## 6. Trampas nuevas

1. **Una pared que la run nunca alcanza no existe.** El umbral de la escalada por
   encima del tier 9 daba `paredes: ninguna` — no porque la curva fuera suave,
   sino porque el bot reencarna al duplicar el ORO antes de llegar. Cuando una
   métrica de "forma" da vacío, mirá primero **hasta dónde llega la run**, no la
   fórmula.
2. **Un knob que arregla un contrato puede romper otro que acaba de cerrar.** Los
   dos candidatos para bajar a 8 reencarnaciones sacaban maxear de la banda de
   20-30. Antes de aplicar un knob "barato", corré las OTRAS métricas.
3. **Un error de build puede estar tapando a otro.** Al arreglar el header de
   `StoreKitTest` apareció un `tmp*.json couldn't be opened` que parecía mío: era
   un artefacto de build incremental y desapareció en la corrida siguiente. La
   atribución correcta fue construir **sin** el cambio y ver que ahí fallaba
   antes, en el header.
4. ⚠️ **El device de simulador es de UNA corrida por vez, y el segundo proceso
   puede ser el tuyo** (ya anotada como trampa 33 el 2026-08-23 bis, y me la
   llevé puesta otra vez).
