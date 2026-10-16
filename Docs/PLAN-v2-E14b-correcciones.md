# E14b — Segunda tanda de correcciones del dueño (2026-10-14)

**Estado:** APROBADO por el dueño el 2026-10-14 11:30. Está en la bandeja del relevo
(`.claude/avo/2026-10-06-fisu-v2/DUENO.md`).

**Tercera tanda (B19–B30):** pedida por el dueño el 2026-10-15 con el iPhone en la mano (build `6ee79bf3`); preguntas
respondidas en el chat (D13 y D15–D19). Va también antes de lanzar, después de B17/B18 y antes de los cierres.

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
| D13 | **Capas por profundidad (2026-10-15):** todo lo que está parado en el piso (empleados, visitantes, cajas, colchón) se ordena por la y de sus pies: lo de más abajo en pantalla va adelante. **La burbuja de texto de un visitante va arriba de todo; nada la tapa, ni el HUD** (B19). **El tamaño según la distancia** (más atrás, más chico) **no entra así**: es un experimento, la última tarea de la 2.0, en una rama aparte; el dueño lo prueba y decide (B30). |
| D15 | **Visitantes (2026-10-15):** se paran **en el medio del piso, centrados** (ya no en el horizonte). **Mientras esperan, caminan despacio de lado a lado.** Su llegada **no se corta nunca**: ni con un merge, ni con un toque, ni con otra celebración. **El pop-up se abre sólo al tocarlos**; ya no se abre solo al llegar, como hacía desde E14 T15 (B20, B21). |
| D16 | **«La Marcha» del Puntero (2026-10-15):** 420 toques a mano en una hora de reloj real dan **30 de dólar blue**. Sale **una vez por semana** (B25). |
| D17 | **Recompensas en dos pasos (2026-10-15):** primero se cobra con «¡Dale!»; después sale un segundo pop-up con «×2 con video» y «No, gracias». **Nunca se ofrece duplicar de entrada.** Va **sólo en las recompensas gratis**: las que ya costaron un video no ofrecen ×2 (B29). |
| D18 | **La barra (2026-10-15):** los botones van con el **diseño B, «Etiqueta y billete»** (`capturas-e14b/mockup-botones-barra.html`). Contratar, el del medio, va arriba de todo. El crema de FisuJobs (#F1E5C9) va en **las dos barras**, la de abajo y el panel de arriba (B27, B28). |
| D19 | **La Tienda va en la barra, en el lugar del Ranking. El Ranking pasa a una tarjeta en Menú › Oficina central** y el tutorial lo explica (B26). |

(D14 no es una decisión de esta tanda: es la regla de cero superposición de E14, que vale para todas las tareas.)

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


### B17 — Caja, colchón y los que caminan por el centro, 20 pt más abajo (pedido del dueño, 2026-10-15)
- En el tablero, la caja y el colchón (`PickupLayout`) y los personajes que caminan por el medio de la pantalla
  (visitantes y especiales sobre `StageLayout.standY`) quedan un poco altos: **bajan ~20 pt** («20 píxeles», dijo
  el dueño; se toma en puntos).
- Un único ajuste en el horizonte de B3 (p. ej. `StageLayout.walkDrop = 20` aplicado a `standY` y a
  `PickupLayout.baselineY`), no un parche por escenario. Sin pisar la barra inferior ni las hileras (D14), y con
  los topes de B3 en el SE (moon/mars/galaxy).
- **Listo cuando:** los tests de `StageLayoutTests`/`PickupLayoutTests` pinean el corrimiento y que nada pasa
  debajo de `floorBottom`; capturas SE y Pro Max de 3 escenarios (alley, luxury, moon) con caja, colchón y un
  visitante. Revisión: sonnet. Va junto con B18 o antes (tocan `PickupLayout`).

### B18 — Cada caja pertenece a un piso y trae a alguien de ese piso (pedido del dueño, 2026-10-15)
- **Hoy:** `PackagesState.waiting` es un contador; el contenido se sortea al abrir (`PackageRoller.typeOdds`) y
  la caja se dibuja en el piso que estés mirando. Al cambiar de piso la caja «flota» entre pisos en la transición.
- **Qué cambia:**
  1. **El contenido se decide cuando la caja aparece** (mismo sorteo de hoy: `eligibleTypes` + `typeOdds`, con
     las chances de hoy). El tipo sorteado define **el piso de la caja**: el piso de ese personaje (p. ej. una
     Fisura → el callejón; el dueño de pyme → el piso de lujo que le corresponde por `floorTable`).
  2. **La caja cae sólo en ese piso**, en un **lugar aleatorio** del piso (x al azar dentro de la franja válida de
     `PickupLayout`, sin pisar otras cajas, el colchón, los visitantes ni las columnas; D14), y **se queda ahí**:
     persistida en el save con su piso, su tipo y su posición. Al cambiar de piso se va con su piso (ya no flota en
     la transición) y al volver sigue en el mismo lugar.
  3. **Abrir una caja de un piso da sí o sí ese personaje de ese piso** (el que se sorteó al aparecer). Si al abrir
     el piso está lleno, aplica lo de hoy (C28 punto 4 / B5: no se abre y sale el aviso arriba).
  4. Varias cajas a la vez: cada una en su piso (pueden ser varias en el mismo piso, apiladas o separadas como hoy
     con `stackStep`).
- **Save:** `PackagesState` pasa de `waiting: Int` a una lista de cajas `[{floor, typeId, x}]` (campo nuevo
  opcional, sin cambiar la versión). **Migración:** un save viejo con `waiting = N` sortea al cargar N cajas con
  la regla nueva (o, si no hay candidatos, las deja como «sin asignar» y se sortean cuando haya lugar). Test de ida
  y vuelta y de save viejo.
- **Decisiones por default (el relevo no las re-pregunta; el dueño puede cambiarlas):**
  - La columna y Regalos (D5) abren la caja **del piso que estás mirando**; si en ese piso no hay, **te llevan al
    piso de la caja más vieja** y la abren ahí. La pantalla de C28 (la primera vez, B5) muestra **sólo la cara del
    personaje que trae** esa caja (ya no la tabla de chances, porque el contenido está decidido) — o «?» si se
    quiere mantener la sorpresa: default = mostrar la cara chica con «¡Llega a tu piso N!».
  - El ascensor marca con un ícono chico los pisos con cajas (como la marca de visitantes de B7).
  - Lluvia de paquetes (`package_rain`) y premios que dan cajas: cada caja se sortea y cae en su piso.
- **Pacing:** el sorteo pasa del momento de abrir al de aparecer (con el estado de ese momento). Correr el
  pacing-sim; Dios tiene que seguir en ~45 h (anotar en `balance-log.md`). EconomyKit con mutantes.
- **Listo cuando:** tests de EK (el sorteo al aparecer fija piso y tipo; abrir da ese tipo; migración del save
  viejo; persistencia entre cambios de piso), unit de `PickupController` (la caja sólo se dibuja en su piso, en su
  x, no flota en la transición), UI test (cae una caja de otro piso → no se ve en el callejón; subís con el ascensor
  → está; la abrís → llega el personaje de ese piso) y capturas SE/Pro Max de dos pisos con cajas. Revisión:
  **opus** (save, plata, pacing). Archivos: EK `PackagesState`/`PackageRoller`/scheduler de paquetes,
  `GameState+Packages`, `PickupController`/`PickupNode`/`PickupLayout`, `PackagePopupView`, el ascensor (marca).

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

---

## Tercera tanda (pedido del dueño, 2026-10-15): B19–B30

Las pidió el dueño en el chat después de probar `6ee79bf3` en su iPhone. Respondió las preguntas en el mismo chat (D13
y D15–D19). Capturas: `capturas-e14b/20.jpg` (todo amontonado en un piso alto) y el mockup aprobado de los botones
`capturas-e14b/mockup-botones-barra.html` (diseño B). Los números y las líneas son de `v2i/e14b-b18` (c7e67153), es
decir, con B17 y B18 hechos. **B22 amplía B18:** se integra B18 primero.

### B19 — Capas por profundidad en todo el escenario (D13)
- **Hoy:**
  - Sólo los empleados se ordenan entre sí por su y: `depthZ` en `BoardScene.swift:2096`, recalculado en
    `refreshCrowdDepth` en :572.
  - La caja y el colchón están en una capa fija detrás de todos: `PickupNode.layerZ = 5`, menor que
    `fieldBaseZ = 10`.
  - El visitante está en otra capa fija, delante de todos (`StageController`, z 190).
  - La burbuja de texto vive adentro de la capa del visitante, en SpriteKit. Por eso cualquier vista de SwiftUI la tapa:
    el HUD, `CornersView` con `ActiveBonusBar`, y `prestigeIndicator` («×1,0 → ×1,4»). En `20.jpg`, el texto
    queda cortado por el panel de arriba y por esa pastilla.
- **Qué cambia:**
  1. **Una sola regla de profundidad** para todo lo que está parado en el piso: empleados, visitantes, cajas, el
     colchón y lo que se sume. El z sale de la y de los pies: **más abajo en la pantalla, más adelante**. Hay un
     único helper (p. ej. `DepthOrder.z(forFeetY:)`) que usan todas las capas, y el z se recalcula cuando algo se
     mueve.
  2. Lo que se arrastra, los anillos, las partículas, las etiquetas y las celebraciones siguen arriba, como hoy.
  3. **La burbuja de texto va arriba de TODO; nada la tapa, ni el HUD.** Sale de SpriteKit a una capa de SwiftUI
     por encima del HUD, las esquinas, los chips y los avisos, y sigue la posición del visitante. Sólo los pop-ups
     modales y el tutorial van más arriba. Además, se acomoda para entrar entera en la pantalla (tope arriba y a
     los costados) y, cuando se puede, sin tapar el HUD.
  4. Los toques los recibe lo que se ve adelante. Una caja que está detrás de un empleado se puede tocar en la
     parte que se ve.
- **Listo cuando:**
  - Hay un unit de la regla: entre dos nodos con distinta y, el de más abajo tiene z mayor. Se prueba en las
    combinaciones de empleado, visitante, caja y colchón.
  - Un test verifica que la burbuja queda arriba del HUD y entera en la pantalla, en el SE y el Pro Max, con los
    10 escenarios.
  - Hay capturas de antes y después de la escena de `20.jpg`: un piso alto, un visitante con burbuja larga y un
    boost activo.
- **Revisión:** opus, porque toca el orden de los toques del tablero.
- **Archivos:** `BoardScene`, `StageController`, `SpeechBubbleNode`, `PickupController`, `PickupNode` y `RootView`
  (capa nueva).

### B20 — Visitantes más abajo, al centro, y caminando mientras esperan (D15)
- **Hoy:** se paran en `standY` (el horizonte menos `walkDrop`, 20 pt según B17), en x = 0,5 del ancho.
- **Qué cambia:**
  1. **El visitante se para en el medio del piso:** en y, a mitad de camino entre el horizonte y `floorBottom`
     (la franja de los empleados), y centrado en x. Con B19, tapa a los que están más atrás y lo tapan los de
     adelante. Nunca queda «parado sobre la cabeza» de un empleado: sus pies van en el piso, no en la línea de las
     cabezas.
  2. **Mientras espera, camina despacio de lado a lado** dentro de una zona central (p. ej. del 35 al 65 % del
     ancho). La burbuja va encima y lo sigue, y el visitante se da vuelta en los bordes de la zona.
  3. Ni la pastilla de su boost («Paquetes ×10», en `ActiveBonusBar`) ni los demás chips de las esquinas lo tapan:
     la zona de caminata y la burbuja quedan fuera de los marcos de `CornersView` (D14). Si en el SE no entra, se
     achica la zona, no se encima.
  4. Los visitantes congelados por piso (B7, D6) siguen igual: al volver al piso, retoman la caminata.
- **Listo cuando:**
  - Hay un unit de la geometría en el SE y el Pro Max: la y del medio del piso en cada escenario y la zona de
    caminata sin tocar los chips.
  - Hay una tira de cuadros de la caminata.
  - Hay capturas de 3 escenarios: alley, luxury y moon.
- **Revisión:** sonnet.
- **Archivos:** `StageLayout`, `StageController` y `CornersView` (sólo los marcos).

### B21 — La llegada del visitante no se corta y el pop-up sale sólo al tocarlo (D15)
- **Causa (encontrada en el código):**
  1. Cualquier toque en el tablero pasa por `touchesBegan` → `tapDuringCelebration` → `skipCurrentCelebration`
     (`BoardScene:757` y :557).
  2. `.visitorEncounter` se puede saltear desde los 0,6 s (`CelebrationQueue:107-113`).
  3. Saltearlo llama a `settleStageArrival` → `completeArrival` (`GameState+Stage:227-237`): el visitante
     salta de golpe a su lugar y el mismo toque sigue de largo hasta el merge.
  4. Hay dos caminos más. Un merge que cambia de piso fuerza la llegada: `setVisibleFloor` llega a
     `leaveStageFloor` con la fase `.entering` (`GameState+Stage:156-159`). Y si otra celebración toma el turno,
     `StageController:78-80` llama a `clear()`.
- **Qué cambia:**
  1. **Los toques del tablero no saltean la llegada del visitante.** Los toques van al tablero (merge, arrastre,
     toque de monedas) y el visitante sigue caminando. Cambiar de piso lo congela (D6) en vez de teletransportarlo,
     y ninguna otra celebración lo borra.
  2. **El pop-up se abre sólo al tocar al visitante**, su aviso de arriba o su chip. Ya no se abre solo al llegar,
     como hacía desde E14 T15. En el pop-up se elige: aprovechar la oferta, o «que se vaya», y se va caminando.
  3. Si se le acaba la paciencia, se va caminando, como hoy.
- **Listo cuando:**
  - Hay units para cuatro casos:
    - Un toque durante la entrada no cambia ni la fase ni la x del visitante.
    - Un merge durante la entrada tampoco.
    - Un cambio de piso durante la entrada lo congela.
    - El pop-up no se abre sin un toque.
  - Hay un UI test: entra un visitante, se hace un merge en medio de la entrada, la animación termina entera, y al
    tocarlo se abre el pop-up.
  - Se actualizan los UI tests de T15 que esperan el pop-up automático.
- **Revisión:** opus, por la cola de celebraciones.
- **Archivos:** `BoardScene`, `CelebrationQueue`, `GameState+Celebrations`, `GameState+Stage` y `StageController`.

### B22 — Las cajas caen en cualquier lugar del piso (amplía B18)
- **Hoy (B18, c7e67153):**
  - Cada caja pertenece a un piso y se guarda con su `x` (de 0 a 1) dentro de la franja `packageXRange`.
  - La y es fija: `baselineY` + `index·stackStep`.
  - Todas las cajas de un piso se apilan en la x de la primera (`PickupController:83-87`) y no se separan.
- **Qué cambia:**
  1. La caja guarda **x e y**: `PackageBox{floor, typeId, x, y}`, normalizadas, con `y` como campo nuevo opcional.
     Las cajas de B18 que no tienen y la sortean al cargar.
  2. **Cae en cualquier lugar de la superficie jugable de su piso**, entre el horizonte y `floorBottom` y fuera de
     las columnas, con la regla de capas de B19. Cae desde arriba hasta su lugar; no aparece de la nada.
  3. **Las cajas quedan separadas:** hay una distancia mínima entre cajas, con el colchón y con la zona de
     caminata del visitante (B20). Si el piso está muy lleno, se prefiere un lugar con poca superposición antes que
     no caer.
  4. **Cada caja se queda en su piso y en su lugar:**
     - No viaja con el jugador al cambiar de piso.
     - Se mantiene entre sesiones.
     - Puede haber muchas, en muchos pisos, y el jugador las abre cuando quiere.
     - Abrirla da sí o sí un personaje de ese piso, entre los desbloqueados (B18).
  5. Siguen las marcas del ascensor en los pisos con cajas (B18).
- **Listo cuando:**
  - Hay tests de EK y unit para tres cosas: el sorteo de la posición respeta la franja y la separación; el save
    hace la ida y la vuelta; y un save de B18 sin y carga bien.
  - Un unit de `PickupController` verifica que cada caja está en su x y su y, con el z que le da la profundidad.
  - Hay un UI test: caen 3 cajas en un piso y se ven separadas; al cambiar de piso y volver, están en las mismas
    posiciones.
  - Hay capturas en el SE y el Pro Max.
- **Revisión:** opus, porque toca el save.
- **Archivos:** EK `PackagesState` y `PackageEngine`, `GameState+Packages`, `PickupController`, `PickupLayout` y
  `PickupNode`.

### B23 — El personaje sale de adentro de la caja
- **Hoy:**
  1. La caja se sacude y pasan los clips `paquete_sacude` y `paquete_abre`.
  2. La caja se desvanece mientras se agranda.
  3. El personaje camina 0,5 s desde el punto de la caja hasta su lugar (`walkOutOfTheBox`, `BoardScene:1281-1302`).
- **Qué cambia (animación con código, sin video nuevo):**
  1. La caja se abre, con las tapas que se separan o el clip de hoy, y **el personaje asoma desde adentro**. Sube
     desde el interior, tapado por el frente de la caja (con una máscara, o con el frente dibujado por encima), y se
     estira al salir.
  2. Salta en arco fuera de la caja y **aterriza en el piso**, al lado: se aplasta, rebota y levanta polvo, con la
     profundidad de B19. Después camina a su lugar en la hilera y empieza a deambular.
  3. La caja vacía queda un instante y se va, achicándose o desarmándose. Hay un sonido de salida y otro de
     aterrizaje; si no existen, se sintetizan con `Tools/audio-synth`.
  4. No hay pop-up (D2). Con Reduce Motion, el personaje aparece al lado de la caja con un fundido.
- **Listo cuando:**
  - Hay una tira de cuadros en el SE y el Pro Max.
  - Un unit verifica que el personaje termina en su lugar y que la caja desaparece.
  - No se pierde ningún toque durante la animación.
- **Revisión:** sonnet.
- **Archivos:** `PickupNode`, `PickupController` y `BoardScene` (`walkOutOfTheBox`).

### B24 — El colchón después del video: que se vea, se pueda tocar y muestre el premio (bug del dueño)
- **Lo que dijo el dueño:** «Al mirar el video del colchón no pasa nada: no aparece en pantalla, no lo puedo tocar,
  no hay animación».
- **Lo que se vio en el código.** El camino del estado parece correcto (`mattressVideoWatched` → `payMattress` →
  `markPaid` → `.onBoard` → `syncMattress` + `drop`) y tiene unit tests. Las hipótesis, de la más probable a la
  menos:
  - **H1 (la más probable): el colchón está, pero no se ve.** Va en la capa fija de atrás (z 5) y cae a la altura
    de las cabezas de la hilera de atrás, en x ≈ 281 de 393 pt, entre dos columnas de empleados. Mide unos 83 pt,
    así que los empleados lo tapan.
  - **H2:** la caída arranca debajo del HUD opaco y de la columna. Dura 0,55 s y coincide con el fundido del pop-up
    que se está cerrando.
  - **H3:** la columna de la derecha lo tapa cuando hay varios bonus activos.
  - **H4:** el SDK de mediación avisa la recompensa después de `adDidDismiss`. Entonces `earnedReward` queda en
    false y no se paga (`AdMobAdsProvider:18-31` y :175-181).
  - **H5:** el primer cuadro después del anuncio trae un delta grande y la caída termina al instante.
- **Qué cambia:**
  1. **Primero se reproduce el bug.** Se prueba en el simulador con un anuncio de prueba y, si se puede, en el
     iPhone del dueño con un video real. La causa se confirma con evidencia y se arregla. H4 se verifica con un log
     en el dispositivo.
  2. **Después del video, el colchón cae en el piso que estás mirando:**
     - En un lugar libre de la superficie (la misma regla de lugar que B22, separado de las cajas y del visitante).
     - Adelante, según B19.
     - La caída se ve entera: empieza cuando el pop-up terminó de cerrarse.
     - Rebota, brilla y muestra una manito o un aviso de «¡Tocame!» hasta que lo tocás.
     - Queda en ese piso, como las cajas.
  3. **Al tocarlo,** hace la animación de apertura (como la caja) y sale **siempre** el pop-up del premio, con
     **el nombre y una imagen ilustrativa** del premio. Se usan las imágenes de los premios aprobados; si falta
     alguna, se genera con Automatic Image Generation (D8).
  4. El colchón de regalo (D4) sigue el mismo camino, sin video.
- **Listo cuando:**
  - El bug está reproducido y explicado en el doc de sesión.
  - Hay un UI test: se ve el video (con stub), el colchón queda a la vista (el hit-test en su centro devuelve el
    colchón), se lo toca y sale el pop-up con la imagen.
  - Hay capturas en el SE y el Pro Max.
- **Revisión:** opus.
- **Archivos:** `GameState+Treasures`, `GameState+Prizes`, `PickupController`, `PickupNode`, `PickupLayout`,
  `MattressPopupView` y `AdMobAdsProvider` (sólo si la causa es H4).

### B25 — Evento «La Marcha» del Puntero: 420 toques en una hora (D16)
- **Qué es:**
  - El Puntero (`npc_puntero`) ya existe: tiene arte, loops y su entrada en `visitors.json:14`. Llega como
    visitante con un guion nuevo (p. ej. `puntero_marcha`) y propone la marcha.
  - Si el jugador acepta, arranca **una hora de reloj real**.
  - Si en esa hora hace **420 toques a mano** sobre los personajes, gana **30 de dólar blue**.
- **Mecánica.** Se reaprovecha el desafío de toques que ya existe:
  - `challenge(taps:windowSeconds:)` en `VisitorsConfig:66`;
  - `StageChallenge`;
  - `beginChallenge`, `noteStageTap` y `finishChallenge` en `GameState+Visitors:197-214`;
  - `ChallengeChip`.

  Esa mecánica se extiende a ventanas largas: **la marcha queda en el save** (inicio, toques y fin). Cuenta en
  cualquier piso y sigue aunque se cierre la app, porque el reloj corre igual; al volver, se resuelve.
  - **Qué toques cuentan:** sólo los que se hacen a mano y dan monedas (`registerTap`). No cuentan el autotoque
    comprado (`advanceAutoTap`) ni los dobles toques de merge.
  - **El chip:** va en las esquinas, con anillo, contador y el tiempo que queda: «Marcha 137/420». Al tocarlo se
    abre un pop-up chico con el estado.
  - **El final:** al llegar a 420, el Puntero vuelve (o sale su pop-up) a festejar. El premio se cobra con el vuelo
    de B13 y el ×2 con video de B29 (D17, porque es gratis). Si se acaba la hora, el Puntero dice su línea y no hay
    premio.
  - **La frecuencia:** **una vez por semana**, con un cupo semanal en el scheduler de visitantes. Si el jugador la
    rechaza, no vuelve hasta la semana siguiente. Nunca sale en la primera sesión ni antes de terminar el tutorial.
- **Textos.** Son un BORRADOR: el dueño los ve en el iPhone. El español es rioplatense y el inglés, de Estados
  Unidos, escritos aparte. «420» queda igual en los dos idiomas; en inglés se lee además como chiste de marihuana, y
  el dueño lo sabe.
  - **es:**
    - Burbuja: «¡Hay marcha! Necesito gente que aplauda.»
    - Pop-up: «Mañana se llena la plaza y me faltan aplaudidores. Tocá 420 veces en una hora y te paso 30 blue. No
      preguntes a quién apoyamos: ni yo sé.»
    - Botones: «¡Me prendo!» / «Hoy no marcho»
    - Si gana: «¡Plaza llena! Ahí van tus 30 blue. Y el chori, si quedó alguno.»
    - Si no llega: «Se desconcentró la marcha. La próxima traé bombo.»
  - **en:**
    - Bubble: «Big rally today. I need people who clap.»
    - Popup: «I promised the candidate a packed rally. Tap 420 times in one hour and 30 blue is yours. Free hot
      dogs while supplies last.»
    - Buttons: «Count me in» / «I'll sit this one out»
    - Success: «Packed house! The candidate thinks he's popular now. Here's your 30 blue.»
    - Fail: «Everybody left early to beat the traffic. Next time, bring a foam finger.»
- **Pacing:** son 30 blue por semana, o 60 con el ×2 de B29. Se corre el pacing-sim con los perfiles free y ads;
  Dios tiene que seguir en ~45 h. Se anota en `balance-log.md`. EK con mutantes.
- **Listo cuando:**
  - Hay tests de EK para:
    - la marcha en el save, ida y vuelta;
    - el reloj real;
    - que 420 cobra una sola vez;
    - que al vencer no hay premio;
    - el cupo semanal.
  - Un unit verifica qué toques cuentan.
  - Hay un UI test con una ventana corta, activada por un flag de DEBUG.
  - Hay capturas del chip y de los pop-ups en el SE y el Pro Max, en es y en.
- **Revisión:** opus (blue, save y pacing).
- **Archivos:** `visitors.json`, EK `VisitorsConfig`, `VisitorScheduler` y `VisitPlanner`, `GameState+Visitors`,
  `GameState+Actions`, `StageChips` y el catálogo.

### B26 — La Tienda va a la barra y el Ranking, adentro del Menú (D19)
- **Hoy:**
  - `GameScreen.barOrder = [.ranking, .upgrades, .skins, .jobs, .gifts, .menu]` (`GameArtComponents:1057`).
  - La Tienda sólo se abre con el «+» de la moneda: `hud.coins.plus` → `open(.store)` (`RootView:296-305`, :399
    y :440).
  - El Ranking es pestaña y también página del pager (`MenuPagerView:404` y :413-416). Se oculta con el interruptor
    del servidor (`GameState+Tabs:14-17`).
- **Qué cambia:**
  1. **La Tienda ocupa el lugar del Ranking** en la barra y en el pager:
     `[.store, .upgrades, .skins, .jobs, .gifts, .menu]`.
     - Ícono: `ui_tab_shop`, que ya está en `ui.atlas`. Leyenda: «Tienda» / «Shop».
     - Se desbloquea en el mismo momento en que se desbloqueaba el Ranking (`tabs.json`).
     - El «+» de la moneda sigue abriendo la Tienda, que ahora es su página del pager.
  2. **El Ranking pasa al Menú (Oficina central):**
     - Es un `Destination.ranking` nuevo, con una tarjeta a todo el ancho como la del Álbum (`MenuView:41-47`,
       :57-79 y :91-99), que lleva a `RankingView`.
     - Si el servidor está apagado, la tarjeta no aparece.
     - Su ícono no puede ser el trofeo, porque ya lo usa Logros (`VectorTrophyIcon(.gold)`, `MenuView:69`). Lleva
       uno propio ilustrado, un podio o una medalla; si no hay, se genera con Automatic Image Generation (D8).
  3. El botón `ranking.hook.store` de la cabecera del Ranking sigue llevando a la Tienda.
  4. **Tutorial:**
     - Una lección o un paso nuevo del Tour explica las dos cosas: «La Tienda ahora está abajo» y «El Ranking lo
       encontrás en el Menú». Va anclado a la pestaña y a la tarjeta.
     - A los jugadores que ya vieron el Tour les sale una vez, como novedad.
     - Los textos van al catálogo en es y en, como borrador para el dueño.
- **Tests que cambian:**
  - unit: `GameArtComponentsTests:24-26` y :50; `TabUnlockRulesTests:46` y :59; `TabUnlockWiringTests:32`, 59,
    87 y 96; `MenuSessionTests:38`.
  - UI: `BottomMenuUITests:83-100` y :120-140; `MenuPagerUITests:12-37`; `RankingTabUITests` (ahora entra por el
    Menú); `RankingEntryCardUITests:105`; `AppStoreScreenshotTests:120`; `ProgressiveTabsUITests:12-27`.
- **Listo cuando:** todos esos tests están en verde y hay capturas de la barra y de la Oficina central en el SE y el
  Pro Max.
- **Revisión:** sonnet.
- **Archivos:** `GameArtComponents`, `BottomMenuBar`, `MenuPagerView`, `RootView`, `MenuView`, `tabs.json`,
  `GameState+Tabs` y el tutorial.

### B27 — El crema de FisuJobs en las dos barras (D18)
- **Hoy:** la barra de abajo es `PaletteCream` #FFF8E7 (`GameArtComponents:1235-1253`), que se ve blanca. El fondo
  de adentro del panel de FisuJobs es `PaletteParchment` #F1E5C9 (`PanelFrames:95-104`).
- **Qué cambia:**
  - La barra de abajo **y el panel de arriba, el de la plata,** pasan a `PaletteParchment`.
  - Las solapas (B28) y las tarjetas que van encima mantienen su contraste: hay que revisar que las pestañas
    inactivas y los textos se lean.
- **Listo cuando:** hay capturas en el SE y el Pro Max, en 3 escenarios, y con el sistema en modo oscuro (el juego
  no cambia de color).
- **Revisión:** sonnet. Es chica y puede ir sola en cualquier hueco.

### B28 — Los botones de la barra: diseño B, «Etiqueta y billete» (D18)
- **Referencia:** `capturas-e14b/mockup-botones-barra.html`, diseño B, elegido por el dueño. Lo que hay que
  arreglar, según su captura: Reencarnar tapa a Contratar, el botón del medio.
- **Qué cambia:**
  1. **Contratar un Fisura (la solapa de la izquierda, `QuickHireButton`):**
     - Es una **etiqueta de precio** verde (`PaletteGreen`) con costura punteada crema, ojal y piolín. Se hamaca
       apenas, como si estuviera colgada.
     - **El Fisura de cuerpo entero, saludando** (`fisura_wave`, que ya está en `ui.atlas`), va parado arriba a la
       izquierda, sobresale de la etiqueta y da un saltito cada tanto.
     - El precio va en una placa crema, con la moneda.
     - Es más grande que la solapa de hoy.
     - Cuando no alcanza la plata, queda gris y quieta, y dice por qué no compra, como hoy.
     - Se mantiene todo lo demás: mantener presionado abre el selector, el sacudón de «no alcanza», la accesibilidad
       y los ids.
  2. **Reencarnar (la solapa de la derecha, `PrestigeButton`):**
     - Es un **billete de dólar blue**: celeste, con guarda, esquinas recortadas y marco crema.
     - El sello del billete (`ui_dolar_blue`) sale por la esquina de arriba a la derecha.
     - Dice «Reencarnar» en blanco, con contorno ink, y la meta en una placa crema («Meta: Multimillonario»).
     - Tiene destellos y aletea cada tanto. Cuando ya se puede reencarnar, brilla más.
  3. **Contratar (el plato del medio):**
     - Es una **carpeta de FisuJobs** amarilla, con su pestaña de carpeta, un legajo que asoma, la cara del Fisura
       en el círculo y el sello rosa «FisuJobs». Flota apenas.
     - **Va en la capa de arriba de todo:** no lo tapan ni las solapas, ni los avisos, ni los chips.
  4. **Cada solapa ocupa su mitad.** Su ancho máximo es la mitad de la barra, menos el plato del medio y un margen.
     Nunca entran al hueco del plato: en el SE, se achican antes que pisarlo, y el texto usa
     `minimumScaleFactor`.
  5. Todo se hace con código (Shapes de SwiftUI, sin SF Symbols) y con los assets que ya existen. Reduce Motion
     apaga la hamaca, el saltito y el aleteo.
- **Listo cuando:**
  - Un unit de la geometría verifica que ningún marco de solapa se cruza con el del plato, en el SE, el 15 Pro y el
    Pro Max, en es y en, con textos largos.
  - Los UI tests de `hud.quickhire` y `hud.prestige` siguen verdes.
  - Hay capturas en el SE y el Pro Max, comparadas con el mockup.
- **Revisión:** sonnet.
- **Archivos:** `BarFlaps`, `QuickHireButton`, `PrestigeButton`, `BottomMenuBar` / `GameTabBar` (el plato) y
  `GameArtComponents`.

### B29 — Toda recompensa gratis en dos pasos: primero se cobra y después «×2 con video» (D17)
- **El pedido:** el Ministro de Economía ofrece plata con «Dale ×2 con video» y «No, gracias» en el mismo pop-up.
  Nadie quiere rechazar la plata, así que el ×2 convierte poco. Se pasa a dos pop-ups, en **todo** el juego, para
  convertir más anuncios.
- **Qué cambia:**
  1. **Paso 1:** el pop-up de la recompensa tiene un solo botón, «¡Dale!» (o el que corresponda), que **cobra**
     con el vuelo de B13.
  2. **Paso 2:** enseguida sale un segundo pop-up, centrado: «¿Lo duplicás?», con la misma recompensa y los botones
     **«×2 con video»** y **«No, gracias»**.
     - Si se ve el video, se cobra otra vez lo mismo, con su vuelo.
     - Si no hay un anuncio cargado (o no hay consentimiento, o no hay conexión), el paso 2 no aparece.
  3. **Nunca** se ofrece duplicar en el primer pop-up.
  4. **Alcance (D17):** sólo las recompensas **gratis**.
     - Las que ya costaron un video no tienen paso 2: el colchón con video, el giro de Ruleta con video, etc.
     - Lo que no se puede duplicar, como una skin única o un personaje de la caja, tampoco.
  5. **Primero, el inventario.** Queda en el doc de sesión: todas las fuentes que dan algo y cómo lo ofrecen hoy.
     - Visitantes y especiales: el Ministro, la Vecina, el Turista, el Puntero, el Conductor, el Arbolito, etc.
     - Eventos.
     - Regalos y el diario.
     - Las ganancias de cuando no jugabas.
     - La Ruleta con giros gratis o de bonus: su «Repetir premio» con video se unifica con este paso 2.
     - El colchón de regalo (D4).
     - El cofre.
     - Los logros.
     - La Marcha (B25).

     Las que hoy ofrecen el ×2 de entrada (p. ej. `puntero_bolson`, que se duplica con un video) pasan al esquema
     nuevo. Todas usan un componente único (p. ej. `RewardDoubleOffer`).
  6. **Pacing y anuncios:**
     - El ×2 ya existía en varias fuentes; las nuevas suben el perfil `ads` del pacing-sim. Hay que correrlo (el
       perfil free no cambia) y Dios tiene que seguir en ~45 h. Se anota en `balance-log.md`.
     - En AdMob habrá más impresiones de rewarded: revisar los topes de frecuencia de `ads.json` y
       `rewarded_ads.json` y dejarlos anotados.
- **Listo cuando:**
  - El inventario está completo.
  - Hay un unit por fuente que cubre cinco casos:
    - el paso 1 cobra 1×;
    - el paso 2, con el video visto, cobra otra vez;
    - «No, gracias» no cobra;
    - sin anuncio no hay paso 2;
    - las fuentes que ya costaron un video no tienen paso 2.
  - Hay un UI test con el Ministro (con stub del anuncio).
  - Hay capturas de los dos pop-ups en el SE y el Pro Max.
- **Revisión:** opus (plata, anuncios y pacing).
- **Archivos:** todos los pop-ups de recompensa, `RewardedOfferButton`, `GameState+Rewards` y `RewardFlight`.

### B30 — Tamaño según la distancia (EXPERIMENTO: última tarea, en una rama aparte) (D13)
- **Qué es:** lo que está más atrás (más cerca del horizonte) se ve un poco más chico, y lo de adelante, un poco más
  grande. Se calcula en tiempo real, según la y de los pies, para los empleados, los visitantes, las cajas y el
  colchón.
- **Va en una rama aparte**, `v2/e14b-b30-escala`, que sale de la integración con todo E14b. **No se mergea** hasta
  que el dueño lo pruebe en el iPhone y diga que sí.
  - Es la última tarea antes de los cierres, o después, si los cierres ya están listos.
  - Si el dueño dice que no, se descarta sin costo.
- **Parámetros chicos,** para que el cambio en tiempo real no se note:
  - p. ej. de 0,85× en el horizonte a 1,0× adelante;
  - con una curva suave y sin saltos mientras deambulan;
  - y sin que el área de toque quede por debajo del mínimo, para que siga siendo fácil tocar.
- **Listo cuando:** la Release de esa rama está instalada en el iPhone del dueño y la pregunta quedó hecha en
  `DUENO.md`.
- **Revisión:** sonnet.

### Orden de la tercera tanda (≤ 2 compilando, sin compilar por tarea: se compila la ola entera)

| Ola | Tareas | Por qué así |
|---|---|---|
| 6 | B19 · B27 · B26 | B19 es la base de capas que usan B20 a B24. B27 es chica. B26 toca la barra y el pager, y no choca con B19. |
| 7 | B20 + B21 · B22 + B23 · B28 | B20 y B21 tocan las dos el visitante (`StageController`), así que van en el mismo agente. B22 y B23 son las cajas (`PickupController`) y van después de integrar B18. B28 toca la barra, después de B26 y B27. |
| 8 | B24 · B29 → B25 | B24 usa el lugar de B22 y las capas de B19. B29 cambia todos los pop-ups de recompensa, y B25 cobra con B29, así que va después. B25 y B29 corren el pacing-sim: una detrás de la otra si chocan en `balance-log.md`. |
| 9 | B30 | Es un experimento en una rama aparte; decide el dueño. |

Al terminar la ola 8, se corre un `completo` y se instala en el iPhone del dueño. Él mira las capas en los 10
escenarios, el visitante caminando y su burbuja, las cajas por el piso y saliendo de la caja, el colchón después del
video, la barra nueva con la Tienda, los dos pasos del ×2 y La Marcha (con la ventana corta de DEBUG).

## Cuarta tanda (pedido del dueño, 2026-10-15, noche): B31–B33

Las pidió el dueño en el chat «Fisu Evolution v2 roadmap», con el iPhone en la mano. Aprobó dos mockups:
`capturas-e14b/mockup-caja-difuminado.html` (opción A, difuminado corto) y
`capturas-e14b/mockup-boton-compra.html` (opción B, sólo la cara).

| # | Decisión |
|---|---|
| D20 | **Colchón gratis cada 30 minutos:** cae en el tablero para abrirlo cuando quieras. **Se suma** a los de video de la columna, que siguen cada 12 minutos. **El «1 de cada 4 gratis» (D4) desaparece**, porque lo cubre este. Corre con **reloj real** (también con el juego cerrado) y **guarda uno solo**: mientras haya uno sin abrir, no cae otro. |
| D21 | **Caja sin el corte de los rayos: difuminado corto.** El 15 % de arriba del video se funde a transparente; sólo los rayos, no las tapas. |
| D22 | **Botón de compra con la cara del personaje que comprás:** la cara en un círculo que sobresale de la etiqueta, y su nombre arriba del precio. Reemplaza al Fisura fijo de B28. |

### B31 — Un colchón gratis cada 30 minutos en el tablero (D20)
- **Hoy:**
  - `treasures.json`: `spawnIntervalSeconds: 720` de juego activo. El colchón va a la columna y se abre con video (D3).
  - `giftOneIn: 4`: uno de cada cuatro cae gratis directo al tablero (D4, B6).
  - Al tablero, B24 lo deja caer a la vista, con «¡Tocame!», y al tocarlo se abre con animación y pop-up del premio
    con imagen.
- **Qué cambia:**
  1. **Un reloj nuevo, aparte del de la columna:** cada **30 minutos de reloj real** cae un colchón **gratis** en el
     tablero. Usa la misma caída, el mismo lugar libre del piso que estás mirando (reglas de B22/B24), las capas de
     B19 y el «¡Tocame!».
  2. **Con el juego cerrado el reloj sigue:** al volver, si pasaron 30 minutos o más, te espera **uno solo**. Nunca se
     acumulan.
  3. **Mientras haya uno sin abrir, no cae otro:** el reloj de 30 minutos arranca de nuevo **al abrirlo**.
  4. **Al tocarlo:** la animación de apertura, el pop-up del premio con nombre e imagen (B24) y, como es gratis, el
     «×2 con video» en dos pasos (D17, B29).
  5. **Se saca `giftOneIn` (D4):** los colchones del ciclo de 12 minutos van todos a la columna, con video, como
     antes. Si sacarlo deja código muerto, se borra.
  6. **El premio** sale de la misma tabla de premios del colchón de hoy, salvo que el pacing pida otra (ver abajo).
- **Save:** campo nuevo opcional, por ejemplo `TreasuresState.freeBoard { lastDropAt, waiting }`, sin cambiar la
  versión. Un save viejo arranca el reloj al cargar. Test de ida y vuelta.
- **Pacing:** el perfil free gana unos dos colchones por hora de juego (y uno por cada vuelta tras 30 minutos o más) y
  pierde el 1 de 4. Correr el pacing-sim: Dios tiene que seguir en ~45 h. Si se acelera, se ajusta la tabla del colchón
  gratis, no el intervalo (el intervalo lo fijó el dueño). Se anota en `balance-log.md`. EK con mutantes.
- **Listo cuando:**
  - Hay tests de EK: el reloj real; se guarda uno; el reloj arranca al abrir; es independiente del ciclo de 12
    minutos; `giftOneIn` ya no existe; save viejo y ida y vuelta.
  - Hay un UI test con un intervalo corto por flag de DEBUG: cae, se toca, sale el pop-up y después el ×2.
  - Hay capturas en el SE y el Pro Max.
- **Revisión:** opus (save, pacing).
- **Archivos:** EK `TreasureScheduler`/`TreasureEngine`/`TreasuresState`, `treasures.json`, `GameState+Treasures`,
  `PickupController`.

### B32 — La caja sin el corte de los rayos (D21)
- **Hoy:** en `obj_paquete_abre.mov` (512×512, HEVC con alfa, 73 cuadros), los rayos y el halo marrón llegan al borde
  de arriba del cuadro y se cortan en línea recta.
- **Lo que se midió:**
  - las tapas abiertas quedan cerca del 17 % desde arriba;
  - durante el salto de la apertura, unos pocos cuadros, llegan al 8 %;
  - la caja cerrada empieza en el 21 %.
- **Qué cambia:**
  1. **Se hornea en el asset**, no como efecto en tiempo real: se vuelve a exportar `obj_paquete_abre.mov` con el alfa
     multiplicado por un degradé vertical que va de 0 en el borde de arriba a 1 en el **15 %** de la altura.
  2. El degradé se aplica **sólo desde el cuadro en que aparecen los rayos**. Así el salto de las tapas (8 %) queda
     intacto.
  3. Se mantienen el formato (HEVC con alfa, `hvc1`), el tamaño y la duración; el peso, parecido.
  4. Se hace con un script reproducible en `Tools/asset-pipeline/` (AVFoundation para leer y escribir con alfa;
     `ffmpeg` no lee el alfa de estos `.mov`). Se guarda el original como respaldo según la convención del pipeline.
  5. **Barrido:** con el mismo script se revisan `obj_paquete_espera`, `obj_paquete_sacude` y los clips del colchón y
     del cofre. Si alguno toca el borde con algo que no sea su contorno, se le aplica la misma regla y se anota cuál.
- **Listo cuando:**
  - Hay una tira de cuadros antes y después (como la del mockup) en el doc de sesión.
  - El test del pipeline de assets está verde.
  - Hay capturas en el SE y el Pro Max de la caja abriéndose en el tablero.
  - Coincide con la opción A del mockup aprobado.
- **Revisión:** sonnet.

### B33 — El botón de compra muestra al personaje que vas a comprar (D22)
- **Hoy:** desde B28, `QuickHireButton` dibuja siempre `fisura_wave` (el Fisura saludando, fijo). Cae a la cara por
  `faceKey` sólo si falta el arte. El dueño no sabe a qué personaje está comprando.
- **Qué cambia:**
  1. **Se saca el Fisura fijo.** En su lugar va **la cara del personaje que ofrece el atajo** (`offer.faceKey`, que
     ya existe para las 43 caras):
     - en un círculo crema con aro ink de 3 pt y sombra;
     - sobresale de la esquina de arriba a la izquierda de la etiqueta, como en el mockup (opción B);
     - con el saltito cada tanto; Reduce Motion lo apaga.
  2. **El nombre del personaje** (`tier.name.<id>`, en es y en) va en mayúsculas chicas, en color marrón, arriba del
     precio y adentro de la placa crema, con `minimumScaleFactor`. Tiene que entrar «CARTONERO» y los nombres más
     largos en el SE.
  3. **La cara y el nombre cambian cuando cambia la oferta:**
     - al cambiar de piso;
     - con el modo «el primero del piso» (E14 T10);
     - al elegir en el selector (mantener presionado).
  4. **Se mantiene todo lo demás de B28:**
     - la etiqueta verde que se hamaca;
     - el gris cuando no alcanza;
     - el sacudón;
     - el selector;
     - los ids;
     - la accesibilidad: el label dice el nombre y el precio.
- **Listo cuando:**
  - Hay unit de la vista: la cara y el nombre de la oferta, y el cambio de oferta los cambia.
  - Hay un UI test: cambiás de piso y la cara del botón es la del tipo base de ese piso.
  - Hay capturas en el SE y el Pro Max con tres personajes de nombre largo y corto, comparadas con el mockup.
- **Revisión:** sonnet.
- **Archivos:** `QuickHireButton`, `BarFlapArt` (si la etiqueta vive ahí) y el catálogo (si falta alguna clave).

### Orden de la cuarta tanda
B32 y B33 son chicas y no se pisan: entran en cualquier hueco. B31 va después de B24 y B29 (usa la caída del colchón y
el ×2) y corre el pacing-sim: no en paralelo con otra tarea que lo corra (B25).

> **Regla del dueño (2026-10-16, en vivo):** el colchón sigue la misma dinámica que la caja (B18/B22): pertenece a un piso, se persiste por piso con su lugar y se queda ahí; no navega con el usuario por los pisos. Vale para el colchón de la columna y el de B31.

### B34 — El logo de Ader Games en la pantalla del principio y en la de lanzamiento (D23, 2026-10-16)

| # | Decisión |
|---|---|
| D23 | **El logo de Ader Games reemplaza a la cara con corona** del splash. Es la opción A del mockup `capturas-e14b/mockup-splash-adergames.html`: el Fisura festejando, la ruedita y el consejo quedan. **También va en la pantalla de lanzamiento de iOS**, el primer cuadro. |

- **Hoy:**
  - `SplashView` (`App/RootView.swift`, ~:49) dibuja arriba `UIArt.image("logo")`, que es la cara del Fisura con
    corona de `ui.atlas`. Si falta, dibuja el wordmark «FISU EVOLUTION».
  - Abajo van `fisura_celebrate`, la ruedita naranja y un consejo.
  - La pantalla de lanzamiento (`Info.plist › UILaunchScreen`) es crema lisa (`UIColorName: PaletteCream`).
- **El asset:** el logo del sitio `adergames-site/public/brand/logo.png` (1254×1254) tiene **fondo negro sin alfa**.
  La sesión del dueño ya lo recortó: le sacó el fondo con un relleno por inundación desde los bordes (umbral 18).
  Quedan las letras blancas 3D con su contorno oscuro y el resto transparente. Está en
  `capturas-e14b/adergames-logo-recortado.png`. Para integrarlo:
  - recortar al rectángulo del contenido;
  - revisar el borde: el alfa del recorte es binario; si se ve serruchado, suavizarlo 1 px;
  - exportar a @2x/@3x.
- **Qué cambia:**
  1. **Splash:** donde estaba la cara con corona va el logo de Ader Games, de ~180 pt de ancho, igual que en el
     mockup. Lo demás no cambia. El label de accesibilidad es «Ader Games». El respaldo tipográfico queda para el
     caso en que falte el asset.
  2. **El asset `logo` de `ui.atlas` (la cara con corona) no se borra** si se usa en otro lado (compartir, Tienda,
     etc.); sólo deja de usarse en el splash. Si no lo usa nadie más, se borra del atlas y del manifest.
  3. **Pantalla de lanzamiento:**
     - `UILaunchScreen` suma `UIImageName` con el logo, como imageset en `Assets.xcassets`; tiene que ir en el
       catálogo, no en el atlas.
     - Se mantiene `UIColorName: PaletteCream`.
     - iOS lo dibuja centrado y a su tamaño natural: se exporta al tamaño en puntos que se quiere ver (~180 pt).
  4. **Que no salte:** la pantalla de lanzamiento centra el logo y el splash lo dibuja arriba. Para que el paso de una
     a otra no se vea como un salto, el splash arranca con el logo centrado, en el mismo lugar y del mismo tamaño que
     en la pantalla de lanzamiento, y en ~0,4 s sube a su lugar mientras aparecen el Fisura y el consejo. Con Reduce
     Motion, sin movimiento: fundido. Si el relevo ve una forma más simple de que no salte, va esa.
- **Listo cuando:**
  - Hay capturas del splash en el SE y el Pro Max, comparadas con la opción A del mockup.
  - Hay un video corto o una tira de cuadros del paso de la pantalla de lanzamiento al splash, sin salto.
  - Los tests que miran el splash o el asset `logo` están al día.
  - Se verifica en el iPhone, porque la pantalla de lanzamiento queda en caché: reinstalar o reiniciar.
- **Revisión:** sonnet.
- **Hecho (relevo 60):** imageset `AderGamesLogo` (@2x/@3x, 180 pt, generado con `Tools/v2/logo_adergames.py`), `UIImageName` en
  `Info.plist`, `SplashView` con el logo que sube del centro en 0,4 s (fundido con Reduce Motion). El `logo` de `ui.atlas`
  **queda**: lo usa `ShareArt` (la tarjeta de compartir). Capturas y video del paso: del controlador al compilar.
- **Arreglo (relevo 60, b34-fix-r60):** en el arranque en frío el splash dura menos que la subida, y el último cuadro
  que se veía era el logo a mitad de camino encima de la cabeza del Fisura, que se fundía a la vez. Ahora el logo sube
  solo (con la ruedita y el consejo) y el Fisura aparece recién cuando el logo llegó arriba; con Reduce Motion todo
  aparece junto por fundido. El logo doble del cuadro de paso es el fundido del sistema entre la pantalla de
  lanzamiento y la app, no dos logos de la app. Capturas en `capturas-r60/b34-fix/`.
