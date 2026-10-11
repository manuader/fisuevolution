"""Spike E8e T10a: hojas de cuadros del idle del tablero sacadas de los clips base.

Prototipo desechable (lo reescribe `idle_frames.py` con tests en T10b). Por cada
tipo de puesto (`characters` del manifest sin `sp_*`) decodifica `char_<tipo>.mov`
con su alfa, muestrea N cuadros uniformes sobre el loop sin el ultimo (~ el
primero) y arma una hoja PNG8 en grilla. Mide peso, cierre del loop y cuanto se
mueve cada tipo; opcionalmente arma GIFs de ritmo y el catalogo ASTC (variante C).

    python idle_frames_spike.py --out <dir>             # variantes A + metricas
    python idle_frames_spike.py --out <dir> --install    # ademas copia a AnimPacks
    python idle_frames_spike.py --out <dir> --gifs homeless administrativo god
    python idle_frames_spike.py --out <dir> --astc       # xcassets de la variante C
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from video_assets import RESOURCES, load_manifest  # noqa: E402

ANIM_PACKS = RESOURCES / "AnimPacks"
SOURCE_SIDE = 512
LOOP_LAST = 120
CLIP_SECONDS = 121 / 24
VARIANTS = [(16, 256), (12, 256), (16, 192), (12, 192)]
DEFAULT = (16, 256)
BENCH_FLOORS = {"anim-piso-2", "anim-piso-3"}


def sample_indices(n: int) -> list[int]:
    return [int(i * LOOP_LAST / n + 0.5) for i in range(n)]


def decode(mov: Path, side: int) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(mov), "-vf", f"scale={side}:{side}:flags=lanczos",
         "-pix_fmt", "rgba", "-f", "rawvideo", "-"],
        check=True, capture_output=True,
    ).stdout
    frames = np.frombuffer(raw, dtype=np.uint8).reshape(-1, side, side, 4).copy()
    frames[frames[..., 3] == 0, :3] = 0
    return frames


def mean_diff(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.abs(a.astype(np.int16) - b.astype(np.int16)).mean())


def sheet(frames: np.ndarray, indices: list[int]) -> Image.Image:
    side = frames.shape[1]
    cols = math.ceil(math.sqrt(len(indices)))
    rows = math.ceil(len(indices) / cols)
    out = Image.new("RGBA", (cols * side, rows * side), (0, 0, 0, 0))
    for k, idx in enumerate(indices):
        out.paste(Image.fromarray(frames[idx], "RGBA"), ((k % cols) * side, (k // cols) * side))
    return out.quantize(colors=256, method=Image.Quantize.FASTOCTREE)


def variant_name(n: int, side: int) -> str:
    return f"A{n}x{side}"


def bench_file(type_id: str, n: int, side: int) -> str:
    return f"idle_{type_id}.png" if (n, side) == DEFAULT else f"idle_{type_id}_n{n}_l{side}.png"


def gif(frames: np.ndarray, indices: list[int], fps: float, path: Path) -> None:
    board = (196, 170, 120, 255)
    images = []
    for idx in indices:
        bg = Image.new("RGBA", frames.shape[1:3][::-1], board)
        bg.alpha_composite(Image.fromarray(frames[idx], "RGBA"))
        images.append(bg.convert("RGB"))
    duration = int(round(1000 / fps))
    images[0].save(path, save_all=True, append_images=images[1:], duration=duration, loop=0)


def astc_catalog(type_id: str, tag: str, frames: np.ndarray, indices: list[int], root: Path) -> None:
    atlas = root / f"idle_{type_id}.spriteatlas"
    atlas.mkdir(parents=True, exist_ok=True)
    (atlas / "Contents.json").write_text(json.dumps({
        "info": {"author": "xcode", "version": 1},
        "properties": {"on-demand-resource-tags": [tag]},
    }, indent=2))
    for k, idx in enumerate(indices):
        name = f"idle_{type_id}_{k:02d}"
        imageset = atlas / f"{name}.imageset"
        imageset.mkdir(exist_ok=True)
        Image.fromarray(frames[idx], "RGBA").save(imageset / f"{name}.png")
        (imageset / "Contents.json").write_text(json.dumps({
            "images": [{"filename": f"{name}.png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"compression-type": "gpu-optimized-best", "on-demand-resource-tags": [tag]},
        }, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--gifs", nargs="*", default=[])
    parser.add_argument("--astc", action="store_true")
    parser.add_argument("--only", nargs="*", default=None)
    args = parser.parse_args()

    characters = {k: v for k, v in load_manifest()["characters"].items() if not k.startswith("sp_")}
    if args.only:
        characters = {k: v for k, v in characters.items() if k in args.only}
    args.out.mkdir(parents=True, exist_ok=True)
    metrics: dict[str, dict] = {}

    for type_id, entry in sorted(characters.items()):
        tag = entry["odrTag"]
        mov = ANIM_PACKS / tag / entry["file"]
        by_side = {side: decode(mov, side) for side in sorted({s for _, s in VARIANTS})}
        f256 = by_side[256]
        consecutive = [mean_diff(f256[i], f256[i + 1]) for i in range(LOOP_LAST)]
        info = {
            "tag": tag,
            "motionPerFrame": float(np.mean(consecutive)),
            "clipLastToFirst": mean_diff(f256[LOOP_LAST], f256[0]),
            "variants": {},
        }
        for n, side in VARIANTS:
            idx = sample_indices(n)
            png = sheet(by_side[side], idx)
            name = variant_name(n, side)
            path = args.out / name / tag / f"idle_{type_id}.png"
            path.parent.mkdir(parents=True, exist_ok=True)
            png.save(path, optimize=True)
            sampled = [mean_diff(by_side[side][idx[k]], by_side[side][idx[k + 1]]) for k in range(n - 1)]
            info["variants"][name] = {
                "bytes": path.stat().st_size,
                "sheet": list(png.size),
                "meanStep": float(np.mean(sampled)),
                "lastToFirst": mean_diff(by_side[side][idx[-1]], by_side[side][idx[0]]),
            }
            if args.install and (tag in BENCH_FLOORS or (n, side) == DEFAULT):
                shutil.copyfile(path, ANIM_PACKS / tag / bench_file(type_id, n, side))
        if type_id in args.gifs:
            idx = sample_indices(16)
            (args.out / "gifs").mkdir(exist_ok=True)
            for label, fps in [("a_clip", 16 / CLIP_SECONDS), ("b_6fps", 6.0), ("c_8fps", 8.0)]:
                gif(f256, idx, fps, args.out / "gifs" / f"{type_id}_{label}.gif")
        if args.astc:
            astc_catalog(type_id, tag, f256, sample_indices(16), args.out / "astc" / "Idle.xcassets")
        metrics[type_id] = info
        print(f"{type_id:28s} {tag:12s} motion {info['motionPerFrame']:.2f} "
              + " ".join(f"{k}={v['bytes'] // 1024}K" for k, v in info["variants"].items()))

    if args.astc:
        (args.out / "astc" / "Idle.xcassets" / "Contents.json").write_text(
            json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
    (args.out / "metrics.json").write_text(json.dumps(metrics, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
