"""Las reglas de `process_dropbox.py`.

Las que escriben un atlas lo hacen en un directorio temporal: el arte de la 2.0
todavía no existe, y un atlas vacío en `Resources` se compilaría igual."""

import io
import json
import re
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

from PIL import Image, ImageDraw

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import process_dropbox  # noqa: E402
from process_dropbox import (  # noqa: E402
    ATLAS_BY_CATEGORY,
    SKIN_FAMILIES,
    destination,
    export_size,
    skin_asset_key,
)

PROMPT_FILE_RE = re.compile(r"^\d{2,3}_(?P<key>.+)\.md$")

# Los prompts de la 2.0 viven en el repo generador, no en este.
PROMPTS_V2 = (
    Path.home() / "Desktop" / "projects" / "automatic-image-generation"
    / "projects" / "fisu-evolution-v2" / "prompts"
)


class SkinAssetKeyTests(unittest.TestCase):
    """La convención del juego es `<char>_idle__<skin>`: el `_idle` va ANTES del
    `__`. Concatenar el sufijo al final (como las otras categorías) daría
    `homeless__second_life_idle`, que no matchea ninguna textura."""

    def test_skin_key_inserts_idle_before_the_skin_id(self):
        self.assertEqual(
            skin_asset_key("homeless__second_life"), "homeless_idle__second_life"
        )
        self.assertEqual(
            skin_asset_key("junior_programmer__hacker"),
            "junior_programmer_idle__hacker",
        )

    def test_skin_key_rejects_a_key_without_separator(self):
        with self.assertRaises(ValueError):
            skin_asset_key("homeless")

    def test_skin_category_does_not_write_the_manifest(self):
        _, manifest_section, _ = ATLAS_BY_CATEGORY["skin"]
        self.assertIsNone(
            manifest_section,
            "una skin en manifest['characters'] rompe manifestEntriesReferenceRealTypes",
        )


class NpcCategoryTests(unittest.TestCase):
    """Los visitantes de la biblia (`Docs/biblia-visitantes.md`) van a su propio
    atlas con la clave del prompt tal cual: `npc_comisario_talk` en el dropbox es
    `npc_comisario_talk` en `npcs.atlas`. Un visitante no es un tier, así que no
    puede caer en `manifest['characters']`."""

    def test_npc_goes_to_its_own_atlas_with_the_prompt_key(self):
        for key in ("npc_comisario", "npc_comisario_talk", "npc_vecina_face"):
            with self.subTest(key=key):
                self.assertEqual(
                    destination({"assetKey": key, "category": "npc"}),
                    ("npcs.atlas", key, "npcs"),
                )

    def test_the_new_poses_of_the_specials_are_visitors_too(self):
        """`sp_<id>_talk` y `sp_<id>_face` son poses de visitante. Registradas como
        `special` caerían en manifest['characters'] con un id que no es especial."""
        self.assertEqual(
            destination({"assetKey": "sp_cryptobro_talk", "category": "npc"}),
            ("npcs.atlas", "sp_cryptobro_talk", "npcs"),
        )

    def test_npc_is_not_a_character_of_the_manifest(self):
        _, manifest_section, _ = ATLAS_BY_CATEGORY["npc"]
        self.assertNotEqual(
            manifest_section, "characters",
            "un visitante en manifest['characters'] rompe manifestEntriesReferenceRealTypes",
        )

    def test_npc_exports_at_the_size_of_a_character(self):
        self.assertEqual(export_size("npc", "npc_comisario"), export_size("character", "homeless"))


class SkinFamilyCategoryTests(unittest.TestCase):
    """Cada familia de skins tiene su atlas (`fam_<familia>.atlas`, PLAN-v2 E6) para
    no mover las páginas de los atlas de fase. La clave es la del prompt,
    `<tipo>__<familia>`, y el sprite sigue la convención de las skins."""

    def test_family_skin_goes_to_the_atlas_of_its_family(self):
        for family in ("pijama", "gaucho", "dinosaurio"):
            with self.subTest(family=family):
                self.assertEqual(
                    destination({"assetKey": f"homeless__{family}", "category": "skinfam"}),
                    (f"fam_{family}.atlas", f"homeless_idle__{family}", None),
                )

    def test_family_skin_does_not_write_the_manifest(self):
        _, manifest_section, _ = ATLAS_BY_CATEGORY["skinfam"]
        self.assertIsNone(manifest_section, "las skins se buscan por nombre, como las de fase")

    def test_an_unknown_family_is_rejected(self):
        """Un typo en la clave no puede inventar un atlas nuevo."""
        for key in ("homeless__pijamas", "homeless", "homeless__oro"):
            with self.subTest(key=key), self.assertRaises(ValueError):
                destination({"assetKey": key, "category": "skinfam"})

    def test_family_skin_exports_at_the_size_of_a_skin(self):
        self.assertEqual(export_size("skinfam", "homeless__gaucho"), export_size("skin", "homeless__oro"))

    @unittest.skipUnless(PROMPTS_V2.is_dir(), f"sin el proyecto generador en {PROMPTS_V2}")
    def test_every_family_prompt_of_the_generator_has_an_atlas(self):
        families = {
            match.group("key").partition("__")[2]
            for md in PROMPTS_V2.glob("[0-9]*.md")
            if (match := PROMPT_FILE_RE.match(md.name)) and "__" in match.group("key")
        }
        self.assertEqual(families, set(SKIN_FAMILIES))


class ProcessNewCategoriesTests(unittest.TestCase):
    """`process` de punta a punta para las dos categorías de la 2.0, contra un
    Resources y un manifest de mentira."""

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.resources = self.root / "Resources"
        self.manifest = self.resources / "Data" / "assets_manifest.json"
        self.manifest.parent.mkdir(parents=True)
        self.manifest.write_text(json.dumps(
            {"schemaVersion": 1, "characters": {}, "backgrounds": {}, "ui": {}}
        ))
        for name, value in (
            ("RESOURCES", self.resources),
            ("MANIFEST", self.manifest),
            ("PROCESSED", self.root / "procesadas"),
        ):
            patcher = mock.patch.object(process_dropbox, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def process(self, key: str, category: str) -> None:
        """Suelta en el dropbox un personaje mínimo sobre papel blanco (un
        cuadrado con contorno) y lo procesa."""
        image = Image.new("RGB", (96, 96), "white")
        ImageDraw.Draw(image).rectangle((24, 16, 72, 88), fill=(200, 80, 40), outline="black", width=3)
        path = self.root / f"{key}.png"
        image.save(path)
        with redirect_stdout(io.StringIO()):
            process_dropbox.process(path, {"assetKey": key, "category": category})

    @staticmethod
    def size_of(png: Path) -> tuple[int, int]:
        with Image.open(png) as image:
            return image.size

    def test_npc_writes_its_atlas_and_a_manifest_section_of_its_own(self):
        self.process("npc_comisario_talk", "npc")

        atlas = self.resources / "npcs.atlas"
        self.assertEqual(self.size_of(atlas / "npc_comisario_talk@3x.png"), (512, 512))
        self.assertEqual(self.size_of(atlas / "npc_comisario_talk@2x.png"), (384, 384))
        manifest = json.loads(self.manifest.read_text())
        self.assertEqual(manifest["npcs"], {"npc_comisario_talk": "npc_comisario_talk"})
        self.assertEqual(manifest["characters"], {})
        self.assertTrue((self.root / "procesadas" / "npc_comisario_talk.png").exists())

    def test_family_skin_writes_its_atlas_and_leaves_the_manifest_alone(self):
        before = self.manifest.read_text()
        self.process("homeless__dinosaurio", "skinfam")

        atlas = self.resources / "fam_dinosaurio.atlas"
        self.assertEqual(self.size_of(atlas / "homeless_idle__dinosaurio@3x.png"), (512, 512))
        self.assertEqual(self.manifest.read_text(), before)
        self.assertTrue((self.root / "procesadas" / "homeless__dinosaurio.png").exists())


class PromptRegistryTests(unittest.TestCase):
    """Todo prompt .md tiene que tener su entrada en prompts.json.

    El 2026-08-06 se escribieron 52 prompts .md nuevos y nadie los agregó a
    prompts.json. `process_dropbox.py` lee el JSON, así que rechazó los 45 PNG
    con "NOMBRES DESCONOCIDOS" y ninguno llegó al juego.
    """

    def test_every_md_prompt_has_a_registry_entry(self):
        pipeline = Path(__file__).resolve().parents[1]
        registry = {
            e["assetKey"]
            for e in json.loads((pipeline / "prompts" / "prompts.json").read_text())
        }
        md_keys = {
            match.group("key")
            for md in (pipeline / "prompts" / "gemini_pro").glob("[0-9][0-9]*.md")
            if md.name != "00_INDICE.md" and (match := PROMPT_FILE_RE.match(md.name))
        }

        faltan = sorted(md_keys - registry)
        self.assertEqual(
            faltan, [],
            "estos .md no tienen entrada en prompts.json, así que process_dropbox "
            f"va a rechazar su PNG: {faltan}",
        )


if __name__ == "__main__":
    unittest.main()
