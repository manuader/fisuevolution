#!/usr/bin/env python3
"""Rehace el recorte de TODOS los assets ya integrados, desde el original.

Los assets del juego se recortaron con `rembg`, que decide por saliencia y por eso
dejo transparente lo blanco de los personajes: el guardapolvo del `senior_doctor`,
las camisas, los papeles. Los originales con fondo blanco estan guardados en
`dropbox/procesadas/`, asi que el arreglo no necesita regenerar nada con Gemini —
alcanza con volver a recortar con `whitebg_cutout`, que corta por conectividad.

    .venv/bin/python scripts/recut_assets.py --dry-run
    .venv/bin/python scripts/recut_assets.py

Los backgrounds no se tocan: nunca se recortaron, van con fondo y todo.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))

from process_dropbox import PIPELINE, RESOURCES, destination, export_atlas  # noqa: E402
from whitebg_cutout import cutout  # noqa: E402

ORIGINALS = PIPELINE / "dropbox" / "procesadas"

# `homeless` es El Fisura, y su original nunca paso por el dropbox: es la
# referencia de estilo aprobada a mano con la que se genero todo lo demas.
ORIGINALES_APARTE = {"homeless": PIPELINE / "heroes" / "approved" / "fisura.png"}

# Los dos originales que NO tienen fondo blanco: Gemini los devolvio como escena
# entera (el estanciero contra un campo estrellado, el cirujano en el quirofano).
# Recortar por conectividad ahi no saca nada — el fondo no es blanco — y dejaria
# el mosaico completo como si fuera el personaje. La silueta que ya esta en el
# juego es buena, asi que a estos se les respeta el recorte y solo se les tapan
# los huecos de adentro, que es la parte del bug que si los toco.
SIN_FONDO_BLANCO = frozenset({"estanciero_estelar", "senior_doctor__cirujano"})


def original_de(asset_key: str) -> Path:
    return ORIGINALES_APARTE.get(asset_key, ORIGINALS / f"{asset_key}.png")


def tapar_huecos(original: Image.Image, integrado: Image.Image) -> Image.Image:
    """Silueta la del asset ya integrado, color el del original, sin huecos.

    Para los assets de `SIN_FONDO_BLANCO`: el recorte de hoy separo bien al
    personaje de su escena, pero le dejo agujeros adentro. Rellenar los huecos de
    la mascara los cierra sin tocar el contorno, y el color sale del original —
    no del PNG ya reescalado— asi no se arrastra la mezcla del borde."""
    alpha = np.array(
        integrado.convert("RGBA").resize(original.size, Image.LANCZOS)
    )[..., 3].astype(np.float32) / 255.0
    solid = alpha > 0.5
    alpha[ndimage.binary_fill_holes(solid) & ~solid] = 1.0
    return Image.fromarray(
        np.dstack([
            np.array(original.convert("RGB")),
            (alpha * 255).round().astype(np.uint8),
        ]),
        mode="RGBA",
    )


def entries() -> list[dict]:
    prompts = json.loads((PIPELINE / "prompts" / "prompts.json").read_text())
    return [e for e in prompts if e.get("category") != "background"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="solo listar")
    parser.add_argument("--only", action="append", default=[], metavar="ASSETKEY")
    args = parser.parse_args()

    todo = entries()
    if args.only:
        todo = [e for e in todo if e["assetKey"] in set(args.only)]

    rehechos, sin_original, sin_integrar = [], [], []
    for entry in sorted(todo, key=lambda e: e["assetKey"]):
        key = entry["assetKey"]
        original = original_de(key)
        atlas_name, asset_key, _ = destination(entry)

        if not original.exists():
            sin_original.append(key)
            continue
        integrado = RESOURCES / atlas_name / f"{asset_key}@3x.png"
        if not integrado.exists():
            # El asset no esta en el juego; recortarlo ahora seria integrarlo por
            # la ventana, que no es lo que este script viene a hacer.
            sin_integrar.append(key)
            continue

        rehechos.append(key)
        if args.dry_run:
            continue
        src = Image.open(original)
        if key in SIN_FONDO_BLANCO:
            recorte = tapar_huecos(src, Image.open(integrado))
            nota = " (silueta de hoy, huecos tapados)"
        else:
            recorte = cutout(src, key)
            nota = ""
        export_atlas(recorte, entry, atlas_name, asset_key)
        print(f"  ✓ {key} → {atlas_name}/{asset_key}@2x/@3x{nota}", flush=True)

    verbo = "se rehacen" if args.dry_run else "rehechos"
    print(f"\n{verbo}: {len(rehechos)}")
    if sin_integrar:
        print(f"con original pero fuera del juego ({len(sin_integrar)}): {sin_integrar}")
    if sin_original:
        print(f"SIN ORIGINAL, no se pueden rehacer ({len(sin_original)}): {sin_original}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
