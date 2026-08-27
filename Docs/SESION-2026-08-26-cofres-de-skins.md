# Sesión 2026-08-26/27 — Los cofres de skins

**Rama**: `feat/cofres-de-skins` (worktree `fisu-wt-cofres`), 32 commits sobre `origin/main`
@ `0df3cba`. **Sin mergear ni pushear**: faltan las tareas 9 a 12.

## Qué se pidió

Cambiar cómo se obtienen las skins e introducir **cofres con premio aleatorio**, con una
animación "super entretenida y sorpresa — es lo que más garpa del sistema de cofres",
interactiva al estilo Clash Royale pero con la estética de FisuEvolution.

## Las ocho decisiones del dueño

1. Las 41 pintas de piso pasan a ser **exclusivas del cofre**: dejan de otorgarse al llegar.
2. Un **cofre temprano en el tutorial**, para enseñar la mecánica ahí.
3. **Rareza + sin repetir dentro de ella.**
4. Si la rareza sorteada está agotada, **sube** a la siguiente con stock.
5. Las **cuatro** fuentes: cada 2 pisos, video, día 7 y reencarnación.
6. El primero se abre solo; **el resto se guardan**.
7. Se mantiene la palabra **"cofre"** para las pintas y **se renombra** lo viejo (el asado
   pasa a pagar "una picada"). Las estrellas van **dibujadas** (PNG), no en código.
8. **La migración v5 reescala sólo las líneas por encima del tope**, no las tres — para no
   tocarle nada a lo comprado legítimamente post-rebalance. Costo aceptado: la línea parada
   exacto en el tope sigue pudiendo llevarse las doradas, y ese agujero **creció** respecto
   del comportamiento anterior (antes bajaba de rebote cuando el save disparaba la huella).

## La bolsa, medida contra los datos reales

De las 131 skins del catálogo, la bolsa son las **41** que llevaban `floorReached`. La rareza
sale del piso donde **vive** el personaje:

| Rareza | Pisos | # | Peso |
|---|---|---:|---:|
| Común | `alley` + `urban` | 7 | 55 |
| Rara | `corporate` + `luxury` | 14 | 28 |
| Épica | `island` + `moon` + `mars` | 12 | 12 |
| Legendaria | `solar` + `galaxy` | 8 | 5 |

⚠️ **"Rara" tiene 14 y no 8 porque el piso corporativo tiene DIEZ personajes**: la
bifurcación de carrera mete cuatro `junior` en T11 y cuatro `senior` en T12. Es el único piso
que no tiene cuatro.

**Por qué la promoción de rareza y no "pagar plata cuando se agota"**: hay 7 comunes con peso
55/100, así que se agotan cerca del cofre 12. Sin promoción, desde ahí **más de la mitad de
los cofres pagaría plata con 34 skins sin sacar**. Con promoción, todo cofre abierto antes de
completar da una skin nueva —41 exactos— y como todo promociona hacia arriba, **las
legendarias quedan para el final**: la colección termina en crescendo.

## Lo que está construido (8 tareas cerradas)

| # | Qué | Commits |
|---|---|---|
| 1 | Las 41 salen del evaluador de milestones (`chestRarity` en vez de `floorReached`) | `eeec7d6`, `d1901eb` |
| 2 | `ChestRoller` + `ChestsConfig` + `chests.json` | `4ca017c`, `e80d17f` |
| 3 | Save **v5** + el arreglo de las doradas | `20f91d2`, `3fe4c4f` |
| 4 | Las cuatro fuentes | `c8d42be`, `7bfe3cf` |
| 5 | `openChest()` + `.chestOpening` en la cola | `71c6d8c`, `50fc7c0` |
| 6 | El renombre (el asado paga "una picada") | `0ae1863`, `ab36b02` |
| 7 | Los 7 assets al atlas y al manifest | `f041c53` |
| 8 | **La animación**, cuatro toques | `4e2bf23` |

**El mecanismo es no tocar `SkinMilestones`**: la entrada declara `chestRarity` **en lugar
de** `floorReached`, y como `isMilestone` se calcula sobre los tres criterios viejos, cae a
`false` sola. No hay forma de que una skin se regale por las dos vías.

## El arte: 7 PNGs, 2 regenerados

Cuatro del cofre (cerrado, forzado, abierto, tapa suelta) y tres de FX (estrella, chispita,
sol de rayos). Los dos que se rehicieron y por qué:

- **`ui_chest_open`** salió como una batea chata vista desde arriba, con otra cámara y otras
  proporciones que el cerrado. Como uno reemplaza al otro durante el estallido, el swap
  saltaba. El prompt v2 abre con la restricción de silueta, ancho, alto y cámara.
- **`fx_burst_rays`** tenía **los huecos entre rayos rellenos de negro** en vez de
  transparentes. Eso rompía el mecanismo central: el juego tiñe con `colorMultiply` y el
  negro multiplicado sigue negro, así que el anuncio de rareza —el latido que hace toda la
  anticipación— habría quedado muerto, y además tapaba la pantalla detrás del cofre.

Los tres FX van en **crema con contorno negro** a propósito: multiplicados, el contorno
sobrevive y sólo el relleno toma el color. Verificado simulando el multiply con los cuatro
colores **antes** de integrar.

⚠️ `ui_chest_open` sigue sin calzar exacto con el cerrado (algo más ancho y girado). Se
compensa con escala y offset en el estallido; el flash de 80 ms tapa el resto. **No se
regenera de nuevo.**

## La animación

Overlay del `ZStack` de `RootView`, **no un `sheet`**. Cuatro toques: tres para forzar el
candado y uno para dar vuelta la carta. **La rareza se anuncia en el segundo toque**, con el
cofre todavía cerrado: los rayos se tiñen y aceleran. Ver dorado antes de saber qué salió es
el mecanismo central.

Hápticos con el vocabulario **semántico** que el juego ya tiene: `.merge` (un transient),
`.purchase` (dos), `.rarity` (tres en crescendo), `.evolution` (el más grande) en el
estallido. Un golpe, dos golpes, tres que suben.

Dos mejoras del implementador sobre el spec, aprobadas:
1. `ChestReward` lleva el monto pagado: la animación apaga el HUD, así que la carta de plata
   habría sido la única celebración que festeja sin decir cuánto.
2. **Con plata también vuela la carta boca abajo** y la moneda va en la cara. El spec pedía
   una moneda volando suelta, pero eso **delata el resultado un latido antes** y le saca el
   cuarto toque justo a los cofres del premio menor.

## Lo que queda

- **Tarea 9** — la tarjeta en Regalos y el puntito. **Bloqueante para jugarlo**: hoy los
  cofres se acumulan y `openChest()` existe pero ningún botón lo llama. Sólo la puerta de
  debug.
- **Tarea 10** — el carrusel de Pintas muestra sólo personajes vistos **en esta partida**, y
  se resetea al reencarnar: ganás la pinta del Emperador Cósmico a los 20 minutos y no podés
  verla.
- **Tarea 11** — el cofre de bienvenida del tutorial, con premio **fijo** (`welcomeSkinId`).
- **Tarea 12** — cierre: build, suite de UI, jugarlo, y decidir dos cosas que quedaron
  anotadas (`floorReached` sin dato que lo ejerza, y verificar que `ach_skins_5`/`_20` vuelvan
  a ser alcanzables).
- **Para el dueño**: un save v4 parado en el piso 8 **cobra 4 cofres de golpe** al actualizar,
  y el número depende de *cuándo* actualiza (recién reencarnado cobra 0). Es balance, no bug;
  el arreglo es una línea en `migrateV4toV5`.
- **28 menores diferidas** en el ledger, para triagear en el review final de rama.

## Verificación al cierre de la tarea 8

EconomyKit 262/262 · app 438 con **exactamente los 12 rojos declarados** (11 StoreKit por el
runtime 26 + `PacingTests.theOwnersTargetsAreMet`) · **UI 49/49 sin un rojo** · cero warnings.
La animación **se miró en el simulador** abriendo cofres de verdad; capturas en el workspace
del ledger.
