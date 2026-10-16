"""El plan de pisos por país de AdMob, sólo como receta.

AdMob no tiene API de grupos de mediación que sirva sin OAuth (V6), así que los
pisos se cargan a mano en la consola. Este módulo arma lo que se tipea: por
formato y por tier de país, un piso propuesto. No escribe nada, ni en AdMob ni en
`release.json`.

Entrada: las tiers de país (`player_value.json`, contrato C2 de la 2.1 F1) y, si
hay, el CSV que el dueño exporta a mano del informe de AdMob (V5): una fila por
COUNTRY × FORMAT × PLATFORM con `earnings` e `impressions`.
"""

from __future__ import annotations

import csv
import json
import math
from pathlib import Path

DEFAULT_FACTOR = 0.5
DEFAULT_MIN_IMPRESSIONS = 1000
TO_MEASURE = "a medir"

# AdMob exporta el país en alfa-2; las tiers van en alfa-3 (el storefront).
ALPHA2_TO_ALPHA3 = {
    "US": "USA", "CA": "CAN", "GB": "GBR", "AU": "AUS", "NZ": "NZL", "DE": "DEU", "CH": "CHE", "NO": "NOR",
    "SE": "SWE", "DK": "DNK", "NL": "NLD", "JP": "JPN", "KR": "KOR", "FR": "FRA", "ES": "ESP", "IT": "ITA",
    "PT": "PRT", "BE": "BEL", "AT": "AUT", "IE": "IRL", "FI": "FIN", "LU": "LUX", "IL": "ISR", "SG": "SGP",
    "AE": "ARE", "SA": "SAU", "HK": "HKG", "TW": "TWN", "MX": "MEX", "AR": "ARG", "BR": "BRA", "CL": "CHL",
    "CO": "COL", "PE": "PER", "UY": "URY", "EC": "ECU", "VE": "VEN", "BO": "BOL", "PY": "PRY", "CR": "CRI",
    "PA": "PAN", "GT": "GTM", "DO": "DOM", "PL": "POL", "TR": "TUR", "RU": "RUS", "UA": "UKR", "RO": "ROU",
    "IN": "IND", "ID": "IDN", "PH": "PHL", "TH": "THA", "VN": "VNM", "MY": "MYS", "EG": "EGY", "ZA": "ZAF",
    "NG": "NGA", "KE": "KEN", "PK": "PAK", "BD": "BGD",
}

FORMAT_ALIASES = {
    "interstitial": "interstitial", "rewarded": "rewarded", "rewardedvideo": "rewarded",
    "rewardedinterstitial": "rewardedInterstitial", "appopen": "appOpen", "banner": "banner",
}


class FloorsError(ValueError):
    """Entrada que no se puede planificar: el CLI la muestra sin traza."""


def normalize_format(raw: str) -> str:
    key = "".join(ch for ch in raw.lower() if ch.isalnum())
    return FORMAT_ALIASES.get(key, raw.strip())


def normalize_country(raw: str) -> str:
    code = raw.strip().upper()
    return ALPHA2_TO_ALPHA3.get(code, code) if len(code) == 2 else code


def load_tiers(path: Path) -> tuple[dict[str, int], int]:
    """`countryTier` y `defaultCountryTier` de player_value.json (C2).

    Acepta el archivo suelto o la sección `player_value` del envoltorio C3."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    data = data.get("sections", {}).get("player_value", data) if "sections" in data else data
    tiers = data.get("countryTier")
    if not isinstance(tiers, dict) or not tiers:
        raise FloorsError(f"{path}: no tiene countryTier")
    return {country: int(tier) for country, tier in tiers.items()}, int(data.get("defaultCountryTier", max(tiers.values())))


def _column(row: dict, *names: str) -> str | None:
    lowered = {key.strip().lower(): key for key in row}
    for name in names:
        if name in lowered:
            return lowered[name]
    return None


def _number(raw: str) -> float:
    return float(raw.strip().replace(",", "").replace("$", "") or 0)


def read_report(path: Path, platform: str | None = "iOS") -> dict[tuple[str, str], tuple[float, int]]:
    """El CSV de AdMob → (país alfa-3, formato) → (ganancias, impresiones), sumadas.

    Las ganancias van en la moneda de la cuenta (o en micros si la columna se llama
    `*_micros`): sólo importa que el eCPM salga en la misma unidad que el piso que se
    tipea en la consola."""
    with open(path, encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise FloorsError(f"{path}: el CSV está vacío")
    sample = rows[0]
    country, fmt = _column(sample, "country", "country_code"), _column(sample, "format", "ad_format")
    earnings = _column(sample, "earnings", "estimated_earnings", "estimated earnings")
    micros = _column(sample, "estimated_earnings_micros", "earnings_micros")
    impressions = _column(sample, "impressions")
    plat = _column(sample, "platform")
    missing = [n for n, c in (("COUNTRY", country), ("FORMAT", fmt), ("impressions", impressions)) if c is None]
    if earnings is None and micros is None:
        missing.append("earnings")
    if missing:
        raise FloorsError(f"{path}: faltan columnas {', '.join(missing)}")
    totals: dict[tuple[str, str], tuple[float, int]] = {}
    for row in rows:
        if platform and plat and row[plat].strip().lower() != platform.lower():
            continue
        amount = _number(row[earnings]) if earnings else _number(row[micros]) / 1_000_000
        key = (normalize_country(row[country]), normalize_format(row[fmt]))
        money, count = totals.get(key, (0.0, 0))
        totals[key] = (money + amount, count + int(_number(row[impressions])))
    return totals


def percentile(values: list[float], fraction: float) -> float:
    """Percentil con interpolación lineal (el de numpy por defecto)."""
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    low, high = math.floor(position), math.ceil(position)
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def build(tiers: dict[str, int], default_tier: int, formats: list[str],
          report: dict[tuple[str, str], tuple[float, int]] | None = None,
          factor: float = DEFAULT_FACTOR, min_impressions: int = DEFAULT_MIN_IMPRESSIONS) -> dict:
    """El plan: un grupo de mediación por tier y formato, con su piso propuesto.

    `piso = factor × eCPM p25 del tier` (p25 entre los países del tier con datos
    suficientes). Sin informe, o sin ningún país con datos en ese tier y formato, el
    piso queda «a medir». Un país sin datos propios cae al piso de su tier."""
    if not 0 < factor <= 1:
        raise FloorsError(f"el factor tiene que estar en (0, 1] para que ningún piso pase al p25 medido: {factor}")
    countries: dict[int, set[str]] = {}
    for country, tier in tiers.items():
        countries.setdefault(tier, set()).add(country)
    for country, _ in (report or {}):
        if country not in tiers:  # un país que no está en la tabla cae a la tier por defecto
            countries.setdefault(default_tier, set()).add(country)
    groups = []
    for tier in sorted(countries):
        for fmt in formats:
            ecpms = {}
            for country in countries[tier]:
                money, count = (report or {}).get((country, fmt), (0.0, 0))
                if count >= min_impressions:
                    ecpms[country] = money / count * 1000
            if ecpms:
                p25 = percentile(list(ecpms.values()), 0.25)
                floor, p25_out, basis = round(factor * p25, 4), round(p25, 4), len(ecpms)
            else:
                floor, p25_out, basis = TO_MEASURE, None, 0
            groups.append({
                "group": f"tier{tier}-{fmt}", "tier": tier, "format": fmt,
                "floorEcpm": floor, "ecpmP25": p25_out, "countriesWithData": basis,
                "countries": sorted(countries[tier]),
            })
    return {
        "factor": factor, "minImpressions": min_impressions, "defaultCountryTier": default_tier,
        "withReport": report is not None, "groups": groups,
    }


def render_table(plan: dict) -> str:
    lines = [f"{'Grupo':<28} {'Tier':>4} {'Formato':<22} {'p25 eCPM':>9} {'Piso eCPM':>10} {'Con datos':>9} Países"]
    for g in plan["groups"]:
        p25 = "-" if g["ecpmP25"] is None else f"{g['ecpmP25']:.4f}"
        floor = g["floorEcpm"] if isinstance(g["floorEcpm"], str) else f"{g['floorEcpm']:.4f}"
        lines.append(f"{g['group']:<28} {g['tier']:>4} {g['format']:<22} {p25:>9} {floor:>10} "
                     f"{g['countriesWithData']:>9} {len(g['countries'])}")
    return "\n".join(lines)
