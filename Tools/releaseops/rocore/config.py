"""La config declarativa (`Distribution/release/release.json`) y su validación.

`validate` contesta una sola pregunta: ¿lo que dice la config es cargable en las
tiendas y coincide con lo que el código va a pedir? No mira las plataformas
(eso es `asc diff` y `admob check`): corre sin red y sin credenciales, y por eso
sirve de oráculo en cualquier máquina.
"""

from __future__ import annotations

import json
import plistlib
import re
from dataclasses import dataclass, field
from pathlib import Path

#: Límites del formulario de App Store Connect (setup §1.4).
NAME_RANGE = (2, 30)
DESCRIPTION_MAX = 45
REFERENCE_NAME_MAX = 64
REVIEW_NOTE_MAX = 4000
IAP_TYPES = ("consumable", "nonConsumable")
AD_FORMATS = ("rewarded", "interstitial", "rewardedInterstitial", "appOpen", "banner", "native")
UNIT_ID = re.compile(r"^ca-app-pub-(\d{16})/(\d{10})$")
APP_ID = re.compile(r"^ca-app-pub-(\d{16})~(\d{10})$")


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    @property
    def ok(self) -> bool:
        return not self.errors

    def render(self) -> str:
        lines = [f"✗ {e}" for e in self.errors] + [f"⚠ {w}" for w in self.warnings]
        verdict = "VERDE" if self.ok else "ROJO"
        lines.append(f"{verdict}: {len(self.errors)} errores, {len(self.warnings)} avisos")
        return "\n".join(lines)


def load(path: Path) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def validate(config: dict, repo: Path) -> Report:
    report = Report()
    _validate_iaps(config, repo, report)
    _validate_admob(config, repo, report)
    return report


# ------------------------------------------------------------------- compras

def _validate_iaps(config: dict, repo: Path, report: Report) -> None:
    section = config["inAppPurchases"]
    prefix = section["productIdPrefix"]
    locales = config["app"]["locales"]
    seen: set[str] = set()
    for product in section["products"]:
        pid = product["productId"]
        where = pid.removeprefix(prefix)
        if pid in seen:
            report.error(f"{where}: productId repetido")
        seen.add(pid)
        if not pid.startswith(prefix):
            report.error(f"{where}: no empieza con {prefix}")
        if product["type"] not in IAP_TYPES:
            report.error(f"{where}: tipo {product['type']!r} (válidos: {IAP_TYPES})")
        if not re.fullmatch(r"\d+\.\d{2}", str(product["priceUSD"])):
            report.error(f"{where}: precio {product['priceUSD']!r} no es un precio en USD")
        if len(product["referenceName"]) > REFERENCE_NAME_MAX:
            report.error(f"{where}: Reference Name de {len(product['referenceName'])} > {REFERENCE_NAME_MAX}")
        note = product.get("reviewNote") or ""
        if len(note) > REVIEW_NOTE_MAX:
            report.error(f"{where}: nota de revisión de {len(note)} > {REVIEW_NOTE_MAX}")
        for locale in locales:
            text = product["localizations"].get(locale)
            if text is None:
                report.error(f"{where}: falta la localización {locale}")
                continue
            if not NAME_RANGE[0] <= len(text["name"]) <= NAME_RANGE[1]:
                report.error(f"{where} [{locale}]: nombre de {len(text['name'])} caracteres "
                             f"(van de {NAME_RANGE[0]} a {NAME_RANGE[1]})")
            if len(text["description"]) > DESCRIPTION_MAX:
                report.error(f"{where} [{locale}]: descripción de {len(text['description'])} > {DESCRIPTION_MAX}")
    _compare_with_code(config, repo, seen, report)


def _compare_with_code(config: dict, repo: Path, configured: set[str], report: Report) -> None:
    """El código pide productos por id: uno que falte en la config desaparece de
    la tienda sin error, y uno de la config que el código no pide es plata que
    nadie puede cobrar."""
    bindings = config["codeBindings"]
    code = json.loads((repo / bindings["products"]).read_text(encoding="utf-8"))
    in_code = {p["id"]: p["type"] for p in code["products"]}
    types = {p["productId"]: p["type"] for p in config["inAppPurchases"]["products"]}
    for pid, kind in in_code.items():
        if pid not in configured:
            report.error(f"el código pide {pid} y la config no lo tiene")
        elif types[pid] != kind:
            report.error(f"{pid}: el código dice {kind} y la config {types[pid]}")
    for pid in sorted(configured - in_code.keys()):
        since = next(p.get("since") for p in config["inAppPurchases"]["products"] if p["productId"] == pid)
        report.warn(f"{pid} está en la config ({since}) pero el código todavía no lo pide")


# -------------------------------------------------------------------- AdMob

def _validate_admob(config: dict, repo: Path, report: Report) -> None:
    admob = config["admob"]
    publisher = admob["publisherId"].removeprefix("pub-")
    match = APP_ID.match(admob["appId"])
    if not match or match.group(1) != publisher:
        report.error(f"appId {admob['appId']!r}: tiene que ser ca-app-pub-{publisher}~<10 dígitos>")
    keys: set[str] = set()
    for unit in admob["units"]:
        if unit["key"] in keys:
            report.error(f"unidad {unit['name']}: clave {unit['key']} repetida")
        keys.add(unit["key"])
        if unit["format"] not in AD_FORMATS:
            report.error(f"unidad {unit['name']}: formato {unit['format']!r}")
        if unit["id"] is None:
            report.warn(f"unidad {unit['name']} ({unit['key']}): falta crearla en AdMob")
            continue
        match = UNIT_ID.match(unit["id"])
        if not match or match.group(1) != publisher:
            report.error(f"unidad {unit['name']}: id {unit['id']!r} no es una unidad de pub-{publisher} "
                         "(las unidades llevan '/', el App ID '~')")
    for test_id in admob["testUnitIds"].values():
        if any(u["id"] == test_id for u in admob["units"]):
            report.error(f"un ID de prueba de Google quedó como unidad real: {test_id}")
    bindings = config["codeBindings"]
    for relative in bindings["adUnitIdFiles"]:
        ids = json.loads((repo / relative).read_text(encoding="utf-8"))["adUnitIDs"]
        for unit in admob["units"]:
            if unit["key"] not in ids:
                report.error(f"{relative}: falta la clave adUnitIDs.{unit['key']}")
            elif ids[unit["key"]] != unit["id"]:
                report.error(f"{relative}: adUnitIDs.{unit['key']} = {ids[unit['key']]!r}, "
                             f"la config dice {unit['id']!r} (corré `admob sync-code`)")
        for extra in ids.keys() - keys:
            report.error(f"{relative}: adUnitIDs.{extra} no está en la config")
    plist = plistlib.loads((repo / bindings["infoPlist"]).read_bytes())
    if plist.get("GADApplicationIdentifier") != admob["appId"]:
        report.error(f"Info.plist GADApplicationIdentifier = {plist.get('GADApplicationIdentifier')!r}, "
                     f"la config dice {admob['appId']!r}")
