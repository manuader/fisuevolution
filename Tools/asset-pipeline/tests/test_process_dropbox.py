"""Las reglas de `process_dropbox.py` que no dependen de una imagen."""

import json
import re
import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from process_dropbox import ATLAS_BY_CATEGORY, skin_asset_key  # noqa: E402

PROMPT_FILE_RE = re.compile(r"^\d{2,3}_(?P<key>.+)\.md$")


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
