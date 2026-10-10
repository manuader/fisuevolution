#!/usr/bin/env python3
"""Lleva al juego lo que el dueno dejo listo en el Estudio — en una rama aparte.

Lo que entra:

- **Imagenes** en estado «listo» con un PNG final guardado en el Estudio que
  todavia no se aplico (o que cambio desde la ultima vez). Van a su atlas en @2x
  y @3x como `aplicar_revision` / `aplicar_limpias` (`export_atlas`); un fondo va
  como JPEG (`export_background`). Igual que esos dos scripts, se anotan en la
  lista de elegidos a mano de `recut_assets.py`, para que un recut futuro no se
  las lleve puestas; las que quedaron por conectividad sin tocar nada salen de
  esa lista, porque el recut da lo mismo.
- **Videos** en «va» que se procesaron en el Estudio: el `.mov` va a su carpeta
  (o a su pack ODR) y entra a `loops_manifest.json`, como `video_assets.py`.

Nunca toca el checkout desde donde corre el Estudio: crea un worktree con la rama
`v2/estudio-aplicar-<fecha>` desde el HEAD actual, aplica ahi, corre los tests del
pipeline y, si pasan, commitea. No pushea ni mergea: la rama se integra por el
flujo de relevos.

    <venv>/bin/python Tools/asset-studio/aplicar.py --dry-run    # que haria
    <venv>/bin/python Tools/asset-studio/aplicar.py --en-rama    # hacerlo

`--ejecutar PLAN.json` es la parte de adentro: aplica un plan a ESTE checkout.
La usa `--en-rama` desde el worktree nuevo; a mano no hace falta.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

import rutas
from rutas import REPO
from registro import Registro, huella

from process_dropbox import destination  # noqa: E402

COMANDO_TESTS = ["-m", "unittest", "discover", "-s", "Tools/asset-pipeline/tests", "-q"]


def _destino(entrada: dict) -> tuple[str, str] | None:
    """(atlas, sprite) donde va la imagen, o None si el juego no la conoce."""
    import catalogo

    if entrada.get("sprite") and entrada.get("atlas"):
        atlas = entrada["atlas"]
        return (atlas if atlas == "Backgrounds" else f"{atlas}.atlas"), entrada["sprite"]
    prompt = catalogo.prompts().get(entrada["id"])
    if prompt and prompt.get("category") != "background":
        atlas, sprite, _ = destination(prompt)
        return atlas, sprite
    return None


def plan(registro: Registro) -> dict:
    """Que se aplicaria hoy, y que se saltea y por que."""
    imagenes, videos, salteadas = [], [], []
    for clave, entrada in sorted(registro.assets.items()):
        final = entrada["archivos"].get("final")
        if entrada["imagen"]["estado"] == "listo" and final:
            ya = (entrada["aplicado"].get("imagen") or {}).get("huella")
            hoy = huella(final)
            destino = _destino(entrada)
            if hoy is None:
                salteadas.append({"id": clave, "motivo": "falta el PNG final guardado"})
            elif ya == hoy:
                pass
            elif destino is None:
                salteadas.append({"id": clave, "motivo": "el juego no lo conoce todavía: falta su entrada "
                                                         "en prompts.json (y en skins.json si es una skin)"})
            else:
                marcas = entrada.get("marcas") or {}
                imagenes.append({
                    "id": clave, "final": final, "atlas": destino[0], "sprite": destino[1],
                    "categoria": entrada.get("categoria") or "character",
                    "metodo": (entrada.get("recorte") or {}).get("metodo"),
                    "tocada": bool(marcas.get("rojas") or marcas.get("trazos")),
                    "en_prompts": bool(entrada.get("en_prompts")),
                })
        video = entrada.get("video")
        if video and video.get("estado") == "va" and video.get("mov_estudio"):
            ya = (entrada["aplicado"].get("video") or {}).get("huella")
            hoy = huella(video["mov_estudio"])
            if hoy and ya != hoy:
                videos.append({"id": clave, "video": {k: video[k] for k in ("kind", "id_juego", "archivo_mov")},
                               "mov": video["mov_estudio"], "opciones": video.get("procesado") or {}})
            elif hoy is None:
                salteadas.append({"id": clave, "motivo": "falta el video procesado"})
    return {"imagenes": imagenes, "videos": videos, "salteadas": salteadas}


def ejecutar(plan_: dict, dry_run: bool = False) -> list[str]:
    """Aplica el plan a ESTE checkout. Devuelve las lineas del informe."""
    from PIL import Image

    from aplicar_revision import elegidos_a_mano, escribir_elegidos_a_mano
    from process_dropbox import export_atlas, export_background
    import video

    informe = []
    antes = elegidos_a_mano()
    ahora = set(antes)
    for item in plan_["imagenes"]:
        if not dry_run:
            with Image.open(item["final"]) as imagen:
                imagen = imagen.convert("RGBA")
                if item["atlas"] == "Backgrounds":
                    export_background(imagen, item["sprite"])
                else:
                    export_atlas(imagen, {"assetKey": item["id"], "category": item["categoria"]},
                                 item["atlas"], item["sprite"])
        informe.append(f"  ✓ {item['id']} → {item['atlas']}/{item['sprite']}")
        if item["en_prompts"] and item["atlas"] != "Backgrounds":
            if item["metodo"] == "conectividad" and not item["tocada"]:
                ahora.discard(item["id"])
            elif not item["id"].endswith(("__oro", "__diamante")):
                ahora.add(item["id"])
    if ahora != antes:
        if not dry_run:
            escribir_elegidos_a_mano(ahora)
        informe.append(f"elegidos a mano en recut_assets.py: {len(antes)} → {len(ahora)}")
    for item in plan_["videos"]:
        if not dry_run:
            video.instalar(item["video"], Path(item["mov"]), item["opciones"])
        informe.append(f"  ✓ {item['id']} → {item['video']['archivo_mov']}")
    return informe


def _git(*args: str, cwd: Path) -> str:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True).stdout.strip()


def en_rama(registro: Registro, avisar=print) -> dict:
    """Worktree + rama nuevos, aplicar, tests, commit. Marca lo aplicado en el registro."""
    plan_ = plan(registro)
    if not plan_["imagenes"] and not plan_["videos"]:
        return {"ok": False, "mensaje": "No hay nada listo para aplicar.", "plan": plan_}
    fecha = datetime.now().strftime("%Y%m%d-%H%M%S")
    rama = f"v2/estudio-aplicar-{fecha}"
    comun = Path(_git("rev-parse", "--path-format=absolute", "--git-common-dir", cwd=REPO))
    destino = comun.parent / ".claude" / "worktrees.nosync" / f"estudio-aplicar-{fecha}"
    base = _git("rev-parse", "--abbrev-ref", "HEAD", cwd=REPO)
    avisar(f"Creando la rama {rama} desde {base}…")
    _git("worktree", "add", "-b", rama, str(destino), "HEAD", cwd=REPO)
    if not (destino / "Tools" / "asset-studio" / "aplicar.py").exists():
        return {"ok": False, "rama": rama, "carpeta": str(destino),
                "mensaje": "La rama no tiene el Estudio commiteado: no hay con qué aplicar."}

    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(plan_, f)
    avisar(f"Aplicando {len(plan_['imagenes'])} imágenes y {len(plan_['videos'])} videos…")
    adentro = subprocess.run([sys.executable, "Tools/asset-studio/aplicar.py", "--ejecutar", f.name],
                             cwd=destino, capture_output=True, text=True)
    Path(f.name).unlink(missing_ok=True)
    if adentro.returncode:
        return {"ok": False, "rama": rama, "carpeta": str(destino),
                "mensaje": "Falló al aplicar; la rama quedó sin commit para mirarla.",
                "log": adentro.stdout + adentro.stderr}

    avisar("Corriendo los tests del pipeline (un minuto)…")
    tests = subprocess.run([sys.executable, *COMANDO_TESTS], cwd=destino, capture_output=True, text=True)
    if tests.returncode:
        return {"ok": False, "rama": rama, "carpeta": str(destino),
                "mensaje": "Los tests del pipeline fallaron: la rama quedó sin commit para mirarla.",
                "log": tests.stdout[-4000:] + tests.stderr[-4000:]}

    _git("add", "-A", "FisuEvolution/Resources", "Tools/asset-pipeline/scripts/recut_assets.py", cwd=destino)
    if not _git("status", "--porcelain", "--untracked-files=no", cwd=destino):
        return {"ok": False, "rama": rama, "carpeta": str(destino),
                "mensaje": "Aplicado, pero no cambió ningún archivo del juego."}
    titulo = (f"arte(estudio): lo que el dueño dejó listo — {len(plan_['imagenes'])} imágenes, "
              f"{len(plan_['videos'])} videos")
    cuerpo = "\n".join([*(f"- {i['id']} ({i['metodo']})" for i in plan_["imagenes"]),
                        *(f"- {v['id']} (video)" for v in plan_["videos"])])
    _git("commit", "-q", "-m", titulo, "-m", cuerpo, cwd=destino)
    sha = _git("rev-parse", "--short", "HEAD", cwd=destino)
    registro.marcar_aplicado([i["id"] for i in plan_["imagenes"]], [v["id"] for v in plan_["videos"]], rama)
    return {"ok": True, "rama": rama, "carpeta": str(destino), "commit": sha, "plan": plan_,
            "mensaje": f"Listo: commit {sha} en la rama {rama}. Se integra por el flujo de relevos.",
            "log": adentro.stdout}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    grupo = parser.add_mutually_exclusive_group(required=True)
    grupo.add_argument("--dry-run", action="store_true", help="decir que se aplicaria, sin tocar nada")
    grupo.add_argument("--en-rama", action="store_true", help="aplicar en una rama y worktree nuevos")
    grupo.add_argument("--ejecutar", type=Path, metavar="PLAN.json", help="aplicar un plan a este checkout")
    args = parser.parse_args()

    if args.ejecutar:
        for linea in ejecutar(json.loads(args.ejecutar.read_text())):
            print(linea)
        return 0
    registro = Registro()
    if args.dry_run:
        plan_ = plan(registro)
        print(f"se aplicarian: {len(plan_['imagenes'])} imagenes, {len(plan_['videos'])} videos")
        for linea in ejecutar(plan_, dry_run=True):
            print(linea)
        for s in plan_["salteadas"]:
            print(f"  ✗ {s['id']}: {s['motivo']}")
        return 0
    resultado = en_rama(registro)
    print(resultado["mensaje"])
    if resultado.get("log") and not resultado["ok"]:
        print(resultado["log"])
    return 0 if resultado["ok"] else 1


if __name__ == "__main__":
    print(f"datos: {rutas.datos()['base']}", file=sys.stderr)
    raise SystemExit(main())
