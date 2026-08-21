#!/usr/bin/env python3
"""Aplica al juego las decisiones tomadas en la pagina de revision.

`revision_recortes.py` arma la pagina; ahi se elige, skin por skin, cual de los
dos recortes queda en el juego, y se marcan las que estan mal con los dos y hay
que regenerar. La pagina baja un `decisiones.json`; este script lo ejecuta.

    pbpaste | .venv/bin/python scripts/aplicar_revision.py -          # copiando el JSON
    .venv/bin/python scripts/aplicar_revision.py ~/Downloads/decisiones.json
    .venv/bin/python scripts/aplicar_revision.py                        # busca el mas reciente

Con `--dry-run` dice que haria sin escribir nada.

Ademas de escribir los PNG, anota la eleccion en `recut_assets.py`: una corrida
futura del recut recorta TODO por conectividad salvo lo que este en su lista de
elegidos a mano, asi que sin esto el recut revertiria en silencio cada skin que
se haya elegido con saliencia. Las que se eligen por conectividad salen de esa
lista, que es justo lo que el recut hace por su cuenta.

Las que quedaron sin decidir no se tocan: siguen como estan.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

from process_dropbox import PIPELINE, RESOURCES, destination  # noqa: E402
from process_dropbox import export_atlas  # noqa: E402
from whitebg_cutout import cutout  # noqa: E402

REMBG = PIPELINE / "state" / "rembg"
ORIGINALES = PIPELINE / "dropbox" / "procesadas"

# `homeless` es El Fisura: su original nunca paso por el dropbox, es la referencia
# de estilo aprobada a mano con la que se genero todo lo demas.
ORIGINALES_APARTE = {"homeless": PIPELINE / "heroes" / "approved" / "fisura.png"}
RECUT = Path(__file__).resolve().parent / "recut_assets.py"
ABRE = "RECORTE_VIEJO_A_PEDIDO = frozenset({"
CIERRA = "})"


BUSCAR_EN = (Path.home() / "Downloads", Path.home() / "Desktop", Path.cwd())


def leer_decisiones(donde: str | None) -> dict:
    """El JSON de la pagina, venga por stdin, por ruta, o buscandolo."""
    if donde == "-":
        crudo = sys.stdin.read()
        if not crudo.strip():
            raise SystemExit("No llego nada por stdin. ¿Copiaste el JSON en la pagina?")
        return json.loads(crudo)

    if donde:
        ruta = Path(donde).expanduser()
        if not ruta.exists():
            raise SystemExit(
                f"No existe {ruta}.\n\n"
                "La pagina lo baja con «Bajar decisiones.json», pero si el navegador no\n"
                "descarga nada usa «Copiar el JSON» y pasamelo por stdin:\n"
                f"    pbpaste | {Path(sys.argv[0]).name} -"
            )
        return json.loads(ruta.read_text())

    encontrados = [f for d in BUSCAR_EN for f in d.glob("decisiones*.json") if f.is_file()]
    if not encontrados:
        raise SystemExit(
            "No encontre ningun decisiones*.json en Downloads, Desktop ni aca.\n"
            f"Pasame la ruta, o el JSON por stdin:  pbpaste | {Path(sys.argv[0]).name} -"
        )
    reciente = max(encontrados, key=lambda f: f.stat().st_mtime)
    print(f"usando {reciente}")
    return json.loads(reciente.read_text())


def catalogo() -> dict[str, dict]:
    return {e["assetKey"]: e for e in json.loads((PIPELINE / "prompts" / "prompts.json").read_text())}


def elegidos_a_mano() -> set[str]:
    texto = RECUT.read_text()
    desde = texto.index(ABRE) + len(ABRE)
    hasta = texto.index(CIERRA, desde)
    return {linea.strip().strip('",') for linea in texto[desde:hasta].splitlines() if '"' in linea}


def escribir_elegidos_a_mano(claves: set[str]) -> None:
    texto = RECUT.read_text()
    desde = texto.index(ABRE) + len(ABRE)
    hasta = texto.index(CIERRA, desde)
    cuerpo = "\n" + "".join(f'    "{clave}",\n' for clave in sorted(claves))
    RECUT.write_text(texto[:desde] + cuerpo + texto[hasta:])


def poner_rembg(entrada: dict) -> str | None:
    atlas, sprite, _ = destination(entrada)
    faltan = [e for e in ("@2x", "@3x") if not (REMBG / atlas / f"{sprite}{e}.png").exists()]
    if faltan:
        return f"no hay version de rembg ({', '.join(faltan)})"
    for escala in ("@2x", "@3x"):
        shutil.copy2(REMBG / atlas / f"{sprite}{escala}.png", RESOURCES / atlas / f"{sprite}{escala}.png")
    return None


def poner_conectividad(entrada: dict) -> str | None:
    clave = entrada["assetKey"]
    original = ORIGINALES_APARTE.get(clave, ORIGINALES / f"{clave}.png")
    if not original.exists():
        return f"falta el original {original.name}"
    atlas, sprite, _ = destination(entrada)
    export_atlas(cutout(Image.open(original), clave), entrada, atlas, sprite)
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("decisiones", nargs="?", default=None,
                        help="el decisiones.json de la pagina, o «-» para leerlo de stdin; "
                             "sin nada, busca el mas reciente")
    parser.add_argument("--dry-run", action="store_true", help="decir que haria, sin tocar nada")
    args = parser.parse_args()

    decisiones = leer_decisiones(args.decisiones)
    elecciones: dict[str, str] = decisiones.get("elecciones", {})
    regenerar: list[str] = decisiones.get("regenerar", [])
    if not elecciones and not regenerar:
        raise SystemExit("El JSON no trae ninguna decision: no hay nada que aplicar.")
    entradas = catalogo()

    puestas, fallaron, desconocidas = [], [], []
    for clave, herramienta in sorted(elecciones.items()):
        if clave not in entradas:
            desconocidas.append(clave)
            continue
        if herramienta not in ("rembg", "conectividad"):
            fallaron.append((clave, f"recorte desconocido: {herramienta}"))
            continue
        if args.dry_run:
            puestas.append((clave, herramienta))
            continue
        poner = poner_rembg if herramienta == "rembg" else poner_conectividad
        problema = poner(entradas[clave])
        if problema:
            fallaron.append((clave, problema))
        else:
            puestas.append((clave, herramienta))
            print(f"  ✓ {clave} → {herramienta}", flush=True)

    # Que el recut no las pise: van a la lista las elegidas por saliencia que el
    # recut no saltea ya por ser de oro o de diamante.
    aplicadas = dict(puestas)
    antes = elegidos_a_mano()
    ahora = set(antes)
    ahora -= {c for c, h in aplicadas.items() if h == "conectividad"}
    ahora |= {c for c, h in aplicadas.items()
              if h == "rembg" and not c.endswith(("__oro", "__diamante"))}

    verbo = "se aplicarian" if args.dry_run else "aplicadas"
    print(f"\n{verbo}: {len(puestas)}")
    if ahora != antes and not args.dry_run:
        escribir_elegidos_a_mano(ahora)
    if ahora != antes:
        entran, salen = sorted(ahora - antes), sorted(antes - ahora)
        print(f"elegidos a mano en recut_assets.py: {len(antes)} → {len(ahora)}")
        if entran:
            print(f"  entran: {', '.join(entran)}")
        if salen:
            print(f"  salen:  {', '.join(salen)}")
    if fallaron:
        print(f"\nno se pudieron aplicar ({len(fallaron)}):")
        for clave, motivo in fallaron:
            print(f"  ✗ {clave}: {motivo}")
    if desconocidas:
        print(f"\nno estan en prompts.json ({len(desconocidas)}): {', '.join(desconocidas)}")
    if regenerar:
        print(f"\na regenerar ({len(regenerar)}), siguen en el juego como estan:")
        for clave in sorted(regenerar):
            print(f"  · {clave}")
    return 1 if fallaron else 0


if __name__ == "__main__":
    raise SystemExit(main())
