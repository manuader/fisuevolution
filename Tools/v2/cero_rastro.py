#!/usr/bin/env python3
"""Cero rastro del nombre viejo del dólar blue (E14b B14).

    Tools/v2/cero_rastro.py          # sale 1 y lista cada línea o archivo que lo nombra

Hasta E14b B14 el dólar blue se llamaba «oro» en el código, los textos y los
assets. El dueño pidió que no quede rastro: este script busca la palabra (en
minúscula, Capitalizada dentro de un identificador o en MAYÚSCULAS) en todo lo
versionado, en el contenido y en los nombres de archivo, y falla si aparece
fuera de las excepciones de abajo. No confunde «tesoro», «corona» o
`floorOrdinal`: la palabra tiene que estar sola o pegada a un identificador.

Las excepciones son invisibles en la app y cada una tiene su porqué:

- Los IDs de producto de App Store Connect (`oro_small`, `oro_medium`,
  `oro_large`): son inmutables, y las claves del catálogo que salen de ellos.
- Las claves del save viejo: se leen si falta la nueva y no se escriben más
  (`LegacyKeys` y sus tests de ida y vuelta, el migrador de los saves v3–v6 y las
  banderas de las dos lecciones del blue en `TutorialFlags`).
- La rareza dorada de las skins: su id es `oro`, igual en los 43 personajes, y
  vive en el save (`allOwnedSkins`), en `skins.json` (`skin.name.oro`) y en el
  arte (`<personaje>_idle__oro`). En pantalla dice «Dorada»/«Golden».
- Lo histórico o externo: los docs (`Docs/`, los `.md`), los snapshots de claves
  ya aplicados (`Tools/v2/claves-pendientes/`) y las herramientas del generador
  de arte (`Tools/asset-pipeline/`, `Tools/asset-studio/`), que usan los nombres
  con que el generador produjo el arte.
"""
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

PALABRA = re.compile(
    r"(?<![A-Za-zÀ-ÿ0-9])oro(?![a-zà-ÿñ])"
    r"|(?<![A-Z])Oro(?![a-zà-ÿñ])"
    r"|(?<![A-Za-z])ORO(?![A-Za-z])"
)

RUTAS_EXCLUIDAS = (
    "Docs/",
    "Tools/v2/claves-pendientes/",
    "Tools/asset-pipeline/",
    "Tools/asset-studio/",
    "Tools/v2/cero_rastro.py",
    "Tools/v2/test_cero_rastro.py",
)
EXTENSIONES_EXCLUIDAS = (".md",)

PRODUCTOS = re.compile(r"oro_(?:small|medium|large)")
SKIN_ARTE = re.compile(r"__oro(?![a-z])")

CLAVES_DEL_SAVE_VIEJO = re.compile(
    r'"(?:oro|oroEarnedLifetime|oroUpgradeLevels|oroPurchases|purchasedOroReconstructed|'
    r'oroPurchasedLifetime|oroSpentEver|oroSpinsUsed|oroExchangedToday|oro_1|oro_3|oroUpgrades|oroShop)"'
)
ARCHIVOS_DEL_SAVE_VIEJO = {
    "Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift",
    "Packages/EconomyKit/Sources/EconomyKit/Prizes/WheelState.swift",
    "Packages/EconomyKit/Sources/EconomyKit/Visitors/VisitorsState.swift",
    "Packages/EconomyKit/Sources/EconomyKit/RewardSpec.swift",
    "FisuEvolution/Persistence/SaveMigrator.swift",
    "FisuEvolution/Game/Tutorial/TutorialFlags.swift",
    "FisuEvolutionTests/SaveMigratorTests.swift",
    "Packages/EconomyKit/Tests/EconomyKitTests/SaveCompatibilityTests.swift",
    "Packages/EconomyKit/Tests/EconomyKitTests/MetaStatePurchasesTests.swift",
    "Packages/EconomyKit/Tests/EconomyKitTests/EngagementStageStateTests.swift",
    "Packages/EconomyKit/Tests/EconomyKitTests/BlueLegacyKeysTests.swift",
}

SKIN_ID = re.compile(r'"oro"|skin\.name\.oro')
ARCHIVOS_DE_SKINS = {
    "FisuEvolution/Resources/Config/skins.json",
    "FisuEvolution/Resources/Localizable.xcstrings",
    "Packages/EconomyKit/Sources/EconomyKit/SkinsConfig.swift",
    "Packages/EconomyKit/Tests/EconomyKitTests/SkinMilestonesTests.swift",
    "FisuEvolutionTests/SkinCatalogRowsTests.swift",
    "FisuEvolutionTests/CharacterSheetFromMenuTests.swift",
}


def excluida(ruta):
    return ruta.startswith(RUTAS_EXCLUIDAS) or ruta.endswith(EXTENSIONES_EXCLUIDAS)


def permitidos(ruta):
    patrones = [PRODUCTOS, SKIN_ARTE]
    if ruta in ARCHIVOS_DEL_SAVE_VIEJO:
        patrones.append(CLAVES_DEL_SAVE_VIEJO)
    if ruta in ARCHIVOS_DE_SKINS:
        patrones.append(SKIN_ID)
    return patrones


def sin_excepciones(texto, ruta):
    for patron in permitidos(ruta):
        texto = patron.sub("", texto)
    return texto


def rastros(raiz=REPO):
    """Las líneas (`ruta:n: texto`) y los nombres de archivo que todavía nombran la moneda vieja."""
    archivos = subprocess.run(
        ["git", "-C", str(raiz), "ls-files"], check=True, capture_output=True, text=True
    ).stdout.splitlines()
    hallados = []
    for ruta in archivos:
        if excluida(ruta):
            continue
        if PALABRA.search(sin_excepciones(Path(ruta).name, ruta)):
            hallados.append(f"{ruta}: el nombre del archivo")
        try:
            texto = (Path(raiz) / ruta).read_text(encoding="utf-8")
        except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
            continue
        for numero, linea in enumerate(texto.splitlines(), start=1):
            if PALABRA.search(linea) and PALABRA.search(sin_excepciones(linea, ruta)):
                hallados.append(f"{ruta}:{numero}: {linea.strip()[:160]}")
    return hallados


def main():
    hallados = rastros()
    for hallado in hallados:
        print(hallado)
    if hallados:
        print(f"✋ {len(hallados)} rastros de la moneda vieja fuera de las excepciones (ver el docstring)")
        return 1
    print("cero rastro: sólo quedan las excepciones documentadas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
