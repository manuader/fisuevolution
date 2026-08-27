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

## El cierre (tarea 12, 2026-08-27)

**Las doce tareas están cerradas.**

### La corrida limpia, que nunca había existido

El checkout estuvo compartido con otras dos sesiones toda la sesión, así que cada tarea
verificó en su propio worktree aislado: los once "todo verde" que había eran de **once
árboles distintos**, y ninguno del final. Esta es la primera del árbol final, en un worktree
limpio sobre el tip, con la matriz de dos runtimes corrida entera:

| suite | resultado |
|---|---|
| EconomyKit (`swift test`) | **262 / 262** |
| app unit — sim 26.5, Store salteado | **447 tests, 1 rojo** (el declarado) |
| Store unit — sim 18.6 (`StoreManagerTests` + `StoreProductsTests`) | **12 / 12** |
| UI — sim 26.5, `StoreUITests` salteado | **53 / 53, sin un rojo** |
| `StoreUITests` — sim 18.6 | **2 / 2** |

O sea **app 459 con un solo rojo · UI 55 sin ninguno**. Los 447 incluyen el test nuevo del
veterano: el árbol pristino daba 446.

Cero warnings de compilador. Los nueve que tira el build son de herramientas: seis de
`TextureAtlas` partiendo páginas (`ui.atlas` en 3, `earth.atlas` en 6, `cosmic.atlas` en 4) y
tres de `appintentsmetadataprocessor`.

**Dos cosas que la corrida corrigió del propio HANDOFF:**

1. **Los "11 rojos de StoreKit" no existen.** En el sim 18.6 de la matriz pasan los 12. §6
   los contaba como parte permanente del cuadro mucho después de que la matriz —construida
   justamente para eso— los resolviera. El único rojo del proyecto es uno.
2. **El rojo declarado estaba descripto con el motivo viejo.** §6 decía "7,27 h contra las
   20-30 pedidas"; lo que falla hoy es `(reincarnations → 9) <= 8`. El contrato de las horas
   **ya pasa** desde la desaceleración, y el docstring del propio test lo explica bien. El
   documento se había quedado atrás.

### El rojo intermitente: es carga, y tiene número

`AscentRenderingUITests.testCharactersStayVisibleAfterTheFirstAscent` **pasó en la corrida de
suite completa**, en **148 segundos**. Es el test más lento del repo por un factor de tres
(el segundo más lento es `testPerfBaselinePopulatedBoard`, 53 s), porque escala el callejón
fusión por fusión. Esa es la explicación de por qué es siempre el primero en caerse cuando la
máquina está cargada, y por qué pasa aislado todas las veces. **Se anota como sensible a
carga; no tiene dueño.**

### Los dos pendientes del plan, decididos

- **`floorReached` se queda, documentado en el campo.** Ver §5.0-quater del general. En una
  frase: el mecanismo tiene cobertura propia con configs sintéticos, sus dos textos están en
  es y en, y la diferencia con `reincarnations` —que tiene dos filas— es dato, no diseño.
- **`ach_skins_5` y `ach_skins_20` son alcanzables.** `skinsOwned` mide
  `player.meta.allOwnedSkins`, que es `Set(ownedSkins) ∪ milestoneSkins` — y el cofre acredita
  en `milestoneSkins`. Como la bolsa no repite dentro de una rareza hasta agotarla, los
  primeros 41 cofres dan 41 pintas distintas: el logro de 5 cae en el quinto cofre y el de 20
  en el vigésimo, contra una oferta medida de ~80 cofres por partida.

## A. Ya cerradas por rondas posteriores (12) — no hay nada que hacer

| # | Anotada como | Estado hoy |
|---|---|---|
| L23 | `GameContentValidationTests:571-572` tautologías sin decirlo | el comentario dice literalmente "NO pueden fallar, quedan como documentación del invariante" |
| L66 | `SaveMigratorTests:445` da razón FALSA para el 24 | reescrito: "NO para separar el proporcional del clamp" |
| L67 | `SaveMigrator.swift:205` apunta al archivo equivocado | apunta a `Docs/PROMPT-merge-con-rebalance-pacing.md` §6, que existe |
| L68 | `SaveMigratorTests:220` MARK "v1 → v4" | dice "v1 → v5" |
| L70 | los cofres pendientes se pierden en un merge de CloudKit | `SaveConflictResolver:39-40` los mergea por `max`, como el ORO |
| L97 | `GameState.swift` párrafo v5 con el comportamiento viejo | dice "reescala **sólo las líneas que** superan su tope" |
| L107 | `BonusCooldownTests:40` mira un solo video | la lista sale del catálogo y el docstring documenta la trampa |
| L16 | `floorReached` sin decidir | se decide hoy (§5b, abajo) |
| L17 | la suite de UI no corrió | corre hoy |
| L25 | `ach_skins_5`/`20` sin fuente | se verifica hoy (§5c) |
| L211 | 3 UI tests con precondición nueva por el auto-scroll | ya documentado en `selectCharacter:405-407` con dónde mirar |
| L128 | `statsMergeByMax` con 3 de 6 líneas sin cubrir | PRE-EXISTENTE, ajeno a los cofres |

## B. Entran ahora — afirmaciones falsas en comentarios (7)

Un comentario que afirma algo que el código no hace es peor que no tenerlo: el próximo
agente lo lee como verdad. Son todos de la misma familia y se barren de una pasada.

1. `FisuEvolutionTests/GameLoopWiringTests.swift:272` — "este merge abre lujo" es falso (el
   setup ya lo abre; T14+T14→T15 no cambia de piso). La conclusión es correcta, el motivo no.
2. `FisuEvolutionTests/SkinCatalogRowsTests.swift:97-98` — "la igualdad también cubre la
   clave cruda" es falso: los dos lados llaman `String(localized:)` contra el mismo bundle.
3. `FisuEvolution/Persistence/SaveMigrator.swift:181` — "los cuatro disponibles": los videos
   son CINCO desde que entró `skin_chest`.
4. `FisuEvolution/Managers/ContentSystems.swift:265` — "las coins del cofre si fue el Asado":
   el renombre dejó al Asado pagando **una picada**. Tercer sitio de la misma oración.
5. `FisuEvolution/UI/Gifts/GiftsView.swift:257` — "es la única tarjeta destacada" y
   `payoutBanner` también lo es, y pueden convivir.
6. `FisuEvolutionUITests/CustomizationUITests.swift:26` — "la skin del Cartonero, que llega
   por el mismo fixture": `urban_trailblazer` es `chestRarity: comun` y `--uitest-skins`
   filtra por `isMilestone`, así que ya no llega.
7. `FisuEvolutionUITests/CustomizationUITests.swift:17` y `:142` — "el que la pantalla elige
   sola", contradicho por `:131` cuatro líneas abajo ("desde f541bde el default es el
   personaje más nuevo"), que es justo por lo que el test lo toca explícitamente.

**+1 fuera del ledger, y es la más cara**: `Docs/HANDOFF.md` §6 describe el rojo declarado
de `PacingTests.theOwnersTargetsAreMet` con el motivo VIEJO —"7,27 h contra las 20-30"—
cuando el docstring del propio test dice que lo que queda rojo son **9 reencarnaciones
contra ≤8** y que el contrato de las horas **ya pasa**. Es el archivo que el próximo agente
lee para saber qué esperar de una corrida.

## C. Entra ahora — un agujero de cobertura de una línea (1)

`Packages/EconomyKit/Tests/EconomyKitTests/ChestRollerTests.swift:91-98` —
`ochoTiradas(semilla:)` está parametrizado y sólo se llama con `99`. Un `SeededRNG` que
IGNORARA su semilla pasaría los dos `#expect`. Cierra con una línea:
`#expect(tirada != ochoTiradas(semilla: 100))`.

## D. Deuda anotada, con motivo (16)

No entran, y cada una tiene por qué.

- **Peso negativo en `chests.json`** (L50/L52) colapsa la distribución en silencio. Es la
  única de esta lista con consecuencia de producción, pero `chests.json` no se valida al
  cargar **a propósito**: decode-a-secas es el patrón mayoritario (9 configs sin validar
  contra 6 con). Cambiarlo es una tarea de la familia entera, no de los cofres.
- `stock()` recomputa `chestPool` hasta 5 veces por tirada (L51) — irrelevante a 41 entradas.
- `.epica` escrito dos veces sin acoplamiento (L87/L124) — `awardChest` lo declara a sabiendas.
- `skinSelectionVersion` sube con premio plata (L123) — un redibujo al pedo.
- Log sin `privacy: .public` (L129) — mimetiza los ~20 `Log.economy.info` del repo.
- `AdsProvider:29-30` docstring mitad inglés mitad español (L88).
- `day.isChest` nombra un `special_roll` rotulado "Sorpresa"; el esquema de carreras conserva
  `coinChest`/`chestFactor` (L137) — es un renombre de esquema, toca migración.
- `flavorText` ciego (L159) — la familia MÁS expuesta, pero es de contenido, no de cofres.
- `BonusHUDUITests:155` `isHittable` síncrono (L180) — candidato #1 a flakear y es el test
  compuerta del feature. **Si la corrida de UI de hoy lo pone rojo, sube a B.**
- El botón mudo con la cola sirviendo otro kind (L181) — auto-sanable, no pierde cofres.
- Desempate de tier en `skinnableTypes` (L212) — preexistente de bdcc578.
- `daily.prize.chest` escrita tres veces sin atar (L108).
- La anotación de F5 cubre 2 de 3 tests (L218).
- `openSkins` docstring huérfano (L220) — preexistente de 388d44d.
- Tres subscripts en vez de igualdad de diccionario (L98) — idioma del archivo.
- El agujero (2) del reescalado sin test (L99) — daño aceptado, no contrato.


### La decisión del dueño sobre el windfall

**Back-fill**: `migrateV4toV5` arranca `floorChestsAwarded` en los pisos abiertos ÷ 2, así que
el veterano cobra **cero** al actualizar y la torre le paga del piso siguiente en adelante.
Se descartó dejarlo (4-5 cofres de golpe, y el número dependiendo de cuándo actualizara).

⚠️ **Lo que salió a la luz al preguntar**: el veterano **nunca recibe el cofre de
bienvenida**. `grantWelcomeChest()` cuelga de `tutorialPhaseFinished()`, que sólo dispara con
la fase del tutorial viva — y un save v4 la cerró hace rato. Con el back-fill, el que
actualiza no cobra nada por actualizar; gana su primer cofre subiendo un piso. Es coherente,
pero es una decisión y no un accidente: si algún día se quiere que el veterano estrene el
feature con algo en la mano, el lugar es ese, no el contador de la torre.

## Lo que quedó afuera, y por qué

- **La revisión final de rama entera** que el proceso pide. No se corrió.
- **Jugarlo de punta a punta desde cero**, con el tutorial. Los tests lo recorren (hay un
  `testRecorreElTutorialEnteroHastaElFinal` y dos de `ChestOpeningUITests` en verde) y hay 33
  capturas de momentos sueltos, pero **nadie se sentó a jugarlo**.
- **Las 16 menores que quedaron como deuda anotada**, cada una con su motivo arriba.
