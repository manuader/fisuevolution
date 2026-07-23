"""Pruebas sin navegador para el runner Gemini Selenium."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from gemini_selenium_runner import (  # noqa: E402
    AssetRunner,
    RunCheckpoint,
    parse_asset,
    pending_assets,
    verify_png,
)
from launch_gemini_chrome import chrome_command, debug_url  # noqa: E402


def write_prompt(path: Path, key: str, state: str = "pendiente") -> Path:
    file = path / f"{int(key[:2]):02d}_{key[3:]}.md"
    file.write_text(
        f"# Asset\n\n- **estado**: {state}\n"
        "- **referencia**: adjuntar `heroes/approved/fisura.png`\n\n"
        "## Prompt\n\nPrompt de prueba.\n",
        encoding="utf-8",
    )
    return file


class GeminiSeleniumRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.prompts = self.root / "prompts"
        self.dropbox = self.root / "dropbox"
        self.processed = self.dropbox / "procesadas"
        self.prompts.mkdir()
        self.dropbox.mkdir()
        self.processed.mkdir()
        self.manifest = self.root / "assets_manifest.json"
        self.manifest.write_text(json.dumps({"characters": {"manifest": {}}}))

    def tearDown(self):
        self.temp.cleanup()

    def test_pending_assets_are_sorted_and_skip_done_dropbox_and_manifest(self):
        (self.prompts / "00_INDICE.md").write_text("# Índice", encoding="utf-8")
        write_prompt(self.prompts, "03_next")
        write_prompt(self.prompts, "01_done", "hecho")
        write_prompt(self.prompts, "02_in_dropbox")
        write_prompt(self.prompts, "05_manifest")
        (self.dropbox / "in_dropbox.png").write_bytes(b"exists")

        queue = pending_assets(self.prompts, self.dropbox, self.processed, self.manifest)

        self.assertEqual([asset.key for asset in queue], ["next"])
        self.assertEqual(queue[0].order, 3)
        self.assertTrue(queue[0].needs_reference)

    def test_verify_png_rejects_non_png_and_undersized_files(self):
        text = self.root / "not-image.png"
        text.write_text("not a png", encoding="utf-8")
        self.assertFalse(verify_png(text, minimum_bytes=1))

        tiny = self.root / "tiny.png"
        Image.new("RGB", (8, 8), "white").save(tiny)
        self.assertFalse(verify_png(tiny, minimum_bytes=100_000))

    def test_verify_png_accepts_a_decodable_sufficiently_large_file(self):
        image = self.root / "valid.png"
        Image.effect_noise((512, 512), 100).convert("RGB").save(image)

        self.assertTrue(verify_png(image, minimum_bytes=100_000))

    def test_checkpoint_records_success_and_failure_atomically(self):
        checkpoint = RunCheckpoint(self.root / "state" / "selenium-run.json")
        checkpoint.record_failure("next", "timeout")
        checkpoint.record_success("next", self.dropbox / "next.png")

        saved = json.loads(checkpoint.path.read_text(encoding="utf-8"))
        self.assertEqual(saved["completed"], ["next"])
        self.assertEqual(saved["failures"]["next"], "timeout")
        self.assertEqual(saved["last_success"], "next")

    def test_chrome_lifecycle_uses_local_debug_port_and_dedicated_profile(self):
        profile = self.root / ".chrome-profile"

        self.assertEqual(debug_url(), "http://127.0.0.1:9222/json/version")
        command = chrome_command(profile, 9222)

        self.assertIn("--remote-debugging-port=9222", command)
        self.assertIn(f"--user-data-dir={profile}", command)
        self.assertIn("https://gemini.google.com/", command)

    def test_failed_download_keeps_md_pending_and_records_failure(self):
        asset_path = write_prompt(self.prompts, "03_next")
        asset = parse_asset(asset_path)
        invalid = self.root / "download.png"
        invalid.write_text("not a png", encoding="utf-8")

        class FakeBrowser:
            def generate(self, _asset, _reference, _downloads):
                return invalid

        checkpoint = RunCheckpoint(self.root / "state" / "selenium-run.json")
        runner = AssetRunner(FakeBrowser(), self.dropbox, None, checkpoint)

        self.assertFalse(runner.run(asset))
        self.assertIn("estado**: pendiente", asset_path.read_text(encoding="utf-8"))
        self.assertIn("next", checkpoint.data["failures"])


if __name__ == "__main__":
    unittest.main()
