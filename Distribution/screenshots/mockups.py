"""Arma las 5 capturas promocionales de App Store, 1284x2778 exactos.

Fondo = arte real del juego (desenfocado y teñido, para que el titular se lea).
Titular = SF Rounded Black, con tilde correcta, dibujado por PIL.
Mockup  = la captura real del simulador, con bisel y sombra.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance
import os, sys

#: Idioma. Acá NO alcanza con cambiar el titular: el mockup muestra la UI real,
#: así que cada idioma necesita SUS capturas del simulador, sacadas con
#: `-AppleLanguages "(xx)"`. Por eso se lee de una carpeta distinta.
LANG = sys.argv[1] if len(sys.argv) > 1 else "es"

W, H = 1284, 2778
GAME = "/Users/manuader/Desktop/projects/fisuevolution/FisuEvolution/Resources"
SHOTS = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "crudas-6.5" if LANG == "es" else f"crudas-6.5-{LANG}")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "promo-6.5" if LANG == "es" else f"promo-6.5-{LANG}")
os.makedirs(OUT, exist_ok=True)

FONT = "/System/Library/Fonts/SFNSRounded.ttf"

def font(size, weight="Black"):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f

# (clave, fondo del juego, captura, titular, color de acento)
TITLES = {
    "es": [["Arrancás", "de fisura"], ["Elegí tu destino", "(con título)"],
           ["Tus personajes", "laburan solos"], ["Coleccioná", "todas las pintas"],
           ["Aparecen", "los especiales"]],
    "en": [["You start", "as a hobo"], ["Pick your destiny", "(degree included)"],
           ["Your characters", "work for you"], ["Collect", "every outfit"],
           ["Specials", "show up"]],
}

PANELS = [
    ("01_arrancas",   "bg_alley",     "01_board.png",   (255, 196, 61)),
    ("02_destino",    "bg_corporate", "02_career.png",  (120, 220, 255)),
    ("03_laburan",    "bg_urban",     "05_mejoras.png", (126, 235, 140)),
    ("04_pintas",     "bg_luxury",    "03_pintas.png",  (255, 170, 220)),
    ("05_especiales", "bg_galaxy",    "04_special.png", (255, 140, 90)),
]


def backdrop(name, accent):
    """Fondo del juego a pantalla completa: recortado, desenfocado y oscurecido."""
    src = Image.open(f"{GAME}/Backgrounds/{name}@3x.png").convert("RGB")
    # cubrir 1284x2778 conservando proporción
    s = max(W / src.width, H / src.height)
    src = src.resize((int(src.width * s + 1), int(src.height * s + 1)), Image.LANCZOS)
    left = (src.width - W) // 2
    top = (src.height - H) // 3          # un tercio: deja ver el cielo, no el piso
    bg = src.crop((left, top, left + W, top + H))
    bg = bg.filter(ImageFilter.GaussianBlur(9))
    bg = ImageEnhance.Brightness(bg).enhance(0.62)
    bg = ImageEnhance.Color(bg).enhance(1.25)

    # viñeta vertical: más oscuro arriba (titular) y abajo (respiro)
    veil = Image.new("L", (1, H))
    for y in range(H):
        t = y / H
        if t < 0.34:
            a = int(150 - 90 * (t / 0.34))
        elif t > 0.88:
            a = int(140 * ((t - 0.88) / 0.12))
        else:
            a = 60
        veil.putpixel((0, y), a)
    veil = veil.resize((W, H))
    dark = Image.new("RGB", (W, H), (12, 10, 26))
    bg = Image.composite(dark, bg, veil.point(lambda v: v))
    bg = Image.blend(bg, dark, 0.10)

    # un halo del color de acento detrás del mockup
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(halo)
    d.ellipse([-180, 900, W + 180, 2400], fill=accent + (46,))
    halo = halo.filter(ImageFilter.GaussianBlur(180))
    bg = Image.alpha_composite(bg.convert("RGBA"), halo)
    return bg


def rounded(img, r):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], r, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def phone(shot_path, target_w):
    """La captura real dentro de un bisel oscuro, con sombra."""
    shot = Image.open(shot_path).convert("RGB")
    scale = target_w / shot.width
    shot = shot.resize((target_w, int(shot.height * scale)), Image.LANCZOS)
    shot = rounded(shot, 54)

    bez = 16
    frame = Image.new("RGBA", (shot.width + bez * 2, shot.height + bez * 2), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        [0, 0, frame.width - 1, frame.height - 1], 72, fill=(24, 22, 34, 255))
    frame.alpha_composite(shot, (bez, bez))

    pad = 90
    canvas = Image.new("RGBA", (frame.width + pad * 2, frame.height + pad * 2), (0, 0, 0, 0))
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [pad, pad + 20, pad + frame.width, pad + 20 + frame.height], 72, fill=(0, 0, 0, 150))
    sh = sh.filter(ImageFilter.GaussianBlur(38))
    canvas.alpha_composite(sh)
    canvas.alpha_composite(frame, (pad, pad))
    return canvas


def headline(canvas, lines, accent):
    d = ImageDraw.Draw(canvas)
    size = 118
    f = font(size)
    # que la línea más larga entre con margen de 80 px por lado
    while max(d.textlength(l, font=f) for l in lines) > W - 160 and size > 60:
        size -= 4
        f = font(size)

    y = 196
    for i, line in enumerate(lines):
        w = d.textlength(line, font=f)
        x = (W - w) / 2
        col = (255, 255, 255) if i == 0 else accent
        # contorno grueso, como el arte del juego
        for dx in range(-6, 7, 2):
            for dy in range(-6, 7, 2):
                if dx * dx + dy * dy <= 36:
                    d.text((x + dx, y + dy), line, font=f, fill=(16, 12, 28, 235))
        d.text((x, y), line, font=f, fill=col)
        y += int(size * 1.18)
    return y


def build(key, bg_name, shot, lines, accent):
    canvas = backdrop(bg_name, accent)
    bottom = headline(canvas, lines, accent)

    ph = phone(os.path.join(SHOTS, shot), 940)
    x = (W - ph.width) // 2
    y = max(bottom + 34, 560)
    if y + ph.height > H + 300:            # que sobresalga apenas por abajo
        y = H + 300 - ph.height
    canvas.alpha_composite(ph, (x, y))

    out = os.path.join(OUT, f"{key}.png")
    canvas.convert("RGB").save(out, "PNG", optimize=True)
    return out


if __name__ == "__main__":
    for (key, bg, shot, accent), lines in zip(PANELS, TITLES[LANG]):
        path = build(key, bg, f'{LANG}_{shot}', lines, accent)
        im = Image.open(path)
        print(f"{os.path.basename(path):22} {im.width}x{im.height}  {os.path.getsize(path)//1024} KB")
