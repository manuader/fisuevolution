# SESION 2026-10-09 — v2, relevo 22: compartir recableado, la privacidad del ranking, las familias en el catálogo y el motor de visitantes

La ola T. El relevo 22 arrancó a las 22:03 con el disparo horario de la rutina `fisu-v2-relevo-a`: el `LOCK` estaba libre (el 21c lo soltó a las 21:47), la cuota
en 5 h 8 % y semanal 54 %. Controlador opus; implementadores sonnet en worktrees manuales (`worktrees.nosync/v2i-<tarea>`); revisión opus para E3b T9 y E6a T1 (las
dos tocan el save o dinero). Todo pasó por **`v2i/integ-r22`** (BASE `version-2` en `e25df6c`, que ya traía el paso de fast-forward del 21c). Carga de la máquina: 1,8 →
265 → 232 → 154 → 10; tope de 2 compilando cuando pasaba de 200 (el `rapido` cuenta). Cerró a 268k de contexto, por debajo del umbral de 300k pero sin margen para otra ola.

## Dónde quedó

| Qué | Estado |
|---|---|
| `version-2` | la punta de `9cccaf6` tras su `rapido` VERDE (fast-forward y push; progreso 159 de 254) |
| `v2i/integ-r22` | **`8ab8b33`**: suma E4a T6, E4a T7 y E6a T1 (🟢 las tres) sobre `9cccaf6` |
| `rapido` sobre `8ab8b33` | VERDE (EK 735 · unit 1143 · 0 rojos · Release 0) |
| Progreso | **159 de 254 en `version-2` (62,6 %)**; **162 de 254 (63,8 %)** si el `rapido` sobre `8ab8b33` da VERDE (`tasks.md` §2) |
| Bloqueadas | ninguna nueva. E7b-a T3 sigue ⛔ por sus dependencias y es **bloqueo de publicación** (sin cambios desde el 21c) |

`rapido` de la tanda, en orden: `a0e7255` **ROJO** (unit 1128/1: `SkinCatalogRowsTests`, ver «El rojo del rapido»); `ddea816` VERDE (EK 654 · unit 1136 · 0 rojos ·
Release 0); `9cccaf6` VERDE (EK 708 · unit 1136 · 0 rojos · Release 0); `8ab8b33` VERDE (EK 735 · unit 1143 · 0 rojos · Release 0).

## Lo que se integró

| Tarea | Commits | Oráculo y revisión | Desvíos |
|---|---|---|---|
| **E6b T9** las tres familias entran | `b9e2cd0` | tarea VERDE (unit 56); `FamilySkinsContentTests` 3×3; diff leído (mecánico) | 129 entradas en `skins.json`, id = familia, 450 ORO, atlas `fam_*`. Los tres atlas ya estaban en el bundle desde E8 (+48 MB compilados): esta tarea no cambia el peso |
| **E12 T15** Privacidad, Términos y notas a App Review | `700c02a` + `a223c0b` | tarea VERDE (unit 13); `PrivacyManifestTests` 4; diff leído. DONE_WITH_CONCERNS | `PrivacyInfo.xcprivacy` suma DeviceID y OtherUserContent, sin vínculo ni tracking; `terms`/`privacy` es+en con el ranking (copia en `Distribution/site`, cubierta por `LegalDocumentTests`); `app-review-notes-e12.md`. Carries abajo |
| **E3b T9** compartir recableado | `2189a09` + arreglos `c8af0ca` | tarea VERDE (unit 106 → 33 tras los arreglos; EK 654); `ShareMomentUITests` 2/2; revisión opus: Approved con arreglos, hechos | `GameState+Share` nuevo, `ShareMoment`, `ShareMomentChip`; `EngagementState.sharedMoments` con default, decodificación tolerante y `resolve` por unión; enganche de piso nuevo en `+TowerSync`; `shareCardMoment` en `boardIsCovered`; 6 claves. Los arreglos: `lifetimeEarnings` en el premio, comentario de `BoardScene:1534`, la X cierra la lección |
| **E4a T3** los relojes en `meta.engagement` | `938efcb` | `SaveMigratorTests` + `PersistenceTests` VERDE (34); EK 662; diff leído (EK puro, 4 archivos, copia del plan) | `VisitorsState` y `EventsState` nuevos; `EngagementState` suma `visitors`/`events` (init, decode tolerante, `resolve`: relojes del ganador, cooldowns max, topes del día max si es el mismo día) |
| **E4a T4** el motor de eventos v2 (EK) | `9db72db` | EK 686; sin revisión (copia del plan, archivos nuevos) | `EventCatalog`/`Scheduler`/`Planner` + 24 tests, código del plan tal cual |
| **E4a T5** los visitantes, puros | `7f51f23` | EK 679; sin revisión (copia del plan) | `VisitorsConfig` + `VisitorScheduler` + 17 tests, tal cual |
| **E5a T4** paquetes, colchón y ruleta en `meta.engagement` | `c00943c` | EK 708 con las anteriores | dueña de `EngagementState` en su ola |
| **E4a T6** `VisitPlanner` | `d37ab28` | `BoardChangeWiringTests` VERDE; EK 720; diff de la app leído (2 casos exhaustivos) | `Origin.visitor` en `BoardChange`; `+BoardChanges`: `discard` e `isPrepaid` exhaustivos con `.visitor = false` |
| **E6a T1** tienda y ofertas en `meta.engagement` | `229579f` + opcionales `f52c803` | `SaveMigratorTests` + `PersistenceTests` VERDE; 13 tests nuevos; EK 723; revisión opus: Approved. DONE_WITH_CONCERNS | `ShopState` y `OffersState` en EK, dentro de `EngagementState`. Desvíos en `resolve`: oferta abierta descartada si el perdedor la cerró o la compró; ×3 pendientes = máximo. Opcionales: sin `boughtElsewhere` (falso positivo), cupo del día mayor, comentario del ×3 |
| **E4a T7** el contenido de los visitantes | `9eb8efd` (merge `7235665`, claves `8ab8b33`) | tarea VERDE (unit 47); diff leído (contenido) | `visitors.json`: 18 visitantes y 26 guiones del Anexo A; `GameContent.visitors` validado contra `specials.json`; `VisitCopy`; `VisitorsContentTests`; 81 claves. Coach con 67 toques en el test; `bug_reinicio` vuelve a la frase del Anexo |

Merges en `integ-r22`: E4a T3 `cbbac5d`, T4 `2b500a1`, T5 `5167e7e`, E5a T4 `612a375`, E4a T7 `7235665`. El Anexo A de `tasks.md` §6 lo aprobó el dueño antes de despachar T7.

### El rojo del rapido: `SkinCatalogRowsTests`

El primer `rapido` de la tanda (`a0e7255`, E6b T9 + E12 T15) dio ROJO unit 1128/1. No era el juego: `SkinCatalogRowsTests.baseComesFirstAndStartsEquipped` pineaba
las filas del Fisura **sin las tres familias** y E6b T9 las agranda a propósito (129 entradas). Lo arregló el controlador (`ababa57`, sólo el test; tarea
`SkinCatalogRowsTests` + `FamilySkinsContentTests` VERDE 13/0). Ante un
rojo del `rapido` después de una tarea de contenido, mirar primero qué test cuenta filas del catálogo que la tarea agrandó.

## Las revisiones opus y sus carries

- **E3b T9** (Approved con arreglos, hechos en `c8af0ca`). Obligatorios: `lifetimeEarnings` en el premio y el comentario de `BoardScene:1534`; opcional: `dismissShareOffer`
  cierra el globo `.share`. **Al dueño:**
  - La **oferta de compartir descartada se pierde** (no vuelve a ofrecerse ese momento).
  - Puede **gastar sus 10 s detrás del intersticial** de `celebrationsDrained`, y el jugador nunca la ve → E7b-a T3.
  - El **premio de reencarnación es casi nulo**: son 5 minutos de la run nueva.
- **E6a T1** (Approved, sin obligatorios; EK 721 al revisar). **Al dueño:**
  - Una oferta abierta **sólo en el save perdedor** (la Bienvenida, por ejemplo) **se pierde para siempre** al cruzar dos dispositivos: ¿debería sobrevivir?
  - Un ×3 pendiente que reaparece (misma política que `chestsPending`; el arreglo pide ids por compra) se **regala** en el caso raro: ¿se acepta?
  - **A E6a T2/T10 (EK, salen de T1):** marcan `lastClosedAt` en toda compra y vencimiento.
  - **A E6a T11:** acreditar la compra aunque la oferta ya no figure abierta.
  - **A E9b T7:** `resolveAcrossReset` no cruza `engagement.offers`.
- **E12 T15 (carries a E10 y al dueño):**
  - `NSPrivacyTracking` sigue en `false` (de antes) aunque haya AdMob y ATT: **decidir con el dueño** antes de enviar (E10).
  - La nota a App Review **no da atajo al revisor** para ver el ranking (con `baseURL` nulo la pestaña no existe en producción).
  - La política de privacidad **no nombra al proveedor de IA** que modera los nombres.
- **E4a T6 → E4b T2 / E4a T9:** `.visitor` **no es prepago**: una visita pagada con video que se descarte no se compensa.
- **E4a T3 → E4a T9:** el reset de debug (`debugResetSave`) **no limpia `visitors` ni `events`**.
- **E4a T7:** carga el Anexo A con los guiños (Coach 67 toques, Crypto Bro «six seven», Vecina «andá pa' allá, bobo»; PLAN-v2 §2).

## Las trampas de la tanda

- **`setsid` no existe en macOS.** Para lanzar el oráculo desacoplado del shell del agente:
  `nohup perl -e 'setpgrp(0,0); exec @ARGV' bash <ruta>/Tools/v2/oraculo.sh rapido > build/<log> 2>&1 &` y esperarlo por PID o por la última línea del log.
- **Las tareas de EK puras no compilan la app.** Se verifican con `swift test` en `Packages/EconomyKit` y **no ocupan cupo de compilación**: en esta ola E4a T4, T5 y
  E5a T4 corrieron juntas mientras el `rapido` ocupaba el único cupo. Las despachó el controlador con «sólo `swift test`» en el brief.
- **Un rojo del `rapido` puede ser un test que pinea un catálogo que la tarea agrandó a propósito** (`SkinCatalogRowsTests`): antes de culpar al juego, mirar si el
  test cuenta filas.
- **El `rapido` va uno por vez.** Mientras corre, `version-2` no recibe merges: las tareas EK terminadas esperan en su worktree hasta el VERDE y se mergean juntas.

## Para el dueño

- E3b T9: ¿se acepta que la oferta de compartir descartada se pierda? ¿y los 10 s detrás del intersticial (se resuelve con E7b-a T3)? ¿el premio de reencarnación de
  5 minutos?
- E6a T1: ¿una oferta abierta sólo en el perdedor sobrevive al cruce? ¿el ×3 regalado en el caso raro?
- E12 T15 / E10: `NSPrivacyTracking` en `false` con AdMob y ATT; sin atajo para el revisor; la privacidad no nombra al proveedor de IA.
- Sigue lo del 21c: **no publicar E7b-a T2 sin T3**; `canRequestAds`; verificar el *fill* del app open en device; capturas de iPad a ASC; los escenarios de E11/E2a/E8c
  a mano. Los 🔒: credenciales de Supabase y `ANTHROPIC_API_KEY` (E12 T16), mediación por SPM (E7b-a T6).

## Oráculo

- `rapido` sobre la punta de `integ-r22` (`8ab8b33`: E4a T6, T7 y E6a T1 sobre `9cccaf6`): VERDE (EK 735 · unit 1143 · 0 rojos · Release 0).
- Sin `completo` en esta tanda. Los cierres que lo piden (E8 T10 `--limpio`, E13b T11) quedan para el 23; E12 T15 y E6b T9 se integraron con `tarea` + `rapido`, no con `completo`.

## Lo descartado

- Despachar E7b-a T3: sigue ⛔ (faltan E4a T8 ✅, **E5a T6, E5b T1, E4b T3**, E1 T14 ✅ en su fila).
- Más despacho tras los 268k de contexto: se terminaron E4a T7 y la revisión de E6a T1 y se cerró.

## Cierre

- Subagentes en vuelo: los marca el controlador. `LOCK`: lo libera el controlador.
- Worktrees: se borró el de cada tarea al integrarla (≈ 4 GB de los EK, 1,6 GB el de E3b T9); quedan por barrer `v2i-integ-r22` y `v2i-docs-r22` (con el shell fuera) y
  los anteriores si no se barrieron.
