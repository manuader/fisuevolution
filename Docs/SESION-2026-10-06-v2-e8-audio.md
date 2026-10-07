# Sesión 2026-10-06 — E8 audio: un tema chiptune por piso

## El pedido

La parte de sonido de E8 (PLAN-v2 §2 fila "Música", §5 "Música por piso" y la
línea "Sonido" de E8):

- **diez temas chiptune en loop, uno por piso**, cada uno con la cara de su
  piso, sintetizados con el generador de la v1 (sin samples ni licencias);
- **un solo tema sonando, con crossfade de ~1,5 s al cambiar de piso** (scroll o
  ascensor), respetando el volumen de música de Ajustes;
- los SFX `sfx_wheel_tick`, `sfx_blackout` y `sfx_elevator_ding`;
- medir cuánto suma al bundle.

## Lo que se hizo

### 1. El sintetizador: diez temas y tres SFX

`Tools/audio-synth/generate_audio.py` sigue siendo stdlib pura y
determinística: dos corridas dan los mismos bytes, también en el AAC (se
re-codificó Marte a mano y `cmp` dio igual). Los 11 archivos de la v1
(10 SFX + `music_earth_loop`) salen **byte a byte iguales**, y también las
sacudidas del cofre, que no son de este script.

Lo que suma el script:

- **Un secuenciador en texto.** Las líneas se escriben como `D4 - F4 . A4`
  (`-` liga, `.` silencio, `|` separa compases) y cada línea tiene que cubrir
  el loop exacto: `play_line` lo verifica, así que una nota de más no genera
  el tema. Además: `Grid` (tempo, compases, swing), `harmony` (acordes por
  tiempos, tiene que cubrir el loop) y `hits` (patrones de percusión).
- **Instrumentos**: lead con vibrato y dos osciladores opcionales, bajo,
  pluck, campana con parciales inarmónicos, steel drum, vibráfono, piano
  eléctrico, órgano, colchón, acordes cortados, eco, y una percusión entera
  (bombo, redoblante, palmas, hats, shaker, aro, clave, congas y toms).
- **El pulso de 25 %** (el timbre NES) como tabla nueva, y
  **ruido con pasabajos** para viento, escobillas y polvo. Las tablas viejas
  no cambian: por eso los archivos de la v1 salen iguales.
- **Filtro por nombre**: `generate_audio.py music_moon_loop` genera sólo ése.

Los temas (todos con wrap-around: la cola de lo que pasa el final suena al
principio, así que la costura es continua por construcción):

| Piso | Tema | Duración | KB | RMS |
|---|---|---|---|---|
| `alley` | Blues en Re menor, shuffle a 84. Bajo que camina, armónica de pulso 25 % con la nota triste (Lab), batería de lata, crujido de vinilo | 22,9 s | 218 | −21,1 |
| `urban` | Funk en Mi menor a 112. Bajo de octavas en semicorcheas, acordes cortados, palmas, lead pegadizo y dos bocinazos al cerrar | 25,7 s | 251 | −21,5 |
| `corporate` | Bossa de ascensor en Do a 90. Piano eléctrico, vibráfono, aro en la clave y un teclado que tipea | 21,3 s | 211 | −21,0 |
| `luxury` | Lounge en Reb a 76 con swing. Arpa, cuerdas, contrabajo, trompeta con sordina, escobillas y burbujas de champán | 25,3 s | 245 | −20,4 |
| `island` | Calipso en Fa a 108. Steel drum, acordes a contratiempo, clave 3-2, congas y shaker | 26,7 s | 269 | −22,5 |
| `moon` | Fa lidio a 64, ralo. Colchones que respiran, "bloops" con eco, latido grave y el pitido del Apolo (2525/2475 Hz) | 30,0 s | 282 | −22,5 |
| `mars` | Re frigio a 96. Ostinato de pulso, toms, metales, melodía con Mib, viento de polvo y un láser | 20,0 s | 196 | −21,3 |
| `solar` | Do lidio a 116. Dos arpegiadores con ciclos de 16 y de 3 que se desfasan como órbitas, colchón y notas largas | 24,8 s | 243 | −20,6 |
| `galaxy` | El loop cósmico de la v1 (La menor a 72, pads y estrellas con eco), que se generaba y nunca sonó | 26,7 s | 246 | −21,4 |
| `god_realm` | Re mayor a 66. Órgano de senos, coro, glissando de arpa, campanas, timbal y una voz de notas largas | 29,1 s | 280 | −21,2 |

Los SFX nuevos (PCM como sus hermanos, pico −3 dBFS):

- `sfx_wheel_tick` (35 ms): la lengüeta contra el clavo, seco.
- `sfx_blackout` (1,2 s): golpe de la térmica, zumbido de 120 Hz que cae a
  35 Hz, el pito de la electrónica bajando y tres chispazos.
- `sfx_elevator_ding` (1,4 s): una campana en Do6 con parciales de campana y
  la octava de abajo.

**No tienen caso en `AudioManager.SFX` todavía**, a propósito:
`AudioWiringTests` exige un call site para cada caso del enum, y la ruleta
(E5), el apagón (E4) y la botonera del ascensor todavía no existen. Cada frente
agrega su caso y su call site juntos.

### 2. La reproducción: crossfade por piso

- **`FloorMusicDirector`** (nuevo, puro): decide qué suena y cómo se pasa al
  siguiente. Devuelve pasos (`fadeIn`, `restore`, `fadeOut`, `cut`) que
  `AudioManager` ejecuta. Nunca hay más de dos voces: la que manda y la que se
  va. Un tercer cambio en medio de un fundido **corta** a la que se iba (que
  ya es la más baja) en vez de apilar un fundido más. Volver al piso que se
  estaba yendo da vuelta el fundido sin recargar el tema. Cada salida lleva un
  turno, para que el aviso de fin de un fundido viejo no corte un tema que
  volvió a mandar.
- **`AudioManager`**:
  - `showFloor(_:)` le pasa el piso al director y ejecuta los pasos con
    `AVAudioPlayer.setVolume(_:fadeDuration:)` (1,5 s).
  - El corte del tercero es un fundido de 0,15 s y no un `stop()` seco, que
    hace clic.
  - Cada tema se carga **decodificado a PCM en memoria** (`decodedWAV`): ver
    decisiones.
  - El volumen de Ajustes aplica al tema que manda; el que se va baja solo.
  - Mientras un tema se decodifica el jugador puede seguir de largo. Por eso
    el tema sólo entra si al terminar la carga sigue mandando.
- **`startMusic()`** (lo llama `FisuEvolutionApp` al arrancar, sin cambios):
  con música por piso no pone nada, porque el primer tema lo pide el tablero
  y entra con el mismo fundido de 1,5 s. Bajo `--uitest*` y en el host de los
  unit tests hace lo de siempre: `music_earth_loop` desde el arranque.

### 3. El enganche (cero líneas en `GameState` y `BoardScene`)

`GameState` ya publica el piso visible (`visibleFloorOrdinal`, observable) y
`visibleFloorDef` lo resuelve a la definición. El único toque fuera de
`Audio/` está en `GameBoardView`, en `FisuEvolution/App/RootView.swift`:

- `@Environment(AudioManager.self) private var audio` (línea 106);
- `.onChange(of: gameState.visibleFloorDef?.id, initial: true) { _, floorID in audio.showFloor(floorID) }`
  (líneas 263–269).

Así entra todo lo que mueve el piso sin que nadie sepa que hay música: el
scroll (`moveVisibleFloor`), el ascensor (`jumpToFloor`, que cambia el piso
antes del vuelo, así que el fundido acompaña la cámara), la subida al
desbloquear (`setVisibleFloor` al final de la animación), el piso con el que
carga la partida (`initial: true`) y el fixture de debug que escribe
`visibleFloorOrdinal` directo.

## Decisiones y su porqué

- **AAC a 80 kbps en CAF, decodificado entero antes de loopear.** La v1 había
  descartado el AAC para la música porque el padding del encoder rompía el
  loop. Diez loops en PCM serían ~22 MB; en AAC son 2,4 MB.
  - Lo que lo vuelve seguro: el CAF guarda la tabla de paquetes (priming 2112,
    remainder variable), `AVAudioFile` la respeta, y el tema decodificado
    tiene el largo exacto.
  - El player loopea PCM, como en la v1.
  - Bitrate medido sobre el loop de la Tierra: 64 kbps da 33,7 dB de SNR, 80 da
    35,7 y 96 da 37,3. Se eligió 80, unos 35 KB más por tema que 64.
- **Loudness igualado, con el techo de la v1.** Con pico a −9 dBFS (el margen
  que dejan los SFX) los temas quedaban entre −20,4 y −24,5 de RMS, y el
  crossfade iba a sonar como subir y bajar el volumen. Se apuntó a −20 de RMS
  con techo de −9 y se rebalancearon las mezclas:
  - el bombo cae a 60 Hz y no a 45: abajo de eso el parlante del teléfono no
    reproduce nada y el pico se come el margen;
  - menos bombo y menos bajo en la ciudad, y el lead a un oscilador;
  - un colchón bajo en la isla.
  - Rango final: **−20,4 a −22,5**. La Luna y la isla quedan abajo por ralas y
    percusivas. Subirlas más pedía comprimir, y no se comprimió.
  - El earth de la v1 tiene −16,7, pero su cresta es atípica (7,7 dB contra
    11–13 de cualquier tema con percusión) y en producción ya no suena.
- **El tema sigue al piso VISIBLE**, que incluye asomarse al primer piso
  bloqueado. Es lo que el jugador ve, y oír el tema del piso siguiente es un
  anticipo.
- **En producción no suena el earth en el splash.** Sonaría un segundo y
  enseguida cruzaría al callejón. El primer tema entra con el tablero.
- **La música por piso está apagada bajo `--uitest*` y bajo XCTest**
  (`AudioManager.launchAllowsFloorMusic`): hoy en los tests suena el earth, y
  eso se conserva; ningún tema nuevo se carga.

## Cómo se verificó

- **El generador** verifica cada tema al codificarlo: lo decodifica de vuelta
  con `afconvert` y exige el **largo exacto** y una **costura** no mayor que el
  p99 de los saltos entre muestras vecinas del tema. Costura medida (fracción
  del p99):
  - callejón 0,10 · ciudad 0,03 · corporativo 0,02 · lujo 0,18 · isla 0,03
  - Luna 0,01 · Marte 0,00 · solar 0,01 · galaxia 0,00 · reino divino 0,18
- **Unit tests nuevos**:
  - `FloorMusicDirectorTests`, 9 tests: piso → tema; el mismo piso no
    re-dispara; crossfade; un cambio rápido corta en vez de apilar; barrer la
    torre ida y vuelta nunca pasa de dos voces; volver restaura sin recargar;
    los avisos viejos no cortan; los turnos.
  - `FloorMusicAssetsTests`, 2 tests contra los archivos del bundle: cada piso
    de `economy.json` tiene su tema, y cada tema decodificado con
    `AudioManager.decodedWAV` mide exacto lo que dice su tabla de paquetes
    (con priming > 0, o sea que se recortó algo). La cabecera del WAV da la
    duración correcta en `AVAudioPlayer` y la costura no salta.
  - `AudioManagerTests.floorMusicStaysOffUnderTests`: bajo tests la música por
    piso no carga nada.
- La lógica del director se corrió además suelta con `swiftc` (11 casos), y
  `AudioManager` + director typecheckean con Swift 6, strict concurrency
  complete y warnings como errores.
- **Oráculo `rapido`** (`build/oraculo/20261006-220738-rapido/`, con el
  script que hace `cd` al repo, y `build-for-testing.log` compilando las
  fuentes de `v2-e8-audio`): **VERDE**.
  - EconomyKit: 267 tests, pasan.
  - Unit: 485 verdes, 1 rojo (`theOwnersTargetsAreMet`, el declarado) y 0
    salteados.
  - Los 12 tests nuevos pasan. El de los diez temas decodificados tarda 5 s.
- **Peso en el bundle**: diez temas 2.501.348 bytes (2,39 MiB) + tres SFX
  244.692 bytes (239 KiB) = **2.746.040 bytes (2,62 MiB)**. Para comparar, el
  earth en PCM pesa 1,69 MiB solo.

## Cómo escuchar cada tema

Desde la raíz del repo:

```bash
# Escuchar un tema tal como viaja en la app (AAC):
afplay FisuEvolution/Resources/Audio/music_alley_loop.caf
# (alley, urban, corporate, luxury, island, moon, mars, solar, galaxy, god_realm)

# Regenerar sólo uno (~40 s) después de tocar su función:
python3 Tools/audio-synth/generate_audio.py music_moon_loop

# Escuchar la COSTURA: tres vueltas pegadas del tema decodificado
# (afplay en loop deja un hueco entre corrida y corrida, así que no sirve).
# Requiere haber corrido el generador, que deja build/<tema>.decoded.wav:
python3 -c "import wave,sys;n=sys.argv[1];r=wave.open(f'Tools/audio-synth/build/{n}.decoded.wav');p=r.getparams();d=r.readframes(r.getnframes());w=wave.open('/tmp/loop.wav','wb');w.setparams(p);w.writeframes(d*3);w.close()" music_moon_loop && afplay /tmp/loop.wav

# Los SFX nuevos:
afplay FisuEvolution/Resources/Audio/sfx_elevator_ding.caf
```

Generar todo tarda ~7 minutos (Python puro, 45 MB de WAV intermedios en
`Tools/audio-synth/build/`, que está en `.gitignore`).

## Trampas nuevas

- **El throttle de 80 ms de `AudioManager.play` va a comerse los tics de la
  ruleta**: un mismo SFX no re-dispara antes de 0,08 s, y una ruleta rápida
  hace más de 12 tics por segundo. E5 tiene que exceptuar `sfx_wheel_tick` o
  aceptar que se saltee tics.
- **Un AAC no se loopea desde el archivo**: hay que decodificarlo entero, como
  hace `decodedWAV`. Un tema nuevo en m4a, o tocado con `AVAudioPlayer(contentsOf:)`,
  vuelve a tener el problema de la v1. `FloorMusicAssetsTests` lo pinea.
- **Normalizar por pico baja los temas con percusión.** El factor de cresta de
  un tema con bombo es de 11–15 dB, contra 7,7 del earth. Antes de subir un
  instrumento, mirá el RMS en la tabla del generador.
- **`#expect` no acepta un método `mutating` adentro.** Con
  `#expect(director.exitFinished(x))`, la expansión lo llama sobre un `$0`
  inmutable y el target de tests no compila. El resultado va primero a una
  constante. Un `==` con la llamada a la izquierda sí compila, porque el
  operando se evalúa afuera, pero conviene no depender de eso.
- **El sandbox de los subagentes no dejó usar git ni escribir con Write en el
  worktree asignado**: los archivos se copiaron con `cp` desde el scratchpad y
  los commits los hace el orquestador.

## Qué queda

- **Escucharlos.** Los temas se compusieron y se midieron, pero nadie los
  escuchó: es el gate del dueño. Si alguno no tiene la cara de su piso, se
  toca su función y se regenera sólo ése.
- **Cablear los tres SFX** con sus features: el caso en `AudioManager.SFX`, el
  call site y la entrada en `AudioWiringTests.declaredCases`, en el mismo
  commit.
  - `wheelTick` va con la ruleta (E5) y su throttle.
  - `blackout` va con el evento del apagón (E4).
  - `elevatorDing` va con la botonera del ascensor (E8 "por código").
- `music_earth_loop` (1,69 MiB) queda para los tests y como música de la v1.
  Si se decide que los tests también usen un tema de piso, se puede borrar.

## Para el HANDOFF general

**§4 (sesión), arriba de todo:**

> ### Sesión del 2026-10-06 — E8 audio: un tema por piso
>
> Diez temas chiptune sintetizados (uno por piso de `economy.json`,
> `music_<id>_loop.caf`, AAC 80 kbps, 2,39 MiB) y los SFX `sfx_wheel_tick`,
> `sfx_blackout` y `sfx_elevator_ding` (sin cablear: van con sus features).
> `AudioManager.showFloor` hace el crossfade de 1,5 s con un
> `FloorMusicDirector` puro: máximo dos voces, el mismo piso no re-dispara y
> volver restaura sin recargar. Se engancha en `GameBoardView` observando
> `gameState.visibleFloorDef?.id`: cero líneas en `GameState`/`BoardScene`.
> Bajo `--uitest*` y XCTest suena el earth de siempre y no carga ningún tema.
> Detalle, números y cómo escucharlos: `Docs/SESION-2026-10-06-v2-e8-audio.md`.

**§5 (decisiones):**

> - **La música de piso viaja en AAC y se decodifica entera antes de loopear**
>   (2026-10-06, E8). PCM serían ~22 MB. El CAF trae la tabla de paquetes y
>   `AVAudioFile` recorta el priming. `FloorMusicAssetsTests` pinea largo y
>   costura de los diez.
> - **Los temas de piso se igualan por RMS (−20 dBFS) con el techo de −9 de la
>   v1**: el crossfade no puede sonar como un cambio de volumen.

**§7 (trampas):**

> - **El throttle de 80 ms de `AudioManager.play` se come los tics rápidos de
>   la ruleta** (E5): exceptuar `sfx_wheel_tick`.
> - **Un AAC loopeado desde el archivo tropieza en la costura**: usar
>   `AudioManager.decodedWAV`, nunca `AVAudioPlayer(contentsOf:)` con loops.
> - **Normalizar por pico hunde los temas con bombo** (cresta 11–15 dB contra
>   7,7 del earth): el bombo cae a 60 Hz, no a 45, que el teléfono no lo
>   reproduce y se come el margen.

**§9 (mapa de documentos):**

> | **`SESION-2026-10-06-v2-e8-audio.md`** | **La música por piso: los diez temas con su carácter, el crossfade y su director puro, el enganche sin tocar `GameState`, el peso medido y los comandos para escuchar cada tema** |
