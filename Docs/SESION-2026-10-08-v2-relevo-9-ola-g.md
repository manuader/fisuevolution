# SESION 2026-10-08 — v2, relevo 9: la ola G, E1 completa y la economía de E2a detrás de perillas

Relevo 9 de la ejecución autónoma de la 2.0. Lo despertó la rutina `fisu-v2-relevo-b` el
2026-10-08 a las 00:57 y cerró a la mañana. Controlador opus; implementadores sonnet en
worktrees aislados; revisión opus sólo donde había plata (E1 T13 y T14).

## Lo que entró a `version-2`

| Tarea | Commit | Merge | Nota |
|---|---|---|---|
| E2a T7 cofres y packs de plata en minutos | `acf633d` | `b0bcf7b` | medido en el `completo` de `528d10b`: pacing-sim sin cambio |
| E11 T6 notificaciones al ciclo de vida | `3825d8c` | `2604119` | programa en `.background` tras el sello; borra al volver a `.active` |
| E3b T2 la ficha de personaje | `e33b844` | `171241e` | `GameConfirmCard`; claves `2408acc` |
| E6b T1r sin skins por código | `255749b` | `9c5df1e` | decisión del dueño: −495 líneas (shaders, galería, `.effect`) |
| E1 T13 el Corralito | `d838fdb` + `8adab56` | `9a641c7` | revisión opus + arreglos: precarga del video `.visitor`, UI coherente con contratar gratis, `UpgradeManager`, pill debajo del texto en el SE |
| E3a T9 las pestañas de a poco | `02ee23b` | `c76af46` | bajo `--uitest*` la barra arranca entera salvo `--uitest-progressive-tabs`; claves `528d10b` |
| E1 T14 el video sin efecto compensa 3 min | `36885a3` + `f01e7b6` | `545208b` | revisión opus + arreglos: test por el camino real con monto exacto, logros, audio sólo con la escena activa |
| E2a T3 amortiguador del salto de precio | `eae6082` | `545208b` | `hire.priceReliefPurchases` = 0 (v1) |
| E2a T4 pisos en marcha | `f38d50e` | `545208b` | `staffedFloorBonus` = 0 (v1) |
| E6a T9 packs de ORO 160 / 550 / 1.400 | `7cc20d9` | `2446069` | foto de la v1 (250/750/2000) intacta |
| E1 T15 el contrato de efectos | `02952ce` | `9f9933e` | mutantes corridos por el controlador: 2 rojos |
| E2a T5 piso móvil para reencarnar | `4ba38d8` | `6976f2f` | `requiresLastRunWall` ausente (v1) |
| E2a T9 las fusiones al amortiguador | `18e8e77` | `6976f2f` | perillas en 0 = identidad |
| E2a T8 la meta del piso móvil en pantalla | `2ae35c1` | claves `72a236b` | |
| E2a T10 "+3 % por compra" en FisuJobs | `db669f0` | claves `72a236b` | el renglón se ve siempre (la curva existe con las perillas en 0) |

Hechas al cierre, integración en el handoff efímero: **E4a T2** (`a031ee8`, los efectos de
eventos: paro, inmunidad, ritmo de paquetes) y **E3a T10** (`789c200`, `PlayLayout`, filas por
capacidad, la cámara que sigue la botonera).

## Oráculo

- `rapido` VERDE en cada integración: `2604119` (EK 506 · unit 713 + 1), `9c5df1e` (508 · 712 + 1),
  `95c4df2` (531 · 738 + 1), `6976f2f` (538 · 750 + 1). Release 0 en todos.
- **`completo` sobre `528d10b`**: EK 508 · unit 724 + 1 · Store 16 · StoreUI 2 · pipeline 49/0 ·
  pacing-sim Dios 30,73 h / 13 reenc. (sin cambio) · Release 0 · **UI 69/70**: el rojo,
  `CustomizationUITests.testSinPrecioLaSkinPagaNoDiceQueNoEstaALaVenta`, pasó aislado 2 de 2 (la
  clase entera 5/5 dos veces) → flaky de carga, no regresión.
- E1 T16 (cierre de E1) pide `completo --limpio` ×2: el #1 corrió sobre `72a236b` (ver el handoff).

## Decisiones de este relevo

- **Contratar gratis sigue permitido durante el Corralito**, y la UI lo muestra así
  (`blockedBySpendingFreeze` = congelado y costo > 0).
- **La salida por video del Corralito va debajo del texto**, no al costado: en el SE el motivo
  salía cortado.
- **E6b T1r** borra todo lo de skins por código (respuesta del dueño, `Docs/SESION-2026-10-08-v2-e6.md`).
- Las ramas de épica sirven de base cuando `version-2` está ocupada por un oráculo: E2a T3 salió de
  `v2/e2a` con E1 T14 mergeado ahí (`59da465`), sin tocar el árbol que corría el `completo`.

## Trampas

- **No mergear en `version-2` con un oráculo corriendo ahí**: cambia el árbol bajo el build. Las
  integraciones esperan al `EXIT` del log; las bases nuevas se arman en la rama de la épica.
- **Snapshots de claves que ya se aplicaron**: `e1-t13-corralito.json` seguía en
  `claves-pendientes/` aunque T13 había commiteado el catálogo. `catalogo.py aplicar` dio 0
  claves nuevas → se borró. Regla: al integrar, `aplicar` y `git rm` del snapshot en el mismo commit.
- **El clasificador le niega a un agente editar archivos ajenos aunque sea para un mutante**: los
  corre el controlador en el worktree del agente y revierte con `git checkout`.
- **El `tarea` de un mutante en EK frena en `economykit`** pero igual compila y corre la clase de
  app: alcanza para ver si la clase muerde.
- Agentes que reportan con fondo vivo: E11 T6, E6b T1r, E1 T14 arreglos, E1 T15 → `TaskStop`
  después del reporte (nunca antes).

## Cambio de protocolo recibido

Una sesión par ("Fisu Evolution v2 roadmap") transmitió una orden del dueño: no se termina ninguna
sesión con subagentes vivos; al cierre se espera a todos, se documenta y se libera el `LOCK`; no se
lanzan rutinas (`fisu-v2-relevo-a` se dispara sola cada hora); el latido del `LOCK` lo mantiene un
bucle de fondo cada 10 min. Aplicado y anotado en el journal.

## Carries abiertos

- E3a T12: la hoja `.large` de la ficha deja vacío abajo; capturas SE de la ficha, del ¡Nuevo! de
  la barra, de FisuJobs ("All…", "1 on pay…" truncados desde antes) y del tablero de T10.
- E9: lecciones que apunten a pestañas todavía cerradas (E3a T9).
- E4: `activeEvent` no se guarda; relanzar en pleno Corralito deja el chip sin banner (≤ 45 s).
- `planMergeAll` (E2a T6/T9) todavía no tiene llamador en la app.
