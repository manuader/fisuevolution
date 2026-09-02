#!/usr/bin/env python3
"""Generación de assets con la API de Gemini (nano banana) — stdlib puro.

Camino primario tras descartar SD1.5/SDXL local por calidad (decisión del
usuario). Consistencia de estilo: las primeras imágenes aprobadas se pasan como
REFERENCIAS en cada request siguiente (el modelo soporta image conditioning),
así todo el set sale "del mismo estudio".

Uso:
    python3 scripts/gemini_batch.py --test            # 4 muestras para review visual
    python3 scripts/gemini_batch.py --tanda 1         # tanda completa
    python3 scripts/gemini_batch.py --asset homeless  # un asset puntual

La key vive en Tools/asset-pipeline/.secrets/gemini.key (gitignored) o en la
variable de entorno GEMINI_API_KEY. Modelo: gemini-2.5-flash-image.
"""

import argparse
import base64
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

PIPELINE = Path(__file__).resolve().parent.parent
MODEL = "gemini-2.5-flash-image"
ENDPOINT = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"

STYLE_PREAMBLE = (
    "Official 2D mobile game character asset, flat vector cartoon style, "
    "thick uniform black outlines, flat colors with minimal cel shading, "
    "vibrant palette (golden yellow #FFD93D, orange #FF6B35, pink #FF4D6D, "
    "blue #4D96FF, green #6BCB77). Single character only, FULL BODY standing "
    "pose with both feet planted on the ground and hands visible, complete "
    "figure with generous margin, slight 3/4 view, characterful idle pose, "
    "big-head small-body proportions, humorous adult-comedy expression. "
    "Pure white background, no shadows on the background, no text, no "
    "watermark, no cropping. Production quality, cohesive studio look."
)

STYLE_PREAMBLE_SCENE = (
    "Official 2D mobile game background, flat vector cartoon style, thick "
    "outlines, flat colors, vibrant palette. Game playfield composition: the "
    "bottom third is a clean, empty, walkable ground surface where characters "
    "will stand (no objects there), scenery and skyline in the upper area. "
    "No characters, no people, no text, no watermark. Full canvas scene."
)

# El ícono de App Store es el único asset que NO va al juego, y por eso es el
# único que contradice a los otros dos preámbulos en tres puntos:
#
#   1. **Fondo opaco, no blanco.** Todo lo demás sale sobre blanco para que
#      `whitebg_cutout.py` lo recorte a PNG transparente. El ícono NO se
#      recorta: Apple RECHAZA un ícono con canal alfa. Su fondo es parte del
#      asset.
#   2. **Degradé permitido.** El preámbulo de personaje pide "NO gradients"
#      —es la regla que mantiene el estilo plano del tablero—; acá el degradé
#      celeste es un pedido explícito del dueño (2026-09-02).
#   3. **Sin texto, y es una decisión, no una omisión.** El juego se llama
#      FisuEvolution en castellano y HoboEvolution en inglés: cualquier texto
#      horneado en el ícono estaría mal en uno de los dos mercados.
#
# La otra restricción es de legibilidad: el ícono se ve a 60×60 pt en la home
# screen y a ~29 pt en Ajustes. Por eso la cara ocupa el 70-80% del lienzo y
# la composición se piensa dentro del círculo seguro — iOS recorta las esquinas
# con su máscara superelíptica y cualquier detalle que viva ahí se pierde.
STYLE_PREAMBLE_ICON = (
    "Official iOS App Store app icon for the mobile game. Match EXACTLY the "
    "art style of the reference images: 2D cartoon with thick dark brown-black "
    "outlines of varying weight, warm muted earthy palette, soft cel shading "
    "with visible texture, expressive hand-drawn character work. "
    "SQUARE 1:1 canvas, fully OPAQUE background edge to edge, no transparency, "
    "no alpha channel. "
    "Composition: a single character HEAD-AND-SHOULDERS portrait, centered, "
    "filling 70-80% of the canvas, facing the viewer. Bold silhouette that "
    "stays readable when scaled down to 60x60 pixels. Keep all important "
    "detail inside a centered circle — the corners get masked by the iOS "
    "rounded-square mask. "
    "ABSOLUTELY NO TEXT, no letters, no words, no numbers, no logo type, no "
    "watermark, no signature, no border frame, no rounded-corner mask drawn "
    "into the image, no drop shadow outside the canvas, no UI chrome, no "
    "mockup of a phone. Flat square full-bleed artwork only."
)


def load_key() -> str:
    import os
    key = os.environ.get("GEMINI_API_KEY")
    if key:
        return key.strip()
    key_file = PIPELINE / ".secrets" / "gemini.key"
    if key_file.exists():
        return key_file.read_text().strip()
    sys.exit(
        "No hay API key. Guardala en Tools/asset-pipeline/.secrets/gemini.key "
        "o exportá GEMINI_API_KEY."
    )


def load_prompts() -> list[dict]:
    return json.loads((PIPELINE / "prompts" / "prompts.json").read_text())


def build_request(entry: dict, references: list[Path]) -> dict:
    category = entry.get("category")
    is_scene = category == "background"
    # El ícono SÍ quiere las referencias (es el mismo Fisura del juego, no un
    # personaje nuevo: sin condicionar por imagen el modelo inventa otro
    # indigente), pero NO quiere el preámbulo de personaje, que le pediría
    # figura completa sobre blanco.
    preamble = (
        STYLE_PREAMBLE_ICON if category == "appicon"
        else STYLE_PREAMBLE_SCENE if is_scene
        else STYLE_PREAMBLE
    )
    subject = entry.get("prompt") or entry.get("subject", "")
    parts: list[dict] = []
    if references and not is_scene:
        parts.append({
            "text": "Match EXACTLY the art style, outline weight, proportions and "
                    "palette of these reference characters from the same game:"
        })
        for ref in references:
            parts.append({
                "inline_data": {
                    "mime_type": "image/png",
                    "data": base64.b64encode(ref.read_bytes()).decode(),
                }
            })
    parts.append({"text": f"{preamble}\n\nSubject: {subject}"})
    return {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }


def generate_one(entry: dict, references: list[Path], key: str, out_path: Path, retries: int = 3) -> bool:
    request_body = json.dumps(build_request(entry, references)).encode()
    for attempt in range(1, retries + 1):
        try:
            request = urllib.request.Request(
                f"{ENDPOINT}?key={key}",
                data=request_body,
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(request, timeout=120) as response:
                payload = json.load(response)
            for candidate in payload.get("candidates", []):
                for part in candidate.get("content", {}).get("parts", []):
                    data = part.get("inlineData") or part.get("inline_data")
                    if data and data.get("data"):
                        out_path.parent.mkdir(parents=True, exist_ok=True)
                        out_path.write_bytes(base64.b64decode(data["data"]))
                        return True
            print(f"  sin imagen en la respuesta (intento {attempt}): {json.dumps(payload)[:200]}")
        except urllib.error.HTTPError as error:
            detail = error.read().decode()[:300]
            print(f"  HTTP {error.code} (intento {attempt}): {detail}")
            if error.code == 429:
                wait = 30 * attempt
                print(f"  rate limit — espero {wait}s")
                time.sleep(wait)
                continue
        except Exception as error:  # red, timeout
            print(f"  error (intento {attempt}): {error}")
        time.sleep(5)
    return False


def reference_images() -> list[Path]:
    """Anclas de estilo: las primeras aprobadas en heroes/approved/ (máx 3)."""
    approved = PIPELINE / "heroes" / "approved"
    if not approved.exists():
        return []
    return sorted(approved.glob("*.png"))[:3]


# El ícono se condiciona con los assets QUE YA ESTÁN EN EL JUEGO, no con
# `heroes/approved/`. La razón es que `approved/` guarda las anclas de estilo de
# la primera tanda, y el arte embarcado evolucionó desde ahí: el ícono tiene que
# parecerse a lo que el jugador ve cuando abre la app, o el paso de la ficha de
# App Store al tablero se siente como dos juegos distintos.
#
# Van la CARA (que es la composición del ícono) y el CUERPO (que trae la paleta
# y el tratamiento de la ropa, y evita que el modelo se invente el gorro).
ICON_REFERENCES = [
    Path("FisuEvolution/Resources/ui.atlas/homeless_face@3x.png"),
    Path("FisuEvolution/Resources/earth.atlas/homeless_idle@2x.png"),
]


def icon_reference_images() -> list[Path]:
    """Las referencias del ícono, resueltas contra la raíz del repo."""
    repo = PIPELINE.parent.parent
    found = [repo / relative for relative in ICON_REFERENCES]
    missing = [p for p in found if not p.exists()]
    if missing:
        sys.exit(
            "faltan las referencias del ícono (¿se renombró el atlas?): "
            + ", ".join(str(p) for p in missing)
        )
    return found


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--test", action="store_true", help="4 muestras para review visual")
    group.add_argument("--tanda", type=int)
    group.add_argument("--asset", type=str)
    parser.add_argument("--out", type=str, default=None)
    args = parser.parse_args()

    key = load_key()
    prompts = load_prompts()
    references = reference_images()
    if references:
        print(f"usando {len(references)} referencias de estilo: {[r.name for r in references]}")

    if args.test:
        test_keys = ["homeless", "ceo", "cartonero", "god"]
        selected = [e for e in prompts if e["assetKey"] in {f"{k}_idle" for k in test_keys} or e["assetKey"] in test_keys]
        out_dir = Path(args.out) if args.out else PIPELINE / "state" / "gemini-test"
    elif args.asset:
        selected = [e for e in prompts if args.asset in e["assetKey"]]
        out_dir = Path(args.out) if args.out else PIPELINE / "raw" / "puntuales"
    else:
        selected = [e for e in prompts if e.get("tanda") == args.tanda]
        out_dir = Path(args.out) if args.out else PIPELINE / "raw" / f"tanda_{args.tanda}"

    if not selected:
        sys.exit("nada que generar con ese filtro")

    print(f"{len(selected)} assets → {out_dir}")
    icon_references = icon_reference_images() if any(
        e.get("category") == "appicon" for e in selected
    ) else []
    failures = []
    for index, entry in enumerate(selected, 1):
        out_path = out_dir / f"{entry['assetKey']}.png"
        if out_path.exists():
            print(f"[{index}/{len(selected)}] {entry['assetKey']} ya existe, salto")
            continue
        print(f"[{index}/{len(selected)}] {entry['assetKey']}…")
        entry_references = (
            icon_references if entry.get("category") == "appicon" else references
        )
        if not generate_one(entry, entry_references, key, out_path):
            failures.append(entry["assetKey"])
        time.sleep(2)  # cortesía de rate limit

    if failures:
        print(f"\nFALLARON {len(failures)}: {failures}")
        sys.exit(1)
    print("\nlisto ✓")


if __name__ == "__main__":
    main()
