#!/usr/bin/env python3
"""Los masters de Higgsfield (pantalla verde) -> los loops y las cinematicas del juego.

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
las cuatro esquinas de tres cuadros, y si las esquinas no son un verde liso el
script se niega en vez de adivinar.

    .venv/bin/python scripts/video_assets.py medir video/chest-animation.mp4
    .venv/bin/python scripts/video_assets.py retrato npc_comisario
    .venv/bin/python scripts/video_assets.py cinematica arresto [--sin-key]

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
MIN_GREEN_LEAD = 40


class MasterError(ValueError):
    """El master no sirve tal como vino: se avisa en vez de adivinar."""


def validate_id(kind: str, piece_id: str) -> None:
    if kind == "cinematica":
        if piece_id not in CINEMATIC_IDS:
            raise ValueError(f"cinematica desconocida {piece_id!r}: las del plan son {CINEMATIC_IDS}")
        return
    if not PORTRAIT_ID.fullmatch(piece_id) or piece_id.endswith(POSE_SUFFIXES):
        raise ValueError(
            f"retrato invalido {piece_id!r}: es la canonica de un visitante, "
            "`npc_<nombre>` o `sp_<id>`, sin sufijo de pose"
        )


def key_color_from_patches(patches: list[np.ndarray]) -> str:
    """El verde de fondo como `0xRRGGBB`, o MasterError si no es un verde liso.

    Cada parche es un array (h, w, 3) de una esquina. La mediana del conjunto es
    el verde; si una esquina se aparta, hay algo encima del fondo (el personaje,
    un logo, un degrade) y el key saldria mal en todo el video."""
    medians = np.array([np.median(p.reshape(-1, 3), axis=0) for p in patches])
    color = np.median(medians, axis=0)
    spread = float(np.abs(medians - color).max())
    if spread > MAX_CORNER_SPREAD:
        raise MasterError(
            f"las esquinas no son un fondo liso (se apartan {spread:.0f} del verde): "
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


def measure_key_color(video: Path) -> str:
    """Mide el verde del master en el stream, como lo ve `chromakey`.

    La conversion a rgb24 la hace ffmpeg con su matriz por defecto
    (limited-range), que es la que hace falta: el hex sacado con la matriz
    full-range parece el mismo verde y no lo es (trampa del cofre)."""
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
        video_filter = (
            f"{key_filter(key_color, similarity, blend)},"
            f"format=gbrap,premultiply=inplace=1,{framing},format=bgra"
        )
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
    return {"schemaVersion": SCHEMA_VERSION, "portraits": {}, "cinematics": {}}


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
    key_color = measure_key_color(master) if keyed else None
    spec = KINDS[kind]
    output = RESOURCES / spec["dir"] / f"{spec['prefix']}{piece_id}.mov"
    encode(kind, master, output, key_color, similarity, blend)
    entry = manifest_entry(output, key_color)
    register(kind, piece_id, entry)
    return entry


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    medir = sub.add_parser("medir", help="imprime el verde de fondo de un master")
    medir.add_argument("video", type=Path)
    for kind in KINDS:
        piece = sub.add_parser(kind)
        piece.add_argument("id")
        piece.add_argument("--video", type=Path, help="el master, si no esta en video/")
        piece.add_argument("--similarity", type=float, default=KEY_SIMILARITY)
        piece.add_argument("--blend", type=float, default=KEY_BLEND)
        if kind == "cinematica":
            piece.add_argument("--sin-key", action="store_true",
                               help="la escena trae su propio fondo: opaca, sin alfa")
    args = parser.parse_args()

    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        print("[ERROR] ffmpeg/ffprobe no estan en el PATH", file=sys.stderr)
        return 1

    try:
        if args.command == "medir":
            print(measure_key_color(args.video))
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
