"""App Store Connect por su API oficial: leer el estado, compararlo con la config
y aplicar sólo la diferencia.

Todo pasa por `plan()`: mira qué hay en App Store Connect y devuelve las
acciones que faltan. `apply` ejecuta ese plan acción por acción y vuelve a leer
después de cada una, así que repetirlo no duplica nada y una corrida cortada se
retoma corriendo lo mismo. Nada de esto borra: un producto que sobra se reporta.

Credenciales (fuera del repo): `~/.appstoreconnect/releaseops.json` con
`issuerId`, `keyId` y `keyPath` (la .p8). La firma ES256 la hace el `openssl`
del sistema, así que no hay dependencias.
"""

from __future__ import annotations

import base64
import json
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

API = "https://api.appstoreconnect.apple.com"
CREDENTIALS = Path.home() / ".appstoreconnect" / "releaseops.json"
ASC_TYPE = {"consumable": "CONSUMABLE", "nonConsumable": "NON_CONSUMABLE"}


class AscError(RuntimeError):
    pass


# --------------------------------------------------------------------- token

def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _der_to_raw(der: bytes) -> bytes:
    """openssl firma ECDSA en DER; JWT quiere r||s de 32 bytes cada uno."""
    assert der[0] == 0x30
    index = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    parts = []
    for _ in range(2):
        assert der[index] == 0x02
        length = der[index + 1]
        value = der[index + 2:index + 2 + length]
        parts.append(value.lstrip(b"\x00").rjust(32, b"\x00"))
        index += 2 + length
    return b"".join(parts)


def make_token(issuer: str, key_id: str, key_path: Path, ttl: int = 1100) -> str:
    now = int(time.time())
    header = _b64(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = _b64(json.dumps({"iss": issuer, "iat": now, "exp": now + ttl,
                               "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{header}.{payload}".encode()
    signed = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(key_path)],
                            input=signing_input, capture_output=True, check=True)
    return f"{header}.{payload}.{_b64(_der_to_raw(signed.stdout))}"


# -------------------------------------------------------------------- client

class Client:
    def __init__(self, credentials: Path = CREDENTIALS):
        if not credentials.exists():
            raise AscError(f"faltan credenciales: {credentials} con issuerId, keyId y keyPath")
        creds = json.loads(credentials.read_text())
        self.issuer = creds["issuerId"]
        self.key_id = creds["keyId"]
        self.key_path = Path(creds["keyPath"]).expanduser()
        self._token = ""
        self._token_at = 0.0

    def _auth(self) -> str:
        if time.time() - self._token_at > 900:
            self._token = make_token(self.issuer, self.key_id, self.key_path)
            self._token_at = time.time()
        return self._token

    def request(self, method: str, path: str, body: dict | None = None, params: dict | None = None) -> dict:
        url = path if path.startswith("http") else API + path
        if params:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method, headers={
            "Authorization": f"Bearer {self._auth()}", "Content-Type": "application/json"})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=60) as response:
                    raw = response.read()
                    return json.loads(raw) if raw else {}
            except urllib.error.HTTPError as error:
                detail = error.read().decode(errors="replace")
                if error.code in (429, 500, 502, 503, 504) and attempt < 3:
                    time.sleep(2 ** attempt * 2)
                    continue
                raise AscError(f"{method} {path} → {error.code}: {_explain(detail)}") from None
        raise AscError(f"{method} {path}: sin respuesta")

    def get_all(self, path: str, params: dict | None = None) -> tuple[list, list]:
        """Todas las páginas: devuelve (data, included)."""
        data, included = [], []
        page = self.request("GET", path, params={"limit": 200, **(params or {})})
        while True:
            data += page.get("data", [])
            included += page.get("included", [])
            nxt = page.get("links", {}).get("next")
            if not nxt:
                return data, included
            page = self.request("GET", nxt)


def _explain(detail: str) -> str:
    try:
        errors = json.loads(detail).get("errors", [])
        return " | ".join(f"{e.get('title')}: {e.get('detail')}" for e in errors) or detail[:300]
    except ValueError:
        return detail[:300]


# --------------------------------------------------------------------- estado

@dataclass
class Action:
    product: str
    kind: str          # create-iap | patch-iap | create-loc | patch-loc | set-price | set-availability
    summary: str
    payload: dict = field(default_factory=dict)
    needs_approval: str | None = None


def find_app(client: Client, bundle_id: str) -> dict:
    apps = client.request("GET", "/v1/apps", params={"filter[bundleId]": bundle_id})["data"]
    if not apps:
        raise AscError(f"no hay app con bundle id {bundle_id} en esta cuenta")
    return apps[0]


def snapshot(client: Client, config: dict) -> dict:
    """Lo que hay hoy en App Store Connect, por productId."""
    app = find_app(client, config["app"]["bundleId"])
    iaps, _ = client.get_all(f"/v1/apps/{app['id']}/inAppPurchasesV2")
    state = {"app": {"id": app["id"], "name": app["attributes"]["name"]}, "products": {}}
    for iap in iaps:
        attrs = iap["attributes"]
        locs, _ = client.get_all(f"/v2/inAppPurchases/{iap['id']}/inAppPurchaseLocalizations")
        state["products"][attrs["productId"]] = {
            "id": iap["id"],
            "referenceName": attrs.get("name"),
            "type": attrs.get("inAppPurchaseType"),
            "state": attrs.get("state"),
            "reviewNote": attrs.get("reviewNote"),
            "familySharable": attrs.get("familySharable"),
            "localizations": _by_locale(locs),
            "priceUSD": _current_price(client, iap["id"]),
            "availability": _availability(client, iap["id"]),
        }
    return state


def _by_locale(locs: list) -> dict:
    """Una entrada por idioma, la que se va a revisar.

    ⚠️ Medido 2026-10-08: un idioma aprobado puede tener DOS localizaciones, la
    APPROVED (en vivo) y un borrador PREPARE_FOR_SUBMISSION que Apple abre
    cuando se toca el producto. La aprobada no se puede editar (409 "ACTIVE");
    el borrador sí, y es el que sale con la próxima versión. Se compara contra
    el borrador cuando existe, y la aprobada queda como `live`."""
    result: dict = {}
    for loc in locs:
        attrs = loc["attributes"]
        entry = {"id": loc["id"], "name": attrs.get("name"), "description": attrs.get("description"),
                 "state": attrs.get("state")}
        current = result.get(attrs["locale"])
        if current is None:
            result[attrs["locale"]] = entry
        elif entry["state"] == "APPROVED":
            current["live"] = entry["name"]
        else:
            entry["live"] = current["name"] if current["state"] == "APPROVED" else current.get("live")
            result[attrs["locale"]] = entry
    return result


def _current_price(client: Client, iap_id: str) -> str | None:
    try:
        schedule = client.request("GET", f"/v2/inAppPurchases/{iap_id}/iapPriceSchedule")["data"]
    except AscError:
        return None
    prices, included = client.get_all(f"/v1/inAppPurchasePriceSchedules/{schedule['id']}/manualPrices",
                                      params={"include": "inAppPurchasePricePoint,territory"})
    points = {i["id"]: i for i in included if i["type"] == "inAppPurchasePricePoints"}
    for price in prices:
        rel = price["relationships"]
        if rel.get("territory", {}).get("data", {}).get("id") == "USA":
            point = points.get(rel["inAppPurchasePricePoint"]["data"]["id"])
            return point["attributes"]["customerPrice"] if point else None
    return None


def _availability(client: Client, iap_id: str) -> dict | None:
    try:
        data = client.request("GET", f"/v2/inAppPurchases/{iap_id}/inAppPurchaseAvailability",
                              params={"include": "availableTerritories"})
    except AscError:
        return None
    if not data.get("data"):
        return None
    attrs = data["data"]["attributes"]
    territories = data["data"].get("relationships", {}).get("availableTerritories", {})
    count = territories.get("meta", {}).get("paging", {}).get("total") or len(territories.get("data", []))
    return {"id": data["data"]["id"], "newTerritories": attrs.get("availableInNewTerritories"),
            "territories": count}


def plan(config: dict, state: dict) -> tuple[list[Action], list[str]]:
    """Las acciones que llevan App Store Connect a la config, y lo que sobra allá."""
    actions: list[Action] = []
    locales = config["app"]["locales"]
    wanted = {p["productId"]: p for p in config["inAppPurchases"]["products"]}
    for pid, product in wanted.items():
        short = pid.rsplit(".", 1)[-1]
        have = state["products"].get(pid)
        if have is None:
            actions.append(Action(short, "create-iap", f"crear {ASC_TYPE[product['type']]} «{product['referenceName']}»",
                                  {"product": product}))
            for locale in locales:
                actions.append(Action(short, "create-loc", f"{locale}: {product['localizations'][locale]['name']}",
                                      {"locale": locale, **product["localizations"][locale]}))
            actions.append(Action(short, "set-price", f"precio USD {product['priceUSD']}", {"usd": product["priceUSD"]}))
            actions.append(Action(short, "set-availability", "disponible en todos los países", {}))
            continue
        if have["type"] != ASC_TYPE[product["type"]]:
            actions.append(Action(short, "conflict", f"en ASC es {have['type']} y la config dice "
                                  f"{ASC_TYPE[product['type']]}: el tipo no se puede cambiar",
                                  needs_approval="decisión del dueño"))
        patch = {}
        if have["referenceName"] != product["referenceName"]:
            patch["name"] = product["referenceName"]
        if (have["reviewNote"] or None) != (product.get("reviewNote") or None) and product.get("reviewNote"):
            patch["reviewNote"] = product["reviewNote"]
        if bool(have["familySharable"]) != bool(product.get("familySharable")):
            patch["familySharable"] = bool(product.get("familySharable"))
        if patch:
            actions.append(Action(short, "patch-iap", "actualizar " + ", ".join(patch), {"id": have["id"], "attributes": patch}))
        for locale in locales:
            want = product["localizations"][locale]
            got = have["localizations"].get(locale)
            if got is None:
                actions.append(Action(short, "create-loc", f"{locale}: {want['name']}",
                                      {"iapId": have["id"], "locale": locale, **want}))
            elif (got["name"], got["description"]) != (want["name"], want["description"]):
                actions.append(Action(short, "patch-loc", f"{locale}: «{got['name']}» / «{got['description']}» → "
                                      f"«{want['name']}» / «{want['description']}»",
                                      {"id": got["id"], "name": want["name"], "description": want["description"]}))
        if have["priceUSD"] is None:
            actions.append(Action(short, "set-price", f"precio USD {product['priceUSD']} (no tenía)",
                                  {"iapId": have["id"], "usd": product["priceUSD"]}))
        elif _same_price(have["priceUSD"], product["priceUSD"]) is False:
            actions.append(Action(short, "set-price", f"precio USD {have['priceUSD']} → {product['priceUSD']}",
                                  {"iapId": have["id"], "usd": product["priceUSD"]},
                                  needs_approval="cambio de precio de un producto publicado"))
        if have["availability"] is None:
            actions.append(Action(short, "set-availability", "disponible en todos los países", {"iapId": have["id"]}))
    extra = sorted(set(state["products"]) - set(wanted))
    return actions, extra


def _same_price(a: str, b: str) -> bool:
    return abs(float(a) - float(b)) < 0.005


# --------------------------------------------------------------------- aplicar

def apply(client: Client, config: dict, state: dict, actions: list[Action], log) -> list[Action]:
    """Ejecuta el plan. Devuelve las acciones que no se pudieron hacer."""
    app_id = state["app"]["id"]
    created: dict[str, str] = {}      # producto corto → id de IAP creado en esta corrida
    failed: list[Action] = []
    for action in actions:
        if action.needs_approval or action.kind == "conflict":
            log({"action": action.kind, "product": action.product, "result": "salteada", "why": action.needs_approval})
            failed.append(action)
            continue
        iap_id = action.payload.get("iapId") or created.get(action.product)
        try:
            if action.kind == "create-iap":
                product = action.payload["product"]
                body = {"data": {"type": "inAppPurchases", "attributes": {
                    "name": product["referenceName"], "productId": product["productId"],
                    "inAppPurchaseType": ASC_TYPE[product["type"]],
                    "familySharable": bool(product.get("familySharable")),
                    **({"reviewNote": product["reviewNote"]} if product.get("reviewNote") else {})},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}
                created[action.product] = client.request("POST", "/v2/inAppPurchases", body)["data"]["id"]
            elif action.kind == "patch-iap":
                client.request("PATCH", f"/v2/inAppPurchases/{action.payload['id']}", {"data": {
                    "type": "inAppPurchases", "id": action.payload["id"], "attributes": action.payload["attributes"]}})
            elif action.kind == "create-loc":
                client.request("POST", "/v1/inAppPurchaseLocalizations", {"data": {
                    "type": "inAppPurchaseLocalizations",
                    "attributes": {k: action.payload[k] for k in ("locale", "name", "description")},
                    "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}}}})
            elif action.kind == "patch-loc":
                client.request("PATCH", f"/v1/inAppPurchaseLocalizations/{action.payload['id']}", {"data": {
                    "type": "inAppPurchaseLocalizations", "id": action.payload["id"],
                    "attributes": {"name": action.payload["name"], "description": action.payload["description"]}}})
            elif action.kind == "set-price":
                _set_price(client, iap_id, action.payload["usd"], config["inAppPurchases"]["defaults"]["baseTerritory"])
            elif action.kind == "set-availability":
                _set_availability(client, iap_id)
            log({"action": action.kind, "product": action.product, "result": "ok", "summary": action.summary})
        except (AscError, KeyError) as error:
            log({"action": action.kind, "product": action.product, "result": "error", "error": str(error)})
            failed.append(action)
    return failed


def _set_price(client: Client, iap_id: str, usd: str, territory: str) -> None:
    points, _ = client.get_all(f"/v2/inAppPurchases/{iap_id}/pricePoints", params={"filter[territory]": territory})
    point = next((p for p in points if _same_price(p["attributes"]["customerPrice"], usd)), None)
    if point is None:
        raise AscError(f"no hay un punto de precio de {usd} en {territory}")
    client.request("POST", "/v1/inAppPurchasePriceSchedules", {
        "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
            "baseTerritory": {"data": {"type": "territories", "id": territory}},
            "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${base}"}]}}},
        "included": [{"type": "inAppPurchasePrices", "id": "${base}", "attributes": {"startDate": None},
                      "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints",
                                                                             "id": point["id"]}}}}]})


def _set_availability(client: Client, iap_id: str) -> None:
    territories, _ = client.get_all("/v1/territories")
    client.request("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
        "type": "inAppPurchaseAvailabilities", "attributes": {"availableInNewTerritories": True},
        "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
            "availableTerritories": {"data": [{"type": "territories", "id": t["id"]} for t in territories]}}}})


# ------------------------------------------------------- captura de revisión

def review_screenshot(client: Client, iap_id: str) -> dict | None:
    try:
        data = client.request("GET", f"/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot").get("data")
    except AscError:
        return None
    if not data:
        return None
    return {"id": data["id"], "fileName": data["attributes"].get("fileName"),
            "state": (data["attributes"].get("assetDeliveryState") or {}).get("state")}


def upload_review_screenshot(client: Client, iap_id: str, png: Path) -> str:
    """Reserva, sube por partes y confirma con el MD5: el protocolo de assets de Apple."""
    import hashlib

    if review_screenshot(client, iap_id):
        raise AscError("ese producto ya tiene captura de revisión; reemplazarla implica borrar la actual")
    blob = Path(png).read_bytes()
    reservation = client.request("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots",
        "attributes": {"fileName": Path(png).name, "fileSize": len(blob)},
        "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}}}})["data"]
    for op in reservation["attributes"]["uploadOperations"]:
        chunk = blob[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"], headers=headers)
        with urllib.request.urlopen(req, timeout=120):
            pass
    client.request("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{reservation['id']}", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots", "id": reservation["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
    return reservation["id"]


def readiness(client: Client, state: dict) -> list[str]:
    """Lo que le falta a cada producto para poder ir a revisión con la versión."""
    missing = []
    for pid, product in sorted(state["products"].items()):
        short = pid.rsplit(".", 1)[-1]
        if not review_screenshot(client, product["id"]):
            missing.append(f"{short}: falta la captura de revisión")
        if product["state"] == "MISSING_METADATA":
            missing.append(f"{short}: App Store Connect lo marca MISSING_METADATA")
        if product["priceUSD"] is None:
            missing.append(f"{short}: sin precio")
        if product["availability"] is None:
            missing.append(f"{short}: sin disponibilidad")
    return missing
