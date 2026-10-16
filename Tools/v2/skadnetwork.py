#!/usr/bin/env python3
"""La unión de SKAdNetwork de la mediación en el Info.plist (PLAN-v2 E7).

Baja la lista oficial de Unity, la une con las que ya trae el Info.plist (las de
Google) y reescribe SÓLO el <array> de
SKAdNetworkItems: los comentarios del archivo se conservan. Las que estaban
quedan primero y en su orden; las nuevas, ordenadas.

    Tools/v2/skadnetwork.py actualizar   # baja, une y escribe
    Tools/v2/skadnetwork.py verificar    # exit 1 si al Info.plist le falta alguna
"""
import re
import sys
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
INFO_PLIST = RAIZ / "FisuEvolution" / "Info.plist"
LISTAS = {
    "Unity": "https://skan.mz.unity3d.com/v3/partner/skadnetworks.plist.json",
}
ID = re.compile(r"[a-z0-9]{10}\.skadnetwork", re.IGNORECASE)
BLOQUE = re.compile(r"(<key>SKAdNetworkItems</key>\s*<array>)(.*?)(\n\t</array>)", re.DOTALL)


def ids_en(texto):
    """Los IDs que aparezcan, en minúscula y sin repetir: la forma de cada
    lista cambia de red en red, el ID no."""
    vistos = []
    for encontrado in ID.findall(texto):
        normal = encontrado.lower()
        if normal not in vistos:
            vistos.append(normal)
    return vistos


def union(actuales, nuevas):
    return list(actuales) + sorted(set(nuevas) - set(actuales))


def reescribir(plist, ids):
    encontrado = BLOQUE.search(plist)
    if not encontrado:
        raise SystemExit("no encontré <key>SKAdNetworkItems</key> en el Info.plist")
    cuerpo = "".join(
        f"\n\t\t<dict>\n\t\t\t<key>SKAdNetworkIdentifier</key>\n\t\t\t<string>{i}</string>\n\t\t</dict>"
        for i in ids
    )
    return plist[: encontrado.start(2)] + cuerpo + plist[encontrado.end(2):]


def bajar(url):
    with urllib.request.urlopen(url, timeout=20) as respuesta:
        return respuesta.read().decode("utf-8", errors="replace")


def deseados(plist):
    nuevas = []
    for red, url in LISTAS.items():
        de_la_red = ids_en(bajar(url))
        if not de_la_red:
            raise SystemExit(f"{red}: la lista vino vacía ({url})")
        print(f"{red}: {len(de_la_red)} IDs")
        nuevas += de_la_red
    return union(ids_en(plist), nuevas)


def main(argv):
    if len(argv) != 2 or argv[1] not in ("actualizar", "verificar"):
        raise SystemExit(__doc__)
    plist = INFO_PLIST.read_text(encoding="utf-8")
    ids = deseados(plist)
    if argv[1] == "verificar":
        faltan = sorted(set(ids) - set(ids_en(plist)))
        print(f"faltan {len(faltan)}" if faltan else f"completo: {len(ids)} IDs")
        return 1 if faltan else 0
    INFO_PLIST.write_text(reescribir(plist, ids), encoding="utf-8")
    print(f"Info.plist: {len(ids)} IDs")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
