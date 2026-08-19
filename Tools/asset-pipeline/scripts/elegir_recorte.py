#!/usr/bin/env python3
"""Cambia el recorte de un asset ya integrado por el de la otra herramienta.

Las dos versiones conviven: el atlas tiene la de conectividad (`whitebg_cutout`,
la que usa el pipeline) y `state/rembg/` guarda la de saliencia con los mismos
nombres y tamaños. Ninguna de las dos gana siempre — la conectividad conserva el
blanco encerrado del dibujo (una camisa, pero tambien la sombra del piso) y la
saliencia se lo come (la sombra, pero tambien la camisa)—, asi que la eleccion es
por asset y a ojo.

    scripts/elegir_recorte.py --rembg emprendedor__oro magnate_solar__diamante
    scripts/elegir_recorte.py --conectividad emprendedor__oro   # volver atras
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

from process_dropbox import PIPELINE, RESOURCES, destination, export_atlas  # noqa: E402
from whitebg_cutout import cutout  # noqa: E402

REMBG = PIPELINE / "state" / "rembg"
ORIGINALES = PIPELINE / "dropbox" / "procesadas"


def entradas() -> dict[str, dict]:
    prompts = json.loads((PIPELINE / "prompts" / "prompts.json").read_text())
    return {e["assetKey"]: e for e in prompts}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    grupo = parser.add_mutually_exclusive_group(required=True)
    grupo.add_argument("--rembg", nargs="+", metavar="ASSETKEY", default=[])
    grupo.add_argument("--conectividad", nargs="+", metavar="ASSETKEY", default=[])
    args = parser.parse_args()

    catalogo = entradas()
    for key in args.rembg:
        entrada = catalogo[key]
        atlas, asset_key, _ = destination(entrada)
        faltan = [
            e for e in ("@2x", "@3x")
            if not (REMBG / atlas / f"{asset_key}{e}.png").exists()
        ]
        if faltan:
            print(f"  ✗ {key}: no hay version de rembg ({', '.join(faltan)})")
            continue
        for escala in ("@2x", "@3x"):
            shutil.copy2(REMBG / atlas / f"{asset_key}{escala}.png",
                         RESOURCES / atlas / f"{asset_key}{escala}.png")
        print(f"  ✓ {key} → rembg")

    for key in args.conectividad:
        entrada = catalogo[key]
        atlas, asset_key, _ = destination(entrada)
        original = ORIGINALES / f"{key}.png"
        if not original.exists():
            print(f"  ✗ {key}: falta el original {original.name}")
            continue
        export_atlas(cutout(Image.open(original), key), entrada, atlas, asset_key)
        print(f"  ✓ {key} → conectividad")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
