#!/usr/bin/env python3
"""Procesa las imágenes que el usuario suelta en dropbox/: recorte de fondo →
export @2x/@3x al atlas correcto → entrada en assets_manifest.json.

El nombre del archivo debe ser `<assetKey>.png` (el que indica el .md de
prompts). Corre con el venv del pipeline (rembg/PIL):

    Tools/asset-pipeline/.venv/bin/python scripts/process_dropbox.py
"""

import json
import sys
from pathlib import Path

PIPELINE = Path(__file__).resolve().parent.parent
DROPBOX = PIPELINE / "dropbox"
PROCESSED = DROPBOX / "procesadas"
RESOURCES = PIPELINE.parent.parent / "FisuEvolution" / "Resources"
MANIFEST = RESOURCES / "Data" / "assets_manifest.json"

# assetKey → (carpeta destino, sección del manifest, sufijo de key)
ATLAS_BY_CATEGORY = {
    "character": ("{phase}.atlas", "characters", "_idle"),
    "special": ("specials.atlas", "characters", ""),
    "ui": ("ui.atlas", "ui", ""),
    "fx": ("ui.atlas", "ui", ""),
    "background": ("Backgrounds", "backgrounds", ""),
}


def load_entries() -> dict[str, dict]:
    prompts = json.loads((PIPELINE / "prompts" / "prompts.json").read_text())
    return {e["assetKey"]: e for e in prompts}


def process(image_path: Path, entry: dict, session) -> None:
    from PIL import Image
    from rembg import remove

    category = entry.get("category", "character")
    atlas_template, manifest_section, key_suffix = ATLAS_BY_CATEGORY[category]
    atlas_name = atlas_template.format(phase=entry.get("atlas", "earth"))
    asset_key = entry["assetKey"] + key_suffix

    img = Image.open(image_path).convert("RGBA")

    if category != "background":
        img = remove(img, session=session)

    target_dir = RESOURCES / atlas_name
    target_dir.mkdir(parents=True, exist_ok=True)
    img.resize((1536, 1536), Image.LANCZOS).save(target_dir / f"{asset_key}@3x.png")
    img.resize((1024, 1024), Image.LANCZOS).save(target_dir / f"{asset_key}@2x.png")

    manifest = json.loads(MANIFEST.read_text())
    if manifest_section == "characters":
        manifest["characters"][entry["assetKey"]] = {
            "atlas": atlas_name.replace(".atlas", ""),
            "key": asset_key,
            "anchor": [0.5, 0.1],
            "scale": 1.0,
        }
    elif manifest_section == "backgrounds":
        # BoardScene busca manifest.backgrounds[stage], donde stage es el nombre
        # de etapa SIN el prefijo "bg_" (alley, urban, …, god_realm).
        stage = entry["assetKey"].removeprefix("bg_")
        manifest["backgrounds"][stage] = asset_key
    else:
        manifest[manifest_section][entry["assetKey"]] = asset_key
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))

    PROCESSED.mkdir(exist_ok=True)
    image_path.rename(PROCESSED / image_path.name)
    print(f"  ✓ {entry['assetKey']} → {atlas_name}/{asset_key}@2x/@3x + manifest")


def main() -> None:
    DROPBOX.mkdir(exist_ok=True)
    entries = load_entries()
    pending = sorted(DROPBOX.glob("*.png"))
    if not pending:
        print(f"dropbox vacío: soltá PNGs con nombre <assetKey>.png en {DROPBOX}")
        return

    from rembg import new_session
    session = new_session("isnet-general-use")

    unknown = []
    for image_path in pending:
        key = image_path.stem
        entry = entries.get(key)
        if not entry:
            unknown.append(key)
            continue
        print(f"procesando {key}…")
        process(image_path, entry, session)

    if unknown:
        print(f"\nNOMBRES DESCONOCIDOS (revisar contra el .md): {unknown}")
        sys.exit(1)
    print("\nlisto ✓ — regenerar el proyecto y buildear para verlos en el juego")


if __name__ == "__main__":
    main()
