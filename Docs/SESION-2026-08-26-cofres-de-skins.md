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


## Las tareas 9, 10 y 11 — lo que hace falta para que un jugador lo use

### 9 — la tarjeta en Regalos y el puntito

Hasta acá el sistema andaba entero pero **nadie podía abrir un cofre**: `openChest()` existía
y ningún botón lo llamaba. Dos hallazgos que el brief no anticipaba y que la habrían dejado
rota:

- **Regalos es un `.sheet` y la animación vive en el `ZStack` de `RootView`**, así que el
  botón **tiene que cerrar la hoja**: si no, el cofre se abre **debajo**, invisible y sordo a
  los toques, con la cola trabada para siempre. Es el mismo pozo que el contrato del orden,
  alcanzado por otra puerta.
- **`pendingChestCount` sale de `player`, que es `@ObservationIgnored`** y no invalida
  SwiftUI: el puntito **nunca se habría prendido**. Se agregó `hasPendingChests`, gemela de
  `hasClaimableAchievements`.

### 10 — el carrusel de Pintas

`CustomizationView` armaba el carrusel con `seenTypes`, que **muere al reencarnar**. Con
cofres, el sorteo puede darte la pinta de un tier 30 a los veinte minutos y no podrías verla.

⚠️ **El criterio ingenuo habría espoileado el juego, y el mecanismo no era el que el spec
suponía.** En `skins.json` **no hay ni una entrada `characterType == "*"`**: la pinta que
visten todos está escrita con el mismo id **43 veces** (`oro`, `diamante`), porque la
propiedad se guarda por id — y esas dos cubren **exactamente** los 43 personajes concretos.
"Traé al carrusel a todo personaje del que tengas una pinta" le habría desplegado **el
catálogo entero** a quien comprara el paquete de diamante. La regla que lo cierra: **una
pinta que viste a más de uno no trae a nadie**.

Y un segundo defecto que la unión creó: `genesis` (la del Dios, a 3 reencarnaciones) es
milestone **y** exclusiva, así que desde el prestigio 3 el Dios encabezaba la lista **para
siempre** y Pintas abría en la celda 43 de 43 con el scroll en cero. Se resolvió **sin
consultar al dueño** porque su decisión ya estaba tomada (2026-08-17, en el comentario de
`characterUpgradeTypes`: *"la pantalla abre en lo último que hiciste"*): **la unión decide
qué se lista, lo VISTO decide dónde abre**, más auto-scroll.

### 11 — el cofre de bienvenida

Cae al cerrar la fase obligatoria del tutorial, por sus **dos** salidas (el cierre y
"Saltar"), con premio **fijo** leído de `content.chests.welcomeSkinId`. En vez de escribir un
camino nuevo se **extrajo** `presentChestReward` de `openChest()`, así el contrato de
`milestoneSkins` queda en un solo lugar.

⚠️ **Dos correcciones al spec, las dos del implementador:**

1. **La lección `.skins` no había que cambiarla.** El código ya decía `!ownedSkins.isEmpty`,
   que publica `allOwnedSkins` (tienda ∪ milestone), donde el cofre acredita. **Lo viejo era
   el comentario.** Y la propuesta del plan (`|| welcomeChestGiven`) era **peor**: la bandera
   dice que el cofre se dio, no que haya pinta que ponerse —rompía la regla de oro del
   tutorial— y se olvidaba de la vía de la tienda.
2. **El premio estaba mal.** El spec decía "la pinta del Cartonero, el personaje que el
   jugador acaba de fusionar", y son dos personajes distintos: `homeless.mergesInto ==
   "trapito"`, así que el tutorial deja al jugador con **El Trapito (T2)** y
   `urban_trailblazer` es del **Cartonero (T4)**. La carta decía *"para tu Cartonero"* de
   alguien que no conoció. Corregido a `naranjita`. Arregla de paso el aterrizaje de Pintas:
   la pinta nueva queda **en la cara donde la pantalla abre**.

## La animación, después de cinco rondas

Las dos que valen:

- **Las 30 partículas del estallido cambiaban de tamaño cuatro o cinco veces en pleno vuelo**,
  porque el sorteo se rehacía en cada pase del `body` — con un docstring que prometía lo
  contrario. Se mudó el sorteo a `Burst.init`, que corre desde `.task`.
- **La caída del cofre no se veía.** En cuatro corridas y dos ramas, el primer cuadro en que
  el cofre existe ya lo agarraba al 75-92 % del recorrido, opaco. El resorte arrancaba en
  `onAppear` pero el hilo principal quedaba bloqueado ~500 ms armando el overlay, así que la
  animación corría **entera detrás del bloqueo**. Arreglo de una línea: `.task { await
  Task.yield(); dropped = true }`.
  ⚠️ **Y funciona por una razón que no está garantizada**: `Task.yield()` reencola una vez y
  no espera ni el armado ni un cuadro dibujado. Es **un hop calibrado contra el bloqueo de
  hoy**. Cuando aterrice la tarea de `AtlasCache`/`preload` puede volverse innecesario **o
  insuficiente**.

También se midió el costo real del retrato: `UIArt.characterImage` en frío cuesta **~320 ms
de hilo principal**, de los cuales **~215 son `texture.size()`** realizando la página del
atlas. Precalentarlo en la llegada bajó el bloqueo del latido de la carta **un 67 %**.

## Lo que queda

**Once de las doce tareas están cerradas.** El sistema es jugable de punta a punta: se ganan
cofres por las cuatro vías, se ven en Regalos con su puntito, se abren con la animación de
cuatro toques, la pinta se acredita donde StoreKit no la puede borrar, aparece en Pintas
aunque nunca hayas visto al personaje, y el tutorial regala el primero.

**Falta la tarea 12, el cierre**, y es más que trámite:

- **Una corrida limpia de la suite entera sobre el árbol final.** Nunca hubo una: el checkout
  estuvo compartido con otras dos sesiones toda la sesión, así que **cada tarea verificó en un
  worktree aislado propio**. Los números que hay son de once árboles distintos.
- **Jugarlo de verdad**, de cero, con el tutorial incluido. Nadie lo hizo todavía.
- **Confirmar el rojo intermitente** `AscentRenderingUITests.testCharactersStayVisibleAfterTheFirstAscent`
  en vez de heredarlo como "conocido": verde tres veces aislado y verde en la base, rojo bajo
  carga de suite completa. O es carga, o tiene dueño.
- **Triagear las 36 menores diferidas** del ledger
  (`.superpowers/sdd/2026-08-26-cofres-de-skins/progress.md`), una por una. Buena parte son
  de la misma familia —docstrings que quedaron afirmando lo que el código ya no hace— y se
  barren mejor de una sola pasada.
- **La revisión final de rama entera**, que el proceso pide y no se corrió.
- **Levantar la tarea de `AtlasCache`/`preload`** con las mediciones de partida ya hechas
  (~215 ms de hilo principal en `texture.size()`), que es lo caro de reconstruir.

**Y dos cosas que son del dueño:**

1. **Un save v4 parado en el piso 8 cobra 4 o 5 cofres de golpe al actualizar**, y el número
   depende de *cuándo* actualiza: recién reencarnado cobra 0. Se le preguntó y no contestó.
   Tres salidas: dejarlo, rellenar el contador según los pisos que ya tenía, o ponerlo al
   máximo para que la torre sólo pague de acá en adelante. Es una línea en `migrateV4toV5`.
2. **El carrusel de Pintas no se auto-scrolleaba** y ahora sí — pero eso cambió la precondición
   de tres UI tests preexistentes, que pasaron a depender del `scrollToVisible` automático de
   XCUITest. Pasan; es superficie de fragilidad nueva.

## Verificación al cierre de la tarea 8

EconomyKit 262/262 · app 438 con **exactamente los 12 rojos declarados** (11 StoreKit por el
runtime 26 + `PacingTests.theOwnersTargetsAreMet`) · **UI 49/49 sin un rojo** · cero warnings.
La animación **se miró en el simulador** abriendo cofres de verdad; capturas en el workspace
del ledger.
