"""El inventario: todo el arte del juego, leido de donde vive, una ficha por asset.

Las imagenes salen de los atlas y de `Backgrounds/`; los videos, de los masters del
generador (`video/<carpeta>/<id>.mp4`) y de lo que ya esta procesado en el juego.
Cada video se cuelga de la imagen que anima (el cuerpo entero de un puesto, la pose
de un visitante, el fondo de un piso); el que no anima ninguna imagen del juego
—un evento, una cinematica, la cabina— es una ficha propia, solo de video.

Nada de esto es del dueno: se rehace en cada arranque. Lo del dueno (estados,
notas, marcas) vive en el registro y se le pega encima (`registro.py`).
"""

from __future__ import annotations

import json
import re
from functools import cache
from pathlib import Path

import rutas
from rutas import PIPELINE, RESOURCES

from process_dropbox import destination  # noqa: E402  (rutas pone scripts/ en el path)

ATLASES = (
    "earth.atlas", "cosmic.atlas", "specials.atlas", "npcs.atlas",
    "fam_pijama.atlas", "fam_gaucho.atlas", "fam_dinosaurio.atlas", "ui.atlas",
)
FAMILIAS = ("pijama", "gaucho", "dinosaurio")
ORIGINALES = PIPELINE / "dropbox" / "procesadas"
ORIGINALES_APARTE = {"homeless": PIPELINE / "heroes" / "approved" / "fisura.png"}

TIPOS = (
    "personaje base", "skin", "visitante/especial", "retrato", "ícono", "evento",
    "objeto", "fondo", "UI", "cinemática",
)
TIPOS_DE_SKIN = ("base", "oro", "diamante", "temática", "pijama", "gaucho", "dinosaurio")

# Carpeta de masters -> clase de pieza de `video_assets.py`.
CARPETAS_DE_VIDEO = {
    "personajes": "personaje", "visitantes": "visitante", "loops": "retrato",
    "fondos": "fondo", "objetos": "objeto", "ascensor": "cabina",
    "cinematicas": "cinematica", "eventos": "evento", "iconos": "icono",
}
TIPO_DE_VIDEO_SOLO = {
    "retrato": "visitante/especial", "objeto": "objeto", "cabina": "cinemática",
    "cinematica": "cinemática", "evento": "evento", "icono": "ícono",
    "personaje": "personaje base", "visitante": "visitante/especial", "fondo": "fondo",
}
VERSION = re.compile(r"^(?P<base>.+?)(?:_v(?P<n>[0-9]+))?$")

PREFIJOS_ICONO = (
    "ui_shop_", "ui_up_", "ui_boost_", "ui_oro", "ui_menu_", "ui_coin", "ui_money",
    "ui_trophy_", "ui_daily", "ui_gift", "ui_elevator", "ui_chest", "ui_tab_gifts",
    "ui_tab_menu", "ui_tab_shop", "ui_tab_skins", "ui_tab_upgrades", "wheel_icon", "mattress_icon",
)


@cache
def prompts() -> dict[str, dict]:
    return {e["assetKey"]: e for e in json.loads((PIPELINE / "prompts" / "prompts.json").read_text())}


@cache
def _textos() -> dict[str, str]:
    crudo = json.loads((RESOURCES / "Localizable.xcstrings").read_text())["strings"]
    textos = {}
    for clave, valor in crudo.items():
        unidad = valor.get("localizations", {}).get("es", {}).get("stringUnit", {})
        if unidad.get("value"):
            textos[clave] = unidad["value"]
    return textos


@cache
def _nombres_de_tipo() -> dict[str, str]:
    tipos = json.loads((RESOURCES / "Data" / "tiers.json").read_text())["types"]
    return {t["id"]: t["displayName"] for t in tipos}


def nombre_de_personaje(personaje: str) -> str:
    if not personaje:
        return ""
    textos = _textos()
    for clave in (f"visitor.{personaje}.name", f"special.{personaje.removeprefix('sp_')}.name"):
        if clave in textos:
            return textos[clave]
    return _nombres_de_tipo().get(personaje, personaje.replace("_", " ").capitalize())


def nombre_de_skin(skin: str) -> str:
    return _textos().get(f"skin.name.{skin}", skin.replace("_", " ").capitalize()) if skin else ""


def clave_de_sprite(sprite: str) -> str:
    """`administrativo_idle__oro` -> `administrativo__oro`; `homeless_idle` -> `homeless`."""
    if "_idle__" in sprite:
        return sprite.replace("_idle__", "__", 1)
    return sprite.removesuffix("_idle")


def tipo_de_skin(clave: str) -> str:
    skin = clave.partition("__")[2]
    if not skin:
        return "base"
    if skin in ("oro", "diamante") or skin in FAMILIAS:
        return skin
    return "temática"


def personaje_de(clave: str) -> str:
    base = clave.partition("__")[0]
    for sufijo in ("_talk", "_action", "_face"):
        base = base.removesuffix(sufijo)
    return base


def tipo_de(clave: str, atlas: str, categoria: str | None) -> str:
    if categoria == "background" or atlas == "Backgrounds":
        return "fondo"
    if clave.endswith("_face"):
        return "retrato"
    if categoria in ("skin", "skinfam") or "__" in clave:
        return "skin"
    if categoria == "character" or atlas in ("earth.atlas", "cosmic.atlas"):
        return "personaje base"
    if categoria in ("npc", "special") or clave.startswith(("npc_", "sp_")):
        return "visitante/especial"
    if clave.startswith(PREFIJOS_ICONO):
        return "ícono"
    if clave.startswith(("pickup_", "mattress")):
        return "objeto"
    return "UI"


def categoria_para_exportar(clave: str, atlas: str) -> str:
    """La `category` de `process_dropbox.export_size` (decide el tamano @2x/@3x)."""
    if clave in prompts():
        return prompts()[clave].get("category", "character")
    if atlas == "npcs.atlas":
        return "npc"
    if atlas in ("ui.atlas",):
        return "ui"
    return "skin" if "__" in clave else "character"


def original_de(clave: str) -> Path | None:
    """El PNG con fondo blanco del que salen los recortes, o None."""
    d = rutas.datos()
    for importado in sorted(d["importaciones"].glob(f"{clave}.*")):
        if importado.suffix.lower() in (".png", ".jpg", ".jpeg"):
            return importado
    candidatos = [ORIGINALES_APARTE.get(clave), ORIGINALES / f"{clave}.png"]
    entrada = prompts().get(clave, {})
    candidatos.append(d["generador"] / "output" / f"{entrada.get('generado_como', clave)}.png")
    for ruta in candidatos:
        if ruta and ruta.exists():
            return ruta
    return None


def _ficha(clave: str, tipo: str, atlas: str, sprite: str, juego: Path | None) -> dict:
    tskin = tipo_de_skin(clave) if tipo in ("skin", "personaje base") else ""
    personaje = personaje_de(clave) if tipo in ("skin", "personaje base", "visitante/especial", "retrato") else ""
    skin = clave.partition("__")[2]
    nombre = nombre_de_personaje(personaje) or clave
    if skin:
        nombre += f" — {nombre_de_skin(skin)}"
    elif clave.endswith(("_talk", "_action", "_face")):
        nombre += {"_talk": " (habla)", "_action": " (pide)", "_face": " (cara)"}[clave[clave.rfind("_"):]]
    original = original_de(clave)
    return {
        "id": clave,
        "nombre": nombre,
        "tipo": tipo,
        "personaje": personaje,
        "tipo_skin": tskin,
        "atlas": atlas.removesuffix(".atlas"),
        "sprite": sprite,
        "categoria": categoria_para_exportar(clave, atlas) if atlas != "Backgrounds" else "background",
        "en_prompts": clave in prompts(),
        "archivos": {
            "original": str(original) if original else None,
            "juego": str(juego) if juego else None,
        },
        "video": None,
    }


def imagenes() -> dict[str, dict]:
    """Cada sprite del juego (los @3x de los atlas) y cada fondo."""
    por_sprite = {}
    for clave, entrada in prompts().items():
        if entrada.get("category") == "background":
            continue
        try:
            atlas, sprite, _ = destination(entrada)
        except (KeyError, ValueError):
            continue
        por_sprite[(atlas, sprite)] = clave

    fichas: dict[str, dict] = {}
    for atlas in ATLASES:
        for png in sorted((RESOURCES / atlas).glob("*@3x.png")):
            sprite = png.name.removesuffix("@3x.png")
            clave = por_sprite.get((atlas, sprite), clave_de_sprite(sprite))
            categoria = prompts().get(clave, {}).get("category")
            fichas[clave] = _ficha(clave, tipo_de(clave, atlas, categoria), atlas, sprite, png)
    for jpg in sorted((RESOURCES / "Backgrounds").glob("bg_*.jpg")):
        fichas[jpg.stem] = _ficha(jpg.stem, "fondo", "Backgrounds", jpg.stem, jpg)
    return fichas


def _revision() -> dict:
    ruta = rutas.datos()["revision_videos"]
    return json.loads(ruta.read_text()) if ruta.exists() else {}


def _ruta_mov(kind: str, id_juego: str) -> Path | None:
    import video_assets

    spec = video_assets.KINDS[kind]
    nombre = f"{spec['prefix']}{id_juego}.mov"
    try:
        ruta = video_assets.piece_dir(kind, id_juego) / nombre
        if ruta.exists():
            return ruta
    except (ValueError, StopIteration):
        pass
    for carpeta in (RESOURCES / spec["dir"], *sorted((RESOURCES / "AnimPacks").glob("*"))):
        if (carpeta / nombre).exists():
            return carpeta / nombre
    return None


def videos() -> list[dict]:
    """Un video por pieza del juego: el master que va (el de `revision.json` en
    "va", o la version mas nueva) y el `.mov` que esta en el juego."""
    import video_assets

    generador = rutas.datos()["generador"] / "video"
    revision = _revision()
    piezas = []
    for carpeta, kind in CARPETAS_DE_VIDEO.items():
        prefijo_master = video_assets.KINDS[kind].get("master_prefix", "")
        grupos: dict[str, list[tuple[int, Path]]] = {}
        for master in sorted((generador / carpeta).glob("*.mp4")):
            partes = VERSION.match(master.stem)
            if re.search(r"_v[0-9]+_", master.stem):
                continue  # `arresto_v1_con_texto`: una prueba descartada, no una version
            base = partes["base"].removeprefix(prefijo_master)
            grupos.setdefault(base, []).append((int(partes["n"] or 0), master))
        for id_juego, masters in sorted(grupos.items()):
            def peso(item):
                numero, master = item
                return (revision.get(f"{carpeta}/{master.stem}", {}).get("estado") == "va", numero)

            _, master = max(masters, key=peso)
            clave_revision = f"{carpeta}/{master.stem}"
            mov = _ruta_mov(kind, id_juego)
            piezas.append({
                "kind": kind,
                "carpeta": carpeta,
                "id_juego": id_juego,
                "clave_revision": clave_revision,
                "master": str(master),
                "mov": str(mov) if mov else None,
                "archivo_mov": f"{video_assets.KINDS[kind]['prefix']}{id_juego}.mov",
                "revision": revision.get(clave_revision),
            })
    return piezas


def clave_de_imagen(video: dict) -> str:
    kind, id_juego = video["kind"], video["id_juego"]
    return "bg_" + id_juego if kind == "fondo" else id_juego


def catalogo() -> dict[str, dict]:
    """Imagenes + videos, cada video colgado de su imagen o en una ficha propia."""
    fichas = imagenes()
    for video in videos():
        clave = clave_de_imagen(video)
        if video["kind"] in ("personaje", "visitante", "retrato", "fondo") and clave in fichas \
                and fichas[clave]["video"] is None:
            fichas[clave]["video"] = video
            continue
        prefijo = video["archivo_mov"].removesuffix(".mov")
        tipo = TIPO_DE_VIDEO_SOLO[video["kind"]]
        ficha = _ficha(prefijo, tipo, "", "", None)
        ficha["solo_video"] = True
        ficha["personaje"] = personaje_de(video["id_juego"]) if video["id_juego"].startswith(("npc_", "sp_")) else ""
        ficha["nombre"] = (nombre_de_personaje(ficha["personaje"]) + " (loop)") if ficha["personaje"] \
            else video["id_juego"].replace("_", " ").capitalize()
        ficha["archivos"]["original"] = None
        poster = _poster(video)
        ficha["archivos"]["poster"] = str(poster) if poster else None
        ficha["video"] = video
        fichas[prefijo] = ficha
    return fichas


def _poster(video: dict) -> Path | None:
    """Una imagen fija para la ficha de un video sin imagen propia."""
    generador = rutas.datos()["generador"]
    candidatos = [
        generador / "video" / video["carpeta"] / "frames" / f"{video['id_juego']}.png",
        generador / "output" / f"{video['id_juego']}.png",
    ]
    for atlas in ("specials.atlas", "npcs.atlas"):
        candidatos.append(RESOURCES / atlas / f"{video['id_juego']}@3x.png")
    return next((c for c in candidatos if c.exists()), None)
