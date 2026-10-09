# E8 — Todo el juego animado: integración de los videos de Higgsfield (diseño)

> Pedido del dueño, 2026-10-08: "animaciones para todo el juego, que todos los assets sean dinámicos,
> con efectos de sonido específicos, que el juego ande fluido y que la identidad visual y sonora
> estén perfectamente integradas". Las decisiones de esta página son del dueño o se desprenden de
> sus reglas, y no se re-litigan.

## Reglas del dueño

- **Fondo claro**: todo asset que se recorta va sobre blanco y se recorta con el criterio topológico
  de `whitebg_cutout.py`, cuadro por cuadro. El verde croma queda sólo para la máscara de la cabina
  del ascensor.
- **Revisión del dueño antes de integrar**: los masters se revisan en la interfaz local de revisión,
  que guarda las decisiones en
  `automatic-image-generation/projects/fisu-evolution-v2/video/revision.json` (`va` · `regenerar` ·
  `obviar`, más una nota). **Sólo entra al juego lo marcado `va`.** Lo que esté en `regenerar` se
  rehace con el método de abajo y vuelve a revisión.
- **Fluidez primero**: ninguna animación puede bajar el juego de 60 fps en el iPhone SE ni en el
  iPad, ni demorar un toque.

## Inventario (masters generados al 2026-10-08)

| Categoría | Cantidad | Dónde se ve | Fondo | Modelo |
|---|---|---|---|---|
| Retratos de visitantes y especiales (loop) | 18 | popup del visitante (E4b) | blanco | Kling v3.0 |
| Personajes de la torre y especiales, cuerpo entero (loop) | 53 | ficha (`CharacterSheetView`), revelación de tier nuevo, Álbum | blanco | Kling v3.0 |
| Visitantes en acción (loop) | 8 | el momento del visitante (pedido / multa / chisme) | blanco | Kling v3.0 |
| Visitantes y especiales hablando (loop) | 18 | mientras el globo de texto está abierto | blanco | Kling v3.0 |
| Eventos (ilustración + loop) | 8 | popup y banner del evento (E4) | blanco | GPT Image 2.5 + Kling pro |
| Paquete de la Aduana y El Colchón (espera + apertura) | 4 | E5 | blanco | Kling pro |
| Íconos de la tienda de ORO (loop) | 10 | tarjetas de la tienda (E6a) | blanco | Kling v3.0 |
| Fondos de los 10 pisos (ambiente, loop) | 10 | tablero, el piso visible | opaco | Kling pro |
| Cabina del ascensor (puertas) | 2 | viaje en ascensor (E13 ítem 13) | opaco, máscara verde | Kling pro |
| Cinemáticas con sonido | 4 | intro (primera vez), reencarnación, arresto, llegada a Dios | opaco | Seedance 2.5 |

## Método de generación (desde ahora)

Lo que falló en la primera tanda (manos de más, deformaciones) vino de pedir gestos. El método:

1. **Una sola imagen aprobada como primer y último cuadro** (loop por construcción).
2. **Prompt en cuatro partes**: qué cambia (mínimo: respiración, parpadeo, pelo, un objeto
   secundario), **qué queda congelado** con nombre propio (brazos, manos, dedos, piernas, objetos),
   reglas de estilo (2D plano, mismo grosor de línea, sin 3D, sin sombreado realista, fondo blanco
   liso) y cámara (fija, sin zoom, sin cortes, vuelve gradualmente al cuadro inicial).
3. **"Exactamente dos brazos y dos manos, sin extremidades ni objetos nuevos"** en todo cuerpo
   entero.
4. Acciones grandes (aperturas, cinemáticas): Kling pro o Seedance 2.5 con cuadro final propio; los
   loops sutiles: Kling v3.0.
5. **Control de calidad cuadro por cuadro** (hoja de contacto cada 15 cuadros, no un solo cuadro del
   medio) antes de pasar a revisión del dueño.

## Arquitectura de reproducción

- **Un componente para SwiftUI** (`AnimatedArtView(id:)`) y **uno para SpriteKit**
  (`LoopingVideoNode`), los dos sobre `AVPlayerLooper` + `AVQueuePlayer`, leyendo
  `loops_manifest.json`. Sin entrada en el manifiesto o sin el archivo, muestran el PNG quieto de
  siempre (regla de oro del pipeline).
- **Póster instantáneo**: primero se dibuja el primer cuadro (PNG del atlas) y el video aparece con un
  fundido de 0,15 s cuando está listo, así nunca hay un hueco ni un parpadeo.
- **Pool de reproductores** (`VideoPlayerPool`): como máximo **3 decodificadores vivos** a la vez
  (el fondo del piso visible + un popup + un ícono). Lo que sale de pantalla se pausa y devuelve su
  reproductor. Los íconos de la tienda animan sólo el que está centrado; los demás, póster.
- **El tablero no usa video para los personajes**: con decenas de personajes en pantalla, siguen con
  la animación por código de siempre. Los videos de cuerpo entero se ven en la ficha, la revelación y
  el Álbum, de a uno.
- **Fondo del piso**: sólo el piso visible anima. Durante el scroll y el viaje en ascensor se ve el
  póster y el video retoma al asentarse.
- **Ahorro**: Reduce Motion y Modo de bajo consumo → todo póster quieto. App en segundo plano →
  pausa todo. Térmica `serious` o peor → sólo póster.
- **Formato**: HEVC con alfa (`.mov`) para los recortados; HEVC opaco para fondos, cabina y
  cinemáticas. Retratos, personajes, visitantes, eventos, objetos e íconos a 384² o 512² (se mide qué
  alcanza en el iPad Pro); fondos a 1024²; cinemáticas a 720×1280.

## Peso de la app

El total sin comprimir de los masters supera lo razonable para el paquete base. Por eso:

- **En el paquete base**: retratos, objetos, cabina, fondos, cinemáticas y lo del primer piso.
- **On-Demand Resources** (etiquetas por familia): personajes de cuerpo entero por piso, visitantes en
  acción y hablando, eventos e íconos. Se precargan al acercarse al piso (o al abrir la tienda) y,
  mientras no bajan, se ve el póster.
- El controlador mide el peso real después del pipeline y ajusta la resolución hasta que el
  paquete base quede ≤ 60 MB por encima del de hoy (la regla de E6b).

## Sonido: un efecto por momento

Todo efecto nuevo se sintetiza con `Tools/audio-synth/generate_audio.py` (o se graba), en el mismo
carácter que los de hoy, y entra a `AudioManager.SFX`. Las cinemáticas traen su propio audio.

| Momento | Efectos |
|---|---|
| Ascensor | `sfx_elevator_spring` (la placa baja/sube), `sfx_elevator_button`, `sfx_elevator_doors_close`, `sfx_elevator_hum` (loop durante el viaje), `sfx_elevator_cable`, `sfx_elevator_ding` (ya existe) |
| Paquete | `sfx_package_rattle` (espera), `sfx_package_tape_rip`, `sfx_package_burst` |
| Colchón | `sfx_mattress_squeak` (espera), `sfx_mattress_rip`, `sfx_cash_burst` |
| Visitante | `sfx_visitor_arrive` (whoosh corto), `sfx_talk_blip` (por sílaba mientras se escribe el globo, con tono por personaje) |
| Eventos | un acento corto por evento: `sfx_ev_plan_platita` (lluvia de monedas), `sfx_ev_startup` (caja registradora), `sfx_ev_devaluacion` (trombón que baja), `sfx_ev_blanqueo` (lavarropas), `sfx_ev_mercado_pago` (error de conexión), `sfx_ev_alien` (zumbido de ovni), `sfx_ev_corralito` (candado), `sfx_ev_aguinaldo` (cotillón) |
| Tienda de ORO | `sfx_shop_shimmer` (al pasar el brillo del ícono centrado, muy bajo) |
| Ficha y revelación | `sfx_reveal_whoosh` + el `sfx_evolution` de hoy |

- Mezcla: los efectos de ambiente (zumbido, espera) a −18 dB por debajo de la música del piso; los de
  acción a −6 dB. El crossfade de música del piso (E8 audio) no se toca.
- Todo respeta el interruptor de sonido y de música de Ajustes, y Silencio de iOS.

## Tests

- `loops_manifest.json` pineado por tests en Swift y Python (como hoy), con las secciones nuevas.
- `VideoPlayerPoolTests`: nunca más de 3 vivos; devolución al salir de pantalla; póster con Reduce
  Motion, Modo de bajo consumo y térmica alta.
- UI tests con `--uitest*`: las vistas muestran el póster (sin video) y siguen pasando.
- Medición de fps en el SE y en el iPad con un piso animado + popup abierto (gate del `completo`).
- `AudioWiringTests` suma los efectos nuevos.

## Orden

1. Pipeline de assets (rama `v2/e8-videos`): recorte blanco, kinds nuevos, manifiesto. En curso.
2. Revisión del dueño en la interfaz (`revision.json`).
3. Plan por tareas del lado Swift (planificador opus): pool, componentes, cada lugar de la tabla de
   inventario, ODR, efectos de sonido.
4. Integración por lugar, en paralelo según los archivos calientes de `tasks.md`.
