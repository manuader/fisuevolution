"""El borde de arriba de los clips con alfa (PLAN-v2 E14b B32): el degrade que se hornea y los clips
de apertura que ya lo llevan.

Dos partes: la aritmetica del degrade sobre cuadros sinteticos (corre en cualquier maquina) y, en
macOS, que los tres clips de apertura que tenian los rayos cortados (paquete, cofre y colchon) ya no
toquen el borde de arriba, mas que mantienen su formato.
"""

import shutil
import sys
import unittest
from pathlib import Path

import numpy as np

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import borde_difuminado as bd  # noqa: E402

LOOPS = Path(__file__).resolve().parents[3] / "FisuEvolution" / "Resources" / "Loops"
HORNEADOS = ("obj_paquete_abre", "obj_cofre_abre", "obj_colchon_abre")


def cuadros_con_rayos(n=6, alto=512, ancho=8, desde=3):
    """Cuadros opacos de adentro; a partir de `desde`, tambien la fila de arriba."""
    c = np.zeros((n, alto, ancho, 4), np.uint8)
    c[:, 150:, :, 3] = 255
    c[desde:, :, :, 3] = 255
    return c


class DegradeTest(unittest.TestCase):
    def test_va_de_casi_cero_arriba_a_uno_en_el_porcentaje(self):
        g = bd.degrade(512, 15.0)[:, 0]
        self.assertLess(g[0], 0.05)
        self.assertTrue(np.all(np.diff(g) >= 0))
        self.assertEqual(g[77], 1.0)
        self.assertEqual(g[511], 1.0)

    def test_el_cuadro_de_los_rayos_es_el_primero_que_toca_el_borde(self):
        self.assertEqual(bd.cuadro_de_rayos(cuadros_con_rayos(desde=3)), 3)

    def test_sin_nada_en_el_borde_no_hay_cuadro_de_rayos(self):
        self.assertIsNone(bd.cuadro_de_rayos(cuadros_con_rayos(desde=99)))

    def test_difuminar_deja_enteros_los_cuadros_de_antes_y_funde_los_de_despues(self):
        c = cuadros_con_rayos(desde=3)
        d = bd.difuminar(c, 3, 15.0)
        np.testing.assert_array_equal(d[:3], c[:3])
        self.assertFalse(bd.toca_borde(d).any())
        self.assertEqual(d[4, 300, 0, 3], 255)
        self.assertEqual(d.shape, c.shape)

    def test_funde_el_color_con_el_alfa_porque_es_premultiplicado(self):
        # si el color quedara entero sobre un alfa casi nulo, el juego lo sumaria al fondo
        c = cuadros_con_rayos(desde=0)
        c[..., :3] = 200
        d = bd.difuminar(c, 0, 15.0)
        self.assertTrue(np.all(d[..., :3].max(axis=-1) <= d[..., 3]))
        np.testing.assert_array_equal(d[:, 300:], c[:, 300:])
        self.assertLess(d[0, 0, 0, 2], 10)


@unittest.skipUnless(sys.platform == "darwin" and shutil.which("swiftc") and shutil.which("ffprobe"),
                     "lee el alfa con AVFoundation: solo macOS")
class ClipsHorneadosTest(unittest.TestCase):
    def test_ya_no_tocan_el_borde_de_arriba(self):
        for nombre in HORNEADOS:
            with self.subTest(nombre):
                c = bd.leer_cuadros(LOOPS / f"{nombre}.mov")
                self.assertEqual(c.shape[1:3], (512, 512))
                self.assertFalse(bd.toca_borde(c).any())

    def test_el_degrade_queda_premultiplicado(self):
        # el 15 % de arriba de los cuadros horneados: el color no supera al alfa (mas el ruido del
        # codec); con el error de la primera horneada el 68 % de lo semitransparente lo superaba
        for nombre in HORNEADOS:
            with self.subTest(nombre):
                c = bd.leer_cuadros(LOOPS / f"{nombre}.mov")[:, :77].astype(int)
                semi = (c[..., 3] > 5) & (c[..., 3] < 250)
                pasados = (c[..., :3].max(axis=-1) > c[..., 3] + 12) & semi
                self.assertLess(pasados.sum() / max(semi.sum(), 1), 0.02)

    def test_mantienen_el_formato(self):
        for nombre in HORNEADOS:
            with self.subTest(nombre):
                p = bd.propiedades(LOOPS / f"{nombre}.mov")
                self.assertEqual((p["codec_name"], p["codec_tag_string"]), ("hevc", "hvc1"))
                self.assertEqual((p["width"], p["height"], p["nb_read_frames"]), ("512", "512", "73"))

    def test_el_salto_de_las_tapas_del_paquete_queda_intacto(self):
        # antes de los rayos (cuadro 44) las tapas llegan al 6 % de arriba: sin degrade
        c = bd.leer_cuadros(LOOPS / "obj_paquete_abre.mov")
        self.assertLess(bd.fila_mas_alta(c)[43], 7.0)
        self.assertGreater(c[43, :, :, 3].max(), 200)


if __name__ == "__main__":
    unittest.main()
