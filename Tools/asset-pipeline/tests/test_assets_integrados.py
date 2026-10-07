"""Barrido sobre el arte que ya esta en el juego: ningun personaje agujereado.

El bug que motivo el recorte nuevo (`rembg` dejando transparente lo blanco del
dibujo) no se ve en el codigo: se ve en el PNG. Esta prueba lo mira ahi, sobre lo
que realmente se compila, para que no pueda volver a entrar sin que salte."""

import json
import sys
import unittest
from functools import cache
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from process_dropbox import PIPELINE, RESOURCES, destination  # noqa: E402
from recut_assets import ORIGINALS, RECORTE_VIEJO_A_PEDIDO, recorte_elegido_a_mano  # noqa: E402
from whitebg_cutout import HUECOS_CALADOS, ISLAS_DE_PAPEL, PAPEL_MEDIDO, cutout  # noqa: E402

# Un uno por ciento cubre el ruido del reescalado a @2x sin dejar pasar un hueco
# de verdad: los rotos que se encontraron iban del 5% al 91%.
MAXIMO_HUECO = 1.0

# Los que pueden tener hueco sin que sea el bug: los que lo tienen de diseno y los
# doce que el dueno prefirio con el recorte viejo, donde el hueco es el precio de
# no cargar con la sombra del piso (ver `recut_assets.RECORTE_VIEJO_A_PEDIDO`).
CON_PERMISO = HUECOS_CALADOS | RECORTE_VIEJO_A_PEDIDO

# Los que tienen papel encerrado que se saco a proposito: el ovalo del lazo y el
# hueco de la soga del tropero, el aire entre la manga y la cabeza del medico. Son
# islas que el dueno eligio mirando (`prompts/islas_de_papel.json`, commit
# bc5f358) o que decide el color (`PAPEL_MEDIDO`), y su hueco es fondo, no dibujo.
# No entran a CON_PERMISO porque el permiso es ESE hueco y nada mas: se mide
# recortando su original, asi que un hueco nuevo en el mismo asset sigue saltando.
#
# Sin esto el test quedo en rojo desde 2b3d23f, y el rojo se leyo como "arte
# calado ya publicado" (PLAN-v2, E8) cuando era la decision del dueno.
CON_PAPEL_ELEGIDO = frozenset(ISLAS_DE_PAPEL) | PAPEL_MEDIDO


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


def porcentaje_de_hueco(imagen: Image.Image) -> float:
    alpha = np.array(imagen.convert("RGBA"))[..., 3]
    solido = alpha > 128
    if not solido.any():
        return 100.0
    tapado = ndimage.binary_fill_holes(solido)
    return float((tapado & ~solido).sum() / tapado.sum() * 100)


@cache
def hueco_permitido(asset_key: str) -> float:
    if asset_key not in CON_PAPEL_ELEGIDO:
        return MAXIMO_HUECO
    elegido = cutout(Image.open(ORIGINALS / f"{asset_key}.png"), asset_key)
    return MAXIMO_HUECO + porcentaje_de_hueco(elegido)


class AssetsIntegradosTests(unittest.TestCase):
    def test_ningun_asset_quedo_agujereado_por_dentro(self):
        agujereados = [
            (key, png.name, round(hueco, 2))
            for key, png in integrados()
            if key not in CON_PERMISO
            and not recorte_elegido_a_mano(key)
            and (hueco := porcentaje_de_hueco(Image.open(png))) > hueco_permitido(key)
        ]
        self.assertEqual(agujereados, [], f"assets con el dibujo calado: {agujereados}")

    def test_el_papel_elegido_no_tapa_un_hueco_nuevo(self):
        """El permiso del tropero es el ovalo de su lazo: si se le cala el pecho,
        salta igual."""
        png = RESOURCES / "cosmic.atlas" / "estanciero_estelar_idle__tropero@3x.png"
        rgba = np.array(Image.open(png).convert("RGBA"))
        rgba[200:250, 230:280, 3] = 0  # un cuadrado en el medio del pecho
        calado = porcentaje_de_hueco(Image.fromarray(rgba))
        self.assertGreater(calado, hueco_permitido("estanciero_estelar__tropero"))

    def test_ningun_asset_quedo_vacio(self):
        vacios = [
            png.name
            for _, png in integrados()
            if np.array(Image.open(png).convert("RGBA"))[..., 3].max() < 16
        ]
        self.assertEqual(vacios, [], f"assets transparentes enteros: {vacios}")


if __name__ == "__main__":
    unittest.main()
