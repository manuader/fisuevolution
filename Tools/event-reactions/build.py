#!/usr/bin/env python3
"""Convierte los juicios en la tabla que lee el juego, y el reporte para revisarla.

Entrada:  state/inputs.jsonl     (de extract.py)
          state/decisions.jsonl  ({event, type, emote, confidence, why?} por línea)
Salida:   FisuEvolution/Resources/Data/event_reactions.json
          state/review.md        (lo más dudoso primero)

El umbral es la decisión de diseño que importa: con confianza < 0,6 la celda
queda en `indiferente`. La duda cae del lado del silencio, porque un personaje
festejando algo sin sentido rompe el chiste y uno que sigue caminando es el
statu quo (Docs/PROMPT-reacciones-de-campo.md §3).

`--check` no escribe nada: falla si el contenido cambió desde la última
extracción (un evento o tier nuevo), si falta un juicio, o si el JSON commiteado
no es exactamente el que salen de los juicios. Es el anti-drift para CI.

Uso: python3 Tools/event-reactions/build.py [--check]
"""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract import INPUTS, ROOT, STATE, build_inputs  # noqa: E402

DECISIONS = STATE / "decisions.jsonl"
REVIEW = STATE / "review.md"
OUTPUT = ROOT / "FisuEvolution" / "Resources" / "Data" / "event_reactions.json"

EMOTES = ["festeja", "se_agarra_la_cabeza", "se_encoge_de_hombros",
          "sonrisa_torcida", "se_esconde", "indiferente"]
THRESHOLD = 0.6
# Fracción máxima de tipos que reaccionan a un mismo evento. Con ~10 personajes
# en el campo, 0,4 son cuatro: el tope en runtime es el mismo.
MAX_REACTING = 0.4


def load_jsonl(path):
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def fail(msg):
    print(f"✘ {msg}", file=sys.stderr)
    sys.exit(1)


def judge(inputs, decisions):
    """Devuelve (tabla, filas para el reporte). Falla ante cualquier hueco."""
    by_pair = {}
    for d in decisions:
        pair = (d["event"], d["type"])
        if pair in by_pair:
            fail(f"juicio duplicado para {pair}")
        if d["emote"] not in EMOTES:
            fail(f"emote desconocido {d['emote']!r} en {pair}")
        if not 0 <= d["confidence"] <= 1:
            fail(f"confianza fuera de [0, 1] en {pair}")
        by_pair[pair] = d

    wanted = [(r["event"], r["type"]) for r in inputs]
    missing = [p for p in wanted if p not in by_pair]
    if missing:
        fail(f"{len(missing)} preguntas sin juicio, p. ej. {missing[:3]}")
    extra = set(by_pair) - set(wanted)
    if extra:
        fail(f"{len(extra)} juicios de preguntas que ya no existen, p. ej. {sorted(extra)[:3]}")

    table = defaultdict(dict)
    rows = []
    for r in inputs:
        d = by_pair[(r["event"], r["type"])]
        applied = d["emote"] if d["confidence"] >= THRESHOLD else "indiferente"
        table[r["event"]][r["type"]] = applied
        rows.append({**r, "propuesto": d["emote"], "confianza": d["confidence"],
                     "aplicado": applied, "por_que": d.get("why", "")})
    return table, rows


def render_json(table):
    doc = {"schemaVersion": 1,
           "reactions": {e: dict(sorted(t.items())) for e, t in sorted(table.items())}}
    return json.dumps(doc, ensure_ascii=False, indent=2) + "\n"


def reacting_share(table):
    return {e: sum(v != "indiferente" for v in t.values()) / len(t) for e, t in table.items()}


def render_review(rows, table):
    out = ["# Reacciones de campo — revisión", "",
           f"Umbral: confianza < {THRESHOLD} → `indiferente`. "
           "Corregí `state/decisions.jsonl` y volvé a correr `build.py`.", "",
           "## Cuántos reaccionan por evento", "",
           "| evento | reaccionan | emotes |", "|---|---|---|"]
    share = reacting_share(table)
    for event, t in table.items():
        counts = Counter(v for v in t.values() if v != "indiferente")
        detail = ", ".join(f"{k} {n}" for k, n in counts.most_common())
        out.append(f"| {event} | {share[event]:.0%} | {detail} |")

    out += ["", "## Todas, lo más dudoso primero", "",
            "| conf | evento | personaje | propuesto | queda | por qué |", "|---|---|---|---|---|---|"]
    for r in sorted(rows, key=lambda r: (r["confianza"], r["event"], r["type"])):
        mark = "" if r["propuesto"] == r["aplicado"] else " ⬇"
        out.append(f"| {r['confianza']:.2f} | {r['event']} | {r['personaje']} | "
                   f"{r['propuesto']} | {r['aplicado']}{mark} | {r['por_que']} |")
    return "\n".join(out) + "\n"


def main():
    check = "--check" in sys.argv[1:]
    fresh = build_inputs()
    if not INPUTS.exists() or INPUTS.read_text().splitlines() != fresh:
        fail("el contenido cambió desde la última extracción: correr extract.py y juzgar lo nuevo")
    if not DECISIONS.exists():
        fail("falta state/decisions.jsonl")

    inputs = [json.loads(line) for line in fresh]
    table, rows = judge(inputs, load_jsonl(DECISIONS))
    loud = {e: s for e, s in reacting_share(table).items() if s > MAX_REACTING}
    if loud:
        fail(f"tabla habladora (> {MAX_REACTING:.0%} reacciona): {loud}")

    rendered = render_json(table)
    if check:
        if not OUTPUT.exists() or OUTPUT.read_text() != rendered:
            fail(f"{OUTPUT.relative_to(ROOT)} no corresponde a los juicios: correr build.py")
        print(f"✔ tabla al día ({len(rows)} celdas)")
        return

    OUTPUT.write_text(rendered)
    REVIEW.write_text(render_review(rows, table))
    reacting = sum(r["aplicado"] != "indiferente" for r in rows)
    lowered = sum(r["aplicado"] != r["propuesto"] for r in rows)
    print(f"{len(rows)} celdas · {reacting} reaccionan · {lowered} bajadas a indiferente por el umbral")
    print(f"→ {OUTPUT.relative_to(ROOT)}\n→ {REVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
