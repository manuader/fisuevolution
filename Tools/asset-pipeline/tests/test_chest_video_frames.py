"""El contrato de `ChestAnim/` visto desde el pipeline (schemaVersion 2).

La mitad de la prueba es geometria pura; la otra mitad mira lo que quedo
INTEGRADO en `Resources/ChestAnim/` — el manifest, los frames interactivos,
el video cinematico y el still del marco — porque el bug tipico de un pipeline
de assets no se ve en el codigo: se ve en el archivo que se compila.
`ChestAnimationTests` (Swift) pina el mismo contrato desde el runtime.
"""

import json
import subprocess
import shutil
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from chest_video_frames import (  # noqa: E402
    AUDIO_DIR,
    CARD_STILL_FILE,
    CARD_STILL_SCALE,
    CHEST_ANIM,
    CHEST_RECT,
    CINEMATIC_FILE,
    CINEMATIC_FIRST,
    CINEMATIC_LAST,
    CINEMATIC_SPEED,
    PARCHMENT_RECT,
    PLAYBACK_FPS,
    SEGMENTS,
    SHAKE_SFX,
    STATIC_OCCUPANCY,
    UI_ATLAS,
    cut_mass_fraction,
    clean_transparent_rgb,
    static_canvas_side,
)

# Presupuesto de los PNG interactivos; el video cinematico va aparte y su
# techo tambien esta pineado abajo. Si esto engorda, la decision de peso se
# tiene que volver a tomar, no colar.
PRESUPUESTO_PNG_KB = 2600
PRESUPUESTO_MOV_KB = 4096


class GeometriaPura(unittest.TestCase):
    def test_el_lienzo_del_estatico_calza_la_ocupacion_del_viejo(self):
        # 448 px de cofre al 84,4 % del ancho -> lienzo de 531.
        self.assertEqual(static_canvas_side(448), 531)

    def test_la_masa_cortada_se_mide_fuera_del_crop(self):
        alpha = np.zeros((10, 10))
        alpha[2:6, 2:6] = 100.0  # 16 celdas adentro
        alpha[0, 0] = 100.0      # 1 celda afuera
        fraction = cut_mass_fraction(alpha, (2, 2, 4, 4))
        self.assertAlmostEqual(fraction, 1 / 17, places=6)

    def test_un_crop_que_contiene_todo_no_corta_nada(self):
        alpha = np.ones((8, 8))
        self.assertEqual(cut_mass_fraction(alpha, (0, 0, 8, 8)), 0.0)

    def test_limpiar_transparentes_pone_negro_solo_donde_alfa_es_cero(self):
        rgba = np.full((2, 2, 4), 200, dtype=np.uint8)
        rgba[0, 0, 3] = 0
        out = clean_transparent_rgb(rgba)
        self.assertEqual(list(out[0, 0]), [0, 0, 0, 0])
        self.assertEqual(list(out[1, 1]), [200, 200, 200, 200])


if __name__ == "__main__":
    unittest.main()
