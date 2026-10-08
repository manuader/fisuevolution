#!/usr/bin/env python3
"""El catálogo de strings en el formato canónico de Xcode (HANDOFF §7, trampa 29).

    Tools/v2/catalogo.py verificar
    Tools/v2/catalogo.py aplicar <claves.json> [<claves.json> …]
    Tools/v2/catalogo.py quitar <clave> [<clave> …]

`verificar` reescribe en memoria los dos catálogos sin cambiarles nada y exige
que salgan byte a byte iguales: es la prueba de que este script escribe el
formato de Xcode (dos espacios, `" : "`, las claves de `strings` en orden
natural, sin salto de línea final). `aplicar` suma las claves de los snapshots
al `Localizable.xcstrings`, y sólo si esa verificación pasa antes. `quitar` borra
claves (y frena sin escribir nada si alguna no existe). Cambiar el texto de una
clave es `quitar` y después `aplicar` de la misma clave.

Un snapshot es {"clave": {"es": "…", "en": "…"}}. Una clave que ya existe con
los mismos textos se saltea; con otros, es un error y no se escribe nada: este
script no pisa traducciones. Los snapshots que esperan integración viven en
`Tools/v2/claves-pendientes/` (PLAN-v2 §0.1).
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LOCALIZABLE = REPO / "FisuEvolution/Resources/Localizable.xcstrings"
CATALOGOS = [LOCALIZABLE, REPO / "FisuEvolution/Resources/InfoPlist.xcstrings"]


def orden_natural(clave):
    # Xcode compara los números como números: `skins_5` va antes que `skins_20`.
    return [int(parte) if parte.isdigit() else parte.lower() for parte in re.split(r"(\d+)", clave)]


def serializar(valor, nivel=0):
    margen = "  " * nivel
    adentro = "  " * (nivel + 1)
    if isinstance(valor, dict):
        if not valor:
            return "{\n\n" + margen + "}"
        # Sólo el diccionario de `strings` (nivel 1) va ordenado; adentro de cada
        # entrada se respeta el orden en que la escribió Xcode.
        claves = sorted(valor, key=orden_natural) if nivel == 1 else list(valor)
        filas = [adentro + json.dumps(c, ensure_ascii=False) + " : " + serializar(valor[c], nivel + 1)
                 for c in claves]
        return "{\n" + ",\n".join(filas) + "\n" + margen + "}"
    if isinstance(valor, list):
        if not valor:
            return "[\n\n" + margen + "]"
        return "[\n" + ",\n".join(adentro + serializar(v, nivel + 1) for v in valor) + "\n" + margen + "]"
    return json.dumps(valor, ensure_ascii=False)


def es_canonico(ruta):
    texto = Path(ruta).read_text(encoding="utf-8")
    return serializar(json.loads(texto)) == texto


def entrada(es, en):
    return {
        "extractionState": "manual",
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "es": {"stringUnit": {"state": "translated", "value": es}},
        },
    }


def textos(existente):
    locs = existente.get("localizations", {})
    return {idioma: locs.get(idioma, {}).get("stringUnit", {}).get("value") for idioma in ("es", "en")}


def aplicar(snapshots, ruta=LOCALIZABLE):
    ruta = Path(ruta)
    if not es_canonico(ruta):
        sys.exit(f"✋ {ruta.name} no está en el formato canónico: no se escribe nada (trampa 29)")
    catalogo = json.loads(ruta.read_text(encoding="utf-8"))
    nuevas = 0
    for snapshot in snapshots:
        for clave, par in json.loads(Path(snapshot).read_text(encoding="utf-8")).items():
            if set(par) != {"es", "en"} or not all(par.values()):
                sys.exit(f"✋ {snapshot}: la clave {clave!r} necesita 'es' y 'en', no vacíos")
            existente = catalogo["strings"].get(clave)
            if existente is None:
                catalogo["strings"][clave] = entrada(par["es"], par["en"])
                nuevas += 1
            elif textos(existente) != par:
                sys.exit(f"✋ {clave!r} ya existe con otro texto: {textos(existente)} contra {par}")
    ruta.write_text(serializar(catalogo), encoding="utf-8")
    print(f"{ruta.name}: {nuevas} claves nuevas")


def quitar(claves, ruta=LOCALIZABLE):
    ruta = Path(ruta)
    if not es_canonico(ruta):
        sys.exit(f"✋ {ruta.name} no está en el formato canónico: no se escribe nada (trampa 29)")
    catalogo = json.loads(ruta.read_text(encoding="utf-8"))
    faltan = [clave for clave in claves if clave not in catalogo["strings"]]
    if faltan:
        sys.exit(f"✋ no existen: {faltan}")
    for clave in claves:
        del catalogo["strings"][clave]
    ruta.write_text(serializar(catalogo), encoding="utf-8")
    print(f"{ruta.name}: {len(claves)} claves borradas")


def main(argumentos):
    if argumentos[:1] == ["verificar"]:
        malos = [r.name for r in CATALOGOS if not es_canonico(r)]
        for r in CATALOGOS:
            print(f"{r.name}: {'NO canónico' if r.name in malos else 'canónico'}")
        return 1 if malos else 0
    if argumentos[:1] == ["aplicar"] and len(argumentos) > 1:
        aplicar(argumentos[1:])
        return 0
    if argumentos[:1] == ["quitar"] and len(argumentos) > 1:
        quitar(argumentos[1:])
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
