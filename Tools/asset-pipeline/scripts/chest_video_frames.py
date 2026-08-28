"""El video del cofre (pantalla verde) -> la animacion completa del juego.

Pedido del dueno (2026-08-28, segunda ronda): la apertura es EL VIDEO ENTERO —
sin rayos, particulas ni carta de la casa — y el contenido del premio se
renderiza al final dentro del marco vacio de la carta del video.

Cuarta ronda (mismo dia, el master DEFINITIVO): video 2D VERTICAL (720x1280)
con la estetica cartoon del juego — cofre de madera con herrajes, contornos
gruesos, cel shading — y CON SONIDO. Verde plano de punta a punta, el cofre
estalla, suelta la carta y se desvanece hacia abajo fundiendose al verde
(~f100-f118; keyeado queda una sombra tenue que se evapora — medido, se ve
deliberado); el final es el marco vacio quieto desde ~f204. La pista de audio
viaja en DOS familias: el tramo cinematico va DENTRO de `chest_open.mov`
(AVPlayer la reproduce con el volumen SFX del juego) y las dos sacudidas de
los toques salen como clips `sfx_chest_shake_a/b.caf` en `Resources/Audio/`
(los dispara la coreografia junto a sus frames, porque el timing lo pone el
dedo, no el video).

Produce cuatro familias de assets:

1. **Frames PNG interactivos** (idle + dos sacudidas, f0-f49): los latidos que
   responden al dedo piden swap de frame INMEDIATO, sin preroll — van como
   secuencia cuantizada que `ChestAnimationFeed` reproduce frame-perfect.
2. **`chest_open.mov`** (f50-f239, HEVC con canal alfa por VideoToolbox, CON
   su pista de audio): el tramo del estallido a la carta es LINEAL — ~8 s de
   corrido — y en video por hardware pesa una fraccion de los PNGs, a 24 fps
   garantizados. q:v 50 es indistinguible del original en A/B.
3. **`chest_card_still.png`** (f239): el estado final — la carta con el marco
   vacio — para Reduce Motion y de fallback.
4. **`sfx_chest_shake_a/b.caf`** (en `Resources/Audio/`): el sonido de cada
   sacudida, recortado de la pista del video, para que la coreografia lo
   dispare junto a sus frames.

`chest_anim.json` (schemaVersion 2) es EL contrato con el runtime
(`ChestAnimation.swift`); lo pinean `ChestAnimationTests` y
`test_chest_video_frames` de los dos lados. Ademas regenera `ui_chest_closed`
(@2x/@3x) desde el primer frame para la tarjeta de Regalos y el premio diario.

Necesita `ffmpeg` (con hevc_videotoolbox) en el PATH. Re-ejecutable: pisa lo
generado y el resultado es identico para el mismo video.

⚠️ El color del key esta medido EN EL STREAM con la matriz limited-range
(el master vigente da 0x10A12A; el del video anterior era 0x0BB427). El hex
calculado con la matriz full-range parece el mismo verde y NO lo es: con el
`chromakey` de ffmpeg se come el cofre entero. La banda util de `similarity`
quedo en 0,08-0,14 — mucho mas angosta de lo que la doc sugiere. Si el master
cambia, volver a medir: `crop=4:4:0:0` de f0 a rawvideo rgb24 y leer el pixel.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from _common import write_json

PIPELINE = Path(__file__).resolve().parent.parent
RESOURCES = PIPELINE.parent.parent / "FisuEvolution" / "Resources"
VIDEO = PIPELINE / "video" / "chest-animation.mp4"
CHEST_ANIM = RESOURCES / "ChestAnim"
UI_ATLAS = RESOURCES / "ui.atlas"
AUDIO_DIR = RESOURCES / "Audio"

# El keying calibrado (ver docstring) y la geometria medida del video.
KEY_COLOR = "0x22924A"
KEY_SIMILARITY = 0.11
KEY_BLEND = 0.04
KEY_FILTER = (
    f"chromakey={KEY_COLOR}:{KEY_SIMILARITY}:{KEY_BLEND},despill=type=green"
)
FPS = 24
CANVAS = (720, 1280)
# Donde REPOSA el cofre dentro del lienzo (componente conexa de f0): salta en
# las sacudidas pero siempre vuelve a este piso, asi que PNGs y video comparten
# esta unica ancla.
CHEST_RECT = {"x": 126, "y": 550, "w": 448, "h": 331}
# El interior pergamino de la carta en el ultimo frame (f239): filas/columnas
# con beige macizo (claro Y desaturado, umbral 60 px) — el bbox pelado se
# estira con los biseles claros del borde dorado y descentra el contenido.
PARCHMENT_RECT = {"x": 172, "y": 363, "w": 349, "h": 504}

# (x, y, w, h) en coordenadas del lienzo + escala de entrega de los PNG.
# Un solo crop para los tres segmentos interactivos: percentil 99,7 de masa
# de alfa ∪ bbox del cofre frame a frame, con margen de 8 px. En este master
# la sacudida A es la que mas polvo tira (x 41-658); la B es el temblor
# agachado que desemboca en el estallido y entra en el mismo encuadre.
STAGE_CROP = (30, 518, 640, 372)
FULL_CROP = (0, 0, 720, 1280)
SEGMENTS = {
    "idle": {"first": 0, "last": 0, "crop": STAGE_CROP, "scale": 1.0},
    "shakeA": {"first": 23, "last": 38, "crop": STAGE_CROP, "scale": 1.0},
    "shakeB": {"first": 39, "last": 49, "crop": STAGE_CROP, "scale": 1.0},
}

# El tramo cinematico: del estallido (la tapa revienta en f51) al marco vacio
# asentado — la sacudida B termina AGACHADA en f49 y f50 la continua, asi que
# el empalme PNG->video es un movimiento continuo. El cofre se desvanece
# fundiendose al verde en ~f100-f118 y el flip de la carta va ~f192-f200.
CINEMATIC_FIRST = 50
CINEMATIC_LAST = 239
# Perilla de interpolacion (minterpolate MCI sobre el VERDE, antes del
# keying — el alfa no sobrevive al filtro y el fondo estatico ayuda a la
# estimacion). MEDIDO el 2026-08-28: a 48 el resultado es visualmente limpio
# (sin fantasmas en confetti ni giro) pero el SIMULADOR lo decodifica peor
# que a 24 — el software-VideoToolbox no sostiene HEVC-alfa a 48 y el tramo
# del giro colapsa a ~5 fps efectivos (grabado y contado), contra los 24
# clavados del mov sin interpolar. Queda en 24 mientras el juego se mire en
# el sim; con device de verdad (F6), subirlo a 48 es cambiar esta constante
# y re-correr. A 24 el minterpolate se saltea entero.
CINEMATIC_OUTPUT_FPS = 24

# Las sacudidas llevan su sonido como clip suelto (el timing lo pone el DEDO):
# la ventana de audio es exactamente la de sus frames, con fade de 10 ms en
# las puntas para que el corte no haga click. PCM en .caf como sus hermanos
# de Resources/Audio/ — un clip de medio segundo no amerita codec.
SHAKE_SFX = {
    "sfx_chest_shake_a": ("shakeA", 23, 39),
    "sfx_chest_shake_b": ("shakeB", 39, 50),
}
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
    #
    # ⚠️ El `premultiply` es lo que hace TRANSPARENTE la transparencia:
    # `AVPlayerLayer` composita el HEVC-alfa como PREMULTIPLICADO
    # (out = rgb + fondo×(1−α)), y `chromakey` deja el RGB intacto — el verde
    # despillado (~L 26) de las zonas con α=0 se SUMABA al juego como un velo
    # claro cortado seco en el encuadre (+20..27 de luminancia, medido en
    # captura). Va DESPUÉS del alphamerge para multiplicar por el alfa ya
    # emplumado, y en gbrap porque el filtro no toma rgba empaquetado.
    # El sonido del tramo viaja DENTRO del mov, recortado al mismo arranque
    # que el video: AVPlayer lo reproduce solo y el volumen lo pone el juego.
    audio_start = CINEMATIC_FIRST / FPS
    interpolation = (
        f"minterpolate=fps={CINEMATIC_OUTPUT_FPS}:mi_mode=mci:mc_mode=aobmc:"
        f"me_mode=bidir:vsbmc=1,"
        if CINEMATIC_OUTPUT_FPS != FPS
        else ""
    )
    filter_complex = (
        f"[0:v]select='between(n,{CINEMATIC_FIRST},{CINEMATIC_LAST})',"
        f"setpts=PTS-STARTPTS,"
        f"{interpolation}"
        f"{KEY_FILTER},format=rgba,split[keyed][forAlpha];"
        "[forAlpha]alphaextract[alpha];"
        "[alpha][1:v]blend=all_mode=multiply:shortest=1[fadedalpha];"
        "[keyed][fadedalpha]alphamerge,format=gbrap,premultiply=inplace=1,"
        "format=bgra[out];"
        f"[0:a]atrim=start={audio_start:.6f},asetpts=PTS-STARTPTS[aout]"
    )
    subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(video),
            "-loop", "1", "-i", str(mask_path),
            "-filter_complex", filter_complex,
            "-map", "[out]", "-map", "[aout]",
            "-c:v", "hevc_videotoolbox",
            "-alpha_quality", HEVC_ALPHA_QUALITY,
            "-q:v", HEVC_QUALITY,
            "-tag:v", "hvc1",
            "-c:a", "aac", "-b:a", "160k",
            "-vsync", "0",
            "-y", str(CHEST_ANIM / CINEMATIC_FILE),
        ],
        check=True,
    )


def emit_shake_sfx(video: Path) -> None:
    """Los clips de las sacudidas, cortados de la pista del propio video."""
    for name, (_, first, last) in SHAKE_SFX.items():
        start, end = first / FPS, last / FPS
        duration = end - start
        subprocess.run(
            [
                "ffmpeg", "-v", "error", "-i", str(video), "-vn",
                "-af", (
                    f"atrim=start={start:.6f}:end={end:.6f},"
                    "asetpts=PTS-STARTPTS,"
                    "afade=t=in:d=0.01,"
                    f"afade=t=out:st={duration - 0.02:.6f}:d=0.02"
                ),
                "-c:a", "pcm_s16le",
                "-y", str(AUDIO_DIR / f"{name}.caf"),
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
    """`ui_chest_closed` nuevo desde el primer frame, a la ocupacion del viejo.

    El recorte es la COMPONENTE CONEXA mas grande, no el bbox global: el video
    trae destellos ambiente sueltos (hay uno en x~1150 ya en f0) que inflarian
    el lienzo y dejarian el cofre a media escala en Regalos y el diario.
    """
    rgba = np.asarray(
        Image.open(keyed_dir / "k000.png").convert("RGBA"), dtype=np.uint8
    )
    solid = rgba[..., 3] >= ALPHA_THRESHOLD
    labels, count = ndimage.label(solid)
    sizes = ndimage.sum(solid, labels, range(1, count + 1))
    ys, xs = np.where(labels == (int(np.argmax(sizes)) + 1))
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
    # ⚠️ Sin esto Xcode NO recompila el atlas: escribir un PNG en el lugar
    # (mismo inode) no cambia el mtime de la CARPETA .atlas, que es lo que
    # mira el build system — y el juego sigue mostrando el cofre anterior
    # desde el atlasc viejo (pasó: la tarjeta de Regalos mostró el cofre de
    # un master ya borrado con el PNG nuevo sentado en el arbol).
    os.utime(UI_ATLAS)


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
    emit_shake_sfx(args.video)

    write_json(CHEST_ANIM / "chest_anim.json", build_manifest())

    frames = sorted(CHEST_ANIM.glob("chest_f*.png"))
    total_kb = sum(f.stat().st_size for f in frames) // 1024
    mov_kb = (CHEST_ANIM / CINEMATIC_FILE).stat().st_size // 1024
    still_kb = (CHEST_ANIM / CARD_STILL_FILE).stat().st_size // 1024
    sfx_kb = sum(
        (AUDIO_DIR / f"{name}.caf").stat().st_size for name in SHAKE_SFX
    ) // 1024
    print(
        f"[OK] {len(frames)} frames ({total_kb} KB) + {CINEMATIC_FILE} "
        f"({mov_kb} KB, con audio) + {CARD_STILL_FILE} ({still_kb} KB) + "
        f"chest_anim.json + ui_chest_closed @2x/@3x + 2 sfx ({sfx_kb} KB)"
    )
    for warning in warnings:
        print(warning)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
