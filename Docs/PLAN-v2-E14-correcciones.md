# E14 — Correcciones del dueño antes de la App Store (2026-10-12)

> Pedido del dueño en el chat, corrección por corrección, antes de subir la 2.0. **Prioridad sobre
> la cola de `tasks.md`.** Las referencias visuales viven en `Docs/correcciones-v2/`. Regla de
> siempre: FisuJobs es la referencia visual y la gramática v3 es canon; el arte nuevo se genera en
> `automatic-image-generation` y entra por `Tools/asset-pipeline/dropbox/`.
>
> Estado: **lista cerrada (C1–C29) el 2026-10-12.** Plan por tareas:
> `docs/superpowers/plans/2026-10-12-v2-e14-correcciones-dueno.md` (decisiones D1–D12 y gates G1–G4).
> Lo visual se programa recién con su mockup aprobado (G1).

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
| C13 | El menú deslizable es UNA sola card fija; desliza el contenido de adentro; afuera, transparente | `MenuPagerView`, `panelSheet` (`PanelFrames.swift`), las hojas de cada pestaña | no | anotada |
| C14 | El atajo de contratar suma la opción «El primero del piso» | `QuickHirePicker`, `QuickHireButton`, `GameState+Hiring`, `meta` del save | no | anotada |
| C15 | El vendedor se va ofendido si no le comprás; TODOS los popups, centrados, contenidos y con una sola estética | las 10 vistas con `presentationDetents`, `PanelFrames.swift`, `VendorCardsView` | **sí: vendedor enojado** | prompt listo |
| C16 | Los que se llevan un empleado lo piden como el alien de Cow Evolution: globo con la cara del empleado | `StageController`, `SpeechBubbleNode` (→ globo de pedido), mecánicas `take`/`arrest`/`sale` | no (usa las caras) | anotada |
| C17 | Intercambiar el orden: Empleado de Fast Food pasa a tier 7 y Chofer de App a tier 8 | `tiers.json`, migración del save | no | anotada |
| C18 | Contratar y Reencarnar, pegados a la barra de abajo e integrados a ella | `RootView.bottomBar`, `QuickHireButton`, `PrestigeButton`, `BottomMenuBar` | no | anotada |
| C19 | Fuera los botones y chips genéricos: todo botón es un asset custom del juego (regla global) | chip de ofertas, `ActionPill`/`PillBackground`, los ~124 SF Symbols de `UI/` | **sí: 7 íconos** | prompts listos |
| C20 | Los avisos de «no hay lugar» / «no alcanza» (y todo toast) salen arriba, no abajo, y no frenan el juego | `RootView` (`TowerNoticeView`, toast de logros), `QuickHireButton` | no | anotada |
| C21 | El desbloqueo de un piso nuevo no se puede saltear | `BoardScene.tapDuringCelebration`, `CelebrationQueue.skip`, `CinematicOverlay` | no | anotada |
| C22 | Los 43 personajes base, sólo estáticos: fuera sus videos (los especiales y lo demás siguen animados) | `loops_manifest.json › characters`, `ArtClips`, `BoardScene`, `CharacterSheetView`, `AnimPacks/anim-piso-*` | no | anotada |
| C23 | Compartir: la oferta y la imagen compartida muestran al personaje con su skin, no un ícono | `ShareMomentChip`, `ShareCardView` (`ShareCardContent`) | no (usa el arte existente) | anotada |
| C24 | Compartir es parte de la celebración del personaje nuevo: grande, con su foto, y el juego sigue recién al elegir | celebración de personaje nuevo (`boardCelebration`), `ShareMomentChip` (se retira para este caso) | no | anotada |
| C25 | Eventos que te llevan directo a la Tienda (plata real) o a gastar dólar blue (Mejoras) | `events.json` (efecto nuevo), `EventPopupView`, navegación a Tienda/Mejoras con foco | quizás (ilustraciones de los eventos nuevos) | anotada |
| C26 | Videos nuevos de Higgsfield para abrir el cofre y para la Ruleta, pensados para encastrar en el juego | `ChestCinematicPlayer`/`ChestAnim`, `WheelView`, `loops_manifest.json` | **sí: 5 videos** | prompts listos |
| C27 | Lo mismo para la caja de la Aduana y el Colchón: espera, sacudida y apertura nuevas | `PickupNode`, `PackageOpeningPlayer`, `loops_manifest.json › objects` | **sí: 6 videos** | prompts listos |
| C28 | El Paquete de la Aduana se entiende: qué trae, dónde está y cómo se abre | `GameState+Packages`, `PackageRoller`, sello de C9, pantalla de premio de C4, lección del tutorial | **sí: `rw_package_employee`** | anotada |
| C29 | Jerarquía y recorrido: Regalos y la tienda de blue guían al jugador; auditoría de UX de todas las pantallas | `GiftsView`, Mejoras › Permanentes/Boosts (C11), todas las hojas | no | anotada |

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

## C13 — El menú deslizable: una sola card fija, desliza el contenido

Referencia: `Docs/correcciones-v2/C13-menu-cards-deslizan.webp` (a mitad de deslizar de Regalos a la
página de al lado: se ven dos marcos de madera, uno al lado del otro, y debajo de la card un fondo
blanco redondeado).

**Lo que dijo el dueño:** al deslizar a izquierda o derecha en el menú (de FisuJobs a Boosts, o
cualquier otra), hoy se ve cómo una pestaña se desliza sobre la otra, cada una con su card. Quiere
que el menú sea **una única card fija**, con el marco quieto, y que el deslizamiento ocurra **adentro**
de la card: cambia el contenido, no la card. Así queda un menú unificado y no parecen muchas
pestañas distintas. Además, por fuera de la card no puede haber nada: abajo se ve un fondo blanco y
tiene que ser transparente. La card sí tiene su fondo liso (el pergamino) para leer bien.

**Hoy (verificado):** `MenuPagerView` es un `ScrollView(.horizontal)` donde cada página es una hoja
entera (su `NavigationStack`, su `panelSheet` con marco de madera, toldo, adorno y su X). Al deslizar se
montan las vecinas, y por eso pasan marcos completos. La hoja que lo contiene deja ver un fondo blanco
debajo del panel (la presentación del sheet, no el arte).

**Qué hacer:**

1. **El marco sale de las páginas y queda en el paginador:** `MenuPagerView` dibuja una sola vez el
   `WoodPanelBackground` + el toldo + la X + la fila de puntos, quietos. Cada página aporta sólo su
   contenido: el título (la cinta con su ícono) y su cuerpo.
2. **El deslizamiento horizontal vive dentro del pergamino**, recortado por el borde interior del
   marco (`columnInset`), con el fundido de los bordes que ya usa la región de scroll. El título de
   la página desliza con su contenido (o hace un fundido cruzado; a elegir midiendo cuál se lee
   mejor). Las flechas ‹ › siguen en la cabecera, fijas.
3. **El adorno propio de cada pestaña** (el moño de Regalos, etc.) cambia con un fundido cruzado al
   asentarse la página, en vez de deslizar con un marco entero.
4. **Afuera, transparente:** la hoja del paginador con `presentationBackground(.clear)` y sin ningún
   contenedor blanco: alrededor del marco se ve el juego atenuado, como en las hojas que ya flotan
   (`panelSheet` de la hoja contenida). El interior sigue siendo pergamino liso.
5. Se conservan las reglas que costaron: en reposo se monta sólo la página actual (la X duplicada de
   `sheet.close` en el árbol de AX), el bloqueo del paginador con un destino empujado (Ajustes,
   Legales) y el «¡Nuevo!» que no se marca a mitad de arrastre (relevo 37). Al tener una sola X,
   el problema de la X triplicada desaparece por construcción.
6. Las vistas que también se abren fuera del paginador (desde un atajo directo) siguen viéndose con
   su marco propio: el marco se pone afuera, por quien las presenta, no adentro de cada vista.
7. Tests: `MenuPagerUITests` y `CustomizationUITests` (regla de la ola) y una captura a mitad de
   deslizar para el dueño.

**Listo cuando:** a mitad de deslizar entre dos pestañas se ve **un solo** marco quieto con dos
contenidos pasando por adentro, y en ningún momento hay blanco fuera del marco.

## C14 — El atajo de contratar: «El primero del piso»

**Lo que dijo el dueño:** en el botón de atajo (la ficha del Fisura, abajo), además de elegir un
personaje o «el mejor disponible», tiene que estar la opción de elegir **al primero de cada piso**,
como una de las opciones por defecto. Con esa opción, parado en el Callejón te da al Fisura; en la
Ciudad, al Mantero; y así, el primer tier del piso donde está parado el jugador.

**Hoy (verificado):** el atajo guarda `player.meta.quickHirePinnedTypeId: String?`: `nil` es «el
mejor» y un id es un personaje fijo (`GameState+Hiring.swift:240-346`). `QuickHirePicker` muestra el
botón «El mejor» (`quickhire.picker.best`) y la grilla de personajes.

**Qué hacer:**

1. El modo del atajo pasa a ser explícito: **el mejor · el primero del piso · un personaje fijo**.
   En el save, un campo nuevo opcional (`quickHireMode`) con migración sin pérdida: lo que hoy es
   `nil` sigue siendo «el mejor» y un id sigue siendo ese personaje.
2. En el picker, junto a «El mejor», un segundo botón de modo, **«El primero del piso»**, con el
   mismo formato (ícono: la cara del tier base del piso visible, que cambia al cambiar de piso). Las
   dos opciones de modo arriba, la grilla de personajes debajo.
3. Con ese modo, la ficha muestra y contrata el **tier base del piso visible** (`board.floor`): Fisura
   en el Callejón, Mantero en la Ciudad, etc. Al scrollear o usar el ascensor, la cara y el precio de la
   ficha se actualizan solos.
4. Los estados de siempre (piso lleno, no alcanza) se comportan igual que hoy, contra ese tier y ese piso.
5. Accesibilidad: el valor del botón dice el modo y el personaje que toca ahora («El primero del
   piso: el Mantero»).
6. Tests: EK o unit del resolvedor (mejor, piso, fijo × piso 1 y piso 2), la migración del save, y un
   UI test que elige el modo, cambia de piso y ve cambiar la cara.

**Listo cuando:** con «El primero del piso» elegido, en el Callejón la ficha contrata al Fisura y,
al subir a la Ciudad, al Mantero, sin volver a tocar el picker.

## C15 — El vendedor se ofende; todos los popups, contenidos en pantalla

Referencia: `Docs/correcciones-v2/C15-popup-vendedor-desborda.webp` (el popup del vendedor como
hoja desde abajo: la card se sale por el borde inferior y debajo se ve un fondo blanco).

**Lo que dijo el dueño:**

- Al vendedor ambulante hay que poder decirle que no («no darle bola»), y que se vaya **enojado
  porque no le compraste nada, tirándote un berretín**.
- La card del popup es muy grande y no se ve entera. **Todas** las cards y popups tienen que tener la
  misma estética, estar **contenidos adentro de la pantalla** y cumplir las reglas de antes,
  inspiradas en Cow Evolution.

**Hoy (verificado):** 10 vistas se presentan como hoja desde abajo con `presentationDetents`
(`VisitorPopupView` en `.fraction(0.62)`, y `SkinAwardView`, `DailyRewardView`, `PrestigeView`,
`CareerChoiceView`, `SpecialDropView`, `OfflineEarningsView`, `MattressPopupView`, `EventPopupView`,
`ShareCardView`). Con contenido alto, la card pasa el detent y se corta, y la hoja deja ver su fondo.

**Qué hacer:**

1. **El berretín del vendedor.** En su popup, «No, gracias» (C2/C5) dispara la reacción: frase
   ofendida en su globo (2–3 variantes por idioma, en el registro del Anexo A, p. ej. «¡Bueno, bueno!
   Después no vengas llorando cuando se te acabe el mate…»), el arte del vendedor enojado
   (`npc_vendedor_enojado`, prompt 19 de `fisu-v2-premios`; si después se quiere animado, un clip de
   Higgsfield con el método de [[videos-higgsfield]]) y, al cerrarse, se va caminando rápido y
   pisando fuerte, de espaldas. Sin penalidad de juego. Mismo patrón, opcional, para otros
   visitantes con personalidad (comisario, vecina) si el dueño lo pide.
2. **Un solo contenedor de popup para todo el juego**, al estilo Cow Evolution: card **centrada**
   en la pantalla sobre el juego atenuado (no hoja desde abajo), con el marco de la casa
   (`PanelCard`/`WoodPanelBackground`, cinta de título, X arriba a la derecha que no se sale del marco),
   y **alto máximo** = la zona segura menos un margen. Si el contenido no entra, scrollea **adentro**
   de la card, nunca la card fuera de la pantalla. Afuera, transparente; adentro, pergamino liso.
3. Se migran a ese contenedor las 10 vistas de arriba y cualquier popup nuevo de E14 (visitantes,
   premios de C4, ganancias offline de C9). Se retiran sus `presentationDetents`.
4. **Ritmo Cow Evolution** en todos: arriba el título, al centro la ilustración grande (personaje y/o
   premio, C4), una línea de texto, y abajo los botones grandes lado a lado (o apilados si son más de
   dos). Las cards de opciones del vendedor (`VendorCardsView`) se achican para que las tres entren
   en una fila en el SE sin cortar el texto.
5. Se mide en SE, iPhone 15, Pro Max e iPad, y con texto dinámico grande: captura de cada popup.

**Listo cuando:** ningún popup del juego se sale de la pantalla ni muestra fondo blanco afuera del
marco, todos se ven con la misma estructura, y decirle que no al vendedor lo hace irse ofendido.

## C16 — Pedir un empleado como el alien de Cow Evolution

Referencia: `Docs/correcciones-v2/C16-cow-alien-pide-vaca.jpg` (el círculo rojo: el alien en su
platillo, con un globo de pensamiento rosa que muestra la cara de la vaca que quiere llevarse).

**Lo que dijo el dueño:** cuando la influencer, el comisario o cualquier especial quiere llevarse a uno
de tus empleados, aparece el popup que explica el pedido, pero **en la pantalla** el personaje se ve
como el alien de Cow Evolution: con una burbuja que pide al empleado **mostrando su cara**. Tiene que
verse igual, adaptado al Fisu y con su identidad visual.

**Qué mecánicas son (de `visitors.json`):** `take` (influencer_novio: 1 empleado; puntero_acto: 3),
`arrest` (comisario_arresto, arca_paraiso) y `sale` (turista_compra: te compra uno por ×4). Las
tres eligen el empleado con `pick` (`lowestDuplicate` / `highestDuplicate`).

**Qué hacer:**

1. **El globo de pedido:** sobre la cabeza del visitante, parado en su lugar del horizonte (C2), un
   globo de pensamiento (las burbujitas que bajan hasta la cabeza, como en la referencia) en la
   paleta de la casa (crema con borde tono-sobre-tono, o un color de acento por mecánica: rojo para
   arresto, rosa para la influencer, verde para la venta), con **la cara del empleado elegido**
   (`VisitorFace`/la cara del tier, con su skin puesta). Si pide 3, las tres caras chiquitas o la
   cara con un «×3». El globo late suave para llamar la atención (con Reduce Motion, quieto).
2. **El flujo:** al llegar, primero sale el popup (C2/C15) con la frase, la cara del empleado y la
   recompensa ilustrada (C4): «Dárselo» / «No». Si se cierra sin elegir, el visitante queda esperando
   con el globo. Tocar el globo o al visitante reabre el popup. **Además, como en Cow Evolution:
   arrastrar al empleado pedido hasta el visitante** lo entrega (con feedback de «ése sí» al soltar
   sobre él y de rebote si no es el pedido). Las dos vías llaman a la misma acción del juego.
3. El empleado pedido se marca en el tablero mientras dure el pedido (un contorno o un «!» chico
   del color del globo) para que se encuentre.
4. Al entregarlo, el empleado camina hasta el visitante y se van juntos, o el comisario se lo lleva
   esposado (`visitorActions` del comisario, que ya existe). Al decir que no, la reacción de cada
   uno (C15).
5. Reemplaza al `SpeechBubbleNode` de texto en estos pedidos: la frase vive en el popup y en la
   escena sólo queda la cara.
6. Tests: el globo muestra al tier que eligió el `pick`; arrastrar el correcto entrega y uno
   incorrecto no; tocar el globo abre el popup.

**Abierto:** Cow Evolution pone al alien abajo a la izquierda, sobre el tablero. Acá el dueño ya pidió
que abajo no quede nada (C2, C10), así que el default es el horizonte, en el medio. Si lo quiere en
una esquina como en la referencia, se cambia.

**Listo cuando:** la influencer, el comisario, el puntero y el turista muestran en el escenario un
globo con la cara del empleado que piden, y se puede entregar por el popup o arrastrándolo.

## C17 — Fast Food antes que Chofer de App

**Lo que dijo el dueño:** intercambiar el orden del Empleado de Fast Food y el Chofer de App.

**Hoy (`Resources/Data/tiers.json`):** … Repartidor (6) → **Chofer de App (7)** → **Empleado de
Fast Food (8)** → Oficinista (9). Queda: Repartidor (6) → **Fast Food (7)** → **Chofer de App (8)** →
Oficinista (9).

**Qué hacer:**

1. **Los números quedan en su posición:** los valores por tier (`tapYield`,
   `passiveYieldPerInstance`, `passiveUnlockCost`, costos de contratación) son de la escalera, no del
   personaje. Se intercambian los **personajes** (`id`, `displayName`, `spritePlaceholder`, arte), no
   la economía. Se rehace la cadena `mergesInto`: Repartidor → fast_food → chofer_app → oficinista.
   El pacing no cambia (Dios a ~45 h intacto).
2. **Migración del save (crítico, la v1 está publicada):** un jugador que tiene empleados de tier 7 o
   8 no puede saltar ni retroceder de economía. Los empleados del tablero, el récord de tier, las
   mejoras por personaje (`maxLevel`, niveles comprados) y el «visto» de la colección se remapean **por
   posición** (lo que era tier 7 sigue siendo tier 7: ahora con la cara del Fast Food). Las **skins
   compradas o ganadas siguen al personaje**, no a la posición (el «taxi clásico» sigue siendo del
   Chofer, el «chef estrella» del Fast Food). Un test de migración con un save v1 real con los dos
   tiers en el tablero y con skins de cada uno.
3. Revisar lo que nombra el orden: textos que dicen «después del Repartidor viene…», lecciones del
   tutorial, logros por tier, cinemáticas de piso, el Álbum, el organigrama (`OrgChartView`), el
   simulador de balance y los tests de EK que fijan ids por tier.
4. Los ids no cambian (`fast_food`, `chofer_app`): sólo su lugar en la escalera.

**Listo cuando:** en partida nueva, fusionar dos Repartidores da un Empleado de Fast Food y dos Fast
Food dan un Chofer de App; un save de la v1 abre con la misma producción por segundo que tenía.

## C18 — Contratar y Reencarnar, integrados a la barra de abajo

**Lo que dijo el dueño:** los botones de contratar (la ficha del Fisura) y de reencarnar tienen que
estar más abajo, pegados a la barra inferior o incluidos en ella, integrados visualmente, para que
ocupen lo menos posible del área de juego y no estorben.

**Hoy (verificado en `RootView.bottomBar`, ~l. 630):** un `VStack(spacing: 8)` con una fila aparte,
`HStack { QuickHireButton; PrestigeButton }`, flotando **encima** de `BottomMenuBar`, con su propio
alto (la ficha verde grande de la captura de C10) y 8 pt de aire. Es una franja entera robada al
tablero.

**Qué hacer:**

1. **Una sola pieza:** los dos botones pasan a ser **solapas de la propia barra**, montadas sobre su
   borde superior, del mismo material y con el mismo borde (crema con el contorno de la barra), como
   la solapa amarilla de Contratar del centro de C12 que ya sobresale. Sin hueco entre ellas y la
   barra: visualmente es la barra la que crece en esos dos lugares.
2. **Más bajas:** la ficha de contratar se compacta a una fila: cara del personaje, precio con su
   moneda y el chevron del picker (C14), sin el nombre en dos líneas; la altura que sobresale de la
   barra es ≤ ~44 pt (objetivo de toque igual ≥ 44, por la solapa entera). Reencarnar, igual: su
   ícono y su estado.
3. **Ubicación:** contratar a la izquierda de la solapa central y reencarnar a la derecha, sin tapar
   los íconos de la barra (que siguen repartidos a todo el ancho, C12) — o, si en el SE no entra,
   las dos solapas sobre las pestañas de los extremos, que quedan debajo intactas. Se elige midiendo
   las dos variantes en el SE y en el Pro Max.
4. **Lo que gana el tablero:** el `bottomInset` del tablero, del escenario (C2) y de las cajas (C10)
   se recalcula contra la barra nueva; todo lo que se apoyaba en la franja vieja baja.
5. Los anclajes del tutorial (`.quickHire`, `.prestige`, `.bottomBar`), el picker de C14, los estados
   (piso lleno, no alcanza, reencarnar bloqueado) y la accesibilidad siguen funcionando; se
   actualizan los UI tests que tocan estos botones por posición.

**Listo cuando:** entre el tablero y la barra no hay una franja aparte: contratar y reencarnar se
leen como parte de la barra, y el tablero gana la altura que ocupaba la fila vieja (medido en pt en el
SE y en el Pro Max).

## C19 — Nada genérico: todo botón es un asset custom (regla global)

Referencia: `Docs/correcciones-v2/C19-chip-promo-generico.png` (el chip rosa de la oferta de la
Mudanza: cápsula plana, un SF Symbol de camión blanco y el reloj).

**Lo que dijo el dueño:** este botón promocional es demasiado genérico. Los botones **nunca** pueden ser
así, cápsulas planas sin onda. Siempre tienen que ser **assets custom** que mantengan la identidad
del Fisu: una promoción, un botón de la ruleta, lo que sea. Si el asset no existe, se crea y se mete al
juego. Vale para los botones de los popups y del juego entero: toda la estética integrada, como en Cow
Evolution o AdVenture Capitalist.

**Alcance medido:** las tres ofertas (`offers.json`) usan SF Symbols (`box.truck.fill`,
`hand.wave.fill`, `arrow.counterclockwise.circle.fill`); en `FisuEvolution/UI` hay **44** `systemName:`
y **80** `systemImage:` (los que más: `lock.fill` ×8, `checkmark.circle.fill` ×6, `play.rectangle.fill`
×5, `sparkles` ×5, `clock.fill` ×3).

**Qué hacer:**

1. **Regla del proyecto (va al HANDOFF §5 como decisión del dueño):** ningún control visible del juego
   usa un SF Symbol ni una cápsula plana de sistema. Ícono = PNG del juego (`GameIcon`/`UIArt` con
   fallback vectorial **dibujado**, nunca un SF Symbol). Botón = la gramática de botón de la casa.
   Excepciones aceptadas: los glifos internos de accesibilidad y el andamiaje de DEBUG.
2. **La gramática de botón, subida de nivel (estilo Cow Evolution / AdVenture Capitalist):** cuerpo
   con volumen (cara clara arriba, labio oscuro abajo, contorno grueso tono-sobre-tono, sombra de
   apoyo), un **medallón** a la izquierda con el ícono custom (como el play rojo del «Open» de Cow
   Evolution) y el texto en `Tokens.title`. Colores por función: verde = gratis o cobrar, naranja =
   cuesta plata del juego, celeste = dólar blue, rojo = video. Se construye sobre `PillBackground`
   (vectorial, para no volver a estirar PNG 9-slice) y reemplaza a `ActionPill`, `PricePill` y
   `RewardedOfferButton` en todo el juego.
3. **El chip de oferta** pasa a ser un **sello de oferta**: el ícono custom de cada oferta
   (`ui_offer_mudanza`, `ui_offer_bienvenida`, `ui_offer_renacer`) grande, con una cinta debajo con el
   reloj (`ui_icon_clock`) — la misma familia que los sellos de la esquina de premios (C9). Vive en la
   columna derecha de C9 (debajo del especial), no flotando suelto.
4. **Íconos de uso general que reemplazan SF Symbols:** `ui_icon_video` (play), `ui_icon_clock`
   (reloj), `ui_icon_lock` (candado), `ui_icon_check` (listo). Prompts 20 a 26 de `fisu-v2-premios`.
   Para el resto de los símbolos se hace un barrido: cada uno se reemplaza por un asset existente
   (`ui_*`, `rw_*` de C4) o se suma su prompt a la cola; la tabla del barrido va en el doc de sesión.
5. Esta regla aplica a todo lo de E14: los sellos de C9, las pantallas de premio de C4, los popups de
   C15, las solapas de C18 y la barra de C12.

**Listo cuando:** un `grep` de `systemName:`/`systemImage:` en `FisuEvolution/UI` sólo devuelve
accesibilidad o DEBUG, y todos los botones del juego comparten la gramática nueva.

## C20 — Los avisos salen arriba y no estorban

**Lo que dijo el dueño:** al tocar contratar sin plata o sin lugar en el piso, el aviso («no hay más
lugar en el piso», «no tenés monedas suficientes») aparece abajo, interfiere con la zona de juego, no
deja espacio para mergear e interrumpe. Tiene que aparecer en la parte de más arriba.

**Hoy (verificado):** el aviso de piso es `TowerNoticeView` (`RootView.swift` ~l. 178), que entra
**desde abajo** (`.move(edge: .bottom)`) sobre el tablero, en la franja donde se juega; el toast de
logros vive en el mismo lugar con el mismo patrón.

**Qué hacer:**

1. **Todo aviso pasajero** (piso lleno, no alcanza, aviso de torre, toast de logros y cualquier toast
   nuevo de E14) aparece **arriba**: debajo del HUD, centrado entre las dos columnas de las esquinas
   (C9), y entra desde arriba.
2. **No frena el juego:** el aviso no come toques del tablero (`allowsHitTesting(false)` salvo su
   propia X o su botón, si tiene); se puede seguir arrastrando y fusionando con el aviso a la vista.
   Dura lo de hoy y se va solo; tocar otra vez contratar no apila otro, renueva el que está.
3. **Estética:** en la gramática de C19 (cinta o cartel de la casa con su ícono custom: `ui_icon_lock`
   para piso lleno, la moneda para no alcanza), no una cápsula plana.
4. Si el aviso ofrece una salida («ver un video para liberar lugar», «ir al ascensor»), el botón va
   dentro del aviso, arriba, sin abrir nada encima del tablero.
5. Los UI tests que esperan el aviso (`tower.notice.*`, `quickhire.blocker.*`) se actualizan a la
   posición nueva; las lecciones del tutorial que apuntan al aviso (`tutorial.floor_full.explain`)
   también.

**Listo cuando:** con el piso lleno, tocar contratar muestra el aviso arriba y en ese mismo momento se
pueden fusionar dos empleados de la parte de abajo del tablero.

## C21 — El desbloqueo de piso no se saltea

**Lo que dijo el dueño:** la animación de desbloqueo de un piso nuevo tiene que ser **insalteable**:
aunque el jugador toque muchas veces, no se puede saltear. Descubrir un piso es siempre una gran
celebración y un evento importante del juego.

**Hoy (verificado):** el desbloqueo es una celebración del tablero (`BoardScene.runFloorUnlockCelebration`,
~l. 1980: cartel con pop, ~0,9 s de espera y el ascenso). Un toque al tablero llama a
`GameState.skipCurrentCelebration()` → `celebrations.skip()` → `abortBoardCelebration()`, y la corta.
Si el piso tiene cinemática, `CinematicOverlay` muestra «Saltear» al segundo (`skipDelay = 1 s`).

**Qué hacer:**

1. La celebración de **piso recién desbloqueado** (y su cinemática, si la tiene) se marca como no
   salteable en la cola (`CelebrationQueue`: un flag por tipo, p. ej. `isSkippable == false` para el
   desbloqueo de piso). `skip()` devuelve `false` para ella y los toques al tablero se consumen sin
   efecto mientras dura; no agarran personajes.
2. En `CinematicOverlay`, sin botón «Saltear» para las cinemáticas de piso nuevo. Las demás
   cinemáticas siguen como hoy.
3. **Sólo la primera vez:** volver a un piso ya conocido (ascensor, scroll) no dispara nada ni se
   bloquea. Una reencarnación que re-desbloquea pisos: se decide con el dueño; default, la primera
   vez **en esa vida** también es insalteable, pero corta (sin la cinemática larga si ya la vio).
4. Ya que pasa a ser obligatoria, que valga la pena: el anuncio en grande del nombre del piso (en la
   gramática de C19), sonido y haptic de evento, el fondo nuevo en su calidad buena (C1) y el
   personaje base del piso entrando. Duración total razonable (~3–4 s sin cinemática) para no hartar.
5. Con Reduce Motion se mantiene insalteable pero sin movimiento brusco (fundidos).
6. El watchdog de celebraciones sigue mandando: si algo se cuelga, la libera igual (no puede trabar
   el juego).
7. Tests: N toques durante el desbloqueo no lo cortan (la celebración sigue `current` hasta su fin);
   un toque durante otra celebración común sí la saltea como hoy.

**Listo cuando:** al desbloquear un piso, tocar la pantalla diez veces seguidas no acorta la
celebración, y el resto de las celebraciones siguen salteables.

## C22 — Personajes base y fondos, sólo imagen estática

**Lo que dijo el dueño:** sacar los videos de las skins base; los personajes del tablero usan sólo
imágenes estáticas. Los especiales y todo lo demás siguen con video. Para los personajes y **sobre
todo para los fondos**, imagen estática: el fondo en video se ve mucho peor que las imágenes
reescaladas de la última vez. (Los fondos ya están en C1; esto lo confirma y lo extiende a los
personajes.)

**Alcance (medido):** `loops_manifest.json › characters` tiene 53 clips: **43 de personajes base**
(`homeless` … `trillonario`, 512×512, matte blanco, **8,6 MB**, repartidos en los packs ODR
`anim-piso-1…10`) y 10 especiales (`sp_*`). Se consumen en `BoardScene` (~l. 1577 y 1755, el
personaje del tablero y su skin activa), `CharacterSheetView` (la ficha), y vía `ArtClips.character`.

**Qué hacer:**

1. **Se quitan los 43 clips base:** sus entradas de `characters` (quedan sólo las `sp_*`), sus `.mov`
   de los packs `AnimPacks/anim-piso-*` y, si un pack queda vacío, su `resourceTags` de
   `project.yml` (y el pedido de ODR en `ArtPacks`). Bundle y descargas más livianos.
2. `BoardScene`, `CharacterSheetView` y el Álbum/organigrama, si los usan, muestran siempre el PNG
   del personaje con su skin (`*_idle__<skin>`), en la mejor resolución que haya. La vida del tablero
   (deambular, rebote, fusión) sigue como hoy: es animación de SpriteKit, no video.
3. **Siguen con video:** especiales (`sp_*` en el Álbum, el drop especial, el escenario), visitantes
   (`portraits`, `talking`, `visitorActions`), eventos, íconos de la tienda, objetos (paquete y
   colchón) y la cabina del ascensor (C7 decide sus ventanas). Los fondos de piso, fuera (C1).
4. `VideoPlaybackPolicy` (tope de 3) gana lugares: revisar que el tope siga teniendo sentido.
5. Pipeline: `Tools/asset-pipeline/scripts/video_assets.py` y su test dejan de esperar clips de
   personajes base; `Tools/v2/oraculo.sh` y los tests de manifiesto se actualizan.
6. Las skins de oro y diamante, si tenían brillo animado, se mantienen como animación de
   SpriteKit sobre la imagen (no video).

**Listo cuando:** ningún personaje base reproduce video en ninguna pantalla, el tamaño de los packs
baja ~8,6 MB, y los especiales siguen animados.

## C23 — Compartir muestra al personaje con su skin

**Lo que dijo el dueño:** cuando aparece el botón de compartir para ganar el bonus, tiene que mostrar
una imagen del personaje que acabás de desbloquear, con su skin, en vez de sólo un ícono: así el
jugador tiene más ganas de compartir el logro.

**Hoy (verificado):**

- `ShareMomentChip` es una `ActionPill` con el SF Symbol `square.and.arrow.up` y una X, abajo,
  apilada sobre los toasts (`bottomPadding`).
- **La imagen que se comparte también es genérica:** `ShareCardContent` (540×960, por
  `ImageRenderer`) dibuja un **SF Symbol** en el plato del retrato (`symbolName`: el
  `spritePlaceholder` del tier, `building.2.fill` para piso, `arrow.triangle.2.circlepath` para
  reencarnar). O sea, a las redes sale un ícono de sistema, no el personaje.

**Qué hacer:**

1. **La oferta de compartir** pasa a ser una tarjetita con el **retrato del personaje recién
   desbloqueado con su skin activa** (el PNG `*_idle__<skin>`), su nombre, el bonus («+N min») y el
   botón de compartir en la gramática de C19 (sin SF Symbols), más su X. Para piso nuevo: el fondo del
   piso en miniatura con su personaje base; para reencarnación: el Fisura con la skin activa y el arte
   de la cinemática de reencarnación.
2. **La imagen compartida** (`ShareCardContent`) muestra el **arte real**: el personaje grande con su
   skin, sobre el fondo de su piso (foto buena de C1) con el pergamino y el marco de la casa, el
   título del logro, el logo del juego y el link o el QR de la App Store. Para Dios, la cinemática o
   el arte de Dios. Fuera los `symbolName`.
3. `ImageRenderer` no carga assets async: el arte se precarga (UIImage) antes de renderizar, y si
   falta, el fallback es el retrato vectorial de la casa, nunca un SF Symbol.
4. Posición: la tarjetita sale **arriba** con los demás avisos (C20), no apilada sobre la barra; se
   va sola a los 10 s como hoy.
5. Tests: el render de la tarjeta para `.newCharacter`, `.newFloor`, `.reincarnation` y `.god` no está
   vacío y contiene la imagen del personaje (snapshot o tamaño de los píxeles no transparentes);
   UI test de la oferta con su identificador de siempre (`share.offer`).

**Listo cuando:** al desbloquear un personaje, la oferta de compartir muestra su cara con la skin, y la
imagen que llega a WhatsApp/Instagram es el personaje real sobre su piso, con el logo del juego.

## C24 — Compartir, dentro de la celebración del personaje nuevo

**Lo que dijo el dueño:** el botón de compartir tiene que ser más vistoso y aparecer **en el mismo
momento en que aparece el personaje nuevo**, junto con su foto. Si el jugador decide no compartir,
**recién ahí** sigue el juego.

**Hoy:** el personaje nuevo dispara la celebración del tablero (apaga la UI, «algo nuevo»,
SESION-2026-08-17); al terminar aparece, aparte y abajo, el chip de compartir (`ShareMomentChip`,
10 s, «nunca es un popup»). Esta corrección **revoca esa regla para el personaje nuevo**.

**Qué hacer:**

1. Cierre de la celebración de **personaje nunca visto** = una card de revelación en el contenedor
   único de C15: el personaje **grande con su skin** (y su animación de entrada; estático por C22),
   rayos detrás (C4), su nombre en la cinta de título y una frase corta de presentación.
2. Debajo, dos botones de la gramática de C19, lado a lado:
   - **«¡Compartir!»** (el principal, grande y vistoso, con el bonus «+N min» bien visible): abre la
     hoja de compartir con la imagen de C23. Al volver del share sheet se cobra el bonus como hoy
     (sólo si se completó) y sigue el juego.
   - **«Seguir»** (secundario): cierra y sigue el juego, sin bonus.
3. Mientras la card está abierta el juego queda en pausa visual (el tablero detrás atenuado, sin
   toques). Es lo único que bloquea; nada más se suma a la cola encima.
4. **Cuándo:** cada personaje nunca visto y Dios. Piso nuevo y reencarnación siguen con la oferta
   chica de C23 (arriba, no bloqueante). **Default del agente:** los primeros personajes del
   tutorial (Fisura → Trapito → Limpiavidrios), que salen en minutos, muestran la card **sin** el
   botón de compartir (sólo «¡Genial!»), para no cortar el arranque cada 30 s; a partir del cuarto,
   con compartir. Si el dueño lo quiere en todos, se saca la excepción.
5. Encaja con C21: si un personaje nuevo coincide con un piso nuevo, primero la celebración del piso
   (insalteable) y después la card del personaje.
6. Tests: un personaje nuevo abre la card con `share.offer`; «Seguir» la cierra sin bonus; compartir
   completado da el bonus una vez; el juego no recibe toques mientras está abierta.

**Listo cuando:** al fusionar y descubrir un personaje, aparece su card con su foto y el botón grande
de compartir, y el tablero sigue recién después de elegir compartir o seguir.

## C25 — Eventos que llevan a la Tienda y a gastar blue

**Lo que dijo el dueño:** que haya eventos que te manden directamente a la Tienda. Lo mismo con la
tienda de blue (lo que se paga con dólar blue, que por C11 vive en Mejoras).

**Hoy:** `events.json` tiene 18 eventos (plan_platita, devaluación, corralito, liquidación, apagón…);
ninguno abre una pantalla de compra.

**Qué hacer:**

1. **Un efecto de evento nuevo, `openShop`**, con destino `store` (Tienda, plata real) o `blue`
   (Mejoras › Boosts/Permanentes, C11) y un **ítem en foco** opcional (`ShopIconFocus`, que ya existe:
   la pantalla abre con esa fila destacada y animada).
2. **Eventos nuevos con ese efecto**, con el presentador y el humor de la casa (borrador para que el
   dueño apruebe el texto, en el registro del Anexo A):
   - **«Cyber Monday del Conurbano»** → Tienda, foco en el pack destacado.
   - **«Llegó el blue al barrio»** → Mejoras › Boosts, foco en el ×2 de ingresos.
   - **«Mudanza de oficinas»** → Mejoras › Permanentes, foco en lugares extra en la torre.
   - **«Cuevita abierta»** (el Arbolito como presentador, C8) → Tienda, foco en los packs de blue.
   Cada uno con su ilustración (C4), en el popup de C15, con dos botones: **«¡Vamos!»** (abre el
   destino) y **«Ahora no»**.
3. **Sin descuentos inventados:** el evento lleva a la pantalla y destaca; no cambia precios. (Si el
   dueño quiere una oferta temporal con descuento, ya existe el sistema de ofertas de `offers.json`:
   se engancha ahí y no en el evento.)
4. **Para que no se sienta spam:** tope de 1 por sesión y separación mínima de ~4 h entre eventos de
   este tipo; nunca durante el tutorial, la primera sesión ni con una celebración en curso; si el
   jugador compró algo en las últimas 24 h, el de Tienda no sale. Peso bajo en el sorteo de eventos.
5. Apple: el popup no presiona («Ahora no» igual de visible, sin cuenta regresiva falsa) y el
   destino muestra precios reales del StoreKit.
6. Tests de EK: el efecto `openShop` no toca la economía; el tope y la separación se respetan; un UI
   test de «¡Vamos!» que abre la Tienda con la fila en foco.

**Listo cuando:** en una partida larga aparece, de vez en cuando, un evento que con un toque abre la
Tienda o Mejoras en el producto que promociona, y nunca dos seguidos ni en el arranque.

## C26 — Videos nuevos del cofre y de la Ruleta (Higgsfield)

**Lo que dijo el dueño:** regenerar con Higgsfield el video de abrir el cofre y el de la Ruleta, para que
se integren perfecto con la estética y la dinámica del juego. Sin fondo: pedir fondo verde o blanco
según cómo se vaya a integrar.

**Hoy:** el cofre usa `chest_open.mov` (HEVC con alfa) para el tramo cinemático más los frames de
`ChestAnim/` (idle y sacudidas, 48 fps, `chest_anim.json` con `chestRect` y `parchmentRect`). La Ruleta
no tiene video: es un `WheelCanvas` vectorial que gira con `spinSeconds` de `wheel.json`.

**Diseño de la integración (lo que decide los prompts):**

- **El premio nunca va en el video.** Lo decide el juego y lo dibuja el código encima (C4). Por eso
  el cofre se abre a un brillo vacío y la Ruleta tiene el **disco liso**: los gajos con sus imágenes
  los pinta `WheelCanvas` encima del disco y son los que giran. El video es el marco con las luces.
- **Encaja con los tres momentos de C4:** cofre: `cofre_espera` (loop) → toque → `cofre_sacude` (1.º y
  2.º toque) → `cofre_abre` (3.er toque) → el premio sale del brillo con rayos y partículas →
  «¡Cobrar!». Ruleta: `ruleta_espera` (loop, luces que corren) → giro (código) → `ruleta_premio`
  (las luces festejan) → el premio del gajo grande.
- **Fondo:** blanco puro en los loops de espera y sacudida (`whitebg_cutout.py`, como los 135
  aprobados); **verde croma** en `cofre_abre` y `ruleta_premio`, porque sus rayos y chispas blancas se
  perderían recortando blanco (`matte: "verde"`, como la cabina).

**Prompts:** `automatic-image-generation/projects/fisu-v2-premios/video/` (README + 5 `.md`), con
las referencias del juego (`ui_chest_closed`, `wheel_frame`, `wheel_pointer`) como primer cuadro.

**Qué hacer:**

1. Generar los 5 en Higgsfield con el método aprobado (primer/último cuadro, cámara quieta, sin
   manos); control cuadro por cuadro; el dueño revisa en la interfaz local (va / regenerar / obviar).
2. Integrar con `video_assets.py` (de a uno, nunca en paralelo: se pisa el manifest), al
   `loops_manifest.json` (sección `objects` o una nueva `prizes`), y con un SFX sintetizado por momento
   (`Tools/audio-synth`).
3. Cofre: `ChestCinematicPlayer` y `ChestAnim` pasan a los clips nuevos; se recalcula `chestRect` /
   `parchmentRect` contra el encuadre nuevo. Se retiran el `chest_open.mov` y los frames viejos.
4. Ruleta: el video va debajo de `WheelCanvas`, alineado al disco (se mide el centro y el radio del
   disco del clip y se guarda en el manifiesto); la flecha y las luces son del video.
5. Con Reduce Motion: el póster estático y el giro/la apertura con fundidos.

**Listo cuando:** abrir un cofre y tirar la Ruleta muestran los videos nuevos encastrados (sin borde
blanco ni verde, alineados con el premio que dibuja el código) y el dueño los aprobó.

## C27 — Videos nuevos de la caja y del Colchón

**Lo que dijo el dueño:** lo mismo que la Ruleta y el cofre (C26), para la caja y el colchón.

**Hoy:** `loops_manifest.json › objects` tiene `paquete_espera`, `paquete_abre`, `colchon_espera` y
`colchon_abre` (512×512, matte blanco), los de la tanda aprobada el 2026-10-09.

**Qué hacer:** igual que C26, en las dos piezas del tablero (C10) y en su pantalla de premio (C4):

- `paquete_espera` / `colchon_espera` (loop, blanco): respiran y piden el toque. Reemplazan a los
  actuales.
- `paquete_sacude` / `colchon_sacude` (1 s, blanco, **nuevos**): la reacción a cada toque de los tres
  que abren (C4 «durante»).
- `paquete_abre` / `colchon_abre` (3 s, **verde**): la caja revienta la cinta y abre las solapas; el
  colchón se descose con un «pop». Sale **sólo luz**: el premio lo dibuja el código encima.
  Reemplazan a los actuales.

Prompts en `fisu-v2-premios/video/` (referencias `pickup_package`, `pickup_mattress` como primer
cuadro). Mismo control de calidad, revisión del dueño e integración de a uno con `video_assets.py`.
Con el tamaño nuevo de C10 (+85 %), se exporta a 768 en lugar de 512 si el SE lo aguanta (medir
memoria con el tope de 3 videos).

**Listo cuando:** la caja y el colchón del tablero respiran, saltan con cada toque y se abren a un
brillo del que sale el premio ilustrado, con los clips nuevos aprobados por el dueño.

## C28 — El Paquete de la Aduana, explicado y a la vista

**Lo que dijo el dueño:** muchas veces gana o le dan paquetes de la Aduana y no entiende qué le dan: no
los puede abrir, no ve dónde están, no entiende el beneficio. Hay que explicarlo mucho más claro,
quizás abrirlo con una animación en la página de bonus, y darle una vuelta de tuerca: un asset que lo
identifique (estático o que se abra animado, como la Ruleta, el cofre, la caja y el colchón), integrado
al juego y con los popups estilo Cow Evolution, donde la imagen deja reconocer la recompensa posible.

**Qué es hoy (verificado en `GameState+Packages.swift`):** un paquete trae **un empleado gratis**: al
abrirlo, `PackageRoller.roll` sortea un tipo entre los que FisuJobs vende con lugar (ventana de
`windowTiers = 4` tiers, pesados por `tierRatioByBestSupplierLevel`, que mejora con «Mejor
proveedor») y lo manda al tablero como llegada. Los paquetes esperan en un buzón
(`engagement.packages.waiting`): caen solos cada 120 s (tope 2) y llegan además como premio de
visitantes, Ruleta y eventos. Si no hay lugar, el paquete no se gasta («LLENO»). **Nada de esto se le
dice al jugador:** el premio de un visitante dice «1 paquete» y el paquete aparece chiquito abajo (C10)
o escondido en el riel (C9).

**Qué hacer:**

1. **Identidad:** el Paquete de la Aduana es «**una caja con un empleado sorpresa adentro**». Su
   ilustración de premio deja de ser una caja sola: `rw_package_employee` (la caja con un empleado
   asomándose y saludando, prompt 27). Es la imagen del paquete en todo premio (C4) y en su sello (C9).
   Subtítulo fijo donde aparezca: «¡Adentro viene un empleado gratis!».
2. **Dónde está:** su sello en la columna de premios de arriba a la izquierda (C9), con la cinta
   «×N» de los que tenés guardados; y en el tablero, la caja grande de C10. Al **ganar** un paquete
   (visitante, Ruleta, evento), la ilustración vuela desde el popup hasta el sello y el sello rebota, con
   un aviso arriba (C20): «¡Te llegó un paquete de la Aduana!».
3. **Abrirlo — pantalla de premio de C4, estilo Cow Evolution:**
   - **Antes:** la caja grande (video `paquete_espera`, C27) y, debajo, «**Adentro puede venir:**» con
     las **caras de los posibles empleados** (los 4 de la ventana de `PackageRoller` para el estado
     actual) y su probabilidad debajo de cada una (la tabla sale del mismo cálculo; los paquetes se
     pueden conseguir con dólar blue — lluvia de paquetes —, así que mostrar las chances es lo
     correcto para Apple 3.1.1). Botón «¡Abrir!» (y «Abrir todos» si hay más de uno).
   - **Durante:** tres toques con `paquete_sacude` y `paquete_abre` (C27).
   - **Después:** el empleado que salió, grande, con su nombre y «**¡Llega a tu piso N!**»; al cerrar,
     cae al tablero en ese piso (la llegada de siempre). Si es un personaje nunca visto, se encadena la
     card de C24.
4. **Sin lugar:** si no entra nadie, la pantalla lo dice antes de abrir, con la cara del empleado y
   «No hay lugar en tus pisos: fusioná o liberá un lugar y volvé», con el paquete guardado (como hoy).
5. **En la página de Regalos/bonus:** una fila del Paquete con su ilustración, cuántos tenés y
   «¡Abrir!», que lleva a la misma pantalla.
6. **Tutorial:** la lección del paquete se reescribe en torno a esto (qué trae, dónde está, ábrelo ahora),
   disparada la primera vez que se gana uno; el Tour de novedades lo nombra igual.
7. Tests: la tabla de «puede venir» coincide con las probabilidades de `PackageRoller` (EK); abrir resta
   uno y encola la llegada en el piso que se anuncia; sin lugar no se gasta.

**Listo cuando:** un jugador que gana un paquete ve volar la caja al sello, sabe que adentro viene un
empleado, ve quiénes pueden salir, lo abre con tres toques y ve a quién le tocó y a qué piso llega.

## C29 — Jerarquía y recorrido en Regalos, en el blue y en todo el juego

**Lo que dijo el dueño:** mejorar la jerarquía de la página de bonus (Regalos) y de la tienda de dólar
blue: lo más importante siempre arriba y que la página guíe; un recorrido que incite a gastar y que
haga entender el flujo, qué conviene ahorrar y qué conviene gastar. La Tienda de plata real está bien
jerarquizada; Regalos y el blue no. Si se puede, mejorar la jerarquía de todas las pantallas: que la UI
se entienda sola, no estrese, se note de calidad, con las mejores prácticas de UX/UI, digna de los
mejores juegos del App Store. Referencias: Cow Evolution y AdVenture Capitalist, con la identidad del Fisu.

**Hoy (verificado en `GiftsView.swift`):** el orden es fijo — Cofres (si hay), La Ruleta, Racha diaria,
Boosts, el cartel del cobro y Videos —, sin importar qué está listo para cobrar. Todas las filas pesan
lo mismo y el texto explicativo va en párrafos (la racha: «Se cobra solo con que aparezcas…»).

### Principios que rigen toda la UI (van al HANDOFF §5 como regla del dueño)

1. **Una acción principal por pantalla y por fila**, y se ve primero: el botón más grande y de color es
   lo que conviene hacer ahora; lo secundario es más chico o neutro.
2. **Lo accionable arriba, lo que espera abajo, lo informativo al final.** El orden de una lista se
   decide por estado (listo › pronto › bloqueado), no por catálogo.
3. **Mostrar, no explicar:** imagen del beneficio (C4), un número grande y una línea de texto. Nada de
   párrafos en las filas; la explicación larga va detrás de un «?» que abre un popup ilustrado.
4. **Estados consistentes en todo el juego:** listo (verde, con el «!» que late), en curso (reloj),
   bloqueado (gris con lo que falta: «Te faltan 40 blue», «Desde el piso 3»), hecho (check). Los mismos
   colores y los mismos íconos custom (C19) en todas las pantallas.
5. **Agrupar con aire y ritmo constante** (Gestalt): secciones con su cinta, filas del mismo alto y la
   misma grilla de espaciados (`Tokens`), alineación a una sola columna.
6. **Feedback inmediato y celebratorio** al cobrar o comprar (la ilustración vuela a su destino, el
   saldo cuenta para arriba, haptic y sonido). Nunca un cambio silencioso.
7. **Divulgación progresiva:** lo que todavía no se usa no aparece o aparece como «se desbloquea en…»,
   para que el jugador nuevo no vea veinte cosas a la vez.
8. **Legibilidad y accesibilidad:** nada por debajo de `Tokens.caption`, contraste AA sobre el
   pergamino, objetivos de toque ≥ 44 pt, texto dinámico y VoiceOver con label y estado en cada fila.

### Regalos (bonus)

1. **Arriba, «Para cobrar ahora»:** una tarjeta destacada (hero) con lo más valioso que está listo
   (orden de valor: cofre sin abrir › paquetes › racha del día › giros de Ruleta › video con bonus),
   grande, con su ilustración y su botón. Debajo, el resto de lo listo, en filas.
2. **Después, «Pronto»:** lo que corre con reloj (la próxima Ruleta, el próximo paquete, mañana en la
   racha), con el reloj como protagonista.
3. **Al final, la racha completa** (la tira de 7 días) y la explicación detrás del «?».
4. Si no hay nada para cobrar, la cabecera lo dice con humor y muestra lo próximo con su reloj («Vení en
   12 min: la Ruleta vuelve a girar»), nunca una página vacía.

### La tienda del dólar blue (Mejoras › Permanentes y Boosts, C11)

1. **Cabecera:** saldo de blue grande con su ícono (C8) y el «+» a la Tienda.
2. **«Tu meta»:** una tarjeta arriba que guía el ahorro: la próxima mejora permanente recomendada (por
   defecto, la de mayor impacto que todavía no compraste; el jugador puede fijar otra) con una barra
   «ahorrando: 160 / 200 blue». Cuando alcanza, la barra se vuelve el botón «¡Comprar!».
3. **Permanentes primero**, con el sello «**Para siempre**: se quedan aunque reencarnes»; ordenadas por
   impacto (lugares extra en la torre arriba). **Boosts después**, con el sello «**Por un rato**» y su
   duración, ordenados por precio. Así la página enseña sola qué conviene ahorrar (permanentes) y qué
   conviene gastar en el momento (boosts).
4. Cada fila dice su efecto en números y con imagen («+2 lugares por piso», «×2 ingresos · 30 min»);
   lo que no alcanza muestra cuánto falta; lo comprado al máximo se va al fondo con un check.
5. Una pista contextual cuando aplica (no siempre): «Tenés 3 pisos llenos: los lugares extra te
   destraban» destacando esa fila.

### El resto de las pantallas

Auditoría de las 13 pantallas, los popups y el HUD contra los 8 principios, con una tabla por pantalla
(qué está mal, qué se cambia) en el doc de sesión, captura antes/después en el SE y en el Pro Max, y
la revisión del dueño. Prioridad: Regalos, Mejoras, FisuJobs, Pintas, la ficha del personaje y Ajustes.
La Tienda de plata real queda como referencia de lo que está bien.

**Listo cuando:** al abrir Regalos lo primero que se ve es lo que se puede cobrar ya; al abrir el blue,
la meta de ahorro y las permanentes; y la tabla de auditoría está cerrada con el visto bueno del dueño.
