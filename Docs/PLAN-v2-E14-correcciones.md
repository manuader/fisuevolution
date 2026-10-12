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
| C8 | La moneda premium deja de llamarse ORO: ahora es el **dólar blue**, con su ícono | `Localizable.xcstrings`, `GameArt` (`ui_oro`), App Store Connect | **sí: `ui_dolar_blue`** | prompt listo |
| C9 | Las dos esquinas de arriba, como Cow Evolution: premios a la izquierda; especial + boosts + relojes a la derecha | `SideRailView`, `ActiveBonusBar`, `StageChips`, `PlayColumn`/`HUDView` | **sí: 4 botones** | prompts listos |
| C10 | La caja y el colchón del tablero: ~90 % más grandes y más arriba, a la vista | `PickupLayout`, `PickupController`, `PickupNode`, `PackageOpeningPlayer` | no | anotada |
| C11 | Todo lo que se paga con dólar blue sale de la Tienda y va a Mejoras; la Tienda queda sólo para plata real | `StoreView`, `OroShopView`, `UpgradesView`, `MenuPagerView` | no | anotada |
| C12 | La barra de abajo: los íconos llenan todo el ancho, escalan por dispositivo y llevan leyenda | `BottomMenuBar`, `GameTabBar` (`GameArtComponents.swift`) | no | anotada |

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

**Resuelto:** el botón de herramientas de esa esquina es andamiaje de DEBUG (`RootView`, apagado en el
modo captura); en Release la esquina está libre. El orden de la columna derecha lo fija C9.

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
| `oro` | `ui_dolar_blue` (nueva, C8) |
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

4. **Pantallas de premio más interactivas, al estilo Cow Evolution** (el dueño, en un segundo
   mensaje: «la ruleta, las cajas y todo lo que te dé premios»). Rige para la Ruleta, el Paquete
   de la Aduana, el Colchón, el cofre de skins, los regalos y los premios de visitantes y eventos:
   - **Antes:** la imagen de lo que puede tocar, grande y con rayos girando detrás. Si es al azar,
     `rw_mystery_all` o, en la Ruleta, **cada gajo con la imagen de su premio** (no sólo el texto).
     Un título corto, una pregunta y un botón grande (video, gratis o precio).
   - **Durante:** el jugador hace algo. La caja o el colchón se tocan para abrirlos (tiembla con
     cada toque y se abre al tercero), la Ruleta se tira con un gesto, el cofre se sacude. Con
     haptics y sonido de los que ya existen. Con Reduce Motion, un solo toque y un fundido.
   - **Después:** el premio **ganado** grande, con su imagen, rayos y un pop con partículas, el monto
     o la duración debajo y un botón «¡Cobrar!». Si se pueden doblar con video, un segundo botón.
   - Todo en la gramática de la casa (`PanelCard`, cinta de título, píldoras caramelo), no la
     estética de Cow Evolution: de allá se toma la **composición y el ritmo**, no los colores.
5. Las hojas que hoy describen premios en listas de texto (las probabilidades del cofre, la tabla
   de la Ruleta) muestran una grilla de imágenes, con el texto como pie.

**Listo cuando:** ningún popup que ofrece o entrega algo muestra el premio sólo como texto, y la
Ruleta y el Colchón muestran sus posibilidades con imagen antes de jugar. Toda pantalla de premio tiene
sus tres momentos (antes, durante y después) con imagen e interacción.

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

## C8 — ORO pasa a llamarse dólar blue

**Lo que dijo el dueño:** la moneda premium deja de llamarse ORO y se llama **dólar blue**, con
un ícono de dólar blue. Todo lo demás queda exactamente igual.

**Alcance (medido):** 48 claves de `Localizable.xcstrings` (94 traducciones, es y en) dicen ORO,
y el inglés también dice «ORO» («Handful of ORO»). Un solo call-site de arte: `GameArt.swift:163-170`
(`ui_oro`).

**Qué hacer:**

1. **Sólo presentación.** Los identificadores internos quedan como están (`oro` en el código, el
   save, `oro_shop.json`, `ui_oro_*`, los product IDs `com.fisuevolution.iap.oro_*`, que en App
   Store Connect no se pueden renombrar). Ni precios, ni cantidades, ni lógica.
2. **Textos.** Cada «ORO» de moneda pasa a «dólares blue» o «dólar blue», con la concordancia
   arreglada a mano, no con un reemplazo ciego: «Puñado de ORO» → «Puñado de dólares blue»,
   «+%@ ORO» → «+%@ blue», «Tienda de ORO» → «Tienda del Blue», «Comprar ORO / Gastar ORO» →
   «Comprar blue / Gastar blue». El número corto con el ícono no lleva palabra.
   Inglés (default): «Blue Dollars», abreviado «Blue». **No se tocan** los «oro» que no son la
   moneda: la skin «De Oro» (tier oro/diamante), «monedas de oro» de la cinemática, el toque «de
   oro» de Suerte, `ui_up_golden`.
3. **Ícono.** `ui_dolar_blue` reemplaza a `ui_oro` en el HUD, la tienda, las ofertas, los premios, el
   prestigio y los logros. Prompt 14 de `fisu-v2-premios`. El de la pila de premios ya cambió los
   lingotes por un fajo de blue.
4. **Fuera del juego:** los nombres y descripciones de los IAP en App Store Connect (`releaseops`),
   `Distribution/iap-appstore-connect.md`, la nota a App Review (`app-review-reply.md`: «plata» y
   «ORO» → «plata» y «dólar blue»), las capturas de la tienda y el texto de la ficha si lo nombra.
5. El tutorial, el Tour de novedades y las lecciones de la tienda nombran la moneda: revisarlos
   con el resto de las claves.

**Ojo con el humor:** el Arbolito (`sp_arbolito`, guiones `arbolito_cambio` y `arbolito_blue`) y
los eventos de devaluación ya juegan con el blue. Hay que releer sus frases para que no choquen
con que ahora la moneda premium **es** el blue. Default: se dejan, y donde se pisan, el chiste se
ajusta al nuevo sentido (p. ej., el Arbolito te cambia plata por blue).

**Listo cuando:** `grep -w ORO` sobre el catálogo da cero en es y en; el ícono nuevo está en todas
las pantallas donde estaba el viejo; ASC tiene los nombres nuevos.

## C9 — Las esquinas de arriba, ordenadas como Cow Evolution

Referencias: `Docs/correcciones-v2/C9-cow-esquina-izquierda.jpg` (el círculo rojo: la columna de
botones-sello de la izquierda, imán, ruleta, tesoro y la caja con «Ready») y
`Docs/correcciones-v2/C9-cow-popup-ganancias.webp` (el popup de ganancias: la ilustración, el monto con
su moneda y dos opciones lado a lado, ×2 gratis con video y ×3 con la moneda premium).

**Lo que dijo el dueño:** la Ruleta, el Colchón, la Caja y todo lo que hoy está adentro del botón
de Regalos de la pantalla principal pasan a la **esquina superior izquierda**, con la misma
disposición que Cow Evolution: cada uno con su ícono propio, uno debajo del otro. Los boosts, los
multiplicadores (el ×3,5K) y los relojes de eventos, que hoy están arriba a la izquierda, pasan a la
**esquina superior derecha**, donde también va el aviso del personaje especial. El aviso del
especial va **arriba de todo** y los boosts y relojes, debajo. Cada cosa en su lugar, sin
amontonar, pero con botones grandes que se entiendan y se toquen bien. Siempre assets custom, nunca
botones genéricos.

**Hoy (verificado):** `SideRailView` es una columna plegable abajo a la izquierda. En reposo es un
solo botón «Premios» (el regalo con el badge «3») y al tocarlo despliega la Ruleta, El Colchón, los
Paquetes y Fusionar todo, en botones de 30 pt con glifos de 20 pt que se recogen a los 3 s.
`ActiveBonusBar` (boosts, multiplicador, chip del evento) está arriba a la izquierda. El chip del
visitante (`StageChips`) está centrado bajo el HUD.

**Qué hacer:**

1. **Izquierda: la columna de premios, siempre desplegada.** Se retira el pliegue y el botón
   «Premios». Arranca bajo el HUD, pegada al borde izquierdo, con los botones-sello uno debajo del
   otro: Ruleta, Colchón, Paquete y Fusionar todo (y lo que se sume después a ese riel). Cada uno:
   - ~56 pt de sello (custom: `ui_rail_wheel`, `ui_rail_mattress`, `ui_rail_package`,
     `ui_rail_merge_all`, prompts 15 a 18 de `fisu-v2-premios`), objetivo de toque ≥ 60 pt;
   - debajo, una **cinta** con su estado: «¡Listo!» cuando se puede usar, el reloj LED cuando falta,
     o el contador (como el «Ready» de la caja de Cow Evolution). La cinta, en la gramática de la
     casa (píldora caramelo o la cinta del `PanelTitleBanner`);
   - el «!» que late cuando hay algo para cobrar, en el mismo badge de siempre;
   - los que no están disponibles todavía no se muestran (no hay sellos grises de relleno), salvo
     que el dueño pida lo contrario al verlo.
   Tocar un sello abre su pantalla de premio de C4 (antes, durante y después), no la tarjeta chica
   de video de hoy.
2. **Derecha: el especial arriba, debajo lo que corre.** Una sola columna bajo el HUD, pegada al
   borde derecho, en este orden fijo:
   1. la tarjeta del personaje especial (C3), siempre la primera;
   2. los relojes de eventos (el chip del presentador, «En curso», el Apagón…);
   3. los boosts activos y los multiplicadores (el ×3,5K), uno por fila, con su ícono custom
      (`ui_boost_*`, `rw_*`) y su tiempo restante.
   Si son más de 4, los boosts se agrupan en un chip «+N» que despliega el resto.
3. **Nada se pisa:** las dos columnas respetan la zona del tablero que se toca. Se mide en el SE y
   en el Pro Max que ninguna tape celdas jugables. Si en el SE no entra todo, se achica el espaciado,
   no los botones.
4. **El botón de Regalos de la barra de abajo** queda para lo que es Regalos (el diario, los
   regalos). El regalo flotante de abajo a la izquierda con el «3» desaparece, porque su contenido
   ya está a la vista arriba.
5. **El popup de ganancias offline** (y el diario) toma la composición de la segunda referencia: la
   ilustración de quién ganó, el monto con el ícono de la moneda, y dos opciones lado a lado, «×2
   gratis» con video y «×3» con dólar blue (B3: los multiplicadores ya existen; esto es sólo la
   forma).
6. Tests: los UI tests del riel (`--uitest-rail-hold`, los cuatro marcos) y los de `ActiveBonusBar`
   se reescriben a la posición nueva. Accesibilidad: cada sello con su label y su estado.

**Listo cuando:** en la pantalla principal, arriba a la izquierda están los sellos de premios con su
cinta de estado, y arriba a la derecha la tarjeta del especial y, debajo, los relojes y los boosts.
Abajo no queda nada flotando sobre el tablero, salvo la ficha del Fisura.

## C10 — La caja y el colchón: más grandes y más arriba

Referencia: `Docs/correcciones-v2/C10-caja-chica-tapada.webp` (la caja de la Aduana, diminuta, entre
el regalo flotante y la ficha del Fisura, medio tapada).

**Lo que dijo el dueño:** las cajas aparecen muy chiquitas y en la parte de abajo, justo arriba del
menú, donde las tapa el botón de comprar (la ficha del Fisura) y el de reencarnar. No se ve la
animación de la caja al abrirse y no se entiende qué pasa. Lo mismo con el colchón: chico y abajo,
y el jugador no ve dónde aparece ni lo puede tocar. Tienen que ser **entre 80 % y 100 % más
grandes** y aparecer **más arriba**, visibles.

**Hoy (verificado en `Scenes/Prizes/PickupLayout.swift`):**

- `sideRatio = 0.62`: la caja mide 0,62 celdas (unos 45 pt en un teléfono de 393 pt).
- `baselineY = bottomInset + cellSize * 0.25`: la misma línea baja del visitante, pegada a la barra
  inferior. Paquete en x = 31 % (justo donde está la ficha del Fisura), colchón en x = 69 % (donde
  está el botón de reencarnar).

**Qué hacer:**

1. **Tamaño:** `sideRatio` de 0,62 a **~1,15** (+85 %, dentro del 80–100 % pedido). Se ajusta mirando
   el SE para que tres cajas apiladas (`maxVisibleBoxes`) no tapen media pantalla. Si no entran,
   `stackStep` se achica o el tope baja a 2 visibles con un «×N».
2. **Altura:** la línea de las cajas deja de ser la del borde inferior. Pasa a la línea del horizonte
   de C2 (la misma donde se para el visitante), o, si en algún fondo queda muy arriba, a una franja
   fija por encima de la ficha del Fisura y del botón de reencarnar, con un margen medido contra sus
   marcos reales y no contra un número. Ninguna parte de la caja ni del colchón puede quedar debajo
   de un control.
3. **Horizontal:** paquete y colchón a los lados del centro, de modo que no choquen con el visitante
   parado en el medio (C2) ni con las columnas de las esquinas (C9). Se respeta `edgeClearance`.
4. **La apertura se ve entera:** `PackageOpeningPlayer` y el clip `paquete_abre`/`colchon_abre` se
   reproducen en el lugar nuevo y a la escala nueva, sin recortarse contra el HUD. Al abrirse sigue la
   pantalla de premio de C4.
5. **El toque:** el área de toque crece con la caja (hoy `insetBy(-8)`); objetivo ≥ 60 pt.
6. Se actualizan los tests de `PickupLayout` y los UI tests que tocan la caja o el colchón por
   coordenadas.

**Listo cuando:** en el SE y en el Pro Max, con la ficha del Fisura y el botón de reencarnar a la
vista, la caja y el colchón se ven enteros y se tocan sin tocar otra cosa, y la animación de apertura
se ve completa.

## C11 — Lo que se paga con blue, en Mejoras; la Tienda, sólo plata real

**Lo que dijo el dueño:** las mejoras permanentes (más lugares en la torre, etc.) son muy importantes,
pero están escondidas en la Tienda. Tienen que estar en el menú de Mejoras, junto a las mejoras
permanentes que ya se pagan con blue. Y lo mismo con **todo** lo que se compra con blue: va a Mejoras
(o a Boosts), no a la Tienda. La Tienda se entiende como el lugar donde se paga con plata real y
asusta; así se incentiva a entrar a Mejoras. (ORO = dólar blue, C8.)

**Hoy (verificado):**

- `StoreView` tiene dos pestañas: **Comprar** (IAP con plata real: destacado, quitar anuncios,
  monedas, packs de ORO, skins) y **Gastar** (`OroShopView`, los estantes de `oro_shop.json`).
- `oro_shop.json` › estantes: `boosts` (×2, ×3, auto-tap, lluvia de paquetes), `shortcuts` (saltos
  de 1 h y 4 h, offline ×3, diario ×3, saltear cooldowns, fusionar todo), `permanents` (lugares extra,
  mejor proveedor, tiradas de ruleta), `luck` (el cofre de skins) y los cosméticos (pintas y familias
  con blue).
- `UpgradesView` ya tiene dos pestañas: **Personajes** y **Permanentes** (las siete mejoras globales
  en ORO, con el saldo arriba).

**Qué hacer:**

1. **Mejoras pasa a tener tres pestañas:** Personajes · **Permanentes** · **Boosts**.
   - **Permanentes** = las siete globales de hoy **más** el estante `permanents` de `oro_shop.json`
     (lugares extra en la torre, mejor proveedor, tiradas de ruleta), en el mismo formato de fila
     (`GameCard` + `PricePill` con el ícono del blue). Arriba, lo que más mueve el juego: lugares
     extra primero.
   - **Boosts** = los estantes `boosts` y `shortcuts`.
   - El saldo de blue va arriba en las dos pestañas de blue, con un «+» que lleva a la Tienda a
     comprar más (único puente hacia la plata real, y sólo si el jugador lo toca).
2. **Lo cosmético con blue** (pintas, familias y el cofre de skins del estante `luck`) va a la hoja
   de Pintas/Personalización, donde ya se eligen las skins, y no a Mejoras. Default del agente:
   ahí se entiende mejor; si el dueño lo prefiere en Mejoras › Boosts, se mueve.
3. **La Tienda pierde la pestaña Gastar:** queda una sola vista, sólo con lo que se paga con plata
   real (incluidos los packs para comprar blue). Se retira el selector Comprar/Gastar.
4. Los atajos que hoy abren «Gastar ORO» (lecciones del tutorial, el Tour de novedades, el «!» de la
   barra, notificaciones, `ShopIconFocus`) apuntan a la pestaña nueva de Mejoras. El «!» de algo
   comprable con blue se mueve al ícono de Mejoras.
5. Las probabilidades del cofre (`ChestOddsDisplay`, Apple 3.1.1) viajan con el cofre a su hoja
   nueva, intactas.
6. Lógica intacta: `buyOroShopItem`, precios y `oro_shop.json` no cambian; sólo dónde se muestran.
   Se reescriben los UI tests de la Tienda (`store.*`), de Mejoras (`upgrades.tab.*`) y de las
   lecciones que la nombran; el `MenuPagerUITests` y `CustomizationUITests` se corren (regla de la ola).

**Listo cuando:** abrir la Tienda muestra sólo precios en plata real; Mejoras › Permanentes
muestra los lugares extra de la torre arriba de todo; ninguna compra con blue requiere entrar a la Tienda.

## C12 — La barra de abajo llena todo el ancho

Referencia: `Docs/correcciones-v2/C12-barra-inferior-vacia.jpg` (iPhone 15: cinco pestañas
amontonadas en el centro, con un tercio de la barra vacío a cada lado).

**Lo que dijo el dueño:** los íconos del menú tienen que llenar la totalidad del ancho de la barra
inferior y adaptarse a cada dispositivo para tener el tamaño adecuado. Hoy, en un iPhone 15, sobra
demasiado espacio. Se escalan para llenar el menú y que se entienda qué es cada uno. Pueden llevar
una leyenda que diga qué es cada uno.

**Hoy (verificado):** `BottomMenuBar` usa lados fijos (`iconSide = 39`, `prominentIconSide = 64`) y
`GameTabBar` las centra. Las pestañas se desbloquean de a una (`unlockedTabsInBarOrder`): la barra
tiene entre 3 y 7 (Contratar, Mejoras, Pintas, Regalos, Tienda, Menú, Ranking), y las etiquetas
(`hud.*.label`) existen pero no se ven.

**Qué hacer:**

1. **Reparto por ancho:** cada pestaña ocupa una fracción igual del ancho útil de la barra (margen
   lateral fijo, ~`Tokens.s12`), y la destacada del centro (Contratar) ocupa ~1,4 de esas fracciones.
   El ícono se dimensiona contra su celda (~70 % del ancho de la celda), con un tope para que en iPad
   no se vuelvan gigantes (ahí, centrado con un ancho máximo de barra, como el resto de las hojas).
2. **Leyenda visible bajo cada ícono**, con las claves `hud.*.label` que ya existen: `Tokens.caption`
   (en la destacada, un poco más grande), una línea, `minimumScaleFactor` para el SE y para los
   textos largos del inglés. La leyenda no cambia los identificadores de accesibilidad
   (trampa 9a-bis: nunca en el contenedor).
3. Con 3, 4… 7 pestañas el reparto se recalcula y la entrada de una pestaña nueva sigue animada como
   hoy. El «!» y el «¡Nuevo!» se anclan a la esquina del ícono, no a la celda.
4. La altura de la barra crece lo justo para la leyenda; se re-mide todo lo que se ancla contra la
   barra (la ficha del Fisura, la caja y el colchón de C10, el riel viejo si queda, `bottomInset` del
   tablero y del escenario).
5. Se comprueba en SE, iPhone 15, 17 Pro Max e iPad (capturas de las cuatro) y con texto
   dinámico grande.

**Listo cuando:** en los cuatro dispositivos los íconos cubren la barra de borde a borde sin huecos
grandes, cada uno con su leyenda legible, con 5 pestañas y con 7.
