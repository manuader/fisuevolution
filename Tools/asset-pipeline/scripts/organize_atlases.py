#!/usr/bin/env python3
"""Exporta approved/ a los atlas nativos de Xcode como PNG @2x/@3x (SIN @1x).

Destinos bajo FisuEvolution/Resources/ (nombre EXACTO = campo atlas del
manifest, lowercase):
    earth.atlas/  cosmic.atlas/  specials.atlas/  ui.atlas/   (fx y logo -> ui.atlas)
    Backgrounds/  (archivos sueltos, no atlas)

Master: si existe approved/masters/{key}.png (1536, p.ej. upscaleado a mano
con RealESRGAN) se usa ese; si no, se upscalea el approved 768 -> 1536:
  - con `realesrgan-ncnn-vulkan` si esta en el PATH (config: RealESRGAN_x2)
  - fallback Pillow LANCZOS (con aviso; suficiente para flat vector)

Tamanos: @3x = 1536, @2x = 1024 (base logica 512pt).
Reanudable: saltea si el destino existe y es mas nuevo que el approved.

Uso:  python3 scripts/organize_atlases.py [--tanda N] [--force]
"""
import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import (  # noqa: E402
    ROOT, load_config, load_prompts, entries_for_tanda, resources_root,
)

MASTER_SIZE = 1536  # 768 x2
SIZES = {"@3x": 1536, "@2x": 1024}  # NO @1x: iOS 17+ no lo usa


def load_master(config, key, approved_path):
    """Devuelve una PIL.Image de 1536 (master dedicado o upscale del approved)."""
    from PIL import Image

    masters_dir = ROOT / config["paths"]["masters"]
    master_path = masters_dir / f"{key}.png"
    if master_path.exists():
        img = Image.open(master_path).convert("RGBA")
        if img.width != MASTER_SIZE:
            img = img.resize((MASTER_SIZE, MASTER_SIZE), Image.LANCZOS)
        return img

    use_realesrgan = config["generation"]["upscale"].lower().startswith("realesrgan")
    if use_realesrgan and shutil.which("realesrgan-ncnn-vulkan"):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / f"{key}.png"
            subprocess.run(
                ["realesrgan-ncnn-vulkan", "-i", str(approved_path), "-o", str(out), "-s", "2"],
                check=True, capture_output=True,
            )
            img = Image.open(out).convert("RGBA")
            if img.width != MASTER_SIZE:
                img = img.resize((MASTER_SIZE, MASTER_SIZE), Image.LANCZOS)
            return img

    if use_realesrgan and not load_master._warned:
        load_master._warned = True
        print("  [AVISO] realesrgan-ncnn-vulkan no esta en el PATH; upscale con "
              "Pillow LANCZOS (para flat vector alcanza).")
    img = Image.open(approved_path).convert("RGBA")
    return img.resize((MASTER_SIZE, MASTER_SIZE), Image.LANCZOS)


load_master._warned = False


def dest_dir(config, entry):
    res = resources_root(config)
    if entry["category"] == "background":
        return res / config["paths"]["backgrounds_dir"]
    return res / config["paths"]["atlases"][entry["atlas"]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tanda", type=int, help="limitar a una tanda (default: todo approved/)")
    parser.add_argument("--force", action="store_true", help="re-exportar aunque este al dia")
    args = parser.parse_args()

    config = load_config()
    entries = load_prompts(config)
    if args.tanda is not None:
        entries = entries_for_tanda(entries, args.tanda)

    approved_dir = ROOT / config["paths"]["approved"]
    exported = skipped = missing = 0

    for e in entries:
        key = e["assetKey"]
        src = approved_dir / f"{key}.png"
        if not src.exists():
            missing += 1
            continue

        out_dir = dest_dir(config, e)
        out_dir.mkdir(parents=True, exist_ok=True)

        targets = {suffix: out_dir / f"{key}{suffix}.png" for suffix in SIZES}
        up_to_date = all(
            t.exists() and t.stat().st_mtime >= src.stat().st_mtime
            for t in targets.values()
        )
        if up_to_date and not args.force:
            skipped += 1
            continue

        master = load_master(config, key, src)
        from PIL import Image

        for suffix, size in SIZES.items():
            img = master if size == master.width else master.resize((size, size), Image.LANCZOS)
            img.save(targets[suffix], optimize=True)
        rel = out_dir.relative_to(resources_root(config))
        print(f"  [EXPORT] {key} -> Resources/{rel}/{key}@2x.png + @3x.png")
        exported += 1

    print(f"\nExportados {exported}, al dia {skipped}, sin approved {missing}.")
    if missing and args.tanda is not None:
        print("(los faltantes de la tanda todavia no pasaron QA)")
    print("Siguiente paso: python3 scripts/update_manifest.py")


if __name__ == "__main__":
    main()
