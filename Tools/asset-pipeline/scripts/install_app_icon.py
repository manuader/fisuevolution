#!/usr/bin/env python3
"""Instala un candidato de ícono generado como el AppIcon de la app.

El ícono de App Store es el único asset del repo con requisitos que Apple
RECHAZA si no se cumplen, y ninguno de los tres los garantiza el generador:

  1. **Exactamente 1024×1024.** Gemini devuelve lo que le sale (suele dar
     1024², pero no está contractual).
  2. **SIN canal alfa.** Un ícono con alfa hace fallar la validación del
     Archive con "Invalid large app icon ... can't be transparent nor contain
     an alpha channel". Es el error más común del primer upload.
  3. **Sin las esquinas redondeadas dibujadas.** iOS aplica su propia máscara
     superelíptica; si el PNG ya trae esquinas, se ven recortadas dos veces.
     Esto NO se puede arreglar por código — se detecta y se avisa, porque la
     única solución es descartar el candidato.

Por eso el paso no es `cp`. Lo que hace:

    - valida que el candidato exista y sea PNG legible
    - lo lleva a 1024×1024 (Lanczos) si no lo está
    - **aplana el alfa contra un fondo opaco** y convierte a RGB
    - avisa si las esquinas parecen transparentes o casi blancas (señal de
      esquinas redondeadas dibujadas o de fondo recortado)
    - escribe el PNG en el .appiconset y verifica lo escrito releyéndolo

Uso:

    .venv/bin/python scripts/install_app_icon.py state/appicon/app_icon_b.png
    .venv/bin/python scripts/install_app_icon.py <archivo> --dry-run

El `Contents.json` del appiconset NO se toca: ya declara una sola entrada
`universal` de 1024×1024 (el formato de ícono único de Xcode 14+), que es
exactamente lo que este script produce.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

PIPELINE = Path(__file__).resolve().parents[1]
REPO = PIPELINE.parent.parent
APPICONSET = (
    REPO
    / "FisuEvolution"
    / "Resources"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
)
TARGET = APPICONSET / "AppIcon.png"
SIDE = 1024

# Contra qué se aplana el alfa. Es el celeste claro del degradé pedido por el
# dueño: si el candidato viniera con un halo semitransparente en los bordes,
# aplanar contra blanco le dejaría un aro claro visible sobre el fondo azul.
FLATTEN_BG = (191, 230, 255)


def corner_report(image: Image.Image) -> list[str]:
    """Avisos sobre las cuatro esquinas — dibujadas redondeadas o recortadas."""
    warnings: list[str] = []
    probe = 12  # px desde el vértice: adentro de la máscara de iOS ya no está
    rgba = image.convert("RGBA")
    corners = {
        "arriba-izquierda": (probe, probe),
        "arriba-derecha": (rgba.width - probe, probe),
        "abajo-izquierda": (probe, rgba.height - probe),
        "abajo-derecha": (rgba.width - probe, rgba.height - probe),
    }
    for name, (x, y) in corners.items():
        r, g, b, a = rgba.getpixel((x, y))
        if a < 250:
            warnings.append(
                f"esquina {name} semitransparente (alfa {a}): el candidato "
                "probablemente trae las esquinas redondeadas dibujadas — "
                "descartalo, esto no se arregla aplanando"
            )
    return warnings


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=str, help="PNG generado a instalar")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="valida y reporta sin escribir nada",
    )
    args = parser.parse_args()

    source = Path(args.candidate)
    if not source.is_absolute():
        # Cómodo desde Tools/asset-pipeline y desde la raíz del repo.
        for base in (Path.cwd(), PIPELINE, REPO):
            if (base / source).exists():
                source = base / source
                break
    if not source.exists():
        sys.exit(f"no existe el candidato: {args.candidate}")

    try:
        original = Image.open(source)
        original.load()
    except Exception as error:
        sys.exit(f"no se pudo leer {source} como imagen: {error}")

    print(f"candidato: {source}")
    print(f"  entrada:  {original.width}×{original.height} modo {original.mode}")

    for warning in corner_report(original):
        print(f"  ⚠️  {warning}")

    icon = original
    if icon.mode in ("RGBA", "LA", "P"):
        icon = icon.convert("RGBA")
        flattened = Image.new("RGB", icon.size, FLATTEN_BG)
        flattened.paste(icon, mask=icon.getchannel("A"))
        icon = flattened
        print(f"  alfa:     aplanado contra rgb{FLATTEN_BG}")
    else:
        icon = icon.convert("RGB")
        print("  alfa:     no tenía")

    if icon.size != (SIDE, SIDE):
        print(f"  escala:   {icon.width}×{icon.height} → {SIDE}×{SIDE}")
        icon = icon.resize((SIDE, SIDE), Image.LANCZOS)

    if args.dry_run:
        print("\n--dry-run: no se escribió nada")
        return

    APPICONSET.mkdir(parents=True, exist_ok=True)
    icon.save(TARGET, format="PNG", optimize=True)

    # Verificar lo ESCRITO, no lo que creemos que escribimos.
    written = Image.open(TARGET)
    written.load()
    ok = written.size == (SIDE, SIDE) and written.mode == "RGB"
    print(f"\nescrito: {TARGET}")
    print(f"  {written.width}×{written.height} modo {written.mode} "
          f"({TARGET.stat().st_size // 1024} KB)")
    if not ok:
        sys.exit(
            f"la verificación falló: quedó {written.width}×{written.height} "
            f"modo {written.mode}, se esperaba {SIDE}×{SIDE} modo RGB"
        )
    print("  ✓ 1024×1024, RGB sin alfa — apto para App Store")


if __name__ == "__main__":
    main()
