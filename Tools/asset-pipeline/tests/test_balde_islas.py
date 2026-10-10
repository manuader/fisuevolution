"""Pruebas del balde de islas: rojo se saca, verde se queda."""

import sys
import unittest
from pathlib import Path

import numpy as np

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from balde_islas import islas, limpiar, mapa  # noqa: E402


def dos_islas() -> np.ndarray:
    """Un cuerpo grande con un hueco blanco adentro y una chispa suelta."""
    rgba = np.zeros((128, 128, 4), dtype=np.uint8)
    rgba[20:110, 20:80] = (40, 40, 200, 255)          # cuerpo
    rgba[50:70, 40:60] = (255, 255, 255, 255)         # blanco encerrado
    rgba[10:12, 100:102] = (220, 60, 30, 255)         # chispa
    rgba[9, 100:102] = (220, 60, 30, 4)               # su antialias, bajo el umbral
    return rgba


class BaldeDeIslasTests(unittest.TestCase):
    def test_encuentra_las_sueltas_por_tamano_y_el_hueco(self):
        _, _, fichas = islas(dos_islas())
        ids = {f["id"]: f for f in fichas}

        self.assertEqual(set(ids), {"s1", "s2", "h1"})
        self.assertEqual(ids["s1"]["area"], 90 * 60, "s1 es siempre la mas grande: el cuerpo")
        self.assertTrue(ids["s2"]["diminuta"], "la chispa se pierde con el ojo")
        self.assertEqual(ids["h1"]["dentro_de"], "s1")

    def test_la_roja_desaparece_y_la_verde_queda(self):
        rgba = dos_islas()

        limpio = limpiar(rgba, ["s2"])

        self.assertTrue((limpio[9:12, 100:102, 3] == 0).all(), "la chispa y su antialias se van")
        np.testing.assert_array_equal(limpio[20:110, 20:80], rgba[20:110, 20:80])

    def test_sacar_el_hueco_deja_el_cuerpo(self):
        rgba = dos_islas()

        limpio = limpiar(rgba, ["h1"])

        self.assertTrue((limpio[50:70, 40:60, 3] == 0).all())
        self.assertEqual(limpio[30, 30, 3], 255)
        self.assertEqual(limpio[11, 101, 3], 255, "la chispa no se pinto: se queda")

    def test_el_mapa_lleva_los_ids_que_lee_la_pagina(self):
        sueltas, huecos, _ = islas(dos_islas())
        pixeles = np.array(mapa(sueltas, huecos))

        self.assertEqual(tuple(pixeles[11, 101]), (2, 0, 0, 255))
        self.assertEqual(tuple(pixeles[60, 50]), (1, 0, 1, 255))
        self.assertEqual(tuple(pixeles[0, 0]), (0, 0, 0, 255))


if __name__ == "__main__":
    unittest.main()
