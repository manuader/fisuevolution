# Estudio de assets — cómo se usa

Una sola herramienta para dejar listo cada asset del juego: la imagen (el
recorte del fondo y las islas que sobran) y su video, con notas para lo que hay
que regenerar. **Reemplaza a las páginas viejas** (`skins-review` y la
«revisión de islas» de `~/Desktop/projects/islas-review`, que quedan como
estaban pero ya no hace falta usarlas): todo lo que hiciste ahí ya está cargado
acá.

## Abrir

Doble clic en **«Abrir Estudio de assets.command»** (en esta carpeta).
Se abre una ventanita negra (Terminal) y Safari con el Estudio.
**No cierres la ventanita negra mientras trabajás**: es la que guarda.

La primera vez macOS puede decir que no puede abrirlo: **clic derecho** sobre
el archivo → **Abrir** → **Abrir**. Después ya abre con doble clic.

Conviene Safari: es el que muestra la transparencia de los videos. Si el video
se ve con fondo, es eso.

## La pantalla

- **Izquierda: la lista.** Buscador y filtros que se combinan (tipo de asset,
  tipo de skin, personaje, atlas, estado de la imagen, estado del video, «con
  notas»). El número entre paréntesis dice cuántos hay. **←** y **→** pasan al
  anterior y al siguiente.
- **Centro: el lienzo.** Rueda del mouse o pellizco para acercar (acerca donde
  está el mouse). Para mover la imagen: **espacio + arrastrar**, el botón del
  medio, o el botón ✋. **Ajustar** (o **F**) la vuelve a encuadrar. Arriba a la
  derecha elegís el fondo: damero, blanco, negro o el color del piso.
- **Derecha: el asset.** Sus datos, su video al lado, los estados y las notas.

## El flujo, en 3 pasos

### 1 · Fondo
Vas a ver lado a lado el **original** (con su fondo blanco, de referencia),
**conectividad**, **rembg** y **en el juego** (cómo está hoy). Acercá para
comparar: las vistas se mueven juntas.

- **Un clic** sobre la vista que va → queda elegida (borde verde).
- **Ninguno sirve** → queda marcado.
- Si rembg dice «calculando…», esperá unos segundos: lo hace en el momento.
- Los que ya elegiste en la revisión de recortes aparecen con su elección.

### 2 · Islas
Tocá **Seguir con las islas →**. Las islas son los pedacitos sueltos (una mota,
una sombra suelta, el blanco encerrado entre las piernas).

- **Sacar** (rojo, tecla **1**): un clic sobre la isla y se va entera — con su
  borde, sin dejar línea clara.
- **Conservar** (verde, tecla **2**): un clic y queda marcada para que se quede.
- Las islas **chiquitas** tienen un aro naranja y están abajo en una lista:
  clic en el nombre para pintarlas aunque no se vean.
- **Pincel** (**P**): borrar a mano lo que la detección no ve. **Goma** (**G**):
  devolver lo que borraste. El tamaño se cambia con la barrita o con **[** y **]**.
- **Cómo queda** (**C**): muestra el resultado de verdad. **C** de nuevo vuelve.
- **↶ / ↷** (**⌘Z** / **⇧⌘Z**): deshacer y rehacer.

### 3 · Guardar
**Guardar** (**⌘S**): guarda el PNG final, lo marca **listo** y te lleva al
siguiente sin revisar. Lo que pintaste y no guardaste no se pierde si cerrás:
queda como borrador en ese navegador.

## Lo que hace cada botón del panel

- **Estado de la imagen**: sin revisar · listo · refinar (hay que volver) ·
  ninguno sirve · regenerar. La nota de abajo es para el generador
  («que tenga dos manos, no tres», «pelo castaño»).
- **Marcar para regenerar**: te pide la nota y elegís si es la imagen o el
  video. Le llega al generador en
  `automatic-image-generation/projects/fisu-evolution-v2/regenerar-desde-estudio.json`.
- **Video — Va / Regenerar / Obviar**: el estado del video (Regenerar pide la
  nota). Se anota también en el `video/revision.json` del generador.
- **Video — qué versión mirar**: la procesada en el Estudio, la del juego, o el
  master (con su fondo).
- **Procesar video**: recorta el master de nuevo, igual que el pipeline, sin
  tocar el juego (tarda un par de minutos; la barrita avisa). «Limpiar motas
  &lt; N px» saca en cada cuadro los pedacitos sueltos más chicos que eso.
- **＋ Importar**: arrastrá (a cualquier parte de la página) o elegí un PNG, JPG
  o MP4. Le ponés el nombre: personaje + skin arman el nombre solo
  (`cartonero` + `vaquero` → `cartonero__vaquero`). Entra como «sin revisar»
  con sus recortes ya hechos. Un video va como master a la carpeta del
  generador; si ya había uno, te pregunta antes de reemplazarlo (el viejo queda
  respaldado en `respaldos/`).
- **Aplicar al juego**: primero muestra el resumen (cuántas imágenes y videos
  listos, y lo que queda afuera y por qué). Si confirmás, lo aplica en una
  **rama nueva** (`v2/estudio-aplicar-<fecha>`), con su propia carpeta: tu copia
  del juego no se toca. Corre los tests del pipeline y, si pasan, lo commitea.

## Al terminar

1. Cerrá la ventanita negra (o Ctrl+C en ella).
2. Si aplicaste al juego, pedile a un agente que **integre la rama
   `v2/estudio-aplicar-…`** (el aviso con el nombre exacto aparece al terminar
   de aplicar). Ahí se mira, se buildea y se mergea como siempre.
3. Lo marcado para regenerar ya está en el archivo del generador: cuando
   vuelvas a generar, sale de ahí.

## Qué hay en esta carpeta

- `registro.json` — el registro central: una entrada por asset con todo lo que
  decidiste. No lo edites a mano.
- `trabajos/<asset>/` — el PNG final y las marcas de cada uno que guardaste.
- `importaciones/` — las imágenes que importaste.
- `videos/` — los videos procesados en el Estudio.
- `importado-previo/` — copia de tu trabajo anterior (las elecciones de
  recorte y las islas del balde), tal cual estaba.
- `respaldos/` — lo que el Estudio reemplazó (el `revision.json` original,
  videos e imágenes viejas).
- `cache/` — recortes y miniaturas calculados. Se puede borrar: se rehacen.
