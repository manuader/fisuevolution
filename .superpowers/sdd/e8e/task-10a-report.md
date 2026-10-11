# E8e T10a: spike del tablero animado con los cuadros de los clips base

**Estado:** DONE_WITH_CONCERNS. Los Steps 1 a 4 y el 6 están hechos. El Step 5 (🔒 el dueño en su SE) queda pendiente con el instructivo de abajo.
**Rama:** `v2i/e8e-t10a-spike` (desechable, no se integra). BASE `e1e39c1`.
**Worktree:** `/Users/manuader/Desktop/projects/FisuEvolution/.claude/worktrees.nosync/v2i-e8e-t10a-spike`

Etiquetas de cada número: **[M]** medido (con el comando indicado), **[E]** estimado (cuenta, no medición).

## Parámetros fijados (los consumen T10b a T10d)

| Parámetro | Valor | Base |
|---|---|---|
| `frames` | **16** | 12 cuadros solo ahorran disco (−11 %) y nada de memoria visible en el simulador. Es el escalón 1 si el SE no entra. |
| `cell` (px) | **256** | entra en todos los presupuestos de disco [M]. 192 px es el escalón 2. |
| `format` | **`png8-sheet`** (`idle_<tipo>.png` en la carpeta del pack `anim-piso-<n>`) | ASTC (variante C) **descartada**, ver "Descartado" |
| grilla | columnas = `ceil(sqrt(N))`, filas = `ceil(N / columnas)` (16 → 4×4 de 1024²; 12 → 4×3 de 1024×768) | spike |
| índices | `int(i * 120 / N + 0.5)`, `i = 0…N-1` (16 → 0, 8, 15, 22, 30, …, 113) | brief |
| `fps` | **el ritmo del clip: N / 5,0 s = 3,2 fps** (`timePerFrame` = 5,0 / N = 0,3125 s con 16) | El loop real dura 120 cuadros = 5,0 s, porque el cuadro 120 ≈ el 0 y se descarta. El brief decía 5,04 s (121/24), una diferencia del 0,8 % sin efecto visible. 6 y 8 fps quedan grabados para que el dueño compare. |
| `maxAnimated` | **`nil`** (provisorio) | Hace falta la memoria del SE (Step 5). El escalón 4 ya está prototipado (`--idle-max=N`). |
| `minPhysicalMemoryGB` | **`nil`** (provisorio) | igual que arriba |
| armado de texturas | **no se crea más de una `SKTexture(cgImage:)` de hoja por cuadro en el main**, o se crea fuera del main | [M] cuesta 15 ms por hoja de 1024² en el main (ver tiempos). Es la única carga atribuible al main. |
| fase por celda | rotar el arreglo de cuadros `slot * 5 mod N` | prototipo, sin salto al arrancar porque el cuadro 0 es el póster |

## Step 1: disco por variante

Comando [M]: `Tools/asset-pipeline/scripts/idle_frames_spike.py --out <scratch> --astc --gifs …` sobre los 43 tipos (`characters` sin `sp_*`), ffmpeg 8.1 `-pix_fmt rgba scale=L:L:flags=lanczos`, RGB=0 donde alfa=0, cuantizado PNG8 FASTOCTREE. Las métricas por tipo están en `.superpowers/sdd/e8e/t10a/metrics.json`.

| Variante | Hoja | Total de los 43 | Peor pack (piso 3, 10 tipos) | Hoja más pesada | Presupuesto (≤10 MB · ≤2,5 MB por pack · ≤300 KB por hoja) |
|---|---|---|---|---|---|
| **A16·256** | 1024² | **6,34 MB** [M] | **1,26 MB** [M] | 251 KB `emperador_cosmico` [M] | ✅ |
| A12·256 | 1024×768 | 5,65 MB [M] | 1,11 MB [M] | 233 KB [M] | ✅ |
| A16·192 | 768² | 3,82 MB [M] | 0,76 MB [M] | 148 KB [M] | ✅ |
| A12·192 | 768×576 | 3,38 MB [M] | 0,67 MB [M] | 136 KB [M] | ✅ |
| C16·256 (ASTC `gpu-optimized-best`, `.spriteatlas` con tag ODR) | atlas recortado de ≈984×968 | 27,6 MB sin adelgazar (ASTC 14,6 + HEVC 12,2) [M, `actool` + `assetutil --info`]; adelgazado para un teléfono: **12,7 MB** (HEVC, deployment ≥ 2018) o 15,1 MB (ASTC, deployment 2016) [M, `assetutil -i phone -s 2 -g APPLE7 -M 4 -r <año>`] | **3,14 MB** (`Assets.car` del pack piso 3 de la build) [M] | ≈310 KB por tipo [M] | ❌ total y peor pack |

¿Xcode respeta la variante C? **Sí** [M]. Con `IdleAstc.xcassets` en el target (XcodeGen lo suma como recurso), la build Debug del simulador deja los renditions en `OnDemandResources/…anim-piso-2/3….assetpack/Assets.car`, con el `Info.plist` del pack en `Tags = [anim-piso-3]`. En el `Assets.car` base quedan solo 252 `ExternalLink`. En esa build la compresión sale `astc`. En cambio, el adelgazado con deployment ≥ 2018 (el target es iOS 18) elige el rendition **HEVC**, que se decodifica a RGBA y no ahorra memoria de GPU.

Cierre del loop [M] (diferencia media sobre 255, cuadros de 256 px):

| Tipo | Clip 120→0 | A16: paso medio | A16: último→primero | A12: paso medio | A12: último→primero |
|---|---|---|---|---|---|
| homeless | 0,86 | 0,99 | 0,87 | 1,46 | 0,87 |
| administrativo (el más movido del piso 3) | 1,26 | 2,57 | 1,74 | 2,80 | 2,16 |
| oficinista (2.º del piso 3) | 0,81 | 1,99 | 1,10 | 2,58 | 1,11 |
| god | 1,17 | 0,90 | 1,18 | 1,18 | 1,18 |
| repartidor (el más movido de todos) | 1,25 | 4,58 | 2,07 | 2,97 | 2,00 |

En los 43 tipos, el salto último→primero queda en 1,23 pasos medios (mediana) y 1,73 en el peor caso (`rey_ladrillo`) [M]. No hay salto: el cierre es un paso más. `god` cierra con 1,18 contra un paso de 0,90 porque el clip mismo cierra con 1,17.

## Step 2: el ritmo

GIFs [M] (16 cuadros, fondo color piso) en `.superpowers/sdd/e8e/t10a/gifs/<tipo>_{a_clip,b_6fps,c_8fps}.gif`, para `homeless`, `administrativo`, `oficinista`, `god` y `repartidor`.
Tablero en el simulador con el visitante hablando, 8 s por ritmo, en `.superpowers/sdd/e8e/t10a/tablero/rec-{a-clip,b-6fps,c-8fps}.gif`. Las capturas son `captura-A16x256.png` y `captura-quieto.png`.
Default propuesto: **(a) el ritmo del clip**. A 6 u 8 fps el loop dura 2,7 o 2 s y el movimiento se ve acelerado respecto del video que el jugador ve en la ficha. Lo decide el dueño al mirarlo (Step 5).

## Step 3: el prototipo

- `Scenes/IdleBenchAnimator.swift` sigue este camino: hoja → `CGImageSource` + redibujo RGBA en `Task.detached` → `SKTexture(cgImage:)` → subtexturas `SKTexture(rect:in:)` → `SKTexture.preload` → `sprite.run(.repeatForever(.animate(…restore: true)))` con la fase corrida. La variante C usa `SKTextureAtlas(named:)` + `textureNamed` + `SKTexture.preload`. Pide el pack del tipo con `ArtPacks.request` y lo suelta con `release`. Solo carga los tipos del piso visible. Ante el aviso de memoria queda quieto y suelta todo. Con `--idle-max=N` anima solo los N nodos más cercanos al centroide.
- `CharacterNode` suma `runIdleFrames`, `stopIdleFrames` (que repone la textura del `configure`), `isIdleAnimating` y `showsRealArt`. `CharacterNodePool.obtain` corta la animación del **sprite**.
- En `BoardScene`, la propiedad, su `init`, un `sync` al final de `renderPlacements` y un `pollPolicy()` en `update`. Este último es solo del spike, porque no hay observador de la política: T10c suma `observePolicy`.
- Banco: `--uitest-idle-bench` / `--uitest-idle-bench-still` (+ `--uitest-idle-bench-cycle`, `--uitest-idle-bench-memwarn`, `--idle-variant=A16x256|A12x256|A16x192|A12x192|C16x256`, `--idle-fps=`, `--idle-max=`). Arma el piso 3 con sus 10 tipos distintos, el piso 2 lleno con sus 4, el visitante `vecina_chisme` hablando y la sonda.
- `FrameRateProbe` suma `peakMs`/`peakSlow`/`resetPeak()` para el peor cuadro de cada cambio de piso.

## Step 4: medición en el simulador

iPhone SE (3rd generation), iOS 18.6, build Debug, `--uitest-reset --uitest-skip-tutorial --uitest-video` + el modo. 65 s por corrida (105 s las de ciclo). Script `bench.sh`: log `fps-probe`/`idle-bench` por `log stream`, `footprint <pid>` a los 50 s y al final.

### Memoria y tiempos [M salvo marca]

| Modo | MB `phys_footprint` 20 a 60 s | `footprint` a 50 s | Decode de hoja fuera del main (mediana / máx) | Upload `preload` (mediana / máx) | **Main: armar las texturas** (mediana / máx) | `apply` en el main |
|---|---|---|---|---|---|---|
| quieto (`still`, `still2`) | 84 / 85–86 | 81 / 85 | — | — | — | — |
| A16·256 (dos corridas) | 82–86 / 81–85 | 84 / 84 | 75 / 108 ms · 62 / 92 ms | 207 / 389 · 73 / 379 ms | **15,2 / 17,5 ms** · 15,4 / 18,3 ms | ≤ 0,5 ms |
| A12·256 | 83–84 | 84 | 99 / 146 ms | 23 / 108 ms | 11,2 / 12,5 ms | ≤ 0,5 ms |
| A16·192 | 82–86 | 86 | 40 / 55 ms | 48 / 82 ms | 8,4 / 10,0 ms | ≤ 0,6 ms |
| A12·192 | 82–84 | 83 | 23 / 33 ms | 22 / 37 ms | 4,4 / 4,8 ms | ≤ 0,1 ms |
| C16·256 | 84–85 | 85 | — | 198 / 341 ms | **34,0 / 36,4 ms** (`SKTextureAtlas` + `textureNamed` en el main) | ≤ 0,3 ms |
| A16·256 `--idle-max=6` | 87–88 | 88 | 50 / 85 ms | 21 / 44 ms | 14,6 / 15,1 ms | ≤ 0,2 ms |

**Animado − quieto, memoria relativa: ≈ 0 MB, dentro del ruido de ±2 MB [M], pero no es concluyente.** El `footprint` por categoría (MALLOC_LARGE 31 a 34 MB, IOSurface 0 B y CG raster 1,3 MB en todos los modos) muestra que en el simulador ni la textura de GPU (Metal del Mac) ni la copia en CPU de las hojas aparecen en `phys_footprint`. Por eso la memoria relativa **no se puede medir en el simulador** y la decide el SE.
Estimado [E]: RGBA en GPU de 4 MiB por tipo con 16·256 (3 MiB con 12·256, 2,25 MiB con 16·192, 1,7 MiB con 12·192). El peor piso, el 3 con 10 tipos, da **40 MiB** con 16·256, el doble de la vara de 20 MB si el SE los cuenta todos. Si SpriteKit además retiene la `CGImage` (lo retiene: `SKTexture(cgImage:)`), habría hasta otros 40 MiB en CPU. Con `restore` + `preload` es probable que no se libere: **es el número que más importa del Step 5.**

### Cambio de piso 2 ↔ 3, veinte cambios (diez idas y vueltas) [M]

| Modo | Peor cuadro por cambio (ms, 20 cambios) | Lentos > 25 ms por cambio | MB en el piso 3 tras cada vuelta |
|---|---|---|---|
| quieto | 184, 138, luego 63–123 (estable ≈ 90–100) | 1–3 | 81–86 |
| A16·256 | 591, 414, luego 55–108 (estable ≈ 90–100) | 1–6 (≈ +2 sobre el quieto) | 81–86, sin crecer |
| C16·256 | 643, 538, luego 116–353 | 2–5 | 102–108; el `footprint` a 50 s llegó a 119 MB, ≈ +30 MB transitorio |

- El peor cuadro del cambio de piso lo pone el viaje de cámara y el fondo del piso, **también quieto**. Con A16·256 el peor cuadro estable es el mismo, más unos 2 cuadros > 25 ms por cambio. Esos dos cuadros coinciden con armar las texturas en el main (15 ms por hoja, y llegan varias en el mismo cuadro). En el simulador no se cumple "ninguno > 25 ms atribuible a la carga" hasta escalonar: **T10c arma una hoja por cuadro (o fuera del main)**. Los primeros dos cambios (591/414 ms) son el primer pedido de packs y caches frías: en el quieto pasa lo mismo (184/138).
- **Las hojas se sueltan** [M]: piso 2 ≈ 65–71 MB, piso 3 ≈ 81–86 MB, sin deriva tras 20 cambios. Son 146 `ready` en 20 cambios: cada vuelta al piso 3 vuelve a pedir, decodificar y subir.
- El `os_signpost` del `apply` está en el subsistema `com.manuader.fisuevolution`, categoría `idle`. `apply` no pasó nunca de 0,9 ms. Lo caro es armar las `SKTexture`, no aplicarlas.

### Aviso de memoria (`_performMemoryWarning`, el mismo que el menú del Simulator) [M]

- `memwarn stopped 10 restoredByAction 10 animating-now 0`: los 10 vuelven a quieto en el acto. La textura ya era la del `configure` tras el `removeAction` (10 de 10), pero `stopIdleFrames` la repone igual.
- MB: 86 antes → 86 (+1 s) → 86 (+5 s) → 87 (+15 s). Es lo mismo que en el quieto con aviso (86 → 86), así que **"la memoria baja" no se puede observar en el simulador** por lo de arriba. Se ve en el SE.

## Step 5: 🔒 instructivo para el dueño (iPhone SE)

1. En Xcode, rama `v2i/e8e-t10a-spike`, `xcodegen generate`, build **Debug** al SE. En el scheme (Run → Arguments), poné `--uitest-reset --uitest-skip-tutorial --uitest-video --uitest-idle-bench-still`. Esperá 60 s y anotá la línea de la sonda del panel DEBUG (fps · peor · > 25 ms · MB).
2. Lo mismo cambiando `--uitest-idle-bench-still` por `--uitest-idle-bench` (variante elegida, A16·256). Después sumá `--idle-variant=A12x192` (dos escalones abajo; para un escalón, `A12x256`).
3. Con `--uitest-idle-bench`, cambiá de piso 2 ↔ 3 diez veces con el ascensor o el swipe: ¿algún tirón? (o sumá `--uitest-idle-bench-cycle`, que lo hace solo desde los 30 s).
4. Mirá el tablero: ¿se ve bien el ritmo? ¿algún personaje "salta" al arrancar? Para comparar ritmos, `--idle-fps=6` y `--idle-fps=8`.
5. **Vara:** promedio ≥ 59 fps; ≤ 1 % de cuadros > 25 ms; **animado − quieto ≤ 20 MB** en el piso 3; total con videos ≤ quieto + 40 MB; ningún tirón al cambiar de piso.
6. Si no entra, la escalera: `--idle-variant=A12x256` → `A16x192`/`A12x192` → (ASTC descartado) → `--idle-max=6`, después `4` → quieto con < 3 GB. Pegá los números y el escalón que quedó en `DUENO.md` o en el chat.

## Descartado (con evidencia)

- **Variante C (ASTC por catálogo):** Xcode **sí** respeta el tag ODR y la compresión. Se descarta por tres razones medidas:
  1. Disco: 12,7 a 15,1 MB adelgazado y 3,14 MB el pack del piso 3. Rompe los presupuestos (≤ 10 MB y ≤ 2,5 MB por pack).
  2. Con deployment iOS 18 el adelgazado elige el rendition **HEVC**, no el ASTC (`assetutil -r 2018…2025` → hevc; `-r 2016` → astc), así que no ahorraría memoria de GPU en la tienda.
  3. `SKTextureAtlas(named:)` + `textureNamed` cuesta 34 ms por tipo **en el main**, más del doble que PNG8, con un pico transitorio de ≈ +30 MB al cambiar de piso.
- **Memoria relativa en el simulador:** no medible (ver Step 4). No se inventó un número: queda estimada y la mide el SE.
- **fps en el simulador:** son los de la GPU del Mac (60 en todos los modos). No cuentan para la vara.

## Hallazgo que afecta a todos (no solo a T10)

`VideoPlaybackPolicy.launch` da `forcedStill` en **toda build Debug lanzada a mano, aun con `--uitest-video`**. `StoreKitTest` (linkeado débil en DEBUG) carga XCTest, entonces `NSClassFromString("XCTestCase") != nil` [M: `xctestLoaded true` en el log, con `policy [forcedStill]`]. Sin el arreglo del spike (`--uitest-video` ignora `xctestLoaded`; `XCTestConfigurationFilePath` sigue mandando) ni el banco ni el `--uitest-anim-stress` de E8d corren con videos fuera de XCTest. Puede que el gate G1/G4 que se mida en el SE con build Debug tampoco. El controlador debería decidir si esto va como arreglo propio en `version-2`.

## Notas para T10c

- `restore: true` no alcanza como contrato. `stopIdleFrames` repone la textura base explícitamente, y el pool lo llama en `obtain`.
- Escalonar el armado de `SKTexture` (≤ 1 hoja por cuadro) o hacerlo fuera del main. Es lo único que el spike vio pegar en el main.
- El pack ODR tardó ≈ 1 a 5 s en llegar en el simulador. Mientras tanto el nodo sigue quieto, que es el comportamiento correcto.

## Archivos (rama del spike)

- `Tools/asset-pipeline/scripts/idle_frames_spike.py` (prototipo)
- `FisuEvolution/Resources/AnimPacks/anim-piso-*/idle_<tipo>.png` (43, A16·256) + `idle_<tipo>_n{12,16}_l{192,256}.png` (pisos 2 y 3)
- `FisuEvolution/Resources/IdleAstc.xcassets` (variante C, pisos 2 y 3)
- `FisuEvolution/Scenes/IdleBenchAnimator.swift`, `Scenes/Nodes/CharacterNode.swift`, `Scenes/BoardScene.swift`, `Debug/FrameRateProbe.swift`, `Game/State/GameState+Debug.swift`, `GameState+Bootstrap.swift`, `UI/Art/Video/VideoPlaybackPolicy.swift`
- `.superpowers/sdd/e8e/t10a/` (GIFs, capturas, `metrics.json`)
- Sin tests nuevos (spike) y sin `oraculo.sh tarea`, porque la rama no se integra. Compiló Debug para el simulador sin warnings (warnings como errores).
