"""Qué builds ya subió el dueño a App Store Connect y cuál es el próximo número libre.

Sólo lectura: un único `GET /v1/builds`. Apple rechaza un `CFBundleVersion`
repetido dentro de la misma versión, y el repo no sabe qué se subió.
"""

from __future__ import annotations

from dataclasses import dataclass

# El último build que se sabe quemado antes de la 2.0 (el 5 es el primero que se puede usar).
FLOOR = 4

PARAMS = {
    "sort": "-uploadedDate",
    "include": "preReleaseVersion",
    "fields[builds]": "version,uploadedDate,processingState,preReleaseVersion",
    "fields[preReleaseVersions]": "version",
}


@dataclass
class Build:
    marketing: str
    build: str
    state: str
    uploaded: str


def fetch(client, app_id: str) -> list[Build]:
    """Todos los builds de la app, más nuevos primero. Sólo `GET`."""
    data, included = client.get_all("/v1/builds", {"filter[app]": app_id, **PARAMS})
    return parse(data, included)


def parse(data: list, included: list) -> list[Build]:
    versions = {i["id"]: i["attributes"].get("version", "?")
                for i in included if i.get("type") == "preReleaseVersions"}
    builds = []
    for item in data:
        attrs = item["attributes"]
        pre = ((item.get("relationships") or {}).get("preReleaseVersion") or {}).get("data") or {}
        builds.append(Build(versions.get(pre.get("id"), "?"), str(attrs.get("version", "?")),
                            attrs.get("processingState") or "?", attrs.get("uploadedDate") or ""))
    return sorted(builds, key=lambda b: b.uploaded, reverse=True)


def next_free(builds: list[Build], marketing: str, project_build: int = 0) -> int:
    """`max(builds de esa versión, 4) + 1`, o el de `project.yml` si es mayor."""
    used = [int(b.build) for b in builds if b.marketing == marketing and b.build.isdigit()]
    return max(max(used + [FLOOR]) + 1, project_build)


def render(builds: list[Build], marketing: str, free: int) -> str:
    lines = [f"{'versión':<10} {'build':<7} {'estado':<12} fecha"]
    lines += [f"{b.marketing:<10} {b.build:<7} {b.state:<12} {b.uploaded}" for b in builds]
    if not builds:
        lines.append("(App Store Connect no tiene builds)")
    lines.append(f"próximo build libre para {marketing}: {free}")
    return "\n".join(lines)
