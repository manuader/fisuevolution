# Sesión 2026-08-28 — Los cofres sólo dan personajes desbloqueados

## Qué se pidió

Palabras del dueño: *"hay que hacer que solo te puedan tocar skins de personajes
desbloqueados. no te puede tocar la skin de semidios si recien vas por oficinista. debe ser
una skin que puedas utilizar instantaneamente"*, y al rato la precisión que decidió la
implementación: *"quiero que sea imposible que te toque una skin de un personaje que no
desbloqueaste todavia (en la historia global, por lo que cuenta a los personajes
desbloqueados en reencarnaciones anteriores)"*.

Dos palabras mandan y las dos son literales: **imposible** —no "improbable", no "casi
nunca"— y **global** —la cuenta, no la run—.

## El dato que ordenó todo: la rareza YA era una banda de pisos

Antes de tocar nada, el cruce de `skins.json` con `economy.json`:

| piso | skins | acumulado | rareza |
|---|---|---|---|
| 1 alley | 3 | 3 | común |
| 2 urban | 4 | 7 | común |
| 3 corporate | 10 | 17 | rara |
| 4 luxury | 4 | 21 | rara |
| 5 island · 6 moon · 7 mars | 4 + 4 + 4 | 33 | épica |
| 8 solar · 9 galaxy | 4 + 4 | 41 | legendaria |

**Sin un solo solapamiento**: común = pisos 1-2, rara = 3-4, épica = 5-7, legendaria = 8-9.
La bolsa se había repartido por el piso donde vive cada personaje, así que filtrar por
desbloqueo es casi filtrar por rareza — y por eso el sistema no necesitó rediseñarse, sólo
un filtro en el lugar correcto.

## Dónde vive la regla, y por qué en UN solo lugar

`ChestRoller.stock(of:owned:unlocked:skins:)`. Es el embudo por el que pasan **los tres
caminos** del sorteo: la rareza que salió, la promoción hacia arriba cuando esa se agota, y
la degradación hacia abajo cuando arriba tampoco hay. Filtrar sólo la rareza sorteada y
olvidarse de la promoción es exactamente el agujero por el que la Deidad se le aparecería a
alguien parado en el Oficinista.

⚠️ **`unlocked` no tiene valor por defecto, y eso es la mitad de la garantía.** Con un
default, un call site que se lo olvidara apagaría la regla sin que nada se pusiera rojo. Sin
default, el compilador la sostiene: los ocho call sites de test tuvieron que decir
explícitamente qué desbloqueo estaban midiendo.

## Qué cuenta como desbloqueado

`meta.stats.maxFloorOrdinalEver` — monótono y a prueba de reencarnación, que es exactamente
lo que el dueño pidió con "historia global". Se descartaron `run.unlockedFloors` y
`run.seenTypes`: mueren al reencarnar, así que el veterano que acaba de reencarnar volvería
al callejón, ya tendría las 7 comunes y sus cofres pagarían plata hasta volver a subir.

⚠️ **La granularidad es el PISO y no el tier, y no es una concesión: es lo correcto.**
Filtrar por tier exacto encerraría las pintas de la rama de carrera que el jugador no
eligió —nunca hacés un `junior_doctor` si sos programador—, así que **la colección quedaría
inalcanzable dentro de una run**. Por piso, entrar a corporate vuelve ganables a los diez
corporativos. El residuo es que puede tocarte alguien de tu mismo piso a pocos tiers de
distancia; el caso que la regla persigue queda muerto igual.

## La bolsa seca: el cofre espera, no paga

Decisión del dueño entre tres salidas. La oferta de cofres (~80 por partida) es mucho mayor
que la bolsa alcanzable temprano, así que la situación "tengo cofres y no hay nada que
ganar" es común, no un borde.

- **Mientras queden pintas sin ganar**, el cofre **no se gasta**: `.needsProgress`, y el
  contador no baja.
- **Con la colección completa de verdad** (las 41), paga plata, que es lo que ya hacía.

`coins` es el premio consuelo del que terminó; el que todavía está armando la colección no
tiene que quemar cofres. Confundir los dos casos le cobraría al que recién empieza, que es
justo a quien más le rinden.

## Tres consecuencias que no estaban en el pedido

1. **El cofre de reencarnación deja de garantizar épica en términos absolutos.** Si el
   jugador nunca llegó a un piso épico, el mínimo cede y entrega lo mejor que sí alcanzó.
   Es la lectura correcta de "imposible" —el desbloqueo no cede ante nada— pero es un
   contrato que cambió, y había un test que lo asumía incondicional.
2. **El puntito de Regalos pasó a seguir `canOpenChest` y no al contador.** Con la regla
   nueva se puede tener cofres y no poder abrir ninguno, y un puntito que el jugador no
   puede apagar se queda prendido un piso entero. Es el mismo puntito que usan logros y
   daily: entrenarlo a mentir los apaga a los tres.
3. **La puerta de debug sube un piso simulado si hace falta.** `debugOpenChest()` se moría
   al cuarto toque en una partida nueva (el primer piso reparte tres pintas), y es el botón
   que existe para poder mirar la animación cuantas veces haga falta. Sube el progreso en
   vez de saltear el filtro **a propósito**: saltearlo acreditaría una pinta que el save no
   puede tener, y una puerta de debug que fabrica estados imposibles es una fábrica de bugs
   fantasma.

## Un tipo nuevo, y por qué no fue un caso más

`ChestDraw` (`.prize(ChestOutcome)` / `.needsProgress`) es un tipo aparte de `ChestOutcome`.
Meter `.needsProgress` como tercer caso de `ChestOutcome` compilaba, pero obligaba a **seis
ramas muertas adentro de `ChestOpeningView`** —una por cada `switch` de la coreografía— para
un valor que esa vista no puede recibir. Separados, el tipo del premio sólo modela premios, y
el compilador sigue obligando a `openChest()` a contestar las dos posibilidades.

El compilador fue quien lo señaló: los seis errores de exhaustividad no eran un obstáculo,
eran el diseño avisando que el caso estaba en el tipo equivocado.

## Lo que la vista dice cuando el cofre espera

`StateBadge` apagado con candado, "Subí un piso" / "Climb a floor", en el mismo riel donde
las filas de boosts dicen "se abre en el callejón". No es un `ActionPill` deshabilitado:
**en este juego `ActionPill` nunca usa `.disabled`** —"una acción que no corresponde no se
dibuja"— y `StateBadge` es lo que ocupa su lugar. El número de cofres no cambia: siguen
siendo suyos, y la tarjeta lo sigue diciendo.
