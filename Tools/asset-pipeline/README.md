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

## Revisar recortes

El recorte se elige a ojo, asset por asset (decisión del dueño, HANDOFF §5).

| Script | Para qué |
|---|---|
| `revision_recortes.py` → `aplicar_revision.py` | Comparar conectividad contra saliencia y aplicar la elegida |
| `revision_islas.py` → `aplicar_islas.py` | Islas de papel blanco que el recorte deja pegadas |
| `elegir_recorte.py` | Cambiar el recorte de UN asset |
| `recut_assets.py` | Re-recortar en lote; respeta los elegidos a mano |

## Flujos aparte

| Script | Para qué |
|---|---|
| `chest_video_frames.py` | Del master `video/chest-animation.mp4` a `Resources/ChestAnim/` |
| `install_app_icon.py` | Instalar un candidato como AppIcon (1024², sin alfa) |
| `analyze_recording.py`, `arrival_probe.py` | Medir trabones en grabaciones del simulador |

## Tests

```bash
.venv/bin/python -m unittest discover -s tests -q
```
