#!/usr/bin/env python3
"""Exporta los prompts en formato copy-paste para generación MANUAL en la app
de Gemini/ChatGPT (flujo del usuario tras agotarse la cuota de API).

Salida: prompts/gemini_manual/tanda_{N}.md — cada asset con:
  - el nombre EXACTO de archivo con el que guardar el PNG
  - el prompt completo listo para pegar
  - nota de referencia de estilo (adjuntar el Fisura aprobado en personajes)

Uso: python3 scripts/export_gemini_prompts.py
"""

import json
from pathlib import Path

PIPELINE = Path(__file__).resolve().parent.parent
OUT_DIR = PIPELINE / "prompts" / "gemini_manual"

REFERENCE_NOTE = (
    "> **ADJUNTÁ la imagen de referencia** (`heroes/approved/fisura.png`) y "
    "empezá el prompt con: *\"Match EXACTLY the art style, outline weight, "
    "proportions and palette of the attached reference character from the same "
    "game.\"* Así todos salen del mismo estudio.\n"
)


def main() -> None:
    prompts = json.loads((PIPELINE / "prompts" / "prompts.json").read_text())
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    by_tanda: dict[int, list[dict]] = {}
    for entry in prompts:
        by_tanda.setdefault(entry.get("tanda", 0), []).append(entry)

    for tanda, entries in sorted(by_tanda.items()):
        lines = [
            f"# Tanda {tanda} — {len(entries)} assets\n",
            "Guardá cada imagen como PNG con el nombre indicado, en formato "
            "cuadrado y fondo blanco liso, y soltala en `Tools/asset-pipeline/dropbox/`. "
            "Después corré `python3 scripts/process_dropbox.py` (o pedile a Claude).\n",
        ]
        has_characters = any(e.get("category") in ("character", "special") for e in entries)
        if has_characters:
            lines.append(REFERENCE_NOTE)

        for entry in entries:
            lines.append(f"\n---\n\n## `{entry['assetKey']}.png`\n")
            lines.append("```")
            lines.append(entry.get("prompt") or entry.get("subject", ""))
            lines.append("```")

        out_file = OUT_DIR / f"tanda_{tanda}.md"
        out_file.write_text("\n".join(lines))
        print(f"tanda {tanda}: {len(entries)} prompts → {out_file.relative_to(PIPELINE)}")


if __name__ == "__main__":
    main()
