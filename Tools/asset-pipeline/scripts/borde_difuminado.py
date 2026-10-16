#!/usr/bin/env python3
"""El borde de arriba de los clips con alfa: medirlo y, si los rayos lo cortan, fundirlo.

PLAN-v2 E14b B32. En `obj_paquete_abre.mov` los rayos y el halo llegan al borde de arriba del
cuadro y se cortan en linea recta. El arreglo se HORNEA en el asset (no es un efecto en tiempo real):
se vuelve a exportar el clip con el alfa multiplicado por un degrade vertical, de 0 en el borde de
arriba a 1 en `--pct` % de la altura (15 % por defecto, la opcion A del mockup aprobado), y SOLO desde
el cuadro en que los rayos tocan el borde: el salto de las tapas, antes, llega al 6-8 % y queda entero.

`ffmpeg` no lee el alfa de estos `.mov`; AVFoundation si. Por eso los cuadros se leen con
`leer_cuadros_alfa.swift` (se compila solo la primera vez) y se escriben por el mismo camino que el
resto del pipeline (`hevc_videotoolbox`, `hvc1`, mismas calidades que `chest_video_frames.py`).

    .venv/bin/python scripts/borde_difuminado.py medir ../../FisuEvolution/Resources/Loops/obj_*.mov
    .venv/bin/python scripts/borde_difuminado.py hornear ../../FisuEvolution/Resources/Loops/obj_paquete_abre.mov
    .venv/bin/python scripts/borde_difuminado.py tira <clip.mov> <salida.png> [--fondo azul]

Respaldo: antes de pisar el clip, `hornear` copia el original a `state/respaldos-b32/` (ignorado
por git, como todo `state/`; el original sigue en la historia) y NO lo pisa si ya existe: volver a
hornear parte siempre del original, asi el degrade no se aplica dos veces.
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))

from chest_video_frames import HEVC_ALPHA_QUALITY, HEVC_QUALITY  # noqa: E402

LECTOR_SWIFT = AQUI / "leer_cuadros_alfa.swift"
LECTOR_BIN = AQUI.parent / "state" / "leer_cuadros_alfa"
RESPALDOS = AQUI.parent / "state" / "respaldos-b32"
FPS = "24"

# Un pixel cuenta como "algo" si su alfa pasa de esto (el antialias del contorno no).
UMBRAL_ALFA = 16
# El borde "tocado": alguna de las primeras filas tiene algo.
FILAS_BORDE = 2
# El degrade por defecto: del 0 % (alfa 0) al 15 % (alfa 1) de la altura.
PCT_DEFECTO = 15.0


class BordeError(RuntimeError):
    pass


def compilar_lector() -> Path:
    if LECTOR_BIN.exists() and LECTOR_BIN.stat().st_mtime >= LECTOR_SWIFT.stat().st_mtime:
        return LECTOR_BIN
    LECTOR_BIN.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(["swiftc", "-O", "-o", str(LECTOR_BIN), str(LECTOR_SWIFT)],
                       capture_output=True, text=True)
    if r.returncode:
        raise BordeError(f"swiftc fallo:\n{r.stderr}")
    return LECTOR_BIN


def leer_cuadros(clip: Path) -> np.ndarray:
    """(n, alto, ancho, 4) BGRA, alfa recto."""
    r = subprocess.run([str(compilar_lector()), str(clip)], capture_output=True)
    if r.returncode:
        raise BordeError(f"no se pudo leer {clip.name}: {r.stderr.decode()}")
    ancho, alto = (int(x) for x in r.stderr.decode().split()[:2])
    datos = np.frombuffer(r.stdout, np.uint8)
    return datos.reshape(-1, alto, ancho, 4).copy()


def toca_borde(cuadros: np.ndarray) -> np.ndarray:
    """Por cuadro: True si hay algo (alfa > umbral) en las primeras filas."""
    return (cuadros[:, :FILAS_BORDE, :, 3] > UMBRAL_ALFA).any(axis=(1, 2))


def fila_mas_alta(cuadros: np.ndarray) -> np.ndarray:
    """Por cuadro: la primera fila con algo, en % de la altura (-1 si esta vacio)."""
    alto = cuadros.shape[1]
    hay = (cuadros[..., 3] > UMBRAL_ALFA).any(axis=2)
    primera = np.where(hay.any(axis=1), hay.argmax(axis=1), -1)
    return np.where(primera >= 0, primera * 100.0 / alto, -1.0)


def cuadro_de_rayos(cuadros: np.ndarray) -> int | None:
    """El primer cuadro en que algo toca el borde (los rayos), o None si ninguno."""
    toca = toca_borde(cuadros)
    return int(toca.argmax()) if toca.any() else None


def degrade(alto: int, pct: float) -> np.ndarray:
    """(alto, 1) de 0 en la fila de arriba a 1 en `pct` % de la altura."""
    fila_uno = max(alto * pct / 100.0, 1.0)
    y = (np.arange(alto) + 0.5) / fila_uno
    return np.clip(y, 0.0, 1.0)[:, None].astype(np.float32)


def difuminar(cuadros: np.ndarray, desde: int, pct: float = PCT_DEFECTO) -> np.ndarray:
    """Copia con el alfa de los cuadros `desde`.. multiplicado por el degrade."""
    salida = cuadros.copy()
    g = degrade(cuadros.shape[1], pct)
    tramo = salida[desde:, :, :, 3].astype(np.float32) * g
    salida[desde:, :, :, 3] = np.rint(tramo).astype(np.uint8)
    return salida


def escribir(cuadros: np.ndarray, destino: Path) -> None:
    """HEVC con alfa, hvc1, sin audio, por el mismo camino que `encode_cutout`."""
    n, alto, ancho, _ = cuadros.shape
    destino.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(
        ["ffmpeg", "-v", "error", "-f", "rawvideo", "-pix_fmt", "bgra", "-s", f"{ancho}x{alto}",
         "-framerate", FPS, "-i", "-", "-vf", "format=bgra", "-c:v", "hevc_videotoolbox",
         "-alpha_quality", HEVC_ALPHA_QUALITY, "-q:v", HEVC_QUALITY, "-tag:v", "hvc1",
         "-an", "-y", str(destino)],
        input=cuadros.tobytes(), capture_output=True)
    if r.returncode:
        raise BordeError(f"ffmpeg fallo: {r.stderr.decode()}")


def propiedades(clip: Path) -> dict:
    r = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames", "-show_entries",
         "stream=codec_name,codec_tag_string,width,height,r_frame_rate,nb_read_frames,duration",
         "-of", "default=nw=1", str(clip)], capture_output=True, text=True, check=True)
    return dict(linea.split("=", 1) for linea in r.stdout.split())


def hornear(clip: Path, pct: float, desde: int | None) -> dict:
    RESPALDOS.mkdir(parents=True, exist_ok=True)
    respaldo = RESPALDOS / clip.name
    if not respaldo.exists():
        shutil.copy2(clip, respaldo)
    original = leer_cuadros(respaldo)
    antes = propiedades(respaldo)
    if desde is None:
        desde = cuadro_de_rayos(original)
        if desde is None:
            raise BordeError(f"{clip.name}: ningun cuadro toca el borde; nada que difuminar")
    nuevo = difuminar(original, desde, pct)
    tmp = clip.with_suffix(".nuevo.mov")
    escribir(nuevo, tmp)
    tmp.replace(clip)
    despues = propiedades(clip)
    for clave in ("codec_name", "codec_tag_string", "width", "height", "r_frame_rate", "nb_read_frames"):
        if antes[clave] != despues[clave]:
            raise BordeError(f"{clip.name}: cambio {clave}: {antes[clave]} -> {despues[clave]}")
    return {"desde": desde, "pct": pct, "peso_antes": respaldo.stat().st_size,
            "peso_despues": clip.stat().st_size, **despues}


def tira(clip: Path, salida: Path, fondo: str, cuadros_pedidos: list[int] | None = None) -> None:
    from PIL import Image
    cuadros = leer_cuadros(clip)
    n = len(cuadros)
    idx = cuadros_pedidos or [int(i) for i in np.linspace(0, n - 1, 8)]
    color = {"azul": (47, 107, 138), "crema": (241, 229, 201)}[fondo]
    celdas = []
    for i in idx:
        f = cuadros[min(i, n - 1)].astype(np.float32)
        a = f[..., 3:4] / 255.0
        rgb = f[..., 2::-1] * a + np.array(color, np.float32) * (1 - a)
        celdas.append(Image.fromarray(rgb.astype(np.uint8)).resize((192, 192)))
    lienzo = Image.new("RGB", (192 * len(celdas), 192))
    for k, c in enumerate(celdas):
        lienzo.paste(c, (192 * k, 0))
    lienzo.save(salida)


def informe(clip: Path) -> str:
    c = leer_cuadros(clip)
    toca = toca_borde(c)
    filas = fila_mas_alta(c)
    desde = cuadro_de_rayos(c)
    return (f"{clip.name}: {len(c)} cuadros, tocan el borde {int(toca.sum())}"
            + (f" (desde el {desde})" if desde is not None else "")
            + f", fila mas alta {filas[filas >= 0].min():.1f} %" if (filas >= 0).any()
            else f"{clip.name}: vacio")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("medir")
    m.add_argument("clips", nargs="+", type=Path)
    h = sub.add_parser("hornear")
    h.add_argument("clip", type=Path)
    h.add_argument("--pct", type=float, default=PCT_DEFECTO)
    h.add_argument("--desde", type=int, default=None, help="cuadro desde el que se aplica (def: el de los rayos)")
    t = sub.add_parser("tira")
    t.add_argument("clip", type=Path)
    t.add_argument("salida", type=Path)
    t.add_argument("--fondo", choices=["azul", "crema"], default="azul")
    t.add_argument("--cuadros", type=int, nargs="+")
    a = p.parse_args()
    try:
        if a.cmd == "medir":
            for clip in a.clips:
                print(informe(clip))
        elif a.cmd == "hornear":
            print(hornear(a.clip, a.pct, a.desde))
        else:
            tira(a.clip, a.salida, a.fondo, a.cuadros)
    except BordeError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
