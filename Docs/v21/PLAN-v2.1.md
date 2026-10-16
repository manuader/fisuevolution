# FisuEvolution 2.1 — Plan: E15 «Valor por jugador», F1–F7

**Estado:** plan del equipo de la 2.1 (relevo 60, 2026-10-16), con las decisiones del dueño del mismo día (§0). Rama
`v21/plan` → `version-2.1` (la integra sólo el controlador). Nada de esto entra a `version-2` ni a `v2i/integ-r59`.
**Spec madre:** `Docs/PLAN-v2-E15-valor-por-jugador.md` (V1–V3, §4, §5, §7 y guardarraíles: **no se re-litigan**).
**Investigación:** `Docs/v21/investigacion-R1-R8.md` (R1–R8 hechas; lo que no tiene fuente está marcado `[SUPUESTO]`).
**Planes por tareas:** `Docs/superpowers/plans/2026-10-16-v21-e15-f1.md`, `-f2.md`, `-f3.md`, `-f5.md` y
`-f4-f6-f7-andamiaje.md`. **Tablero:** `tasks-v21.md` (raíz).

---

## 0. Decisiones del dueño (no se vuelven a preguntar)

Las de la spec (V1–V3) siguen. Las del 2026-10-16, en vivo, sobre las 9 preguntas de la investigación:

| # | Decisión | Qué cambia en el plan |
|---|---|---|
| V4 | **Sin MAX en la 2.1:** AdMob + Unity. | F3 usa «hay un video cargado» + el promedio del ledger del jugador; no hay «anuncio caro cargado» (R2). |
| V5 | **Sin exportes de AdMob ni de ASC por ahora.** | F1 sale con la **tabla semilla** de tiers públicos (F1-T2). La receta de `networkReport` queda para después de lanzar (F7-T4). |
| V6 | **Sin pedir la API `mediationGroups` ni OAuth.** | F4 = herramienta de plan en dry-run (F4-T1) + **receta manual** post-lanzamiento (F4-T2/T3). |
| V7 | **Piso del segmento alto: 30 h, con el ×2,5 acotado por fuente.** | G1 y F2-T5: el ×2,5 sólo en las fuentes donde el peor caso sigue ≥ 30 h. |
| V8 | **Sí al aviso «Oferta elegida para vos» en la Tienda de la UE.** | F5-T3: el aviso sale en los storefronts de la UE (lista en el código). |
| V9 | **Para segmentar se exigen los propósitos TCF {1, 5, 6, 8, 9, 10}**; sin ellos, la base. Sólo en la 2.1 (F0 sigue con los suyos). | `PersonalizationConsent` (F1-T4). |
| V10 | **No se pide edad.** Sin consentimiento o con señal de menor, la base. | `PersonalizationGate` (F1-T4). |
| V11 | **Sin abogado por ahora.** Lo legal queda `[VERIFICAR CON ABOGADO]` y **la personalización sale APAGADA** por el interruptor remoto hasta esa revisión. | Gate 🔒 explícito **V21-F1-T9** y G7: `personalization_enabled` no se prende sin él. |
| V12 | **Corregir la frase de §5 de la spec sobre App Store 5.6.** | Hecho en este commit: 5.6 es el Código de Conducta (conducta engañosa reiterada), no habla de dificultad. |
| — | **Regla general:** nada que implique pagar ni trámites que demoren la 2.0. | Nada de la 2.1 frena el lanzamiento de la 2.0; todo lo que pide un trámite queda post-lanzamiento o 🔒. |

---

## 1. Alcance

La 2.1 es **una sola épica: E15 F1–F7** (F0 ya está en la 2.0: ledger de impresiones, embudo de ofertas, telemetría
apagada en tres capas, privacidad). Nada más entra en la 2.1 sin pasar por el dueño.

| Fase | Qué es | Plan | Tareas |
|---|---|---|---|
| **F1** | VEJ v1 con reglas: `PlayerValue` en EconomyKit, tablas remotas, interruptor, consentimiento, telemetría del segmento, borradores de privacidad, gate legal | `-f1.md` | 9 |
| **F2** | Palancas de ayuda por segmento con topes (`segments.json`), pacing-sim por segmento en CI | `-f2.md` | 9 |
| **F3** | Momento justo: detectores de necesidad natural + video cargado + oferta a la vista + bandido Thompson | `-f3.md` | 8 |
| **F4** | Pisos de eCPM por país en los grupos de mediación de AdMob | `-f4-f6-f7-andamiaje.md` | 3 |
| **F5** | Ofertas de Tienda por segmento (qué oferta ves, nunca el precio), con aviso en la UE | `-f5.md` | 4 |
| **F6** | VEJ v2: modelo de árboles entrenado afuera, evaluado en el teléfono, A/B contra F1 | `-f4-f6-f7-andamiaje.md` | 5 |
| **F7** | Panel: valor por segmento, conversión por oferta, D1/D7, ritmo real contra el simulado | `-f4-f6-f7-andamiaje.md` | 4 |
| | | **Total** | **42** |

---

## 2. Qué se construye ya y qué espera datos reales

La 2.0 todavía no salió: **no hay ni una impresión de producción**, y no hay informe de eCPM por país de la v1 (R3, V5).
Todo lo que sea *código con contrato y tests* se hace ahora; todo lo que sea *un número que sale de medir* se cierra
después de lanzar.

| | Se construye ya (reglas, tablas remotas, andamiaje) | No se puede cerrar sin datos de producción |
|---|---|---|
| **F1** | `PlayerValue` determinista, tablas con validación, cargador remoto, consentimiento (V9), compuerta (V10), servicio, eventos de telemetría | **La tabla de países propia** (V5: receta post-lanzamiento) y **los umbrales de segmento** (percentiles reales). Sale con la **tabla semilla** |
| **F2** | Tipos, topes, sim por segmento, contrato en CI, palancas cableadas, calibración inicial con el sim | Recalibrar con la conversión real de cada segmento (el sim supone el peor caso) |
| **F3** | Detectores, planificador, frecuencia máxima, bandido con priors planos y brazo de control, tarjeta | **Los priors de los brazos** y **el límite de retención** (D1/D7 por brazo contra control), de F7 |
| **F4** | La herramienta del plan de pisos (dry-run) | **Todo lo demás** (V6): aplicar a mano y medir |
| **F5** | Audiencia por oferta, pack destacado, aviso UE, cableado | Ver si la oferta segmentada convierte mejor que la de todos |
| **F6** | Evaluador de árboles en Swift, contrato de features, A/B, scripts de entrenamiento | **Entrenar** (R8: 5–10 mil jugadores etiquetados ≈ 17–33 mil instalaciones), validar y prender por A/B |
| **F7** | Vistas SQL, consultas de `admin.sql`, priors del bandido y guardián de retención | **Leer el panel** y fijar los umbrales de los guardianes |

**Consecuencia:** la 2.1 se puede publicar con F1, F2, F3, F5 y los andamiajes **con el interruptor apagado** (V11), y
prenderse en etapas con `admin.sql` cuando estén la revisión legal (V21-F1-T9) y los textos aprobados. El binario no
depende de los datos: depende de que las tablas remotas existan y validen.

---

## 3. Decisiones de diseño (defaults del planificador)

1. **El VEJ es local.** Se calcula en el teléfono con datos propios del teléfono (ledger de F0, compras, sesiones, país
   de la tienda, modelo). No hay perfil por instalación armado en el servidor (R5: 5.1.2(iii)). Sube, con el
   consentimiento de la telemetría, el segmento asignado (evento `segment`, sólo al cambiar) para el panel. **Riesgo
   anotado:** la investigación lee 5.1.2(iii) como «el servidor no recibe un puntaje por jugador» y a la vez propone el
   evento `segment` (R4): queda `[VERIFICAR CON ABOGADO]` en V21-F1-T9, junto con el entrenamiento de F6.
2. **Segmentos:** `base` (sin personalización: interruptor apagado, sin consentimiento, señal de menor, tablas
   inválidas, UI test sin flag), `low`, `mid`, `high`. `base` es **exactamente** el juego de la 2.0.
3. **Interruptor remoto a la base (guardarraíl):** `personalization_enabled = false` en `public.settings` del mismo
   Supabase; la config entera (tablas, palancas, brazos) en `personalization_config`, servida por **una** RPC que
   devuelve `null` con el interruptor apagado. Cualquier cosa que no sea una config válida → `base`. Mismo patrón que
   `TelemetrySwitch` (C5 de F0) y `AdsRemoteConfig` (todo o nada; lo remoto no pasa los topes).
4. **Los topes viven en el código:** lo remoto puede ser **menos** generoso que el tope, nunca más; y nunca peor que la
   base (premio por video ≥ ×2; relojes ≤ 1,0× la base; forzados ≥ 1,0× el espaciado de la base). Un archivo que viole
   un invariante se descarta entero.
5. **El segmento es estable en la sesión**, se recalcula al empezar sesión como mucho una vez por día, con histéresis y
   de a un escalón. Vive en `Application Support`, **no en el save** (no toca `PlayerState` ni CloudKit).
6. **Todo lo que cambia para el jugador se ve:** el «×2,5 con video» dice ×2,5 y la tarjeta muestra lo que paga; la
   oferta del momento dice qué da y tiene «No, gracias»; la Tienda marca «Oferta elegida para vos» en la UE (V8).
7. **La oferta del momento reutiliza el bloque `gifts`** con `site = moment.<brazo>` (no se crean unidades en AdMob).
8. **El bandido decide en el teléfono, aprende en el servidor:** Thompson con Beta por brazo; priors globales por la
   config (F7-T3 los calcula del embudo agregado por brazo); el teléfono suma sus observaciones. El límite de
   retención lo aplica F7 apagando brazos en la config.
9. **Eventos nuevos con props cerradas** (`segment`, `exposure`, `progress`, `ctx` en `offer`), en **una** migración
   nueva (regla de O2: cambios al SQL = migración nueva).

---

## 4. Gates de la 2.1

Cada fase cierra con una tarea de verificación del controlador; la 2.1 no se manda a revisión sin todas en verde.

| Gate | Qué | Dónde se mide |
|---|---|---|
| **G1 · Pacing por segmento** (V7) | Con `.free`, **ningún segmento llega a Dios más tarde que la base** (45,40 h; contrato 2.600–2.800 min). Con `.ads` y el `acceptRate` de cada segmento, ídem. Monótono: `high ≤ mid ≤ low ≤ base`. `high` con `.ads`, `acceptRate 1` y **los topes del código** (peor caso remoto): **Dios ≥ 30 h**. `.max` + `high` se reporta. Con el segmento `base` / sin `segments`: idéntico a la 2.0 (`.free` 45,40 · `.ads` 31,39 · `.max` 30,40, semilla 0,5) | `SegmentPacingContractTests` (F2-T4) + `pacing-sim --segment-matrix` (F2-T3) |
| **G2 · Interruptor** | Con el interruptor apagado, sin consentimiento (V9), con señal de menor (V10), con tablas inválidas o sin red: `base` en todo y el juego idéntico a la 2.0 | `PersonalizationGateTests`, tests de identidad de cada palanca, UI con `--uitest-segment base` |
| **G3 · Revisión opus** | Toda tarea que toque plata, anuncios, save o privacidad: modelo opus y revisión opus. Al cierre, revisión opus del diff entero contra `version-2` | revisión |
| **G4 · Nada falso** | Ningún número mostrado distinto del pagado; ninguna dificultad peor que la base; toda oferta opt-in y con «No, gracias»; ningún momento fabricado | revisión opus + tests de pago |
| **G5 · Privacidad** | Borradores aprobados por el dueño (🔒 P3) antes de prender; manifiesto con *Product Personalization*; eventos nuevos sólo por la compuerta de F0 | `PrivacyManifestTests`, `TelemetryEventTests` |
| **G6 · Build único por ola** | Los agentes **no compilan** por tarea; el controlador compila y corre todo una vez por ola y corrige en el momento | `oraculo.sh` del controlador |
| **G7 · Revisión legal** (V11) | **`personalization_enabled` no se prende** sin V21-F1-T9 (abogado) hecha. La 2.1 **sí** puede publicarse con el interruptor apagado | 🔒 del dueño |

**El margen de G1 es chico** (R7): `.ads` da 31,39 h con todos los videos aceptados; un ×2,5 en todas las fuentes da
≈ 27,9 h (lineal, `[SUPUESTO]`). Por eso V7: el ×2,5 sólo donde entra, y los topes por fuente los fija F2-T5 con el sim.

**Los visitantes no los juega el bot:** la palanca de visitantes se acota por presupuesto (método de
`RewardBudgetTests` + `Tools/pacing-sim/VisitorRotation.swift`), no por Dios (F2-T4).

---

## 5. Olas

| Ola | Tareas | Por qué juntas |
|---|---|---|
| **1** | F1-T1, F1-T3, F2-T1, F3-T1, F3-T2, F4-T1, F6-T1, F6-T3 | Archivos nuevos y disjuntos (EK puro, SQL, Python, `releaseops`): ningún 🔥 |
| **2** | F1-T2, F1-T4, F1-T6, F2-T2, F3-T3, F5-T1, F5-T2, F6-T2 | Dependen de los tipos de la ola 1; `PacingSimulator*` sólo F2-T2; `admin.sql` sólo F1-T6 |
| **3** | F1-T5, F2-T3, F7-T1, F7-T3 | El servicio (dueño de `FisuEvolutionApp` y `DebugPanelView`), la CLI del sim, las vistas del panel |
| **4** | F1-T7, F2-T6, F2-T7, F2-T8, F3-T4, F3-T5, F5-T3 | Palancas, momentos y Tienda cableados: un dueño por `GameState+*` (ver `tasks-v21.md` §3) |
| **5** | F2-T4, F2-T5, F3-T6, F3-T7, F7-T2 | Contrato de ritmo y calibración (con los momentos ya en el sim), la tarjeta (dueña de `RootView`), el panel |
| **6** | F1-T8, F2-T9, F3-T8, F5-T4 (controlador) | Build único de la 2.1 entera |
| **🔒 / post-lanzamiento** | F1-T9 (abogado), F4-T2, F4-T3, F6-T4, F6-T5, F7-T4 | Revisión legal (V11) / datos de producción |

`Localizable.xcstrings` no lo toca ningún agente: cada tarea con textos entrega
`Tools/v2/claves-pendientes/v21-<fase>-tN.json` y el controlador lo aplica al integrar.

---

## 6. 🔒 Del dueño (nada de esto lo hace un agente)

| # | Qué | Bloquea |
|---|---|---|
| **P2** | Aprobar los valores de `segments.json` y los topes por fuente que salgan de la calibración (V3 + V7) | prender F2 |
| **P3** | Aprobar los borradores de privacidad y términos de la personalización (F1-T7) y la etiqueta de ASC (*Product Personalization*) | prender F1–F5 |
| **P4** | Aplicar las migraciones nuevas en Supabase (config de personalización, telemetría de la 2.1, vistas y guardias del panel) | prender; F7 en producción |
| **P5** | Prender `personalization_enabled` por etapas (F1 sólo medir el segmento → F2 → F3 → F5), **sólo después de V21-F1-T9** | todo lo visible |
| **P8** | Aprobar los textos visibles nuevos (ofertas del momento, «×2,5 con video», «Oferta elegida para vos», «Elegido para vos»), con el humor de la casa | F2-T6, F3-T6, F5-T3 |
| **P9** | Interruptor propio en Ajustes («Ayudas a tu medida»): default **no** en la 2.1 (se apaga desde las opciones de privacidad de UMP, como F0) | F1-T7 |
| **P11** | Prender el modelo v2 por A/B y, si gana, para todos | F6-T5 |
| **F1-T9** | **Revisión con abogado** (V11), cuando el dueño la quiera: TCF {1,5,6,8,9,10}, 5.1.1(ii) (¿las ayudas extra cuentan como beneficio atado a dar datos?), 5.1.2(iii) (evento `segment`, entrenamiento de F6), aviso UE (Omnibus), Ley 24.240 y 25.326 (región de Supabase y transferencia), menores en un 12+ | **prender** cualquier personalización (G7) |
| post | Exportes de AdMob/ASC y la receta de `networkReport` (V5), pisos por país a mano (V6) | F7-T4, F4-T2 |

Ya **no** son 🔒 (decididos en §0): MAX (V4), el piso de G1 (V7), el aviso UE (V8), los propósitos TCF (V9), la edad
(V10), la API de AdMob (V6).

---

## 7. Lo que dejó cada R

| R | Resultado | Dónde entra |
|---|---|---|
| R1 | El reel es «plausible, no confirmado»; sólo los 127 M USD tienen fuente. No cambia el diseño. Corrección de 5.6 en la spec (V12) | spec §1 y §5 |
| R2 | AdMob no da el valor antes de mostrar; MAX no probado; pisos por UI; reporting por API | §0 V4, V6; F3; F4 |
| R3 | No hay datos de la v1; tabla semilla + receta `networkReport` post-lanzamiento | F1-T2, F7-T4 (V5) |
| R4 | Faltan `segment`, `exposure`, `ctx` en `offer` (+ `progress` para el ritmo real) | F1-T6 (una migración) |
| R5 | TCF {1,5,6,8,9,10}; VEJ local; aviso UE prudente; sin edad. Todo `[VERIFICAR CON ABOGADO]` | V8–V11; F1-T4, F1-T7, F1-T9, F5-T3 |
| R6 | A/B 7–14 días; retención ≤ 1 punto como límite; subir el premio del rewarded que ya convierte es la palanca de menos riesgo | F2 (dudas), F3, F6-T5, F7-T3 |
| R7 | El piso de 30 h casi no tiene margen; diseño de `PacingSegment` (`acceptRate`, escalas) y guardas de CI | V7; F2-T2–T5 |
| R8 | 5–10 mil etiquetados ≈ 17–33 mil instalaciones; sin fecha (no hay instalaciones/día de la v1); las reglas pueden alcanzar mucho tiempo | F6-T4 |
