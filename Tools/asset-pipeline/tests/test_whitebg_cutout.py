"""Pruebas del recorte de fondo blanco por conectividad."""

import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from whitebg_cutout import cutout  # noqa: E402


def draw(size: int = 256) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    canvas = Image.new("RGB", (size, size), (255, 255, 255))
    return canvas, ImageDraw.Draw(canvas)


def alpha_of(image: Image.Image) -> np.ndarray:
    return np.array(image)[..., 3]


class CutoutTests(unittest.TestCase):
    def test_saca_el_fondo_y_deja_el_dibujo(self):
        canvas, pen = draw()
        pen.ellipse((60, 60, 195, 195), fill=(200, 40, 40), outline=(0, 0, 0), width=4)

        alpha = alpha_of(cutout(canvas))

        self.assertEqual(alpha[5, 5], 0, "la esquina es fondo")
        self.assertEqual(alpha[128, 128], 255, "el centro del dibujo es opaco")

    def test_el_blanco_encerrado_por_el_dibujo_no_se_recorta(self):
        """El bug que motivo todo esto: el guardapolvo blanco del `senior_doctor`.

        Un modelo de saliencia lo lee como fondo porque es blanco; por conectividad
        no puede serlo, porque la linea del dibujo lo separa del borde."""
        canvas, pen = draw()
        pen.ellipse((40, 40, 215, 215), fill=(255, 255, 255), outline=(0, 0, 0), width=6)

        alpha = alpha_of(cutout(canvas))

        self.assertEqual(alpha[5, 5], 0)
        self.assertEqual(alpha[128, 128], 255, "el blanco de adentro es personaje")

    def test_los_huecos_calados_se_recortan_solo_donde_se_declaran(self):
        canvas, pen = draw()
        pen.ellipse((30, 30, 225, 225), fill=(255, 255, 255), outline=(0, 0, 0), width=6)
        pen.ellipse((90, 90, 165, 165), fill=(0, 0, 0), width=0)
        pen.ellipse((96, 96, 159, 159), fill=(255, 255, 255), width=0)

        self.assertEqual(alpha_of(cutout(canvas))[128, 128], 255)
        self.assertEqual(alpha_of(cutout(canvas, "fx_tap"))[128, 128], 0)

    def test_el_dibujo_que_toca_el_marco_no_se_desangra(self):
        """Los primeros planos apoyan los hombros contra el borde del lienzo."""
        canvas, pen = draw()
        pen.rectangle((0, 150, 255, 255), fill=(255, 255, 255), outline=(0, 0, 0), width=5)

        alpha = alpha_of(cutout(canvas))

        self.assertEqual(alpha[5, 5], 0, "arriba sigue siendo fondo")
        self.assertEqual(alpha[220, 128], 255, "los hombros pegados al marco quedan")

    def test_el_borde_queda_con_antialias_y_sin_halo_blanco(self):
        # ImageDraw dibuja con filo duro, asi que el antialias —que es lo que se
        # esta midiendo— hay que fabricarlo bajando de escala, como hace Gemini.
        grande, pen = draw(1024)
        pen.ellipse((240, 240, 783, 783), fill=(0, 0, 0))
        canvas = grande.resize((256, 256), Image.LANCZOS)

        recorte = np.array(cutout(canvas))
        alpha = recorte[..., 3]

        borde = (alpha > 10) & (alpha < 245)
        self.assertGreater(borde.sum(), 0, "el filo tiene opacidad fraccional")
        self.assertLess(
            recorte[..., :3][borde].max(), 200,
            "al semitransparente se le saca el blanco del fondo que traia mezclado",
        )

    def test_un_lienzo_sin_fondo_blanco_queda_entero(self):
        canvas = Image.new("RGB", (128, 128), (30, 90, 160))
        self.assertTrue((alpha_of(cutout(canvas)) == 255).all())


if __name__ == "__main__":
    unittest.main()
