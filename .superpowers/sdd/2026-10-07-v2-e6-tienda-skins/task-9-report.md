# E6b T9 — las tres familias entran

- Paso 0: fam_pijama / fam_gaucho / fam_dinosaurio con 43 `@2x.png` cada uno (ya commiteados por E8). Entran las tres.
- `skins.json`: +129 entradas (43 x 3), sólo líneas agregadas (el formato del archivo se reproduce byte a byte con `json.dumps(indent=2)`).
  Campos: id = familia (convención oro/diamante), `treatment: texture`, `textureKey` `<base>__<familia>`, `textureAtlas: fam_<familia>`, `family`, `oroPrice: 450`, `displayNameKey: skin.name.<familia>`.
  `schemaVersion` sigue en 1: el campo ya existía en el código (T3) y lo opcional no rompe; no se subió.
- `FamilySkinsContentTests` (3 tests x 3 familias): 43 tipos concretos, id/precio/atlas/nombre, sin cofre ni hito, y cada textura existe en el atlas (`textureNames`).
  Nota: `families` es `nonisolated static` (Swift 6, argumentos de test desde suite @MainActor).
- Claves: `Tools/v2/claves-pendientes/e6b-t9.json` (3 claves es/en). El .xcstrings se aplicó localmente y NO se commitea.
- Oráculo `tarea` (FamilySkinsContentTests, GameContentValidationTests, LocalizationCompletenessTests, StatsSnapshotTests): VERDE, EK 651 tests, unit 56 verdes.
- Peso: las tres `.atlas` fuente miden 15 MB cada una (45 MB), compiladas `.atlasc` en el .app: 16 + 15 + 16 = 48 MB (coincide con ~44 MB de PLAN-v2). Los atlas ya estaban en el árbol desde E8, así que "antes/después" de esta tarea es 0: lo que suman las familias es esos ~48 MB. Debug .app total: 278 MB (no se corrió Release, lo hace el controlador). Las familias agregan 48 MB < 60 MB; si el 🔒 se refiere al bundle total, el Release lo decide el controlador.
