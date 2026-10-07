"""El contrato de los loops y las cinematicas (`loops_manifest.json`) visto desde
el pipeline.

Tres partes: la medicion del verde (sin video y contra el master del cofre, cuyo
verde se calibro a mano), el manifest versionado con lo que quedo INTEGRADO, y
una corrida de punta a punta sobre un master sintetico que el test arma con
ffmpeg, porque todavia no hay masters de Higgsfield. Del lado del juego lo pinea
un test en Swift.
"""

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import numpy as np
from PIL import Image

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import video_assets  # noqa: E402
from chest_video_frames import CHEST_ANIM, CINEMATIC_FILE, KEY_COLOR, VIDEO  # noqa: E402
from video_assets import (  # noqa: E402
    CINEMATIC_IDS,
    KINDS,
    MANIFEST,
    RESOURCES,
    MasterError,
    key_color_from_patches,
    validate_id,
)

TIENE_FFMPEG = shutil.which("ffmpeg") is not None and shutil.which("ffprobe") is not None


def encoders() -> str:
    if not TIENE_FFMPEG:
        return ""
    return subprocess.run(
        ["ffmpeg", "-hide_banner", "-encoders"], capture_output=True, text=True
    ).stdout


PUEDE_CODIFICAR = all(e in encoders() for e in ("hevc_videotoolbox", "libx264"))


def rgb(hex_color: str) -> np.ndarray:
    return np.array([int(hex_color[i:i + 2], 16) for i in (2, 4, 6)])


def parche(color, ruido=0):
    rng = np.random.default_rng(7)
    base = np.full((8, 8, 3), color, dtype=np.int16)
    return np.clip(base + rng.integers(-ruido, ruido + 1, base.shape), 0, 255).astype(np.uint8)


class MedicionDelVerde(unittest.TestCase):
    def test_un_verde_liso_con_ruido_de_compresion_da_su_hex(self):
        parches = [parche((34, 146, 74), ruido=2) for _ in range(12)]
        medido = rgb(key_color_from_patches(parches))
        self.assertLessEqual(np.abs(medido - (34, 146, 74)).max(), 1)

    def test_una_esquina_tapada_se_rechaza_en_vez_de_adivinar(self):
        parches = [parche((34, 146, 74)) for _ in range(11)] + [parche((200, 60, 40))]
        with self.assertRaises(MasterError):
            key_color_from_patches(parches)

    def test_un_fondo_que_no_es_verde_se_rechaza(self):
        with self.assertRaises(MasterError):
            key_color_from_patches([parche((40, 60, 200)) for _ in range(12)])

    @unittest.skipUnless(TIENE_FFMPEG, "sin ffmpeg/ffprobe en el PATH")
    def test_el_master_del_cofre_mide_el_verde_que_se_calibro_a_mano(self):
        """El verde del cofre (`KEY_COLOR`) se saco a ojo leyendo un pixel. Medir
        el mismo master tiene que dar ese verde, o la medicion no sirve."""
        medido = rgb(video_assets.measure_key_color(VIDEO))
        self.assertLessEqual(np.abs(medido - rgb(KEY_COLOR)).max(), 3)


class Identificadores(unittest.TestCase):
    def test_un_retrato_es_la_canonica_de_un_visitante(self):
        for valido in ("npc_comisario", "sp_demonio_arca", "sp_cryptobro"):
            validate_id("retrato", valido)
        for invalido in ("npc_comisario_talk", "sp_lizard_face", "comisario", "npc_Comisario"):
            with self.subTest(invalido=invalido), self.assertRaises(ValueError):
                validate_id("retrato", invalido)

    def test_las_cinematicas_son_las_tres_del_plan(self):
        self.assertEqual(CINEMATIC_IDS, ("reencarnacion", "arresto", "dios"))
        with self.assertRaises(ValueError):
            validate_id("cinematica", "boda")


class ManifestVersionado(unittest.TestCase):
    """Sobre `Resources/Data/loops_manifest.json` versionado, no sobre una corrida
    local: el bug de un pipeline de assets se ve en el archivo que se compila."""

    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))

    def test_la_forma_del_contrato(self):
        # El literal al lado de la constante, como en el cofre: el schema tiene un
        # gemelo en Swift que no se entera si cambia solo de este lado.
        self.assertEqual(self.manifest["schemaVersion"], 1)
        self.assertEqual(self.manifest["schemaVersion"], video_assets.SCHEMA_VERSION)
        self.assertEqual(set(self.manifest), {"schemaVersion", "portraits", "cinematics"})

    def test_cada_entrada_apunta_a_su_pieza_con_su_tamano(self):
        campos = {"file", "width", "height", "fps", "frames", "alpha", "audio", "keyColor"}
        for kind, spec in KINDS.items():
            for piece_id, entry in self.manifest[spec["section"]].items():
                with self.subTest(kind=kind, id=piece_id):
                    validate_id(kind, piece_id)
                    self.assertEqual(set(entry), campos)
                    self.assertEqual(entry["file"], f"{spec['prefix']}{piece_id}.mov")
                    self.assertEqual((entry["width"], entry["height"]), spec["size"])
                    self.assertTrue((RESOURCES / spec["dir"] / entry["file"]).exists())
                    self.assertEqual(entry["alpha"], entry["keyColor"] is not None)
                    if kind == "retrato":
                        self.assertTrue(entry["alpha"], "un retrato va siempre con alfa")
                        self.assertFalse(entry["audio"], "un loop de retrato es mudo")

    def test_no_hay_piezas_huerfanas(self):
        for spec in KINDS.values():
            carpeta = RESOURCES / spec["dir"]
            en_disco = {p.name for p in carpeta.glob("*.mov")} if carpeta.exists() else set()
            declaradas = {e["file"] for e in self.manifest[spec["section"]].values()}
            self.assertEqual(en_disco, declaradas, spec["dir"])


def alfa_decodificable() -> bool:
    """¿Este ffmpeg ve la capa alfa del HEVC de Apple? Se pregunta al mov del
    cofre, que la tiene: ffprobe dice yuv420p igual (trampa del cofre), y un
    ffmpeg viejo decodifica todo opaco."""
    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / "f.png"
        subprocess.run(
            ["ffmpeg", "-v", "error", "-i", str(CHEST_ANIM / CINEMATIC_FILE),
             "-frames:v", "1", "-pix_fmt", "rgba", str(png)],
            check=True,
        )
        with Image.open(png) as img:
            return np.asarray(img)[..., 3].min() < 255


@unittest.skipUnless(PUEDE_CODIFICAR, "sin ffmpeg con hevc_videotoolbox y libx264")
class DePuntaAPunta(unittest.TestCase):
    """Un master sintetico: fondo verde del cofre, un rectangulo rojo en el medio
    (el "personaje") y un tono de fondo como pista de sonido."""

    VERDE = "0x22924A"

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.resources = self.root / "Resources"
        for name, value in (
            ("RESOURCES", self.resources),
            ("MANIFEST", self.resources / "Data" / "loops_manifest.json"),
        ):
            patcher = mock.patch.object(video_assets, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def master(self, width: int, height: int) -> Path:
        path = self.root / f"master_{width}x{height}.mp4"
        subprocess.run(
            ["ffmpeg", "-v", "error",
             "-f", "lavfi", "-i", f"color=c={self.VERDE}:s={width}x{height}:r=24:d=1",
             "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
             "-vf", f"drawbox=x={width // 3}:y={height // 4}:w={width // 3}:h={height // 2}"
                    ":color=0xC83C28:t=fill",
             "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest",
             "-y", str(path)],
            check=True,
        )
        return path

    def cuadro(self, mov: Path) -> np.ndarray:
        png = self.root / f"{mov.stem}.png"
        subprocess.run(
            ["ffmpeg", "-v", "error", "-i", str(mov), "-frames:v", "1",
             "-pix_fmt", "rgba", "-y", str(png)],
            check=True,
        )
        with Image.open(png) as img:
            return np.asarray(img).astype(int)

    def assert_keyeado(self, frame: np.ndarray) -> None:
        h, w = frame.shape[:2]
        esquina, centro = frame[4, 4], frame[h // 2, w // 2]
        # Premultiplicado: donde el alfa es cero el color tambien.
        self.assertLessEqual(esquina[:3].max(), 8, f"esquina {esquina}")
        self.assertGreater(centro[0], 150, f"centro {centro}")
        if alfa_decodificable():
            self.assertEqual(esquina[3], 0)
            self.assertEqual(centro[3], 255)

    def test_un_retrato_sale_cuadrado_con_alfa_mudo_y_registrado(self):
        # 640x480 a proposito: el retrato se recorta al cuadrado del centro.
        entry = video_assets.process("retrato", "npc_prueba", self.master(640, 480))

        mov = self.resources / "Loops" / "loop_npc_prueba.mov"
        info = video_assets.probe(mov)
        video = video_assets.video_stream(info)
        self.assertEqual((video["codec_name"], video["codec_tag_string"]), ("hevc", "hvc1"))
        self.assertEqual((video["width"], video["height"]), (512, 512))
        self.assertFalse(video_assets.has_audio(info))
        self.assert_keyeado(self.cuadro(mov))

        self.assertLessEqual(np.abs(rgb(entry["keyColor"]) - rgb(self.VERDE)).max(), 4)
        self.assertEqual(entry["frames"], 24)
        self.assertEqual(entry["fps"], 24)
        manifest = json.loads((self.resources / "Data" / "loops_manifest.json").read_text())
        self.assertEqual(manifest["portraits"], {"npc_prueba": entry})
        self.assertEqual(manifest["cinematics"], {})

    def test_una_cinematica_cubre_el_vertical_y_lleva_el_sonido(self):
        entry = video_assets.process("cinematica", "arresto", self.master(480, 640))

        mov = self.resources / "Cinematics" / "cine_arresto.mov"
        self.assertEqual((entry["width"], entry["height"]), (720, 1280))
        self.assertTrue(entry["alpha"])
        self.assertTrue(entry["audio"])
        self.assert_keyeado(self.cuadro(mov))

    def test_una_cinematica_sin_key_sale_opaca(self):
        entry = video_assets.process("cinematica", "dios", self.master(480, 640), keyed=False)

        self.assertEqual((entry["alpha"], entry["keyColor"]), (False, None))
        frame = self.cuadro(self.resources / "Cinematics" / "cine_dios.mov")
        self.assertEqual(frame[..., 3].min(), 255)
        self.assertGreater(frame[4, 4, 1], 100, "el verde queda: no se keyeo")


if __name__ == "__main__":
    unittest.main()
