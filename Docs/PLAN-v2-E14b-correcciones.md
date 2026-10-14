# E14b — Segunda tanda de correcciones del dueño (2026-10-14)

**Estado:** APROBADO por el dueño el 2026-10-14 11:30. Está en la bandeja del relevo
(`.claude/avo/2026-10-06-fisu-v2/DUENO.md`).

**Prioridad:** va **antes de lanzar la 2.0** (decisión del dueño). Entra después de lo que el relevo 55 tenga en vuelo
y antes de los cierres (E14 T25, T26, T27).

**Base:** `v2i/integ-r54`. Ya está hecho y estas tareas lo modifican: E14 T15 (visitantes, `standY` con 10 fondos
calibrados), T16 (`PickupLayout` a `standY`), T18 (pantalla del paquete, C28) y el cofre de C26.

**Reglas que valen para todas las tareas:** las 7 de la UI sin genéricos (cero SF Symbols, premios siempre ilustrados,
pop-ups centrados) y D14 (cero superposición). Además, el ciclo barato: brief recortado, `oraculo.sh tarea` y la
revisión según el riesgo.

---

## Decisiones del dueño (no se vuelven a preguntar)

| # | Decisión |
|---|---|
| D1 | Antes de lanzar, no en una 2.0.1. |
| D2 | **Caja (Paquete de la Aduana):** el pop-up de C28 sale **sólo la primera vez**. Desde la segunda, **un toque** en el tablero: sacude, se abre y el empleado aparece directamente en la pantalla, **sin pop-up**. |
| D3 | **Colchón, el recorrido:** cuando aparece, está **sólo en la columna** de arriba a la izquierda. Al tocarlo, sale el pop-up (siempre), se ve el video y **el colchón cae al tablero**. Ahí se toca, se abre con la animación y **sale el pop-up del premio, siempre**, con lo que tocó. |
| D4 | **Colchón de regalo:** **1 de cada 4** colchones llega gratis directo al tablero, sin video. Se recalibra el ritmo para seguir en ~45 h. |
| D5 | Desde la columna (Ruleta, caja, colchón), el pop-up se abre **siempre**. |
| D6 | **Visitantes:** al cambiar de piso, todo lo de ese piso **se congela**, tanto la animación como la espera, y sigue cuando se vuelve. Puede haber visitantes en varios pisos a la vez. El aviso del visitante queda arriba y desde ahí se lo puede despachar. |
| D7 | **Tarjeta de la skin en el cofre:** fondo liso del **mismo color para todas**. Según la rareza cambian **el color del brillo y el del sello** que dice la rareza. |
| D8 | **Imágenes nuevas:** se generan con Automatic Image Generation y se **integran directo**, sin pasar por la aprobación del dueño. Si alguna no le gusta, la cambia después. |
| D10 | **Visitantes entre un 20 y un 30 % más grandes**, a la escala de los demás personajes (B3 punto 6). |
| D11 | **Ruleta: 6 giros por día en total, con video o con blue.** Los giros gratis de un evento o un premio no cuentan. Todos los demás sí, hasta 6. La mejora permanente que se compra con blue (`wheelDailySpins`) sube ese máximo. Con el cupo agotado no se gira ni con video ni con blue, aunque sobre blue (B15). Precisado por el dueño, 2026-10-14 ~12:40. |
| D12 | **Descripción de cada personaje en la hoja**, aprobada por el dueño (44 personajes, `es` y `en`, en `Docs/DESCRIPCIONES-personajes.md`). El español con humor argentino, el inglés con humor de Estados Unidos, escrito aparte y no traducido. Sin marcas ni personas reales. **Todo el juego internacionalizado** (B16). |
| D9 | **Todo pop-up lleva una imagen principal**, grande, vistosa y centrada. Las pantallas que dan recompensa llevan además la imagen de «todos los premios juntos» (tesoros con el mate, como en Cow Evolution), grande y arriba de la lista de posibilidades. |

---

## Tareas

### B1 — Música en pausa durante los anuncios
- Cuando empieza un anuncio (recompensado o intersticial), se pausa la música y los efectos. Cuando el anuncio
  se cierra, se reanudan, también si falló o se canceló.
- Archivos: el lugar donde se presentan los anuncios (los delegados de `AdManager`/mediación) y el `AudioManager`.
- **Listo cuando:** un test unitario verifica que el audio se pausa y se reanuda con cada desenlace (visto, cerrado,
  error). Revisión: sonnet.

### B2 — La caja y el colchón: el duplicado y las capas
- **Duplicado:** en el tablero, la caja y el colchón se ven dos veces (captura del dueño del 2026-10-14). Se debuggea
  de forma sistemática antes de tocar nada. Sospechas: el `PickupNode` dibuja el PNG y además el video de espera, o
  hay dos nodos por pickup después de T16.
- **Capas:** la caja y el colchón van **debajo de los personajes**, para que los personajes siempre los pisen. Se
  ajusta la `zPosition` de `PickupNode` frente a la de los empleados y los visitantes.
- **Listo cuando:** hay un solo nodo por pickup (con un test) y un test de orden de capas, más una captura del SE y
  otra del Pro Max revisadas. Revisión: sonnet.

### B3 — El horizonte: menú inferior sólido y personajes sobre el piso
1. **Menú inferior:** color sólido, no transparente, con el **PNG bien recortado**. Hoy se ve un blanco alrededor
   del borde: hay que revisar el canal alfa del asset y si hay un fondo detrás.
2. El fondo del escenario **termina arriba del menú**, así el horizonte sube.
3. Las **hileras bajan**, también las nuevas que se crean al comprar lugares, para que ninguna quede por encima del
   horizonte.
4. **El límite del piso de cada escenario, registrado:** cada fondo declara en su config la altura del horizonte, y
   de ahí salen el máximo para las hileras, para los visitantes y para la caja y el colchón. Esto amplía los
   `standY` de T15 a un único dato por escenario.
5. Se revisa piso por piso que la caja y el colchón no floten. Si con 1–4 no alcanza, cada escenario lleva su propia
   línea para pickups y visitantes.
6. **Escala de los visitantes:** hoy se ven desproporcionados frente a los empleados. Se agrandan entre un 20 y un
   30 %, lo que haga falta para que la altura de su figura iguale a la de un empleado parado en la misma hilera.
   Se mide sobre el cuerpo dibujado y no sobre el lienzo del PNG o del video, que traen márgenes distintos. La
   escala sale de una sola constante relativa a la de los empleados.
- **Listo cuando:** un test verifica que, con el piso lleno y todas las hileras compradas, ninguna fila supera el
  horizonte de ningún escenario. Otro test verifica que la escala del visitante respeta la proporción con los
  empleados. Además, las capturas de los 10 escenarios en el SE y el Pro Max están revisadas, con un visitante
  al lado de un empleado.
  Revisión: sonnet. Toca `StageLayout`, `PickupLayout` y la barra inferior.

### B4 — Transiciones de menú sin trabas
- Al deslizar de un menú al otro, la pantalla parece recargarse. Hay que medir antes de arreglar: con Instruments
  o los logs, ver qué se reconstruye al cambiar de página (sospechas: `MenuPagerView` vuelve a crear las vistas, o
  carga imágenes de forma síncrona).
- **Listo cuando:** el paso entre páginas no reconstruye la vista vecina y no carga imágenes en el hilo principal,
  con una medición antes y después y `MenuPagerUITests` en verde. Revisión: sonnet.

### B5 — La caja se abre en el tablero (D2)
- Se agrega al save el flag `packageIntroSeen` (campo opcional, sin cambiar de versión).
- **La primera vez:** se abre la pantalla de C28 como está hoy.
- **Desde la segunda:** con un toque, la caja del tablero reproduce `paquete_sacude` y `paquete_abre` en el lugar y
  el empleado sale de la caja hacia su lugar en el tablero. No hay pop-up de recompensa. La card de personaje nuevo
  de C24 se mantiene, porque es otra regla.
- Si no hay lugar, se respeta lo de C28 punto 4: la caja no se abre y aparece un aviso arriba (C20).
- Desde la columna o desde Regalos sigue abriéndose la pantalla de C28 (D5).
- **Listo cuando:** un test unitario cubre las dos ramas del flag y un test de UI cubre el segundo paquete sin
  pop-up. Revisión: **opus**, porque toca el save.

### B6 — El nuevo recorrido del colchón (D3, D4)
- **EconomyKit:** el estado del colchón pasa a ser `waiting` (en la columna, pide video), luego `onBoard` (pagado o
  regalado, en el tablero) y por último se abre. El `TreasureScheduler` sortea 1 de cada 4 como regalo, que entra
  directo en `onBoard`.
- **Save:** el estado nuevo con migración, y se mantiene el «otro colchón».
- **Pacing:** se corre el pacing-sim y Dios tiene que quedar en ~45 h. Si se pasa, se ajusta
  `spawnIntervalSeconds`. Se anota en `balance-log.md`.
- **UI:** en el tablero sólo se muestra el colchón `onBoard`. Al tocarlo, `colchon_sacude` y `colchon_abre` se
  reproducen en el lugar y después sale el pop-up del premio (siempre). El pop-up de la columna sigue igual hasta el
  video, y al terminar el video el colchón **cae** al tablero.
- **Listo cuando:** hay tests de EconomyKit con mutantes, la migración del save probada, el pacing en ~45 h y un test
  de UI del recorrido completo. Revisión: **opus**, porque toca plata, save y pacing.

### B7 — Visitantes congelados por piso y simultáneos (D6)
- Cada piso guarda el estado de su visitante: dónde está la animación y cuánto le queda de espera. Al irse del piso,
  todo se congela, y al volver sigue desde el mismo punto.
- `VisitorScheduler` admite un visitante por piso, varios pisos a la vez. Se revisa el ritmo, porque más visitantes
  simultáneos dan más premios: se corre el pacing-sim y, si hace falta, se ajusta para seguir en ~45 h.
- El aviso de arriba lista los visitantes que están esperando, sin amontonarse: un aviso con «×N» o uno por piso
  con tope. Desde el aviso se lo puede despachar. En el ascensor, una marca chica en los pisos con un visitante.
- **Listo cuando:** hay tests unitarios del congelado (tick con el piso fuera de pantalla = espera intacta), un test
  de UI (sube un piso, vuelve y el visitante sigue) y el pacing en ~45 h. Revisión: **opus**, porque toca el save
  y el ritmo.

### B8 — La skin del cofre en una tarjeta de figurita (D7)
- Detrás de la skin va una tarjeta de fondo liso, del mismo color para todas, con borde grueso y el nombre.
  El brillo queda **detrás de la tarjeta** y lleva el color de la rareza (común, oro, diamante). Lo mismo para el
  sello de rareza.
- Archivos: `ChestOpeningView` (de C26) y las piezas del premio del cofre.
- **Listo cuando:** se revisan capturas de las 3 rarezas y `ChestOpeningUITests` está en verde. Revisión: sonnet.

### B9 — Todo pop-up con su imagen (D8, D9)
1. **Auditoría:** se lista cada pop-up del juego y se anota si tiene imagen principal, cuál es y su tamaño.
2. **Ruleta:** se arregla el arte de la ruleta, que hoy se ve **cortado** (sólo la base). Se agrega la imagen de
   «todos los premios» arriba de «What you can get».
3. **Colchón:** arriba, una imagen del colchón. Debajo, la imagen de los premios, **bastante más grande** que hoy.
4. **Moving Day Pack:** una imagen grande de lo que trae (blue, producción y paquetes de la Aduana). Se achica el
   marco, que hoy deja vacía la mitad de abajo.
5. El resto de las pantallas que dan recompensa llevan la imagen de los premios u otra imagen específica.
6. **Arte:** lo que falte se genera en `automatic-image-generation` (proyecto `fisu-v2-premios`), con el estilo de
   los premios aprobados, y se integra directo (D8). La lista de lo generado queda en el doc de sesión, para que el
   dueño lo mire.
- **Listo cuando:** ninguna fila de la auditoría queda sin imagen y se revisan capturas de cada pop-up en el SE
  (sin desbordes) y el Pro Max. Revisión: sonnet.

### B10 — Cabecera de los menús: flechas arriba y pestañas a todo el ancho
- En **todas** las pantallas del menú (Mejoras, Pintas, Ranking, etc.), las flechas ‹ › suben a la misma altura que
  el cartel del título.
- Así el selector de pestañas (por ejemplo, Characters / Permanent / Boosts) ocupa todo el ancho, con margen a
  los lados, y tiene botones más grandes: cada pestaña se lee completa, sin achicar la letra, y es más fácil de
  tocar.
- **Listo cuando:** hay capturas en el SE y el Pro Max de cada menú con pestañas, sin textos cortados, y
  `MenuPagerUITests` está en verde. Revisión: sonnet. Va en la misma ola que B4, porque toca el mismo pager, o
  justo después.

### B11 — El tip de Compartir queda colgado (BUG, va primero)
- Captura del dueño del 2026-10-14: la tarjeta «Share it and grab a bonus! Once per milestone.» (Fisura saludando
  y la pastilla naranja) queda fija en pantalla, sin botón para cerrarla, y no se puede sacar.
- **Causa:** se debuggea de forma sistemática. Sospecha: es un tip del tutorial o de la oferta de compartir (T23
  movió `ShareOfferLayer` arriba) y espera un ancla o un toque que no está en pantalla.
- **Arreglo:**
  1. Se arregla la causa, para que el tip se cierre solo cuando corresponde.
  2. **Todo tip o aviso de este tipo lleva un botón de cerrar** (asset custom, sin SF Symbol), además de cerrarse
     con un toque afuera o con un tiempo máximo.
- **Listo cuando:** hay un test de UI que reproduce el caso de la captura y lo cierra con el botón, y otro test que
  verifica que ningún tip queda sin una salida. Revisión: sonnet.

### B12 — Ajustes con menos ruido visual
- Captura del dueño del 2026-10-14: la pantalla de Settings está muy cargada.
- **Más aire entre secciones:** más margen entre cada bloque (Tutorial, Purchases, Legal, About) y su cinta.
- **Ningún botón naranja:** el naranja queda reservado para las cintas de sección, porque hoy «See what's new in
  2.0» se confunde con ellas. Los botones de acción usan la gramática de botones de la casa (azul o verde, con
  medallón), y en una misma tarjeta, una sola acción principal.
- Se revisan las flechas ‹ › de las filas de Legal y el ícono de restaurar compras, para que no sean SF Symbols
  (regla de la UI sin genéricos).
- **Listo cuando:** hay capturas de Ajustes en el SE y el Pro Max sin botones naranjas y con más separación, y
  `SettingsPrivacyUITests` está en verde. Revisión: sonnet. Es independiente: puede ir en cualquier ola.

### B15 — Los giros con blue gastan el cupo diario de la Ruleta (D11)
- **Hoy (verificado en `integ-r54`):** `WheelRoller` lleva dos cupos separados, `videoSpinsPerDay` →
  `videoSpinsUsed` y `oroSpinsPerDay` → `oroSpinsUsed` (`.oro` es el dólar blue en el código). Los giros con blue
  no tocan el cupo de video. Quien compra mucho blue suma los dos cupos y gira de más, y acelera el juego.
- **Qué cambia (EconomyKit, `WheelRoller`/`WheelConfig`):**
  1. Hay **un solo cupo diario de 6 giros** (`videoSpinsPerDay` = 6, más lo que sume la mejora permanente
     `wheelDailySpins`, que se compra con blue y sube el máximo). Un giro con video **o** con blue descuenta de
     ese cupo.
  2. El tope propio de blue (`oroSpinsPerDay`) deja de sumar giros aparte. Se mantiene sólo como interruptor
     (0 = sin giro con blue en esa tienda). `spinsLeft(.oro)` = lo que queda del cupo único, con la condición de
     tener el blue. Con el cupo en 0, ni video ni blue.
  3. Los **giros de premio** (`bonusSpins`, los que da un visitante, un evento, etc.) **no** gastan el cupo
     diario, como hoy. Si el relevo ve que eso abre otra puerta a girar sin fin con blue (por ejemplo, un premio
     comprable que da giros), lo anota y se lo consulta al dueño; no lo decide solo.
  4. El reseteo diario sigue igual (los dos contadores vuelven a 0 al cambiar el día).
- **Save:** si hace falta un campo nuevo, va opcional y sin cambiar la versión. Si alcanza con sumar a
  `videoSpinsUsed`, no se toca el save.
- **UI:** el botón de blue muestra el cupo que queda (el mismo número que el de video, por ejemplo «4 left») y se
  apaga con el mismo mensaje cuando no queda. Hay que revisar que la Ruleta de la columna y la de Regalos digan lo
  mismo, y que el texto de la tienda de la mejora `wheelDailySpins` (`OroShopCopy`) siga siendo cierto.
- **Pacing:** con menos giros con blue se corre el pacing-sim. Dios tiene que seguir en ~45 h (el cambio sólo
  le saca recompensas a quien compra blue, así que el camino sin pagar no debería moverse). Se anota en
  `balance-log.md`.
- **Listo cuando:** hay tests de EconomyKit con RED por mutación (un giro con blue baja el cupo de video; con el
  cupo en 0 no hay giro con blue aunque sobre blue; `bonusSpins` no toca el cupo; reseteo diario), `WheelUITests`
  en verde y el pacing en ~45 h. Revisión: **opus**, porque toca plata y pacing.

### B16 — Descripción de cada personaje en la hoja e internacionalización completa (D12)
1. **Textos:** `Docs/DESCRIPCIONES-personajes.md` (aprobado por el dueño el 2026-10-14; copiarlo a la integración).
   44 personajes, todos los de `tiers.json`, incluidos los 5 del tier 11 y los 4 del tier 12. Se cargan **tal
   cual**, sin reescribir ni «mejorar». Cualquier cambio de texto lo aprueba el dueño.
2. **Catálogo:** se agregan 44 claves `tier.desc.<id>` en `Localizable.xcstrings`, con `es` y `en`, y se aplican
   en el momento (regla de las claves del relevo 54). Si el catálogo tiene más idiomas, se copia el inglés como
   respaldo y se anota como carry para traducir.
3. **Hoja de personaje** (la que se abre al mantener apretado; `CharacterSheet`): la descripción va **debajo de las
   skins**, con la tipografía de cuerpo de la casa y en un bloque de pergamino. En el SE no se corta: la hoja
   scrollea. Los personajes que todavía no se descubrieron no muestran su descripción, o la muestran tapada,
   igual que hoy con el nombre y la foto.
4. **Todo el juego internacionalizado:** se audita que no queden textos visibles fuera del catálogo (literales en
   `Text("…")`, `String` armados a mano, textos en JSON de config que se muestran sin clave, alertas, avisos,
   accesibilidad) y que las claves tengan `en` y `es` completos. Se agrega un test que falle si aparece un literal
   visible nuevo o si una clave en uso no tiene alguno de los dos idiomas. Esto se coordina con E14 T26 (textos):
   si T26 todavía no corrió, la auditoría va con T26. Si ya corrió, va acá.
- **Listo cuando:** las 44 claves están en el catálogo con los dos idiomas, un test unitario verifica que cada
  `tier.id` tiene su `tier.desc` en `es` y `en`, el test anti-literales está en verde, y se revisan capturas de la
  hoja (SE y Pro Max, en español y en inglés) con un personaje de texto largo (Fondo Buitre Estelar). Revisión:
  sonnet.

---

## Orden (≤ 2 compilando)

| Ola | Tareas | Por qué así |
|---|---|---|
| 1 | B11 · B2 · B1 | B11 es un bug que bloquea la pantalla y entra al primer hueco. B2 arregla lo que B5 y B6 van a tocar. B1 es independiente. |
| 2 | B3 · B4 + B10 | B3 depende de que B2 haya cerrado las capas. B4 y B10 tocan el mismo pager: van en la misma tarea o una detrás de la otra. |
| 3 | B5 · B8 + B12 | B5 toca `PickupNode` después de B2 y B3. B8 y B12 son independientes (B12 puede entrar antes, en cualquier hueco). |
| 4 | B6 · B9 | B6 va después de B5 (`PickupNode`). B9 corre en paralelo: el arte se genera mientras tanto. |
| 5 | B7 · B15 + B16 | B7 es la que más riesgo tiene en el ritmo. B15 es chica, pero también corre el pacing-sim: si chocan en `balance-log.md`, una detrás de la otra. B15 puede adelantarse a cualquier hueco anterior. B16 no toca la economía: puede entrar en cualquier hueco libre, y si E14 T26 todavía no corrió, su auditoría de textos va junto con T26. (B13 y B14 los agregó el relevo 55 más abajo, con su propio orden.) |

Al terminar se corre un `completo` solo, se instala en el iPhone del dueño y él mira: el duplicado, las capas y el
horizonte en los 10 escenarios, la caja y el colchón en el tablero, los visitantes simultáneos, el menú, el audio
y los pop-ups.

### B13 — Toda recompensa se ve llegar: monedas que vuelan al contador (pedido del dueño, 2026-10-14)
- Hoy un evento o un visitante (la Vecina chusma, el Ministro de Economía, el Turista gringo, etc.) da plata y no
  dice cuánto, ni muestra cuánto tenías antes y cuánto tenés ahora. El jugador no siente que recibió algo.
- **Con cada recompensa** (plata, dólar blue, producción, boosts, paquetes, lo que sea), una animación hecha con
  código (sin video, sin arte nuevo obligatorio: los íconos de moneda/blue que ya existen):
  1. Sale del personaje que la da (o del pop-up/sello de origen) un chorro de monedas (o billetes blue, o el ícono
     del premio) que vuela en curva hasta el contador correspondiente del HUD.
  2. Un rótulo grande con el monto (`+$1,2 M`, `+15 blue`) sobre el origen.
  3. El contador del HUD cuenta hacia arriba de lo que había a lo que hay (no salta), con un rebote y un brillo
     al recibir cada tanda; haptic y sonido de moneda (los efectos que ya existen o sintetizados con
     `Tools/audio-synth`).
  4. Los premios que no son plata (boost, paquete, skin) vuelan con su ícono a su lugar (chip de boosts, sello,
     etc.).
- Un componente reutilizable (p. ej. `RewardFlight`) que cualquier fuente llama con origen, destino, tipo y monto;
  todas las fuentes de recompensa lo usan (eventos, visitantes, Ruleta, colchón, cofre, regalos, offline,
  diario). La plata se acredita igual que hoy: la animación es presentación, no cambia la economía ni el pacing.
- Reduce Motion: sin vuelo; el rótulo del monto y el contador que sube con fundido.
- Rendimiento: tope de partículas por tanda (SE con `maxLive = 2` en video: medir fps), sin trabar el tablero.
- **Listo cuando:** un test unitario verifica que cada fuente de recompensa dispara la animación con el monto
  correcto y que el saldo final es el mismo con y sin animación; capturas (o una tira de cuadros) del vuelo en el
  SE y el Pro Max para un evento de plata y uno de blue; D14 cero superposición. Revisión: sonnet (opus si toca
  `grant()` o la acreditación).

### B14 — Cero rastro de «ORO»: todo pasa a dólar blue (pedido del dueño, 2026-10-14)
- E14 T7 (C8) cambió sólo la presentación (48 claves e ícono `ui_dolar_blue`) y dejó intactos los IDs internos. El
  dueño pide más: **no puede quedar rastro de que el dólar blue se llamó ORO**, ni en nombres, ni en imágenes, ni
  en assets.
- **Inventario primero** (`git grep -i` de `oro`, `gold`, `lingote`, `ingot` y parecidos, con cuidado de no tocar
  palabras que sólo contienen «oro», p. ej. «tesoro», «Moron», «decoro»): textos (es/en), nombres de archivos y de
  assets, atlas, `assets_manifest.json`, `loops_manifest.json`, imágenes que muestran oro (monedas doradas,
  lingotes, cofres de oro usados como moneda premium), íconos de la Tienda, capturas de la App Store, docs de
  review, nombres de IAP visibles, notas de ASC.
- **Imágenes:** toda imagen que represente la moneda premium como oro se reemplaza por una de dólar blue (billetes
  azules, fajos, la estética de `ui_dolar_blue`). Las que falten se generan con `automatic-image-generation`
  (Gemini Flash, proyecto `fisu-v2-premios` o uno nuevo `fisu-v2-blue`, estilo de los premios aprobados) y se
  integran directo (D8). La lista de lo generado queda en el doc de sesión.
- **Código:** se renombran tipos, propiedades, funciones, archivos y assets (`oro*` → `blue*`). **Excepciones
  inevitables, invisibles y documentadas:** los IDs de producto de App Store Connect (inmutables, p. ej.
  `oro_medium`) y las claves de decodificación del save viejo (se leen con la clave vieja y se escriben con la
  nueva, con migración y test de ida y vuelta). Ninguna de las dos se ve en la app.
- La rareza «oro» de las skins (común/oro/diamante) **no es la moneda**: se decide en el inventario; si en
  pantalla dice «Oro»/«Gold», pasa a otro nombre que no remita a la moneda vieja (p. ej. «Dorada»/«Golden» o
  «Épica»), y se anota.
- **Listo cuando:** `git grep -i` sólo encuentra las excepciones listadas (con un test o script que lo verifique y
  falle si aparece una nueva), el save viejo migra sin perder blue (test), las capturas de la Tienda, Mejoras,
  pop-ups y HUD en el SE no muestran oro, y el catálogo de textos no tiene «ORO»/«gold» como moneda. Revisión:
  **opus** (toca el save y las compras).
