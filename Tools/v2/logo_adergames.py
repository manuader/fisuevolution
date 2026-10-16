#!/usr/bin/env python3
"""Arma el imageset del logo de Ader Games (PLAN-v2 E14b B34, D23).

Toma el recorte con alfa (el logo del sitio ya sin fondo negro), lo recorta al
rectángulo del contenido, suaviza 1 px el borde (el alfa del recorte es
binario y serrucha) y exporta @2x/@3x de un logo de ANCHO_PT puntos de ancho,
que es el tamaño con que la pantalla de lanzamiento lo dibuja (iOS lo centra a
su tamaño natural) y con que el splash arranca.

Uso: python3 Tools/v2/logo_adergames.py <recorte.png> [imageset]
Requiere Pillow.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter

ANCHO_PT = 180
DEFAULT_SET = Path(__file__).resolve().parents[2] / "FisuEvolution/Resources/Assets.xcassets/AderGamesLogo.imageset"


def main() -> None:
    src = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_SET
    im = Image.open(src).convert("RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    images = []
    out.mkdir(parents=True, exist_ok=True)
    for scale in (2, 3):
        w = ANCHO_PT * scale
        h = round(im.height * w / im.width)
        # El radio va en píxeles de ORIGEN: ~1 px de destino tras el reescalado.
        radio = im.width / w
        base = im.copy()
        base.putalpha(base.getchannel("A").filter(ImageFilter.GaussianBlur(radio * 0.8)))
        name = f"adergames-logo@{scale}x.png"
        base.resize((w, h), Image.LANCZOS).save(out / name, optimize=True)
        images.append({"idiom": "universal", "filename": name, "scale": f"{scale}x"})
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (out / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


if __name__ == "__main__":
    main()
