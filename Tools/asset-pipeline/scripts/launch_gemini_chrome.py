#!/usr/bin/env python3
"""Abre Gemini en un perfil de Chrome aislado y depurable por Selenium."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

PIPELINE = Path(__file__).resolve().parents[1]
DEFAULT_PORT = 9222
GEMINI_URL = "https://gemini.google.com/"


def debug_url(port: int = DEFAULT_PORT) -> str:
    return f"http://127.0.0.1:{port}/json/version"


def chrome_binary() -> str:
    """Encuentra Chrome estable en macOS, Linux o PATH."""
    candidates = [
        shutil.which("google-chrome"),
        shutil.which("Google Chrome"),
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return str(candidate)
    raise RuntimeError("No encontré Google Chrome. Instalalo y volvé a correr el launcher.")


def chrome_command(profile: Path, port: int = DEFAULT_PORT) -> list[str]:
    return [
        chrome_binary(),
        f"--remote-debugging-port={port}",
        f"--user-data-dir={Path(profile)}",
        "--no-first-run",
        "--no-default-browser-check",
        GEMINI_URL,
    ]


def debug_is_ready(port: int = DEFAULT_PORT) -> bool:
    try:
        with urlopen(debug_url(port), timeout=1) as response:
            return response.status == 200
    except (URLError, TimeoutError, OSError):
        return False


def ensure_debug_chrome(port: int = DEFAULT_PORT, profile: Path | None = None) -> bool:
    """Devuelve True si lo lanzó; False si ya había un Chrome depurable."""
    if debug_is_ready(port):
        return False
    profile = profile or PIPELINE / ".chrome-profile"
    profile.mkdir(parents=True, exist_ok=True)
    subprocess.Popen(
        chrome_command(profile, port),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        if debug_is_ready(port):
            return True
        time.sleep(0.25)
    raise RuntimeError(
        f"Chrome abrió pero no expuso {debug_url(port)} en 20 segundos. "
        "Cerrá la ventana Gemini aislada y reintentá."
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--profile", type=Path, default=PIPELINE / ".chrome-profile")
    args = parser.parse_args()
    launched = ensure_debug_chrome(args.port, args.profile)
    message = "Chrome aislado abierto" if launched else "Chrome aislado ya estaba abierto"
    print(f"{message}: {debug_url(args.port)}")
    print("Iniciá sesión en Gemini en ESA ventana si te lo pide; luego corré el runner.")


if __name__ == "__main__":
    main()
