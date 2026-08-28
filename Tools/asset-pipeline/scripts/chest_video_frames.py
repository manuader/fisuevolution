"""El video del cofre (pantalla verde) -> la animacion completa del juego.

Pedido del dueno (2026-08-28, segunda ronda): la apertura es EL VIDEO ENTERO —
sin rayos, particulas ni carta de la casa — y el contenido del premio se
renderiza al final dentro del marco vacio de la carta del video.

Produce tres familias de assets en `Resources/ChestAnim/`:

1. **Frames PNG interactivos** (idle + dos sacudidas, f0-f47): los latidos que
   responden al dedo piden swap de frame INMEDIATO, sin preroll — van como
   secuencia cuantizada que `ChestAnimationFeed` reproduce frame-perfect.
2. **`chest_open.mov`** (f48-f239, HEVC con canal alfa por VideoToolbox): el
   tramo del estallido a la carta es LINEAL — 8 s de corrido — y en video por
   hardware pesa 3 MB contra ~12 MB en PNGs, a 24 fps garantizados. q:v 50 es
   indistinguible del original en A/B (verificado sobre el frame de espirales).
3. **`chest_card_still.png`** (f239): el estado final — la carta con el marco
   vacio — para Reduce Motion y de fallback.

`chest_anim.json` (schemaVersion 2) es EL contrato con el runtime
(`ChestAnimation.swift`); lo pinean `ChestAnimationTests` y
`test_chest_video_frames` de los dos lados. Ademas regenera `ui_chest_closed`
(@2x/@3x) desde el primer frame para la tarjeta de Regalos y el premio diario.

Necesita `ffmpeg` (con hevc_videotoolbox) en el PATH. Re-ejecutable: pisa lo
generado y el resultado es identico para el mismo video.

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
KEY_FILTER = (
    f"chromakey={KEY_COLOR}:{KEY_SIMILARITY}:{KEY_BLEND},despill=type=green"
)
FPS = 24
CANVAS = (1280, 720)
# Donde vive el cofre en reposo dentro del lienzo: no se mueve del piso en
# todo el video, asi que PNGs y video comparten esta unica ancla.
CHEST_RECT = {"x": 431, "y": 257, "w": 407, "h": 363}
# El interior pergamino de la carta en el ultimo frame (f239), medido por
# componente conexa: donde el juego renderiza el contenido del premio.
PARCHMENT_RECT = {"x": 489, "y": 143, "w": 302, "h": 424}

# (x, y, w, h) en coordenadas del lienzo + escala de entrega de los PNG.
# La sacudida B tira los chorros de polvo mas lejos que la A (medido: el
# escenario comun le cortaba 1,37 % de su masa de alfa) y lleva crop propio.
STAGE_CROP = (200, 100, 860, 560)
SHAKE_B_CROP = (60, 40, 1160, 620)
FULL_CROP = (0, 0, 1280, 720)
SEGMENTS = {
    "idle": {"first": 0, "last": 0, "crop": STAGE_CROP, "scale": 1.0},
    "shakeA": {"first": 7, "last": 26, "crop": STAGE_CROP, "scale": 1.0},
    "shakeB": {"first": 33, "last": 47, "crop": SHAKE_B_CROP, "scale": 1.0},
}

# El tramo cinematico: del candado cerrandose al marco vacio asentado.
CINEMATIC_FIRST = 48
CINEMATIC_LAST = 239
CINEMATIC_FILE = "chest_open.mov"
# VideoToolbox: q:v 50 dio 3,1 MB indistinguible del original en A/B.
HEVC_QUALITY = "50"
HEVC_ALPHA_QUALITY = "0.6"

CARD_STILL_FILE = "chest_card_still.png"
CARD_STILL_SCALE = 0.8

# Si un crop deja afuera mas que esto de la masa de alfa de su segmento, el
# recorte esta cortando algo que se ve.
MAX_CUT_MASS = 0.007

QUANT_COLORS = 256

# El cofre del PNG viejo ocupaba el 84,4 % del ancho de su lienzo (medido en
# `ui_chest_closed@3x` antes de reemplazarlo). El nuevo se calza a esa
# ocupacion para que los dos call sites estaticos no cambien de tamano.
STATIC_OCCUPANCY = 0.844
STATIC_SIDES = {"@3x": 384, "@2x": 256}
ALPHA_THRESHOLD = 24


def extract_keyed_frames(video: Path, out_dir: Path) -> None:
    """Los frames RGBA de los tramos interactivos + el ultimo (para el still)."""
    last_png = SEGMENTS["shakeB"]["last"]
    vf = (
        f"select='between(n,0,{last_png})+eq(n,{CINEMATIC_LAST})',"
        f"{KEY_FILTER}"
    )
    subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(video),
            "-vf", vf, "-vsync", "0", "-start_number", "0",
            str(out_dir / "k%03d.png"),
        ],
        check=True,
    )
    # El select entrega en orden: el ultimo archivo emitido es f239.
    emitted = sorted(out_dir.glob("k*.png"))
    emitted[-1].rename(out_dir / f"k{CINEMATIC_LAST:03d}.png")


# El glow del estallido toca los bordes del encuadre y cortado seco delataba
# el rectángulo de 1280×720 sobre el juego (visto en el smoke): el alfa se
# desvanece en los últimos px de cada borde y la costura desaparece.
EDGE_FEATHER_PX = 28


def write_feather_mask(path: Path) -> None:
    """Máscara L: blanca adentro, degradada a negro en los cuatro bordes."""
    w, h = CANVAS
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    dist = np.minimum(np.minimum(xs, w - 1 - xs), np.minimum(ys, h - 1 - ys))
    mask = np.clip(dist / EDGE_FEATHER_PX, 0.0, 1.0)
    Image.fromarray((mask * 255).astype(np.uint8), mode="L").save(path)


def encode_cinematic(video: Path, workdir: Path) -> None:
    """f48-f239 como HEVC con alfa (hvc1) y bordes emplumados, para AVPlayer."""
    mask_path = workdir / "edge_mask.png"
    write_feather_mask(mask_path)
    # ⚠️ El `shortest=1` va DENTRO del `blend` y el split de [keyed] es
    # obligatorio: la máscara en `-loop 1` es un stream INFINITO, y sin el
    # shortest del filtro, `blend` repite el último frame para siempre — el
    # `-shortest` de output no corta streams de un filter_complex (medido: un
    # encode de 192 frames llevaba 4 h y 1,25 GB cuando se lo mató).
    filter_complex = (
        f"[0:v]select='between(n,{CINEMATIC_FIRST},{CINEMATIC_LAST})',"
        f"setpts=PTS-STARTPTS,{KEY_FILTER},format=rgba,split[keyed][forAlpha];"
        "[forAlpha]alphaextract[alpha];"
        "[alpha][1:v]blend=all_mode=multiply:shortest=1[fadedalpha];"
        "[keyed][fadedalpha]alphamerge,format=bgra[out]"
    )
    subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(video),
            "-loop", "1", "-i", str(mask_path),
            "-filter_complex", filter_complex,
            "-map", "[out]",
            "-c:v", "hevc_videotoolbox",
            "-alpha_quality", HEVC_ALPHA_QUALITY,
            "-q:v", HEVC_QUALITY,
            "-tag:v", "hvc1",
            "-vsync", "0", "-an",
            "-y", str(CHEST_ANIM / CINEMATIC_FILE),
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


def render_frame(
    keyed_path: Path, crop: tuple[int, int, int, int], scale: float
) -> Image.Image:
    x, y, w, h = crop
    rgba = np.asarray(Image.open(keyed_path).convert("RGBA"), dtype=np.uint8)
    img = Image.fromarray(clean_transparent_rgb(rgba)).crop((x, y, x + w, y + h))
    if scale != 1.0:
        img = img.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
    return img


def emit_segment_frames(keyed_dir: Path) -> list[str]:
    """Corta, escala y cuantiza cada frame interactivo. Devuelve avisos."""
    warnings: list[str] = []
    for name, seg in SEGMENTS.items():
        mass_out = 0.0
        mass_total = 0.0
        for n in range(seg["first"], seg["last"] + 1):
            keyed = keyed_dir / f"k{n:03d}.png"
            alpha = np.asarray(
                Image.open(keyed).getchannel("A"), dtype=np.float64
            )
            mass_total += float(alpha.sum())
            mass_out += float(alpha.sum()) * cut_mass_fraction(alpha, seg["crop"])
            quantized(render_frame(keyed, seg["crop"], seg["scale"])).save(
                CHEST_ANIM / f"chest_f{n:03d}.png", optimize=True
            )
        fraction = mass_out / mass_total if mass_total else 0.0
        if fraction > MAX_CUT_MASS:
            warnings.append(
                f"[AVISO] el crop de '{name}' corta {fraction:.2%} de la masa "
                f"de alfa (umbral {MAX_CUT_MASS:.2%}): revisar el encuadre"
            )
    return warnings


def emit_card_still(keyed_dir: Path) -> None:
    """El último frame, con el MISMO feather de bordes que el video: en
    Reduce Motion el still ocupa el lugar del frame final y deben ser
    indistinguibles."""
    rgba = np.asarray(
        Image.open(keyed_dir / f"k{CINEMATIC_LAST:03d}.png").convert("RGBA"),
        dtype=np.uint8,
    )
    w, h = CANVAS
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    dist = np.minimum(np.minimum(xs, w - 1 - xs), np.minimum(ys, h - 1 - ys))
    mask = np.clip(dist / EDGE_FEATHER_PX, 0.0, 1.0)
    rgba = clean_transparent_rgb(rgba)
    rgba[..., 3] = (rgba[..., 3].astype(np.float64) * mask).astype(np.uint8)
    img = Image.fromarray(rgba)
    if CARD_STILL_SCALE != 1.0:
        img = img.resize(
            (round(w * CARD_STILL_SCALE), round(h * CARD_STILL_SCALE)),
            Image.LANCZOS,
        )
    quantized(img).save(CHEST_ANIM / CARD_STILL_FILE, optimize=True)


def build_manifest() -> dict:
    def rect(crop):
        return {"x": crop[0], "y": crop[1], "w": crop[2], "h": crop[3]}

    return {
        "schemaVersion": 2,
        "fps": FPS,
        "canvas": {"w": CANVAS[0], "h": CANVAS[1]},
        "chestRect": CHEST_RECT,
        "parchmentRect": PARCHMENT_RECT,
        "segments": {
            name: {
                "first": seg["first"],
                "last": seg["last"],
                "crop": rect(seg["crop"]),
                "scale": seg["scale"],
            }
            for name, seg in SEGMENTS.items()
        },
        "cinematic": {
            "file": CINEMATIC_FILE,
            "first": CINEMATIC_FIRST,
            "last": CINEMATIC_LAST,
            "crop": rect(FULL_CROP),
        },
        "cardStill": {
            "file": CARD_STILL_FILE,
            "crop": rect(FULL_CROP),
            "scale": CARD_STILL_SCALE,
        },
    }


def static_canvas_side(bbox_w: int, occupancy: float = STATIC_OCCUPANCY) -> int:
    """Lado del lienzo cuadrado para que el cofre ocupe `occupancy` del ancho."""
    return int(round(bbox_w / occupancy))


def emit_static_chest(keyed_dir: Path) -> None:
    """`ui_chest_closed` nuevo desde el primer frame, a la ocupacion del viejo."""
    rgba = np.asarray(
        Image.open(keyed_dir / "k000.png").convert("RGBA"), dtype=np.uint8
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
        emit_card_still(keyed_dir)
        emit_static_chest(keyed_dir)
        encode_cinematic(args.video, keyed_dir)

    write_json(CHEST_ANIM / "chest_anim.json", build_manifest())

    frames = sorted(CHEST_ANIM.glob("chest_f*.png"))
    total_kb = sum(f.stat().st_size for f in frames) // 1024
    mov_kb = (CHEST_ANIM / CINEMATIC_FILE).stat().st_size // 1024
    still_kb = (CHEST_ANIM / CARD_STILL_FILE).stat().st_size // 1024
    print(
        f"[OK] {len(frames)} frames ({total_kb} KB) + {CINEMATIC_FILE} "
        f"({mov_kb} KB) + {CARD_STILL_FILE} ({still_kb} KB) + chest_anim.json "
        f"+ ui_chest_closed @2x/@3x"
    )
    for warning in warnings:
        print(warning)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
