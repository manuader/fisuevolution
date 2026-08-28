"""El video del cofre (pantalla verde) -> frames del juego + el cofre estatico.

Corta `video/chest-animation.mp4` en los cuatro segmentos que reproducen los
latidos de `ChestOpeningView` (idle, dos sacudidas y el estallido), le saca el
croma, cuantiza cada frame y escribe `Resources/ChestAnim/` con su manifest
`chest_anim.json` — que es EL contrato con el runtime: `ChestAnimation.swift`
lo parsea y `ChestAnimationTests` + `test_chest_video_frames` lo pinean de los
dos lados. Ademas regenera `ui_chest_closed` (@2x/@3x) desde el primer frame,
calzado a la ocupacion del PNG viejo para que Regalos y el premio diario no
cambien de tamano percibido.

Necesita `ffmpeg` en el PATH (herramienta local, no viaja al repo). Es
re-ejecutable: pisa lo generado y el resultado es identico para el mismo video.

⚠️ El color del key esta medido EN EL STREAM con la matriz limited-range
(0x0BB427). El hex calculado con la matriz full-range (0x189D30) parece el
mismo verde y NO lo es: con el `chromakey` de ffmpeg se come el cofre entero.
La banda util de `similarity` quedo en 0,08-0,14 — mucho mas angosta de lo que
la doc sugiere.
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

from _common import write_json

PIPELINE = Path(__file__).resolve().parent.parent
RESOURCES = PIPELINE.parent.parent / "FisuEvolution" / "Resources"
VIDEO = PIPELINE / "video" / "chest-animation.mp4"
CHEST_ANIM = RESOURCES / "ChestAnim"
UI_ATLAS = RESOURCES / "ui.atlas"

# El keying calibrado (ver docstring) y la geometria medida del video.
KEY_COLOR = "0x0BB427"
KEY_SIMILARITY = 0.11
KEY_BLEND = 0.04
FPS = 24
CANVAS = (1280, 720)
# Donde vive el cofre en reposo dentro del lienzo: no se mueve del piso en
# todo el video, asi que TODOS los segmentos comparten esta ancla.
CHEST_RECT = {"x": 431, "y": 257, "w": 407, "h": 363}

# El ultimo frame que se extrae: en f83 la carta generica del video empieza a
# asomar del cofre, y esa carta no se usa (la del premio es la PanelCard de la
# casa). Todo lo que el juego necesita vive antes.
LAST_FRAME = 82

# (x, y, w, h) en coordenadas del lienzo + escala de entrega. El escenario de
# las sacudidas va a escala nativa (el cofre queda a ~407 px para 210 pt de
# dibujo); el estallido entrega a 0,8: durante la explosion el ojo esta en el
# caos y el frame final congelado se achica enseguida, y el peso baja ~1,5 MB.
# La sacudida B tira los chorros de polvo mas lejos que la A (medido: con el
# crop del stage cortaba 1,37 % de su masa de alfa) y por eso lleva crop propio.
STAGE_CROP = (200, 100, 860, 560)
SHAKE_B_CROP = (60, 40, 1160, 620)
BURST_CROP = (0, 0, 1280, 656)
SEGMENTS = {
    "idle": {"first": 0, "last": 0, "crop": STAGE_CROP, "scale": 1.0},
    "shakeA": {"first": 7, "last": 26, "crop": STAGE_CROP, "scale": 1.0},
    "shakeB": {"first": 33, "last": 47, "crop": SHAKE_B_CROP, "scale": 1.0},
    "burst": {"first": 49, "last": 82, "crop": BURST_CROP, "scale": 0.8},
}

# Si un crop deja afuera mas que esto de la masa de alfa de su segmento, el
# recorte esta cortando algo que se ve (el umbral cubre las puntas de los
# rosarios de gotitas de polvo, que son pixeles sueltos).
MAX_CUT_MASS = 0.007

QUANT_COLORS = 256

# El cofre del PNG viejo ocupaba el 84,4 % del ancho de su lienzo (medido en
# `ui_chest_closed@3x` antes de reemplazarlo). El nuevo se calza a esa
# ocupacion para que los dos call sites estaticos no cambien de tamano.
STATIC_OCCUPANCY = 0.844
STATIC_SIDES = {"@3x": 384, "@2x": 256}
ALPHA_THRESHOLD = 24


def extract_keyed_frames(video: Path, out_dir: Path) -> None:
    """Un solo pase de ffmpeg: key + despill, RGBA a PNG por frame."""
    vf = (
        f"select='between(n,0,{LAST_FRAME})',"
        f"chromakey={KEY_COLOR}:{KEY_SIMILARITY}:{KEY_BLEND},"
        "despill=type=green"
    )
    subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(video),
            "-vf", vf, "-vsync", "0", "-start_number", "0",
            str(out_dir / "f%03d.png"),
        ],
        check=True,
    )


def clean_transparent_rgb(rgba: np.ndarray) -> np.ndarray:
    """RGB = 0 donde alfa = 0: libera paleta y no sangra verde al filtrar."""
    out = rgba.copy()
    out[out[..., 3] == 0, :3] = 0
    return out


def cut_mass_fraction(alpha: np.ndarray, crop: tuple[int, int, int, int]) -> float:
    """Fraccion de la masa de alfa que queda FUERA del crop."""
    total = float(alpha.sum())
    if total == 0:
        return 0.0
    x, y, w, h = crop
    inside = float(alpha[y : y + h, x : x + w].sum())
    return (total - inside) / total


def quantized(img: Image.Image) -> Image.Image:
    return img.quantize(colors=QUANT_COLORS, method=Image.Quantize.FASTOCTREE)


def emit_segment_frames(keyed_dir: Path) -> list[str]:
    """Corta, escala y cuantiza cada frame de cada segmento. Devuelve avisos."""
    warnings: list[str] = []
    for name, seg in SEGMENTS.items():
        x, y, w, h = seg["crop"]
        scale = seg["scale"]
        out_size = (round(w * scale), round(h * scale))
        mass_out = 0.0
        mass_total = 0.0
        for n in range(seg["first"], seg["last"] + 1):
            rgba = np.asarray(
                Image.open(keyed_dir / f"f{n:03d}.png").convert("RGBA"),
                dtype=np.uint8,
            )
            alpha = rgba[..., 3].astype(np.float64)
            mass_total += float(alpha.sum())
            mass_out += float(alpha.sum()) * cut_mass_fraction(alpha, seg["crop"])
            img = Image.fromarray(clean_transparent_rgb(rgba)).crop(
                (x, y, x + w, y + h)
            )
            if scale != 1.0:
                img = img.resize(out_size, Image.LANCZOS)
            quantized(img).save(
                CHEST_ANIM / f"chest_f{n:03d}.png", optimize=True
            )
        fraction = mass_out / mass_total if mass_total else 0.0
        if fraction > MAX_CUT_MASS:
            warnings.append(
                f"[AVISO] el crop de '{name}' corta {fraction:.2%} de la masa "
                f"de alfa (umbral {MAX_CUT_MASS:.2%}): revisar el encuadre"
            )
    return warnings


def build_manifest() -> dict:
    return {
        "schemaVersion": 1,
        "fps": FPS,
        "canvas": {"w": CANVAS[0], "h": CANVAS[1]},
        "chestRect": CHEST_RECT,
        "segments": {
            name: {
                "first": seg["first"],
                "last": seg["last"],
                "crop": {
                    "x": seg["crop"][0],
                    "y": seg["crop"][1],
                    "w": seg["crop"][2],
                    "h": seg["crop"][3],
                },
                "scale": seg["scale"],
            }
            for name, seg in SEGMENTS.items()
        },
    }


def static_canvas_side(bbox_w: int, occupancy: float = STATIC_OCCUPANCY) -> int:
    """Lado del lienzo cuadrado para que el cofre ocupe `occupancy` del ancho."""
    return int(round(bbox_w / occupancy))


def emit_static_chest(keyed_dir: Path) -> None:
    """`ui_chest_closed` nuevo desde el primer frame, a la ocupacion del viejo."""
    rgba = np.asarray(
        Image.open(keyed_dir / "f000.png").convert("RGBA"), dtype=np.uint8
    )
    alpha = rgba[..., 3]
    ys, xs = np.where(alpha >= ALPHA_THRESHOLD)
    x1, x2 = int(xs.min()), int(xs.max())
    y1, y2 = int(ys.min()), int(ys.max())
    chest = Image.fromarray(clean_transparent_rgb(rgba)).crop(
        (x1, y1, x2 + 1, y2 + 1)
    )
    side = static_canvas_side(chest.width)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(chest, ((side - chest.width) // 2, (side - chest.height) // 2))
    for suffix, out_side in STATIC_SIDES.items():
        canvas.resize((out_side, out_side), Image.LANCZOS).save(
            UI_ATLAS / f"ui_chest_closed{suffix}.png", optimize=True
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--video", type=Path, default=VIDEO)
    args = parser.parse_args()

    if shutil.which("ffmpeg") is None:
        print("[ERROR] ffmpeg no esta en el PATH", file=sys.stderr)
        return 1
    if not args.video.exists():
        print(f"[ERROR] no existe {args.video}", file=sys.stderr)
        return 1

    CHEST_ANIM.mkdir(parents=True, exist_ok=True)
    for stale in CHEST_ANIM.glob("chest_f*.png"):
        stale.unlink()

    with tempfile.TemporaryDirectory() as tmp:
        keyed_dir = Path(tmp)
        extract_keyed_frames(args.video, keyed_dir)
        warnings = emit_segment_frames(keyed_dir)
        emit_static_chest(keyed_dir)

    write_json(CHEST_ANIM / "chest_anim.json", build_manifest())

    frames = sorted(CHEST_ANIM.glob("chest_f*.png"))
    total_kb = sum(f.stat().st_size for f in frames) // 1024
    print(f"[OK] {len(frames)} frames en {CHEST_ANIM.relative_to(RESOURCES.parent)}"
          f" ({total_kb} KB) + chest_anim.json + ui_chest_closed @2x/@3x")
    for warning in warnings:
        print(warning)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
