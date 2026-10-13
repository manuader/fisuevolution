"""El alta de la tanda de la 2.0: cada PNG del generador tiene destino, y el
traedor lo deja en el dropbox con la clave del juego."""

import json
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import traer_tanda  # noqa: E402
from process_dropbox import PIPELINE, SKIN_FAMILIES, destination  # noqa: E402

# Lo que el dueño aprobó y no tiene dónde ir (PLAN E8 "integración", duda 5).
SIN_DESTINO = frozenset({"ui_oro_skin_effect"})


def registro() -> list[dict]:
    return json.loads((PIPELINE / "prompts" / "prompts.json").read_text())


def tanda() -> list[dict]:
    return [e for e in registro() if e.get("tanda") == "v2"]


class AltaTests(unittest.TestCase):
    def test_no_asset_key_is_registered_twice(self):
        repetidas = [k for k, n in Counter(e["assetKey"] for e in registro()).items() if n > 1]
        self.assertEqual(repetidas, [])

    def test_every_entry_of_the_batch_has_a_destination(self):
        for entry in tanda():
            with self.subTest(entry["assetKey"]):
                destination(entry)

    def test_the_batch_has_the_size_of_the_plan(self):
        por_categoria = Counter(e["category"] for e in tanda())
        self.assertEqual(por_categoria, {"skinfam": 129, "npc": 52, "ui": 31, "background": 10})

    def test_every_family_has_its_43(self):
        familias = Counter(e["assetKey"].partition("__")[2] for e in tanda() if e["category"] == "skinfam")
        self.assertEqual(familias, {familia: 43 for familia in SKIN_FAMILIES})

    @unittest.skipUnless(traer_tanda.GENERADOR.is_dir(), "sin el proyecto generador")
    def test_every_png_of_the_generator_has_an_entry_or_a_reason(self):
        generados = {png.stem for png in traer_tanda.GENERADOR.glob("*.png")}
        cubiertos = {e.get("generado_como", e["assetKey"]) for e in tanda()}
        self.assertEqual(generados - cubiertos, set(SIN_DESTINO))
        self.assertEqual(cubiertos - generados, set())


PREMIOS = 27  # `fisu-v2-premios/output/`: 26 de `ui.atlas` y el Vendedor enojado


def premios() -> list[dict]:
    return [e for e in registro() if e.get("tanda") == "premios"]


class PremiosTests(unittest.TestCase):
    """El alta de los premios ilustrados de E14 (C4/C8/C15), aprobados por el dueño."""

    def test_the_batch_has_its_27(self):
        self.assertEqual(Counter(e["category"] for e in premios()), {"ui": 26, "npc": 1})
        self.assertEqual(len(premios()), PREMIOS)

    def test_every_entry_has_a_destination_and_a_prompt(self):
        for entry in premios():
            with self.subTest(entry["assetKey"]):
                atlas, key, seccion = destination(entry)
                self.assertEqual(key, entry["assetKey"])
                self.assertEqual((atlas, seccion), ("npcs.atlas", "npcs") if entry["category"] == "npc"
                                 else ("ui.atlas", "ui"))
                self.assertGreater(len(entry["prompt"]), 100)

    def test_the_reward_art_is_drawn_big_and_the_icons_small(self):
        from process_dropbox import export_size
        self.assertEqual(export_size("ui", "rw_coins"), (384, 512))
        self.assertEqual(export_size("ui", "ui_offer_mudanza"), (384, 512))
        self.assertEqual(export_size("ui", "ui_icon_lock"), (192, 256))

    def test_every_png_is_integrated_in_the_game(self):
        from process_dropbox import RESOURCES
        manifest = json.loads((RESOURCES / "Data" / "assets_manifest.json").read_text())
        for entry in premios():
            with self.subTest(entry["assetKey"]):
                atlas, key, seccion = destination(entry)
                self.assertEqual(manifest[seccion][entry["assetKey"]], key)
                for escala in ("@2x", "@3x"):
                    self.assertTrue((RESOURCES / atlas / f"{key}{escala}.png").exists())
                self.assertTrue((PIPELINE / "dropbox" / "procesadas" / f"{entry['assetKey']}.png").exists())

    @unittest.skipUnless(traer_tanda.GENERADOR_PREMIOS.is_dir(), "sin el proyecto generador")
    def test_every_png_of_the_generator_has_an_entry(self):
        generados = {png.stem for png in traer_tanda.GENERADOR_PREMIOS.glob("*.png")}
        self.assertEqual(generados, {e["assetKey"] for e in premios()})

    def test_the_prizes_come_from_their_own_generator(self):
        with tempfile.TemporaryDirectory() as tmp:
            generador, dropbox = Path(tmp) / "out", Path(tmp) / "dropbox"
            generador.mkdir()
            (generador / "rw_coins.png").write_bytes(b"png")
            entradas = [{"assetKey": "rw_coins", "category": "ui", "tanda": "premios"}]
            with mock.patch.object(traer_tanda, "GENERADOR_PREMIOS", generador), \
                 mock.patch.object(traer_tanda, "entradas_premios", return_value=entradas):
                self.assertEqual(traer_tanda.traer("premios", dropbox=dropbox), ["rw_coins"])
            self.assertEqual((dropbox / "rw_coins.png").read_bytes(), b"png")

    def test_the_v2_groups_do_not_bring_the_prizes(self):
        self.assertTrue(all(e.get("tanda") == "v2" for e in traer_tanda.entradas_v2()))


class TraerTests(unittest.TestCase):
    def test_brings_a_group_with_the_key_of_the_game(self):
        with tempfile.TemporaryDirectory() as tmp:
            generador, dropbox = Path(tmp) / "out", Path(tmp) / "dropbox"
            generador.mkdir()
            (generador / "ui_oro_autotap.png").write_bytes(b"png")
            entradas = [{"assetKey": "ui_shop_auto_tap", "category": "ui", "tanda": "v2",
                         "generado_como": "ui_oro_autotap"}]
            with mock.patch.object(traer_tanda, "GENERADOR", generador), \
                 mock.patch.object(traer_tanda, "entradas_v2", return_value=entradas):
                traidas = traer_tanda.traer("ui", dropbox=dropbox)
            self.assertEqual(traidas, ["ui_shop_auto_tap"])
            self.assertEqual((dropbox / "ui_shop_auto_tap.png").read_bytes(), b"png")

    def test_one_png_can_feed_two_keys(self):
        claves = sorted(e["assetKey"] for e in tanda() if e.get("generado_como") == "ui_oro_income_boost")
        self.assertEqual(claves, ["ui_shop_income_x2", "ui_shop_income_x3"])

    def test_a_missing_png_fails_loudly(self):
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(traer_tanda, "GENERADOR", Path(tmp)), \
                 mock.patch.object(traer_tanda, "entradas_v2",
                                   return_value=[{"assetKey": "npc_x", "category": "npc", "tanda": "v2"}]):
                with self.assertRaises(FileNotFoundError):
                    traer_tanda.traer("npc", dropbox=Path(tmp) / "d")
