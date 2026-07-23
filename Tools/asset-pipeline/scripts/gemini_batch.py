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
    is_scene = entry.get("category") == "background"
    preamble = STYLE_PREAMBLE_SCENE if is_scene else STYLE_PREAMBLE
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
    failures = []
    for index, entry in enumerate(selected, 1):
        out_path = out_dir / f"{entry['assetKey']}.png"
        if out_path.exists():
            print(f"[{index}/{len(selected)}] {entry['assetKey']} ya existe, salto")
            continue
        print(f"[{index}/{len(selected)}] {entry['assetKey']}…")
        if not generate_one(entry, references, key, out_path):
            failures.append(entry["assetKey"])
        time.sleep(2)  # cortesía de rate limit

    if failures:
        print(f"\nFALLARON {len(failures)}: {failures}")
        sys.exit(1)
    print("\nlisto ✓")


if __name__ == "__main__":
    main()
