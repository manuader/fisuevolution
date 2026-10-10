# Asset pipeline — integración de arte

Este directorio **integra** imágenes al juego: las recorta, las exporta a los
atlas y escribe el manifest. **No las genera.** La generación vive en su propio
repo, `~/Desktop/projects/automatic-image-generation` (proyecto
`fisu-evolution`), desde el 2026-08-19.

## Setup

```bash
cd Tools/asset-pipeline
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
brew install ffmpeg        # sólo para el video del cofre
```

⚠️ Un worktree no trae `.venv` (está gitignoreado): usá el del checkout
principal o hacé un symlink.

## Integrar un asset nuevo

1. Generalo en `automatic-image-generation`.
2. Verificá que el asset tenga su entrada en `prompts/prompts.json`
   (`{assetKey, category, prompt}`) y, por convención, su
   `prompts/gemini_pro/<NNN>_<assetKey>.md`. Sin la entrada del JSON,
   `process_dropbox.py` lo rechaza como "NOMBRE DESCONOCIDO".
3. Copiá el PNG a `dropbox/<assetKey>.png` y corré:

   ```bash
   .venv/bin/python scripts/process_dropbox.py
   ```

   Recorta el fondo (`whitebg_cutout`), exporta `@2x`/`@3x` al atlas que toca,
   escribe la entrada del manifest y mueve el original a `dropbox/procesadas/`.
4. Commiteá juntos el atlas, el manifest y `dropbox/procesadas/`.

⚠️ Un build incremental **no** recompila los atlas: después de integrar,
borrá DerivedData antes de mirar el resultado en el juego.

### Categorías de la 2.0

| `category` | Claves | Destino |
|---|---|---|
| `npc` | `npc_<nombre>`, `npc_<nombre>_talk/_action/_face` y también `sp_<id>_talk/_face` | `npcs.atlas/<assetKey>`, manifest `npcs` |
| `skinfam` | `<tipo>__pijama`, `<tipo>__gaucho`, `<tipo>__dinosaurio` | `fam_<familia>.atlas/<tipo>_idle__<familia>`, sin manifest |

Las poses nuevas de los especiales van como `npc`, no como `special`: con
`special` caerían en `manifest['characters']` con un id que no es especial, y
`manifestEntriesReferenceRealTypes` se pone rojo.

### La tanda de la 2.0 (`tanda: "v2"`)

Sus entradas ya están en `prompts.json`. En lugar del paso 3 a mano, traé un grupo entero
desde `automatic-image-generation/projects/fisu-evolution-v2/output/`:

```bash
.venv/bin/python scripts/traer_tanda.py <npc|pijama|gaucho|dinosaurio|ui|fondos> [--dry-run]
```

Copia cada PNG a `dropbox/<assetKey>.png`. Si el generador nombró el archivo distinto de la
clave del juego, la entrada lo dice con `generado_como` (`ui_oro_autotap` → `ui_shop_auto_tap`);
un mismo PNG puede alimentar dos claves (`ui_shop_income_x2` y `_x3`). Falta un PNG: falla con
la lista, no trae nada a medias. `ui_oro_skin_effect` no tiene entrada (el dueño descartó los
efectos por código).

## Revisar recortes

El recorte se elige a ojo, asset por asset (decisión del dueño, HANDOFF §5).

**Desde 2026-10-10 todo esto se hace en el Estudio de assets**
(`Tools/asset-studio/`, doble clic en `~/Desktop/estudio-assets/Abrir Estudio de assets.command`):
fondo, islas, pincel, video y notas de regeneración en una sola página, con un
registro central en `~/Desktop/estudio-assets/registro.json`. Lo listo va al juego con
`Tools/asset-studio/aplicar.py --dry-run` / `--en-rama` (rama y worktree propios, tests
del pipeline, commit). Los tests del Estudio:
`.venv/bin/python -m unittest discover -s ../asset-studio/tests`. Los scripts de abajo
siguen andando y el Estudio los reusa.

| Script | Para qué |
|---|---|
| `revision_recortes.py` → `aplicar_revision.py` | Comparar conectividad contra saliencia y aplicar la elegida |
| `revision_islas.py` → `aplicar_islas.py` | Islas de papel blanco que el recorte deja pegadas |
| `balde_islas.py` → `aplicar_limpias.py` | Sacar a mano, con un balde rojo/verde, las islas sueltas de los sprites ya integrados (`~/Desktop/projects/islas-review`) |
| `elegir_recorte.py` | Cambiar el recorte de UN asset |
| `recut_assets.py` | Re-recortar en lote; respeta los elegidos a mano |

## Flujos aparte

| Script | Para qué |
|---|---|
| `chest_video_frames.py` | Del master `video/chest-animation.mp4` a `Resources/ChestAnim/` |
| `video_assets.py` | De los masters de Higgsfield (`video/loops/`, `video/objetos/`, `video/ascensor/`, `video/cinematicas/`) a `Resources/Loops/` y `Resources/Cinematics/`, más `Data/loops_manifest.json`. Retratos y objetos: recorte de fondo blanco cuadro por cuadro (`whitebg_cutout`); cabina: key verde medido en el hueco; cinemáticas: `--sin-key`, opacas con su audio |
| `install_app_icon.py` | Instalar un candidato como AppIcon (1024², sin alfa) |
| `analyze_recording.py`, `arrival_probe.py` | Medir trabones en grabaciones del simulador |

## Tests

```bash
.venv/bin/python -m unittest discover -s tests -q
```
