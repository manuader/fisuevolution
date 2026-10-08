#!/usr/bin/env python3
"""Trae al dropbox un grupo de la tanda de la 2.0 desde el proyecto generador.

El generador nombra cada PNG con SU clave y el juego a veces espera otra
(`ui_oro_autotap` es `ui_shop_auto_tap` en `oro_shop.json`): la entrada de
`prompts.json` lo dice con `generado_como`. Un mismo PNG puede alimentar dos
claves (el ×2 y el ×3 de ingresos comparten ícono).

    .venv/bin/python scripts/traer_tanda.py pijama
    .venv/bin/python scripts/traer_tanda.py ui --dry-run
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from process_dropbox import DROPBOX, PIPELINE  # noqa: E402

GENERADOR = (
    Path.home() / "Desktop" / "projects" / "automatic-image-generation"
    / "projects" / "fisu-evolution-v2" / "output"
)

GRUPOS = {
    "npc": lambda e: e["category"] == "npc",
    "pijama": lambda e: e["category"] == "skinfam" and e["assetKey"].endswith("__pijama"),
    "gaucho": lambda e: e["category"] == "skinfam" and e["assetKey"].endswith("__gaucho"),
    "dinosaurio": lambda e: e["category"] == "skinfam" and e["assetKey"].endswith("__dinosaurio"),
    "ui": lambda e: e["category"] == "ui",
    "fondos": lambda e: e["category"] == "background",
}


def entradas_v2() -> list[dict]:
    prompts = json.loads((PIPELINE / "prompts" / "prompts.json").read_text())
    return [e for e in prompts if e.get("tanda") == "v2"]


def origen(entry: dict) -> Path:
    return GENERADOR / f"{entry.get('generado_como', entry['assetKey'])}.png"


def traer(grupo: str, dropbox: Path = DROPBOX, dry_run: bool = False) -> list[str]:
    elegidas = sorted((e for e in entradas_v2() if GRUPOS[grupo](e)), key=lambda e: e["assetKey"])
    faltan = [str(origen(e)) for e in elegidas if not origen(e).exists()]
    if faltan:
        raise FileNotFoundError(f"faltan en el generador: {faltan}")
    if not dry_run:
        dropbox.mkdir(parents=True, exist_ok=True)
        for entry in elegidas:
            shutil.copyfile(origen(entry), dropbox / f"{entry['assetKey']}.png")
    return [e["assetKey"] for e in elegidas]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("grupo", choices=sorted(GRUPOS))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    traidas = traer(args.grupo, dry_run=args.dry_run)
    print(f"{'se traerían' if args.dry_run else 'traídas'}: {len(traidas)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
