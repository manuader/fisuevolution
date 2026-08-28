# Sesión 2026-08-28 (ter) — El cofre definitivo: 2D, vertical y con sonido

> Pedido del dueño, textual: «ya tengo el video definitivo chest-animation-2d.mp4
> ponelo en el juego con su respectivo sonido. usa la estetica de este cofre que
> es en 2d. queda mucho mas integrado con la estetica del juego. borra todo lo
> relativo a las animaciones anteriores de los cofres».
>
> Tercera ronda del día — cierra el arco de
> `SESION-2026-08-28-cofre-animado.md` (v1, el master 3D con viñeta) y
> `SESION-2026-08-28-cofre-video-v2.md` (v2, el sprite puro y el bug del velo).

## El master definitivo

**720×1280 VERTICAL**, 24 fps, 10 s, verde plano (0x22924A en el stream,
misma banda de similarity), estética 2D cartoon calzada al juego — cofre de
madera con herrajes dorados, contornos gruesos, cel shading — **y con pista
de audio AAC estéreo**. El arco: idle largo (f0–22, quieto al pixel) ·
sacudida A [23,38] que vuelve al reposo · reposo · **temblor agachado [39,49]
que desemboca SIN CORTE en el estallido (f50)** · la carta sube, el cofre se
funde hacia el verde (~f100–118) · la carta gira al centro · flip f192–200 ·
marco vacío quieto desde ~f204.

Dos regalos de este master:

- **El empalme del tercer toque es un movimiento continuo**: la sacudida B
  termina en f49 agachada y el video arranca en f50 — el mejor empalme de las
  tres rondas. El mapeo de latidos quedó: toque 1 y 2 → sacudida A (la
  repetición la pone el jugador), toque 3 → el temblor B → video.
- **El desvanecimiento del cofre keyeado se ve deliberado**: la mezcla al
  verde horneada pasa por `chromakey`+`despill` y queda una sombra tenue que
  se evapora — sobre el telón oscuro lee como humo, no como artefacto. Se
  verificó A/B antes de confiar (f100–f120 compuestos sobre fondo oscuro).

## Vertical = full-bleed de verdad

Con el cofre a **274 pt** (k = 274/448), el lienzo vertical rinde
427×760 pt: cubre la pantalla **de lado a lado (Pro Max incluido) y hasta
arriba**; sólo queda un tramo de adoquines abajo donde los destellos son
ralos y el feather no se nota. Medido en captura: los saltos de luminancia de
un frame con video activo y del reposo son idénticos fila a fila — el borde
del encuadre no existe en pantalla.

**El push-in de la casa murió**: la carta del video ya hace su propio zoom al
centro y termina GRANDE (pergamino 349×504 px → ~214×308 pt). Se fueron
`cinematicZoom`, `zoomFinal` y el ancla del pergamino como UnitPoint; el
contenido se posiciona directo con `parchmentStage` (172,363,349,504 —
medido por beige macizo, verificado con el rect dibujado sobre f239).

## El sonido: dos familias, una fuente

| Qué | Cómo viaja | Quién lo dispara |
|---|---|---|
| El tramo cinemático (t 2,083–10 del master) | **DENTRO de `chest_open.mov`** (AAC 160k, recortado con `atrim` al mismo arranque que el video) | `AVPlayer` solo; `play(rate:volume:)` lee el volumen SFX del juego al reproducir |
| Las dos sacudidas | `sfx_chest_shake_a/b.caf` en `Resources/Audio/` (PCM s16, ventanas exactas de sus frames, fade de 10/20 ms en las puntas) | la coreografía, junto a los frames — el timing lo pone el DEDO, no el video |

- `AudioManager.SFX` ganó `chestShakeA`/`chestShakeB`; la precarga los toma
  sola (`allCases`).
- `AudioWiringTests` se extendió: `declaredCases` incluye los dos nuevos y el
  barrido de call sites suma `UI/Popups` (las sacudidas suenan desde la
  coreografía del popup, no desde una acción de `GameState`). El barrido
  sigue sin falsos positivos: los popups no tenían ni un `?.play(` antes.
- El volumen respeta Ajustes: clips por `AudioManager.play` (que ya corta con
  `sfxVolume == 0`) y el mov por `player.volume = sfxVolume`. Con Reduce
  Motion no hay video ni sacudidas → apertura en silencio, coherente con el
  resto del modo.
- La sesión de audio ya era `.ambient` con `mixWithOthers`: el sonido del
  cofre convive con la música del juego y con la del usuario.

## Qué se borró (pedido explícito)

- El master v2 (3D violeta) — pisado por el definitivo en
  `Tools/asset-pipeline/video/chest-animation.mp4` (el anterior queda en git).
- Los 45 PNG del set v2 (f004–f047 muertos; el set nuevo es f000 + f023–f049,
  28 frames) + mov + still + manifest + `ui_chest_closed` regenerados.
- `cinematicZoom`/`zoomFinal`/`cardAnchor` del runtime (el video hace su
  propio push-in).
- Nada más quedaba de las animaciones previas: los assets de la casa
  (rayos, carta SwiftUI, etc.) habían muerto en la v1.

## Verificación

| qué | dónde | resultado |
|---|---|---|
| Pipeline Python (13: +sfx, +audio del mov) | `unittest` | **13/13** ✅ |
| Unit sin Store (459) | sim 26.5 propio (`cofre-2d-26`, borrado al cierre) | **el único rojo es el DECLARADO** (Pacing, contrato) |
| Cofre+Audio unit (17: manifest, feed, AudioManager, AudioWiring) | mismo sim | **17/17** ✅ |
| `ChestOpeningUITests` + circuito de Regalos | mismo sim | **3/3** ✅ |
| Latidos en vivo (`log stream`, dos corridas) | sim | arco completo: waiting→forced1/2/3 (1,2 s c/u, forced3 0,5 s)→**cinemático 8,19 s terminado por la notificación real**→resting |
| mov | ffprobe + decode | hevc/hvc1 190 frames + **AAC 7,922 s** · premultiplicado (RGB 0,05 en α=0; composición sobre gris clava 120,00) |
| Clips | astats | señal real (picos −9,3 / −15,5 dB) |
| Smoke visual | capturas cronometradas | full-bleed sin costura (saltos de luminancia idénticos con y sin video), fade del cofre como humo, flip, marco+contenido centrados, botones limpios |

⚠️ **Un susto instructivo que NO era bug**: la primera sábana de capturas
mostró el reposo "demasiado pronto" y parecía que el video se salteaba. Era el
overhead de `simctl io screenshot` en máquina cargada (2–4 s por captura)
corriendo la ventana de muestreo — el log de latidos en vivo mostró el arco
completo con el video entero, dos veces. **El instrumento para juzgar timing
es `log stream` con los latidos (`Log.assets`), no la cadencia de
screenshots** — la misma lección del flaky del primer arranque de la v1,
visto desde otro ángulo.

## Decisiones de esta tanda

| Decisión | Por qué |
|---|---|
| chestSide 274 (antes 210) | el lienzo vertical cubre TODO el ancho (Pro Max incluido) y hasta arriba: full-bleed sin costuras; y respeta el encuadre del animador (el cofre al 62 % del ancho) |
| Toques 1 y 2 repiten la sacudida A | este master no tiene segunda sacudida que vuelva al reposo; la B es el temblor que desemboca en el estallido y ésa es del tercer toque — empalme continuo f49→f50 |
| El sonido de los toques como clips, el del cinemático en el mov | los toques tienen timing del dedo (imposible sincronizarlos con una pista lineal); el cinemático es lineal y AVPlayer lo lleva gratis |
| Los clips en PCM `.caf` | medio segundo no amerita codec; el formato de sus hermanos de `Resources/Audio/`; AVAudioPlayer lo lee sin sorpresas |
| El pipeline escribe también en `Resources/Audio/` | los clips son PRODUCTO del video master, igual que los frames — regenerable todo con una corrida |
| Sin ducking de la música durante el cofre | palanca disponible si el dueño lo pide; el mix `.ambient` ya convive y agregarlo es decisión de diseño sonoro, no técnica |
