# E14 — Correcciones del dueño antes de la App Store (2026-10-12)

> Pedido del dueño en el chat, corrección por corrección, antes de subir la 2.0. **Prioridad sobre
> la cola de `tasks.md`.** Las referencias visuales viven en `Docs/correcciones-v2/`. Regla de
> siempre: FisuJobs es la referencia visual y la gramática v3 es canon; el arte nuevo se genera en
> `automatic-image-generation` y entra por `Tools/asset-pipeline/dropbox/`.
>
> Estado: **recolectando** — no se implementa nada hasta que el dueño cierre la lista.

| # | Corrección | Toca | Arte nuevo | Estado |
|---|---|---|---|---|
| C1 | Fondos de piso: fuera los videos, sólo la foto | `FloorNode`, `BoardScene`, `loops_manifest.json` | no | anotada |
| C2 | El visitante camina al medio y abre un popup; fuera el globo de abajo | `StageLayout`, `StageController`, `SpeechBubbleNode`, `VisitorPopupView` | no (usa los clips) | anotada |
| C3 | La tarjeta del personaje especial, más chica y siempre arriba a la derecha | `StageChips` (`VisitorChip`, `ChallengeChip`), columna de juego | no | anotada |
| C4 | Toda recompensa se ilustra: visitantes, eventos, Ruleta, Colchón, Paquete | popups de premio, `WheelView`, `MattressPopupView`, `EventPopupView` | **sí: 13 ilustraciones** | prompts listos |
| C5 | Rotación pareja de visitantes; el vendedor deja de tener carril propio; decirle que no a cualquiera | `VisitorScheduler`, `visitors.json`, `VisitorPopupView` | no | anotada |
| C6 | El visitante se queda en el piso donde apareció | `StageController`, `BoardScene` (capa del piso) | no | anotada |
| C7 | Viaje en ascensor: por las ventanas se ve la torre pasando, piso por piso | `ElevatorRideView`, `ElevatorCabin`, `BoardScene` (cámara) | quizás (ventanas de la cabina en video) | anotada |

---

## C1 — Fondos de piso: fuera los videos, sólo la foto

**Lo que dijo el dueño:** el fondo en buena calidad sólo se ve al cambiar de escenario; ya en el
escenario aparece el video del fondo, que se ve notablemente peor. Sacar los videos del fondo y
usar solamente la foto, que está en mejor calidad.

**Por qué pasa (verificado en el código):**

- `FloorNode.render` (`Scenes/Nodes/FloorNode.swift:73-96`) monta la foto `bg_<escenario>.jpg`
  y, si `loops_manifest.json › floors` tiene clip, le pone encima un `LoopingVideoNode` con la
  foto como póster.
- `BoardScene.applyBackgroundAnimation` (`Scenes/BoardScene.swift` ~1701-1734) prende el video
  sólo en el piso visible y quieto. Por eso, durante el cambio de piso se ve la foto y al
  asentarse entra el video.
- Las fotos están a **2048×2048** (`Resources/Backgrounds/bg_*.jpg`) y los videos a
  **1024×1024** (`Resources/Backgrounds/Loops/bgloop_*.mov`, 10 clips, 6,7 MB). El video tiene
  la mitad de la resolución y encima compresión.

**Qué hacer:**

1. El piso muestra siempre la foto: se retira el `LoopingVideoNode` de fondo en `FloorNode`
   (`backgroundVideo`, `setBackgroundAnimating`, `hasBackgroundVideo`) y el
   `applyBackgroundAnimation` del tablero con sus llamadas.
2. Se saca la sección `floors` de `loops_manifest.json` y los 10 `bgloop_*.mov` del bundle
   (≈ 6,7 MB menos). Hay que revisar quién más lee `.floor(...)` antes de borrar:
   `LoopsManifest.swift`, `VisitCopy.swift`, `GameState+Upgrades.swift`, el Estudio de assets y
   `VideoPlaybackPolicy` (el tope de 3 videos libera un lugar).
3. Se limpian los tests y fixtures del fondo animado y lo que diga «fondo animado» en Ajustes,
   el tutorial o el Tour, si existe.

**Listo cuando:** en cualquier piso, quieto o después de un viaje en ascensor, se ve la foto de
2048 sin un solo frame de video; no queda `bgloop_*` en el bundle; el `rapido` está verde.

**Abierto:** el dueño habló de fondos «en 4K». Hoy no hay fuente 4K: las fotos del juego son
2048 (las de `fisu-evolution-v2/output`, reescaladas desde originales de 1254). Default: quedan
en 2048. Si se quieren en 4K, es un reescalado aparte (más peso en el bundle).

---

## C2 — El visitante camina al medio y abre un popup

Referencia: `Docs/correcciones-v2/C2-visitante-tapa-botones.jpg`.

**Lo que dijo el dueño:** el personaje especial que viene a decir algo hoy se para abajo de la
pantalla. Él y su globo tapan los botones (Regalos, la ficha del Fisura) y la zona de juego, y
estorba mucho. Tiene que venir caminando hasta el medio de la pantalla, **justo donde el fondo
corta con el piso** (el horizonte), y al llegar, en vez del cuadro de texto, abrir un popup con su
animación hablando, la frase y los bonus que ofrece. El popup se puede rechazar: el visitante se va
y no estorba el juego.

**Hoy (verificado):** `StageLayout.baselineY = bottomInset + cellSize * 0.25`, o sea que se para
pegado a la barra de abajo. `StageController.wait` dibuja el `SpeechBubbleNode` sobre su cabeza.
El popup (`VisitorPopupView`) existe, pero sólo se abre si tocás al visitante o el chip.

**Qué hacer:**

1. El punto de parada pasa a la línea del horizonte del fondo del piso: el borde fondo/piso de la
   foto. Se mide por escenario: se suma un `horizon` (fracción de la altura) por fondo en
   `floors` o en `assets_manifest › backgrounds` y se calibra mirando las 10 fotos. El visitante
   queda centrado en x.
2. Entra caminando con su clip de caminar (o el de `characters` o `talking`, con su
   póster) hasta ese punto. Con Reduce Motion aparece sin caminar.
3. Al llegar **no hay globo**: se abre solo el popup del visitante (el `SpeechBubbleNode` del
   escenario se retira). El popup lleva:
   - su animación hablando (`talking`, y si no hay, `portrait`), grande;
   - la frase en el globo del popup, como hoy;
   - la **ilustración de lo que ofrece** (C4) y los botones de opción;
   - un botón de **«No, gracias»** explícito, además de la cruz. Rechazar = se va caminando y
     termina la visita (sin penalidad, salvo que la mecánica ya la tenga, como el comisario).
4. Si el jugador cierra el popup sin elegir, el visitante queda esperando en el horizonte y su
   tarjeta (C3) lo reabre. No vuelve a abrir el popup solo.
5. Cuidado con las colas: el popup no se abre encima de una celebración, un ascenso, el tutorial
   o el viaje en ascensor. Espera su turno en la cola de popups que ya existe.

**Listo cuando:** en un SE y en un 17 Pro Max, ningún visitante ni su texto tapan la barra de
abajo, la ficha del Fisura ni Regalos. El popup sale solo al llegar, se puede rechazar, y los UI
tests de visitantes están actualizados (hoy tocan al actor o al chip).

## C3 — La tarjeta del personaje especial, más chica y arriba a la derecha

**Lo que dijo el dueño:** la tarjeta del Vendedor Ambulante, el Puntero, el Turista Yanqui o
cualquier especial que aparezca tiene que estar **siempre en la esquina superior derecha, por
encima de todo**, y **más chica** (en la captura, la flecha «SMALLER» va del chip del camión al de
la tarjeta: hoy ocupa todo el ancho). Ese es el lugar fijo del personaje especial. Al tocarla, abre
su popup con animación y mensaje (C2).

**Qué hacer:**

1. `VisitorChip` y `ChallengeChip` pasan de la fila centrada bajo el HUD a la esquina superior
   derecha, debajo del HUD y al costado del botón de herramientas (o en su lugar, si el dueño lo
   decide al verlo). Tamaño compacto, del alto del chip del camión: la cara animada o el retrato,
   el «!» que late y, como mucho, el nombre corto (o sólo la cara).
2. Va por encima de cualquier otra capa del tablero (z / overlay), pero debajo de los popups.
3. Mantiene la accesibilidad de hoy: es el objetivo de toque de VoiceOver.

**Abierto:** si convive con el botón de herramientas en esa esquina o si lo desplaza. Default: va
debajo de las herramientas, alineada a la derecha.

## C4 — Toda recompensa se ilustra

Referencia: `Docs/correcciones-v2/C4-referencia-cow-evolution-premio.webp` (el popup «Hidden
Treasures» de Cow Evolution: el premio grande en el centro con rayos detrás, la pregunta y un
botón de video).

**Lo que dijo el dueño:** una recompensa nunca se describe sólo con texto: siempre hay una imagen
que la ilustra. Vale para los popups de visitantes y especiales (el asset del personaje **y** el
de la recompensa), los eventos, la Ruleta y el Colchón. Donde el premio es al azar, una imagen
que muestre todas las posibilidades. Es prioridad en todo el juego.

**Qué hacer:**

1. Un componente único `RewardIllustration(kind:)`, que mapea cada tipo de efecto a su imagen
   y lleva los rayos dibujados en código detrás (estilo Cow Evolution, en la paleta de la casa).
   Va en `VisitorPopupView`, `EventPopupView`, `MattressPopupView`, la hoja del Paquete,
   `WheelView` (antes de girar: `rw_mystery_all`; al caer: la del premio) y las ofertas.
2. El mapa (de `visitors.json`, `events.json` y `wheel.json`):

| Efecto | Imagen |
|---|---|
| `coinsSeconds` | `rw_coins` (nueva) |
| `incomeMultiplier`, `passiveMultiplier` | `rw_income_mult` (nueva) |
| `tapMultiplier` | `rw_tap_mult` (nueva) |
| `spawnCostMultiplier` | `rw_hire_discount` (nueva) |
| `clearBoostCooldowns` | `rw_boost_refresh` (nueva) |
| `evolveBestUnit` | `rw_evolve` (nueva) |
| `grantUnit` | `rw_free_unit` (nueva) |
| `exchange` | `rw_exchange` (nueva) |
| `fine`, `fee`, `take` | `rw_fine` (nueva) |
| `arrest` | `rw_arrest` (nueva) |
| `spendingFrozen` | `rw_frozen` (nueva) |
| `oro` | `ui_oro` (existe) |
| `package`, `packageRateMultiplier` | `pickup_package_full` / `ui_oro_package_rain` (existen) |
| `skinChest` | `ui_chest_closed` (existe) |
| `wheelSpin` | `wheel_icon` (existe) |
| `gift` | `ui_gift_bow` (existe) |
| Ruleta o Colchón antes de abrir (premio al azar) | `rw_mystery_all` (nueva) |
| El Colchón abierto | `rw_mattress_treasure` (nueva) o el clip `colchon_abre` |
| `modifier`, `gossip`, `callVisitor`, `video` | según lo que termine dando; si no da nada, sin imagen |

3. Arte: proyecto `fisu-v2-premios` en `automatic-image-generation` (13 prompts escritos, con
   el estilo de `references/style/icon.png`, la familia de los `ui_oro_*`). Motor Gemini con el
   modelo **Flash**, modo `game-asset` (384 y 512). Entra por el `dropbox/` del pipeline como
   siempre y pasa por la revisión del dueño.

**Listo cuando:** ningún popup que ofrece o entrega algo muestra el premio sólo como texto, y la
Ruleta y el Colchón muestran sus posibilidades con imagen antes de jugar.

## C5 — Rotación pareja de visitantes; fuera el carril del vendedor

**Lo que dijo el dueño:** «Me pasé el juego y me apareció muchísimas veces más el vendedor
ambulante que la vieja chusma, el ministro de Economía, el turista yanqui… creo que apareció más de
10 veces el vendedor y ni una sola vez el turista ni la vecina.» El vendedor aparece muy seguido y
estorba. Tiene que pasar más lento, los personajes se intercalan, ninguno es más probable que
otro, en general te toca uno distinto cada vez y aparecen **todos** con su chiste y su ventaja.
Al tocar a cualquiera (en especial al vendedor) se le puede decir que no y se va.

**Por qué pasa (verificado en `VisitorScheduler.swift` y `visitors.json`):**

- El vendedor tiene **carril propio** (`lane: vendor`): un reloj aparte cada
  `vendorIntervalSeconds` = 180 s ± 30, con `dailyCap` = **20**. El resto comparte el carril
  principal, cada 240–360 s. El vendedor sale más seguido que **todos los demás juntos**.
- El carril principal sortea **guiones por peso**, no visitantes. Un visitante con dos guiones
  (comisario, sindicalista, puntero, vecina…) pesa el doble. El `antiRepeat` = 3 mira guiones,
  así que el mismo personaje puede volver con su otro guion.
- Muchos guiones se filtran por `isOfferable` (`take` o `sale` necesitan duplicados) y por
  `minTier`, y con un solo lugar en escena el carril del vendedor, más corto, gana la carrera.
  **Hipótesis a confirmar con el simulador:** con un visitante por vez, el principal choca con el
  vendedor ya en escena, cae en `retrySoon` y queda muerto de hambre. Eso explicaría «ni una sola
  vez el turista».

**Qué hacer:**

1. **Un solo carril.** El vendedor entra a la rotación como uno más: se retiran `lane`,
   `vendorIntervalSeconds` y `vendorJitterSeconds` (la validación «el vendedor, y sólo él, va por su
   carril» se va con ellos), y su `dailyCap` baja a lo de los demás (2).
2. **Bolsa barajada por visitante, no sorteo por peso.** Entre los visitantes elegibles
   (desbloqueados por `minTier` y con algún guion ofrecible), cada uno sale **una vez** antes de
   que alguno repita. Al vaciarse se rebaraja, sin repetir el último en el borde de la bolsa. Dentro
   de un visitante, sus guiones se alternan. El `weight` deja de decidir quién viene (queda, como
   mucho, para elegir entre los guiones de un mismo visitante).
3. Si el elegido no tiene guion ofrecible ahora, se pasa al siguiente de la bolsa y él queda
   primero para la próxima. No se pierde el turno ni se reintenta a los 30 s con el mismo.
4. La bolsa y el último visitante se guardan en el save (los campos nuevos opcionales, con
   migración sin pérdida).
5. **Decir que no** (de C2): en el popup de cualquier visitante, incluido el vendedor, un «No,
   gracias». Se va caminando y la visita cuenta como hecha, así la bolsa avanza.
6. Test de EK: en una simulación de N visitas con todos desbloqueados, ningún visitante sale más
   de una vez por vuelta de bolsa, y en 2 vueltas salen todos los elegibles. Test de regresión:
   el vendedor no puede salir dos veces seguidas.
7. Correr el simulador de pacing (`Tools/v2`) para medir cuánto cambia el ingreso por visitantes
   al bajar el vendedor de ~20 a ~2 por día. Si el pacing se mueve, se ajusta y se avisa (Dios a
   ~45 h es decisión cerrada).

**Listo cuando:** una partida simulada hasta Dios muestra a los 18 visitantes, con conteos
parejos entre los desbloqueados al mismo tiempo, y el vendedor en la misma proporción que el resto.

## C6 — El visitante se queda en el piso donde apareció

**Lo que dijo el dueño:** si cambiás de piso, el personaje tiene que quedarse en el piso en el que
apareció. Hoy se mueve con vos, y se ve raro.

**Hoy:** el `StageController` cuelga al actor de la capa de la cámara, no de la del piso.

**Qué hacer:**

1. La visita guarda el `ordinal` del piso donde apareció, y el actor se cuelga del `FloorNode` de
   ese piso (o de una capa con su mismo desplazamiento). Al scrollear o usar el ascensor, se va con
   su piso.
2. El popup automático (C2) sólo sale si estás mirando ese piso. Si no, queda la tarjeta de la
   esquina (C3), que al tocarla abre el popup directo, sin viajar. Default: la tarjeta lleva el
   número de piso chiquito.
3. La paciencia del visitante corre igual, estés o no en su piso.
4. Si el piso se recicla (sale del rango vivo de `floorNodes`), el actor se vuelve a montar al
   volver, con el mismo estado.

**Listo cuando:** con un visitante esperando en el piso 3, viajar al 7 y volver lo muestra en el 3,
nunca en el 7. Test de UI o de escena que lo cubra.

## C7 — Viaje en ascensor: la torre pasa por las ventanas

Referencia: `Docs/correcciones-v2/C7-ascensor-ventanas-negras.webp` (captura en pleno viaje: las
dos ventanas de las puertas son negras y el visor dice ▲1).

**Lo que dijo el dueño:** en la transición del ascensor no se ve el fondo. Antes del kit del
ascensor había una transición que recorría la torre con todos los pisos apilados. Hay que hacer lo
mismo pero con el kit del ascensor encima, de modo que por las ventanas se vea cómo se avanza por
todos los pisos.

**Hoy (verificado):**

- `ElevatorRideView` ya intenta esto: en `.traveling` pinta `backdropLayer`, con miniaturas de los
  fondos de `plan.passingOrdinals` (`FloorBackdrops`, achicadas al 60 % si son más de 5) que pasan
  detrás, y encima la cabina.
- La cabina se resuelve en `ElevatorCabinArt.resolve`: **gana el video**
  (`cabina_puertas_cierran/abren.mov`, matte verde) sobre los PNG. En `cabina_cerrada.png` las
  ventanas **sí son transparentes** (alfa 0, medido), pero el video sólo recorta el verde de
  afuera: sus ventanas son gris oscuro opaco. Hipótesis principal: durante el viaje queda el último
  frame del video de cierre, con las ventanas tapadas. Hipótesis a descartar: las miniaturas no
  llegan a cargar (la `task` es async) y debajo hay negro.

**Qué hacer:**

1. Lo que pasa por la ventana es **la torre real apilada**, como la transición vieja: los pisos uno
   arriba del otro, en continuidad, con sus fotos buenas (C1) y sus personajes, desplazándose a la
   velocidad del viaje. Dos caminos, a elegir midiendo en el SE:
   - (a) mover la cámara del `BoardScene` por la torre durante el viaje (la transición vieja; hay
     que ver en `git log` cómo era antes del kit) con la cabina SwiftUI encima;
   - (b) seguir con `backdropLayer`, pero con las fotos apiladas sin hueco, a resolución
     suficiente y precargadas antes de cerrar las puertas.
   Preferencia: (a), porque es literalmente «la torre» y ya existió.
2. **Ventanas transparentes durante todo el viaje:** en `.traveling` la cabina se pinta con el
   PNG cerrado (ventanas con alfa 0) y no con el último frame del video. Si se quiere el video
   también en el cierre o la apertura, hay que re-exportar los dos `.mov` con las ventanas en
   verde de croma para que se recorten. Si no, una máscara con la forma de las ventanas encima del
   video.
3. Las puertas abren con el piso destino ya detrás, como hoy. El visor ▲N cuenta los pisos que pasan.
4. Viajes largos (1 → 30): se acelera en el medio y se frena al final. Se ve pasar la torre sin que
   el viaje dure más que hoy. El tope de memoria del SE manda: medir.

**Listo cuando:** en un viaje 1 → 10 en un SE se ven por las dos ventanas los pisos pasando en
orden, sin negro en ningún frame, y el visor llega al número del destino cuando abren las puertas.
