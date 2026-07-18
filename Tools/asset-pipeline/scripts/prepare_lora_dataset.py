#!/usr/bin/env python3
"""Prepara el dataset para entrenar el LoRA de estilo en Tensor.Art.

- Normaliza cada hero aprobado a 768x768 (compone alpha sobre blanco,
  encaja con padding, sin deformar).
- Escribe un caption .txt por imagen con el trigger `hoboevo_style` primero.
  Caption extra por imagen (opcional): heroes/captions.json
      { "hero_fisura_01.png": "scruffy street man holding a bottle" }

Output: lora/dataset/{nombre}.png + {nombre}.txt — eso es lo que se sube a
Tensor.Art (base SD 1.5, defaults, trigger word hoboevo_style). El .safetensors
descargado va a lora/hoboevo_style.safetensors (SIN watermark; nunca generar
imagenes finales en Tensor.Art free tier).

Uso:  python3 scripts/prepare_lora_dataset.py [--input heroes/approved] [--output lora/dataset]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _common import ROOT, load_config, read_json  # noqa: E402

BASE_CAPTION = (
    "2d flat vector cartoon character, big head small body, uniform thick "
    "black outline, flat colors, minimal cel shading, humorous expression, "
    "full body, white background"
)


def normalize(src, dst, size):
    from PIL import Image  # pip install pillow

    img = Image.open(src).convert("RGBA")
    # componer sobre blanco: el LoRA aprende mejor sin alpha
    canvas = Image.new("RGB", img.size, (255, 255, 255))
    canvas.paste(img, mask=img.split()[3])
    # encajar en cuadrado con padding blanco, sin deformar
    ratio = size / max(canvas.size)
    new_size = (max(1, round(canvas.width * ratio)), max(1, round(canvas.height * ratio)))
    canvas = canvas.resize(new_size, Image.LANCZOS)
    out = Image.new("RGB", (size, size), (255, 255, 255))
    out.paste(canvas, ((size - new_size[0]) // 2, (size - new_size[1]) // 2))
    out.save(dst, optimize=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", default=None, help="carpeta de heroes aprobados")
    parser.add_argument("--output", default=None, help="carpeta destino del dataset")
    parser.add_argument("--size", type=int, default=None, help="lado del cuadrado (default: config resolution)")
    args = parser.parse_args()

    config = load_config()
    trigger = config["generation"]["trigger"]
    size = args.size or config["generation"]["resolution"]
    in_dir = ROOT / (args.input or config["paths"]["heroes"])
    out_dir = ROOT / (args.output or config["paths"]["lora_dataset"])
    out_dir.mkdir(parents=True, exist_ok=True)

    images = sorted(
        p for p in in_dir.glob("*")
        if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")
    )
    if not images:
        raise SystemExit(
            f"[ERROR] No hay imagenes en {in_dir}.\n"
            "  [GATE HUMANO] Primero generar/aprobar los heroes (prompts/hero_prompts.txt)\n"
            "  y guardarlos en heroes/approved/. Ideal: 10-15 imagenes on-style."
        )
    if len(images) < 10:
        print(f"[AVISO] Solo {len(images)} imagenes; el doc recomienda 10-15 para el LoRA.")

    extra_captions = read_json(in_dir.parent / "captions.json", default={}) or {}

    for src in images:
        stem = src.stem
        normalize(src, out_dir / f"{stem}.png", size)
        extra = extra_captions.get(src.name, "").strip()
        caption = ", ".join(x for x in (trigger, BASE_CAPTION, extra) if x)
        (out_dir / f"{stem}.txt").write_text(caption + "\n", encoding="utf-8")
        print(f"  [OK] {stem}.png + {stem}.txt")

    print(f"\nDataset listo: {len(images)} pares en {out_dir.relative_to(ROOT)}")
    print("\n[GATE HUMANO] Entrenar en Tensor.Art (gratis, ~100 creditos/dia):")
    print("  1. tensor.art -> Train -> LoRA -> base: Stable Diffusion 1.5")
    print(f"  2. Subir TODO el contenido de {out_dir.relative_to(ROOT)} (png + txt)")
    print(f"  3. Trigger word: {trigger}  | resto de settings: defaults")
    print("  4. Descargar el .safetensors resultante a lora/hoboevo_style.safetensors")
    print("  5. Importarlo en Draw Things (Manage Models -> LoRA) y/o copiarlo a")
    print("     ComfyUI/models/loras/hoboevo_style.safetensors")
    print("  NUNCA generar imagenes finales en Tensor.Art (watermark en free tier).")


if __name__ == "__main__":
    main()
