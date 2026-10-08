"""AdMob del lado del proyecto: qué falta crear y cómo llevar los IDs al código.

AdMob no deja crear unidades por API (la API pública sólo lista), así que la
creación es visual —el playbook está en la skill— y este módulo hace las dos
puntas que sí son código: decir qué falta y escribir los IDs en los archivos
del juego sin tocar nada más.
"""

from __future__ import annotations

import json
import re
from pathlib import Path


def plan(config: dict) -> list[dict]:
    """Las unidades de la config que todavía no tienen ID: las que hay que crear."""
    admob = config["admob"]
    pending = []
    for unit in admob["units"]:
        if unit["id"] is None:
            entry = {"name": unit["name"], "format": unit["format"], "key": unit["key"]}
            if unit["format"] == "rewarded":
                entry["reward"] = admob["rewardDefaults"]
            pending.append(entry)
    return pending


def renames(config: dict) -> list[tuple[str, str]]:
    return [(u["renameFrom"], u["name"]) for u in config["admob"]["units"] if u.get("renameFrom")]


def set_unit_id(config_path: Path, key: str, unit_id: str) -> None:
    """Anota en la config el ID que devolvió AdMob al crear la unidad."""
    config = json.loads(config_path.read_text(encoding="utf-8"))
    unit = next(u for u in config["admob"]["units"] if u["key"] == key)
    unit["id"] = unit_id
    config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sync_code(config: dict, repo: Path, dry_run: bool) -> list[str]:
    """Copia los IDs de la config a los archivos del juego. Devuelve los cambios.

    Toca sólo `adUnitIDs.<clave>` y, en `ads.json`, `switches.appOpen`: el
    setup lo prende recién cuando la unidad de app open existe (antes caería al
    ID de prueba)."""
    changes: list[str] = []
    ids = {u["key"]: u["id"] for u in config["admob"]["units"]}
    for relative in config["codeBindings"]["adUnitIdFiles"]:
        path = repo / relative
        text = path.read_text(encoding="utf-8")
        current = json.loads(text)
        # Reemplazo de texto dentro de cada bloque, no `json.dump`: el archivo
        # conserva su formato y el diff muestra sólo las líneas que cambiaron.
        for key, unit_id in ids.items():
            if key not in current["adUnitIDs"]:
                raise KeyError(f"{relative}: no tiene adUnitIDs.{key}; agregarla es tarea del código")
            if current["adUnitIDs"][key] != unit_id:
                changes.append(f"{relative}: adUnitIDs.{key} {current['adUnitIDs'][key]!r} → {unit_id!r}")
                text = _replace_in_block(text, "adUnitIDs", key, json.dumps(unit_id))
        switches = current.get("switches")
        if switches is not None and ids.get("appOpen") and switches.get("appOpen") is False:
            changes.append(f"{relative}: switches.appOpen false → true (la unidad ya existe)")
            text = _replace_in_block(text, "switches", "appOpen", "true")
        json.loads(text)  # nunca se escribe un JSON roto
        if not dry_run:
            path.write_text(text, encoding="utf-8")
    return changes


def _replace_in_block(text: str, block: str, key: str, value: str) -> str:
    start = text.index(f'"{block}"')
    end = text.index("}", start)
    pattern = re.compile(rf'("{re.escape(key)}"\s*:\s*)(null|true|false|"[^"]*")')
    inner, count = pattern.subn(lambda m: m.group(1) + value, text[start:end], count=1)
    if count != 1:
        raise ValueError(f'no encontré "{key}" dentro de "{block}"')
    return text[:start] + inner + text[end:]
