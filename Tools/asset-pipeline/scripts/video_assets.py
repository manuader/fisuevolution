#!/usr/bin/env python3
"""Los masters de Higgsfield (pantalla verde o magenta) -> los loops y las cinematicas del juego.

PLAN-v2 E8, "Pipeline de video". Dos clases de pieza, con el mismo keying que
el cofre (`chest_video_frames.py`):

- **Retratos**: los 18 loops de visitante (Kling, cuadro inicial = final = la
  canonica). HEVC con alfa, 512x512, sin sonido, en `Resources/Loops/`.
- **Cinematicas**: reencarnacion, arresto y Dios (Seedance). 720x1280, en
  `Resources/Cinematics/`, con la pista de sonido del master si la trae.

`Resources/Data/loops_manifest.json` es EL contrato con el runtime: una pieza
con entrada ahi se reproduce, una sin entrada cae al arte quieto (la regla de
oro de `assets_manifest.json`). Lo pinea `test_video_assets` y, del lado del
juego, un test en Swift.

**El verde del key se mide en cada master, no se fija a mano.** El del cofre se
calibro a ojo y dos masters dieron dos verdes distintos (ver el docstring de
`chest_video_frames.py`): un master nuevo con el verde del anterior se come al
personaje. Se mide como alla, en el stream con la matriz limited-range, pero en
las esquinas de tres cuadros (las de arriba si es un retrato: los hombros tocan
las de abajo), y si no son un fondo liso, verde o magenta, el script se niega
en vez de adivinar. El magenta es para los personajes de piel verde.

    .venv/bin/python scripts/video_assets.py medir video/chest-animation.mp4 [--clase retrato]
    .venv/bin/python scripts/video_assets.py retrato npc_comisario
    .venv/bin/python scripts/video_assets.py cinematica arresto [--sin-key]
    .venv/bin/python scripts/video_assets.py ascensor cierra --video <master>
    .venv/bin/python scripts/video_assets.py ascensor-cuadros --dir <carpeta>

Los masters van en `video/loops/<id>.mp4` y `video/cinematicas/<id>.mp4`
(`--video` para otro). Necesita `ffmpeg` con `hevc_videotoolbox` en el PATH.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from fractions import Fraction
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import write_json  # noqa: E402
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

# Cada clase de pieza: carpeta en Resources, seccion del manifest, prefijo del
# archivo, tamano de salida y carpeta de sus masters. El prefijo no es adorno:
# Xcode aplana los recursos en la raiz del bundle, asi que dos `.mov` con el
# mismo nombre en carpetas distintas se pisan al copiarse.
KINDS = {
    "retrato": {
        "dir": "Loops", "section": "portraits", "prefix": "loop_",
        "size": (512, 512), "masters": "loops",
    },
    "cinematica": {
        "dir": "Cinematics", "section": "cinematics", "prefix": "cine_",
        "size": (720, 1280), "masters": "cinematicas",
    },
}

# Las tres cinematicas del plan (E8, "Cuando se reproducen"); el juego las pide
# por este id.
CINEMATIC_IDS = ("reencarnacion", "arresto", "dios")

# Un retrato es el loop de la canonica de un visitante: `npc_<nombre>` o
# `sp_<id>`. Las poses (`_talk`, `_action`, `_face`) no tienen loop propio.
PORTRAIT_ID = re.compile(r"(npc|sp)_[a-z0-9]+(_[a-z0-9]+)*")
POSE_SUFFIXES = ("_talk", "_action", "_face")

# La medicion del verde: un parche por esquina en el primer cuadro, el del medio
# y el ultimo. En el master del cofre las esquinas se mueven de a 1-3 por canal
# (R 31-34, G 146-148, B 73-76) y la mediana da 0x22934C, a 2 del verde que se
# calibro a mano: 12 de tolerancia deja pasar la compresion y no un objeto.
CORNER_PATCH = 8
MAX_CORNER_SPREAD = 12
# Cuanto le gana el canal del key a los otros dos: verde (G sobre R y B) o
# magenta (R y B sobre G), para los personajes de piel verde.
MIN_KEY_LEAD = 40
# Las esquinas que se miden por clase. Un retrato es un busto: los hombros tocan
# las dos de abajo (10 de los 18 masters de croma), asi que se miden las de
# arriba; en la cinematica las cuatro son fondo.
CORNER_ROWS = {"retrato": ("top",), "cinematica": ("top", "bottom")}

# El ascensor (PLAN-v2 E13 item 13): una sola cabina para todos los viajes. Las
# esquinas del master son la cabina, asi que el verde se mide en el hueco de las
# puertas (cuadro con las puertas abiertas) y en las ventanas (cuadro cerradas).
ELEVATOR_CLIPS = {
    # id: (cuadro de puertas abiertas, recorte en cuadros del master, duracion final)
    "ascensor_cierra": ("first", (6, 62), 0.75),
    "ascensor_abre": ("last", (9, 73), 0.65),
}
ELEVATOR_ARGS = {"cierra": "ascensor_cierra", "abre": "ascensor_abre"}
ELEVATOR_STILLS = {
    # id: (archivo del master, el cuadro tiene las puertas abiertas)
    "ascensor_cerrada": ("cabina_cerrada.png", False),
    "ascensor_abierta": ("cabina_abierta.png", True),
}
ELEVATOR_MASTER_FPS = 24
ELEVATOR_FPS = 30
# Fracciones del cuadro: el hueco abierto y las dos ventanas de las puertas
# cerradas (medidas en los masters del 2026-10-08).
HOLE_POINTS = [(fx, fy) for fy in (0.35, 0.5, 0.65) for fx in (0.4, 0.5, 0.6)]
WINDOW_POINTS = [(fx, 0.45) for fx in (0.33, 0.36, 0.64, 0.67)]
# Hueco y ventanas son dos verdes (B 35 vs 14): se aceptan juntos si cada uno es
# un verde liso y entre ellos no se apartan mas que esto.
ELEVATOR_MAX_SPREAD = 28


class MasterError(ValueError):
    """El master no sirve tal como vino: se avisa en vez de adivinar."""


def validate_id(kind: str, piece_id: str) -> None:
    if kind == "cinematica":
        if piece_id not in CINEMATIC_IDS and piece_id not in ELEVATOR_CLIPS:
            raise ValueError(
                f"cinematica desconocida {piece_id!r}: las del plan son "
                f"{CINEMATIC_IDS + tuple(ELEVATOR_CLIPS)}"
            )
        return
    if not PORTRAIT_ID.fullmatch(piece_id) or piece_id.endswith(POSE_SUFFIXES):
        raise ValueError(
            f"retrato invalido {piece_id!r}: es la canonica de un visitante, "
            "`npc_<nombre>` o `sp_<id>`, sin sufijo de pose"
        )


def key_family(color: str) -> str | None:
    """`green` o `magenta` segun el canal que domina el key, None si ninguno."""
    r, g, b = (int(color[i:i + 2], 16) for i in (2, 4, 6))
    if g - max(r, b) >= MIN_KEY_LEAD:
        return "green"
    if min(r, b) - g >= MIN_KEY_LEAD:
        return "magenta"
    return None


def keying(color: str, similarity: float, blend: float) -> str:
    """El filtro del key. El magenta va sin `despill`: ffmpeg sólo lo conoce para
    verde y azul, y uno verde se comeria a quien esta sobre magenta por ser verde."""
    if key_family(color) == "green":
        return key_filter(color, similarity, blend)
    return f"chromakey={color}:{similarity}:{blend}"


def key_color_from_patches(patches: list[np.ndarray],
                           max_spread: int = MAX_CORNER_SPREAD) -> str:
    """El verde (o magenta) de fondo como `0xRRGGBB`, o MasterError si no es un fondo liso.

    Cada parche es un array (h, w, 3) de una zona de fondo (las esquinas). La
    mediana del conjunto es el verde; si una zona se aparta, hay algo encima del
    fondo (el personaje, un logo, un degrade) y el key saldria mal en todo el video."""
    medians = np.array([np.median(p.reshape(-1, 3), axis=0) for p in patches])
    color = np.median(medians, axis=0)
    spread = float(np.abs(medians - color).max())
    if spread > max_spread:
        raise MasterError(
            f"las zonas medidas no son un fondo liso (se apartan {spread:.0f} del color): "
            "algo tapa una zona o el fondo tiene degrade"
        )
    hex_color = "0x{:02X}{:02X}{:02X}".format(*(int(round(c)) for c in color))
    if key_family(hex_color) is None:
        raise MasterError(
            f"el fondo no es verde ni magenta: mide {tuple(int(c) for c in color)}"
        )
    return hex_color


def probe(video: Path) -> dict:
    return json.loads(subprocess.run(
        ["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(video)],
        capture_output=True, text=True, check=True,
    ).stdout)


def video_stream(info: dict) -> dict:
    return next(s for s in info["streams"] if s["codec_type"] == "video")


def has_audio(info: dict) -> bool:
    return any(s["codec_type"] == "audio" for s in info["streams"])


def decode_frames(video: Path, picks: list[int]) -> np.ndarray:
    """Los cuadros `picks` del video como rgb24 (n, h, w, 3), con la matriz por
    defecto de ffmpeg (limited-range): la que hace falta para medir el verde, el
    hex sacado con la matriz full-range parece el mismo verde y no lo es (trampa
    del cofre)."""
    stream = video_stream(probe(video))
    width, height = int(stream["width"]), int(stream["height"])
    select = "+".join(f"eq(n\\,{n})" for n in picks)
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(video), "-vf", f"select={select}",
         "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, height, width, 3)


def frame_count(video: Path) -> int:
    return int(video_stream(probe(video)).get("nb_frames") or 1)


def measure_key_color(video: Path, rows: tuple[str, ...] = ("top", "bottom")) -> str:
    """Mide el fondo del master en el stream, como lo ve `chromakey`. `rows` dice
    cuales esquinas son fondo: `top`, `bottom` o las dos."""
    frames = frame_count(video)
    decoded = decode_frames(video, sorted({0, frames // 2, frames - 1}))
    height, width = decoded.shape[1:3]
    p = CORNER_PATCH
    patches = [
        frame[y:y + p, x:x + p]
        for frame in decoded
        for y in [{"top": 0, "bottom": height - p}[row] for row in rows]
        for x in (0, width - p)
    ]
    return key_color_from_patches(patches)


def region_patches(frame: np.ndarray, points: list[tuple[float, float]]) -> list[np.ndarray]:
    height, width = frame.shape[:2]
    half = CORNER_PATCH // 2
    return [
        frame[y - half:y + half, x - half:x + half]
        for x, y in ((int(fx * width), int(fy * height)) for fx, fy in points)
    ]


def measure_key_in_regions(video: Path, open_frame: str,
                           points_open: list[tuple[float, float]],
                           points_closed: list[tuple[float, float]]) -> str:
    """El verde de un master cuyas esquinas no son verdes: se mide en el hueco
    de las puertas (cuadro abierto) y en sus ventanas (cuadro cerrado).

    `open_frame` dice si el cuadro con las puertas abiertas es el `first` o el
    `last`; el otro es el cerrado. Un cuadro fijo (un solo cuadro) sirve para
    cualquiera de los dos: se pasa la lista que no le toca vacia."""
    first, last = decode_frames(video, sorted({0, frame_count(video) - 1}))[[0, -1]]
    opened, closed = (first, last) if open_frame == "first" else (last, first)
    patches = region_patches(opened, points_open) + region_patches(closed, points_closed)
    return key_color_from_patches(patches, max_spread=ELEVATOR_MAX_SPREAD)


def framing_filter(kind: str, width: int, height: int) -> str:
    """Del cuadro del master al de la pieza.

    El retrato se recorta al cuadrado del centro (la canonica es cuadrada y
    Kling la respeta); la cinematica cubre 720x1280 y recorta lo que sobra."""
    out_w, out_h = KINDS[kind]["size"]
    if kind == "retrato":
        side = min(width, height)
        return f"crop={side}:{side},scale={out_w}:{out_h}:flags=lanczos"
    return (
        f"scale={out_w}:{out_h}:force_original_aspect_ratio=increase:flags=lanczos,"
        f"crop={out_w}:{out_h}"
    )


def keyed_filter(key_color: str, similarity: float, blend: float, framing: str,
                 despill: bool = True) -> str:
    """Key + premultiplicado + encuadre, en ese orden (ver `encode`).

    `despill` quita el verde que el key deja en los bordes del personaje; en una
    escena con amarillos (la cabina) tambien los vuelve naranja."""
    key = keying(key_color, similarity, blend) if despill \
        else f"chromakey={key_color}:{similarity}:{blend}"
    return (
        f"{key},"
        f"format=gbrap,premultiply=inplace=1,{framing},format=bgra"
    )


def encode(kind: str, master: Path, output: Path, key_color: str | None,
           similarity: float, blend: float) -> None:
    info = probe(master)
    stream = video_stream(info)
    framing = framing_filter(kind, int(stream["width"]), int(stream["height"]))
    if key_color is None:
        video_filter = f"{framing},format=yuv420p"
        video_args = ["-c:v", "hevc_videotoolbox", "-q:v", HEVC_QUALITY]
    else:
        # Premultiplicado ANTES de escalar: el filtro de escala promedia vecinos,
        # y con el alfa recto el RGB de lo transparente (verde despillado) se
        # colaria en el borde. Y premultiplicado porque `AVPlayerLayer` composita
        # el HEVC-alfa asi (ver `encode_cinematic` del cofre: sin esto el fondo
        # keyeado se suma al juego como un velo).
        video_filter = keyed_filter(key_color, similarity, blend, framing)
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


def manifest_entry(output: Path, key_color: str | None) -> dict:
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
        "alpha": key_color is not None,
        "audio": has_audio(info),
        # De donde salio el key: si un loop se ve comido, es lo primero que se mira.
        "keyColor": key_color,
    }


def load_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {"schemaVersion": SCHEMA_VERSION, "portraits": {}, "cinematics": {}, "stills": {}}


def register(kind: str, piece_id: str, entry: dict) -> None:
    manifest = load_manifest()
    section = manifest.setdefault(KINDS[kind]["section"], {})
    section[piece_id] = entry
    manifest[KINDS[kind]["section"]] = dict(sorted(section.items()))
    write_json(MANIFEST, manifest)


def process(kind: str, piece_id: str, master: Path, keyed: bool = True,
            similarity: float = KEY_SIMILARITY, blend: float = KEY_BLEND) -> dict:
    """Master -> pieza en Resources + su entrada en el manifest. Devuelve la entrada."""
    validate_id(kind, piece_id)
    if kind == "retrato" and not keyed:
        raise ValueError("un retrato va siempre con alfa (PLAN-v2 E8)")
    key_color = measure_key_color(master, rows=CORNER_ROWS[kind]) if keyed else None
    spec = KINDS[kind]
    output = RESOURCES / spec["dir"] / f"{spec['prefix']}{piece_id}.mov"
    encode(kind, master, output, key_color, similarity, blend)
    entry = manifest_entry(output, key_color)
    register(kind, piece_id, entry)
    return entry


def process_ascensor(clip_id: str, master: Path, similarity: float = KEY_SIMILARITY,
                     blend: float = KEY_BLEND) -> dict:
    """Master de puertas -> clip HEVC con alfa, recortado al movimiento de las
    puertas y acelerado a la duracion del viaje (los masters tardan ~2,1-2,5 s).
    Sin despill: la cabina es amarilla y plateada, y el hueco ya esta bordeado
    por el contorno negro, asi que no hay verde que limpiar."""
    validate_id("cinematica", clip_id)
    open_frame, (start, end), seconds = ELEVATOR_CLIPS[clip_id]
    key_color = measure_key_in_regions(master, open_frame, HOLE_POINTS, WINDOW_POINTS)
    stream = video_stream(probe(master))
    framing = framing_filter("cinematica", int(stream["width"]), int(stream["height"]))
    original = (end - start) / ELEVATOR_MASTER_FPS
    video_filter = (
        f"trim=start_frame={start}:end_frame={end},"
        f"setpts=(PTS-STARTPTS)*{seconds}/{original},fps={ELEVATOR_FPS},"
        f"{keyed_filter(key_color, similarity, blend, framing, despill=False)}"
    )
    output = RESOURCES / KINDS["cinematica"]["dir"] / f"cine_{clip_id}.mov"
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(master), "-vf", video_filter,
         "-c:v", "hevc_videotoolbox", "-alpha_quality", HEVC_ALPHA_QUALITY,
         "-q:v", HEVC_QUALITY, "-tag:v", "hvc1", "-an",
         "-fps_mode", "passthrough", "-y", str(output)],
        check=True,
    )
    entry = manifest_entry(output, key_color)
    register("cinematica", clip_id, entry)
    return entry


def process_ascensor_stills(source_dir: Path, similarity: float = KEY_SIMILARITY,
                            blend: float = KEY_BLEND) -> dict:
    """Los dos cuadros fijos de la cabina -> PNG con alfa premultiplicado de
    720x1280, para cuando no hay clip. Devuelve las entradas del manifest."""
    entries = {}
    for still_id, (filename, is_open) in ELEVATOR_STILLS.items():
        source = source_dir / filename
        if not source.exists():
            raise MasterError(f"no existe el cuadro {source}")
        key_color = measure_key_in_regions(
            source, "first", HOLE_POINTS if is_open else [], [] if is_open else WINDOW_POINTS
        )
        stream = video_stream(probe(source))
        framing = framing_filter("cinematica", int(stream["width"]), int(stream["height"]))
        output = RESOURCES / KINDS["cinematica"]["dir"] / f"cine_{still_id}.png"
        output.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["ffmpeg", "-v", "error", "-i", str(source),
             "-vf", keyed_filter(key_color, similarity, blend, framing, despill=False),
             "-frames:v", "1", "-update", "1", "-y", str(output)],
            check=True,
        )
        out = video_stream(probe(output))
        entries[still_id] = {
            "file": output.name, "width": int(out["width"]),
            "height": int(out["height"]), "keyColor": key_color,
        }
    manifest = load_manifest()
    manifest.setdefault("stills", {}).update(entries)
    manifest["stills"] = dict(sorted(manifest["stills"].items()))
    write_json(MANIFEST, manifest)
    return entries


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    medir = sub.add_parser("medir", help="imprime el color de fondo de un master")
    medir.add_argument("video", type=Path)
    medir.add_argument("--clase", choices=sorted(CORNER_ROWS),
                       help="mide las esquinas de esa clase (por defecto, las cuatro)")
    for kind in KINDS:
        piece = sub.add_parser(kind)
        piece.add_argument("id")
        piece.add_argument("--video", type=Path, help="el master, si no esta en video/")
        piece.add_argument("--similarity", type=float, default=KEY_SIMILARITY)
        piece.add_argument("--blend", type=float, default=KEY_BLEND)
        if kind == "cinematica":
            piece.add_argument("--sin-key", action="store_true",
                               help="la escena trae su propio fondo: opaca, sin alfa")
    ascensor = sub.add_parser("ascensor", help="un clip de las puertas del ascensor")
    ascensor.add_argument("clip", choices=sorted(ELEVATOR_ARGS))
    ascensor.add_argument("--video", type=Path, help="el master de las puertas")
    cuadros = sub.add_parser("ascensor-cuadros", help="los dos cuadros fijos de la cabina")
    cuadros.add_argument("--dir", type=Path, required=True)
    for keyed in (ascensor, cuadros):
        keyed.add_argument("--similarity", type=float, default=KEY_SIMILARITY)
        keyed.add_argument("--blend", type=float, default=KEY_BLEND)
    args = parser.parse_args()

    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        print("[ERROR] ffmpeg/ffprobe no estan en el PATH", file=sys.stderr)
        return 1

    try:
        if args.command == "medir":
            rows = CORNER_ROWS[args.clase] if args.clase else ("top", "bottom")
            print(measure_key_color(args.video, rows))
            return 0
        if args.command == "ascensor-cuadros":
            for still_id, entry in process_ascensor_stills(
                    args.dir, args.similarity, args.blend).items():
                print(f"[OK] {still_id} -> {entry['file']} "
                      f"({entry['width']}x{entry['height']}, key {entry['keyColor']})")
            return 0
        if args.command == "ascensor":
            if args.video is None or not args.video.exists():
                print(f"[ERROR] no existe el master {args.video}", file=sys.stderr)
                return 1
            args.id = ELEVATOR_ARGS[args.clip]
            entry = process_ascensor(args.id, args.video, args.similarity, args.blend)
            print(f"[OK] {args.id} -> {entry['file']} ({entry['width']}x{entry['height']}, "
                  f"{entry['frames']} cuadros a {entry['fps']} fps, key {entry['keyColor']})")
            return 0
        master = args.video or MASTERS / KINDS[args.command]["masters"] / f"{args.id}.mp4"
        if not master.exists():
            print(f"[ERROR] no existe el master {master}", file=sys.stderr)
            return 1
        entry = process(args.command, args.id, master,
                        keyed=not getattr(args, "sin_key", False),
                        similarity=args.similarity, blend=args.blend)
    except (MasterError, ValueError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1
    print(f"[OK] {args.id} -> {entry['file']} ({entry['width']}x{entry['height']}, "
          f"{entry['frames']} cuadros a {entry['fps']} fps, key {entry['keyColor']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
