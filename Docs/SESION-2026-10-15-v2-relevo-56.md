# Sesión 2026-10-14/15 — relevo 56: E14b entera, T25, T26 y la regla de no compilar por tarea

Relevo por la rutina `fisu-v2-relevo-a`: el disparo de las 15:02 encontró el LOCK del 55, y el dueño pidió en el
chat arrancar a las 15:53. Estuvo en vivo todo el relevo. Su sesión «Fisu Evolution v2 roadmap» (`local_4ddbb4c3`)
mandó B16 por mensaje directo (también en `DUENO.md`).

## La regla nueva del dueño (manda sobre §0.1 del PLAN-v2)

**Los agentes no compilan por tarea.** Escriben código y tests sin correrlos, commitean y entregan. La ola entera
se integra, se compila **una vez**, y lo que falla lo arregla **un agente** desplegado para eso. Excepciones:
`swift test` de EconomyKit y el pacing-sim (no levantan simulador); los arreglos de bugs del dueño y de rojos del
build único sí compilan y verifican. Las claves de texto van sólo como snapshot y las aplica el controlador al
integrar (T26 fue dueña única del catálogo en su ola). Reglas y tabla de dueños: `.claude/avo/2026-10-06-fisu-v2/ola-r56/comun.md`.

Resultado: 16 tareas en ~6 h. La primera ola sin compilar tuvo 4 errores de compilación, todos de Swift 6/Testing,
arreglados en el momento; las siguientes compilaron a la primera porque esos casos se sumaron al prompt de los agentes:
- conformancia `Equatable`/`Animatable` en un tipo `@MainActor` → `@MainActor Equatable` o `nonisolated var animatableData`;
- un `@autoclosure` capturado en un `Logger` → evaluarlo antes;
- `#expect(cond, label)` con una variable `String` → `"\(label)"` (pide `Comment`).

## Qué entró (en `v2i/integ-r54`, pusheada)

| Tarea | Commit → merge | Qué |
|---|---|---|
| fix-r56 | `f04fe7d7` | `TowerNoticeUITests`: no era bug; el aviso dura 2,4 s y bajo carga el test llegaba tarde. `--uitest-notices-slow` (9,6 s, sólo DEBUG). |
| B11 | `d67df73b` → `9a7d070d` | El tip de Compartir colgado: `ShareOfferLayer` escondía el chip con `showing == nil` (T23). Botón de cerrar en las lecciones. |
| B16 | `5d071895` | 44 `tier.desc.<id>` es/en tal cual, bloque en `CharacterSheetView`. |
| B12 | `dabb2cc4` | Ajustes: más aire, `GameButton`, sin naranja ni SF Symbols. |
| B8 | `8d9439b4` | `ChestPrizeCard` (figurita; 4 rarezas reales: común/rara/épica/legendaria). |
| B4+B10 | `317f0478` | `PagerSlot` `@MainActor Equatable`, vecinas armadas en reposo, `UIArt.warmAtlases`; flechas a la altura del cartel; `PagerProbe` (DEBUG, `fisu.pager`). |
| B15 | `aadbdaa5` | Ruleta con cupo único (video + blue = 6/día + `wheelDailySpins`); EK con mutantes; pacing igual. |
| B9 | `58e43e23` | 8 imágenes aprobadas al `ui.atlas`, `PopupHero`, `OfferSheet` centrado, `WheelStageFit`, 22/22 eventos con imagen. |
| B3 | `1caf2208` | Horizonte único (`StageLayout.horizons` + `floorBottom`), barra crema opaca, visitante +25,8 %, aviso del SE más abajo. **Fracciones de horizonte calibradas a ojo.** |
| B5 | `7bcb6937` | `packageIntroSeen`; desde la 2.ª caja se abre en el tablero. |
| B13 | `8911667f` | `RewardFlight`: monedas que vuelan al contador y contador que sube (sólo presentación). |
| B7 | `c87a794b` | Visitante congelado por piso (`FloorVisitor`), aviso «×N» en `StageChips`, marca en el ascensor. |
| B6 | `cd31abd4` | Colchón: columna → video → tablero (`phase`), 1 de cada 4 de regalo; migración del save. |
| B14 | `d53db2d0` | Cero ORO: ~250 archivos `oro`→`blue`, `LegacyKeys` de lectura, 3 packs de blue, «Dorada» en la rareza; guardián `Tools/v2/cero_rastro.py`. |
| T25 | `fce2f6da` | Cero SF Symbols en `UI/` (salvo manos del tutorial y respaldos), ~25 glifos nuevos, `ActionPill` retirado; test `noViewDrawsSystemSymbols`. |
| T26 | `444aa887` | Catálogo limpio (10 huérfanas fuera), Tour de 12 pasos, 8 textos **aprobados por el dueño**, `VisibleLiteralsGuardTests`. |
| fix-wheel | `f6726179` | Test viejo de B15: la Ruleta da blue de premio legítimo. |
| fix-dueno | `079f6f29` → `0fe18cea` | Bugs del dueño en su iPhone: la tarjeta de tip a pantalla completa (B11 le puso `maxHeight: .infinity` a la X) y el hueco abajo en el cofre (la barra se apagaba con la UI); **la barra inferior nunca desaparece** (decisión del dueño). |
| cofre-r56 | `e4bb594f` → `6ee79bf3` | Bug del dueño: el cofre de skins mostraba el póster fijo y la tarjeta. C26 (`c56d5e4e`) colgó los clips de `VideoPlaybackPolicy.allowsLoops`, que Bajo consumo, el térmico o «Auto-Play Video Previews» apagan. Rehecho con `ChestClipDeck` (los 3 clips montados), cofre de 460 pt, golpes 1-2-3, estallido de la rareza, la figurita volando y 7 SFX sintetizados. |
| fix-ui | `41d39b5f` → `bc6610cd` | Bug real: con la lección de compartir con el turno, el momento nunca salía como chip. Los demás rojos eran carga o tests viejos frente a B7. |

## Verificación

- `completo` de `ce26b978`: EK 959 · unit 2009 · store-unit 18 · store-ui 3 · iPad 4 · SE 2 · pipeline 99 · Release 0 ·
  Dios 45,40 h VERDES; UI 170 + 10 rojos → fix-dueno y fix-ui.
- `completo` de `bc6610cd`: cortado en se-ui. EK, unit, Release y store-unit VERDES; UI 166 + 16 rojos, y los runners de store-ui e ipad-ui caídos, con carga 500–850 (el agente del cofre compiló ~7 h encima). **`version-2` no se adelantó:** el 57 corre el `completo` con la máquina sola.
- Instalada en el iPhone 15 Pro del dueño la Release de `0fe18cea`.

## Para el próximo relevo (en orden)

1. Si el `completo` de `bc6610cd` quedó VERDE (o con rojos de carga verdes aislados): fast-forward de `version-2`.
2. El cofre rehecho ya está integrado; falta verlo en el iPhone con Bajo consumo prendido.
3. **B17 y B18** (pedidos del dueño del 2026-10-15; briefs `ola-r56/e14b-b17.md` y `e14b-b18.md`).
4. Cierres: E14 T27, E8d T15, E8e T9, E12 T17/T18 y E10 (T9, T11–T13).

## Trampas nuevas

- **No mandar `SendMessage` a un agente que ya entregó: lo reanuda.** Le pasó a fix-dueno: retomó los rojos de UI
  y duplicó el trabajo de fix-ui con carga ~450 durante una hora.
- **`xcodebuild -destination id=<iPhone>` falla con «Device is busy»** si el iPhone se está conectando; compilar con
  `-destination 'generic/platform=iOS'` y después `devicectl device install app`. Ojo: si el build falla,
  `devicectl` reinstala el `.app` viejo del DerivedData sin avisar.
- Las conformancias aisladas de Swift 6 y `#expect` con `Comment` (arriba): van en el prompt de todo agente que no compila.

## Para el dueño

- G4 en el iPhone: horizonte de los 10 escenarios (calibrado a ojo), caja y colchón en el tablero, vuelo de monedas,
  menús al deslizar, visitantes por piso.
- Decisiones por default que puede cambiar: B6 (el sello del colchón se va de la columna mientras está en el tablero),
  B18 (columna y Regalos abren la caja del piso actual o llevan al de la más vieja; la pantalla de la 1.ª caja muestra
  la cara del que llega; el ascensor marca pisos con cajas).
- Fuera del repo: notas de ASC que dicen «Gives 160 ORO.» y capturas de la ficha.
- T25: arte PNG para los glifos nuevos y un rol de botón destructivo (hoy naranja).
