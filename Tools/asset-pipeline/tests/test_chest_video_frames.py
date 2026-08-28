"""El contrato de `ChestAnim/` visto desde el pipeline.

La mitad de la prueba es geometria pura; la otra mitad mira lo que quedo
INTEGRADO en `Resources/ChestAnim/` — el manifest, los frames y el estatico —
porque el bug tipico de un pipeline de assets no se ve en el codigo: se ve en
el PNG que se compila. `ChestAnimationTests` (Swift) pina el mismo contrato
desde el runtime.
"""

import json
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from chest_video_frames import (  # noqa: E402
    CHEST_ANIM,
    CHEST_RECT,
    SEGMENTS,
    STATIC_OCCUPANCY,
    UI_ATLAS,
    cut_mass_fraction,
    clean_transparent_rgb,
    static_canvas_side,
)

# El presupuesto declarado en el spec: si el directorio engorda por encima de
# esto, la decision de peso se tiene que volver a tomar, no colar.
PRESUPUESTO_KB = 4096


class GeometriaPura(unittest.TestCase):
    def test_el_lienzo_del_estatico_calza_la_ocupacion_del_viejo(self):
        # 407 px de cofre al 84,4 % del ancho -> lienzo de 482.
        self.assertEqual(static_canvas_side(407), 482)

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


class LoIntegrado(unittest.TestCase):
    """Sobre `Resources/ChestAnim/` versionado, no sobre una corrida local."""

    @classmethod
    def setUpClass(cls):
        with open(CHEST_ANIM / "chest_anim.json", encoding="utf-8") as f:
            cls.manifest = json.load(f)

    def test_el_manifest_dice_lo_que_el_pipeline_genera(self):
        self.assertEqual(self.manifest["schemaVersion"], 1)
        self.assertEqual(self.manifest["fps"], 24)
        self.assertEqual(set(self.manifest["segments"]), set(SEGMENTS))
        for name, seg in SEGMENTS.items():
            entry = self.manifest["segments"][name]
            self.assertEqual((entry["first"], entry["last"]),
                             (seg["first"], seg["last"]), name)

    def test_el_ancla_del_cofre_vive_dentro_del_lienzo(self):
        canvas = self.manifest["canvas"]
        rect = self.manifest["chestRect"]
        self.assertEqual(rect, CHEST_RECT)
        self.assertLessEqual(rect["x"] + rect["w"], canvas["w"])
        self.assertLessEqual(rect["y"] + rect["h"], canvas["h"])

    def test_cada_frame_referenciado_existe_con_su_tamano(self):
        for name, entry in self.manifest["segments"].items():
            crop, scale = entry["crop"], entry["scale"]
            expected = (round(crop["w"] * scale), round(crop["h"] * scale))
            for n in range(entry["first"], entry["last"] + 1):
                path = CHEST_ANIM / f"chest_f{n:03d}.png"
                self.assertTrue(path.exists(), f"{name}: falta {path.name}")
                with Image.open(path) as img:
                    self.assertEqual(img.size, expected, path.name)
                    # Cuantizado: si un dia vuelve RGBA plano, el peso se
                    # triplica en silencio.
                    self.assertEqual(img.mode, "P", path.name)

    def test_no_hay_frames_huerfanos_y_el_peso_respeta_el_presupuesto(self):
        referenced = {
            f"chest_f{n:03d}.png"
            for entry in self.manifest["segments"].values()
            for n in range(entry["first"], entry["last"] + 1)
        }
        on_disk = {p.name for p in CHEST_ANIM.glob("chest_f*.png")}
        self.assertEqual(on_disk, referenced)
        total_kb = sum(
            (CHEST_ANIM / name).stat().st_size for name in on_disk
        ) // 1024
        self.assertLessEqual(total_kb, PRESUPUESTO_KB)

    def test_el_estatico_nuevo_calza_la_ocupacion_del_viejo(self):
        for suffix, side in (("@3x", 384), ("@2x", 256)):
            path = UI_ATLAS / f"ui_chest_closed{suffix}.png"
            with Image.open(path) as img:
                self.assertEqual(img.size, (side, side), suffix)
                alpha = np.asarray(img.convert("RGBA").getchannel("A"))
            xs = np.where(alpha.max(axis=0) >= 24)[0]
            occupancy = (xs.max() - xs.min() + 1) / alpha.shape[1]
            self.assertAlmostEqual(occupancy, STATIC_OCCUPANCY, delta=0.02)


if __name__ == "__main__":
    unittest.main()
