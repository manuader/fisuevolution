"""Verificaciones del `.app` (PLAN-v2 §8) como chequeos con exit 0/1. Sin red y sin compilar:
lee los plists del bundle y los compara con el fuente y con `release.json`."""

from __future__ import annotations

import plistlib
import subprocess
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

# El ID propio de cada red; el resto de su lista se compara contra el fuente.
OWN_SKADNETWORK = {
    "google": ["cstr6suwn9"],
    "unity": ["4dzt52r2t5"],
}
MIN_BUILD = 5


@dataclass
class Check:
    name: str
    ok: bool
    detail: str


def locate_app(path: Path) -> Path:
    """Acepta un `.app` o un `.xcarchive` (busca en Products/Applications)."""
    if path.suffix == ".xcarchive":
        apps = sorted((path / "Products" / "Applications").glob("*.app"))
        if not apps:
            raise FileNotFoundError(f"el archivo {path} no tiene ningún .app en Products/Applications")
        return apps[0]
    if not path.is_dir():
        raise FileNotFoundError(f"no existe {path}")
    return path


def required_networks(config: dict) -> list[str]:
    """Google más las redes de `mediation.networks` que no están rechazadas (las rechazadas llevan `status`)."""
    networks = config.get("mediation", {}).get("networks", {})
    return ["google"] + [name for name, body in networks.items() if "status" not in body]


def _load(path: Path) -> dict:
    return plistlib.loads(path.read_bytes())


def _skad_ids(info: dict) -> set[str]:
    ids = (item.get("SKAdNetworkIdentifier", "") for item in info.get("SKAdNetworkItems", []))
    return {i.removesuffix(".skadnetwork").lower() for i in ids if i}


def verify(app: Path, source_info: Path, source_privacy: Path, config: dict) -> list[Check]:
    info = _load(app / "Info.plist")
    checks: list[Check] = []

    family = info.get("UIDeviceFamily")
    checks.append(Check("UIDeviceFamily", family == [1, 2], f"esperaba [1, 2], hay {family}"))
    full = info.get("UIRequiresFullScreen")
    checks.append(Check("UIRequiresFullScreen", full is True, f"esperaba True, hay {full}"))

    manifest_path = app / "PrivacyInfo.xcprivacy"
    if manifest_path.exists():
        manifest = _load(manifest_path)
        tracking = manifest.get("NSPrivacyTracking")
        wanted = _load(source_privacy).get("NSPrivacyTracking")
        domains = manifest.get("NSPrivacyTrackingDomains") or []
        if tracking != wanted:
            checks.append(Check("NSPrivacyTracking", False, f"el fuente dice {wanted}, el .app {tracking}"))
        elif tracking is True and not domains:
            checks.append(Check("NSPrivacyTracking", False,
                                "True sin NSPrivacyTrackingDomains (ITMS-91064)"))
        else:
            checks.append(Check("NSPrivacyTracking", True, f"{tracking}"))
        checks.append(Check("PrivacyInfo.xcprivacy", True, "presente"))
    else:
        checks.append(Check("NSPrivacyTracking", False, "no hay manifiesto que leer"))
        checks.append(Check("PrivacyInfo.xcprivacy", False, "falta en el bundle"))

    app_id = config["admob"]["appId"]
    got = info.get("GADApplicationIdentifier")
    checks.append(Check("GADApplicationIdentifier", got == app_id, f"esperaba {app_id}, hay {got}"))

    have = _skad_ids(info)
    problems = []
    missing_source = sorted(_skad_ids(_load(source_info)) - have)
    if missing_source:
        problems.append("faltan del fuente: " + ", ".join(missing_source))
    for network in required_networks(config):
        missing = [i for i in OWN_SKADNETWORK.get(network, []) if i not in have]
        if missing:
            problems.append(f"falta el propio de {network}: {', '.join(missing)}")
    checks.append(Check("SKAdNetworkItems", not problems,
                        "; ".join(problems) or f"{len(have)} IDs, todos los del fuente y los de las redes"))

    version = config["store"]["version"]
    short = info.get("CFBundleShortVersionString")
    checks.append(Check("CFBundleShortVersionString", short == version, f"esperaba {version}, hay {short}"))
    build = str(info.get("CFBundleVersion", ""))
    checks.append(Check("CFBundleVersion", build.isdigit() and int(build) >= MIN_BUILD,
                        f"esperaba un entero >= {MIN_BUILD}, hay {build!r}"))
    checks.append(embedded_frameworks(app, info))
    return checks


def otool_load_commands(binary: Path) -> str:
    return subprocess.run(["xcrun", "otool", "-l", str(binary)],
                          check=True, capture_output=True, text=True).stdout


def parse_load_commands(text: str) -> tuple[list[str], list[str]]:
    """De `otool -l`: las dependencias fuertes (LC_LOAD_DYLIB) y los rpaths (LC_RPATH)."""
    dylibs: list[str] = []
    rpaths: list[str] = []
    command = None
    for line in text.splitlines():
        words = line.split()
        if len(words) < 2:
            continue
        if words[0] == "cmd":
            command = words[1]
        elif command == "LC_LOAD_DYLIB" and words[0] == "name":
            dylibs.append(words[1])
        elif command == "LC_RPATH" and words[0] == "path":
            rpaths.append(words[1])
    return dylibs, rpaths


def embedded_frameworks(app: Path, info: dict,
                        load_commands: Callable[[Path], str] = otool_load_commands) -> Check:
    """Cada `@rpath/…` fuerte del ejecutable (y de su `.debug.dylib`) tiene que resolverse ADENTRO
    del `.app` por un rpath relativo. Si no, dyld aborta al abrir desde el ícono: Xcode lo tapa
    inyectando `DYLD_FRAMEWORK_PATH` al correr o testear, así que sólo se ve fuera de Xcode.
    Las débiles (StoreKitTest en Debug) quedan afuera: dyld tolera que falten."""
    executable = info.get("CFBundleExecutable", "")
    binaries = [app / executable, app / f"{executable}.debug.dylib"]
    problems = []
    resolved = 0
    for binary in (b for b in binaries if executable and b.is_file()):
        dylibs, rpaths = parse_load_commands(load_commands(binary))
        bases = [Path(str(r).replace("@executable_path", str(app)).replace("@loader_path", str(binary.parent)))
                 for r in rpaths if r.startswith(("@executable_path", "@loader_path"))]
        for dylib in sorted({d for d in dylibs if d.startswith("@rpath/")}):  # fat: un juego por arquitectura
            relative = dylib.removeprefix("@rpath/")
            if any((base / relative).exists() for base in bases):
                resolved += 1
            else:
                problems.append(f"{binary.name} → {relative}")
    if not executable or not (app / executable).is_file():
        return Check("Frameworks embebidos", False, f"no está el ejecutable {executable!r}")
    return Check("Frameworks embebidos", not problems,
                 "no se resuelven dentro del .app: " + ", ".join(problems) if problems
                 else f"{resolved} dependencias @rpath, todas dentro del .app")
