# Sesión 2026-08-28 — El cofre animado por video

> Pedido del dueño, textual: «acabo de agregar la animacion de cofre
> chest-animation.mp4 al directorio. tiene una pantalla verde. sacale la
> pantalla verde e integrala al juego para mejorar la animacion de apertura de
> cofres. si es necesario, extrae frames del video y genera assets apartir del
> nuevo cofre para meter en los demas lugares del juego. hace un plan para
> integrar la animacion de manera fluida y suave, completamente integrado, en
> especial en lo visual. high end y profesional.»
>
> **Y la enmienda, a mitad de vuelo** (misma sesión, textual): «saca la
> animacion que hiciste antes con los demas assets y deja solo el video. usa el
> video completo y finalmente reenderiza el contenido de la carta en donde
> corresponda (carta vacia en el video)».
>
> Spec (con la enmienda en §8): `Docs/superpowers/specs/2026-08-28-cofre-animado-por-video-design.md`
> · Plan: `Docs/superpowers/plans/2026-08-28-cofre-animado-por-video.md`.

## Las dos rondas en una línea

La primera ronda integró el video como EL COFRE (sacudidas y estallido reales)
conservando los rayos, las partículas y la carta `PanelCard` de la casa; la
enmienda del dueño lo dio vuelta: **el video entero es la animación** — cofre,
estallido, carta que sube, gira y termina en un marco vacío — y el contenido
del premio se renderiza dentro de ese marco. De la coreografía de la casa
quedaron los tres toques del candado, los hápticos, el telón, el respiro y los
botones; murieron `ChestShake`, `ChestDrop`, `FlyingLid`, el flash, los rayos
teñibles, las ráfagas y la carta SwiftUI con su flip 3D.

## El keying: la trampa del limited range

El croma se mide EN EL STREAM: **0x0BB427** con la matriz limited-range del
yuv420p. El mismo verde convertido con la matriz full-range da 0x189D30, parece
idéntico a simple vista, y con él `chromakey` de ffmpeg **se come el cofre
entero** — la métrica de `similarity` además es mucho más agresiva de lo que la
doc sugiere (la banda útil quedó en 0,08–0,14; embarcado: `0.11:0.04` +
`despill=type=green`). El glow dorado que se funde al verde queda con alfa
parcial y sobre el telón negro al 55 % del overlay se comporta como luz, que es
exactamente cómo el video fue diseñado para verse.

## El formato es híbrido, y es medido

| Tramo | Formato | Por qué |
|---|---|---|
| idle + dos sacudidas (f0–f47) | **36 PNG cuantizados** (1,4 MB), `ChestAnimationFeed` | responden al DEDO: el swap tiene que salir en el mismo cuadro, y un seek de AVPlayer mete latencia variable |
| estallido → marco vacío (f48–f239, 8 s) | **`chest_open.mov` — HEVC con canal alfa** (3,0 MB, `hevc_videotoolbox -q:v 50 -alpha_quality 0.6`, hvc1) | es LINEAL: por hardware pesa 4× menos que en PNGs (~12 MB medidos) con 24 fps garantizados; q50 es indistinguible del original en A/B |
| estado final (Reduce Motion / fallback) | `chest_card_still.png` (f239 a 0,8; 31 KB) | estado final quieto, regla del design system |

Total de `Resources/ChestAnim/`: **4,5 MB**. Es el **primer AVFoundation del
repo** (`ChestCinematicPlayer`: AVPlayer + AVPlayerLayer transparente,
`actionAtItemEnd = .pause` — el video queda clavado en el marco vacío — y
`awaitEnd` con tope para que un decoder trabado no cuelgue la cola). El preroll
se paga en la llegada, latidos antes de reproducir.

- Todos los encuadres comparten el lienzo 1280×720 en el que el cofre no se
  mueve (`chestRect` (431,257,407,363)): una sola ancla y el empalme PNG→video
  es invisible (f47 y f48 son el mismo cofre quieto; el PNG queda montado
  debajo del video tapando cualquier hueco del arranque del decoder).
- `parchmentRect` (489,143,302,424; medido por componente conexa en f239) es
  la segunda ancla: el interior vacío de la carta, donde `cardContent`
  (retrato 96 pt con plato, cinta de rareza, nombre, subtítulo) aparece cuando
  el video pausó.
- **El push-in**: zoom del escenario 1 → 1,3 (easeInOut 3,2 s) mientras la
  carta sube, anclado al centro del pergamino — así el marco final queda en
  ~200 pt de ancho. El contenido vive FUERA del subárbol escalado (texto bajo
  `scaleEffect` queda rasterizado y estirado) y como el pergamino es el ancla,
  su centro no se mueve: la posición del contenido es la misma con y sin zoom.
- El háptico `.rarity` del flip de la carta se dispara **por reloj** (f197 =
  6,2 s del tramo), no por observer del player: el `.task(id: beat)` ya es
  cancelable y no hay closures `@Sendable` que pelear.
- `ChestAnimationFeed` (los PNGs): playhead por FECHA sobre
  `TimelineView(.animation(paused:))` — sin deriva, los cuadros comidos se
  saltean solos, `paused` al mostrar el último frame (ningún display link vivo
  fuera de una reproducción), ventana deslizante de decode con
  `preparingForDisplay()` y rescate sync (~3 ms) si la ventana no llegó.
- La sacudida B lleva crop propio (60,40,1160,620): tira el polvo más lejos y
  el escenario común le cortaba el 1,37 % de la masa de alfa (el pipeline lo
  mide y avisa con umbral 0,7 %).

## Lo que la enmienda se llevó (y hay que saber)

- **El anuncio de rareza del segundo toque murió con los rayos teñibles**: la
  rareza ahora se revela con la cinta dentro del marco. Era el mecanismo de
  anticipación del diseño de la sesión de cofres; si el dueño lo extraña, la
  vía de vuelta es un glow vectorial teñido detrás del cofre (no hay más FX de
  atlas).
- `fx_burst_rays`, `fx_star` y `fx_sparkle` quedaron sin llamadores y salieron
  de atlas y manifest, igual que `ui_chest_cracked/open/lid` en la primera
  ronda (siete assets menos; los masters siguen en git).
- El **cuarto toque** murió: la carta se da vuelta sola en el video. Son tres
  toques y el espectáculo; el tramo cinemático NO se saltea (decisión
  conservadora: el dueño pidió el video entero — si 8 s molestan en el juego
  real, un tap-para-acelerar es la palanca y la decide él).
- Las claves `chest.title.skin`/`chest.title.coins` y `chest.card.facedown`
  quedaron sin uso en el catálogo (el banner del título y el dorso murieron);
  no se borraron para no tocar el xcstrings a mano — anotadas acá para la
  próxima pasada de limpieza.

## Los demás lugares del juego

`ui_chest_closed` se regeneró desde el f0 del video, con el aire calzado a la
**ocupación del PNG viejo (84,4 % del ancho)** para que la tarjeta de Regalos
(44 pt) y el premio diario (52 pt) no cambien de tamaño percibido — cero
cambios de código en esos call sites.

## Verificación

| qué | dónde | resultado |
|---|---|---|
| Pipeline Python (12) | `unittest` | **12/12** ✅ |
| Unit del cofre (loader+feed, 11) | sim iOS 26.5 | **11/11** ✅ |
| `ChestOpeningUITests` (2) | sim iOS 26.5 | **2/2** ✅ (⚠️ fallaron UNA vez en el primer arranque post-instalación — la app en frío con el decoder recién estrenado; en la repetición y en corridas posteriores pasan; las transiciones de latido quedaron logueadas con `Log.assets` para diagnosticar si reaparece) |
| EconomyKit | `swift test` | **262/262** ✅ |
| Unit sin Store (447 + 11 nuevos) | sim iOS 26.5 | **458, con el ÚNICO rojo declarado** (`PacingTests.theOwnersTargetsAreMet`: 9 vs ≤8 reencarnaciones — preexistente, es contrato) |
| Store unit (10+2) | sim iOS 18.6 | 🔴 **`StoreManagerTests` con fallos ROTATIVOS de entorno** (ver abajo); `StoreProductsTests` 2/2 ✅ |
| UI sin Store | sim iOS 26.5 | **53, con 2 rojos re-verificados**: el de Regalos era MÍO (el 4º tap del flujo viejo — adaptado a 3 toques, verde), el del menú pasó aislado sin cambios (carga del sim, precedente del general) |
| StoreUITests | sim iOS 18.6 | **2/2** ✅ |
| Smokes con captura | sim 26.5 | ✅ sacudida limpia · carta girando sin costura de encuadre (feather) · marco final con retrato+cinta+nombre+subtítulo y botones sin rozar el marco |

### 🔴 `StoreManagerTests` en 18.6: la infraestructura falló HOY, y no es de esta rama

Tres corridas, fallos ROTATIVOS con la misma firma del breakage conocido de
StoreKit Testing: primero `loadsTheCatalogProducts` (`.failed` tras 268 s de
catálogo vacío), después `refundRevokesEntitlement` (el refund no revoca), y
en la tercera —con el sim BORRADO a cero— los dos. Lo que se verificó antes de
declararlo entorno: **el diff completo de esta sesión no toca un solo archivo
de Store** (`git diff 78711c8..HEAD` — cero matches), Xcode NO cambió de build
(26.6/17F113), `StoreUITests` pasa 2/2 en el mismo sim, y ayer (2026-08-27)
los 12 pasaron en 18.6 en la corrida del cierre de cofres. Es la máquina hoy,
no el árbol. Señal de re-verificación: `StoreManagerTests` entero en un sim
18.6 virgen un día que la máquina esté sana.

## Decisiones de esta tanda

| Decisión | Por qué |
|---|---|
| Híbrido PNG + HEVC-alfa, no todo-frames ni todo-video | el dedo pide swap inmediato (PNG); lo lineal pide hardware (12 MB → 3 MB); cada formato donde es fuerte |
| El contenido del marco fuera del subárbol del zoom | texto bajo `scaleEffect` queda rasterizado y estirado; el pergamino es el ancla del zoom, así que el punto es el mismo |
| El háptico del flip por reloj, no por observer | `.task(id:)` ya es cancelable; un boundary observer suma un closure `@Sendable` y cero precisión útil |
| El cinemático a 4× bajo `--uitest-chest-manual` | sin eso cada smoke paga 8 s de video; a 4× son 2 s y el flujo es el mismo |
| El mp4 versionado en `Tools/asset-pipeline/video/` | es el master que regenera los assets, mismo criterio que los originales de arte |
