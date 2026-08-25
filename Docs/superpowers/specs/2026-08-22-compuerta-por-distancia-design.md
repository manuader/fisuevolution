# Decisión de diseño — La compuerta de contratación pasa a medirse en TIERS

**Fecha**: 2026-08-22 · **Pedido del dueño** · **Estado**: decidido, pendiente de calibrar N

## El pedido, textual

> "el mayor problema es que siempre que se sube a un piso nuevo, es muy barato/facil
> comprar los personajes del piso anterior. por lo que el usuario nunca termina usando
> el ascensor, solamente baja al piso que esta inmediatamente arriba o abajo."
>
> "la idea es que comprar los personajes sea mas dificil y que el usuario tenga que
> mergear desde varios pisos mas abajo para poder desbloquear un nuevo personaje."
>
> Sus dos candidatas: (A) bloquear la compra hasta tener **dos pisos** desbloqueados
> por encima; (B) desbloquear un personaje cuando ya tenés **5 o más personajes
> arriba** desbloqueados. Con el Fisura exento en las dos: la dinámica corre del
> Trapito (T2) para arriba.

## El diagnóstico: la compuerta de hoy tiene un borde dentado, y el jugador compra por el lado corto

La compuerta actual (`TowerActions.canHire`) se mide en **pisos**: para contratar en
el piso F hace falta que F+1 esté desbloqueado. Pero **FisuJobs vende TODOS los tipos
vistos de un piso habilitado**, y un piso tiene 4 tiers. Entonces:

| lo que comprás | distancia a tu frontera | unidades para hacer 1 de tu frontera |
|---|---:|---:|
| la BASE del piso habilitado (4F+1) | 4 tiers | **16** |
| el TOPE del piso habilitado (4F+4) | **1 tier** | **2** |

La regla dice "un piso de profundidad" pero **lo que ata es el caso más barato: UN
tier, DOS unidades**. Abrís un piso nuevo, bajás uno, comprás el tope de ese piso —
que está pegadito a tu frontera— y con dos de esos ya tenés uno nuevo arriba. Por eso
nunca hace falta el ascensor: todo pasa entre dos pisos contiguos. La queja del dueño
es exacta y el mecanismo es éste.

## La decisión: compuerta por DISTANCIA EN TIERS (la opción B, generalizada)

Un personaje de tier `T` se puede contratar sólo si tu frontera (`maxTierReached`)
llegó a `T + N`. `N` es un knob de `economy.json`.

**El Fisura (T1) queda exento**: es el motor del early game y el tutorial lo enseña.
La dinámica corre del Trapito (T2) para arriba, como pidió el dueño.

### Por qué B y no A — las dos miden lo mismo, pero A lo hace desparejo

Expresadas en la única unidad que importa (cuántos tiers tenés que mergear):

| | distancia exigida | unidades | forma |
|---|---|---|---|
| hoy (1 piso) | **1 a 4 tiers** según dónde compres | 2 a 16 | **dentada** |
| (A) 2 pisos | **5 a 8 tiers** según dónde compres | 32 a 256 | **dentada** |
| (B) N tiers | **N siempre** | 2^N | **pareja** |

A y B cubren el mismo rango de dificultad. La diferencia es que **A conserva el borde
dentado** —seguiría habiendo un lado barato por el que colarse, sólo que más lejos— y
**B lo elimina por construcción**. Tres razones más para B:

1. **La ronda 2 acaba de morder por concentrar dificultad.** El review encontró un
   acantilado de ×90 entre corporativo y lujo (13,2 h activas, 10 días de pared en UN
   piso, al 90 % del peor muro histórico del juego). Una compuerta por pisos empuja en
   la misma dirección: escalones. Una por tiers reparte.
2. **Es un dial, no un interruptor.** `N` se calibra de a un tier; "un piso más" salta
   de golpe ×16 en unidades.
3. **Deja de necesitar excepciones.** Hoy hay dos parches por piso: el callejón siempre
   habilitado y `hireGateExempt` en el urbano. Con distancia por tier, la única
   excepción es el Fisura, que es una regla de diseño y no un parche.

⚠️ **La contra de A, medida y en la bitácora**: la compuerta de dos pisos ya se probó
(2026-08-04) y **dejó el juego sin terminar** — el bot se trabó en tier 12. Aquello fue
con otra economía y habría que re-medirlo, pero el precedente existe y es la razón por
la que la profundidad de un piso quedó como decisión cerrada (HANDOFF §5). Esta
decisión **la reemplaza explícitamente**: la profundidad deja de medirse en pisos.

### Por qué NO "5 personajes vistos arriba" al pie de la letra

Es la misma idea que B, pero contar TIPOS se rompe en el fork de carrera: los tiers 11
y 12 tienen **4 tipos cada uno**. "5 tipos arriba" ahí significa apenas 1-2 tiers de
merge, justo en el tramo que ya es el más difícil. Contar TIERS es la misma intención
sin el agujero.

## Qué hay que calibrar (no se decide de taquito)

`N` sale del simulador, no de la intuición. Candidatos: **5** (32 unidades, 1,25 pisos),
**6** (64, 1,5 pisos) y **8** (256, 2 pisos — "varios pisos más abajo" literal).

Contratos que no se pueden perder al calibrar (`PacingTests.theOwnersTargetsAreMet`):
maxear las siete líneas en **20-30 h activas**, **≤8 reencarnaciones**, **Dios después
de maxear**, y **sin reencarnar tiene que ser más lento que reencarnando**.

Y la contra a vigilar: con la compuerta más profunda, el juego se alarga solo. Es
probable que haya que **aflojar** knobs que la ronda 1 y 2 apretaron (el ORO, el costo
de las mejoras). Eso es bueno: la dificultad pasa a ser **estructural** (profundidad de
merge) en vez de **numérica** (precios), que es lo que hace que un merge-idle se sienta
un merge-idle.

## Lo que esto le cambia al TUTORIAL

Hoy el guion enseña: tocá → contratá → fusioná → mejoras → mapa. Con la compuerta por
distancia, **contratar deja de ser la respuesta por defecto** y el juego pasa a tener
un bucle explícito que hay que enseñar:

1. **El Fisura es la única compra libre.** Es tu fábrica: de ahí sale todo.
2. **Fusionar es cómo se sube**, no un atajo — cada personaje nuevo sale de 2^N
   compras del que podés comprar.
3. **El ascensor se usa**: comprás abajo y el resultado aparece arriba. La torre pasa a
   leerse de punta a punta en vez de como dos pisos contiguos.
4. **Cuando FisuJobs muestra un personaje bloqueado**, el mensaje tiene que decir la
   regla nueva ("te faltan N tiers"), no la vieja ("falta desbloquear el piso de
   arriba").

El paso del tutorial que hoy dice "contratá" tiene que pasar a "contratá **al Fisura**"
y agregarse un paso que muestre el bucle comprar-abajo → fusionar → aparece-arriba.
