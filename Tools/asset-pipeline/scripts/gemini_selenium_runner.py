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

FILE_RE = re.compile(r"^(?P<order>\d{2,3})_(?P<key>.+)\.md$")
STATE_RE = re.compile(r"^- \*\*estado\*\*: (?P<state>\w+)$", re.MULTILINE)
# El path de la referencia se lee del propio .md: cada skin adjunta a SU
# personaje, no al Fisura. Se acepta con o sin backticks.
REFERENCE_RE = re.compile(
    r"^- \*\*referencia\*\*:[^`\n]*`?(?P<path>[^`\n]+?)`?\s*$", re.MULTILINE
)
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
    prompt: str
    #: Imagen de estilo a adjuntar, resuelta desde el campo `**referencia**` del
    #: .md. `None` = el asset no lleva referencia (fondos, íconos UI).
    reference: Path | None

    @property
    def needs_reference(self) -> bool:
        return self.reference is not None


def parse_reference(text: str, base: Path) -> Path | None:
    """Resuelve el path del campo `**referencia**` relativo a la raíz del pipeline.

    Hasta F7 el runner ignoraba este valor y adjuntaba siempre `fisura.png`: con
    93 assets del mismo personaje base daba igual. Las skins rompen ese supuesto
    — cada una necesita como referencia de estilo a SU personaje — así que ahora
    el path escrito en el .md es el que manda."""
    match = REFERENCE_RE.search(text)
    if not match:
        return None
    raw = match.group("path").strip()
    candidate = Path(raw)
    return candidate if candidate.is_absolute() else (base / raw)


def parse_asset(path: Path, base: Path = PIPELINE) -> Asset:
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
        prompt=prompt.strip(),
        reference=parse_reference(text, base),
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
    for path in sorted(prompts_dir.glob("[0-9][0-9]*.md")):
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


def verify_png(path: Path, minimum_bytes: int = 1_000) -> bool:
    """Comprueba firma, decodificación y DIMENSIONES de un PNG generado.

    El gate real es dimensional (>=512px), no de bytes: un ícono UI plano
    comprime a ~30-90 KB (mucho menos que un personaje detallado) pero sigue
    siendo un 1024x1024 real. Un umbral de 100 KB rechazaba íconos válidos.
    El piso de bytes queda mínimo, sólo para descartar archivos vacíos/truncados."""
    if not path.is_file() or path.stat().st_size < minimum_bytes:
        return False
    try:
        from PIL import Image

        with Image.open(path) as image:
            image.verify()  # integridad del stream
        with Image.open(path) as image:
            width, height = image.size
        if min(width, height) < 512:
            return False
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
        minimum_bytes: int = 1_000,
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
            # La del .md manda; `self.reference` queda de fallback histórico.
            source = self.browser.generate(asset, asset.reference or self.reference, downloads)
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

    def __init__(self, port: int = 9222, timeout: int = 180, ref_threshold: float = 12):
        self.port = port
        self.timeout = timeout
        # Distancia MAE por debajo de la cual una imagen se considera "es la
        # referencia adjunta" y se descarta. Con referencias de OTRO personaje
        # (los 93 assets originales) 12 es holgado; con skins —donde la
        # referencia es el MISMO personaje con otra ropa— hay que bajarlo o el
        # filtro se come el resultado legítimo.
        self.ref_threshold = ref_threshold
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

    #: Frases que comparten substring con un bloqueo real pero NO bloquean nada.
    #: El banner "Estás por alcanzar el límite de uso" es un aviso preventivo: el
    #: chat sigue generando. Como contiene "límite de uso", sin sacarlo antes de
    #: buscar errores TODOS los assets fallan con "límite alcanzado" y el batch
    #: se frena creyendo que la cuota se agotó.
    BENIGN_NOTICES = (
        "estás por alcanzar el límite de uso",
        "estas por alcanzar el limite de uso",
        "you're approaching your usage limit",
        "youre approaching your usage limit",
    )

    @classmethod
    def _contains_error(cls, text: str) -> str | None:
        normalized = text.lower()
        for notice in cls.BENIGN_NOTICES:
            normalized = normalized.replace(notice, "")
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

    def _focus_compose(self) -> None:
        """Clickea el compose box para darle foco DOM (assets sin referencia, que
        no tienen paste). Sin esto los keystrokes de System Events se pierden."""
        field = self._find_first([
            ("CSS_SELECTOR", "[contenteditable='true']"),
            ("CSS_SELECTOR", "textarea"),
        ])
        if field is not None:
            field.click()
            time.sleep(0.3)

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
        send = self._wait_for(
            lambda: self._find_first([
                ("CSS_SELECTOR", "button[aria-label='Enviar mensaje']"),
                ("CSS_SELECTOR", "button[aria-label='Send message']"),
            ]),
            "el botón Enviar mensaje de Gemini",
        )
        # Click directo del botón (Return no siempre envía); confirmar que la
        # conversación arranca por el cambio de URL a /app/<id>.
        driver = self._driver()
        driver.execute_script("arguments[0].click();", send)
        self._wait_for(
            lambda: "/app/" in driver.current_url,
            "que Gemini abra la conversación tras enviar",
        )

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
        else:
            # Sin referencia no hay paste que enfoque el editor: hay que clickearlo
            # para que los keystrokes de System Events aterricen en el compose box.
            self._focus_compose()
        self._submit(asset.prompt)
        # La imagen GENERADA vive en la respuesta y difiere de la referencia
        # adjunta (que también es 2048px). Se espera una imagen grande cuya huella
        # de píxeles NO coincida con la referencia.
        raw = self._wait_for(
            lambda: self._extract_generated_png(reference if asset.needs_reference else None),
            "la imagen generada por Gemini (distinta de la referencia)",
        )
        out = downloads / f"gemini_{asset.key}.png"
        out.write_bytes(raw)
        if not verify_png(out):
            raise GenerationBlocked("la imagen extraída no es un PNG válido")
        return out

    def _fingerprint(self, png_bytes: bytes) -> tuple:
        from io import BytesIO
        from PIL import Image

        thumb = Image.open(BytesIO(png_bytes)).convert("RGB").resize((32, 32))
        return tuple(thumb.getdata())

    @staticmethod
    def _fingerprint_distance(a: tuple, b: tuple) -> float:
        total = 0
        for (r1, g1, b1), (r2, g2, b2) in zip(a, b):
            total += abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)
        return total / (len(a) * 3)

    def _extract_generated_png(self, reference: Path | None):
        """Devuelve los bytes PNG de la primera imagen grande que NO sea la
        referencia. None si todavía no apareció (para que `_wait_for` reintente).

        La imagen recién generada suele ser un `blob:` same-origin y se extrae por
        canvas. Cuando Gemini ya la sirvió desde lh3.googleusercontent.com el canvas
        queda "tainted" (cross-origin) y `toDataURL` lanza SecurityError; en ese caso
        se baja el `src` con las cookies de la sesión y se re-codifica a PNG."""
        import base64

        driver = self._driver()
        ref_fp = None
        if reference is not None:
            # Cache POR PATH: con referencia por asset, una sola entrada global
            # haría que la skin del CEO se comparara contra el Fisura.
            if not hasattr(self, "_ref_fp_cache"):
                self._ref_fp_cache = {}
            key = str(reference)
            if key not in self._ref_fp_cache:
                self._ref_fp_cache[key] = self._fingerprint(reference.read_bytes())
            ref_fp = self._ref_fp_cache[key]

        candidates = sorted(
            (i for i in driver.find_elements("tag name", "img")
             if int(i.get_attribute("naturalWidth") or 0) >= 512),
            key=lambda i: int(i.get_attribute("naturalWidth")),
            reverse=True,
        )
        for image in candidates:
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
            if data_url.startswith("data:image"):
                raw = base64.b64decode(data_url.split(",", 1)[1])
            else:
                # Canvas "tainted" (imagen cross-origin de googleusercontent):
                # bajar el original con las cookies de Google de la sesión.
                raw = self._download_cross_origin(image.get_attribute("src"))
                if raw is None:
                    continue
            if not self._has_content(raw):
                continue  # placeholder vacío/transparente: esperar el render real
            if ref_fp is not None:
                if self._fingerprint_distance(self._fingerprint(raw), ref_fp) < self.ref_threshold:
                    continue  # es la referencia; seguir buscando/esperando
            return raw
        return None

    @staticmethod
    def _has_content(raw: bytes) -> bool:
        """Descarta extracciones vacías: un placeholder transparente o un bloque de
        color uniforme (el canvas leído antes de que la imagen termine de renderizar).
        Un asset real tiene píxeles opacos Y variación de color."""
        from io import BytesIO
        from PIL import Image

        image = Image.open(BytesIO(raw)).convert("RGBA")
        _, alpha_max = image.getchannel("A").getextrema()
        if alpha_max < 16:
            return False  # totalmente transparente
        ranges = [hi - lo for lo, hi in image.convert("RGB").getextrema()]
        return max(ranges) >= 8  # alguna variación de color (no un bloque plano)

    def _download_cross_origin(self, src: str | None):
        """Baja la imagen generada (lh3.googleusercontent.com sirve 403 sin auth)
        con las cookies de Google de la sesión de Chrome y la re-codifica a PNG.
        Devuelve bytes PNG, o None si el src no es http o la bajada falla."""
        if not src or not src.startswith("http"):
            return None
        import urllib.request
        from io import BytesIO
        from PIL import Image

        try:
            cookie_header = "; ".join(
                f"{cookie['name']}={cookie['value']}"
                for cookie in self._driver().get_cookies()
            )
            request = urllib.request.Request(
                src, headers={"User-Agent": "Mozilla/5.0", "Cookie": cookie_header}
            )
            with urllib.request.urlopen(request, timeout=30) as response:
                data = response.read()
            buffer = BytesIO()
            Image.open(BytesIO(data)).convert("RGB").save(buffer, "PNG")
            return buffer.getvalue()
        except Exception:
            return None


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
    parser.add_argument("--retries", type=int, default=1,
                        help="reintentos por asset ante un fallo transitorio")
    parser.add_argument("--max-consecutive-failures", type=int, default=3,
                        help="frena el batch tras N fallos SEGUIDOS (bloqueo/logout/cuota)")
    parser.add_argument("--ref-threshold", type=float, default=12,
                        help="distancia MAE bajo la cual se descarta una imagen por "
                             "ser la referencia adjunta. Bajalo (~5) cuando la "
                             "referencia sea el MISMO personaje que se genera (skins)")
    args = parser.parse_args()

    queue = pending_assets(PROMPTS_DIR, DROPBOX, PROCESSED, MANIFEST)
    if args.only:
        queue = [asset for asset in queue if asset.key == args.only]
    if args.limit:
        queue = queue[:args.limit]
    print("Cola:", ", ".join(f"{asset.order:02d}_{asset.key}" for asset in queue) or "vacía")
    for asset in queue:
        if asset.reference is not None and not asset.reference.is_file():
            print(f"  ⚠️  {asset.key}: falta la referencia {asset.reference}", file=sys.stderr)
    if args.dry_run or not queue:
        return

    runner = AssetRunner(
        GeminiBrowser(args.port, args.timeout, args.ref_threshold),
        DROPBOX,
        REFERENCE,
        RunCheckpoint(CHECKPOINT),
    )
    py = str(PIPELINE / ".venv" / "bin" / "python")
    process_script = str(PIPELINE / "scripts" / "process_dropbox.py")
    completed: list[str] = []
    consecutive_failures = 0
    for index, asset in enumerate(queue, 1):
        print(f"[{index}/{len(queue)}] {asset.key}…", flush=True)
        # Un fallo transitorio (timeout de red/UI) no debe voltear todo el batch:
        # se reintenta el asset y, si igual falla, se salta al siguiente. Sólo se
        # frena ante N fallos SEGUIDOS (síntoma de bloqueo/logout/cuota agotada).
        ok = False
        for attempt in range(args.retries + 1):
            ok = runner.run(asset)
            if ok:
                break
            if attempt < args.retries:
                print(f"  … reintento {attempt + 1}/{args.retries}", file=sys.stderr)
                time.sleep(args.pause)
        if ok:
            completed.append(asset.key)
            consecutive_failures = 0
            print(f"  ✓ dropbox/{asset.key}.png")
            # Integrar y ARCHIVAR en procesadas/ inmediatamente (robusto ante
            # interrupciones): recorte → atlas → manifest → mueve el original.
            if args.process:
                subprocess.run([py, process_script], check=False)
        else:
            consecutive_failures += 1
            print(f"  ✗ {asset.key} falló ({consecutive_failures} seguidas); "
                  "sigo con el próximo", file=sys.stderr)
            if consecutive_failures >= args.max_consecutive_failures:
                print(f"  ⨯ {consecutive_failures} fallos seguidos: freno para no "
                      "gastar tu cuota (¿bloqueo/logout?)", file=sys.stderr)
                break
        if index < len(queue):
            time.sleep(args.pause)
    print(f"=== FIN: {len(completed)}/{len(queue)} OK, "
          f"{len(queue) - len(completed)} pendientes ===")


if __name__ == "__main__":
    main()
