# El cofre animado por video — diseño

> Pedido del dueño (2026-08-28, textual): «acabo de agregar la animacion de cofre
> chest-animation.mp4 al directorio. tiene una pantalla verde. sacale la pantalla
> verde e integrala al juego para mejorar la animacion de apertura de cofres. si
> es necesario, extrae frames del video y genera assets apartir del nuevo cofre
> para meter en los demas lugares del juego. hace un plan para integrar la
> animacion de manera fluida y suave, completamente integrado, en especial en lo
> visual. high end y profesional.»

## 1. Qué hay en el video, medido

`chest-animation.mp4`: 1280×720, 24 fps, 10 s, 240 frames, H.264 yuv420p
(limited range), croma verde **0x0BB427** medido en esquina. Tres actos:

| Frames | Qué pasa |
|---|---|
| f0–f6 | Cofre cerrado, quieto (violeta + dorado, candado plateado) |
| f7–f26 | **Sacudida A**: salto con squash, rayitos de impacto, nubes de polvo que se asientan (0,83 s) |
| f27–f32 | Reposo con polvillo residual |
| f33–f47 | **Sacudida B**: segundo salto, más corto (0,63 s) |
| f48–f52 | La tapa se abre (f50–f52) |
| f53–f82 | **Explosión**: confeti multicolor + abanico de rayos dorados + estrellas; en f82 el cofre queda abierto irradiando |
| f83–f240 | Una carta genérica (dorso azul con corona) sale del cofre, gira y termina de frente con un marco pergamino vacío |

**El tramo de la carta (f83+) no se usa.** La carta del premio ya existe y habla
el idioma de la casa (`PanelCard` v3 con moño, retrato, cinta de rareza,
botones); la carta del video es de otra familia visual (corona genérica, marco
render 3D). Meterla reemplazaría el design system por el de otro juego.

**Dato que simplifica todo**: el cofre no se mueve del piso en los tres actos.
Todos los segmentos comparten un mismo lienzo 1280×720 con el cofre en reposo en
el rect **(431, 257)–(838, 620)** — 407×363 px, un solo sistema de coordenadas y
un solo ancla.

## 2. La decisión de integración: el video pone el COFRE, la casa pone el resto

La animación existente (`ChestOpeningView`, sesión 2026-08-26/27) es
**interactiva de 4 toques** con 9 latidos, y eso es pedido del dueño («lo que
más garpa del sistema»: la maneja el jugador, no un video de 2,6 s). El video es
lineal. La síntesis: **los latidos siguen mandando, y cada latido reproduce su
segmento de video en lugar del PNG estático + transformación**.

| Latido | Hoy | Con el video |
|---|---|---|
| `.arriving` | `ui_chest_closed` cae (`ChestDrop`) | frame idle (f0) cae — `ChestDrop` intacto |
| `.waiting` | respiro `scaleEffect(1.04)` | idle + el mismo respiro |
| `.forced1` | `ChestShake` ±5° + 4 partículas | segmento **shakeA** (salto real con polvo del animador) |
| `.forced2` | `ChestShake` ±9°, arte `cracked`, rayos se tiñen | segmento **shakeB** + rayos teñidos (intacto) |
| `.forced3` | `ChestShake` ±14° + hinchado 1.12 | **shakeA** de nuevo + hinchado 1.12 (intacto) |
| `.bursting` | flash 80 ms, arte `open` compensado, `FlyingLid`, 30 partículas | segmento **burst** (f49–f82, congela en el último frame) + flash + partículas intactos |
| `.flying`/`.flipping`/`.resting` | cofre se achica a 0.4 y baja | igual, mostrando el frame final del burst |

Qué se conserva **sin tocar**: la caída con aplaste, el respiro, el hinchado,
el foco radial, los rayos `fx_burst_rays` **teñibles por rareza** (el anuncio
del segundo toque — el mecanismo central de anticipación — sigue siendo el
sistema de la casa; los rayos dorados horneados del video sólo aparecen en el
estallido, cuando la rareza ya fue anunciada, y el dorado es celebración
neutral que no la delata), el flash de 80 ms (ya no tapa un desalineo, ahora
tapa la apertura de tapa f49–f52 y da el énfasis), las ráfagas
`Burst`/`SparkBurst` teñidas, la carta completa, los hápticos, el auto-avance
de 1,2 s, `--uitest-chest-manual` y todos los identifiers.

Qué se retira: `ChestShake` (la sacudida ahora es real), `FlyingLid` (la tapa
se abre en el video), el switch de 3 PNG con la compensación
`scaleEffect(x:1.04)/offset` de `ui_chest_open` (el desalineo documentado como
«no se regenera arte» muere de raíz: los frames del video son coherentes entre
sí por construcción).

**Reduce Motion**: sin reproducción. Frame idle quieto antes del estallido,
frame final del burst (cofre abierto irradiando) desde el estallido — estado
final, como pide la regla del design system.

## 3. El keying, calibrado

ffmpeg `chromakey=0x0BB427:0.11:0.04,despill=type=green`, verificado sobre los
frames difíciles (glow dorado semitransparente + confeti):

- El color es el verde **medido en el stream con la matriz limited-range**;
  con el hex calculado en full-range (0x189D30) el filtro se come el cofre
  entero. La métrica de `similarity` es mucho más agresiva de lo que sugiere la
  doc: el rango útil quedó en 0,08–0,14.
- El glow que se funde al verde queda con alfa parcial — sobre el telón negro
  al 55 % del overlay se comporta como luz (verificado compuesto sobre oscuro).
- La cuantización a 256 colores (PIL `FASTOCTREE`) no introduce banding visible
  en los degradés del glow (verificado con A/B con y sin dither) y deja los
  frames en 30–100 KB.

## 4. Formato de entrega y reproducción

**Frames PNG cuantizados + player SwiftUI propio.** Se descartó AVPlayer con
HEVC-alpha: la animación es interactiva por segmentos (seeks con latencia),
el repo no tiene ni un solo uso de AVFoundation (el idioma es SwiftUI +
`keyframeAnimator`), y los frames permiten pausa exacta, tinte y testeo.

- `FisuEvolution/Resources/ChestAnim/chest_f{NNN}.png` — ~70 frames:
  - idle: f0 · shakeA: f7–f26 · shakeB: f33–f47 · burst: f49–f82.
  - Crop de los tres primeros: **(200, 100)–(1060, 660)** (860×560, a escala
    nativa; el cofre queda a ~407 px para 210 pt de dibujo ≈ @1,9x — hoy el
    PNG de 256 px a 210 pt es @1,2x, así que la nitidez SUBE).
  - Crop del burst: **(0, 0)–(1280, 656)** a escala **0,8** (1024×524): durante
    la explosión el ojo está en el caos, y el frame final congelado se achica a
    0.4 enseguida; el peso baja de ~4,1 a ~2,6 MB.
- `chest_anim.json` en el mismo directorio: `schemaVersion`, `fps: 24`,
  `canvas`, `chestRect` y por segmento `{first, last, crop, scale}`. **Es el
  contrato pipeline↔runtime** y lo pinean tests de los dos lados.
- Presupuesto: **≤ 4 MB** de PNGs (medido al integrar). El bundle además pierde
  los 6 PNG de `ui_chest_cracked/open/lid`.
- Reproducción: `TimelineView(.animation(minimumInterval: 1/24, paused:))` —
  el índice sale del reloj del timeline (drift-free, los frames caídos se
  saltean solos) y `paused` se prende al llegar al último frame, así el display
  link muere (regla de la casa: nada de `repeatForever`/relojes incondicionales).
- Memoria: los frames decodifican **por ventana deslizante** (prefetch de ~8
  por delante del playhead en background con `preparingForDisplay()`, LRU).
  Todos los frames del burst decodificados a la vez serían ~90 MB; la ventana
  los deja en <20 MB pico. El primer frame de cada segmento se precalienta
  antes de que su latido llegue (idle en el armado del overlay; shakeA tras la
  caída; burst al entrar a `forced2`).

## 5. Assets derivados para el resto del juego

- **`ui_chest_closed` se regenera** desde f0 (recorte al cofre + aire calzado a
  la ocupación del PNG viejo, para que GiftsView a 44 pt y DailyRewardView a
  52 pt no cambien de tamaño percibido): master @2x 256 / @3x 384 — sin
  upscale (el nativo es 407 px). Los dos call sites quedan sin tocar.
- **`ui_chest_cracked`, `ui_chest_open` y `ui_chest_lid` se retiran** de
  `ui.atlas` y del manifest: su único llamador era `ChestOpeningView` y la
  regla de la casa es que lo que queda sin llamadores no se queda de recuerdo
  (los originales quedan en git; los prompts 324–327 del pipeline no se tocan —
  regenerar o no es decisión del dueño).
- El mp4 se versiona como master en `Tools/asset-pipeline/video/` (mismo
  criterio que los originales de arte: lo que regenera assets vive en git).

## 6. Piezas nuevas

| Pieza | Dónde | Responsabilidad |
|---|---|---|
| `chest_video_frames.py` | `Tools/asset-pipeline/scripts/` | Video → frames keyed/cuantizados + `chest_anim.json` + masters de `ui_chest_closed`. Constantes de calibración arriba del archivo. Re-ejecutable. Avisa si un crop corta >0,7 % de la masa de alfa de un segmento. |
| `test_chest_video_frames.py` | `Tools/asset-pipeline/tests/` | Funciones puras (geometría de crops, ocupación del estático) + integridad de lo integrado (manifest ↔ archivos ↔ dimensiones). |
| `ChestAnimation.swift` | `FisuEvolution/UI/Popups/` | Parseo/validación del manifest, resolución de URLs por segmento, y la geometría: escala y offset para dibujar cualquier segmento con el cofre a N pt anclado al centro. |
| `ChestAnimationFeed.swift` | `FisuEvolution/UI/Popups/` | `@Observable`: segmento vigente, índice por fecha, caché LRU + prefetch en background, `paused`. |
| Cirugía en `ChestOpeningView.swift` | — | `chestArt` → player; `choreograph` dispara segmentos; retiros de `ChestShake`/`FlyingLid`. |
| `ChestAnimationTests.swift` | `FisuEvolutionTests/` | El manifest del bundle parsea, cada frame referenciado existe, la geometría del ancla es coherente, `load()` no falla. |

Si `ChestAnimation.load()` fallara en runtime (manifest ausente/corrupto), el
popup cae al `ui_chest_closed` estático para todos los latidos: feo pero
funcional, y un test pina que no pasa.

## 7. Qué NO cambia (contratos)

- La CelebrationQueue y el kind `.chestOpening` (prioridad, timeout nil, no
  salteable, `dismissChestReward()` antes de `celebrationFinished`).
- Los 9 latidos, sus toques, sus tiempos de auto-avance y sus hápticos (el
  único tiempo revisable con capturas es el auto-avance de `.bursting`).
- El anuncio de rareza en el segundo toque, tiñendo los rayos de la casa.
- Los identifiers (`chest.tap`, `chest.card`, `chest.equip`, `chest.dismiss`)
  y el smoke `ChestOpeningUITests`.
- Cero strings nuevos.
