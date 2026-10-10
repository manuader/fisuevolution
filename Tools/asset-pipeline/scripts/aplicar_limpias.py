#!/usr/bin/env python3
"""Lleva al juego los sprites que el dueno limpio con el balde de islas.

`balde_islas.py` arma la pagina; ahi se pintan de rojo las islas que sobran y se
guarda: `servir.py` deja la imagen en `limpias/<sprite>.png` y lo pintado en
`marcas.json`. Este script mete cada una en su atlas, en @2x y @3x.

    .venv/bin/python scripts/aplicar_limpias.py --dry-run
    .venv/bin/python scripts/aplicar_limpias.py
    .venv/bin/python scripts/aplicar_limpias.py --carpeta ~/Desktop/projects/islas-review

La imagen no se toma tal cual la bajo el navegador: el canvas premultiplica el
alfa y en los bordes semitransparentes redondea el color. Se rehace aca, desde el
mismo PNG del juego y con las mismas islas, que da los pixeles exactos. Por eso
se exige que el PNG del juego sea el mismo sobre el que se pinto (la huella
`origen`): si cambio despues, las islas pueden no ser las mismas y ese sprite se
saltea. Un PNG de `limpias/` sin marcas (puesto a mano) entra tal cual.

Igual que `aplicar_revision.py`, anota cada sprite tocado en la lista de elegidos
a mano de `recut_assets.py`, para que un recut futuro no se lo lleve puesto.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

from aplicar_revision import elegidos_a_mano, escribir_elegidos_a_mano  # noqa: E402
from balde_islas import SALIDA, catalogo, huella, limpiar  # noqa: E402
from process_dropbox import RESOURCES, destination, export_atlas  # noqa: E402


def limpia(clave: str, marca: dict | None, fuente: Path, carpeta: Path) -> tuple[Image.Image | None, str]:
    """(imagen limpia o None, por que). None con motivo vacio = no hay nada que sacar."""
    if marca is None:
        png = carpeta / "limpias" / f"{clave}.png"
        return Image.open(png).convert("RGBA"), "PNG de limpias/ sin marcas, entra tal cual"
    if not marca.get("rojas"):
        return None, ""
    if marca.get("origen") and marca["origen"] != huella(fuente):
        return None, "el PNG del juego cambio desde que se pinto: volve a armar la pagina y a revisarlo"
    rgba = np.array(Image.open(fuente).convert("RGBA"))
    return Image.fromarray(limpiar(rgba, marca["rojas"]), mode="RGBA"), ""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--carpeta", type=Path, default=SALIDA, help="la carpeta de la revision")
    parser.add_argument("--dry-run", action="store_true", help="decir que haria, sin tocar nada")
    parser.add_argument("--solo", action="append", default=[], metavar="CLAVE")
    args = parser.parse_args()

    carpeta = args.carpeta.expanduser()
    marcas_json = carpeta / "marcas.json"
    marcas = json.loads(marcas_json.read_text()) if marcas_json.exists() else {}
    marcas = {c: m for c, m in marcas.items() if m.get("listo")}
    sueltas = {p.stem for p in (carpeta / "limpias").glob("*.png")} - set(marcas)
    claves = sorted(set(marcas) | sueltas)
    if args.solo:
        claves = [c for c in claves if c in set(args.solo)]
    if not claves:
        raise SystemExit(f"No hay nada guardado en {carpeta} todavia.")

    entradas = catalogo()
    puestas, sin_cambios, fallaron = [], [], []
    for clave in claves:
        entrada = entradas.get(clave)
        if entrada is None:
            fallaron.append((clave, "no esta en prompts.json"))
            continue
        atlas, sprite, _ = destination(entrada)
        fuente = RESOURCES / atlas / f"{sprite}@3x.png"
        if not fuente.exists():
            fallaron.append((clave, f"no esta en el juego ({atlas}/{sprite})"))
            continue
        imagen, motivo = limpia(clave, marcas.get(clave), fuente, carpeta)
        if imagen is None and motivo:
            fallaron.append((clave, motivo))
            continue
        if imagen is None:
            sin_cambios.append(clave)
            continue
        rojas = len(marcas.get(clave, {}).get("rojas", []))
        detalle = f"{rojas} islas fuera" if rojas else motivo
        if not args.dry_run:
            export_atlas(imagen, entrada, atlas, sprite)
        puestas.append(clave)
        print(f"  ✓ {clave} → {atlas}/{sprite} ({detalle})", flush=True)

    # Que el recut no las pise (las de oro y diamante ya las saltea solo).
    antes = elegidos_a_mano()
    ahora = antes | {c for c in puestas if not c.endswith(("__oro", "__diamante"))}
    if ahora != antes and not args.dry_run:
        escribir_elegidos_a_mano(ahora)

    verbo = "se aplicarian" if args.dry_run else "aplicadas"
    print(f"\n{verbo}: {len(puestas)}")
    if ahora != antes:
        print(f"elegidos a mano en recut_assets.py: {len(antes)} → {len(ahora)}")
    if sin_cambios:
        print(f"revisadas sin nada que sacar: {len(sin_cambios)}")
    if fallaron:
        print(f"\nno se aplicaron ({len(fallaron)}):")
        for clave, motivo in fallaron:
            print(f"  ✗ {clave}: {motivo}")
    return 1 if fallaron else 0


if __name__ == "__main__":
    raise SystemExit(main())
