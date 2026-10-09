"""El contrato de los loops y las cinematicas (`loops_manifest.json`) visto desde
el pipeline.

Cuatro partes: la medicion del verde (sin video y contra el master del cofre,
cuyo verde se calibro a mano), el recorte de fondo blanco de un cuadro, el
manifest versionado con lo que quedo INTEGRADO, y una corrida de punta a punta
sobre masters sinteticos que el test arma con ffmpeg (los de Higgsfield no se
versionan). Del lado del juego lo pinea un test en Swift.
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
from PIL import ImageDraw  # noqa: E402
from video_assets import (  # noqa: E402
    BUSTO,
    CABIN_IDS,
    CABIN_STILLS,
    CINEMATIC_IDS,
    EVENT_IDS,
    FLOOR_IDS,
    ICON_IDS,
    KINDS,
    MANIFEST,
    OBJECT_IDS,
    RESOURCES,
    SECTIONS,
    MasterError,
    cutout_frame,
    green_patches,
    key_color_from_patches,
    odr_tag,
    piece_dir,
    target,
    validate_id,
)
from whitebg_cutout import TODOS_LOS_BORDES  # noqa: E402

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

    def test_en_la_cabina_el_verde_se_mide_en_el_hueco_y_no_en_las_esquinas(self):
        # Pared crema en las esquinas, una ventana verde en el medio.
        cuadro = np.full((64, 36, 3), (240, 225, 180), np.uint8)
        cuadro[20:44, 10:26] = (4, 246, 30)
        parches = green_patches(np.stack([cuadro, cuadro]))
        medido = rgb(key_color_from_patches(parches))
        self.assertLessEqual(np.abs(medido - (4, 246, 30)).max(), 1)

    def test_una_cabina_sin_verde_se_rechaza(self):
        pared = np.full((1, 64, 36, 3), (240, 225, 180), np.uint8)
        with self.assertRaises(MasterError):
            green_patches(pared)

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

    def test_las_cinematicas_son_las_cuatro_del_plan(self):
        self.assertEqual(CINEMATIC_IDS, ("intro", "reencarnacion", "arresto", "dios"))
        with self.assertRaises(ValueError):
            validate_id("cinematica", "boda")

    def test_los_objetos_y_la_cabina_son_los_del_plan(self):
        self.assertEqual(
            OBJECT_IDS, ("paquete_abre", "paquete_espera", "colchon_abre", "colchon_espera")
        )
        self.assertEqual(CABIN_IDS, ("puertas_cierran", "puertas_abren"))
        for kind, invalido in (("objeto", "cofre_abre"), ("cabina", "puertas")):
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                validate_id(kind, invalido)

    def test_un_personaje_es_un_asset_key_sin_version(self):
        for valido in ("god", "senior_doctor", "sp_contador_dios", "sp_influencer"):
            validate_id("personaje", valido)
        for invalido in ("sp_influencer_v2", "God", "senior-doctor"):
            with self.subTest(invalido=invalido), self.assertRaises(ValueError):
                validate_id("personaje", invalido)

    def test_un_visitante_es_una_pose(self):
        for valido in ("npc_vecina_talk", "npc_comisario_action", "sp_contador_dios_talk"):
            validate_id("visitante", valido)
        for invalido in ("npc_vecina", "sp_lizard_action", "sp_influencer_talk_v2"):
            with self.subTest(invalido=invalido), self.assertRaises(ValueError):
                validate_id("visitante", invalido)

    def test_el_visitante_se_registra_por_el_id_del_retrato_en_la_seccion_de_su_pose(self):
        self.assertEqual(target("visitante", "npc_vecina_talk"), ("talking", "npc_vecina"))
        self.assertEqual(target("visitante", "npc_vecina_action"), ("visitorActions", "npc_vecina"))
        self.assertEqual(target("visitante", "sp_zombie_ceo_talk"), ("talking", "sp_zombie_ceo"))
        self.assertEqual(target("icono", "ui_oro_autotap"), ("shopIcons", "ui_oro_autotap"))

    def test_el_pack_odr_sale_de_la_clase_y_del_piso(self):
        self.assertEqual(odr_tag("personaje", "homeless"), "anim-piso-1")
        self.assertEqual(odr_tag("personaje", "god"), "anim-piso-10")
        self.assertEqual(odr_tag("personaje", "sp_lizard"), "anim-especiales")
        self.assertEqual(odr_tag("visitante", "npc_vecina_action"), "anim-visitantes")
        self.assertEqual(odr_tag("evento", "aguinaldo"), "anim-eventos")
        self.assertEqual(odr_tag("icono", "ui_oro_autotap"), "anim-tienda")
        for kind in ("retrato", "objeto", "cabina", "cinematica", "fondo"):
            self.assertIsNone(odr_tag(kind, "x"), kind)
        with self.assertRaises(ValueError):
            odr_tag("personaje", "sin_piso")

    def test_eventos_iconos_y_fondos_son_los_del_plan(self):
        self.assertEqual(len(EVENT_IDS), 8)
        self.assertEqual(len(ICON_IDS), 10)
        self.assertEqual(len(FLOOR_IDS), 10)
        for kind, invalido in (("evento", "boda"), ("icono", "ui_oro_nada"),
                               ("fondo", "bg_alley")):
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                validate_id(kind, invalido)

    def test_cada_clase_tiene_su_alfa(self):
        """Regla del dueno: el arte va sobre blanco; el verde, solo en la cabina
        (y en la cinematica, si alguna vez trae croma). El fondo es opaco."""
        self.assertEqual({k: s["matte"] for k, s in KINDS.items()}, {
            "retrato": "blanco", "objeto": "blanco", "cabina": "verde", "cinematica": "verde",
            "personaje": "blanco", "visitante": "blanco", "evento": "blanco",
            "icono": "blanco", "fondo": None,
        })
        self.assertEqual(KINDS["retrato"]["bordes"], BUSTO)
        for kind in ("objeto", "personaje", "visitante", "evento", "icono"):
            self.assertEqual(KINDS[kind]["bordes"], TODOS_LOS_BORDES, kind)
        # Comparten carpeta: lo que los separa en el bundle aplanado es el prefijo.
        prefijos = [s["prefix"] for s in KINDS.values()]
        self.assertEqual(len(prefijos), len(set(prefijos)))


def lienzo(alto: int = 240, ancho: int = 240):
    canvas = Image.new("RGB", (ancho, alto), (255, 255, 255))
    return canvas, ImageDraw.Draw(canvas)


class RecorteDeUnCuadro(unittest.TestCase):
    """`cutout_frame`: el criterio de `whitebg_cutout`, cuadro por cuadro."""

    def test_saca_el_fondo_y_conserva_lo_blanco_de_adentro(self):
        canvas, pen = lienzo()
        pen.ellipse((40, 40, 200, 200), fill=(255, 255, 255), outline=(0, 0, 0), width=6)
        rgba = cutout_frame(np.array(canvas), TODOS_LOS_BORDES).astype(int)

        self.assertEqual(rgba[5, 5].tolist(), [0, 0, 0, 0], "fondo: transparente y premultiplicado")
        self.assertEqual(rgba[120, 120].tolist(), [255, 255, 255, 255], "el blanco encerrado queda")

    def test_solo_cuenta_el_blanco_conectado_al_borde(self):
        # Dos blancos iguales: el de afuera toca el marco, el de adentro no.
        canvas, pen = lienzo()
        pen.rectangle((60, 60, 180, 180), outline=(0, 0, 0), width=4)
        alpha = cutout_frame(np.array(canvas), TODOS_LOS_BORDES)[..., 3]

        self.assertEqual(alpha[30, 120], 0)
        self.assertEqual(alpha[120, 120], 255)

    def test_un_retrato_no_se_come_la_camisa_apoyada_en_el_marco(self):
        canvas, pen = lienzo()
        pen.rectangle((70, 140, 170, 260), fill=(255, 255, 255), outline=(0, 0, 0), width=5)
        frame = np.array(canvas)

        self.assertEqual(cutout_frame(frame, BUSTO)[220, 120, 3], 255)
        self.assertEqual(cutout_frame(frame, BUSTO)[230, 10, 3], 0)
        self.assertEqual(cutout_frame(frame, TODOS_LOS_BORDES)[220, 120, 3], 0)

    def test_el_filo_sale_premultiplicado_y_sin_blanco(self):
        grande = Image.new("RGB", (960, 960), (255, 255, 255))
        ImageDraw.Draw(grande).ellipse((240, 240, 720, 720), fill=(200, 40, 40))
        frame = np.array(grande.resize((240, 240), Image.LANCZOS))
        rgba = cutout_frame(frame, TODOS_LOS_BORDES).astype(int)

        filo = (rgba[..., 3] > 10) & (rgba[..., 3] < 245)
        self.assertGreater(filo.sum(), 0)
        # Premultiplicado: ningun canal pasa al alfa. Un halo blanco lo violaria.
        self.assertLessEqual((rgba[..., :3].max(axis=2) - rgba[..., 3]).max(), 1)


class ManifestVersionado(unittest.TestCase):
    """Sobre `Resources/Data/loops_manifest.json` versionado, no sobre una corrida
    local: el bug de un pipeline de assets se ve en el archivo que se compila."""

    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))

    def piezas(self, kind):
        """(id del pipeline, entrada) de una clase; el visitante reparte sus poses
        entre `talking` y `visitorActions` con la clave del juego (`npc_vecina`)."""
        if kind != "visitante":
            return list(self.manifest[KINDS[kind]["section"]].items())
        spec = KINDS[kind]
        return [
            (f"{key}_{pose}", entry)
            for pose, section in (("talk", spec["section"]), ("action", spec["actions_section"]))
            for key, entry in self.manifest[section].items()
        ]

    def test_la_forma_del_contrato(self):
        # El literal al lado de la constante, como en el cofre: el schema tiene un
        # gemelo en Swift que no se entera si cambia solo de este lado.
        self.assertEqual(self.manifest["schemaVersion"], 1)
        self.assertEqual(self.manifest["schemaVersion"], video_assets.SCHEMA_VERSION)
        self.assertEqual(set(self.manifest), {
            "schemaVersion", "portraits", "objects", "cabin", "cinematics",
            "characters", "talking", "visitorActions", "events", "shopIcons", "floors",
        })
        self.assertEqual(list(self.manifest), ["schemaVersion", *SECTIONS])

    def test_cada_entrada_apunta_a_su_pieza_con_su_tamano(self):
        campos = {
            "file", "width", "height", "fps", "frames", "alpha", "audio", "matte", "keyColor",
        }
        for kind, spec in KINDS.items():
            for piece_id, entry in self.piezas(kind):
                with self.subTest(kind=kind, id=piece_id):
                    validate_id(kind, piece_id)
                    tag = odr_tag(kind, piece_id)
                    self.assertEqual(set(entry), campos | ({"odrTag"} if tag else set()))
                    self.assertEqual(entry.get("odrTag"), tag)
                    self.assertEqual(entry["file"], f"{spec['prefix']}{piece_id}.mov")
                    self.assertEqual((entry["width"], entry["height"]), spec["size"])
                    self.assertTrue((piece_dir(kind, piece_id) / entry["file"]).exists())
                    self.assertEqual(entry["alpha"], entry["matte"] is not None)
                    self.assertIn(entry["matte"], (spec["matte"], None))
                    self.assertEqual(entry["keyColor"] is not None, entry["matte"] == "verde")
                    if kind != "cinematica":
                        self.assertEqual(entry["matte"], spec["matte"])
                        self.assertFalse(entry["audio"], f"un {kind} es mudo")

    def test_las_piezas_del_plan_estan_todas(self):
        for kind, ids in (("objeto", OBJECT_IDS), ("cabina", CABIN_IDS),
                          ("cinematica", CINEMATIC_IDS), ("evento", EVENT_IDS),
                          ("icono", ICON_IDS), ("fondo", FLOOR_IDS)):
            with self.subTest(kind=kind):
                self.assertEqual(set(self.manifest[KINDS[kind]["section"]]), set(ids))
        self.assertEqual(len(self.manifest["portraits"]), 18)
        self.assertEqual(len(self.manifest["characters"]), 53)
        self.assertEqual(len(self.manifest["talking"]), 18)
        self.assertEqual(len(self.manifest["visitorActions"]), 8)
        # Cada visitante de la 2.0 tiene su _talk, y los npc ademas su _action;
        # el juego los pide por el id del retrato.
        for retrato in self.manifest["portraits"]:
            with self.subTest(retrato=retrato):
                self.assertIn(retrato, self.manifest["talking"])
                self.assertEqual(retrato in self.manifest["visitorActions"],
                                 retrato.startswith("npc_"))

    def test_cada_pieza_va_a_su_pack_y_lo_base_queda_en_el_paquete(self):
        # La tabla de E8d: personajes por piso, especiales, poses, eventos y tienda
        # viajan por ODR; retratos, objetos, cabina, cinematicas y fondos, no.
        por_seccion = {
            "portraits": None, "objects": None, "cabin": None, "cinematics": None,
            "floors": None, "talking": "anim-visitantes", "visitorActions": "anim-visitantes",
            "events": "anim-eventos", "shopIcons": "anim-tienda",
        }
        for seccion, tag in por_seccion.items():
            for piece_id, entry in self.manifest[seccion].items():
                with self.subTest(seccion=seccion, id=piece_id):
                    self.assertEqual(entry.get("odrTag"), tag)
        pisos = {}
        for piece_id, entry in self.manifest["characters"].items():
            with self.subTest(personaje=piece_id):
                esperado = "anim-especiales" if piece_id.startswith("sp_") else entry["odrTag"]
                self.assertEqual(entry["odrTag"], esperado)
                self.assertRegex(entry["odrTag"], r"anim-especiales|anim-piso-([1-9]|10)")
                pisos.setdefault(entry["odrTag"], []).append(piece_id)
        self.assertEqual(len(pisos["anim-especiales"]), 10)
        self.assertEqual(len(pisos) - 1, 10, "los diez pisos tienen su pack")
        self.assertIn("homeless", pisos["anim-piso-1"])
        self.assertIn("god", pisos["anim-piso-10"])

    def test_las_cinematicas_son_opacas_y_suenan(self):
        for piece_id, entry in self.manifest["cinematics"].items():
            with self.subTest(id=piece_id):
                self.assertFalse(entry["alpha"])
                self.assertTrue(entry["audio"])

    def test_no_hay_piezas_huerfanas(self):
        # Por carpeta y no por clase: retratos y objetos comparten `Loops/`.
        carpetas = {spec["dir"] for spec in KINDS.values()}
        packs = {f"AnimPacks/{p.name}" for p in (RESOURCES / "AnimPacks").iterdir()}
        for carpeta in carpetas | packs:
            en_disco = {p.name for p in (RESOURCES / carpeta).glob("*.mov")}
            declaradas = {
                entry["file"]
                for kind, spec in KINDS.items() if spec["dir"] == carpeta or carpeta in packs
                for piece_id, entry in self.piezas(kind)
                if piece_dir(kind, piece_id) == RESOURCES / carpeta
            }
            self.assertEqual(en_disco, declaradas, carpeta)

    def test_los_unicos_png_son_los_cuadros_fijos_de_la_cabina(self):
        # Sin entrada en el manifest: `ElevatorCabinArt` los pide por nombre.
        carpeta = RESOURCES / KINDS["cabina"]["dir"]
        self.assertEqual({p.name for p in carpeta.glob("*.png")}, set(CABIN_STILLS))


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
    """Masters sinteticos con un tono de fondo como pista de sonido: un rectangulo
    en el medio (el "personaje", o el hueco de la cabina) sobre un fondo liso."""

    VERDE = "0x22924A"
    CROMA = "0x04F61E"
    AMARILLO = "0xF5C518"

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
               caja: str = "0xC83C28", t: str = "fill") -> Path:
        """`t` es el grosor del borde de la caja: "fill" la pinta llena, un numero
        deja el adentro del color del fondo (el blanco encerrado del dibujo)."""
        path = self.root / f"master_{width}x{height}_{fondo}_{t}.mp4"
        subprocess.run(
            ["ffmpeg", "-v", "error",
             "-f", "lavfi", "-i", f"color=c={fondo}:s={width}x{height}:r=24:d=1",
             "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
             "-vf", f"drawbox=x={width // 3}:y={height // 4}:w={width // 3}:h={height // 2}"
                    f":color={caja}:t={t}",
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

    def assert_recortado(self, frame: np.ndarray) -> None:
        """Fondo blanco afuera, transparente; blanco encerrado adentro, opaco."""
        h, w = frame.shape[:2]
        esquina, centro = frame[4, 4], frame[h // 2, w // 2]
        self.assertLessEqual(esquina[:3].max(), 8, f"esquina {esquina}")
        self.assertGreater(centro[:3].min(), 230, f"centro {centro}")
        if alfa_decodificable():
            self.assertEqual(esquina[3], 0)
            self.assertEqual(centro[3], 255, "el blanco de adentro no se recorta")

    def test_un_retrato_sale_cuadrado_recortado_mudo_y_registrado(self):
        # 640x480 a proposito: el retrato se recorta al cuadrado del centro.
        master = self.master(640, 480, fondo="0xFFFFFF", caja="0x101010", t="8")
        entry = video_assets.process("retrato", "npc_prueba", master)

        mov = self.resources / "Loops" / "loop_npc_prueba.mov"
        info = video_assets.probe(mov)
        video = video_assets.video_stream(info)
        self.assertEqual((video["codec_name"], video["codec_tag_string"]), ("hevc", "hvc1"))
        self.assertEqual((video["width"], video["height"]), (512, 512))
        self.assertFalse(video_assets.has_audio(info))
        self.assert_recortado(self.cuadro(mov))

        self.assertEqual((entry["alpha"], entry["matte"], entry["keyColor"]),
                         (True, "blanco", None))
        self.assertEqual(entry["frames"], 24)
        self.assertEqual(entry["fps"], 24)
        manifest = json.loads((self.resources / "Data" / "loops_manifest.json").read_text())
        self.assertEqual(manifest["portraits"], {"npc_prueba": entry})
        self.assertEqual(manifest["cinematics"], {})

    def test_un_objeto_sale_recortado_en_su_seccion(self):
        master = self.master(720, 720, fondo="0xFFFFFF", caja="0x101010", t="8")
        entry = video_assets.process("objeto", "paquete_espera", master)

        mov = self.resources / "Loops" / "obj_paquete_espera.mov"
        self.assertEqual((entry["file"], entry["width"], entry["height"]),
                         (mov.name, 512, 512))
        self.assert_recortado(self.cuadro(mov))
        manifest = json.loads((self.resources / "Data" / "loops_manifest.json").read_text())
        self.assertEqual(manifest["objects"], {"paquete_espera": entry})
        self.assertEqual(manifest["portraits"], {})

    def test_la_cabina_deja_transparente_solo_el_hueco_verde(self):
        # Pared amarilla a proposito: el despill del cofre la volveria naranja.
        master = self.master(540, 956, fondo=self.AMARILLO, caja=self.CROMA)
        entry = video_assets.process("cabina", "puertas_abren", master)

        frame = self.cuadro(self.resources / "Cinematics" / "cabina_puertas_abren.mov")
        self.assertEqual((entry["width"], entry["height"]), (720, 1280))
        self.assertEqual(entry["matte"], "verde")
        self.assertFalse(entry["audio"], "la cabina es muda")
        self.assertLessEqual(np.abs(rgb(entry["keyColor"]) - rgb(self.CROMA)).max(), 4)
        esquina, hueco = frame[4, 4], frame[640, 360]
        self.assertLessEqual(np.abs(esquina[:3] - rgb(self.AMARILLO)).max(), 12,
                             f"la pared queda y del mismo amarillo: {esquina}")
        self.assertLessEqual(hueco[:3].max(), 8, f"hueco {hueco}")
        if alfa_decodificable():
            self.assertEqual((esquina[3], hueco[3]), (255, 0))

    def test_un_icono_sale_a_256_recortado(self):
        master = self.master(480, 480, fondo="0xFFFFFF", caja="0x101010", t="6")
        entry = video_assets.process("icono", "ui_oro_autotap", master)

        mov = self.resources / "AnimPacks" / "anim-tienda" / "icon_ui_oro_autotap.mov"
        self.assertEqual((entry["width"], entry["height"], entry["matte"]), (256, 256, "blanco"))
        self.assertEqual(entry["odrTag"], "anim-tienda")
        self.assert_recortado(self.cuadro(mov))

    def test_un_fondo_de_piso_sale_opaco_mudo_y_cuadrado(self):
        master = self.master(720, 720, fondo=self.AMARILLO)
        entry = video_assets.process("fondo", "alley", master)

        mov = self.resources / "Backgrounds" / "Loops" / "bgloop_alley.mov"
        self.assertEqual((entry["file"], entry["width"], entry["height"]),
                         (mov.name, 1024, 1024))
        self.assertEqual((entry["alpha"], entry["matte"], entry["audio"]), (False, None, False))
        frame = self.cuadro(mov)
        self.assertEqual(frame[..., 3].min(), 255)
        manifest = json.loads((self.resources / "Data" / "loops_manifest.json").read_text())
        self.assertEqual(manifest["floors"], {"alley": entry})

    def test_los_cuadros_fijos_de_la_cabina_salen_keyeados_y_sin_manifest(self):
        fuente = self.root / "ascensor"
        fuente.mkdir()
        for still, (x, y, ancho, alto) in zip(CABIN_STILLS, ((.28, .25, .12, .4), (.2, .2, .6, .6))):
            w, h = 1520, 2688
            subprocess.run(
                ["ffmpeg", "-v", "error", "-f", "lavfi", "-i", f"color=c={self.AMARILLO}:s={w}x{h}",
                 "-vf", f"drawbox=x={int(w * x)}:y={int(h * y)}:w={int(w * ancho)}"
                        f":h={int(h * alto)}:color={self.CROMA}:t=fill",
                 "-frames:v", "1", "-y", str(fuente / still)],
                check=True,
            )

        escritos = video_assets.process_cabin_stills(fuente)

        self.assertEqual([p.name for p in escritos], list(CABIN_STILLS))
        self.assertFalse((self.resources / "Data" / "loops_manifest.json").exists())
        for png, hueco in zip(escritos, ((.34, .45), (.5, .5))):
            with self.subTest(png=png.name), Image.open(png) as img:
                self.assertEqual((img.mode, img.size), ("RGBA", (720, 1280)))
                pixels = np.asarray(img).astype(int)
                self.assertEqual(pixels[int(1280 * hueco[1]), int(720 * hueco[0]), 3], 0)
                pared = pixels[10, 10]
                self.assertEqual(pared[3], 255)
                self.assertLessEqual(np.abs(pared[:3] - rgb(self.AMARILLO)).max(), 12,
                                     f"la pared queda y del mismo amarillo: {pared}")

    def test_solo_la_cinematica_puede_ir_sin_alfa(self):
        for kind, piece_id in (("retrato", "npc_prueba"), ("objeto", "colchon_abre"),
                               ("cabina", "puertas_cierran")):
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                video_assets.process(kind, piece_id, self.root / "no.mp4", keyed=False)

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
