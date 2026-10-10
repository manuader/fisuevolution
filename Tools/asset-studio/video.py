"""El recorte de un video, hecho desde el Estudio sin tocar el juego.

`video_assets.py` recorta el master y lo deja en `Resources/` con su entrada en
el manifest. Para MIRAR el resultado eso es demasiado: el Estudio lo procesa
igual —mismo kind, mismo criterio, mismos parametros de ffmpeg— pero a
`~/Desktop/estudio-assets/videos/`, y recien "Aplicar al juego" lo copia a su
lugar y lo registra en `loops_manifest.json`.
"""

from __future__ import annotations

import json
from pathlib import Path

import rutas  # noqa: F401
import video_assets as va  # noqa: E402
from chest_video_frames import KEY_BLEND, KEY_SIMILARITY  # noqa: E402


def matte_actual(kind: str, id_juego: str) -> str | None:
    """El matte con el que la pieza esta hoy en el juego (una cinematica puede ir
    sin key: trae su propio fondo)."""
    if not va.MANIFEST.exists():
        return va.KINDS[kind]["matte"]
    manifest = json.loads(va.MANIFEST.read_text(encoding="utf-8"))
    seccion, clave = va.target(kind, id_juego)
    entrada = manifest.get(seccion, {}).get(clave)
    return entrada["matte"] if entrada else va.KINDS[kind]["matte"]


def procesar(video: dict, carpeta: Path, menores: int = 0, progreso=None) -> tuple[Path, dict]:
    """Master -> `.mov` recortado en `carpeta`. Devuelve (ruta, opciones usadas)."""
    kind, id_juego = video["kind"], video["id_juego"]
    va.validate_id(kind, id_juego)
    master = Path(video["master"])
    if not master.exists():
        raise va.MasterError(f"no existe el master {master}")
    carpeta.mkdir(parents=True, exist_ok=True)
    salida = carpeta / video["archivo_mov"]
    temporal = salida.with_name(salida.stem + ".procesando.mov")
    matte = matte_actual(kind, id_juego)
    color = None
    if matte == "blanco":
        va.encode_cutout(kind, master, temporal, papel=id_juego in va.PAPEL_MEDIDO_VIDEO,
                         menores=menores, progreso=progreso)
    else:
        if matte == "verde":
            color = va.measure_key_color(master, en_el_cuadro=kind == "cabina")
        if progreso:
            progreso(0, 0)
        va.encode(kind, master, temporal, color, KEY_SIMILARITY, KEY_BLEND)
    temporal.replace(salida)
    return salida, {"matte": matte, "key_color": color, "menores": menores if matte == "blanco" else 0}


def instalar(video: dict, mov: Path, opciones: dict) -> dict:
    """Copia el `.mov` del Estudio a su lugar en `Resources/` y lo registra en el
    manifest, como lo hace `video_assets.process`. Devuelve la entrada."""
    import shutil

    kind, id_juego = video["kind"], video["id_juego"]
    destino = va.piece_dir(kind, id_juego) / video["archivo_mov"]
    destino.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(mov, destino)
    entrada = va.manifest_entry(destino, opciones.get("matte"), opciones.get("key_color"))
    if tag := va.odr_tag(kind, id_juego):
        entrada["odrTag"] = tag
    va.register(kind, id_juego, entrada)
    return entrada
