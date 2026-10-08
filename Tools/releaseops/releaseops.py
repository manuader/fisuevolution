#!/usr/bin/env python3
"""releaseops — lo comercial del juego como código: compras y anuncios.

    python3 Tools/releaseops/releaseops.py validate
    python3 Tools/releaseops/releaseops.py asc status
    python3 Tools/releaseops/releaseops.py asc plan           # dry-run: qué cambiaría
    python3 Tools/releaseops/releaseops.py asc apply --yes    # aplica el plan
    python3 Tools/releaseops/releaseops.py asc diff           # exit 0 si ASC == config
    python3 Tools/releaseops/releaseops.py asc ready          # exit 0 si todo puede ir a revisión
    python3 Tools/releaseops/releaseops.py asc screenshot <producto> <png>
    python3 Tools/releaseops/releaseops.py admob plan         # unidades por crear
    python3 Tools/releaseops/releaseops.py admob set-id <clave> <ad-unit-id>
    python3 Tools/releaseops/releaseops.py admob sync-code [--dry-run]
    python3 Tools/releaseops/releaseops.py version bump [--build | --patch | --minor]

La fuente de verdad es `Distribution/release/release.json`. Nada borra recursos
ni cambia el precio de un producto publicado sin `--allow-price-change`. Los logs
van a `~/.releaseops/logs/` (sin secretos).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from rocore import admob, config as cfg  # noqa: E402

REPO = HERE.parents[1]
CONFIG = REPO / "Distribution" / "release" / "release.json"
LOGS = Path.home() / ".releaseops" / "logs"


def logger(name: str):
    LOGS.mkdir(parents=True, exist_ok=True)
    path = LOGS / f"{time.strftime('%Y%m%d-%H%M%S')}-{name}.jsonl"

    def log(entry: dict) -> None:
        entry = {"at": time.strftime("%Y-%m-%dT%H:%M:%S"), **entry}
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry, ensure_ascii=False) + "\n")
        mark = {"ok": "✓", "error": "✗", "salteada": "⏸"}.get(entry.get("result"), "·")
        print(f"  {mark} {entry.get('product', '')} {entry.get('action', '')}: "
              f"{entry.get('summary') or entry.get('error') or entry.get('why') or ''}")
    log.path = path
    return log


# ----------------------------------------------------------------- comandos

def cmd_validate(args) -> int:
    report = cfg.validate(cfg.load(args.config), args.repo)
    print(report.render())
    return 0 if report.ok else 1


def _asc_state(args):
    from rocore import asc
    config = cfg.load(args.config)
    client = asc.Client()
    return asc, config, client, asc.snapshot(client, config)


def cmd_asc_status(args) -> int:
    _, config, _, state = _asc_state(args)
    print(f"App: {state['app']['name']} ({state['app']['id']})")
    print(f"{'producto':<20} {'tipo':<15} {'estado':<28} {'USD':>6}  locales")
    for pid, p in sorted(state["products"].items()):
        locs = ", ".join(f"{k}:{(v['state'] or '?')[:12]}" for k, v in sorted(p["localizations"].items()))
        print(f"{pid.rsplit('.', 1)[-1]:<20} {p['type'] or '?':<15} {p['state'] or '?':<28} "
              f"{p['priceUSD'] or '—':>6}  {locs}")
    if args.json:
        Path(args.json).write_text(json.dumps(state, ensure_ascii=False, indent=2))
    return 0


def cmd_asc_plan(args, apply_it: bool = False) -> int:
    asc, config, client, state = _asc_state(args)
    actions, extra = asc.plan(config, state)
    if args.allow_price_change:
        for action in actions:
            if action.kind == "set-price":
                action.needs_approval = None
    for pid in extra:
        print(f"  ⚠ en App Store Connect pero no en la config (no se toca): {pid}")
    if not actions:
        print("Sin diferencias: App Store Connect coincide con la config.")
        return 0
    print(f"{len(actions)} acciones:")
    for action in actions:
        flag = f"  [pide aprobación: {action.needs_approval}]" if action.needs_approval else ""
        print(f"  · {action.product:<18} {action.kind:<17} {action.summary}{flag}")
    if not apply_it:
        print("Dry-run: no se cambió nada. `asc apply --yes` lo ejecuta.")
        return 1
    if not args.yes:
        print("Falta --yes para aplicar.")
        return 1
    log = logger("asc-apply")
    failed = asc.apply(client, config, state, actions, log)
    if any(a.kind == "patch-loc" for a in failed):
        # Un texto aprobado no se edita: Apple abre el borrador cuando se toca
        # el producto (p. ej. al sumar un idioma). Segunda pasada sobre él.
        state = asc.snapshot(client, config)
        retry = [a for a in asc.plan(config, state)[0] if a.kind == "patch-loc"]
        print(f"Segunda pasada: {len(retry)} textos sobre el borrador que abrió Apple")
        failed = [a for a in failed if a.kind != "patch-loc"] + asc.apply(client, config, state, retry, log)
    print(f"Log: {log.path}")
    # Verificación: el estado se vuelve a leer, no se confía en las respuestas.
    after, _ = asc.plan(config, asc.snapshot(client, config))
    print(f"Después de aplicar: {len(after)} diferencias pendientes ({len(failed)} acciones sin hacer).")
    return 0 if not after else 1


def cmd_asc_diff(args) -> int:
    asc, config, _, state = _asc_state(args)
    actions, _ = asc.plan(config, state)
    for action in actions:
        print(f"  · {action.product:<18} {action.kind:<17} {action.summary}")
    print("VERDE: App Store Connect == config" if not actions else f"ROJO: {len(actions)} diferencias")
    return 0 if not actions else 1


def cmd_asc_ready(args) -> int:
    asc, _, client, state = _asc_state(args)
    missing = asc.readiness(client, state)
    for line in missing:
        print(f"  ✗ {line}")
    print("VERDE: todo listo para ir a revisión con la versión" if not missing else f"ROJO: {len(missing)} pendientes")
    return 0 if not missing else 1


def cmd_asc_screenshot(args) -> int:
    asc, config, client, state = _asc_state(args)
    pid = config["inAppPurchases"]["productIdPrefix"] + args.product
    if pid not in state["products"]:
        print(f"✗ {pid} no existe en App Store Connect (corré `asc apply` primero)")
        return 1
    if args.dry_run:
        print(f"Dry-run: subiría {args.png} como captura de {args.product}")
        return 0
    shot = asc.upload_review_screenshot(client, state["products"][pid]["id"], args.png)
    logger("asc-screenshot")({"action": "screenshot", "product": args.product, "result": "ok", "summary": shot})
    return 0


def cmd_admob_plan(args) -> int:
    config = cfg.load(args.config)
    pending = admob.plan(config)
    for old, new in admob.renames(config):
        print(f"  ✎ renombrar «{old}» → «{new}» (cosmético; el ID no cambia)")
    if not pending:
        print("Todas las unidades de la config tienen ID.")
        return 0
    print(f"{len(pending)} unidades por crear en {config['admob']['appName']} ({config['admob']['appId']}):")
    for unit in pending:
        reward = f"  recompensa {unit['reward']['amount']} {unit['reward']['item']}" if "reward" in unit else ""
        print(f"  + {unit['name']:<12} {unit['format']:<14} → adUnitIDs.{unit['key']}{reward}")
    return 1


def cmd_admob_set_id(args) -> int:
    config = cfg.load(args.config)
    publisher = config["admob"]["publisherId"].removeprefix("pub-")
    if not re.fullmatch(rf"ca-app-pub-{publisher}/\d{{10}}", args.unit_id):
        print(f"✗ {args.unit_id!r} no es una unidad de pub-{publisher}")
        return 1
    clash = next((u for u in config["admob"]["units"] if u["id"] == args.unit_id and u["key"] != args.key), None)
    if clash:
        print(f"✗ ese ID ya es de la unidad {clash['name']}")
        return 1
    admob.set_unit_id(args.config, args.key, args.unit_id)
    print(f"✓ adUnitIDs.{args.key} = {args.unit_id} en la config (falta `admob sync-code`)")
    return 0


def cmd_admob_sync(args) -> int:
    changes = admob.sync_code(cfg.load(args.config), args.repo, args.dry_run)
    for change in changes:
        print(f"  {'·' if args.dry_run else '✓'} {change}")
    print("Sin cambios." if not changes else ("Dry-run." if args.dry_run else f"{len(changes)} cambios escritos."))
    return 0


def cmd_version_bump(args) -> int:
    path = args.repo / cfg.load(args.config)["codeBindings"]["projectYml"]
    text = path.read_text(encoding="utf-8")
    version = re.search(r'MARKETING_VERSION: "([\d.]+)"', text).group(1)
    build = int(re.search(r'CURRENT_PROJECT_VERSION: "(\d+)"', text).group(1))
    major, minor, patch = (list(map(int, version.split("."))) + [0, 0])[:3]
    if args.minor:
        version = f"{major}.{minor + 1}.0"
    elif args.patch:
        version = f"{major}.{minor}.{patch + 1}"
    text = re.sub(r'(MARKETING_VERSION: )"[\d.]+"', rf'\1"{version}"', text)
    text = re.sub(r'(CURRENT_PROJECT_VERSION: )"\d+"', rf'\1"{build + 1}"', text)
    print(f"{version} ({build + 1})" + ("  [dry-run]" if args.dry_run else ""))
    if not args.dry_run:
        path.write_text(text, encoding="utf-8")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--config", type=Path, default=CONFIG)
    parser.add_argument("--repo", type=Path, default=REPO)
    sub = parser.add_subparsers(dest="area", required=True)
    sub.add_parser("validate").set_defaults(run=cmd_validate)

    asc_p = sub.add_parser("asc").add_subparsers(dest="cmd", required=True)
    status = asc_p.add_parser("status")
    status.add_argument("--json", help="guarda la foto completa en este archivo")
    status.set_defaults(run=cmd_asc_status)
    for name, run in (("plan", cmd_asc_plan), ("apply", lambda a: cmd_asc_plan(a, True))):
        p = asc_p.add_parser(name)
        p.add_argument("--yes", action="store_true")
        p.add_argument("--allow-price-change", action="store_true")
        p.set_defaults(run=run)
    asc_p.add_parser("diff").set_defaults(run=cmd_asc_diff)
    asc_p.add_parser("ready").set_defaults(run=cmd_asc_ready)
    shot = asc_p.add_parser("screenshot")
    shot.add_argument("product", help="el sufijo del productId, p. ej. offer_bienvenida")
    shot.add_argument("png", type=Path)
    shot.add_argument("--dry-run", action="store_true")
    shot.set_defaults(run=cmd_asc_screenshot)

    ad = sub.add_parser("admob").add_subparsers(dest="cmd", required=True)
    ad.add_parser("plan").set_defaults(run=cmd_admob_plan)
    setid = ad.add_parser("set-id")
    setid.add_argument("key")
    setid.add_argument("unit_id")
    setid.set_defaults(run=cmd_admob_set_id)
    sync = ad.add_parser("sync-code")
    sync.add_argument("--dry-run", action="store_true")
    sync.set_defaults(run=cmd_admob_sync)

    ver = sub.add_parser("version").add_subparsers(dest="cmd", required=True)
    bump = ver.add_parser("bump")
    group = bump.add_mutually_exclusive_group()
    group.add_argument("--patch", action="store_true")
    group.add_argument("--minor", action="store_true")
    group.add_argument("--build", action="store_true", help="sólo el build number (default)")
    bump.add_argument("--dry-run", action="store_true")
    bump.set_defaults(run=cmd_version_bump)

    args = parser.parse_args()
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main())
