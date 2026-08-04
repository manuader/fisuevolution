# Gate de contratación por piso + secuencia de celebraciones — Diseño

> Fecha: 2026-08-04. Pedido del dueño, aprobado en conversación antes de escribir
> código. Dos cambios que llegaron juntos y que conviene hacer juntos, porque el
> primero agrega un aviso a una pila de feedback que ya está saturada.

## Problema

**1. La contratación en pisos superiores no está gateada.** Hoy podés contratar
el tier base de cualquier piso desbloqueado. El diseño lo desalienta sólo por
precio (§3.3 del prompt de F7: "precio punitivo... recién rentable como backfill
cuando tu frontera está 2-3 pisos más arriba"), o sea con una señal económica
implícita que el jugador tiene que deducir de los números. El dueño quiere que
sea una **regla explícita**.

**2. Cuando se desbloquea un piso, se solapa todo.** Un merge que asciende y abre
piso dispara HOY, todo en `t = 0`:

| Feedback | Dónde vive | Duración |
|---|---|---|
| Pop + partículas del merge | `BoardScene` | ~0,2 s |
| Vuelo de ascenso | `BoardScene.runAscentAnimation` | 0,7 s |
| Reveal del personaje nuevo | `BoardScene.runEvolutionReveal` | ~2 s (hold 1,5) |
| Celebración de piso nuevo | `BoardScene.runFloorUnlockCelebration` | ~1,3 s |
| Sheet de skin de milestone | `RootView` → `SkinAwardView` | lo cierra el jugador |

Los tres primeros arrancan simultáneos y el sheet aparece encima. **No se
aprecia ninguno.** Es el momento más importante del juego y se pierde.

Sumarle el aviso del punto 1 sin arreglar esto lo empeoraría.

---

## Cambio 1 — El gate

### La regla

Una función pura en EconomyKit,
`TowerActions.canHire(floorOrdinal:unlockedFloors:floorTable:) -> Bool`:

1. **Ordinal 0 (callejón): siempre `true`.** Contratar un Fisura tiene que ser
   siempre posible — es el motor del early game y ya es la excepción de precio
   (multiplicador 50 en vez de 300, ver `balance-log`).
2. **Tope de la torre**: si `unlockedFloors` contiene el id del **último** piso,
   `true` para cualquier ordinal.
3. **Regla general**: `true` si `unlockedFloors` contiene el piso `ordinal + 1`.

La regla 2 existe porque el último piso no tiene ninguno por encima; sin ella
nunca dejaría contratar. Decisión del dueño frente a un botón que no se abre.

> ⚠️ **El pedido original era `ordinal + 2` y se midió que rompe el juego.**
> Con dos pisos el bot se traba en tier 12 y no llega a Dios nunca. La causa es
> estructural, no de calibración: el §3.3 del prompt de F7 dice que el merge puro
> es matemáticamente inviable (T30 = 2²⁹ fisuras) y que el backfill es el puente.
> Pedir dos pisos saca ese puente justo donde hace falta —no podés comprar
> material en el piso que estás atravesando— y queda un huevo-y-gallina, porque
> la frontera avanza GRACIAS al backfill.
>
> Medido el 2026-08-04, misma config, tres corridas de `pacing-sim`:
>
> | | sin gate | **+1 (elegido)** | +2 (pedido original) |
> |---|---|---|---|
> | luxury (piso 4) | 25,7 min activos | 200,8 min | 977,9 min |
> | island (piso 5) | 58 min | 403,5 min | nunca |
> | **Dios** | **38,2 h** | **264,2 h** | **nunca** (tier 12) |
> | reencarnaciones | 17 | 50 | 49 |
>
> El dueño eligió +1 sabiendo que alarga el juego ~7×.

`TowerActions.hire` suma `guard canHire(...) else { throw TowerError.hireLocked }`
**después** del `floorLocked` que ya existe. Son errores distintos a propósito: el
piso puede estar abierto y aun así no permitir contratar, y la UI los distingue.

### Una sola función, dos consumidores

`canHire` la usan `TowerActions.hire` **y** `PacingSimulator` (en el barrido de
backfill de pisos superiores). No duplicar la condición: es exactamente el error
que el `balance-log` documenta para la fórmula de costo —"antes la fórmula estaba
duplicada en los dos lugares; unificarla evita que el simulador cotice distinto
que el juego"— y no hay motivo para repetirlo.

`hireQuote` **no cambia**: sigue devolviendo tipo y costo aunque el gate esté
cerrado, porque el botón los muestra igual. El permiso viaja aparte.

### El botón

`SpawnButtonView` ya tiene dos estados especiales (piso lleno, piso bloqueado).
Suma un tercero, con el patrón legible ya establecido en el proyecto: texto ink +
desaturación leve, **nunca** `.disabled` (su dimming baja el texto a ~0.3 y lo
vuelve ilegible — bug ya arreglado una vez).

Proyección nueva en `GameState`: `visibleFloorAllowsHiring`, comparada antes de
escribir como el resto de `refreshProjections`.

Claves nuevas es/en en `Localizable.xcstrings`, en el mismo commit que su vista.

---

## Cambio 2 — La secuencia

### Orden

```
pop + partículas del merge     inmediato — es manipulación directa, no se toca
        ↓
vuelo de ascenso               0,7 s
        ↓
reveal del personaje nuevo     ~2 s
        ↓
celebración de piso nuevo      ~1,3 s
        ↓
sheet de skin de milestone     lo cierra el jugador
        ↓
toast "ya podés contratar acá" ~2 s, autocierra o se toca
```

El pop del merge queda instantáneo a propósito: es la respuesta al gesto del
jugador y demorarla haría sentir el juego trabado. La regla del proyecto ya
distingue los micro-rebotes de <150 ms de manipulación directa, que se
conservaron incluso con Reduce Motion.

### Cómo

**Las tres animaciones de escena se encadenan dentro de `BoardScene`**, que ya es
dueña de ellas; `SKAction` las secuencia naturalmente y cada una recibe un
completion. No hay estado nuevo que sincronizar entre módulos para esta parte.

**Las dos superficies de SwiftUI esperan a que la escena termine.** `GameState`
deja de publicar `skinAward` en el instante del merge: lo **retiene** y lo publica
cuando la escena avisa que terminó (`celebrationsDidFinish()`). El toast se
publica cuando el sheet se cierra (`skinAward` vuelve a `nil`).

Si no hay skin que otorgar, el toast va directo después de la escena. Si no hay
piso nuevo, no hay cadena: todo sigue como hoy.

**Reduce Motion sale gratis**: colapsa las duraciones de cada paso, pero la
secuencia se mantiene porque encadena por completion y no por delays fijos. Ésa
fue la razón principal para descartar la alternativa de escalonar con offsets
calculados: los tiempos cambian con Reduce Motion y un offset fijo no puede
esperar a un sheet que cierra el jugador.

### Qué floor nombra el aviso

Al desbloquear el piso `U`, el conjunto de pisos que pasan de no-contratables a
contratables es:

- caso normal: `{U - 1}`
- caso tope (`U` es el último): `{último - 1, último}` — el de abajo por la regla
  general y el último por el escape

El toast nombra **el más bajo** de ese conjunto: es el que el jugador va a querer
rellenar y da una sola regla para los dos casos. Se calcula con una función pura
`newlyHireableFloors(before:after:)`, no comparando ordinales a mano en el sitio
de llamada.

---

## Qué se testea

**EconomyKit (puro):**
- `canHire`: piso 0 siempre; con `ordinal + 1` desbloqueado sí y sin él no; el
  escape habilita el último piso, que si no nunca se abriría.
- `hire` tira `hireLocked` y **no** cobra monedas ni ocupa slot.
- `newlyHireableFloors`: caso normal devuelve uno, caso tope devuelve dos, y no
  devuelve nada cuando el unlock no destraba a nadie.

**App (wiring):**
- El `skinAward` no se publica en el instante del merge y sí después de
  `celebrationsDidFinish()`.
- El toast no se publica mientras el sheet está arriba.
- La proyección `visibleFloorAllowsHiring` sigue la regla.

**UI / visual:** una captura por paso de la cadena en el ascenso que abre Urban,
para confirmar que se ven de a uno. El smoke `testCharactersStayVisibleAfterTheFirstAscent`
ya recorre ese camino y **hay que ajustarlo**: hoy espera 3 s fijos tras el merge
y ahora la cadena dura más.

---

## Riesgos

1. **Pacing.** El gate cambia lo que el bot puede hacer, así que `PacingTests`
   puede moverse. Están pineados a la conducta real por decisión explícita del
   dueño (`balance-log §F7.6`). **Si se mueven, se le traen los números antes de
   re-pinear nada** — no se toca balance por cuenta propia. La expectativa es que
   el impacto sea chico: el bot ya sólo hace backfill cuando es rentable, y el
   diseño dice que eso pasa con la frontera 2-3 pisos arriba, o sea casi donde cae
   el gate.

2. **Migración de partidas en curso.** Un save existente puede tener unidades en
   un piso que bajo la regla nueva todavía no permitiría contratar. Eso está
   bien y no requiere nada: el gate es sobre la ACCIÓN de contratar, no sobre
   tener unidades. `TowerReconciler` no se toca.

3. **El smoke del ascenso se vuelve más lento.** La cadena secuencial suma ~2 s
   al camino que el test recorre. Es un ajuste de espera, no un cambio de
   contrato.

4. **La escena tiene que avisar que terminó.** Es acoplamiento nuevo escena →
   `GameState`. Se mantiene chico: un solo método sin parámetros. Pero si la
   escena nunca avisara, el sheet de skin no aparecería **y el smoke no lo
   detectaría**: `dismissSkinAward` usa `waitForExistence` con `guard`, así que
   tolera que el sheet no esté (a propósito — su presencia depende de
   `fisuTutorialDone`, que `--uitest-reset` no controla). O sea que esa regresión
   sería silenciosa por ese lado.

   Por eso **el guardián de que el award se publica es el wiring test**, no el
   smoke: un test de `GameState` que verifique que tras `celebrationsDidFinish()`
   el `skinAward` está publicado. El smoke sigue cubriendo lo visual.

---

## Fuera de alcance

- Hacer el número configurable. Hoy es una constante en `canHire`; si mañana se
  quiere tunear, va a `economy.json`, no a código.
- Rebalancear costos de contratación. La regla de precios de `balance-log`
  (300× el click del piso, 50 en el callejón) no se toca.
- Encolar cualquier otra celebración del juego (daily, specials, eventos): esta
  cadena es la del ascenso que abre piso.
