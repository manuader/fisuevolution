#!/usr/bin/env python3
"""Reescala los PNG del juego al tamaño en que realmente se dibujan.

El pipeline exportaba TODO a 1024² (@2x) y 1536² (@3x): un ícono de moneda de
26 pt pesaba lo mismo que un fondo de pantalla completa. Eso no sólo desperdicia
memoria, **rompe el texture atlas**: el límite de página es 2048 px, así que dos
imágenes de 1536 no entran juntas y el packer termina poniendo una por página.
Con una imagen por página el atlas no agrupa nada y cada sprite en pantalla es su
propio draw call irreducible.

Bajando a 512 entran ~16 por página y el batching vuelve a funcionar.

Los fondos NO se tocan: son el único grupo que está sub-muestreado (se dibujan
magnificados ~1,9×), así que reducirlos los empeoraría. Su problema es la
proporción —son cuadrados para una pantalla 9:19.5— y se trata aparte.

    .venv/bin/python scripts/rightsize_assets.py [--dry-run]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PIPELINE = Path(__file__).resolve().parents[1]
RESOURCES = PIPELINE.parent.parent / "FisuEvolution" / "Resources"

# Tamaño objetivo por grupo, en píxeles: (@2x, @3x).
#
# Los personajes se dibujan a ~146 pt → 438 px @3x; 512 deja margen para que un
# piso con menos capacidad los agrande sin que se vean blandos.
CHARACTER_SIZE = (384, 512)
# Paneles, retratos de tutorial y logo se estiran grande en pantalla.
LARGE_UI_SIZE = (448, 640)
# Íconos y botones: el botón más alto mide 60 pt → 180 px @3x.
SMALL_UI_SIZE = (192, 256)

LARGE_UI_PREFIXES = ("panel_", "fisura_", "logo")


def target_for(atlas: str, stem: str) -> tuple[int, int] | None:
    """Devuelve (@2x, @3x) o None si el asset no se toca."""
    if atlas in {"earth.atlas", "cosmic.atlas", "specials.atlas"}:
        return CHARACTER_SIZE
    if atlas == "ui.atlas":
        base = stem.split("@")[0]
        if base.startswith(LARGE_UI_PREFIXES):
            return LARGE_UI_SIZE
        return SMALL_UI_SIZE
    return None  # Backgrounds y cualquier cosa nueva: sin tocar.


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    from PIL import Image

    total_before = total_after = 0
    changed = skipped = 0

    for atlas_dir in sorted(RESOURCES.iterdir()):
        if not atlas_dir.is_dir() or not atlas_dir.name.endswith(".atlas"):
            continue
        for png in sorted(atlas_dir.glob("*.png")):
            target = target_for(atlas_dir.name, png.stem)
            if target is None:
                continue
            scale_index = 1 if png.stem.endswith("@3x") else 0
            side = target[scale_index]

            before = png.stat().st_size
            with Image.open(png) as image:
                if max(image.size) <= side:
                    skipped += 1
                    total_before += before
                    total_after += before
                    continue
                resized = image.convert("RGBA").resize((side, side), Image.LANCZOS)
            if not args.dry_run:
                resized.save(png, optimize=True)
            after = png.stat().st_size if not args.dry_run else before
            total_before += before
            total_after += after
            changed += 1

    print(f"redimensionados: {changed} | ya estaban bien: {skipped}")
    print(f"disco: {total_before / 1e6:.1f} MB → {total_after / 1e6:.1f} MB")
    if args.dry_run:
        print("(dry-run: no se escribió nada)")


if __name__ == "__main__":
    sys.exit(main())
