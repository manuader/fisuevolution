#!/usr/bin/env python3
"""Aplica las decisiones por isla que sale de `revision_islas.py`.

Escribe `prompts/islas_de_papel.json` —que es lo que `whitebg_cutout` consulta
para saber que islas encerradas son fondo— y vuelve a recortar e integrar los
assets tocados desde su original.

    pbpaste | .venv/bin/python scripts/aplicar_islas.py -
    .venv/bin/python scripts/aplicar_islas.py ~/Downloads/islas.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

from process_dropbox import PIPELINE, destination, export_atlas  # noqa: E402
from recut_assets import original_de  # noqa: E402
from whitebg_cutout import ISLAS_DE_PAPEL, cutout  # noqa: E402

DATOS = PIPELINE / "prompts" / "islas_de_papel.json"


def leer(donde: str | None) -> dict:
    if donde == "-":
        crudo = sys.stdin.read()
        if not crudo.strip():
            raise SystemExit("No llego nada por stdin. ¿Copiaste el JSON en la pagina?")
        return json.loads(crudo)
    if not donde:
        raise SystemExit(f"Pasame el islas.json, o el JSON por stdin: pbpaste | {Path(sys.argv[0]).name} -")
    ruta = Path(donde).expanduser()
    if not ruta.exists():
        raise SystemExit(f"No existe {ruta}.")
    return json.loads(ruta.read_text())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("islas", nargs="?", default=None)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    decisiones = {k: sorted(set(v)) for k, v in leer(args.islas).items() if v}
    guardado = json.loads(DATOS.read_text()) if DATOS.exists() else {}
    fusion = {**guardado, **decisiones}

    catalogo = {e["assetKey"]: e for e in json.loads((PIPELINE / "prompts" / "prompts.json").read_text())}
    rehechos, fallaron = [], []
    for clave, ids in sorted(decisiones.items()):
        entrada = catalogo.get(clave)
        original = original_de(clave) if entrada else None
        if not entrada or not original.exists():
            fallaron.append((clave, "no está en prompts.json" if not entrada else f"falta {original.name}"))
            continue
        antes = guardado.get(clave, [])
        print(f"  {clave}: {len(ids)} islas de fondo" + (f" (antes {len(antes)})" if antes else ""))
        if args.dry_run:
            continue
        ISLAS_DE_PAPEL[clave] = ids          # que el cutout de esta corrida ya las vea
        atlas, sprite, _ = destination(entrada)
        export_atlas(cutout(Image.open(original), clave), entrada, atlas, sprite)
        rehechos.append(clave)

    if not args.dry_run:
        DATOS.write_text(json.dumps(fusion, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
        print(f"\nguardado en {DATOS.relative_to(PIPELINE)}")
    print(f"{'se recortarian' if args.dry_run else 'recortados de nuevo'}: {len(decisiones if args.dry_run else rehechos)}")
    for clave, motivo in fallaron:
        print(f"  ✗ {clave}: {motivo}")
    return 1 if fallaron else 0


if __name__ == "__main__":
    raise SystemExit(main())
