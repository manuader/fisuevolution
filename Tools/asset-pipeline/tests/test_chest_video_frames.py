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


class LoIntegrado(unittest.TestCase):
    """Sobre `Resources/ChestAnim/` versionado, no sobre una corrida local."""

    @classmethod
    def setUpClass(cls):
        with open(CHEST_ANIM / "chest_anim.json", encoding="utf-8") as f:
            cls.manifest = json.load(f)

    def test_el_manifest_dice_lo_que_el_pipeline_genera(self):
        self.assertEqual(self.manifest["schemaVersion"], 2)
        # 36 y no 24: la velocidad 1,5x del dueño viaja en el manifest (los
        # PNG del dedo y el mov retimeado corren a la misma cadencia).
        self.assertEqual(self.manifest["fps"], 36)
        self.assertEqual(self.manifest["fps"], PLAYBACK_FPS)
        self.assertEqual(set(self.manifest["segments"]), set(SEGMENTS))
        for name, seg in SEGMENTS.items():
            entry = self.manifest["segments"][name]
            self.assertEqual((entry["first"], entry["last"]),
                             (seg["first"], seg["last"]), name)
        cine = self.manifest["cinematic"]
        self.assertEqual(cine["file"], CINEMATIC_FILE)
        self.assertEqual((cine["first"], cine["last"]),
                         (CINEMATIC_FIRST, CINEMATIC_LAST))
        still = self.manifest["cardStill"]
        self.assertEqual(still["file"], CARD_STILL_FILE)
        self.assertEqual(still["scale"], CARD_STILL_SCALE)

    def test_las_anclas_viven_dentro_del_lienzo(self):
        canvas = self.manifest["canvas"]
        for key, expected in (("chestRect", CHEST_RECT),
                              ("parchmentRect", PARCHMENT_RECT)):
            rect = self.manifest[key]
            self.assertEqual(rect, expected, key)
            self.assertLessEqual(rect["x"] + rect["w"], canvas["w"], key)
            self.assertLessEqual(rect["y"] + rect["h"], canvas["h"], key)

    def test_el_pergamino_vive_dentro_del_encuadre_del_cinematico(self):
        # El contenido del premio se renderiza sobre el video: si el crop del
        # cinematico no contiene el pergamino, el contenido flota en el vacio.
        crop = self.manifest["cinematic"]["crop"]
        parch = self.manifest["parchmentRect"]
        self.assertGreaterEqual(parch["x"], crop["x"])
        self.assertGreaterEqual(parch["y"], crop["y"])
        self.assertLessEqual(parch["x"] + parch["w"], crop["x"] + crop["w"])
        self.assertLessEqual(parch["y"] + parch["h"], crop["y"] + crop["h"])

    def test_cada_frame_interactivo_existe_con_su_tamano(self):
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
        self.assertLessEqual(total_kb, PRESUPUESTO_PNG_KB)

    def test_el_cinematico_es_hevc_hvc1_con_su_audio(self):
        path = CHEST_ANIM / CINEMATIC_FILE
        self.assertTrue(path.exists())
        self.assertLessEqual(path.stat().st_size // 1024, PRESUPUESTO_MOV_KB)
        if shutil.which("ffprobe") is None:
            self.skipTest("sin ffprobe en el PATH")
        probe = json.loads(subprocess.run(
            ["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(path)],
            capture_output=True, text=True, check=True,
        ).stdout)
        video = probe["streams"][0]
        self.assertEqual(video["codec_name"], "hevc")
        self.assertEqual(video["codec_tag_string"], "hvc1")
        # El retime a 1,5x NO sintetiza ni tira frames: los 190 cuadros del
        # master, exactos, presentados a 36 fps. La duracion pina la
        # velocidad — un mov sin retimear duraria 7,92 s y esto lo caza.
        frames_del_tramo = CINEMATIC_LAST - CINEMATIC_FIRST + 1
        self.assertEqual(int(video["nb_frames"]), frames_del_tramo)
        expected_dur = frames_del_tramo / PLAYBACK_FPS
        self.assertAlmostEqual(
            float(video["duration"]), expected_dur, delta=0.06
        )
        # La pista de sonido del tramo viaja adentro del mov: sin ella el
        # cinematico corre mudo y nadie lo nota hasta el playtest. Y viaja
        # COMPRIMIDA por el mismo atempo — un audio a 7,9 s contra un video
        # de 5,3 s es el atempo olvidado.
        self.assertEqual(len(probe["streams"]), 2)
        self.assertEqual(probe["streams"][1]["codec_type"], "audio")
        self.assertEqual(probe["streams"][1]["codec_name"], "aac")
        self.assertAlmostEqual(
            float(probe["streams"][1]["duration"]), expected_dur, delta=0.15
        )

    def test_los_clips_de_sacudida_calzan_sus_frames(self):
        for name, (_, first, last) in SHAKE_SFX.items():
            path = AUDIO_DIR / f"{name}.caf"
            self.assertTrue(path.exists(), name)
            # PCM s16 estereo a 48 kHz: 192 KB/s + cabecera caf. La ventana
            # se mide en frames del MASTER (24) y el atempo la comprime.
            expected_kb = (last - first) / 24 * 192 / CINEMATIC_SPEED
            self.assertAlmostEqual(
                path.stat().st_size / 1024, expected_kb, delta=expected_kb * 0.2
            )

    def test_el_still_del_marco_tiene_el_tamano_del_encuadre(self):
        crop = self.manifest["cardStill"]["crop"]
        expected = (round(crop["w"] * CARD_STILL_SCALE),
                    round(crop["h"] * CARD_STILL_SCALE))
        with Image.open(CHEST_ANIM / CARD_STILL_FILE) as img:
            self.assertEqual(img.size, expected)
            self.assertEqual(img.mode, "P")

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
