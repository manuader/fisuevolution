"""Pósters de App Store a partir del arte generado con ChatGPT.

La imagen del modelo viene 941x1672 (9:16). App Store pide 1284x2778 (~0.462),
que es MÁS alto: se escala a cubrir por altura y se recorta al centro en ancho.
El titular lo dibuja PIL —no el modelo— para que las tildes salgan bien.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

#: Idioma del titular. `es` → ficha FisuEvolution · `en` → ficha HoboEvolution.
#: El arte NO cambia: los prompts piden cero texto justamente para esto, así que
#: la versión en inglés no vuelve a gastar cuota del modelo.
LANG = sys.argv[1] if len(sys.argv) > 1 else "es"

W, H = 1284, 2778
SRC = "/Users/manuader/Desktop/projects/automatic-image-generation/projects/fisu-store-promo/output"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "ai-posters-6.5" if LANG == "es" else f"ai-posters-6.5-{LANG}")
os.makedirs(OUT, exist_ok=True)
FONT = "/System/Library/Fonts/SFNSRounded.ttf"


def font(size, weight="Black"):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def cover(path):
    im = Image.open(path).convert("RGB")
    s = max(W / im.width, H / im.height)
    im = im.resize((int(im.width * s + .5), int(im.height * s + .5)), Image.LANCZOS)
    left = (im.width - W) // 2
    return im.crop((left, 0, left + W, H))


def scrim(im, height=1050):
    """Degradado oscuro arriba: el titular se lee sobre cualquier cielo."""
    g = Image.new("L", (1, height))
    for y in range(height):
        g.putpixel((0, y), int(205 * (1 - y / height) ** 1.5))
    veil = Image.new("RGBA", (W, height), (10, 8, 26))
    veil.putalpha(g.resize((W, height)))
    out = im.convert("RGBA")
    out.alpha_composite(veil)
    return out


def headline(canvas, lines, accent, top=150):
    d = ImageDraw.Draw(canvas)
    size = 124
    f = font(size)
    while max(d.textlength(l, font=f) for l in lines) > W - 140 and size > 58:
        size -= 4
        f = font(size)
    y = top
    for i, line in enumerate(lines):
        x = (W - d.textlength(line, font=f)) / 2
        for dx in range(-7, 8, 2):
            for dy in range(-7, 8, 2):
                if dx * dx + dy * dy <= 49:
                    d.text((x + dx, y + dy), line, font=f, fill=(12, 9, 26, 245))
        d.text((x, y), line, font=f, fill=(255, 255, 255) if i == 0 else accent)
        y += int(size * 1.17)


TITLES = {
    "es": [
        ["Arrancás", "de fisura"],
        ["Fusioná", "y evolucioná"],
        ["Elegí tu destino", "(con título)"],
        ["Hacete el", "rey del ladrillo"],
        ["Llegá a Dios", "(literal)"],
    ],
    "en": [
        ["You start", "as a hobo"],
        ["Merge", "and evolve"],
        ["Pick your destiny", "(degree included)"],
        ["Become the", "brick king"],
        ["Reach God", "(literally)"],
    ],
}

PANELS = [
    ("01_fisura",    "promo_fisura.png",   (255, 196, 61)),
    ("02_evolucion", "promo_merge.png",    (126, 235, 140)),
    ("03_carrera",   "promo_carrera.png",  (120, 220, 255)),
    ("04_ladrillo",  "promo_ladrillo.png", (255, 170, 220)),
    ("05_dios",      "promo_dios.png",     (255, 225, 130)),
]

if __name__ == "__main__":
    for (key, src, accent), lines in zip(PANELS, TITLES[LANG]):
        c = scrim(cover(os.path.join(SRC, src)))
        headline(c, lines, accent)
        p = os.path.join(OUT, f"{key}.png")
        c.convert("RGB").save(p, "PNG", optimize=True)
        im = Image.open(p)
        print(f"[{LANG}] {key+'.png':18} {im.width}x{im.height}  {os.path.getsize(p)//1024} KB")
