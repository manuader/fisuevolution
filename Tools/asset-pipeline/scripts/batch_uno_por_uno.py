#!/usr/bin/env python3
"""Corre el batch de Gemini un asset por proceso, verificando cada uno.

El runner en modo cola es eficiente pero comparte un proceso entre los 86
assets: si uno se cuelga y hay que matarlo, se lleva puesta la corrida entera y
al relanzar vuelve a empezar por el primero — que fue exactamente lo que hizo
regenerar al Fisura una y otra vez.

Acá cada asset es una invocación aislada con `--only`. Si uno falla, muere solo:
el siguiente arranca limpio y los que ya salieron bien quedan fuera de la cola
porque el runner les marca `- **estado**: hecho` recién después de verificar el
PNG en disco.

    .venv/bin/python scripts/batch_uno_por_uno.py --filtro __oro
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from gemini_selenium_runner import (  # noqa: E402
    DROPBOX,
    PROCESSED,
    PROMPTS_DIR,
    parse_asset,
)

PIPELINE = Path(__file__).resolve().parents[1]
RUNNER = Path(__file__).resolve().parent / "gemini_selenium_runner.py"
VENV = PIPELINE / ".venv" / "bin" / "python"


def chrome_vivo(puerto: int = 9222) -> bool:
    """Sin el Chrome dedicado no hay nada que hacer: sin esto, cada asset
    fallaria al instante y el batch quemaria los 86 en segundos sin generar nada."""
    import urllib.error
    import urllib.request

    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{puerto}/json/version", timeout=5):
            return True
    except (urllib.error.URLError, OSError):
        return False


def ya_esta(key: str) -> bool:
    """Un asset esta listo cuando su PNG existe, este en dropbox o ya archivado."""
    return (DROPBOX / f"{key}.png").exists() or (PROCESSED / f"{key}.png").exists()


def pendientes(filtro: str | None) -> list[str]:
    cola = []
    for path in sorted(PROMPTS_DIR.glob("[0-9][0-9]*.md")):
        if path.name == "00_INDICE.md":
            continue
        asset = parse_asset(path)
        if asset.state == "hecho" or ya_esta(asset.key):
            continue
        if filtro and filtro not in asset.key:
            continue
        cola.append(asset.key)
    return cola


def generar(key: str, timeout: int, umbral: float) -> bool:
    """Una invocacion, un asset. Devuelve si el PNG quedo en disco."""
    # `--retries 0` es deliberado: el runner reintenta con `range(retries + 1)`,
    # asi que un 1 serian DOS generaciones por invocacion y, multiplicado por los
    # reintentos de este driver, hasta cuatro por asset. La politica de reintento
    # vive en un solo lugar —aca— y cada invocacion gasta exactamente una.
    orden = [
        str(VENV), str(RUNNER), "--process", "--only", key,
        "--timeout", str(timeout), "--ref-threshold", str(umbral), "--retries", "0",
    ]
    # El colgado se corta desde afuera: el runner ya tiene su propio timeout por
    # imagen, pero si se traba antes de llegar a esperarla nadie lo despierta.
    try:
        subprocess.run(orden, cwd=PIPELINE, timeout=timeout * 3, check=False)
    except subprocess.TimeoutExpired:
        print(f"  (se colgo mas de {timeout * 3}s, lo corto)", flush=True)
    return ya_esta(key)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--filtro", help="subcadena del assetKey, ej: __oro")
    parser.add_argument("--timeout", type=int, default=400)
    parser.add_argument("--ref-threshold", type=float, default=1.5)
    parser.add_argument("--reintentos", type=int, default=2,
                        help="intentos por asset antes de saltearlo")
    parser.add_argument("--pausa", type=int, default=5, help="segundos entre assets")
    args = parser.parse_args()

    if not chrome_vivo():
        print("No hay Chrome de depuracion en :9222. Corre primero:\n"
              "  .venv/bin/python scripts/launch_gemini_chrome.py", flush=True)
        return 1

    cola = pendientes(args.filtro)
    print(f"pendientes: {len(cola)}", flush=True)

    ok, fallados = [], []
    for indice, key in enumerate(cola, 1):
        for intento in range(1, args.reintentos + 1):
            marca = f"[{indice}/{len(cola)}] {key}"
            print(f"{marca} (intento {intento}/{args.reintentos})", flush=True)
            if generar(key, args.timeout, args.ref_threshold):
                print(f"  OK {key}", flush=True)
                ok.append(key)
                break
            print(f"  sin PNG", flush=True)
        else:
            print(f"  SALTEADO {key}", flush=True)
            fallados.append(key)
        if indice < len(cola):
            time.sleep(args.pausa)

    print(f"\n=== FIN: {len(ok)} generados, {len(fallados)} salteados", flush=True)
    if fallados:
        print(f"salteados: {fallados}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
