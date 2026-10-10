#!/usr/bin/env python3
"""El balde de islas: arma la pagina para sacar, como con el balde del Paint, las
islas que sobran en los sprites que ya estan en el juego.

Una isla es un pedazo suelto del dibujo: un componente conexo de pixeles opacos
del PNG ya recortado (una chispa, una sombra que quedo flotando, el pedazo de
fondo que el recorte no se llevo). Tambien son islas los huecos de blanco
encerrado que quedaron opacos —la loza bajo los pies, el blanco entre el brazo y
el cuerpo—, porque son justo lo que a veces conviene sacar y a veces no (una
camisa). En la pagina, rojo = se saca y verde o sin pintar = se queda.

    .venv/bin/python scripts/balde_islas.py                   # arma ~/Desktop/projects/islas-review
    .venv/bin/python scripts/balde_islas.py --salida /otra/carpeta

Los sprites son los de la revision de recortes (`decisiones.json`): sus elecciones
y los que quedaron a regenerar. Lo que el dueno ya marco o guardo no se pierde al
volver a armar la pagina: vive en `marcas.json` y `limpias/`, que no se tocan.

La pagina la sirve `balde_islas/servir.py` (solo biblioteca estandar), que guarda
el PNG limpio y las marcas; `aplicar_limpias.py` las lleva al juego.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))

from process_dropbox import PIPELINE, RESOURCES, destination  # noqa: E402

SALIDA = Path.home() / "Desktop" / "projects" / "islas-review"
DECISIONES = Path.home() / "Desktop" / "revision-v2" / "decisiones.json"
PLANTILLA = Path(__file__).resolve().parent / "balde_islas"

# Opaco es lo que pasa este alfa; lo de abajo es el antialias de algun borde.
UMBRAL_ALFA = 8
# El antialias suelto se va con la isla mas cercana si esta a esta distancia o menos.
HALO = 3
# Blanco es lo que no se aleja del blanco puro mas que esto (como `whitebg_cutout`).
TOLERANCIA_BLANCO = 14
# El anillo de un hueco: lo claro que lo rodea y se va con el.
ANILLO = 2
ANILLO_CLARO = 60
# Un hueco mas chico que esto, en un sprite de 512, es un ojo o un brillo.
HUECO_MINIMO_512 = 64
# El canal B del mapa lleva el id del hueco: no entran mas de 255.
HUECOS_MAXIMOS = 255
# Una isla mas chica que esto, en un sprite de 512, se pierde con el ojo.
DIMINUTA_512 = 150

GRUPOS = {
    "earth.atlas": "Tierra",
    "cosmic.atlas": "Cosmos",
    "npcs.atlas": "NPCs",
    "fam_pijama.atlas": "Familia Pijama",
    "fam_gaucho.atlas": "Familia Gaucho",
    "fam_dinosaurio.atlas": "Familia Dinosaurio",
    "ui.atlas": "Interfaz",
}


def escala(alto: int, ancho: int, a_512: int) -> int:
    return max(4, round(a_512 * alto * ancho / (512 * 512)))


def islas(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray, list[dict]]:
    """(id de isla suelta por pixel, id de hueco por pixel, fichas de cada isla).

    Los ids de las sueltas van de 1 en adelante por area, asi que `s1` es siempre
    el cuerpo. Un pixel de hueco tambien pertenece a la suelta que lo encierra:
    pintar de rojo la suelta se lleva sus huecos."""
    alfa = rgba[..., 3]
    opaco = alfa > UMBRAL_ALFA
    alto, ancho = alfa.shape

    crudas, cuantas = ndimage.label(opaco, structure=np.ones((3, 3), dtype=bool))
    sueltas = np.zeros_like(crudas)
    fichas: list[dict] = []
    if cuantas:
        areas = ndimage.sum_labels(opaco, crudas, index=np.arange(1, cuantas + 1))
        orden = np.argsort(-areas, kind="stable")
        renumero = np.zeros(cuantas + 1, dtype=crudas.dtype)
        renumero[orden + 1] = np.arange(1, cuantas + 1)
        sueltas = renumero[crudas]

        # El antialias que quedo afuera del umbral se va con su isla.
        semitransparente = (alfa > 0) & ~opaco
        if semitransparente.any():
            distancia, (fy, fx) = ndimage.distance_transform_edt(~opaco, return_indices=True)
            cerca = semitransparente & (distancia <= HALO)
            sueltas[cerca] = sueltas[fy[cerca], fx[cerca]]

        fichas += _fichas("s", sueltas, opaco, cuantas, alto, ancho)

    huecos = _huecos(rgba, opaco)
    fichas += _fichas("h", huecos, huecos > 0, int(huecos.max()), alto, ancho)
    for ficha in fichas:
        if ficha["id"].startswith("h"):
            y, x = ficha["_un_pixel"]
            ficha["dentro_de"] = f"s{int(sueltas[y, x])}"
    for ficha in fichas:
        del ficha["_un_pixel"]
    return sueltas.astype(np.int32), huecos.astype(np.int32), fichas


def _huecos(rgba: np.ndarray, opaco: np.ndarray) -> np.ndarray:
    alto, ancho = opaco.shape
    lejos_del_blanco = 255 - rgba[..., :3].min(axis=2).astype(np.int16)
    blanco = (lejos_del_blanco <= TOLERANCIA_BLANCO) & (rgba[..., 3] >= 250)
    crudos, cuantos = ndimage.label(blanco)
    huecos = np.zeros(opaco.shape, dtype=np.int32)
    if not cuantos:
        return huecos
    areas = ndimage.sum_labels(blanco, crudos, index=np.arange(1, cuantos + 1))
    minimo = escala(alto, ancho, HUECO_MINIMO_512)
    grandes = [i + 1 for i in np.argsort(-areas, kind="stable") if areas[i] >= minimo]
    claro = opaco & (lejos_del_blanco <= ANILLO_CLARO)
    for nuevo, viejo in enumerate(grandes[:HUECOS_MAXIMOS], 1):
        hueco = crudos == viejo
        anillo = ndimage.binary_dilation(hueco, iterations=ANILLO) & claro & (huecos == 0)
        huecos[hueco | anillo] = nuevo
    return huecos


def _fichas(prefijo: str, ids: np.ndarray, cuenta: np.ndarray, cuantas: int,
            alto: int, ancho: int) -> list[dict]:
    if not cuantas:
        return []
    indices = np.arange(1, cuantas + 1)
    areas = ndimage.sum_labels(cuenta, ids, index=indices)
    cajas = ndimage.find_objects(ids, max_label=cuantas)
    diminuta = escala(alto, ancho, DIMINUTA_512)
    fichas = []
    for numero, (area, caja) in enumerate(zip(areas, cajas), 1):
        if caja is None:
            continue
        ys, xs = caja
        dentro = np.argwhere(ids[caja] == numero)[0]
        fichas.append({
            "id": f"{prefijo}{numero}",
            "area": int(area),
            "caja": [xs.start, ys.start, xs.stop, ys.stop],
            "diminuta": bool(area < diminuta),
            "_un_pixel": (int(ys.start + dentro[0]), int(xs.start + dentro[1])),
        })
    return fichas


def mapa(sueltas: np.ndarray, huecos: np.ndarray) -> Image.Image:
    """PNG opaco que la pagina lee para saber que isla hay bajo el mouse: R y G
    llevan el id de la suelta, B el del hueco. Opaco, para que el navegador no
    toque los valores al premultiplicar."""
    lienzo = np.zeros((*sueltas.shape, 4), dtype=np.uint8)
    lienzo[..., 0] = sueltas % 256
    lienzo[..., 1] = sueltas // 256
    lienzo[..., 2] = huecos
    lienzo[..., 3] = 255
    return Image.fromarray(lienzo, mode="RGBA")


def limpiar(rgba: np.ndarray, rojas: list[str]) -> np.ndarray:
    """El sprite sin las islas pintadas de rojo (`s3`, `h1`...). Lo demas no se toca."""
    sueltas, huecos, _ = islas(rgba)
    rojas_s = [int(r[1:]) for r in rojas if r.startswith("s")]
    rojos_h = [int(r[1:]) for r in rojas if r.startswith("h")]
    sacar = np.isin(sueltas, rojas_s) | np.isin(huecos, rojos_h)
    limpio = rgba.copy()
    limpio[sacar] = 0
    return limpio


def huella(ruta: Path) -> str:
    return hashlib.sha1(ruta.read_bytes()).hexdigest()


def catalogo() -> dict[str, dict]:
    return {e["assetKey"]: e for e in json.loads((PIPELINE / "prompts" / "prompts.json").read_text())}


def sprites(decisiones: dict, entradas: dict[str, dict]) -> list[tuple[str, dict, bool]]:
    """(clave, entrada, a_regenerar) de cada sprite de la revision."""
    regenerar = set(decisiones.get("regenerar", []))
    claves = sorted(set(decisiones.get("elecciones", {})) | regenerar)
    return [(c, entradas[c], c in regenerar) for c in claves if c in entradas]


def armar(salida: Path, decisiones: dict) -> int:
    from revision_recortes import nombres_de_personaje, nombres_de_skin, variante

    personajes, skins = nombres_de_personaje(), nombres_de_skin()
    for sub in ("img", "mapas"):
        if (salida / sub).exists():
            shutil.rmtree(salida / sub)
        (salida / sub).mkdir(parents=True)
    (salida / "limpias").mkdir(parents=True, exist_ok=True)

    fichas = []
    lista = sprites(decisiones, catalogo())
    for numero, (clave, entrada, a_regenerar) in enumerate(lista, 1):
        atlas, sprite, _ = destination(entrada)
        fuente = RESOURCES / atlas / f"{sprite}@3x.png"
        if not fuente.exists():
            print(f"  ✗ {clave}: no esta en el juego ({atlas}/{sprite})")
            continue
        rgba = np.array(Image.open(fuente).convert("RGBA"))
        sueltas, huecos, islas_ = islas(rgba)
        shutil.copy2(fuente, salida / "img" / f"{clave}.png")
        mapa(sueltas, huecos).save(salida / "mapas" / f"{clave}.png", optimize=True)
        base, _, skin = clave.partition("__")
        fichas.append({
            "clave": clave,
            "nombre": personajes.get(base, base.replace("_", " ").capitalize()),
            "skin": skins.get(skin, skin.replace("_", " ").capitalize() if skin else ""),
            "variante": variante(clave),
            "grupo": GRUPOS.get(atlas, atlas),
            "regenerar": a_regenerar,
            "lado": [int(rgba.shape[1]), int(rgba.shape[0])],
            "origen": huella(fuente),
            "islas": islas_,
        })
        print(f"  [{numero:3}/{len(lista)}] {clave}: {len(islas_)} islas", flush=True)

    (salida / "datos.js").write_text(
        "window.SPRITES = " + json.dumps(fichas, ensure_ascii=False, separators=(",", ":")) + ";\n",
        encoding="utf-8",
    )
    for archivo in PLANTILLA.iterdir():
        shutil.copy2(archivo, salida / archivo.name)
    (salida / "Abrir revisión de islas.command").chmod(0o755)
    print(f"\nsprites en la pagina: {len(fichas)}")
    print(f"para abrirla: doble clic en {salida / 'Abrir revisión de islas.command'}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--salida", type=Path, default=SALIDA)
    parser.add_argument("--decisiones", type=Path, default=DECISIONES)
    args = parser.parse_args()
    return armar(args.salida.expanduser(), json.loads(args.decisiones.expanduser().read_text()))


if __name__ == "__main__":
    raise SystemExit(main())
