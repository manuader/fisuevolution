"""La ficha de la App Store de una versión: textos por idioma y notas para App Review.

Mismo contrato que las compras: `snapshot` lee, `plan` devuelve la diferencia con la
sección `store` de la config, `apply` la aplica y se vuelve a leer. Si la versión
todavía no existe, el plan compara contra la última publicada —App Store Connect
copia sus textos al crear la nueva— y la primera acción es crearla.

La disponibilidad en Mac y en Vision Pro no está en la API: el plan la lista
como paso manual (navegador).
"""

from __future__ import annotations

from dataclasses import dataclass, field

from rocore.asc import AscError, Client

INFO_FIELDS = ("name", "subtitle", "privacyPolicyUrl")
VERSION_FIELDS = ("description", "keywords", "promotionalText", "marketingUrl", "supportUrl", "whatsNew")
LIVE_STATES = {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "PENDING_DEVELOPER_RELEASE"}


@dataclass
class Step:
    kind: str
    summary: str
    payload: dict = field(default_factory=dict)
    manual: bool = False


def _attrs(item: dict) -> dict:
    return item.get("attributes", {})


def snapshot(client: Client, config: dict, app_id: str) -> dict:
    store = config["store"]
    versions, _ = client.get_all(f"/v1/apps/{app_id}/appStoreVersions")
    ios = [v for v in versions if _attrs(v).get("platform") == store["platform"]]
    target = next((v for v in ios if _attrs(v).get("versionString") == store["version"]), None)
    base = target or next((v for v in ios if (_attrs(v).get("appStoreState") or _attrs(v).get("appVersionState")) in LIVE_STATES), None)
    infos, _ = client.get_all(f"/v1/apps/{app_id}/appInfos")
    editable = [i for i in infos if (_attrs(i).get("state") or _attrs(i).get("appStoreState")) not in LIVE_STATES]
    info = editable[0] if (target and editable) else infos[0]
    state = {"versionExists": target is not None, "versionId": target["id"] if target else None,
             "baseVersion": _attrs(base).get("versionString") if base else None,
             "appInfoId": info["id"], "appInfoEditable": bool(target and editable),
             "info": {}, "version": {}, "reviewDetail": None}
    locs, _ = client.get_all(f"/v1/appInfos/{info['id']}/appInfoLocalizations")
    for loc in locs:
        state["info"][_attrs(loc)["locale"]] = {"id": loc["id"], **{k: _attrs(loc).get(k) for k in INFO_FIELDS}}
    if base:
        vlocs, _ = client.get_all(f"/v1/appStoreVersions/{base['id']}/appStoreVersionLocalizations")
        for loc in vlocs:
            state["version"][_attrs(loc)["locale"]] = {"id": loc["id"], **{k: _attrs(loc).get(k) for k in VERSION_FIELDS}}
        try:
            detail = client.request("GET", f"/v1/appStoreVersions/{base['id']}/appStoreReviewDetail")["data"]
            state["reviewDetail"] = {"id": detail["id"], **_attrs(detail)}
        except AscError:
            state["reviewDetail"] = None
    return state


def _changed(want: dict, have: dict | None, fields: tuple) -> dict:
    """Los campos que la config fija (no-null) y que difieren de lo que hay."""
    return {k: want[k] for k in fields if want.get(k) is not None and (have or {}).get(k) != want[k]}


def plan(config: dict, state: dict) -> list[Step]:
    store = config["store"]
    steps: list[Step] = []
    if not state["versionExists"]:
        steps.append(Step("create-version", f"crear la versión {store['version']} (copia los textos de la "
                                            f"{state['baseVersion']})", {"version": store["version"]}))
    for locale, want in store["localizations"].items():
        have_info = state["info"].get(locale)
        info_diff = _changed(want, have_info, INFO_FIELDS)
        if have_info is None:
            steps.append(Step("create-info-loc", f"{locale}: ficha nueva «{want['name']}»", {"locale": locale, **info_diff}))
        elif info_diff:
            steps.append(Step("patch-info-loc", f"{locale}: " + ", ".join(info_diff), {"locale": locale, **info_diff}))
        have_ver = state["version"].get(locale)
        ver_diff = _changed(want, have_ver, VERSION_FIELDS)
        if have_ver is None:
            steps.append(Step("create-version-loc", f"{locale}: textos de la versión ({', '.join(ver_diff)})",
                              {"locale": locale, **ver_diff}))
        elif ver_diff:
            steps.append(Step("patch-version-loc", f"{locale}: " + ", ".join(ver_diff), {"locale": locale, **ver_diff}))
    if store.get("reviewNotes") and (state["reviewDetail"] or {}).get("notes") != store["reviewNotes"]:
        steps.append(Step("set-review-notes", f"notas para App Review ({len(store['reviewNotes'])} caracteres)",
                          {"notes": store["reviewNotes"]}))
    availability = store.get("availability", {})
    if availability.get("appleSiliconMac") is False:
        steps.append(Step("manual", "Pricing and Availability: destildar 'iPhone and iPad Apps on Apple Silicon Mac'",
                          manual=True))
    if availability.get("visionPro") is False:
        steps.append(Step("manual", "Pricing and Availability: destildar 'Apple Vision Pro'", manual=True))
    return steps


def apply(client: Client, config: dict, app_id: str, steps: list[Step], log) -> int:
    """Ejecuta el plan; si hace falta crea la versión y vuelve a leer antes de los textos."""
    failures = 0
    state = None
    if any(s.kind == "create-version" for s in steps):
        try:
            client.request("POST", "/v1/appStoreVersions", {"data": {
                "type": "appStoreVersions",
                "attributes": {"platform": config["store"]["platform"], "versionString": config["store"]["version"]},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
            log({"action": "create-version", "result": "ok", "summary": config["store"]["version"]})
        except AscError as error:
            log({"action": "create-version", "result": "error", "error": str(error)})
            return 1
        state = snapshot(client, config, app_id)
        steps = plan(config, state)
    state = state or snapshot(client, config, app_id)
    # Crear la ficha de un idioma (appInfoLocalization) hace que Apple cree sola
    # la localización de la versión, vacía (medido 2026-10-08: el POST siguiente
    # da 409 "already exists"). Por eso las fichas van primero y los textos de
    # la versión se recalculan después.
    info_steps = [s for s in steps if s.kind.endswith("info-loc")]
    if info_steps:
        failures += _run(client, state, info_steps, log)
        state = snapshot(client, config, app_id)
        steps = [s for s in plan(config, state) if not s.kind.endswith("info-loc") and s.kind != "create-version"]
    return failures + _run(client, state, steps, log)


def _run(client: Client, state: dict, steps: list[Step], log) -> int:
    failures = 0
    for step in steps:
        if step.manual:
            log({"action": "manual", "result": "salteada", "why": step.summary})
            continue
        fields = {k: v for k, v in step.payload.items() if k != "locale"}
        locale = step.payload.get("locale")
        try:
            if step.kind == "create-info-loc":
                client.request("POST", "/v1/appInfoLocalizations", {"data": {
                    "type": "appInfoLocalizations", "attributes": {"locale": locale, **fields},
                    "relationships": {"appInfo": {"data": {"type": "appInfos", "id": state["appInfoId"]}}}}})
            elif step.kind == "patch-info-loc":
                loc_id = state["info"][locale]["id"]
                client.request("PATCH", f"/v1/appInfoLocalizations/{loc_id}", {"data": {
                    "type": "appInfoLocalizations", "id": loc_id, "attributes": fields}})
            elif step.kind == "create-version-loc":
                client.request("POST", "/v1/appStoreVersionLocalizations", {"data": {
                    "type": "appStoreVersionLocalizations", "attributes": {"locale": locale, **fields},
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": state["versionId"]}}}}})
            elif step.kind == "patch-version-loc":
                loc_id = state["version"][locale]["id"]
                client.request("PATCH", f"/v1/appStoreVersionLocalizations/{loc_id}", {"data": {
                    "type": "appStoreVersionLocalizations", "id": loc_id, "attributes": fields}})
            elif step.kind == "set-review-notes":
                detail = state["reviewDetail"]
                if detail:
                    client.request("PATCH", f"/v1/appStoreReviewDetails/{detail['id']}", {"data": {
                        "type": "appStoreReviewDetails", "id": detail["id"], "attributes": {"notes": fields["notes"]}}})
                else:
                    client.request("POST", "/v1/appStoreReviewDetails", {"data": {
                        "type": "appStoreReviewDetails", "attributes": {"notes": fields["notes"]},
                        "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": state["versionId"]}}}}})
            log({"action": step.kind, "result": "ok", "summary": step.summary})
        except (AscError, KeyError) as error:
            log({"action": step.kind, "result": "error", "error": str(error)})
            failures += 1
    return failures
