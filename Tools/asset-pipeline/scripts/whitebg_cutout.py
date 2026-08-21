#!/usr/bin/env python3
"""Recorte de fondo blanco por conectividad — el que NO se come lo blanco del personaje.

El pipeline original usaba `rembg` (isnet-general-use), un modelo de saliencia:
decide "qué es el sujeto" mirando la imagen entera y, con arte cartoon sobre
fondo blanco, confunde un guardapolvo blanco con el fondo y lo deja transparente
(ver `senior_doctor`, `junior_doctor`, media galeria de skins).

Acá el criterio no es semantico sino topologico, que es el que corresponde:
**fondo = lo blanco que se toca con el borde del lienzo**. Una camisa blanca esta
rodeada por la linea negra del dibujo, no se conecta con el borde, y por lo tanto
JAMAS se recorta. No hay modelo, no hay umbral magico sobre "qué es un personaje":
hay componentes conexas.

El borde queda con alpha fraccional por matting (`alpha = d / d_solido`) y con el
blanco descontaminado del color, asi no queda el halo claro tipico del recorte
por umbral.
"""

from __future__ import annotations

import numpy as np
from PIL import Image
from scipy import ndimage

# Un pixel es "blanco de fondo" si ningun canal baja de 255 - WHITE_TOLERANCE.
# Gemini devuelve el fondo en 253-255, y el antialias del dibujo arranca bien por
# debajo: 14 separa los dos sin tocar el gris mas claro de un personaje.
WHITE_TOLERANCE = 14

# Ancho en pixeles del anillo de antialias alrededor del fondo. Todo lo que este
# mas adentro es personaje opaco aunque sea casi blanco, y ademas es de donde se
# saca el color de referencia para calcular la opacidad del anillo.
FEATHER = 3

# Solo para los assets de `HUECOS_CALADOS`: una isla mas chica que esto es ruido
# de compresion dentro de una zona clara, no un hueco que el dibujo quiso dejar.
MIN_HOLE_AREA = 256

# Los assets cuyo blanco encerrado SI es un hueco de verdad.
#
# Una isla blanca rodeada por el dibujo es ambigua: puede ser un guardapolvo o
# puede ser el aire entre dos anillos. Medido sobre los 219 originales, de 1183
# islas encerradas la enorme mayoria es dibujo — camisas, ojos, papeles, el toldo
# del mantero — asi que el default correcto es tratarlas como personaje. El color
# no las distingue (un guardapolvo blanco puro mide igual que el fondo), de modo
# que la excepcion se declara a mano y se verifica mirando el contacto.
HUECOS_CALADOS = frozenset({
    "fx_tap",            # ondas concentricas: el aire entre anillo y anillo
    "ui_trophy_gold",    # el ojo de las asas de la copa
    "ui_trophy_silver",
    "ui_trophy_bronze",
})


# Assets donde el blanco encerrado se decide MIDIENDO, isla por isla.
#
# Una isla encerrada es ambigua sólo si se la mira por su forma. Por su COLOR no:
# el papel atrapado —el óvalo que deja un lazo cerrado, el aire entre las piernas
# que cierra la sombra del piso— es literalmente el fondo del lienzo y mide 0.06
# de distancia contra él; un guardapolvo blanco está pintado, tiene sombreado, y
# mide 4.9. La franja del medio existe (ojos, chispas, dientes) y por eso el
# criterio es conservador: sólo se saca lo que mide como papel, y ante la duda
# gana el personaje, que es no perder dibujo.
PAPEL_MEDIDO = frozenset({
    "estanciero_estelar__tropero",
    "cartonero__diamante",
    "mantero__diamante",
})

# Distancia máxima al blanco del lienzo para considerar que una isla ES el lienzo.
DISTANCIA_PAPEL = 0.8


def islas_de_papel(rgb: np.ndarray, background: np.ndarray, whiteish: np.ndarray) -> np.ndarray:
    """Las islas encerradas cuyo color es el del fondo, no el de un blanco pintado."""
    interior = whiteish & ~background
    etiquetas, cuantas = ndimage.label(interior)
    if not cuantas:
        return np.zeros_like(interior)

    referencia = rgb[background].astype(float).mean(axis=0)
    areas = ndimage.sum_labels(interior, etiquetas, index=np.arange(1, cuantas + 1))
    papel = np.zeros_like(interior)
    for indice, area in enumerate(areas):
        if area < MIN_HOLE_AREA:
            continue
        isla = etiquetas == indice + 1
        # Sin el anillo de antialias, que siempre tira hacia el color del vecino.
        nucleo = ndimage.binary_erosion(isla, iterations=2)
        if nucleo.sum() < 30:
            nucleo = isla
        distancia = np.abs(rgb[nucleo].astype(float).mean(axis=0) - referencia).mean()
        if distancia < DISTANCIA_PAPEL:
            papel |= isla
    return papel


def white_distance(rgb: np.ndarray) -> np.ndarray:
    """Cuanto se aleja cada pixel del blanco puro, por el canal que mas se aleja.

    Usa el minimo de los canales y no la luminancia para que un amarillo saturado
    (255, 255, 0) cuente como color pleno y no como "casi blanco"."""
    return 255 - rgb.min(axis=2).astype(np.int16)


def background_mask(distance: np.ndarray, punch_holes: bool = False) -> np.ndarray:
    """Lo blanco conectado con el borde del lienzo. El resto es dibujo.

    Los primeros planos (`*_face`) apoyan los hombros contra el marco: ahi el
    borde tiene pixeles de personaje, y por eso las semillas se toman solo de los
    pixeles de borde que ademas son blancos.

    `punch_holes` suma tambien las islas blancas que el dibujo encierra; es lo que
    piden los pocos assets de `HUECOS_CALADOS` y lo que arruina a todos los demas."""
    whiteish = distance <= WHITE_TOLERANCE
    labels, count = ndimage.label(whiteish)
    if count == 0:
        return np.zeros_like(whiteish)

    border = np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])
    seeds = np.unique(border[border > 0])
    if seeds.size == 0:
        # Un dibujo que llena el lienzo de lado a lado no tiene fondo que sacar.
        return np.zeros_like(whiteish)

    background = np.isin(labels, seeds)

    if not punch_holes:
        return background

    interior = whiteish & ~background
    interior_labels, interior_count = ndimage.label(interior)
    if interior_count:
        areas = ndimage.sum_labels(
            interior, interior_labels, index=np.arange(1, interior_count + 1)
        )
        big = np.flatnonzero(areas >= MIN_HOLE_AREA) + 1
        background |= np.isin(interior_labels, big)

    return background


def alpha_from_background(distance: np.ndarray, background: np.ndarray) -> np.ndarray:
    """Opacidad 0 en el fondo, 1 en el dibujo y rampa en el anillo de antialias.

    En el anillo el pixel observado es una mezcla del color del dibujo con el
    blanco del fondo, asi que su opacidad real es `d / d_del_color_sin_mezclar`.
    Ese color de referencia se toma del pixel **de adentro** mas cercano, no del
    mas oscuro: quien define si un pixel ya es color pleno es la geometria (estar
    lejos del fondo), no su tono. Con un umbral de tono, un filo que es 80% blanco
    da lo bastante oscuro como para pasar por pleno y se queda opaco — que es
    justo el halo claro que se quiere evitar."""
    alpha = np.ones(distance.shape, dtype=np.float32)
    alpha[background] = 0.0

    outside = ndimage.binary_dilation(background, iterations=FEATHER)
    ring = outside & ~background
    inside = ~outside
    if not ring.any() or not inside.any():
        # Un dibujo tan fino que es todo filo: mejor entero que comido.
        return alpha

    _, nearest = ndimage.distance_transform_edt(~inside, return_indices=True)
    reference = distance[nearest[0], nearest[1]].astype(np.float32)
    alpha[ring] = np.clip(distance[ring] / np.maximum(reference[ring], 1.0), 0.0, 1.0)
    return alpha


def undo_white_matte(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Le saca al borde el blanco del fondo que tiene mezclado.

    Sin esto, los pixeles semitransparentes conservan su tono lavado y el sprite
    queda con un halo claro alrededor cuando se dibuja sobre el fondo del juego."""
    safe = np.maximum(alpha, 1e-3)[..., None]
    recovered = (rgb.astype(np.float32) - 255.0 * (1.0 - alpha[..., None])) / safe
    blended = np.where(alpha[..., None] > 0.0, recovered, rgb.astype(np.float32))
    return np.clip(blended, 0, 255).astype(np.uint8)


def cutout(image: Image.Image, asset_key: str = "") -> Image.Image:
    """PNG sin fondo, con el personaje entero — incluido todo lo blanco que tenga."""
    rgb = np.array(image.convert("RGB"))
    distance = white_distance(rgb)
    background = background_mask(distance, punch_holes=asset_key in HUECOS_CALADOS)
    if asset_key in PAPEL_MEDIDO:
        background = background | islas_de_papel(rgb, background, distance <= WHITE_TOLERANCE)
    alpha = alpha_from_background(distance, background)
    clean = undo_white_matte(rgb, alpha)
    return Image.fromarray(
        np.dstack([clean, (alpha * 255).round().astype(np.uint8)]), mode="RGBA"
    )
