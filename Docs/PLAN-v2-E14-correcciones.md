# E14 — Correcciones del dueño antes de la App Store (2026-10-12)

> Pedido del dueño en el chat, corrección por corrección, antes de subir la 2.0. **Prioridad sobre
> la cola de `tasks.md`.** Las referencias visuales viven en `Docs/correcciones-v2/`. Regla de
> siempre: FisuJobs es la referencia visual y la gramática v3 es canon; el arte nuevo se genera en
> `automatic-image-generation` y entra por `Tools/asset-pipeline/dropbox/`.
>
> Estado: **recolectando** — no se implementa nada hasta que el dueño cierre la lista.

| # | Corrección | Toca | Arte nuevo | Estado |
|---|---|---|---|---|
| C1 | Fondos de piso: fuera los videos, sólo la foto | `FloorNode`, `BoardScene`, `loops_manifest.json` | no | anotada |

---

## C1 — Fondos de piso: fuera los videos, sólo la foto

**Lo que dijo el dueño:** el fondo en buena calidad sólo se ve al cambiar de escenario; ya en el
escenario aparece el video del fondo, que se ve notablemente peor. Sacar los videos del fondo y
usar solamente la foto, que está en mejor calidad.

**Por qué pasa (verificado en el código):**

- `FloorNode.render` (`Scenes/Nodes/FloorNode.swift:73-96`) monta la foto `bg_<escenario>.jpg`
  y, si `loops_manifest.json › floors` tiene clip, le pone encima un `LoopingVideoNode` con la
  foto como póster.
- `BoardScene.applyBackgroundAnimation` (`Scenes/BoardScene.swift` ~1701-1734) prende el video
  sólo en el piso visible y quieto. Por eso, durante el cambio de piso se ve la foto y al
  asentarse entra el video.
- Las fotos están a **2048×2048** (`Resources/Backgrounds/bg_*.jpg`) y los videos a
  **1024×1024** (`Resources/Backgrounds/Loops/bgloop_*.mov`, 10 clips, 6,7 MB). El video tiene
  la mitad de la resolución y encima compresión.

**Qué hacer:**

1. El piso muestra siempre la foto: se retira el `LoopingVideoNode` de fondo en `FloorNode`
   (`backgroundVideo`, `setBackgroundAnimating`, `hasBackgroundVideo`) y el
   `applyBackgroundAnimation` del tablero con sus llamadas.
2. Se saca la sección `floors` de `loops_manifest.json` y los 10 `bgloop_*.mov` del bundle
   (≈ 6,7 MB menos). Hay que revisar quién más lee `.floor(...)` antes de borrar:
   `LoopsManifest.swift`, `VisitCopy.swift`, `GameState+Upgrades.swift`, el Estudio de assets y
   `VideoPlaybackPolicy` (el tope de 3 videos libera un lugar).
3. Se limpian los tests y fixtures del fondo animado y lo que diga «fondo animado» en Ajustes,
   el tutorial o el Tour, si existe.

**Listo cuando:** en cualquier piso, quieto o después de un viaje en ascensor, se ve la foto de
2048 sin un solo frame de video; no queda `bgloop_*` en el bundle; el `rapido` está verde.

**Abierto:** el dueño habló de fondos «en 4K». Hoy no hay fuente 4K: las fotos del juego son
2048 (las de `fisu-evolution-v2/output`, reescaladas desde originales de 1254). Default: quedan
en 2048. Si se quieren en 4K, es un reescalado aparte (más peso en el bundle).
