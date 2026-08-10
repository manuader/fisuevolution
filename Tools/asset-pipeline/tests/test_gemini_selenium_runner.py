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
    GeminiBrowser,
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

    def test_verify_png_accepts_full_size_icon_below_old_100kb_gate(self):
        # Regresión: un ícono UI plano de 1024x1024 comprime muy por debajo de
        # 100 KB pero es válido. El gate es dimensional, no de bytes.
        icon = self.root / "flat_icon.png"
        Image.linear_gradient("L").resize((1024, 1024)).convert("RGB").save(icon)
        self.assertLess(icon.stat().st_size, 100_000)  # habría fallado el viejo gate
        self.assertTrue(verify_png(icon))

    def test_verify_png_rejects_small_dimensions_even_if_bytes_ok(self):
        # Una imagen chica (p.ej. un thumbnail espurio) no es un asset válido.
        small = self.root / "small.png"
        Image.effect_noise((128, 128), 100).convert("RGB").save(small)
        self.assertFalse(verify_png(small, minimum_bytes=1))

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

    def test_has_content_rejects_blank_and_accepts_real_image(self):
        from io import BytesIO

        def png_bytes(img):
            buf = BytesIO()
            img.save(buf, "PNG")
            return buf.getvalue()

        transparent = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        solid = Image.new("RGB", (1024, 1024), (255, 255, 255))
        real = Image.linear_gradient("L").resize((1024, 1024)).convert("RGB")
        self.assertFalse(GeminiBrowser._has_content(png_bytes(transparent)))
        self.assertFalse(GeminiBrowser._has_content(png_bytes(solid)))
        self.assertTrue(GeminiBrowser._has_content(png_bytes(real)))

    def test_download_cross_origin_ignores_non_http_src_without_browser(self):
        # El guard corta antes de tocar Selenium: un blob:/None nunca abre driver.
        browser = GeminiBrowser(port=9222)
        self.assertIsNone(browser._download_cross_origin(None))
        self.assertIsNone(browser._download_cross_origin("blob:https://x/abc"))
        self.assertIsNone(browser.driver)  # jamás se conectó

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


class TransientBrowserErrorTests(unittest.TestCase):
    """Un error del DOM no puede llevarse puesta la corrida entera.

    Pasó el 2026-08-10 con 8 fondos por delante: Gemini mostró un mensaje de
    error suyo, el DOM se rehizo debajo de Selenium y
    `StaleElementReferenceException` subió por `_wait_for` → `generate` → `run`
    → `main` y mató el proceso. `run` atrapaba sólo
    `(GenerationBlocked, OSError, RuntimeError)`, y las excepciones de Selenium
    no son ninguna de las tres.

    Es la misma lección del bug #4 del handoff de arte —el batch no se frena por
    UN fallo— pero por una puerta que aquel arreglo no cubría.
    """

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.prompts = self.root / "prompts"
        self.prompts.mkdir()
        self.dropbox = self.root / "dropbox"

    def tearDown(self):
        self.temp.cleanup()

    def test_wait_for_survives_a_stale_element_and_retries(self):
        """El DOM se rehace mientras leemos: hay que reintentar, no abortar."""
        from selenium.common.exceptions import StaleElementReferenceException

        browser = GeminiBrowser(timeout=5)
        calls = {"n": 0}

        def flaky():
            calls["n"] += 1
            if calls["n"] < 3:
                raise StaleElementReferenceException("stale element not found")
            return "listo"

        self.assertEqual(browser._wait_for(flaky, "algo"), "listo")
        self.assertEqual(calls["n"], 3)

    def test_a_selenium_error_fails_only_that_asset(self):
        """Y si igual explota, se anota el fallo y sigue el próximo."""
        from selenium.common.exceptions import WebDriverException

        asset_path = write_prompt(self.prompts, "04_boom")
        asset = parse_asset(asset_path)

        class ExplodingBrowser:
            def generate(self, _asset, _reference, _downloads):
                raise WebDriverException("stale element reference")

        checkpoint = RunCheckpoint(self.root / "state" / "selenium-run.json")
        runner = AssetRunner(ExplodingBrowser(), self.dropbox, None, checkpoint)

        self.assertFalse(runner.run(asset))
        self.assertIn("boom", checkpoint.data["failures"])
        self.assertIn("estado**: pendiente", asset_path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()


class ReferencePerAssetTests(unittest.TestCase):
    """F7: cada skin adjunta a SU personaje. Antes el runner leía el campo
    `**referencia**` como un booleano y adjuntaba siempre fisura.png, lo que
    habría mandado el Fisura como referencia de estilo de la skin del CEO."""

    def test_reference_path_comes_from_the_md(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            prompt = root / "40_ceo__magnate.md"
            prompt.write_text(
                "# Skin\n\n- **estado**: pendiente\n"
                "- **referencia**: adjuntar `dropbox/procesadas/ceo.png`\n\n"
                "## Prompt\n\nPrompt de prueba.\n",
                encoding="utf-8",
            )
            asset = parse_asset(prompt, base=root)
            self.assertTrue(asset.needs_reference)
            self.assertEqual(asset.reference, root / "dropbox/procesadas/ceo.png")

    def test_asset_without_reference_field_has_none(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            prompt = root / "47_bg_alley.md"
            prompt.write_text(
                "# Fondo\n\n- **estado**: pendiente\n\n## Prompt\n\nUna calle.\n",
                encoding="utf-8",
            )
            asset = parse_asset(prompt, base=root)
            self.assertIsNone(asset.reference)
            self.assertFalse(asset.needs_reference)

    def test_runner_prefers_the_assets_own_reference(self):
        captured = {}

        class FakeBrowser:
            def generate(self, asset, reference, downloads):
                captured["reference"] = reference
                raise RuntimeError("corta acá: sólo interesa qué referencia se pasó")

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            prompt = root / "41_god__dorado.md"
            prompt.write_text(
                "# Skin\n\n- **estado**: pendiente\n"
                "- **referencia**: adjuntar `dropbox/procesadas/god.png`\n\n"
                "## Prompt\n\nPrompt.\n",
                encoding="utf-8",
            )
            asset = parse_asset(prompt, base=root)
            runner = AssetRunner(
                FakeBrowser(),
                root / "dropbox",
                root / "heroes" / "approved" / "fisura.png",  # fallback global
                RunCheckpoint(root / "state.json"),
            )
            self.assertFalse(runner.run(asset))
        self.assertEqual(captured["reference"], root / "dropbox/procesadas/god.png")

    def test_fingerprint_cache_is_keyed_by_path(self):
        """Una sola entrada global compararía la skin del CEO contra el Fisura."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            first, second = root / "a.png", root / "b.png"
            Image.new("RGB", (600, 600), (10, 20, 30)).save(first)
            Image.new("RGB", (600, 600), (200, 180, 160)).save(second)

            browser = GeminiBrowser()
            browser._ref_fp_cache = {}
            for path in (first, second):
                browser._ref_fp_cache[str(path)] = browser._fingerprint(path.read_bytes())

            self.assertEqual(len(browser._ref_fp_cache), 2)
            self.assertNotEqual(
                browser._ref_fp_cache[str(first)],
                browser._ref_fp_cache[str(second)],
            )


class SkinAssetKeyTests(unittest.TestCase):
    """La convención del juego es `<char>_idle__<skin>`: el `_idle` va ANTES del
    `__`. Concatenar el sufijo al final (como las otras categorías) daría
    `homeless__second_life_idle`, que no matchea ninguna textura."""

    def test_skin_key_inserts_idle_before_the_skin_id(self):
        from process_dropbox import skin_asset_key

        self.assertEqual(
            skin_asset_key("homeless__second_life"), "homeless_idle__second_life"
        )
        self.assertEqual(
            skin_asset_key("junior_programmer__hacker"),
            "junior_programmer_idle__hacker",
        )

    def test_skin_key_rejects_a_key_without_separator(self):
        from process_dropbox import skin_asset_key

        with self.assertRaises(ValueError):
            skin_asset_key("homeless")

    def test_skin_category_does_not_write_the_manifest(self):
        from process_dropbox import ATLAS_BY_CATEGORY

        _, manifest_section, _ = ATLAS_BY_CATEGORY["skin"]
        self.assertIsNone(
            manifest_section,
            "una skin en manifest['characters'] rompe manifestEntriesReferenceRealTypes",
        )


class BlockDetectionTests(unittest.TestCase):
    """El banner de aviso de cuota comparte substring con el bloqueo real."""

    def test_approaching_limit_banner_is_not_a_block(self):
        page = (
            "Conversación con Gemini | ¿Tienes nuevas ideas para explorar? | "
            "Estás por alcanzar el límite de uso. El modelo Pro puede agotarlo "
            "más rápido. | Consultar uso | Pro"
        )
        self.assertIsNone(
            GeminiBrowser._contains_error(page),
            "el aviso preventivo frenaba el batch entero como si fuera un bloqueo",
        )

    def test_real_limit_message_is_still_detected(self):
        self.assertEqual(
            GeminiBrowser._contains_error("Llegaste a tu límite de mensajes por hoy"),
            "Gemini alcanzó su límite de uso",
        )
        self.assertEqual(
            GeminiBrowser._contains_error("Alcanzaste el límite de uso del modelo Pro"),
            "Gemini alcanzó su límite de uso",
        )

    def test_other_blocks_are_untouched(self):
        self.assertEqual(GeminiBrowser._contains_error("Please solve this CAPTCHA"), "Gemini mostró un CAPTCHA")
        self.assertEqual(GeminiBrowser._contains_error("Something went wrong"), "Gemini devolvió un error")
        self.assertIsNone(GeminiBrowser._contains_error("todo bien por acá"))


class PromptLandedTests(unittest.TestCase):
    """El prompt tiene que llegar al editor ANTES de tocar enviar.

    El 2026-08-06 el runner mandó imágenes sin prompt: la UI nueva de Gemini
    (`new-input-ui`) suelta el foco al `<body>` después de pegar la referencia,
    así que los keystrokes de System Events caían en la página. El runner no lo
    notaba porque su única comprobación era que el botón "Enviar mensaje"
    estuviera habilitado — y la imagen sola ya lo habilita.
    """

    def test_blank_editor_never_counts_as_landed(self):
        # Quill deja "\n" y la clase ql-blank cuando el editor está vacío.
        self.assertFalse(GeminiBrowser.prompt_landed("\n", "Match EXACTLY the art style"))
        self.assertFalse(GeminiBrowser.prompt_landed("", "Match EXACTLY the art style"))
        self.assertFalse(GeminiBrowser.prompt_landed("   \n  ", "Match EXACTLY the art style"))

    def test_editor_with_the_prompt_counts_as_landed(self):
        prompt = "Match EXACTLY the art style, line weight and color treatment."
        self.assertTrue(GeminiBrowser.prompt_landed(prompt, prompt))

    def test_partially_typed_prompt_does_not_count(self):
        # Un keystroke que se corta a la mitad es peor que uno que no llega:
        # genera arte con un prompt truncado y lo da por bueno.
        prompt = "Match EXACTLY the art style, line weight and color treatment."
        self.assertFalse(GeminiBrowser.prompt_landed("Match EXACTLY the art", prompt))

    def test_ignores_whitespace_and_case_noise_from_the_editor(self):
        # El editor normaliza saltos y puede agregar espacio de cola.
        prompt = "Full body standing character, centered."
        self.assertTrue(GeminiBrowser.prompt_landed("Full body standing character, centered. \n", prompt))


class PromptRegistryTests(unittest.TestCase):
    """Todo prompt .md tiene que tener su entrada en prompts.json.

    El 2026-08-06 se escribieron 52 prompts .md nuevos y nadie los agregó a
    prompts.json. El runner los generó igual —lee los .md— pero
    `process_dropbox.py` lee el JSON, así que rechazó los 45 PNG con
    "NOMBRES DESCONOCIDOS" y ninguno llegó al juego. Dos fuentes de verdad que
    nadie chequeaba una contra la otra.
    """

    def test_every_md_prompt_has_a_registry_entry(self):
        pipeline = Path(__file__).resolve().parents[1]
        registry = {
            e["assetKey"]
            for e in json.loads((pipeline / "prompts" / "prompts.json").read_text())
        }
        md_keys = set()
        for md in (pipeline / "prompts" / "gemini_pro").glob("[0-9][0-9]*.md"):
            if md.name == "00_INDICE.md":
                continue
            md_keys.add(parse_asset(md).key)

        faltan = sorted(md_keys - registry)
        self.assertEqual(
            faltan, [],
            "estos .md no tienen entrada en prompts.json, así que process_dropbox "
            f"va a rechazar su PNG: {faltan}",
        )
