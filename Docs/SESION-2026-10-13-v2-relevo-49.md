# SESION 2026-10-12/13 — relevo 49: la calibración de 45 h, la mediación, y la primera ola de E14

Relevo en vivo con el dueño (sesión `local_af675368…`). Arrancó al responder el dueño el playtest de precios; los relevos 39–48 habían cerrado sin trabajo esperando esa respuesta. Integración en `v2i/integ-r49`; briefs y `comun.md` de la ola en `.claude/avo/2026-10-06-fisu-v2/ola-r49/`.

## Lo que pidió el dueño

1. **El playtest de precios, cerrado con una decisión:** el juego más difícil y más largo, **Dios en ~45 h** (antes ~31), porque los videos, los anuncios y las ventajas de la 2.0 lo acortaban. La curva y el amortiguador los elige la calibración. Contrato nuevo en `tasks.md` §7 «2026-10-12».
2. **Seguir hasta el 100 %** y juntar lo suyo al final.
3. A media sesión: **E14 cerrada y mergeada** (sesión paralela del dueño) con prioridad absoluta; **E14 T29 (C32) crítico y primero**; E8e T10a–f salteadas por C22; E12 T16 lo hace la otra sesión (no tocar); el arte de E14 aprobado completo.
4. Al final: cerrar el relevo al terminar lo planteado, para que siga un agente con contexto fresco.

## Qué entró

| Tarea | Commit (merge en integ) | Qué |
|---|---|---|
| E2b T12 | `53cd1a77` (`42c5a9b9`) | 75 corridas de las mecánicas contra el contrato de 45 h |
| E2b T13 | `4f8a64c1` | Búsqueda AVO (208 corridas): la candidata de 45 h |
| E2b T14 | `6c702730` (`2e70dd83`) | La calibración declarada y el contrato prendido (4 asserts provisorios) |
| E2b T15 + E10 T10 | `f2ae865a`, `fe85e5e9` (`daf0bd7c`) | Cierre de E2b; `balance-log.md` «2.0 — la calibración declarada» |
| E12 T12 | `e1cd5d28` + `347491a0` (`0ca87d4c`) | El reset abre un intento nuevo del ranking; el reloj arranca al terminar el núcleo |
| E7b-a T6 | `db38542b` (`24fce67d`) | Mediación Unity 4.21.000 + Meta 6.22.000 por SPM, SKAdNetwork 89, Ad Inspector |
| E7b-a T7 | `c96ab82b` | Cierre de E7b-a: **E7b cerrada** |
| E10 T14 | — (⏭) | B22 no hace falta: Meta declara su rastreo en su propio manifiesto |
| fix-placa | `a11ad877` (`655d55c8`) | `debugUnlockFloors(.max)` colgaba el arranque con la escalada por bandas |
| fix-fban | `4439eeb3` (`803f8b63`) | La app Debug no arrancaba fuera de Xcode (rpath pisado en `project.yml`); `app verify` lo chequea |
| E14 T7 | `37af4e22` (`98661314`) | ORO → dólar blue: 46 claves (snapshot + `.quitar`) y Distribution en 3 idiomas |
| E14 T29 | `bdbdf54f` + `66d762ee` (`441668a5`) | **C32 crítico:** el video del boost, una vez por ciclo; el mismo boost renueva, no multiplica |
| E14 T5 | `08b2bfcf` (`5640d384`) | Fast Food ↔ Chofer de App (tiers 7↔8) y el save v7 con migración por posición |
| E14 T9 | `bb32b1d0` (`1186d84e`) | Componentes base: `GameButton`, `PopupContainer`, `RewardIllustration`, estados, `CornerSeal` |

## La calibración de 45 h (E2b)

Perillas declaradas: g 1,11 · r 1 · K 12; bandas `[(8,1.7),(13,2.0),(17,2.2),(21,1.9),(25,1.6),(29,1.3),(33,1.0)]`; escalón 0,03 desde `luxury`; `oro.divisor` 8e11; capacidad 15; `baseCost` 2 en las 6 líneas (348 redondeado); logros de ORO ×2 (66); colchón cada 720 s con el ORO en peso 5. Resultado: **Dios 45,40 h activas · 6 reencarnaciones · 1ª a 1,67 h · `.ads` 69 % · `.max` 66 %** (tres semillas). `completo --limpio` de `2e70dd83`: EK 879 · unit 1774 · Release 0 · pacing 45,40 h.

**Preguntas al dueño (asserts provisorios):** punto 5 «antes» (≤ 15 tiers más tarde), punto 6 (reencarnar paga 18–38 % contra ≥ 65 %), island 241 contra 270–410 (y moon en una semilla), punto 8 (sin reencarnar llega a 2,39× Dios), y el colchón a 720 s. Detalle: `Docs/SESION-2026-10-12-v2-e2b.md` §5.

## Decisiones del controlador

- E12 T12 y E7b-a T6 estaban ⛔ por inercia: sus dependencias estaban hechas, y la mediación era un pedido del dueño, no un 🔒.
- Tras un reset, el reloj del ranking arranca al terminar el núcleo, igual que en una instalación nueva.
- B22 cerrado sin dominios: la app no rastrea; el SDK de Meta se declara solo.
- El catálogo de E14 lo vuelca T26 (regla del plan de E14): T7 y T9 dejaron sus snapshots.

## Trampas nuevas

- **Un fixture de debug con `Int.max` como frontera cuelga cualquier cálculo que itere por tier** (la escalada por bandas recorre `2...frontier`). Los fixtures recortan al `maxTier` del contenido.
- **Un override de `LD_RUNPATH_SEARCH_PATHS` en una config de `project.yml` pisa el preset de XcodeGen** (`@executable_path/Frameworks`): la app Debug no arranca fuera de Xcode si algún framework del paquete es dinámico. `releaseops app verify` lo detecta.
- **`.claude/worktrees/version-2` es el mismo directorio que `.claude/worktrees.nosync/version-2`, y otra sesión lo puede tener en otra rama.** Se promueve `version-2` por ref (`git push origin v2i/integ-rNN:version-2`), sin tocar ese worktree; el `Package.resolved` de las tareas se copia del de la integración.
- **La palabra «seguimiento» en una fila de `tasks.md` la saca del conteo** (`grep -vc seguimiento`).
- **Con la máquina sobre ~700 de carga, `oraculo.sh tarea` falla porque el simulador no bootea en 60 s:** no es un rojo; se corre a mano o se reintenta.

## Carries abiertos

- **E14 T29:** `grant()` de `GameState+Rewards` sigue sumando el mismo premio (tienda del blue `income_x2/x3`, `package_rain` hasta ×10⁵, `skip_cooldowns` sin tope diario; ruleta, visitantes, ofertas, tesoros, pausa). B2/B5 aceptaron multiplicar boosts distintos y repetir en la ruleta; `package_rain` y `skip_cooldowns` sin tope son preguntas al dueño. El UI test nuevo de `BonusHUDUITests` no tiene RED visto.
- **E14 T7:** el ícono de la moneda (`GameArt`) y la cinemática de reencarnación con monedas de oro; subir los textos a ASC.
- **E14 T5:** `CustomizationUITests.landingType` cambió a `chofer_app` (corrido en la verificación del cierre).
- **E14 T9:** las capturas de la galería quedaron en el `build/` del worktree (borrado); se rehacen con `--debug-componentes`.
- **E12 T17:** `minRealSecondsToGod` no existe todavía en el repo.
