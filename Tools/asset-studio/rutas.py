"""Donde vive cada cosa que el Estudio lee o escribe.

El codigo esta en el repo; los datos del dueno, afuera (`~/Desktop/estudio-assets`),
porque sobreviven a cambiar de rama. Cada ruta de afuera se puede mover con una
variable de entorno: los tests y las pruebas de punta a punta las apuntan a una
carpeta temporal, y asi nunca tocan el trabajo real.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ESTUDIO = Path(__file__).resolve().parent
REPO = ESTUDIO.parent.parent
PIPELINE = REPO / "Tools" / "asset-pipeline"
SCRIPTS = PIPELINE / "scripts"
RESOURCES = REPO / "FisuEvolution" / "Resources"
WEB = ESTUDIO / "web"
ESQUEMA = ESTUDIO / "esquema" / "registro.schema.json"
EXPORT = ESTUDIO / "registro.export.json"

if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))


def _ruta(variable: str, por_defecto: Path) -> Path:
    return Path(os.environ.get(variable, por_defecto)).expanduser()


HOME = Path.home()
GENERADOR = HOME / "Desktop" / "projects" / "automatic-image-generation" / "projects" / "fisu-evolution-v2"


def datos() -> dict[str, Path]:
    """Las rutas de los datos del dueno (se leen en cada llamada: los tests las mueven)."""
    base = _ruta("ESTUDIO_DATOS", HOME / "Desktop" / "estudio-assets")
    generador = _ruta("ESTUDIO_GENERADOR", GENERADOR)
    return {
        "previo_decisiones": _ruta("ESTUDIO_DECISIONES", HOME / "Desktop" / "revision-v2" / "decisiones.json"),
        "previo_islas": _ruta("ESTUDIO_ISLAS", HOME / "Desktop" / "projects" / "islas-review"),
        "base": base,
        "registro": base / "registro.json",
        "trabajos": base / "trabajos",
        "importaciones": base / "importaciones",
        "cache": base / "cache",
        "videos": base / "videos",
        "respaldos": base / "respaldos",
        "generador": generador,
        "revision_videos": generador / "video" / "revision.json",
        "pedido_regenerar": generador / "regenerar-desde-estudio.json",
    }
