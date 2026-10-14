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

---

## Orden (≤ 2 compilando)

| Ola | Tareas | Por qué así |
|---|---|---|
| 1 | B11 · B2 · B1 | B11 es un bug que bloquea la pantalla y entra al primer hueco. B2 arregla lo que B5 y B6 van a tocar. B1 es independiente. |
| 2 | B3 · B4 + B10 | B3 depende de que B2 haya cerrado las capas. B4 y B10 tocan el mismo pager: van en la misma tarea o una detrás de la otra. |
| 3 | B5 · B8 + B12 | B5 toca `PickupNode` después de B2 y B3. B8 y B12 son independientes (B12 puede entrar antes, en cualquier hueco). |
| 4 | B6 · B9 | B6 va después de B5 (`PickupNode`). B9 corre en paralelo: el arte se genera mientras tanto. |
| 5 | B7 | Es la que más riesgo tiene en el ritmo. Va sola y con el pacing-sim. |

Al terminar se corre un `completo` solo, se instala en el iPhone del dueño y él mira: el duplicado, las capas y el
horizonte en los 10 escenarios, la caja y el colchón en el tablero, los visitantes simultáneos, el menú, el audio
y los pop-ups.
