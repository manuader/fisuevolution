#!/usr/bin/env python3
"""Recorte de fondo batch con rembg (modelo isnet-general-use, bordes limpios).

raw/tanda_N/{key}.png -> cutout/tanda_N/{key}.png

- Los BACKGROUNDS no se recortan (son escenas full-canvas): se copian tal cual.
- Reanudable: saltea si el output ya existe (usar --force para rehacer).
- rembg se importa dentro de la funcion: el resto del pipeline no lo necesita.

Uso:  python3 scripts/cutout_batch.py --tanda 1 [--force]
"""
import argparse
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import ROOT, load_config, load_prompts, entries_for_tanda  # noqa: E402


def cutout_image(session, src, dst):
    """Recorta el fondo de src y guarda PNG RGBA en dst."""
    from rembg import remove  # import perezoso (pip install rembg)

    data = src.read_bytes()
    result = remove(data, session=session)
    dst.write_bytes(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tanda", type=int, required=True, help="numero de tanda (1-5)")
    parser.add_argument("--force", action="store_true", help="rehacer aunque exista el output")
    args = parser.parse_args()

    config = load_config()
    entries = entries_for_tanda(load_prompts(config), args.tanda)
    if not entries:
        raise SystemExit(f"[ERROR] La tanda {args.tanda} no existe en prompts.json")

    raw_dir = ROOT / config["paths"]["raw"] / f"tanda_{args.tanda}"
    out_dir = ROOT / config["paths"]["cutout"] / f"tanda_{args.tanda}"
    out_dir.mkdir(parents=True, exist_ok=True)

    pending = []
    for e in entries:
        src = raw_dir / f"{e['assetKey']}.png"
        dst = out_dir / f"{e['assetKey']}.png"
        if not src.exists():
            print(f"  [FALTA RAW] {src.relative_to(ROOT)} — genera primero esta imagen")
            continue
        if dst.exists() and not args.force:
            print(f"  [SKIP]      {e['assetKey']} (ya existe)")
            continue
        pending.append((e, src, dst))

    if not pending:
        print("Nada para recortar.")
        return

    session = None
    done = 0
    for e, src, dst in pending:
        if e["category"] == "background":
            shutil.copyfile(src, dst)
            print(f"  [COPY]      {e['assetKey']} (background: sin recorte)")
        else:
            if session is None:
                from rembg import new_session  # import perezoso

                print("Cargando modelo rembg isnet-general-use...")
                session = new_session("isnet-general-use")
            cutout_image(session, src, dst)
            print(f"  [CUTOUT]    {e['assetKey']}")
        done += 1

    print(f"Listo: {done} imagenes en {out_dir.relative_to(ROOT)}")
    print(f"Siguiente paso: python3 scripts/qa_clip.py --batch {args.tanda}")


if __name__ == "__main__":
    main()
