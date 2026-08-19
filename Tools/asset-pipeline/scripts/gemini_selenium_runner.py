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

# Errores de Selenium que significan "el DOM cambió debajo nuestro", NO "se
# rompió todo". Se importan de forma defensiva porque el módulo se puede cargar
# sin selenium instalado (los tests de cola y de PNG no lo necesitan).
try:  # pragma: no cover - depende del entorno
    from selenium.common.exceptions import (
        StaleElementReferenceException,
        WebDriverException,
    )
    TRANSIENT_DOM_ERRORS: tuple = (StaleElementReferenceException,)
    BROWSER_ERRORS: tuple = (WebDriverException,)
except ImportError:  # pragma: no cover
    TRANSIENT_DOM_ERRORS = ()
    BROWSER_ERRORS = ()


def _applescript_string(text: str) -> str:
    """Literal AppleScript seguro para `keystroke` (escapa \\ y comillas)."""
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + escaped + '"'


#: Tipeo por tandas. El 2026-08-16, con la máquina cargada (varios frontends de
#: agente abiertos a la vez), escribir el prompt entero en UN `keystroke` falló
#: tres veces seguidas: `ui_tab_upgrades` escribió 0 de 2099 caracteres y
#: `ui_tab_gifts` 0 de 2079 —otra ventana se robó el frente DURANTE los varios
#: segundos que dura esa única llamada, así que las teclas aterrizaron en otra
#: app— y `ui_tab_skins` 2146 de 2150, la cola de eventos se comió cuatro.
#: Cortar en tandas acota el daño de cada pérdida y, sobre todo, abre un hueco
#: entre tanda y tanda para volver a preguntar quién está al frente.
TYPE_CHUNK_CHARS = 250
TYPE_PAUSE_SECONDS = 0.25
#: Intentos de recuperar el frente para TODO el prompt (no por tanda): si tres
#: `activate` seguidos no alcanzan, el ladrón no es una ventana de paso.
FOCUS_RECOVERIES = 3
#: Lo que tarda macOS en dejar a Chrome adelante después de `activate`.
FOCUS_SETTLE_SECONDS = 1.0
#: Techo para la consulta de frontmost: corre ~9 veces por asset, así que un
#: System Events colgado frenaría el batch entero si esperara para siempre.
FRONTMOST_TIMEOUT_SECONDS = 10
#: Nombre del proceso tal como lo reporta System Events (`launch_gemini_chrome`
#: abre siempre Chrome estable, nunca Canary).
CHROME_PROCESS_NAME = "Google Chrome"


def chunk_prompt(prompt: str, size: int = TYPE_CHUNK_CHARS) -> list[str]:
    """Parte el prompt en tandas de `size` caracteres sin tocar el contenido.

    Invariante que sostiene todo lo demás: ``"".join(chunk_prompt(p, n)) == p``
    para cualquier `p` y cualquier `n`. Nada de `strip`, nada de normalizar
    saltos de línea, nada de cortar por palabra: el corte es puramente
    posicional, así que lo que se tipea en tandas es carácter por carácter lo
    mismo que tipeaba la llamada única. Si esto se "mejorara" recortando
    espacios, `prompt_landed` —que compara el arranque— lo rechazaría, y con
    razón: sería otro prompt.
    """
    step = max(1, int(size))
    return [prompt[index:index + step] for index in range(0, len(prompt), step)]


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
        except (GenerationBlocked, OSError, RuntimeError) + BROWSER_ERRORS as error:
            self.checkpoint.record_failure(asset.key, str(error))
            return False
        mark_asset_done(asset)
        self.checkpoint.record_success(asset.key, destination)
        return True


class GeminiBrowser:
    """Adaptador pequeño y deliberadamente conservador para la web de Gemini."""

    def __init__(
        self,
        port: int = 9222,
        timeout: int = 180,
        ref_threshold: float = 4,
        type_chunk: int = TYPE_CHUNK_CHARS,
        type_pause: float = TYPE_PAUSE_SECONDS,
    ):
        self.port = port
        self.timeout = timeout
        # Tamaño de tanda y respiro entre tandas al tipear el prompt (ver
        # TYPE_CHUNK_CHARS). El piso del tamaño lo pone `chunk_prompt`, que es
        # quien tiene que aguantar cualquier número: una sola fuente de verdad.
        self.type_chunk = int(type_chunk)
        self.type_pause = max(0.0, float(type_pause))
        #: stderr de la última consulta fallida por el proceso al frente.
        self._frontmost_error = ""
        # Distancia MAE por debajo de la cual una imagen se considera "es la
        # referencia". Bajó de 12 a 4 con las skins de oro (2026-08-19): la
        # huella es un thumbnail de 32x32 y el fondo blanco ocupa el 74% del
        # cuadro, así que una variante que conserva la pose queda MUY cerca del
        # original — el dorado del Fisura medía 9.51 y se descartaba solo, y ni
        # un personaje enteramente NEGRO pasa de 25.8. Medido del otro lado: la
        # misma imagen re-codificada o reescalada no supera 0.14, así que 4
        # separa las dos poblaciones con margen. Con 12 el runner esperaba el
        # timeout entero de cada asset sin encontrar nunca un candidato válido.
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
        last_transient = None
        while time.monotonic() < deadline:
            self._check_blocked()
            try:
                result = action()
            except TRANSIENT_DOM_ERRORS as error:
                # El DOM se rehizo mientras lo leíamos. Pasa de verdad: cuando
                # Gemini muestra un mensaje de error propio, o mientras
                # reemplaza el placeholder por la imagen final, el nodo que
                # teníamos en la mano deja de existir. Es exactamente la
                # condición "todavía no está listo", así que se reintenta hasta
                # el deadline en vez de abortar.
                last_transient = error
                time.sleep(0.5)
                continue
            if result:
                return result
            time.sleep(0.5)
        if last_transient is not None:
            raise GenerationBlocked(
                f"timeout esperando {description} (el DOM se rehizo: {type(last_transient).__name__})"
            )
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

    @staticmethod
    def prompt_landed(editor_text: str, prompt: str) -> bool:
        """¿El prompt llegó de verdad al editor?

        No compara exacto a propósito: `keystroke` de System Events puede
        maltratar algún carácter suelto (la raya larga, sobre todo) y no vale
        abortar una corrida de 53 assets por eso. Pide dos cosas que un fallo
        real nunca cumple: que el arranque coincida y que no falte texto.

        Los dos fallos que tiene que atrapar son el vacío —el keystroke cayó en
        otro lado— y el truncado, que es peor: genera arte contra medio prompt
        y lo da por bueno.
        """
        def norm(s: str) -> str:
            return " ".join((s or "").split())

        got, want = norm(editor_text), norm(prompt)
        if not got or not want:
            return False
        cabeza = min(40, len(want))
        return got[:cabeza] == want[:cabeza] and len(got) >= int(len(want) * 0.9)

    #: Quién tiene el frente AHORA. Es la única pregunta que distingue "el
    #: keystroke va a aterrizar en Gemini" de "el keystroke se lo come otra app".
    FRONTMOST_SCRIPT = (
        'tell application "System Events" to get name of first application '
        "process whose frontmost is true"
    )

    def _frontmost_app(self) -> str:
        """Nombre del proceso al frente, o "" si System Events no contestó."""
        try:
            result = subprocess.run(
                ["osascript", "-e", self.FRONTMOST_SCRIPT],
                capture_output=True, text=True, timeout=FRONTMOST_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            # Esta consulta corre ~9 veces por asset: un System Events colgado no
            # puede quedarse con el batch entero. Se trata como "no sé quién está
            # al frente", que ya tiene camino (recuperar y, si insiste, abortar).
            self._frontmost_error = (
                f"System Events no contestó en {FRONTMOST_TIMEOUT_SECONDS}s"
            )
            return ""
        if result.returncode != 0:
            # Sin permiso de Accesibilidad esta consulta falla igual que el
            # keystroke. Se guarda el error para que el abort lo diga en vez de
            # inventar un ladrón que no existe.
            self._frontmost_error = result.stderr.strip()
            return ""
        self._frontmost_error = ""
        return result.stdout.strip()

    def _recover_focus(self) -> None:
        """Pide el frente para Chrome y le devuelve el foco DOM al compose box.

        Acá NO se manda ninguna tecla: `activate` es un pedido, no una garantía,
        y hasta que la próxima consulta no confirme quién está adelante
        cualquier keystroke puede aterrizar en la app ajena. El click de Selenium
        es seguro porque va por CDP al DOM, tenga Chrome el frente o no."""
        subprocess.run(["osascript", "-e", 'tell application "Google Chrome" to activate'])
        time.sleep(FOCUS_SETTLE_SECONDS)
        self._focus_compose()

    def _restore_caret(self) -> None:
        """Manda el cursor al final del texto ya escrito (cmd+↓).

        Hace falta porque `_focus_compose` clickea el CENTRO del compose box: con
        medio prompt adentro, eso deja el cursor en el medio y la tanda siguiente
        se intercalaría. Va DOS veces a propósito: la tecla es idempotente, así
        que la primera hace de pre-tipeo descartable para la que se traga la app
        después de un `activate` —el mismo motivo por el que existe el espacio
        del arranque—. Y si aun así no llega, `_verify_prefix` lo atrapa."""
        for _ in range(2):
            subprocess.run([
                "osascript", "-e",
                'tell application "System Events" to key code 125 using command down',
            ])
            time.sleep(0.2)

    def _ensure_chrome_frontmost(self, remaining: int, restore_caret: bool = False) -> int:
        """Chrome al frente antes de tipear; devuelve los intentos que sobran.

        El presupuesto es de TODO el prompt, no de cada tanda: una ventana que
        aparece y se va cuesta un intento y la corrida sigue, pero una app que se
        queda adelante agota los tres y aborta ANTES de teclear en ella."""
        frontmost = self._frontmost_app()
        recuperado = False
        while frontmost != CHROME_PROCESS_NAME:
            if remaining <= 0:
                quien = (
                    f"«{frontmost}»" if frontmost else
                    "una app que System Events no supo nombrar (¿falta permiso de "
                    f"Accesibilidad? {self._frontmost_error})"
                )
                raise GenerationBlocked(
                    "no pude devolverle el foco a Chrome para escribir el prompt: al "
                    f"frente está {quien} después de {FOCUS_RECOVERIES} intentos. "
                    "Cerrá o minimizá esa ventana antes de reintentar."
                )
            remaining -= 1
            # Que se vea en la corrida: el dueño tiene que poder auditar QUÉ
            # assets pasaron por el camino raro sin leer el checkpoint.
            print(
                f"  ⚠️  el foco se lo llevó «{frontmost or '¿?'}»; recupero y sigo "
                f"(quedan {remaining} intentos)",
                file=sys.stderr, flush=True,
            )
            self._recover_focus()
            recuperado = True
            frontmost = self._frontmost_app()
        if recuperado and restore_caret:
            # Recién ACÁ, con Chrome confirmado adelante, se toca el teclado.
            self._restore_caret()
        return remaining

    @staticmethod
    def _same_text(one: str, other: str) -> bool:
        """Igualdad con el mismo criterio de espacios que `prompt_landed`."""
        return " ".join((one or "").split()) == " ".join((other or "").split())

    def _verify_prefix(self, editor, prompt: str, escritos: int, momento: str) -> None:
        """Aborta si el editor no tiene EXACTAMENTE lo tipeado hasta acá.

        Es la red del único fallo nuevo que trae la recuperación de foco.
        `_focus_compose` clickea el CENTRO del compose box: si el cursor no
        vuelve al final del texto —el `cmd+↓` puede no alcanzar— la tanda
        siguiente se intercala EN EL MEDIO. Lo que queda tiene el largo justo y
        los primeros 40 caracteres en su lugar, así que `prompt_landed` lo
        aprueba y se gastaría cuota generando contra un prompt barajado. Ese
        fallo no existía antes del tipeo por tandas: toda perturbación de foco
        daba vacío o truncado, y el guard lo atrapaba.

        Compara contra el prefijo esperado, que sí detecta el intercalado, y es
        estricto a propósito: sobre el camino raro un carácter maltratado cuesta
        un reintento (cuota: cero), no una imagen contra un prompt roto.
        """
        escrito = editor.get_attribute("innerText") or ""
        if self._same_text(escrito, prompt[:escritos]):
            return
        raise GenerationBlocked(
            f"el editor no coincide con lo tipeado hasta acá ({momento}): tiene "
            f"{len(escrito.strip())} caracteres y esperaba {escritos}. Probable: "
            "el cursor quedó en el medio del texto al volver el foco y la tanda "
            "se intercaló. No envío: sería cuota gastada contra un prompt barajado."
        )

    def _submit(self, prompt: str) -> None:
        # El prompt es el texto EXACTO del .md del asset (nunca inventado).
        # Gemini exige input "trusted": send_keys/CDP no habilitan el botón de
        # enviar. Se escribe con keystrokes reales de macOS (System Events),
        # indistinguibles de un humano.
        #
        # ⚠️ 2026-08-06: acá decía "NO clickear el campo, el foco OS-level viene
        # del paste". Eso valía para la UI vieja. La nueva (`new-input-ui`, un
        # editor Quill) **suelta el foco al `<body>` después de pegar la
        # imagen**, así que los keystrokes caían en la página y se enviaba la
        # referencia sin prompt. Medido con `document.activeElement`.
        self._focus_compose()
        subprocess.run(["osascript", "-e", 'tell application "Google Chrome" to activate'])
        time.sleep(1.0)
        # ⚠️ La pregunta por el frente va ANTES del pre-tipeo: el espacio y el
        # Delete descartables son teclas de verdad, y si el ladrón ya está
        # adelante las cobra él. Un Backspace suelto en Mail borra el mail
        # seleccionado. Hasta no saber quién está al frente no se teclea NADA.
        recoveries = self._ensure_chrome_frontmost(FOCUS_RECOVERIES)
        # Pre-tipeo descartable: la app a veces pierde el primer carácter tras activate.
        subprocess.run(["osascript", "-e", 'tell application "System Events" to keystroke " "'])
        time.sleep(0.3)
        subprocess.run(["osascript", "-e", 'tell application "System Events" to key code 51'])  # Delete
        time.sleep(0.2)

        # El editor se busca ACÁ, antes de tipear: además de la verificación
        # final hace falta para auditar lo ya escrito cada vez que hubo que
        # recuperar el foco (ver `_verify_prefix`).
        editor = self._find_first([
            ("CSS_SELECTOR", "[contenteditable='true']"),
            ("CSS_SELECTOR", "textarea"),
        ])
        if editor is None:
            raise GenerationBlocked("no encontré el editor para verificar el prompt")

        # ⚠️ 2026-08-16: el prompt entero iba en UN `keystroke` de 2000+ caracteres.
        # Esa llamada tarda varios segundos y en una máquina cargada es una eternidad:
        # si otra ventana se pone adelante mientras dura, TODO el texto se lo lleva
        # ella (0 de 2099 caracteres, medido) y no hay forma de enterarse hasta el
        # final. Ahora se tipea en tandas cortas y ANTES DE CADA UNA se pregunta
        # quién está al frente: el robo de foco cuesta una tanda, no el prompt.
        chunks = chunk_prompt(prompt, self.type_chunk)
        escritos = 0
        for index, chunk in enumerate(chunks, 1):
            quedaban = recoveries
            recoveries = self._ensure_chrome_frontmost(recoveries, restore_caret=escritos > 0)
            recuperado = recoveries != quedaban
            if recuperado and escritos:
                # ¿Volvió intacto lo que ya estaba escrito?
                self._verify_prefix(editor, prompt, escritos, "al recuperar el foco")
            script = 'tell application "System Events" to keystroke %s' % _applescript_string(chunk)
            result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
            if result.returncode != 0:
                raise GenerationBlocked(
                    "System Events no pudo escribir (¿falta permiso de Accesibilidad?): "
                    + result.stderr.strip()
                    + f" [tanda {index} de {len(chunks)}]"
                )
            escritos += len(chunk)
            time.sleep(self.type_pause)
            if recuperado:
                # Y sobre todo: ¿entró DONDE correspondía? Esta es la pregunta
                # cara: si el cursor quedó en el medio, la tanda se intercaló.
                self._verify_prefix(
                    editor, prompt, escritos, "en la tanda que siguió a la recuperación"
                )

        # ⚠️ El botón de enviar NO sirve como confirmación de que el texto entró:
        # la imagen adjunta sola ya lo habilita (medido: `disabled == False` con
        # el editor en `ql-blank`). Por eso el runner mandó referencias sin
        # prompt sin enterarse. Se comprueba el editor, que es el único que sabe.
        escrito = editor.get_attribute("innerText") or ""
        if not self.prompt_landed(escrito, prompt):
            raise GenerationBlocked(
                "el prompt no llegó al editor: se escribieron "
                f"{len(escrito.strip())} de {len(prompt)} caracteres. "
                "Sin esto se enviaría la referencia sin instrucción."
            )

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
        from io import BytesIO

        from PIL import Image

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

        todas = driver.find_elements("tag name", "img")
        medidas = sorted(
            (int(i.get_attribute("naturalWidth") or 0) for i in todas), reverse=True
        )
        # Diagnóstico: si la generada entra como preview chico, el filtro de 512
        # la deja afuera y el único candidato es la referencia. Se imprime sólo
        # cuando cambia, para no inundar el log en cada poll de `_wait_for`.
        reporte = ",".join(str(m) for m in medidas[:8] if m)
        if getattr(self, "_ultimo_reporte", None) != reporte:
            self._ultimo_reporte = reporte
            print(f"  · imgs en pantalla (ancho natural): {reporte or 'ninguna'}",
                  file=sys.stderr, flush=True)

        candidates = sorted(
            (i for i in todas
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
                    print("  · descarte: no se pudo bajar la imagen cross-origin",
                          file=sys.stderr, flush=True)
                    continue
            if not self._has_content(raw):
                print("  · descarte: imagen vacía o de color plano (aún renderizando)",
                      file=sys.stderr, flush=True)
                continue  # placeholder vacío/transparente: esperar el render real
            if ref_fp is not None:
                distancia = self._fingerprint_distance(self._fingerprint(raw), ref_fp)
                if distancia < self.ref_threshold:
                    # Se guarda lo descartado para poder MIRARLO: distinguir "es
                    # la referencia" de "es el generado que se parece demasiado"
                    # no se puede hacer con el numero solo.
                    depurar = PIPELINE / "state" / "descartes"
                    depurar.mkdir(parents=True, exist_ok=True)
                    ancho = Image.open(BytesIO(raw)).width
                    (depurar / f"mae{distancia:05.2f}_w{ancho}.png").write_bytes(raw)
                    print(f"  · descarte: se parece a la referencia "
                          f"(MAE {distancia:.2f} < {self.ref_threshold})",
                          file=sys.stderr, flush=True)
                    continue  # es la referencia; seguir buscando/esperando
                print(f"  · candidato aceptado (MAE {distancia:.2f})",
                      file=sys.stderr, flush=True)
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
    parser.add_argument("--process", action="store_true",
                        help="integra y archiva cada asset APENAS se genera, no al "
                             "final. Obligatorio cuando un asset de la cola usa como "
                             "referencia a otro de la misma cola (las caras adjuntan "
                             "el cuerpo del propio personaje)")
    parser.add_argument("--port", type=int, default=9222, help="puerto Chrome debug")
    parser.add_argument("--timeout", type=int, default=180, help="timeout de UI/descarga por asset")
    parser.add_argument("--retries", type=int, default=1,
                        help="reintentos por asset ante un fallo transitorio")
    parser.add_argument("--max-consecutive-failures", type=int, default=3,
                        help="frena el batch tras N fallos SEGUIDOS (bloqueo/logout/cuota)")
    parser.add_argument("--type-chunk", type=int, default=TYPE_CHUNK_CHARS,
                        help="caracteres por tanda de tipeo. Bajalo si la máquina "
                             "está cargada y se pierden caracteres")
    parser.add_argument("--type-pause", type=float, default=TYPE_PAUSE_SECONDS,
                        help="segundos de respiro entre tandas de tipeo")
    parser.add_argument("--ref-threshold", type=float, default=4,
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
        GeminiBrowser(
            args.port, args.timeout, args.ref_threshold,
            type_chunk=args.type_chunk, type_pause=args.type_pause,
        ),
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
