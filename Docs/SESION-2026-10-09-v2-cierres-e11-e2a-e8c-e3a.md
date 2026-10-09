# SESION 2026-10-09 — v2, los cierres de E11 T7, E2a T15, E8c T10 y E3a T12 (relevo 21c)

Un solo `completo` compartido por los cuatro cierres, sobre la rama `v2i/cierres-r21c` (BASE `ea0bb23` = `version-2`, más los dos commits
de test de E3a T12). No se tocó `tasks.md` ni `HANDOFF.md`: los actualiza el controlador con lo de acá.

## El `completo` (`0383a1d`, log en `build/oraculo/20261009-183630-completo/`)

| Paso | Resultado |
|---|---|
| economykit | 642 tests, passed |
| unit (iOS 26.5) | 1070 verdes · 0 rojos (más `store-unit` 16/0 en iOS 18.6) |
| release | 0 warnings |
| ui | 96 verdes · 4 rojos · 4 salteados (ver abajo) |
| store-ui | 2/0 |
| ipad-ui | 4/0 (`IPadLayoutUITests`) |
| se-ui (nuevo) | 0/2: **mi test, con dos controles que ya no existen**; arreglado en el commit siguiente y verde (ver abajo) |
| pipeline | 89/0 |
| pacing-sim | `Dios en 31.34 h ACTIVAS (561.00 h de pared) · 13 reencarnaciones` (la línea de base de E13 T7: 9 reencarnaciones para «las 6 al tope») |

Las suites que nombran los cuatro briefs corrieron todas dentro de `unit` y `ui` (unit 1070 es la clase entera; `ui` 96 verdes incluye
`NotificationsSettingsUITests`, `NotificationPermissionCardUITests`, `MergeAllChainUITests`, `BottomMenuUITests`, `HUDRedesignUITests`).

**Los 4 rojos de `ui`, uno por uno:**

1. `BonusHUDUITests.testElCofreSeGanaSeVeYSeAbreDesdeRegalos`: el rojo conocido de la base (re-corrido en el SE: sigue rojo, "sin cofres guardados la
   pestaña no puede tener puntito"). **No está en `rojos-declarados.txt` de esta base**: el oráculo lo marca "ROJO NUEVO". Carry: declararlo o arreglarlo.
2. `RankingTabUITests.testSeDeslizaHastaElRankingDesdeMejoras`: **flaky**; aislado en el SE (con las otras 5 de la clase) 6/6 verdes.
3. y 4. `LocalizationLayoutUITests` (2): `hud.store` ya no existe en la barra (E12 T13 la sacó) y el display `hud.elevator.display` se fue del tablero
   (E3a/E8d). El test del brief los asumía. Corregido (`test(i18n): el SE en castellano sin la Tienda ni el display…`) y corrido aislado en un SE 3 propio
   (iOS 26.5): `LocalizationLayoutUITests` 2/2, `BottomMenuUITests` 4/4, `HUDRedesignUITests` 3/3, `RankingTabUITests` 6/6. Las capturas del SE
   en castellano (tablero + las cinco hojas) están en `build/cierres-r21c/se-es/`; el tablero se ve sin encimados.

El `completo` queda entonces **ROJO por el oráculo** (por mi test mal armado, ya corregido, y el rojo 1 no declarado); no hace falta una segunda corrida
completa para el resto, que no cambió. Si el controlador quiere el VERDE sobre la punta: declarar `BonusHUD...Regalos` y re-correr.

Hallazgos de E3a T12 al armar el test: la Tienda abre desde `hud.coins.plus` (ya cubierto por `HUDRedesignUITests`); la barra son seis (E12 T13).

## E2a T15 — las perillas medidas (para E2b; siempre `--upgrades`)

`economy.json` temporal por variante en `build/e2a-knobs/` (script `run.py`). La base da la línea vigente (31,34 h · 13 · «las 6 al tope»), no la del brief (30,73/13/«las 7»).

| Variante | Dios activo | Reenc. | 1ª reencarnación (pared) | Las 6 al tope |
|---|---|---|---|---|
| base | 31,34 h | 13 | 9,28 h (0,94 h activas) | 20,67 h activas · 9 reenc. |
| `defaultCostGrowth` 1,12 + `mergeRefundCounts` 1 | 27,76 h | 12 | 14,00 h (1,00 h) | 15,67 h · 8 reenc. |
| `priceReliefPurchases` 24 | 30,05 h | 13 | 9,16 h (0,83 h) | 19,67 h · 9 reenc. |
| `staffedFloorBonus` 0,05 | 31,34 h | 13 | 9,28 h | 20,67 h · 9 (idéntico a la base) |
| `oro.requiresLastRunWall` true | 31,34 h | 13 | 9,28 h | 20,67 h · 9 (idéntico a la base) |
| `floors[].capacity` 15 | 31,34 h | 13 | 9,28 h | 20,67 h · 9 (idéntico a la base) |

Lectura: sólo el par growth+refund y el amortiguador mueven el simulador. Pisos en marcha y capacidad 15 no mueven nada (con el bot nunca se llena un
piso: la trampa ya anotada; E2b tiene que darle la política), y el piso móvil tampoco (el bot no lo modela). Es el punto de partida de E2b, no un veredicto.

## Los escenarios a mano

Hechos por log/automático, lo posible en un simulador: la cadena de «Fusionar todo» del fixture `--uitest-merge-all` (E8c, SE 3, iOS 26.5): grabación
`build/cierres-r21c/e8c-cadena-se.mp4` y captura final `e8c-cadena-final-se.png`; `MergeAllChainUITests` (cadena sola y tocando sin parar) verde en el `completo`.

**Para el dueño** (necesitan el diálogo del sistema, Reduce Motion, un teléfono real o jugar el núcleo del tutorial, que no se automatiza):

- **E11 T7 escenarios 1–5**: partida nueva sin diálogo y qué se programó; "Ahora no" y la reaparición a los 3 días; reinstalar y "Sí, avisame" con el diálogo del
  sistema; apagar desde Ajustes de iOS y "Abrir Ajustes"; instalar sobre una v1 con el toggle apagado. **`NotificationsManager` no loguea nada** (el brief asumía un log de lo
  programado): no se puede verificar por log. Lo automatizable (preferencia ≠ permiso ≠ ausencia, la tarjeta, el maestro) está en `NotificationsSettingsUITests`,
  `NotificationPermissionCardUITests` y las suites unit, todas verdes. Carry: un `Logger` del plan programado, si se quiere verificar a mano.
- **E2a T15 escenarios 1–5** (UBA con `--uitest-career`, variantes de precio del panel de debug, piso móvil, pisos en marcha, «Fusionar todo» con tier nuevo): a mano.
- **E8c T10 Step 2**: la cadena en el 16 Pro, con Reduce Motion apagado y prendido; con una hoja abierta en el medio; yéndose a background a mitad; por ORO y por video.
  Grabación de cada una para el dueño. Sólo está la del SE sin Reduce Motion.
- **E3a T12**: los PNG del iPad Pro 13" (2064 × 2752, castellano e inglés, seis pantallas cada uno) ya están: `build/cierres-r21c/ipad13/` (12 archivos, tamaño verificado).
  Subirlos a App Store Connect es de E10.

## Carries

- `CelebrationQueue.swift:68` (comentario viejo que E8c T10 manda corregir): **no se tocó**, es de E8b T8 en esta ola.
- Los Steps de docs de los briefs en `HANDOFF.md` (§4, §5, §7, §9 de cada épica), `tasks.md`, `HANDOFF-v2.md:90-91` y los handoffs efímeros: del controlador.
- `rojos-declarados.txt`: `BonusHUDUITests...Regalos` no figura (ver arriba).
- `RankingTabUITests.testSeDeslizaHastaElRankingDesdeMejoras` flaky bajo el completo (3.º simulador del día): vigilarlo.
- Lo de E3a T12 ya está commiteado: `LocalizationLayoutUITests`, `deviceSlot` (`@MainActor`, el brief lo daba sin) en `AppStoreScreenshotTests` y el paso `se-ui` en `oraculo.sh`.
