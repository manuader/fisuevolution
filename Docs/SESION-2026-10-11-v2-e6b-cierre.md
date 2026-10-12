# Sesión 2026-10-11 — E6b: lugares extra, pintas con ORO y familias (cierre de E6b)

Cierre de E6b T10 y, con él, de E6b entera. Sólo documentación: no compila ni corre oráculo. El `completo` que lo cubre es el de tanda del relevo 35 (ver §5); este documento no escribe resultados que no estén en las fuentes.
Plan: `Docs/superpowers/plans/2026-10-07-v2-e6b-lugares-skins.md`. Con este cierre quedan cerradas E6a (`Docs/SESION-2026-10-11-v2-e6.md`) y E6b: E6 entera.

## 1. Qué es E6b, tal como quedó

El plan decía «lugares extra, pintas con ORO, efectos y familias». **Los efectos no existen** (el dueño los descartó el 2026-10-07, ver §3). Lo que entró:

- **Lugares extra** (`extra_slots`, +3 y +2 sobre la base vigente, 600 y 1500 ORO): la capacidad vive en la tabla de pisos (`FloorTable.expanded(by:)`), no en `slots.count`.
- **La pinta comprada con ORO es tuya** (`OroShop.purchaseSkin`): vive en `engagement.shop.skins`, sobrevive a la reencarnación y se une con las ganadas en `allOwnedSkins`.
- **Las tres familias** (Pijama de Ositos, Gaucho, Disfraz de Dinosaurio; 43 personajes cada una, 450 ORO) y el estante Cosméticos de la Tienda de ORO.
- **Ocho pintas de la v1 que pasan a exclusivas de ORO** (T8): salen del cofre; quien ya las tiene las conserva.
- **El reset de cuenta conserva las pintas compradas con ORO** (fuera del plan original; decisión del dueño en el relevo 35).

## 2. La tabla por tarea

| Tarea | Qué entregó | Commit (rama / merge) | Verificación y revisión |
|---|---|---|---|
| T1 | Los 8 efectos de skin por shader | `f9cd4b9` (merge `15318a0`) | **Borrado en T1r** |
| T2 | La galería DEBUG de los 8 efectos | `d3c0889` (merge `15318a0`) | El dueño no aprobó ninguno → **borrada en T1r** |
| T3 | `skins.json` v2 y su validador (EK) | `2ba7c2e` (merge `e27efb1`) | El caso `.effect` se quita en T1r; quedan familias y precio en ORO |
| T1r | Sin skins por código: borra shaders, galería y `Treatment.effect`/`shaderId` | `255749b` (merge `9c5df1e`) | −495 líneas; grep vacío |
| T9 (r22) | Las tres familias entran: 129 entradas en `skins.json`, id = familia, 450 ORO, atlas `fam_*` | `b9e2cd0` (merge `e02c34c4`) | Unit 56, `FamilySkinsContentTests` 3×3; diff leído (mecánico). El rojo del `rapido` (`SkinCatalogRowsTests.baseComesFirstAndStartsEquipped`) pineaba un catálogo que la tarea agrandó a propósito; lo arregló el controlador (`ababa57`, sólo el test) |
| T6 (r23) | Lugares extra, puros (EK): `FloorDef.withCapacity`, `FloorTable.expanded(by:)` | `1778826` (merge `a839357b`) | EK 784; 6 tests; diff leído |
| T4 (r29) | La pinta comprada con ORO es tuya: `purchaseSkin` (`alreadyOwned` antes de `spendOro`, rechaza `price <= 0`), `buySkinWithOro` síncrono con un guardado, `.oroPurchasable` | `fa6b4cc` + arreglos `08fbf82` (merge `d6b8450`, clave `26df563`) | Unit 17; `CharacterSheetUITests` 3/3 y `CustomizationUITests` 5/5; RED visto del guard `alreadyOwned` y de `invalidPrice`. Opus **Approved con arreglos menores** (hechos). `rapido` VERDE (unit 1403) |
| T5 (r31) | Las familias se ven: atlas por familia en 2 lugares de `BoardScene`, `SkinArt` en Pintas/ficha/tienda, `Shelf.cosmetics` + `GameState+Cosmetics`, estante con `PurchaseLatch` vía `buySkinWithOro`, `packSize` para `.oroPurchasable` (leyenda «incluye 43») | `4234920` (merge `2a85f23d`, 4 claves `7b1c4439`) | EK 863 · unit 14; RED: no compila. **Sin UI del estante en la tarea** |
| T7 (r31) | Lugares extra en la partida: `applyExtraSlots` al inicio de `reconcileTower` (idempotente desde `baseFloorTable`), `growTowerToTheExtraSlots` al comprar sin compactar, `extra_slots` 600/1500 ORO | `a061128` + arreglos `3408d55` (merge `b51c24d1`, 2 claves `fb9ca7ff`) | EK 863 · unit 64; RED por mutación del cobro. Opus **aprobada con un obligatorio de test**: `ExtraSlotsLayoutUITests` pasaba sin lugares aplicados (ahora exige `count > 10` y `rows >= 3`); menores hechos |
| T8 (r35) | Ocho pintas de la v1 a ORO (`chestRarity` → `oroPrice`): legendarias `agujero_negro`, `dinastia`, `iluminado`, `titan` a 300; épicas `corona_solar`, `selenita`, `terraformador`, `moneda_propia` a 150; la bolsa de cofres pasa de 41 a 33 (7 / 14 / 8 / 4) | `335dd892` (merge `5d5e99ca`, docs `af3472f3`) | EK 867 · unit 160; `OroSkinsContentTests` 9; `CosmeticsUITests` de punta a punta (comprar `corona_solar`) verde; RED ×2. Opus **Approved sin obligatorios**. Detalle en `Docs/SESION-2026-10-11-v2-e6b-t8.md` |
| El reset de las pintas (r35, sin fila) | `ResetPlan` conserva `engagement.shop.skins`; `milestoneSkins` se pierde como antes; `Summary.keptSkins`/`skinsLost` | `4299cb3d` + arreglos `3a986da0` (merge `32b5c60c`, claves `0dc356dc`) | EK 875 · unit 29; `SettingsResetUITests` 1/1; RED en EK. Opus **Approved con arreglos** (O1: `reset-pintas.quitar` listaba mal `reset.summary.iap_skins`) |
| El test de cofres (r35) | `ChestSourcesTests.openingSpendsThePrestigeChestFirst` a 10 vueltas | `0ae88671` | Con la bolsa de 33, la de épica o mejor quedó en 12 y 1 + 12 aperturas la agotaban |
| T10 | Este cierre | — | Sólo docs |

## 3. Lo que se descartó, y por qué

- **Los 8 efectos por shader** (neón, holograma, fantasma, arcoíris, glitch, pixel, oro líquido, sombra) y su galería: el dueño aprobó los 8 a 150 ORO el 2026-10-07 y un minuto después lo corrigió: «No incluyas skins hechas con código. Solamente las skins propuestas por el plan de la versión 2 y las que ya estaban en la versión 1» (`Docs/SESION-2026-10-08-v2-e6.md`). La corrección anula lo anterior. T1r borró shaders, galería y `Treatment.effect`/`shaderId`. De ahí no hay escenarios de efectos ni de Reduce Motion sobre efectos, ni miniaturas quietas, y `skinEffects` queda como el único hueco declarado del tutorial (E9b T3).
- **El tinte en vivo de las pintas sin clip propio** (spike `cb9c264b`, relevo 35; no es una tarea de E6b pero toca sus pintas): el dueño vio las tres variantes sobre `cartonero__oro` y eligió el PNG real; no se reabre. Queda en la rama `v2i/spike-tinte` como traza.
- **Que la capacidad pase a `slots.count`** (lo que pedía PLAN-v2): el simulador y los pisos en marcha de E2a no tienen torre; la capacidad vive en la tabla de pisos, agrandada en un solo lugar.

## 4. Las decisiones que quedaron

- **La capacidad vive en la tabla de pisos.** Quien arme una tabla de pisos parte de `content.floorTable`, no de `baseFloorTable`; `applyExtraSlots` es idempotente desde la base.
- **Una pinta de ORO vive en `shop.skins`.** No en `milestoneSkins`: por eso sobrevive a la reencarnación y el reset de cuenta la conserva (con el ORO conservado en `min(saldo, comprado)`), mientras las de cofre se pierden como antes.
- **No se vende lo que no se ve.** Sin el atlas completo, una familia no se vende aunque las otras sí; de a una.
- **Una exclusiva de ORO sale del cofre y quien la tenía la conserva** (la de cofre vive en `milestoneSkins`; `allOwnedSkins` no mira `chestRarity`; `purchaseSkin` responde `alreadyOwned` y no cobra).
- Los lugares extra son **deltas** (+3, +2) sobre la base, sea la que sea.

## 5. Verificación y mediciones

- **`completo` de `c21d9e47`** (relevo 35; cubre T8): ROJO sólo unit por **1** test (`ChestSourcesTests.openingSpendsThePrestigeChestFirst`, determinista, ajustado en `0ae88671`); lo demás VERDE: EK 872 · unit 1740 · UI 155 + 4 salteados · store 18 + 2 · iPad 4 · SE 2 · Release 0 · pipeline 97 · pacing Dios 31,34 h · 13 reencarnaciones.
- **`rapido` de `0dc356dc`** (suma el arreglo del test y el reset de las pintas): **VERDE (EK 875 · unit 1743 · Release 0)**. Con él, T8 pasó a ✅.
- T4 entró con el `rapido` del relevo 29 (`26df563`: EK 845 · unit 1403). T5 y T7 entraron con el `completo` de `45bc9bf` (VERDE con el rojo de Ranking declarado) y el `rapido` de `7dc2ec7` (EK 863 · unit 1581 · Release 0).
- **Peso:** +39,3 MB sobre la v1.0.0 (206,8 MB contra 167,6 MB; estimado +29, gate 60: no hay 🔒 de ODR). Medido por E8 T10 (relevo 23), con los tres atlas de familias ya en el bundle: T9 no cambia el peso. Memoria pico 117 MB en el SE, medida allí sólo del lado nuevo.
- **Pacing:** no se movió (Dios 31,34 h · 13 reencarnaciones).
- **Draws por efecto: no medido** (los efectos no existen). **Las 4 filas en el SE: no medido** (🔒 del dueño). **El estante Cosméticos y `ExtraSlotsLayoutUITests` tras los arreglos de T7: no consta en las fuentes que algún oráculo los haya corrido** (el `completo` de `c21d9e47` corrió `CosmeticsUITests`, que cubre la compra de T8).

## 6. Escenarios a mano 🔒 para el dueño

Nada de esto se hizo en device ni en simulador a mano; no se inventan resultados.

1. **Lugares extra y las 4 filas en el SE:** comprar los dos niveles (600 y 1500 ORO) y ver que el piso llega a 4 filas y entra en un SE; si no entra, decidir el escalón de `crowdTopRatio`, sprites más chicos o sólo pantallas grandes. Con la base que fije E2b hay que re-pinear.
2. **Comprar lugares y los pisos llenos:** ver que comprar saca de «en marcha» a los pisos llenos (ganás menos hasta llenarlos) y decidir si la UI lo avisa.
3. **Una pinta de ORO de punta a punta:** comprar `corona_solar` (150) en Pintas y en la ficha; equiparla y verla en el tablero; reabrir la app y comprobar que sigue tuya.
4. **Una familia:** comprar una (450 ORO) y ver los 43 en Pintas, en la ficha y en el tablero; la leyenda «incluye 43»; que una familia sin atlas completo no se ofrezca.
5. **Las 8 exclusivas:** que no salgan más del cofre y que, si ya las tenías, las conserves y figuren «tuya» sin cobrar de nuevo; la bolsa de 33 se completa antes y paga plata.
6. **El reset de cuenta:** con pintas compradas con ORO y de cofre, resetear y ver que las de ORO se conservan, las de cofre se pierden, y que el resumen lo dice con sus claves.
7. **El logro «Todas las pintas»:** exige comprar las 3 familias (1350 ORO) y ahora también las 8 exclusivas con ORO; decidir si es lo que querías.

## 7. Carries abiertos

- **E6b T8:** sin test punta a punta por `openChest`; `skinsAll` pide ORO por estas 8 (menores de la opus, no hechos).
- **UI no corridos:** el estante de pintas de T5 sin UI test en la tarea; `ExtraSlotsLayoutUITests`, `OroShopUITests` y `SideRailUITests` no corridos tras los arreglos (ver §5).
- Con E2b (base 15) re-pinear y ver 4 filas en el SE; comprar lugares saca de «en marcha» a los pisos llenos (dueño).
- Las hojas nuevas van en `boardIsCovered` (de T7).
- La §9 de `Docs/SESION-2026-10-11-v2-e6.md` dice «E6b T10 ⛔»: lo supera este documento.
