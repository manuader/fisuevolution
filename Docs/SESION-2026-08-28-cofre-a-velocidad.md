# Sesión 2026-08-28 (sexta) — El cofre a velocidad: 1,5x, 36 fps y el empalme sin congelón

> (Nació como "quinta", pero la sesión paralela del muro de la cuesta
> pre-compuerta aterrizó primero y se llevó el número.)

> Pedido del dueño: «por alguna razon la animacion del cofre se sigue viendo
> lagueada. ademas es muy lenta. hace que se reproduzca en x1,5 de velocidad
> y mas fluido. no se puede trabar. debe reproducirse como correctamente como
> en el video. sin lag».
>
> Continúa a `SESION-2026-08-28-pulido-post-cofre.md` (cuarta). La cuarta
> había diagnosticado "máquina cargada" y dejado la perilla de interpolación
> apagada; el dueño lo volvió a ver trabado, así que esta vez no se discutió
> el instrumento: se buscó lo que el promedio escondía y se hizo la animación
> objetivamente más rápida y más fluida.

## 1. La traba ERA real: ~280 ms de congelón en el empalme

La medición de la cuarta contaba frames distintos POR SEGUNDO — un promedio
que sostiene "24 clavados" aunque haya un congelón de un cuarto de segundo
adentro del bucket. El instrumento nuevo mide **corridas de frames
idénticos** sobre la grabación normalizada a 60 CFR, y ahí apareció lo que el
dueño veía: **150 + 133 ms de pantalla congelada justo al arrancar el video**
— en el empalme f49→f50, o sea en pleno estallido, el momento más visible de
toda la animación.

La causa estaba escrita en el propio código: el "preroll" del player era
sólo crear el item en la llegada (el `preroll(atRate:)` real estaba evitado
porque crashea en `.unknown`), `automaticallyWaitsToMinimizeStalling` seguía
en su default `true`, y el `AVPlayerLayer` se montaba recién en el latido que
lo reproduce — el armado del layer se pagaba en el frame del estallido.

El arreglo, en `ChestCinematicPlayer` + `stageCanvas`:

- **preroll de verdad**: un task en el init espera `readyToPlay` (poll de
  50 ms en el MainActor — KVO mete closures `@Sendable` que no conviven con
  AVPlayer bajo strict concurrency) y recién ahí llama `preroll(atRate:)`;
- `automaticallyWaitsToMinimizeStalling = false` (archivo local: arranca en
  el acto o no arranca, no "cuando junte confianza");
- `playImmediately(atRate:)` en vez de `play()` + `rate`;
- **la capa del video vive montada desde la llegada, con opacity 0** hasta el
  latido cinemático: el armado del layer se paga en el hueco muerto de los
  toques, no en el estallido.

Medido después: el congelón del empalme quedó en ~100 ms (el umbral de
detección del instrumento), con la máquina cargada.

## 2. El 1,5x: los mismos 190 frames, presentados a 36 fps

«Más rápido y más fluido» tiene una solución que no cuesta nada de calidad:
**retimear**. El master trae 24 fps reales; presentar esos MISMOS frames a
36 fps es exactamente 1,5x de velocidad, con más cuadros distintos por
segundo (36 contra 24 = más fluido), sin sintetizar ni tirar un solo frame —
«como en el video», literalmente, pero más rápido. La alternativa
(interpolar) ya se había medido en la cuarta: limpia a ojo pero el sim
colapsa a ~5 fps efectivos con HEVC-alfa a 48. **36 sí lo sostiene: 28–36
cuadros distintos/s durante todo el tramo, grabado con la máquina cargada.**

Cómo viaja:

- `CINEMATIC_SPEED = 1.5` / `PLAYBACK_FPS = 36` en el pipeline; el mov se
  retimea con `setpts=PTS/1.5` **al final de la cadena** (con la máscara ya
  mezclada — antes del blend desalinearía los streams) y el audio con
  `atempo=1.5` (comprime SIN subir el tono);
- ⚠️ **VideoToolbox pisa los PTS retimeados con `-vsync 0`** (medido: el mov
  salía con la cadencia 1/24 del master, o sea sin el 1,5x, aunque el filtro
  emitía 1/36 perfecto). El encode va con `-r 36 -fps_mode cfr` +
  `-frames:v 190` (el cfr solo rellenaría un frame de cola);
- el **manifest lleva fps 36**: las sacudidas PNG corren al mismo ritmo por
  su propio playhead y el empalme no cambia de velocidad a mitad del gesto;
  el `TimelineView` del escenario ahora lee el intervalo del manifest (el
  1/24 hardcodeado se saltearía un frame de cada tres);
- los **clips SFX de las sacudidas** se cortan del master y se comprimen con
  el mismo `atempo` (sin eso el sonido sobreviviría al temblor);
- relojes de la vista re-derivados: flip **4,0 s** (f194), datos del premio
  **4,33 s** (f206), tramo **5,28 s** (190/36), y el auto-avance del tercer
  toque **0,33 s** (la sacudida B dura 0,31 s a 36; el 0,5 viejo habría
  clavado el cofre 0,2 s en la agachada — una traba nueva).

Contrato pineado en las dos puntas: mov = **190 frames exactos, 36/1,
5,278 s video / 5,269 s audio** (`test_chest_video_frames`, que ahora pina
duración de video Y de audio — un audio a 7,9 s contra un video de 5,3 s es
el atempo olvidado) y `ChestAnimationTests` con fps 36 y los playheads
re-contados.

## 3. La trampa GRANDE del día: el checkout compartido compila el árbol ajeno

A mitad de sesión, el fixture `--uitest-chest` "dejó de funcionar": app
viva, tablero andando, cero cofre, cero líneas de log. Dos horas de
arqueología después, la causa no estaba en el árbol: **el build baseline se
había compilado en el checkout principal MIENTRAS la sesión paralela
(`fisuevolution-c1`) editaba ese mismo árbol** — el binario heredó un estado
a medias ajeno. El MISMO commit compilado desde un worktree aislado funcionó
perfecto a la primera.

Protocolo desde ahora (§7 del general): con una sesión paralela viva en el
checkout, **ni un solo build de verificación desde el checkout compartido** —
worktree aislado SIEMPRE (`git worktree add` desde el HEAD local + symlink
del `.venv` + `xcodegen generate`). Señales de que te está pasando: builds
interrumpidos sin motivo (`database is locked`, `BUILD INTERRUPTED`) y
comportamiento imposible con el código que estás leyendo.

## 4. El instrumento también mejoró

- **Corridas de frames idénticos ≥100 ms**, no sólo distintos/s: los
  congelones puntuales viven DENTRO de un segundo que promedia bien.
- Extraer un frame "por índice" de una grabación del sim MIENTE: el h264 del
  sim es VFR y el frame n ≠ n/60 s (un frame extraído "a los 17 s" mostraba
  el reposo que en realidad llegó a los 21,5). Para mapear tiempos: SIEMPRE
  sobre el stream normalizado (`fps=60`) o con `-ss` por tiempo.

## Verificación del bloque

| qué | resultado |
|---|---|
| Pipeline Python | **13/13** ✅ (contrato nuevo: 190 exactos, duración vídeo+audio, clips ÷1,5) |
| Unit (463, sin `StoreManagerTests`) | únicos rojos los DOS documentados: el contrato de Pacing y `StoreProductsTests` (ENTORNO StoreKit del 26.5, §6 — corrió porque el skip sólo tapaba `StoreManagerTests`) |
| UI cofre (ChestOpening ×2 + circuito Regalos) | **3/3** ✅ sobre el retime (el 4× de los uitests ahora es 6× efectivo y sigue verde) |
| Grabación ANTES (24 fps, 1×) | cinemático 7,9 s · 24 distintos/s · congelones 150+133 ms en el empalme |
| Grabación DESPUÉS (36 fps, 1,5×) | cinemático **5,2 s** · **28–36 distintos/s** · empalme ~100 ms · arco entero verificado frame a frame (estallido → fade → giro → marco) |
| mov | 1600 KB (techo 4096) · still y PNGs sin cambios de peso |

## Decisiones de esta tanda

| Decisión | Por qué |
|---|---|
| 1,5x por RETIME (36 fps), no por `rate` de AVPlayer | mismo costo de decode que un mov de 36 nativo, pero el atempo offline suena mejor que el time-stretch del player, el asset es la verdad única, y `rate` queda libre para el 4× de los uitests (que ahora es 6× efectivo sobre el retime y sigue verde) |
| Todos los frames del master, ninguno sintetizado | «debe reproducirse correctamente como en el video»: 36 = 24×1,5 exacto — cada cuadro es del animador; interpolar era la alternativa y ya estaba medida como peor en el sim |
| El manifest lleva el fps de PRESENTACIÓN | una sola fuente de ritmo para PNGs y video: el empalme f49→f50 no puede cambiar de velocidad a mitad del gesto |
| El preroll espera `readyToPlay` con poll y no con KVO | `preroll` en `.unknown` crashea (medido en el primer smoke); KVO mete `@Sendable` que no convive con AVPlayer bajo strict concurrency; 50 ms de poll en la llegada son invisibles |
| La capa del video se monta invisible desde la llegada | el armado del `AVPlayerLayer` costaba parte de los ~280 ms del congelón, y en la llegada hay latidos enteros de hueco muerto |
