#!/usr/bin/env python3
"""Extrae las 352 preguntas de la tabla de reacciones (tipo × evento).

Lee el contenido del juego —`tiers.json`, `events.json` y los textos de
`Localizable.xcstrings`— y escribe `state/inputs.jsonl`: una línea por par
(evento, tipo), en el orden de los archivos fuente. Es determinista: correrlo
dos veces sobre el mismo contenido da el mismo archivo byte a byte, y eso es lo
que `build.py --check` usa para detectar una tabla desfasada del contenido.

Sin dependencias fuera de la stdlib.

Uso: python3 Tools/event-reactions/extract.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "FisuEvolution" / "Resources"
STATE = Path(__file__).resolve().parent / "state"
INPUTS = STATE / "inputs.jsonl"


def _text(strings, key, lang):
    unit = strings.get(key, {}).get("localizations", {}).get(lang, {}).get("stringUnit", {})
    value = unit.get("value")
    if not value:
        raise SystemExit(f"falta el texto {lang} de {key} en Localizable.xcstrings")
    return value


def build_inputs():
    """Las líneas de `inputs.jsonl`, como strings JSON, en orden estable."""
    types = json.loads((RES / "Data" / "tiers.json").read_text())["types"]
    events = json.loads((RES / "Config" / "events.json").read_text())["events"]
    strings = json.loads((RES / "Localizable.xcstrings").read_text())["strings"]
    max_tier = max(t["tier"] for t in types)

    lines = []
    for event in events:
        flavor = event["flavorTextKey"]
        for t in types:
            row = {
                "event": event["id"],
                "type": t["id"],
                "personaje": _text(strings, f"tier.name.{t['id']}", "es"),
                "personaje_en": _text(strings, f"tier.name.{t['id']}", "en"),
                "escalon": f"tier {t['tier']} de {max_tier}, fase {t['phase']}",
                "evento_es": _text(strings, flavor, "es"),
                "evento_en": _text(strings, flavor, "en"),
                "es_buff": event["isBuff"],
                "efecto": event["effectType"],
            }
            lines.append(json.dumps(row, ensure_ascii=False, sort_keys=True))
    return lines


def main():
    lines = build_inputs()
    STATE.mkdir(exist_ok=True)
    INPUTS.write_text("\n".join(lines) + "\n")
    print(f"{len(lines)} preguntas → {INPUTS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
