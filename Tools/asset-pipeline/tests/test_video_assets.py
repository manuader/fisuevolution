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


class MedicionDelFondo(unittest.TestCase):
    def test_un_verde_liso_con_ruido_de_compresion_da_su_hex(self):
        parches = [parche((34, 146, 74), ruido=2) for _ in range(12)]
        medido = rgb(key_color_from_patches(parches))
        self.assertLessEqual(np.abs(medido - (34, 146, 74)).max(), 1)

    def test_una_esquina_tapada_se_rechaza_en_vez_de_adivinar(self):
        parches = [parche((34, 146, 74)) for _ in range(11)] + [parche((200, 60, 40))]
        with self.assertRaises(MasterError):
            key_color_from_patches(parches)

    def test_un_fondo_que_no_es_ni_verde_ni_magenta_se_rechaza(self):
        with self.assertRaises(MasterError):
            key_color_from_patches([parche((40, 60, 200)) for _ in range(12)])

    @unittest.skipUnless(TIENE_FFMPEG, "sin ffmpeg/ffprobe en el PATH")
    def test_un_magenta_liso_da_su_hex(self):
        parches = [parche((253, 4, 252), ruido=2) for _ in range(6)]
        medido = rgb(key_color_from_patches(parches))
        self.assertLessEqual(np.abs(medido - (253, 4, 252)).max(), 1)
        self.assertEqual(video_assets.key_family("0xFD04FC"), "magenta")

    def test_la_familia_del_key_sale_del_color(self):
        self.assertEqual(video_assets.key_family("0x22924A"), "green")
        self.assertIsNone(video_assets.key_family("0x283CC8"))

    def test_el_magenta_va_sin_despill_y_el_verde_con(self):
        self.assertIn("despill=type=green", video_assets.keying("0x22924A", 0.11, 0.04))
        self.assertNotIn("despill", video_assets.keying("0xFD04FC", 0.11, 0.04))

    def test_cada_clase_mide_sus_esquinas(self):
        self.assertEqual(video_assets.CORNER_ROWS["retrato"], ("top",))
        self.assertEqual(video_assets.CORNER_ROWS["cinematica"], ("top", "bottom"))

    def test_el_master_del_cofre_mide_el_verde_que_se_calibro_a_mano(self):
        """El verde del cofre (`KEY_COLOR`) se saco a ojo leyendo un pixel. Medir
        el mismo master tiene que dar ese verde, o la medicion no sirve."""
        medido = rgb(video_assets.measure_key_color(VIDEO))
        self.assertLessEqual(np.abs(medido - rgb(KEY_COLOR)).max(), 3)


class FondoBlanco(unittest.TestCase):
    def test_el_blanco_se_reconoce_como_familia(self):
        self.assertEqual(video_assets.key_family("0xFEFEFE"), "white")
        medido = rgb(key_color_from_patches([parche((254, 254, 254), ruido=1)] * 6))
        self.assertGreaterEqual(medido.min(), 252)
        self.assertEqual(video_assets.key_family("0xE0E0E0"), None)


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

    def test_los_clips_del_ascensor_son_cinematicas_validas(self):
        for clip in ("ascensor_cierra", "ascensor_abre"):
            validate_id("cinematica", clip)


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
        self.assertEqual(
            set(self.manifest), {"schemaVersion", "portraits", "cinematics", "stills"}
        )

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

    # Los 18 de la tanda de Higgsfield (PLAN-v2 E8): 8 visitantes y los 10 especiales.
    # El gemelo en Swift es `LoopsManifestTests.portraits`.
    RETRATOS = {
        "npc_comisario", "npc_conductor", "npc_ministro", "npc_puntero",
        "npc_sindicalista", "npc_turista", "npc_vecina", "npc_vendedor",
        "sp_alien_investor", "sp_arbolito", "sp_bug_simulacion", "sp_coach",
        "sp_contador_dios", "sp_cryptobro", "sp_demonio_arca", "sp_influencer",
        "sp_lizard", "sp_zombie_ceo",
    }

    def test_estan_los_18_retratos(self):
        self.assertEqual(set(self.manifest["portraits"]), self.RETRATOS)

    def test_las_tres_cinematicas_son_opacas_y_suenan(self):
        # Subconjunto y no igualdad: P-E13b suma las puertas de la cabina a esta sección.
        for piece_id in CINEMATIC_IDS:
            with self.subTest(id=piece_id):
                entry = self.manifest["cinematics"][piece_id]
                self.assertFalse(entry["alpha"], "la escena trae su propio fondo: --sin-key")
                self.assertTrue(entry["audio"], "Seedance la entregó con sonido")

    def test_cada_cuadro_fijo_apunta_a_su_png_con_su_tamano(self):
        for still_id, entry in self.manifest["stills"].items():
            with self.subTest(id=still_id):
                self.assertIn(still_id, video_assets.ELEVATOR_STILLS)
                self.assertEqual(set(entry), {"file", "width", "height", "keyColor"})
                self.assertEqual(entry["file"], f"cine_{still_id}.png")
                self.assertEqual((entry["width"], entry["height"]), KINDS["cinematica"]["size"])
                self.assertTrue((RESOURCES / "Cinematics" / entry["file"]).exists())

    def test_no_hay_piezas_huerfanas(self):
        for spec in KINDS.values():
            carpeta = RESOURCES / spec["dir"]
            en_disco = {p.name for p in carpeta.glob("*.mov")} if carpeta.exists() else set()
            declaradas = {e["file"] for e in self.manifest[spec["section"]].values()}
            self.assertEqual(en_disco, declaradas, spec["dir"])
        carpeta = RESOURCES / "Cinematics"
        en_disco = {p.name for p in carpeta.glob("*.png")} if carpeta.exists() else set()
        declaradas = {e["file"] for e in self.manifest["stills"].values()}
        self.assertEqual(en_disco, declaradas, "Cinematics (cuadros fijos)")


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

    def master(self, width: int, height: int, fondo: str = VERDE,
               personaje: str = "0xC83C28", hombros: bool = False) -> Path:
        path = self.root / f"master_{width}x{height}_{fondo}_{hombros}.mp4"
        cajas = [f"drawbox=x={width // 3}:y={height // 4}:w={width // 3}:h={height // 2}"
                 f":color={personaje}:t=fill"]
        if hombros:
            # Un busto: los hombros llegan a las dos esquinas de abajo.
            cajas.append(f"drawbox=x=0:y={height - height // 6}:w={width}:h={height // 6}"
                         f":color={personaje}:t=fill")
        subprocess.run(
            ["ffmpeg", "-v", "error",
             "-f", "lavfi", "-i", f"color=c={fondo}:s={width}x{height}:r=24:d=1",
             "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
             "-vf", ",".join(cajas),
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

    def master_blanco(self, side: int = 640) -> Path:
        path = self.root / "master_blanco.mp4"
        c, r = side // 2, side // 8
        subprocess.run(
            ["ffmpeg", "-v", "error",
             "-f", "lavfi", "-i", f"color=c=white:s={side}x{side}:r=24:d=1",
             "-vf", (f"drawbox=x={side // 4}:y={side // 4}:w={side // 2}:h={side // 2}:color=0xC83C28:t=fill,"
                     f"drawbox=x={c - r}:y={c - r}:w={2 * r}:h={2 * r}:color=black:t=fill,"
                     f"drawbox=x={c - r + 6}:y={c - r + 6}:w={2 * r - 12}:h={2 * r - 12}:color=white:t=fill"),
             "-c:v", "libx264", "-pix_fmt", "yuv420p", "-an", "-y", str(path)],
            check=True,
        )
        return path

    def test_un_retrato_sobre_blanco_recorta_el_fondo_y_no_el_ojo(self):
        entry = video_assets.process("retrato", "npc_prueba", self.master_blanco())
        self.assertEqual(video_assets.key_family(entry["keyColor"]), "white")
        self.assertTrue(entry["alpha"])
        self.assertEqual((entry["frames"], entry["fps"]), (24, 24))
        frame = self.cuadro(self.resources / "Loops" / "loop_npc_prueba.mov")
        self.assertLessEqual(frame[4, 4, :3].max(), 8, "el fondo blanco se fue (premultiplicado)")
        self.assertGreater(frame[256, 256, :3].min(), 230, "el blanco encerrado es dibujo y queda")
        if alfa_decodificable():
            self.assertEqual(frame[4, 4, 3], 0)
            self.assertEqual(frame[256, 256, 3], 255)

    def test_una_cinematica_sobre_blanco_se_rechaza(self):
        with self.assertRaises(MasterError):
            video_assets.process("cinematica", "dios", self.master_blanco())

    def test_un_busto_se_mide_por_arriba_y_sale(self):
        master = self.master(640, 640, hombros=True)
        with self.assertRaises(MasterError, msg="con las cuatro esquinas, los hombros lo tapan"):
            video_assets.measure_key_color(master, rows=("top", "bottom"))
        entry = video_assets.process("retrato", "npc_prueba", master)
        self.assertLessEqual(np.abs(rgb(entry["keyColor"]) - rgb(self.VERDE)).max(), 4)

    def test_un_retrato_verde_sobre_magenta_conserva_su_verde(self):
        master = self.master(640, 640, fondo="0xFF00FF", personaje="0x2CA02C")
        entry = video_assets.process("retrato", "sp_prueba", master)
        self.assertEqual(video_assets.key_family(entry["keyColor"]), "magenta")
        frame = self.cuadro(self.resources / "Loops" / "loop_sp_prueba.mov")
        h, w = frame.shape[:2]
        self.assertLessEqual(frame[4, 4, :3].max(), 8, "el fondo magenta se fue")
        self.assertGreater(frame[h // 2, w // 2, 1], 120, "y el personaje sigue verde")

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

    # --- El ascensor: las esquinas son la cabina, el verde esta en el hueco ---

    HUECO = "0x04F523"
    VENTANA = "0x03FA0E"

    def master_de_puertas(self, width=360, height=640, abierto_primero=True) -> Path:
        """73 cuadros a 24 fps (como los masters de Higgsfield): la cabina gris
        en todos lados, el hueco verde en un cuadro y las dos ventanas en el otro."""
        w, h = width, height
        hueco = f"drawbox=x={int(w * .2)}:y={int(h * .2)}:w={int(w * .6)}:h={int(h * .6)}:color={self.HUECO}:t=fill"
        ventanas = ",".join(
            f"drawbox=x={int(w * x)}:y={int(h * .25)}:w={int(w * .12)}:h={int(h * .4)}:color={self.VENTANA}:t=fill"
            for x in (.28, .60)
        )
        abierto, cerrado = (hueco, ventanas) if abierto_primero else (ventanas, hueco)
        path = self.root / f"puertas_{abierto_primero}.mp4"
        gris = f"color=c=0x808080:s={w}x{h}:r=24:d=1.5"
        subprocess.run(
            ["ffmpeg", "-v", "error", "-f", "lavfi", "-i", gris, "-f", "lavfi", "-i", gris,
             "-filter_complex",
             f"[0]{abierto}[a];[1]{cerrado}[b];[a][b]concat=n=2:v=1:a=0,trim=end_frame=73",
             "-c:v", "libx264", "-pix_fmt", "yuv420p", "-y", str(path)],
            check=True,
        )
        return path

    def cuadros(self, mov: Path) -> np.ndarray:
        info = video_assets.video_stream(video_assets.probe(mov))
        raw = subprocess.run(
            ["ffmpeg", "-v", "error", "-i", str(mov), "-pix_fmt", "rgba",
             "-f", "rawvideo", "-"], capture_output=True, check=True,
        ).stdout
        return np.frombuffer(raw, np.uint8).reshape(-1, info["height"], info["width"], 4).astype(int)

    def test_el_ascensor_mide_el_verde_en_el_hueco(self):
        master = self.master_de_puertas()
        with self.assertRaises(MasterError):
            video_assets.measure_key_color(master)
        medido = rgb(video_assets.measure_key_in_regions(
            master, "first", video_assets.HOLE_POINTS, video_assets.WINDOW_POINTS))
        self.assertLessEqual(np.abs(medido - rgb(self.HUECO)).max(), 4)

    def test_los_dos_verdes_del_ascensor_se_keyean(self):
        entry = video_assets.process_ascensor("ascensor_cierra", self.master_de_puertas())

        cuadros = self.cuadros(self.resources / "Cinematics" / "cine_ascensor_cierra.mov")
        abierto, cerrado = cuadros[0], cuadros[-1]
        h, w = abierto.shape[:2]
        self.assertLessEqual(np.abs(rgb(entry["keyColor"]) - rgb(self.HUECO)).max(), 4)
        if not alfa_decodificable():
            self.skipTest("este ffmpeg no decodifica el alfa del HEVC de Apple")
        self.assertEqual(abierto[h // 2, w // 2, 3], 0, "el hueco")
        self.assertEqual(abierto[10, 10, 3], 255, "la cabina")
        for fx in (.34, .66):
            self.assertEqual(cerrado[int(h * .45), int(w * fx), 3], 0, f"la ventana en {fx}")
        self.assertEqual(cerrado[h // 2, w // 2, 3], 255, "la puerta entre las ventanas")

    def test_el_ascensor_se_recorta_y_acelera(self):
        for clip, segundos in (("ascensor_cierra", .75), ("ascensor_abre", .65)):
            with self.subTest(clip=clip):
                abierto = video_assets.ELEVATOR_CLIPS[clip][0] == "first"
                entry = video_assets.process_ascensor(clip, self.master_de_puertas(abierto_primero=abierto))

                mov = self.resources / "Cinematics" / f"cine_{clip}.mov"
                info = video_assets.probe(mov)
                video = video_assets.video_stream(info)
                self.assertLessEqual(abs(entry["frames"] - segundos * 30), 1)
                self.assertEqual(entry["fps"], 30)
                self.assertEqual((video["width"], video["height"]), (720, 1280))
                self.assertFalse(video_assets.has_audio(info))
                self.assertTrue(entry["alpha"])
                manifest = json.loads((self.resources / "Data" / "loops_manifest.json").read_text())
                self.assertEqual(manifest["cinematics"][clip], entry)

    def test_los_cuadros_del_ascensor_salen_keyeados_y_registrados(self):
        w, h = 1520, 2688
        fuente = self.root / "cuadros"
        fuente.mkdir()
        cajas = {
            "cabina_abierta.png": [(.2, .2, .6, .6, self.HUECO), (.02, .02, .1, .1, "0xFFC02B")],
            "cabina_cerrada.png": [(.28, .25, .12, .4, self.VENTANA), (.60, .25, .12, .4, self.VENTANA)],
        }
        for archivo, rectangulos in cajas.items():
            filtro = ",".join(
                f"drawbox=x={int(w * x)}:y={int(h * y)}:w={int(w * ancho)}:h={int(h * alto)}:color={c}:t=fill"
                for x, y, ancho, alto, c in rectangulos
            )
            subprocess.run(
                ["ffmpeg", "-v", "error", "-f", "lavfi", "-i", f"color=c=0x808080:s={w}x{h}",
                 "-vf", filtro, "-frames:v", "1", "-y", str(fuente / archivo)], check=True)

        entries = video_assets.process_ascensor_stills(fuente)

        manifest = json.loads((self.resources / "Data" / "loops_manifest.json").read_text())
        self.assertEqual(manifest["stills"], entries)
        self.assertEqual(set(entries), {"ascensor_cerrada", "ascensor_abierta"})
        for still_id, hueco in (("ascensor_abierta", (.5, .5)), ("ascensor_cerrada", (.34, .45))):
            with self.subTest(still_id=still_id):
                entry = entries[still_id]
                self.assertEqual(entry["file"], f"cine_{still_id}.png")
                with Image.open(self.resources / "Cinematics" / entry["file"]) as img:
                    self.assertEqual((img.mode, img.size), ("RGBA", (720, 1280)))
                    pixels = np.asarray(img).astype(int)
                self.assertEqual(pixels[int(1280 * hueco[1]), int(720 * hueco[0]), 3], 0)
                self.assertEqual(pixels[10, 10, 3], 255)
        # El amarillo de la cabina sobrevive: sin despill no vira a naranja.
        with Image.open(self.resources / "Cinematics" / "cine_ascensor_abierta.png") as img:
            amarillo = np.asarray(img).astype(int)[1280 // 20, 720 // 20]
        self.assertGreater(amarillo[1], 170, f"el amarillo viro: {amarillo}")


if __name__ == "__main__":
    unittest.main()
