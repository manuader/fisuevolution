# Sesión 2026-08-23 — El precio atado a la frontera (cuarta ronda de balance)

> **Lo que había que hacer**: la ronda 3 midió la causa raíz del pacing y el
> dueño eligió la Opción 1 —que el precio de contratar deje de seguir a
> `tapYield(tier)`—. Está hecho, testeado y medido: **comprar hondo pasó de
> costar `0,71^d` a costar `1,33^d`**, y con eso la compuerta se volvió por
> primera vez un dial de dificultad real.
>
> **Lo que NO se logró**: el contrato de 20-30 h. Sigue en 7,27 h. Pero la causa
> que queda ya no es la que el dueño creyó atacar, es otra y está medida: **la
> mitad del tiempo activo del bot es apretar el botón, no esperar plata**. Los
> números están en `Docs/balance-log.md`, "Cuarta ronda". Acá está el **por qué**
> y lo que hay que decidir.

Commits: `e7a9b08` (el precio) · `9e698fc` (el bot) · `c90a0aa` (la compuerta a 6).

---

## 1. La fórmula, y por qué el ancla tiene que ser la frontera

    mult(piso) × tapYield(FRONTERA) × factorDePiso
              × priceGrowthPerTier^(tier − frontera) × growth^compras

La derivación de una línea, que es lo que hace que esto no sea una preferencia:
el diseño quiere **dos** cosas y con un precio `f(tier)` no puede tener las dos.

1. Que subir un tier cueste siempre lo mismo en **tiempo** ⇒ el precio tiene que
   ser proporcional al rendimiento de tu frontera, que es de donde sale tu
   ingreso ⇒ pendiente **2,8** por tier.
2. Que la **pendiente del precio por tier** sea **≤ 2** —el factor de merge—, o
   si no comprar `2^d` unidades hondas siempre sale menos que comprar una arriba.

La (1) le fija la pendiente en 2,8 y la (2) la quiere en 2. Contradicción, y por
eso ningún knob de la ronda 3 podía arreglarlo. Anclar el precio a la frontera
**separa el nivel de la pendiente**: el nivel sigue a `tapYield(frontera)` (2,8
por tier de frontera, pacing plano) y la pendiente pasa a ser un knob propio
(1,5 por tier comprado, atajo cerrado). Es la Opción 1 en su forma mínima.

El knob es `hire.priceGrowthPerTier` y lo que importa de su valor es que esté por
**debajo de 2**: una unidad de tu frontera comprada `d` tiers abajo sale
`(2/P)^d`. Con 1,5, **1,33× más caro por tier de profundidad**.

`tierPremium` (1,8) se borró. **No por inerte** —lo era, pero ése no es el
motivo—: bajo la fórmula nueva dejaría la pendiente real dentro de un piso en
2,8 × 1,8 = 5,04, o sea el agujero otra vez. Su trabajo de siempre —que comprar
arriba no sea un atajo contra mergear— ya lo hace la compuerta, que no autoriza
nada por encima de `frontera − N`.

### El invariante nuevo, y por qué el viejo se dio vuelta

El test que decía `costo(t+1) > 2 × costo(t)` ahora dice lo contrario, y no es un
aflojamiento: **las dos condiciones son complementarias**.

- `costo(t+1)/costo(t) > 2` ⟺ comprar hondo sale más barato.
- `costo(t+1)/costo(t) < 2` ⟺ comprar arriba sale más barato.

El filo es exactamente el factor de merge; no hay una tercera opción. El diseño
elige el segundo lado y el primero lo cubre **la compuerta**, no el precio.

### La costura del callejón, que es el precio de una decisión cerrada

El callejón cotiza con 25 y los otros nueve pisos con 600, así que comprar ahí
sale 24× menos y la regla no vale al cruzar esa frontera. Lo que hace que no
rompa el balance es que **el descuento no compone**: comprar el tope del callejón
y subir sale `25 × 1,33^(f−4)`, que CRECE con la frontera, mientras que comprar
lo que la compuerta habilita sale `600 × 1,33^N` y es constante. El callejón deja
de ser el camino barato en el **tier 22 de 37**. Está pineado
(`elDescuentoDelCallejonSeAgotaSolo`) para que si alguien mueve el 25 o el 600
sepa qué está moviendo.

---

## 2. La tercera ceguera del bot (van tres en esta rama)

`nextAction` elegía la contratación con el `min` por **precio**. Valía mientras
lo más barato fuera también lo más eficiente, y el precio viejo lo garantizaba.
Con el precio nuevo las dos respuestas **se dan vuelta**: el Fisura sigue siendo
lo más barato del catálogo y pasa a ser lo MENOS eficiente, porque hacen falta
`2^d` para una unidad de tu frontera.

Costo del arreglo: maxear 5,33 → **4,14 h**. El bot juega mejor, así que tarda
menos.

> **La lección de método, por tercera vez y ahora con nombre**: cuando una regla
> del juego cambia, hay que preguntarse **qué supuesto del bot dependía de la
> regla vieja**. Las tres veces el supuesto no estaba escrito como supuesto: la
> primera estaba escrito como un ranking (`max(by: contribution)`), la segunda
> como una optimización ("comprar arriba nunca conviene"), y ésta como una
> obviedad (`min(by: cost)`). Los tres eran correctos y los tres se murieron en
> silencio.

---

## 3. El hallazgo de esta ronda: el juego es *action-bound*, no *money-bound*

El simulador cobra **1 s de manipulación por compra**, y con la compuerta en `N`
cada tier de frontera cuesta `2^N` compras. Poniendo ese segundo en cero
(experimento, no commiteado):

| | con 1 s por compra | sin manipulación |
|---|---:|---:|
| N=5 | 4,14 h | **2,19 h** (−47 %) |
| N=8 + growth 1,02 | 11,67 h | 9,67 h (−17 %) |

**La mitad del tiempo activo del bot es apretar el botón.** Tres consecuencias, y
explican todo lo demás:

1. **Los knobs de precio son sublineales.** `defaultCostMultiplier` ×16 compra
   ×1,75 de partida. Es por qué el barrido de la ronda 3 tenía techo y por qué el
   de ésta también.
2. **El atajo viejo estaba sosteniendo la mitad del largo del juego, sin que
   nadie lo hubiera diseñado.** Comprar hondo era barato pero pedía
   `2^(frontera−1)` compras. Cerrarlo bajó las compras y por eso la partida se
   acortó (6,67 → 4,14 h) ANTES de subir la compuerta. La compuerta a 6 es lo que
   devuelve ese trabajo, ahora a propósito y con un número.
3. **Reencarnar no puede pagar mientras el reloj sea de manipulación.** El ORO te
   saca la ESPERA, no las compras, y la torre vuelve al tier 1 cada vez. Ninguna
   mejora del catálogo acorta la SUBIDA.

Y queda un segundo acelerador abierto: el `incomeMultiplier` del piso (1 → 620) lo
cobra el **pasivo** y no lo cobra el precio, así que el ingreso crece 3,33× por
tier contra los 2,8× del precio. Se ve crudo en la corrida: **"entrar al piso" va
de 100 s en el callejón a 0,0 s en el reino divino**, y la mitad del tiempo de una
subida entera se va en los dos primeros pisos.

---

## 4. Por qué la compuerta quedó en 6 y no en 7

| N | maxear | reenc | dios | 1ª reenc | peor paso |
|---:|---:|---:|---:|---:|---:|
| 5 | 4,14 h | 9 | 4,59 h | 4,00 h | ×7,64 |
| **6** | **7,27 h** | **8** | **9,40 h** | **4,28 h** | **×16,37** |
| 7 | 185,63 h | 8 | 189,62 h | 28,29 h | ×4.441,72 |

El 7 no falla por el largo: falla por el **muro del early game**. Hasta que la
frontera llega a `N+2` lo único contratable es el Fisura, así que hay que mergear
`2^(N+1)` de ellos contra `1,06^compras`. Bajarle la curva SÓLO al callejón
(`hireCostGrowth` 1,02) destraba el muro y N=7 mide 10,34 h — pero deja el peor
paso en ×19,43 y la primera reencarnación a 9 h de pared, así que **no se
shippeó**: eran 3 h más a cambio de resucitar el escalón que la ronda 3 había
enterrado, y el contrato no cerraba igual.

---

## 5. La guarda del gradiente subió, y hay que saber por qué

`PacingTests.floorGradient` tenía la guarda del peor paso en **10,21** y ahora
está en **21,30**. Eso es un aflojamiento salvo que se lea el número al lado: el
paso que la mueve es urbano → corporativo, y en tiempo absoluto son **1,3 min →
21,3 min**. El ratio es grande porque el arranque es cortísimo (el Fisura sale
25), no porque haya una pared — el acantilado que esa guarda nació para cazar
eran **13,3 h** de un solo salto.

Para que la banda no se debilite donde importa, al lado va el assert que el dueño
enunció y **que no existía**: `noHitoJumpIsLongerThanFourActiveHours`, en HORAS y
sobre los diez pisos. Peor salto medido: **2,02 h** (contra 4,45 h en la ronda 3 y
10,0 h en la segunda). El tope es 4 h fijo y no "lo medido +30 %", a propósito:
no es una banda alrededor de la conducta, es el contrato del dueño.

---

## 6. Qué quedó del contrato

| métrica | contrato | ronda 3 | ahora | |
|---|---|---:|---:|---|
| maxear las siete | 20-30 h activas | 6,67 h | **7,27 h** | 🔴 |
| reencarnaciones al maxear | ≤ 8 | 7 | **8** | ✅ |
| cadencia | 2,5-4 h activas | 0,6-2,3 h | **0,6-1,4 h** | 🔴 |
| dios después de maxear | sí | ×2,04 | **×1,29** | ✅ |
| sin reencarnar más lento | sí | ×0,24 | **×0,30** | 🔴 |

`PacingTests.theOwnersTargetsAreMet` **sigue en rojo a propósito** y no se
aflojó. Su docstring lleva el diagnóstico nuevo y los dos caminos medidos.

Lo que sí mejoró y no es poco: la **fase fisura casi se triplicó** (28,0 → 78,0 s
activos) sin tocar el Fisura ni un peso, el **peor salto entre hitos bajó a
2,02 h**, y la compuerta —que era el dial que el diseño le había prometido al
dueño el 2026-08-22 y que no funcionaba— **funciona**.

---

## 7. Lo que hay que decidir (es del dueño, no de una calibración)

1. **¿El simulador cobra el MERGE?** Hoy cuenta las compras y no las fusiones,
   que son el verbo central del juego. Si el reloj del dueño es "horas de dedo",
   el instrumento está midiendo de menos. Medido: sube todo ~30 % (N=6 → 6,67 h;
   N=7 con el callejón destrabado → 13,33 h y dios a 21,21 h). **No se adoptó**
   porque cambiaría lo que mide el instrumento y re-pinearía todas las bandas
   históricas de la rama — y usarlo para "llegar" a 20-30 h sería medir contra el
   objetivo.
2. **¿Se cierra el segundo acelerador?** El `incomeMultiplier` del piso lo cobra
   el pasivo y no el precio. Aplanarlo a 1,0 → 6,83 h (12,16 h con N=6, pero 9
   reencarnaciones); anclarle el precio al `incomeMultiplier` de la frontera →
   6,63 h (10,49 h con N=6, pero 13 reencarnaciones). Las dos rompen algo.
3. **¿Reencarnar tiene que pagar?** Con el reloj de manipulación, ningún
   multiplicador de ingreso alcanza: haría falta una mejora permanente que
   acorte **la subida** (menos compras por tier), que hoy no existe en el
   catálogo.
4. **¿Se re-enuncia el contrato?** 7,27 h a maxear y 9,40 h a dios es lo que el
   juego mide hoy con el jugador de verdad.

---

## 8. Trampas de máquina (para el próximo)

- ✅ **El runtime de iOS 26 ya está instalado** (26.5 - 23F77). El gate humano de
  la ronda 3 está resuelto: `actool` compila el catálogo de assets y **no hace
  falta sacar `Assets.xcassets` del target**. La corrida de esta sesión es con el
  catálogo puesto.
- ⚠️ **`StoreKitTest` sigue sin compilar sin parche**: su header usa
  `SKPaymentTransactionState`, deprecado en iOS 18, y el target compila con
  `-warnings-as-errors`. Hay que pasar
  `OTHER_SWIFT_FLAGS='$(inherited) -Xcc -Wno-deprecated-declarations'` a
  `xcodebuild`. Sin eso el build de tests **no arranca**.
- 🔴 **Las 11 pruebas de StoreKit fallan, y fallaban ANTES de esta rama.**
  `store.products` vuelve vacío contra el runtime iOS 26.5: la tienda local no
  carga el `.storekit` del scheme. **Verificado a mano en un worktree limpio en
  `8f884ea`**, con el mismo simulador y el mismo comando: mismas 10 fallas de
  `StoreManagerTests` más `StoreProductsTests`. No es del cambio de precios —que
  no toca IAP— y es un gate de máquina, no del proyecto.
