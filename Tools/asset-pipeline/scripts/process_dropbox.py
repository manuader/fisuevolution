#!/usr/bin/env python3
"""Procesa las imágenes que el usuario suelta en dropbox/: recorte de fondo →
export @2x/@3x al atlas correcto → entrada en assets_manifest.json.

El nombre del archivo debe ser `<assetKey>.png` (el que indica el .md de
prompts). Corre con el venv del pipeline (PIL/numpy/scipy):

    Tools/asset-pipeline/.venv/bin/python scripts/process_dropbox.py
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

PIPELINE = Path(__file__).resolve().parent.parent
DROPBOX = PIPELINE / "dropbox"
PROCESSED = DROPBOX / "procesadas"
RESOURCES = PIPELINE.parent.parent / "FisuEvolution" / "Resources"
MANIFEST = RESOURCES / "Data" / "assets_manifest.json"

# assetKey → (carpeta destino, sección del manifest, sufijo de key)
# `manifest_section = None` ⇒ el asset NO entra al manifest (ver categoría skin).
ATLAS_BY_CATEGORY = {
    "character": ("{phase}.atlas", "characters", "_idle"),
    "special": ("specials.atlas", "characters", ""),
    "ui": ("ui.atlas", "ui", ""),
    "fx": ("ui.atlas", "ui", ""),
    "background": ("Backgrounds", "backgrounds", ""),
    # Skins (F7.5): viven en el atlas de SU personaje y el juego las resuelve por
    # nombre directo (`PlaceholderRenderer`), no por manifest. Meterlas en
    # manifest["characters"] rompería el test de "manifest huérfano" porque no
    # son tiers. El sufijo lo arma `skin_asset_key`, no esta tabla: la
    # convención es `<char>_idle__<skin>`, con el `__` DESPUÉS de `_idle`.
    "skin": ("{phase}.atlas", None, ""),
    # Visitantes de la 2.0 (`Docs/biblia-visitantes.md`): las cuatro piezas de los
    # 8 nuevos (`npc_<nombre>`, `_talk`, `_action`, `_face`) y las poses nuevas de
    # los 10 especiales (`sp_<id>_talk`, `_face`). La clave del prompt es el
    # sprite. Sección propia del manifest porque un visitante no es un tier: en
    # "characters" rompería `manifestEntriesReferenceRealTypes`.
    "npc": ("npcs.atlas", "npcs", ""),
    # Familias de skins (PLAN-v2 E6): un atlas por familia, para no mover las
    # páginas de los atlas de fase. Se resuelven por nombre, como las skins.
    "skinfam": ("fam_{family}.atlas", None, ""),
}

# Las familias de skins de la 2.0 (`Docs/biblia-visitantes.md`). Fuera de esta
# lista una clave `<tipo>__<familia>` se rechaza: un typo inventaría un atlas.
SKIN_FAMILIES = ("pijama", "gaucho", "dinosaurio")


# Piezas de UI de la 2.0 que se dibujan más grandes que un ícono.
TAMANO_POR_PREFIJO = (
    ("wheel_frame", (640, 960)),           # la ruleta mide 300 pt (WheelView, E5b)
    ("pickup_", (384, 512)),               # cajas y colchón del tablero, ~96 pt
    ("ui_album_card_frame", (448, 640)),   # la carta del Álbum de especiales
)


def export_size(category: str, asset_key: str) -> tuple[int, int]:
    """(@2x, @3x) en píxeles según cómo se dibuja el asset en pantalla.

    Los assets ya integrados tienen estos tamaños: si cambia uno, los nuevos
    vuelven a desentonar con los que están en el juego."""
    if category == "npc" and asset_key.endswith("_face"):
        return (192, 256)    # como las 43 caras de la v1 (ui.atlas): chip y Álbum
    if category in {"character", "special", "skin", "skinfam", "npc"}:
        return (384, 512)    # se dibujan a ~146 pt → 438 px @3x
    for prefijo, tamanos in TAMANO_POR_PREFIJO:
        if asset_key.startswith(prefijo):
            return tamanos
    if asset_key.startswith(("panel_", "fisura_", "logo")):
        return (448, 640)    # se estiran grande (9-slice, retratos de tutorial)
    return (192, 256)        # íconos y botones de UI


def skin_asset_key(asset_key: str) -> str:
    """`homeless__second_life` → `homeless_idle__second_life`.

    El assetKey del pipeline usa `<char>__<skin>` (un solo nombre de archivo por
    asset); el juego espera el sufijo `_idle` sobre el personaje base. Concatenar
    `_idle` al final —como hacen las otras categorías— daría
    `homeless__second_life_idle`, que no matchea nada."""
    character, separator, skin = asset_key.partition("__")
    if not separator:
        raise ValueError(f"assetKey de skin sin '__': {asset_key}")
    return f"{character}_idle__{skin}"


def skin_family(asset_key: str) -> str:
    """`homeless__dinosaurio` → `dinosaurio`, o ValueError si no es una familia."""
    family = asset_key.partition("__")[2]
    if family not in SKIN_FAMILIES:
        raise ValueError(f"assetKey de familia sin familia conocida {SKIN_FAMILIES}: {asset_key}")
    return family


def load_entries() -> dict[str, dict]:
    prompts = json.loads((PIPELINE / "prompts" / "prompts.json").read_text())
    return {e["assetKey"]: e for e in prompts}


def destination(entry: dict) -> tuple[str, str, str | None]:
    """(carpeta del atlas, nombre del archivo sin @Nx, sección del manifest)."""
    category = entry.get("category", "character")
    atlas_template, manifest_section, key_suffix = ATLAS_BY_CATEGORY[category]
    fields = {"phase": entry.get("atlas", "earth")}
    if category == "skinfam":
        fields["family"] = skin_family(entry["assetKey"])
    atlas_name = atlas_template.format(**fields)
    asset_key = (
        skin_asset_key(entry["assetKey"]) if category in {"skin", "skinfam"}
        else entry["assetKey"] + key_suffix
    )
    return atlas_name, asset_key, manifest_section


# Fondos de la 2.0 (PLAN-v2 E3 "Arte"): un solo JPEG de 2048 sin sufijo de escala.
# Son opacos y `FloorNode` hace aspect-fill sobre el tamaño de la textura, así que
# la escala del archivo no importa; el iPad, que es @2x, deja de dibujar el de
# 1024. En PNG los diez sumaban +26 MB al bundle; en JPEG restan 27.
BACKGROUND_SIDE = 2048
BACKGROUND_QUALITY = 90


def export_background(img, asset_key: str) -> str:
    """Escribe `Backgrounds/<key>.jpg` y retira los PNG de la v1. Devuelve el nombre
    con extensión, que es lo que el juego busca con `UIImage(named:)`."""
    from PIL import Image

    target_dir = RESOURCES / "Backgrounds"
    target_dir.mkdir(parents=True, exist_ok=True)
    name = f"{asset_key}.jpg"
    side = (BACKGROUND_SIDE, BACKGROUND_SIDE)
    img.convert("RGB").resize(side, Image.LANCZOS).save(target_dir / name, quality=BACKGROUND_QUALITY)
    for escala in ("@2x", "@3x"):
        (target_dir / f"{asset_key}{escala}.png").unlink(missing_ok=True)
    return name


def export_atlas(img, entry: dict, atlas_name: str, asset_key: str) -> None:
    """Escribe el @2x/@3x del asset ya recortado en su atlas."""
    from PIL import Image

    target_dir = RESOURCES / atlas_name
    target_dir.mkdir(parents=True, exist_ok=True)
    # Tamaño según USO, no un 1536 para todo. Exportar todo a 1536 rompía el
    # texture atlas: el límite de página es 2048, así que dos imágenes de 1536 no
    # entran juntas y el packer ponía UNA POR PÁGINA — el atlas no agrupaba nada
    # y cada sprite era su propio draw call.
    at2x, at3x = export_size(entry.get("category", "character"), entry["assetKey"])
    img.resize((at3x, at3x), Image.LANCZOS).save(target_dir / f"{asset_key}@3x.png")
    img.resize((at2x, at2x), Image.LANCZOS).save(target_dir / f"{asset_key}@2x.png")


def process(image_path: Path, entry: dict) -> None:
    from PIL import Image

    from whitebg_cutout import cutout

    category = entry.get("category", "character")
    atlas_name, asset_key, manifest_section = destination(entry)

    img = Image.open(image_path).convert("RGBA")

    if category != "background":
        # Recorte por conectividad, NO por saliencia: `rembg` dejaba transparente
        # todo lo blanco del personaje (ver el guardapolvo del `senior_doctor`).
        img = cutout(img, entry["assetKey"])

    if category == "background":
        asset_name = export_background(img, asset_key)
    else:
        export_atlas(img, entry, atlas_name, asset_key)

    if manifest_section is None:
        # Skins: el catálogo vive en skins.json y el arte se busca por nombre.
        PROCESSED.mkdir(exist_ok=True)
        image_path.rename(PROCESSED / image_path.name)
        print(f"  ✓ {entry['assetKey']} → {atlas_name}/{asset_key}@2x/@3x (sin manifest)")
        return

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
        manifest["backgrounds"][stage] = asset_name
    else:
        # `setdefault`: la sección "npcs" nace con el primer visitante integrado.
        manifest.setdefault(manifest_section, {})[entry["assetKey"]] = asset_key
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))

    PROCESSED.mkdir(exist_ok=True)
    image_path.rename(PROCESSED / image_path.name)
    destino = asset_name if category == "background" else f"{atlas_name}/{asset_key}@2x/@3x"
    print(f"  ✓ {entry['assetKey']} → {destino} + manifest")


def main() -> None:
    DROPBOX.mkdir(exist_ok=True)
    entries = load_entries()
    pending = sorted(DROPBOX.glob("*.png"))
    if not pending:
        print(f"dropbox vacío: soltá PNGs con nombre <assetKey>.png en {DROPBOX}")
        return

    unknown = []
    for image_path in pending:
        key = image_path.stem
        entry = entries.get(key)
        if not entry:
            unknown.append(key)
            continue
        print(f"procesando {key}…")
        process(image_path, entry)

    if unknown:
        print(f"\nNOMBRES DESCONOCIDOS (revisar contra el .md): {unknown}")
        sys.exit(1)
    print("\nlisto ✓ — regenerar el proyecto y buildear para verlos en el juego")


if __name__ == "__main__":
    main()
