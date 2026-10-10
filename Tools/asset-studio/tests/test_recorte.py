"""El paso de islas: lo que sale no deja borde, y el pincel y la goma hacen lo que dicen."""

import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from recorte import islas, mascara_de_trazo, renderizar  # noqa: E402

TINTA = (30, 30, 120)


def con_borde_suave(rgba: np.ndarray, centro: tuple[int, int], radio: float, color) -> None:
    """Un disco con su anillo de antialias de 4 px, como lo deja un recorte."""
    alto, ancho = rgba.shape[:2]
    yy, xx = np.mgrid[:alto, :ancho]
    distancia = np.hypot(yy - centro[0], xx - centro[1]) - radio
    alfa = np.clip(1 - distancia / 4, 0, 1)
    pinta = alfa > rgba[..., 3] / 255
    rgba[pinta, :3] = color
    rgba[pinta, 3] = np.round(alfa[pinta] * 255).astype(np.uint8)


def personaje_y_chispa() -> np.ndarray:
    rgba = np.zeros((160, 160, 4), dtype=np.uint8)
    con_borde_suave(rgba, (80, 60), 40, TINTA)        # el personaje
    con_borde_suave(rgba, (30, 135), 6, (230, 90, 20))  # la chispa suelta, a mas de 20 px
    return rgba


class SacarSinHaloTests(unittest.TestCase):
    def test_la_isla_se_va_con_todo_su_anillo_y_el_personaje_no_se_toca(self):
        rgba = personaje_y_chispa()
        ids = {f["id"]: f for f in islas(rgba)[2]}
        self.assertIn("s2", ids, "la chispa es la segunda isla")

        final = renderizar(rgba, ["s2"], [])

        yy, xx = np.mgrid[:160, :160]
        anillo_chispa = np.hypot(yy - 30, xx - 135) <= 6 + 6
        self.assertEqual(int(final[anillo_chispa, 3].max()), 0, "ni un pixel del antialias de la chispa")
        personaje = np.hypot(yy - 80, xx - 60) <= 40 + 6
        np.testing.assert_array_equal(final[personaje], rgba[personaje], "el contorno del personaje intacto")

    def test_el_antialias_suelto_bajo_el_umbral_tambien_se_va(self):
        rgba = personaje_y_chispa()
        rgba[30, 146:149] = (230, 90, 20, 6)  # polvo de antialias que ninguna isla reclama

        final = renderizar(rgba, ["s2"], [])

        self.assertEqual(int(final[30, 146:149, 3].max()), 0)

    def test_sacar_un_hueco_blanco_no_deja_linea_clara(self):
        rgba = np.zeros((120, 120, 4), dtype=np.uint8)
        rgba[10:110, 10:110] = (*TINTA, 255)
        yy, xx = np.mgrid[:120, :120]
        r = np.hypot(yy - 60, xx - 60)
        # Hueco blanco de radio 20 con el filo que mezcla la tinta con el blanco.
        mezcla = np.clip((r - 20) / 3, 0, 1)[..., None]
        zona = r < 23
        rgba[zona, :3] = np.round(255 * (1 - mezcla[zona]) + np.array(TINTA) * mezcla[zona]).astype(np.uint8)
        hueco = next(f["id"] for f in islas(rgba)[2] if f["id"].startswith("h"))

        final = renderizar(rgba, [hueco], [])

        # Compuesto sobre negro, el filo no puede brillar mas que la tinta.
        sobre_negro = final[..., :3].astype(float) * final[..., 3:4] / 255
        filo = (r >= 19) & (r <= 26)
        self.assertLessEqual(sobre_negro[filo].max(), max(TINTA) + 3, "quedo una linea clara")
        self.assertEqual(int(final[r < 18, 3].max()), 0, "el hueco se fue")
        np.testing.assert_array_equal(final[r > 30][..., 3], rgba[r > 30][..., 3])


class PincelYGomaTests(unittest.TestCase):
    def test_el_pincel_saca_y_la_goma_devuelve(self):
        rgba = np.zeros((100, 100, 4), dtype=np.uint8)
        rgba[20:80, 20:80] = (*TINTA, 255)
        pincel = {"modo": "pincel", "radio": 5, "puntos": [[30, 50], [70, 50]]}
        goma = {"modo": "goma", "radio": 5, "puntos": [[50, 50]]}

        solo_pincel = renderizar(rgba, [], [pincel])
        con_goma = renderizar(rgba, [], [pincel, goma])

        self.assertEqual(solo_pincel[50, 30, 3], 0)
        self.assertEqual(solo_pincel[50, 70, 3], 0)
        self.assertEqual(solo_pincel[30, 50, 3], 255, "lejos del trazo no se toca")
        self.assertEqual(con_goma[50, 50, 3], 255, "la goma devolvio el medio")
        self.assertEqual(con_goma[50, 35, 3], 0, "fuera de la goma sigue sacado")

    def test_la_goma_devuelve_parte_de_una_isla_roja(self):
        rgba = personaje_y_chispa()
        goma = {"modo": "goma", "radio": 3, "puntos": [[135, 30]]}

        final = renderizar(rgba, ["s2"], [goma])

        self.assertGreater(int(final[30, 135, 3]), 0)

    def test_el_trazo_tiene_el_radio_pedido(self):
        mascara = mascara_de_trazo((50, 50), {"radio": 4, "puntos": [[25, 25]]})
        self.assertTrue(mascara[25, 29])
        self.assertFalse(mascara[25, 31])


if __name__ == "__main__":
    unittest.main()
