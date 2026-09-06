# Sesión 2026-09-06 (séptima) — El cofre a 2x, y la traba que no era del decoder

> Pedido del dueño: «hace que la animacion de los cofres vaya a velocidad x2.
> por alguna razon la animacion del cofre se lagea. (se traba por momentos en
> lugar de mostrar el video mp4 correctamente y de manera fluida.) diagnostica
> porque esta sucediendo esto y arreglalo».
>
> Continúa a `SESION-2026-08-28-cofre-a-velocidad.md` (sexta), que llevó el
> tramo a 1,5x/36 fps y bajó el congelón del empalme de ~280 ms a ~100 ms. El
> dueño lo volvió a ver trabado.

## 1. La traba que quedaba NO era del video: era el relevo del PNG

La sexta dejó ~100 ms en el empalme y lo atribuyó al arranque del decoder. La
medición de hoy, con el mismo instrumento (`analyze_recording.py`, corridas de
frames idénticos sobre la grabación normalizada a 60 CFR), mostró **dos**
congelones y el segundo no estaba explicado:

```
10.32s: 100 ms quieto     ← arranque del decoder (conocido)
10.90s: 166 ms quieto     ← ???
```

El video arranca ~10,3 s. El segundo congelón cae a los **0,6 s exactos** del
arranque — y `stageHandoffSeconds` valía **0,6**. No era el decoder: era
`stageRetired = true` desmontando la capa PNG de respaldo.

El mecanismo: con `if !stageRetired { ChestStage(…) }`, jubilar el PNG le
**cambia la forma al `ZStack`** en pleno video. SwiftUI rehace el árbol y
vuelve a correr el layout del escenario —con el `UIViewRepresentable` del
`AVPlayerLayer` adentro— mientras el decoder entrega cuadros, y el resultado
son 166 ms de pantalla clavada en el momento más visible de la animación.

**Arreglo**: apagar el escenario con `opacity`, no desmontarlo. El árbol no
cambia de forma y el PNG queda como una `Image` quieta e invisible; su
`TimelineView` ya está `paused` desde f49, así que no hay display link vivo
detrás. Medido después: **el congelón de los 0,6 s desapareció**.

## 2. El 2x: 48 fps, y por qué el descarte heredado no aplicaba

La sexta había dejado escrito que **48 fps no se sostiene** («el simulador no
sostiene HEVC-alfa a 48 y el giro colapsaba a ~5 fps efectivos»). Ese descarte
era real pero **de un asset que ya no existe**: se midió sobre HEVC **con canal
alfa**, que el simulador decodifica por software. Desde la sesión del velo el
mov es premultiplicado, y el asset embarcado es `yuv420p` PLANO — verificado
con ffprobe: dos streams, `hevc yuv420p` + `aac`, sin pista de alfa.

Heredar ese "48 no se banca" habría sido heredar el síntoma de otro archivo.

Medido con 48 fps de verdad, en grabación: **47-48 cuadros distintos por
segundo sostenidos durante todo el tramo**, contra los 32-36 del 1,5x.

`CINEMATIC_SPEED = 2.0` / `PLAYBACK_FPS = 48`: los MISMOS 190 cuadros del
master, ninguno sintetizado ni tirado, presentados al doble de ritmo.

## 3. La capa del player estaba pidiendo blending para nada

Mismo origen que el punto 2: `ChestCinematicView` iba `isOpaque = false` +
fondo `.clear` porque el mov **tenía** alfa. Con el asset premultiplicado y
`videoGravity = .resize` (el video cubre los bounds enteros), esa
transparencia obligaba al compositor a mezclar una capa de ~1320×2350 px
contra lo de atrás en **cada cuadro**, para un contenido sin un solo píxel
translúcido. Ahora es opaca. El recorte y el feather del borde los trae
horneados el propio video: apagar la transparencia no los toca.

## 4. Los relojes de la vista pasaron a derivar de un solo número

Estaban escritos `144.0 / 36.0`, `156.0 / 36.0`, `190.0 / 36.0`: tres lugares
donde el 36 podía quedar viejo por separado. Ahora hay
`ChestOpeningView.playbackFPS` y los tres derivan de ahí.

⚠️ **Sigue habiendo un gemelo que el compilador no relaciona**:
`playbackFPS` (Swift) y `PLAYBACK_FPS` (pipeline, que escribe el `fps` del
manifest). Si se separan **no falla nada** — los relojes del flip y del reveal
quedan corridos respecto del video. Lo pinean los dos tests, cada uno con el
literal al lado de su constante, para que cambiarlo duela en los dos lados.

`stageHandoffSeconds` pasó a medirse en FRAMES (`21.0 / playbackFPS`): lo que
importa es cuántos cuadros rindió el decoder, no un tiempo fijo. Con el 0,6 s
heredado, a 48 fps el relevo caía al doble de profundidad dentro del tramo.

## 5. La trampa del día: ffmpeg 9 borró `-vsync`

El pipeline murió en el primer intento con `Unrecognized option 'vsync'`.
**ffmpeg 9 no deprecó `-vsync`: lo sacó.** El reemplazo exacto es
`-fps_mode passthrough` (un frame de salida por frame de entrada). Medido con
ffmpeg 9.0.1.

Sigue vigente lo de la sexta: **VideoToolbox pisa los PTS retimeados**, así que
el encode va con `-r 48 -fps_mode cfr -frames:v 190`.

## Verificación del bloque

| qué | resultado |
|---|---|
| mov | **190 frames, 48/1, 3,958 s vídeo / 3,955 s audio**, 1585 KB |
| Pipeline (`test_chest_video_frames`) | **13/13** ✅ |
| Unit (467, sin las dos suites de Store) | único rojo el declarado de `PacingTests` |
| `ChestOpeningUITests` | **2/2** ✅ |
| Grabación ANTES (36 fps) | 32-36 distintos/s · congelones **100 ms + 166 ms** en el arranque |
| Grabación DESPUÉS (48 fps) | **47-48 distintos/s** · primera corrida **sin un solo congelón** dentro del tramo · segunda, 100-116 ms sólo en el arranque (el umbral del instrumento) |

## Decisiones de esta tanda

| Decisión | Por qué |
|---|---|
| 2x por RETIME (48 fps), no por `rate` del player | mismo criterio que la sexta: el asset es la verdad única, el `atempo` offline suena mejor que el time-stretch del player, y `rate` queda libre para el 4× de los uitests |
| Re-medir el descarte de 48 en vez de heredarlo | el descarte era de HEVC-alfa; el asset de hoy es `yuv420p` plano. Un "ya se midió" sobre otro archivo no es una medición |
| El escenario PNG se apaga, no se desmonta | cambiar la FORMA del árbol durante el video cuesta un re-layout con el player adentro — 166 ms medidos |
| La capa del video pasa a opaca | el alfa ya no existe en el asset; el blending por cuadro era herencia |
