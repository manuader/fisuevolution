#!/usr/bin/env python3
"""Generación batch de assets con Gemini Pro (app web) manejada por un agente.

Recorre los prompts secuenciales de `prompts/gemini_pro/NN_<assetKey>.md` y,
por cada asset pendiente, lanza UNA corrida de `claude -p` (agente con las
tools de Chrome `claude-in-chrome`) que:

  1. abre gemini.google.com en un chat nuevo con generación de imágenes,
  2. adjunta la referencia `heroes/approved/fisura.png` si el .md la pide,
  3. pega el prompt tal cual está en el .md,
  4. descarga la imagen generada y la guarda como `dropbox/<assetKey>.png`.

El runner NO confía en el agente: solo marca `estado: hecho` (en el .md y en
`00_INDICE.md`) si `dropbox/<assetKey>.png` existe al terminar la corrida.
Reanudable: saltea todo lo que ya está hecho / en dropbox / en el manifest.

Requisitos: `claude` CLI en PATH, Chrome abierto con la extensión de Claude
conectada y sesión de Google/Gemini iniciada. Solo stdlib.

Uso:
    python3 scripts/gemini_agent_run.py --dry-run          # ver qué haría
    python3 scripts/gemini_agent_run.py --limit 5          # generar 5
    python3 scripts/gemini_agent_run.py --only kiosco      # un asset puntual
    python3 scripts/gemini_agent_run.py --process          # al final, corre
                                                           # process_dropbox.py
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

PIPELINE = Path(__file__).resolve().parent.parent
PROMPTS_DIR = PIPELINE / "prompts" / "gemini_pro"
DROPBOX = PIPELINE / "dropbox"
PROCESSED = DROPBOX / "procesadas"
REFERENCE = PIPELINE / "heroes" / "approved" / "fisura.png"
MANIFEST = PIPELINE.parent.parent / "FisuEvolution" / "Resources" / "Data" / "assets_manifest.json"
INDICE = PROMPTS_DIR / "00_INDICE.md"

FILE_RE = re.compile(r"^(\d{2})_(.+)\.md$")
ESTADO_RE = re.compile(r"^- \*\*estado\*\*: (\w+)$", re.MULTILINE)


def parse_md(path: Path) -> dict:
    """Extrae nn, assetKey, estado, si lleva referencia, y el texto del prompt."""
    m = FILE_RE.match(path.name)
    text = path.read_text()
    estado = ESTADO_RE.search(text)
    _, _, prompt = text.partition("## Prompt")
    return {
        "path": path,
        "nn": m.group(1),
        "key": m.group(2),
        "estado": estado.group(1) if estado else "pendiente",
        "referencia": "**referencia**" in text,
        "prompt": prompt.strip(),
    }


def manifest_keys() -> set[str]:
    if not MANIFEST.exists():
        return set()
    data = json.loads(MANIFEST.read_text())
    keys: set[str] = set()
    for section in ("characters", "backgrounds", "ui"):
        keys.update(data.get(section, {}))
    return keys


def already_done(asset: dict, in_manifest: set[str]) -> str | None:
    """Devuelve el motivo de salteo, o None si está pendiente de verdad."""
    if asset["estado"] == "hecho":
        return "estado: hecho"
    png = f"{asset['key']}.png"
    if (DROPBOX / png).exists():
        return "ya está en dropbox/"
    if (PROCESSED / png).exists():
        return "ya está en dropbox/procesadas/"
    if asset["key"] in in_manifest:
        return "ya está en assets_manifest.json"
    return None


def agent_prompt(asset: dict) -> str:
    """Arma la tarea que se le pasa a `claude -p` para UN asset."""
    dest = DROPBOX / f"{asset['key']}.png"
    ref_step = (
        f"2. Adjuntá al chat el archivo de referencia `{REFERENCE}` "
        "(usá la tool de subir archivos de la extensión de Chrome).\n"
        if asset["referencia"]
        else "2. Este asset NO lleva imagen de referencia: no adjuntes nada.\n"
    )
    return f"""Sos un agente de generación de assets. Tenés las tools de Chrome
(claude-in-chrome) para manejar el navegador del usuario. Tarea: generar UNA
imagen con la app web de Gemini y guardarla en el disco. No hagas nada más.

1. Abrí https://gemini.google.com en una pestaña nueva y empezá un chat nuevo.
   Asegurate de usar el modo de generación de imágenes de Gemini Pro
   (herramienta "Crear imágenes" / modelo con imágenes).
{ref_step}3. Pegá EXACTAMENTE este prompt (sin agregar ni sacar nada) y envialo:

---PROMPT---
{asset['prompt']}
---FIN PROMPT---

4. Esperá a que la imagen termine de generarse (puede tardar ~1 minuto).
5. Descargá la imagen generada en su resolución máxima.
6. Con Bash, mové el archivo descargado (queda en ~/Downloads, es el más
   reciente) a exactamente esta ruta: `{dest}`
7. Verificá con `ls` que `{dest}` existe y pesa más de 100 KB. Si Gemini se
   negó, dio error o la descarga falló, reintentá UNA vez desde el paso 3.
   Si vuelve a fallar, NO crees el archivo y terminá reportando el error.

Éxito = el archivo `{dest}` existe. No edites ningún otro archivo del repo."""


def mark_done(asset: dict) -> None:
    """Marca estado: hecho en el .md del asset y actualiza 00_INDICE.md."""
    md = asset["path"]
    md.write_text(md.read_text().replace("- **estado**: pendiente", "- **estado**: hecho", 1))

    if INDICE.exists():
        lines = INDICE.read_text().splitlines()
        row_prefix = f"| {asset['nn']} | {asset['key']} |"
        for i, line in enumerate(lines):
            if line.startswith(row_prefix):
                lines[i] = line.replace("| pendiente |", "| hecho |")
        done = sum(1 for l in lines if l.startswith("| ") and l.endswith(" hecho |"))
        total = sum(1 for l in lines if re.match(r"^\| \d{2} \|", l))
        for i, line in enumerate(lines):
            if line.startswith("**Progreso**:"):
                lines[i] = f"**Progreso**: {done}/{total} hechos, {total - done} pendientes."
        INDICE.write_text("\n".join(lines) + "\n")


def run_agent(asset: dict, args: argparse.Namespace) -> bool:
    cmd = [args.claude_bin, "-p", agent_prompt(asset), "--chrome"]
    if args.yolo:
        cmd.append("--dangerously-skip-permissions")
    else:
        cmd += [
            "--permission-mode", "acceptEdits",
            "--allowedTools", "mcp__claude-in-chrome,ToolSearch,Read,Bash",
        ]
    try:
        result = subprocess.run(cmd, timeout=args.timeout)
    except subprocess.TimeoutExpired:
        print(f"  [TIMEOUT] {asset['key']} superó {args.timeout}s")
        return False
    except FileNotFoundError:
        raise SystemExit(f"[ERROR] no se encontró `{args.claude_bin}` en PATH")
    if result.returncode != 0:
        print(f"  [AGENTE FALLÓ] {asset['key']} (exit {result.returncode})")
    return (DROPBOX / f"{asset['key']}.png").exists()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--limit", type=int, default=0,
                        help="máximo de assets a generar en esta corrida (0 = todos)")
    parser.add_argument("--only", help="generar solo este assetKey")
    parser.add_argument("--dry-run", action="store_true",
                        help="listar qué se generaría, sin lanzar el agente")
    parser.add_argument("--timeout", type=int, default=600,
                        help="segundos máximos por asset (default 600)")
    parser.add_argument("--pause", type=int, default=5,
                        help="pausa en segundos entre assets (default 5)")
    parser.add_argument("--claude-bin", default="claude",
                        help="binario del CLI de claude (default: claude)")
    parser.add_argument("--yolo", action="store_true",
                        help="pasar --dangerously-skip-permissions al agente")
    parser.add_argument("--process", action="store_true",
                        help="al terminar, correr process_dropbox.py con el venv")
    args = parser.parse_args()

    files = sorted(p for p in PROMPTS_DIR.glob("[0-9][0-9]_*.md")
                   if FILE_RE.match(p.name) and p.name != INDICE.name)
    if not files:
        raise SystemExit(f"[ERROR] no hay prompts en {PROMPTS_DIR}")
    DROPBOX.mkdir(exist_ok=True)

    in_manifest = manifest_keys()
    queue = []
    for path in files:
        asset = parse_md(path)
        if args.only and asset["key"] != args.only:
            continue
        reason = already_done(asset, in_manifest)
        if reason:
            print(f"  [SKIP] {asset['nn']} {asset['key']} ({reason})")
            if asset["estado"] != "hecho":
                mark_done(asset)  # sincroniza el estado si el png ya existe
            continue
        queue.append(asset)

    if args.limit > 0:
        queue = queue[: args.limit]

    if not queue:
        print("Nada pendiente para generar.")
    else:
        print(f"\n{len(queue)} assets a generar: "
              + ", ".join(f"{a['nn']}_{a['key']}" for a in queue) + "\n")

    if args.dry_run:
        return

    ok, failed = [], []
    for i, asset in enumerate(queue):
        print(f"[{i + 1}/{len(queue)}] Generando {asset['nn']}_{asset['key']}…")
        if run_agent(asset, args):
            mark_done(asset)
            ok.append(asset["key"])
            print(f"  ✓ {asset['key']} → dropbox/{asset['key']}.png (estado: hecho)")
        else:
            failed.append(asset["key"])
            print(f"  ✗ {asset['key']} sin resultado (queda pendiente)")
        if i < len(queue) - 1:
            time.sleep(args.pause)

    print(f"\nResumen: {len(ok)} generados, {len(failed)} fallidos.")
    if failed:
        print(f"  fallidos: {failed} — reintentá con --only <key> o corré de nuevo")

    if args.process and ok:
        venv_python = PIPELINE / ".venv" / "bin" / "python"
        py = str(venv_python) if venv_python.exists() else sys.executable
        print("\nCorriendo process_dropbox.py…")
        subprocess.run([py, str(PIPELINE / "scripts" / "process_dropbox.py")], check=False)
    elif ok:
        print("\nSiguiente paso: revisar dropbox/ y correr "
              ".venv/bin/python scripts/process_dropbox.py")


if __name__ == "__main__":
    main()
