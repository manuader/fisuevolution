#!/usr/bin/env python3
"""Rehace el recorte de TODOS los assets ya integrados, desde el original.

Los assets del juego se recortaron con `rembg`, que decide por saliencia y por eso
dejo transparente lo blanco de los personajes: el guardapolvo del `senior_doctor`,
las camisas, los papeles. Los originales con fondo blanco estan guardados en
`dropbox/procesadas/`, asi que el arreglo no necesita regenerar nada con Gemini —
alcanza con volver a recortar con `whitebg_cutout`, que corta por conectividad.

    .venv/bin/python scripts/recut_assets.py --dry-run
    .venv/bin/python scripts/recut_assets.py

Los backgrounds no se tocan: nunca se recortaron, van con fondo y todo.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

from process_dropbox import PIPELINE, RESOURCES, destination, export_atlas  # noqa: E402
from whitebg_cutout import cutout  # noqa: E402

ORIGINALS = PIPELINE / "dropbox" / "procesadas"

# `homeless` es El Fisura, y su original nunca paso por el dropbox: es la
# referencia de estilo aprobada a mano con la que se genero todo lo demas.
ORIGINALES_APARTE = {"homeless": PIPELINE / "heroes" / "approved" / "fisura.png"}

# Los que el dueno prefirio con el recorte viejo (revision del 2026-08-18).
#
# En los doce, lo que el recorte por conectividad suma es la SOMBRA del piso o el
# telon de la escena: el toldo del mantero, la cupula del terraformador, la
# plataforma del rey de asteroides, el campo estrellado del estanciero, el
# quirofano del cirujano, la figurita del coleccionista. El dibujo los encierra,
# asi que por topologia son personaje y no hay forma de distinguirlos — es la
# contracara del criterio que salva los guardapolvos. Parado sobre el tablero eso
# se lee como una loza blanca a los pies. El recorte por saliencia se los comia, y
# en estos doce conviene que se los coma.
#
# Se saltean enteros: el PNG que esta en el juego es el que vale, y volver a
# correr este script no se lo lleva puesto.
RECORTE_VIEJO_A_PEDIDO = frozenset({
    "cartonero",
    "cartonero__urban_trailblazer",
    "coleccionista_galaxias__figurita",
    "dueno_marte__terraformador",
    "estanciero_estelar",
    "magnate_solar",
    "magnate_solar__corona_solar",
    "mantero",
    "mantero__feriante",
    "rey_asteroides",
    "rey_asteroides__chatarrero",
    "senior_doctor__cirujano",
})


def recorte_elegido_a_mano(asset_key: str) -> bool:
    """Assets cuyo recorte lo eligio el dueno mirando, no el pipeline.

    Las skins de oro y diamante van con el recorte por saliencia (`rembg`), que
    en ellas gana por una razon concreta: el material es un mismo tono en toda la
    figura, asi que el blanco encerrado que el criterio topologico conserva —la
    sombra del piso, la tarima del emprendedor, la tarjeta del magnate solar— no
    se distingue del personaje por conectividad, y sobre el tablero se lee como
    una loza blanca a los pies. El costo esta medido y asumido: en diamante la
    saliencia se come parte del cuerpo palido (hasta 18% de la silueta en
    `rey_asteroides__diamante`), y aun asi el dueno prefirio esa version.

    Se saltean enteros: el PNG que esta en el juego es el que vale."""
    return asset_key.endswith(("__oro", "__diamante"))


def original_de(asset_key: str) -> Path:
    return ORIGINALES_APARTE.get(asset_key, ORIGINALS / f"{asset_key}.png")


def entries() -> list[dict]:
    prompts = json.loads((PIPELINE / "prompts" / "prompts.json").read_text())
    return [e for e in prompts if e.get("category") != "background"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="solo listar")
    parser.add_argument("--only", action="append", default=[], metavar="ASSETKEY")
    args = parser.parse_args()

    todo = entries()
    if args.only:
        todo = [e for e in todo if e["assetKey"] in set(args.only)]

    rehechos, sin_original, sin_integrar, a_pedido = [], [], [], []
    for entry in sorted(todo, key=lambda e: e["assetKey"]):
        key = entry["assetKey"]
        original = original_de(key)
        atlas_name, asset_key, _ = destination(entry)

        if key in RECORTE_VIEJO_A_PEDIDO or recorte_elegido_a_mano(key):
            a_pedido.append(key)
            continue
        if not original.exists():
            sin_original.append(key)
            continue
        if not (RESOURCES / atlas_name / f"{asset_key}@3x.png").exists():
            # El asset no esta en el juego; recortarlo ahora seria integrarlo por
            # la ventana, que no es lo que este script viene a hacer.
            sin_integrar.append(key)
            continue

        rehechos.append(key)
        if args.dry_run:
            continue
        export_atlas(cutout(Image.open(original), key), entry, atlas_name, asset_key)
        print(f"  ✓ {key} → {atlas_name}/{asset_key}@2x/@3x", flush=True)

    verbo = "se rehacen" if args.dry_run else "rehechos"
    print(f"\n{verbo}: {len(rehechos)}")
    if a_pedido:
        print(f"con el recorte elegido a mano, no se tocan: {len(a_pedido)}")
    if sin_integrar:
        print(f"con original pero fuera del juego ({len(sin_integrar)}): {sin_integrar}")
    if sin_original:
        print(f"SIN ORIGINAL, no se pueden rehacer ({len(sin_original)}): {sin_original}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
