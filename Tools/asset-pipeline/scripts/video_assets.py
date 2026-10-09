#!/usr/bin/env python3
"""Los masters de Higgsfield -> los loops y las cinematicas del juego.

PLAN-v2 E8, "Pipeline de video". Estas clases de pieza:

- **Retratos**: los 18 loops de visitante (Kling, cuadro inicial = final = la
  canonica). HEVC con alfa, 512x512, sin sonido, en `Resources/Loops/`.
- **Objetos**: el Paquete de la Aduana y el Colchon, su apertura y su espera en
  loop. Como los retratos, 512x512 con alfa, en `Resources/Loops/`.
- **Cabina**: las puertas del ascensor que cierran y abren. 720x1280 en
  `Resources/Cinematics/`, opaca salvo el hueco y las ventanas. Mas sus dos
  cuadros fijos en PNG (`cabina-cuadros`), el respaldo del juego si faltan los
  clips; esos no van al manifest: el juego los pide por nombre.
- **Cinematicas**: intro, reencarnacion, arresto y Dios (Seedance). 720x1280,
  en `Resources/Cinematics/`, con la pista de sonido del master si la trae.
- **Personajes**: los cuerpos enteros de los puestos y los especiales, en loop.
  512x512 con alfa, `char_<id>` en `Resources/Loops/`.
- **Visitantes**: las poses de los visitantes (`_talk`, `_action`) en loop.
  512x512 con alfa, `vis_<id>` en `Resources/Loops/`.
- **Eventos**: las ilustraciones de los eventos, en loop. 512x512 con alfa,
  `ev_<id>` en `Resources/Loops/`.
- **Iconos**: las mejoras de la tienda de ORO, en loop. 256x256 con alfa,
  `icon_<id>` en `Resources/Loops/`.
- **Fondos**: el fondo de cada piso, en loop. 1024x1024 opaco, `bgloop_<piso>`
  en `Resources/Backgrounds/Loops/` (el master es `video/fondos/bg_<piso>.mp4`).

**On-Demand Resources.** Lo pesado de la segunda tanda (personajes, poses,
eventos, iconos) viaja en packs y no en el paquete base: el `.mov` sale a
`Resources/AnimPacks/<tag>/` y su entrada lleva `odrTag` (ver `odr_tag`). Retratos,
objetos, cabina, cinematicas y fondos quedan en el paquete base.

**Regla del dueno (2026-10-08): el arte va sobre fondo blanco.** Todo lo que
lleva alfa salvo la cabina se recorta cuadro por cuadro con el criterio topologico de
`whitebg_cutout.py` (fondo = lo blanco conectado al borde), que no se come lo
blanco de adentro del dibujo. El verde croma, con el keying del cofre
(`chest_video_frames.py`), queda solo para la mascara de la cabina: el hueco y
las ventanas por donde el codigo muestra el piso.

`Resources/Data/loops_manifest.json` es EL contrato con el runtime: una pieza
con entrada ahi se reproduce, una sin entrada cae al arte quieto (la regla de
oro de `assets_manifest.json`). Lo pinea `test_video_assets` y, del lado del
juego, un test en Swift.

**El verde del key se mide en cada master, no se fija a mano.** El del cofre se
calibro a ojo y dos masters dieron dos verdes distintos (ver el docstring de
`chest_video_frames.py`): un master nuevo con el verde del anterior se come al
personaje. Se mide como alla, en el stream con la matriz limited-range, en tres
cuadros: en las cuatro esquinas, o, en la cabina (cuyas esquinas son la pared),
en lo que es verde pleno del cuadro. Si no da un verde liso, el script se niega
en vez de adivinar.

    .venv/bin/python scripts/video_assets.py medir video/chest-animation.mp4
    .venv/bin/python scripts/video_assets.py retrato npc_comisario
    .venv/bin/python scripts/video_assets.py objeto paquete_espera
    .venv/bin/python scripts/video_assets.py cabina puertas_abren
    .venv/bin/python scripts/video_assets.py cabina-cuadros [--dir video/ascensor]
    .venv/bin/python scripts/video_assets.py cinematica arresto [--sin-key]
    .venv/bin/python scripts/video_assets.py personaje god
    .venv/bin/python scripts/video_assets.py personaje sp_influencer \
        --video video/personajes/sp_influencer_v2.mp4
    .venv/bin/python scripts/video_assets.py fondo alley

Los masters van en `video/<carpeta de la clase>/<id>.mp4` (`--video` para otro:
una version corregida, `_v2`, entra con el id del juego, sin el sufijo). No se
versionan: la fuente es `automatic-image-generation`, y su `revision.json` dice
cuales van. Necesita `ffmpeg` con `hevc_videotoolbox` en el PATH.
"""

from __future__ import annotations

import argparse
import functools
import json
import multiprocessing
import re
import shutil
import subprocess
import sys
from fractions import Fraction
from pathlib import Path

import numpy as np
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import write_json  # noqa: E402
from whitebg_cutout import (  # noqa: E402
    TODOS_LOS_BORDES,
    WHITE_TOLERANCE,
    alpha_from_background,
    background_mask,
    islas_de_papel,
    undo_white_matte,
    white_distance,
)
from chest_video_frames import (  # noqa: E402
    HEVC_ALPHA_QUALITY,
    HEVC_QUALITY,
    KEY_BLEND,
    KEY_SIMILARITY,
    key_filter,
)

PIPELINE = Path(__file__).resolve().parent.parent
RESOURCES = PIPELINE.parent.parent / "FisuEvolution" / "Resources"
MANIFEST = RESOURCES / "Data" / "loops_manifest.json"
MASTERS = PIPELINE / "video"

SCHEMA_VERSION = 1

# Un busto lo corta el marco de abajo: ahi apoya la camisa, y el fondo blanco
# se siembra solo desde los otros tres lados (ver `background_mask`).
BUSTO = ("arriba", "izquierda", "derecha")

# Las piezas cuyo blanco encerrado se decide midiendo, como `PAPEL_MEDIDO` de
# los PNG. La aureola del Contador Dios es un anillo en perspectiva que se cierra
# contra la cabeza: el aire de adentro queda encerrado y mide como el lienzo
# (0.3-0.4), cuadro tras cuadro. La camisa tambien mide como lienzo (0.1), pero
# toca el marco de abajo, y eso la deja afuera (ver `cutout_frame`). Los ojos y
# los dientes tambien miden como papel: por eso es una lista, y por eso cuenta
# solo la isla de mas del 0.4% del cuadro. En el Contador, los dos lados del
# aire de la aureola miden ~0.7% en los 121 cuadros; el blanco de un ojo abierto
# del todo, 0.17% como mucho.
#
# Los cuerpos enteros traen el mismo caso que los PNG de `PAPEL_MEDIDO`: el aire
# entre las piernas que cierra la sombra del piso (cartonero, estanciero, rey de
# los asteroides), el de adentro del llavero (pyme) y el que encierran las
# orbitas (magnate solar). Medido en los 53: son los unicos con una isla de
# papel de mas del 0.4%; la bandera blanca del dueno de la Luna tambien mide
# como papel, pero es dibujo, y por eso no esta.
PAPEL_MEDIDO_VIDEO = frozenset({
    "sp_contador_dios",
    "cartonero", "estanciero_estelar", "rey_asteroides", "dueno_pyme", "magnate_solar",
})
MIN_AIRE_FRACTION = 0.004

# El despill de la cabina. El del cofre le saca al verde lo que le sobra sobre
# el promedio de rojo y azul: el marco amarillo sale naranja y la pared crema,
# durazno. Sin despill, el filo de la mascara (verde mezclado con la linea negra)
# queda como un hilo verde alrededor del hueco. Este le pone al verde de tope el
# mayor de rojo y azul: el amarillo, el crema, el acero y el negro ya estan
# debajo y no cambian; el hilo verde se apaga a la linea negra.
DESPILL_TOPE = "geq=r='r(X,Y)':g='min(g(X,Y),max(r(X,Y),b(X,Y)))':b='b(X,Y)':a='alpha(X,Y)'"

# Cada clase de pieza: carpeta en Resources, seccion del manifest, prefijo del
# archivo, tamano de salida, carpeta de sus masters y de donde sale el alfa
# (`matte`): "blanco" es el recorte topologico, "verde" el key medido. El prefijo
# no es adorno: Xcode aplana los recursos en la raiz del bundle, asi que dos
# `.mov` con el mismo nombre en carpetas distintas se pisan al copiarse.
KINDS = {
    "retrato": {
        "dir": "Loops", "section": "portraits", "prefix": "loop_",
        "size": (512, 512), "masters": "loops", "matte": "blanco", "bordes": BUSTO,
    },
    "objeto": {
        "dir": "Loops", "section": "objects", "prefix": "obj_",
        "size": (512, 512), "masters": "objetos", "matte": "blanco",
        "bordes": TODOS_LOS_BORDES,
    },
    "cabina": {
        "dir": "Cinematics", "section": "cabin", "prefix": "cabina_",
        "size": (720, 1280), "masters": "ascensor", "matte": "verde", "despill": "tope",
    },
    "cinematica": {
        "dir": "Cinematics", "section": "cinematics", "prefix": "cine_",
        "size": (720, 1280), "masters": "cinematicas", "matte": "verde",
    },
    # Cuerpos enteros, poses, eventos e iconos flotan en el lienzo: ninguno
    # toca el marco de abajo (medido en los 26 masters de visitante), asi que
    # se siembran desde los cuatro lados.
    "personaje": {
        "dir": "Loops", "section": "characters", "prefix": "char_",
        "size": (512, 512), "masters": "personajes", "matte": "blanco",
        "bordes": TODOS_LOS_BORDES,
    },
    "visitante": {
        "dir": "Loops", "section": "talking", "actions_section": "visitorActions",
        "prefix": "vis_",
        "size": (512, 512), "masters": "visitantes", "matte": "blanco",
        "bordes": TODOS_LOS_BORDES,
    },
    "evento": {
        "dir": "Loops", "section": "events", "prefix": "ev_",
        "size": (512, 512), "masters": "eventos", "matte": "blanco",
        "bordes": TODOS_LOS_BORDES,
    },
    "icono": {
        "dir": "Loops", "section": "shopIcons", "prefix": "icon_",
        "size": (256, 256), "masters": "iconos", "matte": "blanco",
        "bordes": TODOS_LOS_BORDES,
    },
    # El fondo del piso es una escena entera: opaco, sin recorte ni key.
    "fondo": {
        "dir": "Backgrounds/Loops", "section": "floors", "prefix": "bgloop_",
        "size": (1024, 1024), "masters": "fondos", "matte": None,
        "master_prefix": "bg_",
    },
}

# Las secciones del manifest, en el orden de KINDS (las poses de un visitante
# abren dos: lo que habla y lo que pide).
SECTIONS = tuple(dict.fromkeys(
    section
    for spec in KINDS.values()
    for section in (spec["section"], spec.get("actions_section"))
    if section
))

# Los packs On-Demand Resources (`odrTag` del manifest). Lo que no figura aca
# viaja en el paquete base: retratos, objetos, cabina, cinematicas y fondos.
ODR_SPECIALS = "anim-especiales"
ODR_VISITORS = "anim-visitantes"
ODR_EVENTS = "anim-eventos"
ODR_SHOP = "anim-tienda"

# Las piezas con nombre fijo; el juego las pide por este id. Las cinematicas
# son las tres del plan (E8, "Cuando se reproducen"); el Paquete y el Colchon
# tienen una apertura y una espera en loop; la cabina, las puertas en un sentido
# y en el otro (E13, item 13).
CINEMATIC_IDS = ("intro", "reencarnacion", "arresto", "dios")
OBJECT_IDS = ("paquete_abre", "paquete_espera", "colchon_abre", "colchon_espera")
CABIN_IDS = ("puertas_cierran", "puertas_abren")
EVENT_IDS = (
    "aguinaldo", "blanqueo", "cayo_mercado_pago", "corralito", "devaluacion",
    "inversion_alienigena", "plan_platita", "startup_comprada",
)
ICON_IDS = tuple(f"ui_oro_{n}" for n in (
    "autotap", "better_supplier", "daily_boost", "extra_slots", "extra_spins",
    "income_boost", "merge_all", "offline_boost", "package_rain", "time_skip",
))
FLOOR_IDS = (
    "alley", "urban", "corporate", "luxury", "island",
    "moon", "mars", "solar", "galaxy", "god_realm",
)
FIXED_IDS = {
    "cinematica": CINEMATIC_IDS, "objeto": OBJECT_IDS, "cabina": CABIN_IDS,
    "evento": EVENT_IDS, "icono": ICON_IDS, "fondo": FLOOR_IDS,
}
# Los cuadros fijos de la cabina: el master y el PNG del juego se llaman igual.
CABIN_STILLS = ("cabina_cerrada.png", "cabina_abierta.png")

# Un retrato es el loop de la canonica de un visitante: `npc_<nombre>` o
# `sp_<id>`. Las poses (`_talk`, `_action`, `_face`) no tienen loop propio.
PORTRAIT_ID = re.compile(r"(npc|sp)_[a-z0-9]+(_[a-z0-9]+)*")
POSE_SUFFIXES = ("_talk", "_action", "_face")

# Un visitante es una pose animada: `_talk` (todos) o `_action` (los npc).
VISITOR_ID = re.compile(r"(npc_[a-z0-9]+_(talk|action)|sp_[a-z0-9]+(_[a-z0-9]+)*_talk)")

# Un personaje es el assetKey del puesto o del especial (`god`, `senior_doctor`,
# `sp_lizard`). Un sufijo de version (`_v2`) es del master, nunca del juego.
CHARACTER_ID = re.compile(r"[a-z0-9]+(_[a-z0-9]+)*")
VERSION_SUFFIX = re.compile(r".*_v[0-9]+")

# La medicion del verde: un parche por esquina en el primer cuadro, el del medio
# y el ultimo. En el master del cofre las esquinas se mueven de a 1-3 por canal
# (R 31-34, G 146-148, B 73-76) y la mediana da 0x22934C, a 2 del verde que se
# calibro a mano: 12 de tolerancia deja pasar la compresion y no un objeto.
CORNER_PATCH = 8
MAX_CORNER_SPREAD = 12
MIN_GREEN_LEAD = 40

# En la cabina el verde se busca adentro del cuadro: cuenta el pixel cuyo verde
# le saca al rojo y al azul el doble de lo minimo (asi el filo antialiaseado,
# mezclado con el marco amarillo, no tira la mediana), y tiene que haber al
# menos un 1% del cuadro asi. Las ventanas solas, con la puerta cerrada, son ~9%.
# El verde de las ventanas y el del hueco no son el mismo: en las puertas de
# Kling el azul va de 13 a 37 de un cuadro a otro (R ~4, G ~246). En el plano
# de color de `chromakey` eso es ~0.05, la mitad de la `similarity` del cofre:
# un solo verde los saca a los dos, y la tolerancia se abre a 30 para medirlo.
MASK_GREEN_LEAD = 2 * MIN_GREEN_LEAD
MIN_MASK_FRACTION = 0.01
MAX_MASK_SPREAD = 30


class MasterError(ValueError):
    """El master no sirve tal como vino: se avisa en vez de adivinar."""


def validate_id(kind: str, piece_id: str) -> None:
    if kind in FIXED_IDS:
        if piece_id not in FIXED_IDS[kind]:
            raise ValueError(
                f"{kind} desconocido: {piece_id!r}; los del plan son {FIXED_IDS[kind]}"
            )
        return
    if VERSION_SUFFIX.fullmatch(piece_id):
        raise ValueError(
            f"{piece_id!r} trae sufijo de version: el id es el del juego, "
            "y el master corregido entra con --video"
        )
    if kind == "personaje":
        if not CHARACTER_ID.fullmatch(piece_id):
            raise ValueError(f"personaje invalido {piece_id!r}: es un assetKey en snake_case")
        return
    if kind == "visitante":
        if not VISITOR_ID.fullmatch(piece_id):
            raise ValueError(
                f"visitante invalido {piece_id!r}: `npc_<nombre>_talk|_action` "
                "o `sp_<id>_talk`"
            )
        return
    if not PORTRAIT_ID.fullmatch(piece_id) or piece_id.endswith(POSE_SUFFIXES):
        raise ValueError(
            f"retrato invalido {piece_id!r}: es la canonica de un visitante, "
            "`npc_<nombre>` o `sp_<id>`, sin sufijo de pose"
        )


def key_color_from_patches(patches: list[np.ndarray],
                           max_spread: float = MAX_CORNER_SPREAD) -> str:
    """El verde de fondo como `0xRRGGBB`, o MasterError si no es un verde liso.

    Cada parche es un array (..., 3): una esquina, o lo verde de un cuadro de la
    cabina. La mediana del conjunto es el verde; si un parche se aparta, hay
    algo encima del fondo (el personaje, un logo, un degrade) y el key saldria
    mal en todo el video."""
    medians = np.array([np.median(p.reshape(-1, 3), axis=0) for p in patches])
    color = np.median(medians, axis=0)
    spread = float(np.abs(medians - color).max())
    if spread > max_spread:
        raise MasterError(
            f"el verde no es liso (los parches se apartan {spread:.0f}): "
            "algo tapa una esquina o el fondo tiene degrade"
        )
    r, g, b = color
    if g - max(r, b) < MIN_GREEN_LEAD:
        raise MasterError(f"el fondo no es verde: mide {tuple(int(c) for c in color)}")
    return "0x{:02X}{:02X}{:02X}".format(*(int(round(c)) for c in color))


def probe(video: Path) -> dict:
    return json.loads(subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(video)],
        capture_output=True, text=True, check=True,
    ).stdout)


def video_stream(info: dict) -> dict:
    return next(s for s in info["streams"] if s["codec_type"] == "video")


def has_audio(info: dict) -> bool:
    return any(s["codec_type"] == "audio" for s in info["streams"])


def green_patches(frames: np.ndarray) -> list[np.ndarray]:
    """Lo que es verde pleno en cada cuadro: un parche por cuadro.

    Para la cabina, cuyas esquinas son la pared. La puerta se mueve y el hueco
    cambia de tamano, pero las ventanas estan siempre: en cada cuadro hay verde."""
    patches = []
    for frame in frames:
        rgb = frame.astype(np.int16)
        lead = rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])
        green = frame[lead >= MASK_GREEN_LEAD]
        if len(green) < MIN_MASK_FRACTION * lead.size:
            raise MasterError(
                f"un cuadro casi no tiene verde ({len(green)} pixeles): "
                "la mascara del hueco y las ventanas no esta"
            )
        patches.append(green)
    return patches


def measure_key_color(video: Path, en_el_cuadro: bool = False) -> str:
    """Mide el verde del master en el stream, como lo ve `chromakey`.

    La conversion a rgb24 la hace ffmpeg con su matriz por defecto
    (limited-range), que es la que hace falta: el hex sacado con la matriz
    full-range parece el mismo verde y no lo es (trampa del cofre).

    `en_el_cuadro` lo busca en lo verde de adentro del cuadro y no en las
    esquinas: es la cabina, una pared con un hueco verde."""
    stream = video_stream(probe(video))
    width, height = int(stream["width"]), int(stream["height"])
    frames = int(stream.get("nb_frames") or 1)
    picks = sorted({0, frames // 2, frames - 1})
    select = "+".join(f"eq(n\\,{n})" for n in picks)
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(video), "-vf", f"select={select}",
         "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True, check=True,
    ).stdout
    decoded = np.frombuffer(raw, np.uint8).reshape(-1, height, width, 3)
    if en_el_cuadro:
        return key_color_from_patches(green_patches(decoded), MAX_MASK_SPREAD)
    p = CORNER_PATCH
    patches = [
        frame[y:y + p, x:x + p]
        for frame in decoded
        for y in (0, height - p)
        for x in (0, width - p)
    ]
    return key_color_from_patches(patches)


def framing_filter(kind: str, width: int, height: int) -> str:
    """Del cuadro del master al de la pieza.

    Retrato y objeto se recortan al cuadrado del centro (la canonica es cuadrada
    y Kling la respeta); cabina y cinematica cubren 720x1280 y recortan lo que
    sobra."""
    out_w, out_h = KINDS[kind]["size"]
    if out_w == out_h:
        side = min(width, height)
        return f"crop={side}:{side},scale={out_w}:{out_h}:flags=lanczos"
    return (
        f"scale={out_w}:{out_h}:force_original_aspect_ratio=increase:flags=lanczos,"
        f"crop={out_w}:{out_h}"
    )


def keyed_filter(kind: str, key_color: str, similarity: float, blend: float,
                 framing: str) -> str:
    """Key + despill + premultiplicado + encuadre, en ese orden.

    Premultiplicado ANTES de escalar: el filtro de escala promedia vecinos, y con
    el alfa recto el RGB de lo transparente (verde despillado) se colaria en el
    borde. Y premultiplicado porque `AVPlayerLayer` composita el HEVC-alfa asi
    (ver `encode_cinematic` del cofre: sin esto el fondo keyeado se suma al juego
    como un velo)."""
    if KINDS[kind].get("despill") == "tope":
        keying = (f"{key_filter(key_color, similarity, blend, despill=False)},"
                  f"format=gbrap,{DESPILL_TOPE}")
    else:
        keying = f"{key_filter(key_color, similarity, blend)},format=gbrap"
    return f"{keying},premultiply=inplace=1,{framing},format=bgra"


def encode(kind: str, master: Path, output: Path, key_color: str | None,
           similarity: float, blend: float) -> None:
    info = probe(master)
    stream = video_stream(info)
    framing = framing_filter(kind, int(stream["width"]), int(stream["height"]))
    if key_color is None:
        video_filter = f"{framing},format=yuv420p"
        video_args = ["-c:v", "hevc_videotoolbox", "-q:v", HEVC_QUALITY]
    else:
        video_filter = keyed_filter(kind, key_color, similarity, blend, framing)
        video_args = [
            "-c:v", "hevc_videotoolbox",
            "-alpha_quality", HEVC_ALPHA_QUALITY,
            "-q:v", HEVC_QUALITY,
        ]
    # Un loop de retrato es mudo; la cinematica lleva el sonido del master.
    audio_args = (
        ["-c:a", "aac", "-b:a", "160k"]
        if kind == "cinematica" and has_audio(info) else ["-an"]
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(master), "-vf", video_filter,
         *video_args, "-tag:v", "hvc1", *audio_args,
         "-fps_mode", "passthrough", "-y", str(output)],
        check=True,
    )


def cutout_frame(rgb: np.ndarray, bordes: tuple[str, ...], papel: bool = False) -> np.ndarray:
    """Un cuadro sobre fondo blanco -> RGBA premultiplicado, con `whitebg_cutout`.

    Lo mismo que `cutout` de alla, sin las excepciones a mano por asset (huecos
    calados, islas elegidas), que son de los PNG. `papel` suma las islas grandes
    que miden como el lienzo (`PAPEL_MEDIDO_VIDEO`), salvo las que tocan un borde:
    esas son la ropa del busto, que solo quedo encerrada porque no se siembra
    desde abajo. Premultiplicado por lo mismo que el camino del key: lo escala
    ffmpeg despues, y `AVPlayerLayer` composita el HEVC-alfa asi."""
    distance = white_distance(rgb)
    background = background_mask(distance, bordes=bordes)
    if papel:
        aire = islas_de_papel(rgb, background, distance <= WHITE_TOLERANCE)
        labels, count = ndimage.label(aire & ~background_mask(distance))
        if count:
            areas = ndimage.sum_labels(aire, labels, index=np.arange(1, count + 1))
            grandes = np.flatnonzero(areas >= MIN_AIRE_FRACTION * aire.size) + 1
            background = background | np.isin(labels, grandes)
    alpha = alpha_from_background(distance, background)
    color = undo_white_matte(rgb, alpha).astype(np.float32) * alpha[..., None]
    return np.dstack([
        color.round().astype(np.uint8),
        (alpha * 255).round().astype(np.uint8),
    ])


def encode_cutout(kind: str, master: Path, output: Path, papel: bool = False) -> None:
    """El camino del fondo blanco: un ffmpeg decodifica, Python recorta cada
    cuadro a la resolucion del master, y otro ffmpeg encuadra y codifica.

    El recorte va antes de escalar: el anillo de antialias del dibujo es de unos
    pocos pixeles, y achicado a 512 no queda de donde sacar la opacidad. Cuesta
    ~1 s por cuadro de 960x960, asi que los cuadros se reparten entre los
    nucleos (`imap` los devuelve en orden)."""
    spec = KINDS[kind]
    stream = video_stream(probe(master))
    width, height = int(stream["width"]), int(stream["height"])
    frame_bytes = width * height * 3
    output.parent.mkdir(parents=True, exist_ok=True)
    decoder = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-i", str(master), "-fps_mode", "passthrough",
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        stdout=subprocess.PIPE,
    )
    encoder = subprocess.Popen(
        ["ffmpeg", "-v", "error",
         "-f", "rawvideo", "-pix_fmt", "rgba", "-s", f"{width}x{height}",
         "-framerate", stream["r_frame_rate"], "-i", "-",
         "-vf", f"{framing_filter(kind, width, height)},format=bgra",
         "-c:v", "hevc_videotoolbox",
         "-alpha_quality", HEVC_ALPHA_QUALITY,
         "-q:v", HEVC_QUALITY,
         "-tag:v", "hvc1", "-an", "-y", str(output)],
        stdin=subprocess.PIPE,
    )

    def frames():
        while len(raw := decoder.stdout.read(frame_bytes)) == frame_bytes:
            yield np.frombuffer(raw, np.uint8).reshape(height, width, 3)

    recortar = functools.partial(cutout_frame, bordes=spec["bordes"], papel=papel)
    try:
        with multiprocessing.Pool() as pool:
            for rgba in pool.imap(recortar, frames(), chunksize=2):
                encoder.stdin.write(rgba.tobytes())
    finally:
        encoder.stdin.close()
        decoder.stdout.close()
    if decoder.wait() or encoder.wait():
        raise MasterError(f"ffmpeg fallo al recortar {master.name}")


def manifest_entry(output: Path, matte: str | None, key_color: str | None) -> dict:
    """Lo que el runtime necesita saber de la pieza, leido del archivo final."""
    info = probe(output)
    stream = video_stream(info)
    fps = Fraction(stream["r_frame_rate"])
    return {
        "file": output.name,
        "width": int(stream["width"]),
        "height": int(stream["height"]),
        "fps": int(fps) if fps.denominator == 1 else round(float(fps), 3),
        "frames": int(stream["nb_frames"]),
        "alpha": matte is not None,
        "audio": has_audio(info),
        # De donde salio el alfa ("blanco", "verde" o ninguno) y, si fue el key,
        # con que verde: si una pieza se ve comida, es lo primero que se mira.
        "matte": matte,
        "keyColor": key_color,
    }


def load_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {"schemaVersion": SCHEMA_VERSION, **{section: {} for section in SECTIONS}}


def target(kind: str, piece_id: str) -> tuple[str, str]:
    """Seccion y clave del manifest: el juego pide al visitante por su id, y la
    pose (`_talk`, `_action`) decide la seccion."""
    spec = KINDS[kind]
    if kind != "visitante":
        return spec["section"], piece_id
    base, _, pose = piece_id.rpartition("_")
    return (spec["section"] if pose == "talk" else spec["actions_section"]), base


@functools.cache
def floor_of_character() -> dict[str, int]:
    """El piso (1..10) de cada personaje de puesto, por `tiers.json` y `economy.json`."""
    data = RESOURCES / "Data"
    tiers = json.loads((data / "tiers.json").read_text(encoding="utf-8"))["types"]
    floors = json.loads((data / "economy.json").read_text(encoding="utf-8"))["floors"]
    return {
        t["id"]: next(
            n for n, f in enumerate(floors, start=1) if f["firstTier"] <= t["tier"] <= f["lastTier"]
        )
        for t in tiers
    }


def odr_tag(kind: str, piece_id: str) -> str | None:
    """El pack ODR de una pieza; `None` si va en el paquete base."""
    if kind == "personaje":
        if piece_id.startswith("sp_"):
            return ODR_SPECIALS
        floor = floor_of_character().get(piece_id)
        if floor is None:
            raise ValueError(f"personaje {piece_id!r} sin piso en tiers.json: no hay pack")
        return f"anim-piso-{floor}"
    return {"visitante": ODR_VISITORS, "evento": ODR_EVENTS, "icono": ODR_SHOP}.get(kind)


def piece_dir(kind: str, piece_id: str) -> Path:
    """Donde vive el `.mov`: la carpeta de su clase, o la de su pack ODR."""
    tag = odr_tag(kind, piece_id)
    return RESOURCES / "AnimPacks" / tag if tag else RESOURCES / KINDS[kind]["dir"]


def register(kind: str, piece_id: str, entry: dict) -> None:
    manifest = load_manifest()
    name, key = target(kind, piece_id)
    section = manifest.setdefault(name, {})
    section[key] = entry
    manifest[name] = dict(sorted(section.items()))
    # Las secciones siempre todas y en el orden de KINDS: un manifest de antes
    # de una clase nueva la gana vacia, y el diff no baila.
    write_json(MANIFEST, {
        "schemaVersion": manifest["schemaVersion"],
        **{section: manifest.get(section, {}) for section in SECTIONS},
    })


def process(kind: str, piece_id: str, master: Path, keyed: bool = True,
            similarity: float = KEY_SIMILARITY, blend: float = KEY_BLEND) -> dict:
    """Master -> pieza en Resources + su entrada en el manifest. Devuelve la entrada."""
    validate_id(kind, piece_id)
    if kind != "cinematica" and not keyed:
        raise ValueError(
            f"la pieza {kind!r} va siempre con alfa: --sin-key es de las cinematicas"
        )
    spec = KINDS[kind]
    matte = spec["matte"] if keyed else None
    output = piece_dir(kind, piece_id) / f"{spec['prefix']}{piece_id}.mov"
    key_color = None
    if matte == "blanco":
        encode_cutout(kind, master, output, papel=piece_id in PAPEL_MEDIDO_VIDEO)
    else:
        if matte == "verde":
            key_color = measure_key_color(master, en_el_cuadro=kind == "cabina")
        encode(kind, master, output, key_color, similarity, blend)
    entry = manifest_entry(output, matte, key_color)
    if tag := odr_tag(kind, piece_id):
        entry["odrTag"] = tag
    register(kind, piece_id, entry)
    return entry


def process_cabin_stills(source_dir: Path, similarity: float = KEY_SIMILARITY,
                         blend: float = KEY_BLEND) -> list[Path]:
    """Los dos cuadros fijos de la cabina -> PNG con alfa de 720x1280, con el key
    de los clips. El juego los usa solo si no estan los clips (E13b T5), y los
    pide por nombre: no van al manifest. Devuelve los PNG escritos."""
    written = []
    for still in CABIN_STILLS:
        source = source_dir / still
        if not source.exists():
            raise MasterError(f"no existe el cuadro {source}")
        key_color = measure_key_color(source, en_el_cuadro=True)
        stream = video_stream(probe(source))
        framing = framing_filter("cabina", int(stream["width"]), int(stream["height"]))
        output = RESOURCES / KINDS["cabina"]["dir"] / still
        output.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["ffmpeg", "-v", "error", "-i", str(source),
             "-vf", keyed_filter("cabina", key_color, similarity, blend, framing),
             "-frames:v", "1", "-update", "1", "-y", str(output)],
            check=True,
        )
        written.append(output)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    medir = sub.add_parser("medir", help="imprime el verde de fondo de un master")
    medir.add_argument("video", type=Path)
    for kind in KINDS:
        piece = sub.add_parser(kind)
        piece.add_argument("id")
        piece.add_argument("--video", type=Path, help="el master, si no esta en video/")
        if KINDS[kind]["matte"] == "verde":
            piece.add_argument("--similarity", type=float, default=KEY_SIMILARITY)
            piece.add_argument("--blend", type=float, default=KEY_BLEND)
        if kind == "cinematica":
            piece.add_argument("--sin-key", action="store_true",
                               help="la escena trae su propio fondo: opaca, sin alfa")
    cuadros = sub.add_parser("cabina-cuadros", help="los dos cuadros fijos de la cabina")
    cuadros.add_argument("--dir", type=Path, default=MASTERS / KINDS["cabina"]["masters"])
    cuadros.add_argument("--similarity", type=float, default=KEY_SIMILARITY)
    cuadros.add_argument("--blend", type=float, default=KEY_BLEND)
    args = parser.parse_args()

    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        print("[ERROR] ffmpeg/ffprobe no estan en el PATH", file=sys.stderr)
        return 1

    try:
        if args.command == "medir":
            print(measure_key_color(args.video))
            return 0
        if args.command == "cabina-cuadros":
            for still in process_cabin_stills(args.dir, args.similarity, args.blend):
                print(f"[OK] {still.name}")
            return 0
        spec = KINDS[args.command]
        master = args.video or (
            MASTERS / spec["masters"] / f"{spec.get('master_prefix', '')}{args.id}.mp4"
        )
        if not master.exists():
            print(f"[ERROR] no existe el master {master}", file=sys.stderr)
            return 1
        entry = process(args.command, args.id, master,
                        keyed=not getattr(args, "sin_key", False),
                        similarity=getattr(args, "similarity", KEY_SIMILARITY),
                        blend=getattr(args, "blend", KEY_BLEND))
    except (MasterError, ValueError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1
    print(f"[OK] {args.id} -> {entry['file']} ({entry['width']}x{entry['height']}, "
          f"{entry['frames']} cuadros a {entry['fps']} fps, alfa {entry['matte']}, "
          f"key {entry['keyColor']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
