"""Barrido sobre el arte que ya esta en el juego: ningun personaje agujereado.

El bug que motivo el recorte nuevo (`rembg` dejando transparente lo blanco del
dibujo) no se ve en el codigo: se ve en el PNG. Esta prueba lo mira ahi, sobre lo
que realmente se compila, para que no pueda volver a entrar sin que salte."""

import json
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from process_dropbox import PIPELINE, RESOURCES, destination  # noqa: E402
from whitebg_cutout import HUECOS_CALADOS  # noqa: E402

# Un uno por ciento cubre el ruido del reescalado a @2x sin dejar pasar un hueco
# de verdad: los rotos que se encontraron iban del 5% al 91%.
MAXIMO_HUECO = 1.0


def integrados():
    prompts = json.loads((PIPELINE / "prompts" / "prompts.json").read_text())
    for entry in sorted(prompts, key=lambda e: e["assetKey"]):
        if entry.get("category") == "background":
            continue
        atlas_name, asset_key, _ = destination(entry)
        for escala in ("@2x", "@3x"):
            png = RESOURCES / atlas_name / f"{asset_key}{escala}.png"
            if png.exists():
                yield entry["assetKey"], png


def porcentaje_de_hueco(png: Path) -> float:
    alpha = np.array(Image.open(png).convert("RGBA"))[..., 3]
    solido = alpha > 128
    if not solido.any():
        return 100.0
    tapado = ndimage.binary_fill_holes(solido)
    return float((tapado & ~solido).sum() / tapado.sum() * 100)


class AssetsIntegradosTests(unittest.TestCase):
    def test_ningun_asset_quedo_agujereado_por_dentro(self):
        agujereados = [
            (key, png.name, round(hueco, 2))
            for key, png in integrados()
            if key not in HUECOS_CALADOS
            and (hueco := porcentaje_de_hueco(png)) > MAXIMO_HUECO
        ]
        self.assertEqual(agujereados, [], f"assets con el dibujo calado: {agujereados}")

    def test_ningun_asset_quedo_vacio(self):
        vacios = [
            png.name
            for _, png in integrados()
            if np.array(Image.open(png).convert("RGBA"))[..., 3].max() < 16
        ]
        self.assertEqual(vacios, [], f"assets transparentes enteros: {vacios}")


if __name__ == "__main__":
    unittest.main()
