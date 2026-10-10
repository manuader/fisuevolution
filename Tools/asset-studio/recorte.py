"""Los recortes, las islas y el PNG final de una imagen.

Paso 1 (fondo): de un original con fondo blanco salen dos cortes —conectividad
(`whitebg_cutout`) y rembg (saliencia, isnet-general-use)— mas la version que hoy
esta en el juego. El dueno elige uno.

Paso 2 (islas): sobre el corte elegido, las islas de `balde_islas` (componentes
sueltos y huecos de blanco encerrado) se pintan de rojo para sacarlas, y un pincel
y una goma cubren lo que la deteccion no ve. El PNG final lo rehace SIEMPRE este
modulo desde el corte y las marcas —nunca se toma la imagen del navegador, que
premultiplica el alfa y redondea los bordes— asi el mismo pedido da los mismos
pixeles.

Al sacar algo no tiene que quedar la linea clara de su borde: `quitar_sin_halo`
se lleva tambien el anillo de antialias suelto alrededor de lo que sale y le
rehace el antialias al borde que queda, con el mismo matting de `whitebg_cutout`.
"""

from __future__ import annotations

import io
import threading
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import rutas  # noqa: F401  (pone scripts/ en el path)
from balde_islas import islas, mapa  # noqa: E402
from whitebg_cutout import FEATHER, cutout, undo_white_matte, white_distance  # noqa: E402

# Cuanto se dilata lo que sale para llevarse su antialias suelto.
ANILLO_HALO = 2
MAX_TRAZOS = 2000
MAX_PUNTOS = 20000


def cargar_rgba(ruta: str | Path) -> np.ndarray:
    with Image.open(ruta) as imagen:
        return np.array(imagen.convert("RGBA"))


def png(rgba: np.ndarray) -> bytes:
    salida = io.BytesIO()
    Image.fromarray(rgba, mode="RGBA").save(salida, format="PNG", compress_level=3)
    return salida.getvalue()


# ---------- cortes ----------
def corte_conectividad(original: Path, clave: str) -> np.ndarray:
    with Image.open(original) as imagen:
        return np.array(cutout(imagen.convert("RGB"), clave))


_rembg = {"sesion": None}
_candado_rembg = threading.Lock()


def corte_rembg(original: Path) -> np.ndarray:
    """La saliencia de rembg, al tamano del original. Carga el modelo una vez."""
    from rembg import new_session, remove

    with _candado_rembg:
        if _rembg["sesion"] is None:
            _rembg["sesion"] = new_session("isnet-general-use")
        with Image.open(original) as imagen:
            return np.array(remove(imagen.convert("RGB"), session=_rembg["sesion"]).convert("RGBA"))


def corte_juego(juego: Path) -> np.ndarray:
    return cargar_rgba(juego)


# ---------- islas ----------
def islas_y_mapa(rgba: np.ndarray) -> tuple[list[dict], bytes]:
    """Las fichas de cada isla y el PNG que la pagina lee para saber que hay bajo el mouse."""
    sueltas, huecos, fichas = islas(rgba)
    salida = io.BytesIO()
    mapa(sueltas, huecos).save(salida, format="PNG", compress_level=3)
    return fichas, salida.getvalue()


def mascara_de_trazo(forma: tuple[int, int], trazo: dict) -> np.ndarray:
    """Un trazo de pincel o goma: circulos de radio `radio` unidos por lineas."""
    alto, ancho = forma
    radio = max(0.5, float(trazo.get("radio", 8)))
    puntos = [(float(x), float(y)) for x, y in trazo.get("puntos", [])][:MAX_PUNTOS]
    lienzo = Image.new("L", (ancho, alto), 0)
    dibujo = ImageDraw.Draw(lienzo)
    if len(puntos) > 1:
        dibujo.line(puntos, fill=255, width=max(1, round(2 * radio)))
    for x, y in puntos:
        dibujo.ellipse((x - radio, y - radio, x + radio, y + radio), fill=255)
    return np.array(lienzo) > 0


def mascara_a_sacar(sueltas: np.ndarray, huecos: np.ndarray, rojas: list[str],
                    trazos: list[dict]) -> np.ndarray:
    """Lo que sale: las islas rojas, mas el pincel, menos la goma (en orden)."""
    rojas_s = [int(r[1:]) for r in rojas if r[:1] == "s" and r[1:].isdigit()]
    rojas_h = [int(r[1:]) for r in rojas if r[:1] == "h" and r[1:].isdigit()]
    sacar = np.isin(sueltas, rojas_s) | np.isin(huecos, rojas_h)
    for trazo in trazos[:MAX_TRAZOS]:
        trazo_mascara = mascara_de_trazo(sacar.shape, trazo)
        if trazo.get("modo") == "goma":
            sacar &= ~trazo_mascara
        else:
            sacar |= trazo_mascara
    return sacar


def rehacer_borde(rgba: np.ndarray, quitado: np.ndarray) -> np.ndarray:
    """El antialias del borde que queda donde se saco algo, como lo hace
    `whitebg_cutout`: en el anillo pegado a lo quitado, opacidad = d / d_de_adentro
    (d = cuanto se aleja del blanco) y color sin el blanco mezclado. Un borde de
    color pleno mide d ≈ d_de_adentro y no cambia; uno lavado de blanco —el filo
    de un hueco que se saco— baja su alfa y recupera el color de la linea."""
    cerca = ndimage.binary_dilation(quitado, iterations=FEATHER)
    # Solo lo opaco: un filo que ya era semitransparente ya tiene su matting.
    anillo = cerca & ~quitado & (rgba[..., 3] == 255)
    dentro = (rgba[..., 3] == 255) & ~cerca
    if not anillo.any() or not dentro.any():
        return rgba
    rgb = rgba[..., :3]
    distancia = white_distance(rgb).astype(np.float32)
    _, (fy, fx) = ndimage.distance_transform_edt(~dentro, return_indices=True)
    referencia = distancia[fy, fx]
    alfa = np.ones(distancia.shape, dtype=np.float32)
    alfa[anillo] = np.clip(distancia[anillo] / np.maximum(referencia[anillo], 1.0), 0.0, 1.0)
    salida = rgba.copy()
    salida[..., :3] = undo_white_matte(rgb, alfa)
    viejo = rgba[..., 3].astype(np.float32) / 255
    salida[..., 3] = np.where(anillo, np.round(np.minimum(viejo, alfa) * 255), rgba[..., 3]).astype(np.uint8)
    return salida


def quitar_sin_halo(rgba: np.ndarray, sacar: np.ndarray, conservar: np.ndarray) -> np.ndarray:
    """Saca `sacar` sin dejar la linea clara de su borde.

    Lo que sale se dilata `ANILLO_HALO` px sobre todo lo que no se conserva (el
    antialias suelto que ninguna isla reclamo), y el borde que queda se rehace."""
    if not sacar.any():
        return rgba.copy()
    afuera = sacar | (ndimage.binary_dilation(sacar, iterations=ANILLO_HALO) & ~conservar)
    quitado = afuera & (rgba[..., 3] > 0)
    limpio = rgba.copy()
    limpio[afuera] = 0
    return rehacer_borde(limpio, quitado)


def renderizar(rgba: np.ndarray, rojas: list[str], trazos: list[dict]) -> np.ndarray:
    """El PNG final: el corte sin las islas rojas ni lo pintado con el pincel."""
    sueltas, huecos, _ = islas(rgba)
    sacar = mascara_a_sacar(sueltas, huecos, rojas, trazos)
    conservar = (sueltas > 0) & ~sacar
    return quitar_sin_halo(rgba, sacar, conservar)


def miniatura(ruta: Path, lado: int = 112) -> bytes:
    with Image.open(ruta) as imagen:
        imagen = imagen.convert("RGBA")
        imagen.thumbnail((lado, lado), Image.LANCZOS)
        salida = io.BytesIO()
        imagen.save(salida, format="PNG")
        return salida.getvalue()
