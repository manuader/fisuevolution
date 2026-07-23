#!/usr/bin/env python3
"""Genera assets de Gemini web de forma secuencial y reanudable.

La cola y el checkpoint no dependen de Selenium para poder verificarse sin
navegador. La parte de browser se agrega más abajo en este mismo archivo.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

from _common import read_json, write_json

FILE_RE = re.compile(r"^(?P<order>\d{2})_(?P<key>.+)\.md$")
STATE_RE = re.compile(r"^- \*\*estado\*\*: (?P<state>\w+)$", re.MULTILINE)
PIPELINE = Path(__file__).resolve().parents[1]
PROMPTS_DIR = PIPELINE / "prompts" / "gemini_pro"
DROPBOX = PIPELINE / "dropbox"
PROCESSED = DROPBOX / "procesadas"
REFERENCE = PIPELINE / "heroes" / "approved" / "fisura.png"
MANIFEST = PIPELINE.parent.parent / "FisuEvolution" / "Resources" / "Data" / "assets_manifest.json"
CHECKPOINT = PIPELINE / "state" / "selenium-run.json"


def _applescript_string(text: str) -> str:
    """Literal AppleScript seguro para `keystroke` (escapa \\ y comillas)."""
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + escaped + '"'


class GenerationBlocked(RuntimeError):
    """Gemini pidió intervención humana o la UI no fue reconocida."""


@dataclass(frozen=True)
class Asset:
    order: int
    key: str
    path: Path
    state: str
    needs_reference: bool
    prompt: str


def parse_asset(path: Path) -> Asset:
    """Convierte un MD numerado de Gemini Pro en una entrada de cola."""
    match = FILE_RE.match(path.name)
    if not match:
        raise ValueError(f"Nombre de prompt inválido: {path.name}")
    text = path.read_text(encoding="utf-8")
    state = STATE_RE.search(text)
    _, marker, prompt = text.partition("## Prompt")
    if not marker or not prompt.strip():
        raise ValueError(f"Falta ## Prompt en {path}")
    return Asset(
        order=int(match.group("order")),
        key=match.group("key"),
        path=path,
        state=state.group("state") if state else "pendiente",
        needs_reference="**referencia**" in text,
        prompt=prompt.strip(),
    )


def manifest_keys(path: Path) -> set[str]:
    """Lee todas las claves de las tres secciones del manifest, si existe."""
    data = read_json(path, {}) or {}
    return {
        key
        for section in ("characters", "backgrounds", "ui")
        for key in data.get(section, {})
    }


def pending_assets(
    prompts_dir: Path,
    dropbox: Path,
    processed_dir: Path,
    manifest: Path,
) -> list[Asset]:
    """Devuelve únicamente assets no integrados, en orden de evolución."""
    known_manifest = manifest_keys(manifest)
    assets: list[Asset] = []
    for path in sorted(prompts_dir.glob("[0-9][0-9]_*.md")):
        if path.name == "00_INDICE.md":
            continue
        asset = parse_asset(path)
        if asset.state == "hecho":
            continue
        name = f"{asset.key}.png"
        if (dropbox / name).exists() or (processed_dir / name).exists():
            continue
        if asset.key in known_manifest:
            continue
        assets.append(asset)
    return assets


def verify_png(path: Path, minimum_bytes: int = 100_000) -> bool:
    """Comprueba firma, tamaño y decodificación de un PNG descargado."""
    if not path.is_file() or path.stat().st_size < minimum_bytes:
        return False
    try:
        from PIL import Image

        with Image.open(path) as image:
            image.verify()
        return path.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
    except (OSError, ValueError):
        return False


class RunCheckpoint:
    """Estado pequeño, atómico y legible para pausar/reanudar el batch."""

    def __init__(self, path: Path):
        self.path = Path(path)
        self.data = read_json(
            self.path,
            {"completed": [], "failures": {}, "last_success": None},
        )

    def _save(self) -> None:
        write_json(self.path, self.data)

    def record_success(self, key: str, destination: Path) -> None:
        if key not in self.data["completed"]:
            self.data["completed"].append(key)
        self.data["last_success"] = key
        self.data.setdefault("downloads", {})[key] = str(destination)
        self._save()

    def record_failure(self, key: str, reason: str) -> None:
        self.data.setdefault("failures", {})[key] = reason
        self._save()


def mark_asset_done(asset: Asset) -> None:
    """Cambia el MD sólo después de haber verificado el PNG de destino."""
    text = asset.path.read_text(encoding="utf-8")
    if asset.state != "hecho":
        asset.path.write_text(
            text.replace("- **estado**: pendiente", "- **estado**: hecho", 1),
            encoding="utf-8",
        )


class AssetRunner:
    """Coordina navegador, disco y checkpoint sin integrar assets al juego."""

    def __init__(
        self,
        browser: object,
        dropbox: Path,
        reference: Path | None,
        checkpoint: RunCheckpoint,
        minimum_bytes: int = 100_000,
    ):
        self.browser = browser
        self.dropbox = Path(dropbox)
        self.reference = reference
        self.checkpoint = checkpoint
        self.minimum_bytes = minimum_bytes

    def run(self, asset: Asset) -> bool:
        self.dropbox.mkdir(parents=True, exist_ok=True)
        destination = self.dropbox / f"{asset.key}.png"
        # Chrome (attach por debugger) baja siempre a ~/Downloads pese al CDP.
        downloads = Path.home() / "Downloads"
        try:
            source = self.browser.generate(asset, self.reference, downloads)
            source = Path(source)
            if not verify_png(source, self.minimum_bytes):
                raise GenerationBlocked("la descarga no es un PNG válido de más de 100 KB")
            if source != destination:
                shutil.move(str(source), destination)
            if not verify_png(destination, self.minimum_bytes):
                raise GenerationBlocked("el PNG no llegó íntegro a dropbox")
        except (GenerationBlocked, OSError, RuntimeError) as error:
            self.checkpoint.record_failure(asset.key, str(error))
            return False
        mark_asset_done(asset)
        self.checkpoint.record_success(asset.key, destination)
        return True


class GeminiBrowser:
    """Adaptador pequeño y deliberadamente conservador para la web de Gemini."""

    def __init__(self, port: int = 9222, timeout: int = 180):
        self.port = port
        self.timeout = timeout
        self.driver = None

    def _driver(self):
        if self.driver is not None:
            return self.driver
        try:
            from selenium import webdriver
            from selenium.webdriver.chrome.options import Options
        except ImportError as error:
            raise GenerationBlocked("falta Selenium: pip install -r requirements.txt") from error
        options = Options()
        options.debugger_address = f"127.0.0.1:{self.port}"
        try:
            self.driver = webdriver.Chrome(options=options)
        except Exception as error:  # Selenium expone tipos distintos según driver.
            raise GenerationBlocked(
                f"no pude conectar Selenium al Chrome aislado en el puerto {self.port}"
            ) from error
        return self.driver

    @staticmethod
    def _contains_error(text: str) -> str | None:
        normalized = text.lower()
        patterns = {
            "captcha": "Gemini mostró un CAPTCHA",
            "límite de uso": "Gemini alcanzó su límite de uso",
            "llegaste a tu límite": "Gemini alcanzó su límite de uso",
            "try again later": "Gemini pidió reintentar más tarde",
            "something went wrong": "Gemini devolvió un error",
            "no se pudo generar": "Gemini no pudo generar la imagen",
        }
        for needle, reason in patterns.items():
            if needle in normalized:
                return reason
        return None

    def _check_blocked(self) -> None:
        reason = self._contains_error(self._driver().page_source)
        if reason:
            raise GenerationBlocked(reason)

    def _find_first(self, selectors: list[tuple[str, str]]):
        from selenium.webdriver.common.by import By

        driver = self._driver()
        for kind, value in selectors:
            elements = driver.find_elements(getattr(By, kind), value)
            for element in elements:
                if element.is_displayed() and element.is_enabled():
                    return element
        return None

    def _wait_for(self, action, description: str):
        deadline = time.monotonic() + self.timeout
        while time.monotonic() < deadline:
            self._check_blocked()
            result = action()
            if result:
                return result
            time.sleep(0.5)
        raise GenerationBlocked(f"timeout esperando {description}")

    def _open_new_chat(self) -> None:
        driver = self._driver()
        driver.get("https://gemini.google.com/app")
        self._wait_for(
            lambda: self._find_first([
                ("CSS_SELECTOR", "textarea"),
                ("CSS_SELECTOR", "[contenteditable='true']"),
            ]),
            "el cuadro de prompt de Gemini (confirmá el login en Chrome aislado)",
        )

    def _upload_reference(self, reference: Path) -> None:
        # Gemini no expone un <input type=file> accesible; el camino confiable es
        # pegar la imagen desde el portapapeles del sistema (macOS) con cmd+v.
        if reference is None or not reference.is_file():
            raise GenerationBlocked("el prompt requiere fisura.png pero no existe la referencia")
        from selenium.webdriver.common.by import By
        from selenium.webdriver.common.keys import Keys

        script = (
            'set the clipboard to (read (POSIX file "%s") as «class PNGf»)'
            % str(reference.resolve())
        )
        result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
        if result.returncode != 0:
            raise GenerationBlocked(f"no pude cargar la referencia al portapapeles: {result.stderr.strip()}")

        field = self._find_first([
            ("CSS_SELECTOR", "[contenteditable='true']"),
            ("CSS_SELECTOR", "textarea"),
        ])
        if field is None:
            raise GenerationBlocked("no encontré el cuadro de prompt para pegar la referencia")
        field.click()
        time.sleep(0.4)
        field.send_keys(Keys.COMMAND, "v")

        driver = self._driver()
        self._wait_for(
            lambda: any(
                int(img.get_attribute("naturalWidth") or 0) > 100
                for img in driver.find_elements(By.TAG_NAME, "img")
            ),
            "la miniatura de la referencia adjunta",
        )
        self._check_blocked()

    def _submit(self, prompt: str) -> None:
        # El prompt es el texto EXACTO del .md del asset (nunca inventado).
        # Gemini exige input "trusted": send_keys/CDP no habilitan el botón de
        # enviar. Se escribe con keystrokes reales de macOS (System Events) y se
        # confirma con un Return real; ambos indistinguibles de un humano.
        # NO clickear el campo: el foco OS-level viene del paste de la referencia.
        # Re-clickear con Selenium lo rompe. Chrome al frente + keystroke real.
        subprocess.run(["osascript", "-e", 'tell application "Google Chrome" to activate'])
        time.sleep(1.0)
        # Pre-tipeo descartable: la app a veces pierde el primer carácter tras activate.
        subprocess.run(["osascript", "-e", 'tell application "System Events" to keystroke " "'])
        time.sleep(0.3)
        subprocess.run(["osascript", "-e", 'tell application "System Events" to key code 51'])  # Delete
        time.sleep(0.2)
        script = 'tell application "System Events" to keystroke %s' % _applescript_string(prompt)
        result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
        if result.returncode != 0:
            raise GenerationBlocked(
                "System Events no pudo escribir (¿falta permiso de Accesibilidad?): "
                + result.stderr.strip()
            )

        # Esperar a que Gemini habilite "Enviar mensaje" (confirma que el texto entró).
        self._wait_for(
            lambda: self._find_first([
                ("CSS_SELECTOR", "button[aria-label='Enviar mensaje']"),
                ("CSS_SELECTOR", "button[aria-label='Send message']"),
            ]),
            "el botón Enviar mensaje de Gemini",
        )
        subprocess.run(["osascript", "-e", 'tell application "System Events" to key code 36'])

    def _biggest_image(self):
        from selenium.webdriver.common.by import By

        driver = self._driver()
        imgs = sorted(
            driver.find_elements(By.TAG_NAME, "img"),
            key=lambda i: int(i.get_attribute("naturalWidth") or 0),
            reverse=True,
        )
        return imgs[0] if imgs and int(imgs[0].get_attribute("naturalWidth") or 0) >= 800 else None

    def _download_button(self):
        # Aparece recién al hacer hover sobre la imagen; se revela con ActionChains
        # y se toma regardless de is_displayed().
        from selenium.webdriver.common.by import By
        from selenium.webdriver.common.action_chains import ActionChains

        driver = self._driver()
        image = self._biggest_image()
        if image is None:
            return None
        ActionChains(driver).move_to_element(image).perform()
        time.sleep(0.8)
        matches = driver.find_elements(
            By.XPATH,
            "//button[contains(@aria-label,'Descargar imagen') or contains(@aria-label,'Download image') or contains(@aria-label,'Descargar') or contains(@aria-label,'Download')]",
        )
        for element in matches:
            if element.is_enabled():
                return element
        return None

    def _wait_for_download(self, downloads: Path, before: set[Path]) -> Path:
        deadline = time.monotonic() + self.timeout
        while time.monotonic() < deadline:
            self._check_blocked()
            pending = list(downloads.glob("*.crdownload"))
            candidates = [
                path for path in downloads.glob("Gemini_Generated_Image_*.png")
                if path not in before
            ]
            if candidates and not pending:
                newest = max(candidates, key=lambda path: path.stat().st_mtime)
                if verify_png(newest):
                    return newest
            time.sleep(0.5)
        raise GenerationBlocked("timeout esperando un PNG descargado desde Gemini")

    def generate(self, asset: Asset, reference: Path | None, downloads: Path) -> Path:
        """Genera uno y devuelve el PNG guardado en `downloads`. La imagen se
        extrae por canvas (píxeles ya renderizados) — sin depender del botón de
        descarga hover-only ni de blobs que Gemini revoca."""
        import base64

        downloads.mkdir(parents=True, exist_ok=True)
        driver = self._driver()
        driver.set_script_timeout(30)
        self._open_new_chat()
        if asset.needs_reference:
            self._upload_reference(reference)
        self._submit(asset.prompt)
        image = self._wait_for(self._biggest_image, "la imagen generada por Gemini")
        # Dejar que termine de renderizar a resolución plena.
        time.sleep(2)
        image = self._biggest_image() or image
        data_url = driver.execute_script(
            """
            const img = arguments[0];
            const c = document.createElement('canvas');
            c.width = img.naturalWidth; c.height = img.naturalHeight;
            try { c.getContext('2d').drawImage(img, 0, 0); return c.toDataURL('image/png'); }
            catch (e) { return 'TAINT:' + e; }
            """,
            image,
        )
        if not data_url.startswith("data:image"):
            raise GenerationBlocked(f"no pude extraer la imagen por canvas: {data_url[:60]}")
        raw = base64.b64decode(data_url.split(",", 1)[1])
        out = downloads / f"gemini_{asset.key}.png"
        out.write_bytes(raw)
        if not verify_png(out):
            raise GenerationBlocked("la imagen extraída no es un PNG válido")
        return out


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=0, help="máximo de assets (0 = todos)")
    parser.add_argument("--only", help="assetKey puntual")
    parser.add_argument("--dry-run", action="store_true", help="muestra cola sin abrir Gemini")
    parser.add_argument("--pause", type=float, default=4, help="segundos entre assets")
    parser.add_argument("--resume", action="store_true", help="continúa la cola; es el comportamiento por defecto")
    parser.add_argument("--process", action="store_true", help="procesa dropbox explícitamente al terminar")
    parser.add_argument("--port", type=int, default=9222, help="puerto Chrome debug")
    parser.add_argument("--timeout", type=int, default=180, help="timeout de UI/descarga por asset")
    args = parser.parse_args()

    queue = pending_assets(PROMPTS_DIR, DROPBOX, PROCESSED, MANIFEST)
    if args.only:
        queue = [asset for asset in queue if asset.key == args.only]
    if args.limit:
        queue = queue[:args.limit]
    print("Cola:", ", ".join(f"{asset.order:02d}_{asset.key}" for asset in queue) or "vacía")
    if args.dry_run or not queue:
        return

    runner = AssetRunner(GeminiBrowser(args.port, args.timeout), DROPBOX, REFERENCE, RunCheckpoint(CHECKPOINT))
    completed: list[str] = []
    for index, asset in enumerate(queue, 1):
        print(f"[{index}/{len(queue)}] {asset.key}…", flush=True)
        if runner.run(asset):
            completed.append(asset.key)
            print(f"  ✓ dropbox/{asset.key}.png")
        else:
            print("  ✗ queda pendiente; se detiene para no gastar tu cuota", file=sys.stderr)
            break
        if index < len(queue):
            time.sleep(args.pause)
    if args.process and completed:
        subprocess.run([str(PIPELINE / ".venv" / "bin" / "python"), str(PIPELINE / "scripts" / "process_dropbox.py")], check=False)


if __name__ == "__main__":
    main()
