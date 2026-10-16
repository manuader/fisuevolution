# Sesión 2026-10-16 — relevo 61: la 2.0 sin trabajo de agentes; la 2.1 en las olas 3 a 5 (31 de 42)

Relevo despertado por la rutina horaria (candado libre, cuota 5 h 3 %). La 2.0 estaba al 100 % y subida (`version-2` = `eb5efe3b`, código del
build 7 `50e34c33`, VALID en ASC): lo que queda es del dueño, igual que en el handoff del 60. Por la orden del dueño (DUENO 2026-10-16) el relevo
siguió con la **2.1** en su rama `version-2.1`, con agentes con nombre y **sin compilar por tarea**: sólo los verificadores de cada ola compilan.

## Resultado en una línea

`version-2.1` avanzó por fast-forward `c633fa96` → `62e50cb0` → `657b8182` → `15451961` → `e57ef592` (el tablero). La **ola 3** quedó verificada con la
2.0 final mergeada adentro; las **olas 4** (F1-T7, F2-T6, F2-T7, F2-T8, F3-T4, F3-T5, F5-T3) y **5** (F2-T4, F3-T6, F3-T7, F7-T2) se hicieron,
integraron y verificaron. La 2.1 está en **31 de 42**. Queda **F2-T5** y después la ola 6. La 2.0 no cambió.

## Qué entró

- **Ola 3 verificada** (`v21-verif-ola3`, `62e50cb0`): merge de la 2.0 final sin conflictos; `rapido` VERDE a la primera (EK 1245 · unit 2366 · Release 0);
  UI del DebugPanel 11/11; pacing por defecto 45,40 h · 6 (= 2.0); matriz OK salvo C3·3 (low ≤ base es imposible con `acceptRate` distintos).
- **Ola 4** (7 tareas, opus, sin compilar), integrada sin conflictos. Revisión del controlador: F5-T3 había sacado de la Tienda de la 2.0 el
  `.disabled(purchasing)` (la única excepción admitida de la gramática) y se **restauró**; la 2.1 sólo suma la cinta.
  - F2-T7 `GameContent.applying(levers)` y `GameState+SegmentLevers`; F2-T6 `RewardDouble.multiplier` (×2 mínimo siempre) y botón «×2,5 con video»;
    F2-T8 `ForcedAdsPacer.spacingScale` (sólo agranda); F5-T3 señales con segmento, Bienvenida sólo `nonBuyer`, `OfferNotice` en la UE.
  - F3-T4 los momentos en el simulador (peor caso); F3-T5 `GameState+Moments` y `MomentOffer`.
  - F1-T7 privacidad: borrador de 6 bloques (nota App Review 3994/4000, 8 preguntas al abogado), `PrivacyInfo.xcprivacy` y `PrivacyManifestTests`.
- **Ola 4 verificada** (`v21-verif-ola4`, `657b8182`): EK 1253 · unit 2431 · Release 0 · UI 18/18 (26.5) + 5/5 StoreKit (18.6) · pacing 45,40 / 6.
- **Ola 5** (4 tareas), integrada sin conflictos: F2-T4 (contrato de ritmo por segmento en CI, `PacingFixture` con `playerSegment`, C3.3 redefinido
  como high ≤ mid ≤ low), F3-T6 (`MomentOfferCard`), F3-T7 (`BanditStore`, el bandido aprende), F7-T2 (`admin.sql` 21–28 y `Tools/v21/panel.sh`).
- **Ola 5 verificada** (`v21-verif-ola5`, `15451961`): EK 1253 · unit 2456 + 1 known issue · Release 0 · UI 6/6 · matriz C3 verde con y sin `--caps`
  (high .ads 30,40–31,40; con caps 30,86) · SQL 67.

## El determinismo del simulador (también toca la 2.0)

El simulador **no era determinista**: `IncomeTicker.basePassivePerSecond` sumaba en el orden de un `Dictionary`, y el sim daba `.ads` 31,71 o 32,19 h
según el proceso, **también en la 2.0**. Se arregló en la 2.1 con una suma ordenada por id (`af1165d2`; sólo cambia el orden de la suma; la 2.0 por
defecto sigue en 45,40 h · 6). Conviene llevarlo a la 2.0 en su próxima versión (no hace falta ahora: el build 7 ya salió).

## Qué queda de la 2.1 (en orden)

1. **F2-T5**, la calibración de `segments.json` y de los topes. Corre `pacing-sim` (con habilitación del controlador). Tiene dos cosas en `withKnownIssue`:
   el **presupuesto de visitantes** (con los topes `high` del código cobra ≈79 min/día contra ≈52,8; hace falta multiplicador o escala ≤ ≈2,17) y **dos
   pares de C3.3** (low `.ads` 0,25 y high `.ads` 1 contra la base: caos del sim, ±1 h según la semilla; necesitan tolerancia o más semillas).
2. **Ola 6**, el build único: F1-T8, F2-T9, F3-T8, F5-T4 en un solo `completo` + `supabase/test.sh` + `pacing-sim --segment-matrix`.
3. **🔒 del dueño de la 2.1:** P2 (valores de F2-T5), P3 (privacidad; cinco decisiones abiertas del borrador de F1-T7: apagado fuera de UE/UK/CH, borrar el
   cálculo local al retirar el consentimiento, Device ID sin personalización, Bienvenida oculta a compradores no-base, y el resto de las preguntas al abogado),
   P8 (textos nuevos de F2-T6, F3-T6, F5-T3) y **C3.3 redefinido** (high ≤ mid ≤ low). La 2.1 sale apagada por el interruptor remoto hasta la revisión legal.

## Trampas nuevas

- `limpiar-worktrees.sh` necesita **ruta absoluta**; con una relativa no hace nada.
- Su chequeo de «hay procesos adentro» compara por prefijo (`grep -F "/$name"`): `v21-integ` da falso positivo contra `v21-integ5`. Se reintenta al cierre.
- El sim no es determinista si algo suma en orden de `Dictionary`: ordená por id antes de sumar.
- Un agente puede quitar una excepción «admitida» de la 2.0 si el brief lo empuja (F5-T3 y `.disabled(purchasing)`): revisar el diff contra la gramática.
