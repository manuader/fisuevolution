# Sesión 2026-10-16 — relevo 60: los dos rojos de unit, B34 y su cuelgue, B30 con el sí del dueño, el `completo` de integ-r60 y la 2.1 (olas 1–3)

> **BORRADOR escrito por un agente sin compilar durante el relevo.** Los números los completa el controlador al cierre. Lo marcado con
> `[COMPLETAR]` espera el `completo` de `v2i/integ-r60`, el archive y la subida del build.

Relevo por la orden del dueño al cierre del 59: **agent teams hasta el 100 %**, después instalar y **subir el build a App Store
Connect** (autorizado sólo para subir; mandar a revisión no). Regla vigente: **los agentes no compilan por tarea**; se integra y se
compila la ola entera. Excepciones de hoy, con permiso explícito en su brief: `fix-unit-r60` (sólo `AdPlacementMap`/`QuickHire`),
`fix-ui-r60` (sus clases de UI, con turno y simulador propio) y los verificadores de la 2.1 (`swift test` de EK, sin la app).

## Resultado en una línea

`integ-r59` quedó en **`5b3d2cce`** con los 2 rojos de unit arreglados y los textos finales de tienda (E10 T11); su `completo` dio **EK 1057 ·
unit 2283 · Release 0 · pacing igual** y 6 rojos de UI, que `fix-ui-r60` resolvió. Entró **B34** (el logo de Ader Games) y, con el **sí del
dueño**, **B30** (el tamaño según la distancia) en una integración nueva, **`v2i/integ-r60`** (punta `0c0676b0`), cuyo `completo --limpio` corre
al escribir esto `[COMPLETAR: resultado]`. En paralelo, la **2.1** avanzó tres olas (20 de 42 tareas) en la rama `version-2.1`. `version-2`
sigue en `36697cac` hasta que ese `completo` dé VERDE.

## Decisiones del dueño (en vivo, en este chat)

- **Agent teams = agentes con nombre.** Preguntó por los equipos; verificado: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` está en su
  `settings.json`, pero esta versión no tiene `TeamCreate`: el equipo es implícito de la sesión y un `Agent` con `name` es un compañero
  direccionable por `SendMessage` (entre ellos y con el controlador). Desde ahí todos los agentes se lanzan **con nombre**.
- **No tiene iPhone SE, sólo un 15 Pro.** Decidió: **E8d T15 y E8e T9 se cierran midiendo sólo en el simulador del SE** (iOS 26.5); su
  iPhone no se usa para eso. El número del SE real queda como riesgo aceptado y anotado.
- **Terminar la 2.0 al 100 % en esta sesión y subir el build a ASC** (subir sí; mandar a revisión no).
- **«Trabajá en la 2.1 en una branch aparte con agent teams»:** rama `version-2.1` creada desde integ-r59 (`5b3d2cce`) y pusheada. Alcance =
  E15 R1–R8 + F1–F7 (decisión V1).
- **Las 9 respuestas de las preguntas de la 2.1** («todo lo recomendado, salvo lo que implique pagar o trámites que demoren la 2.0»):
  (1) sin AppLovin MAX: AdMob + Unity, y F3 usa «anuncio cargado» + el promedio del ledger; (2) sin exportes de AdMob/ASC por ahora: F1 arranca
  con la tabla semilla de tiers públicos; (3) sin pedir la API `mediationGroups` ni OAuth: los pisos por país de F4 quedan como receta
  manual para después del lanzamiento; (4) piso del segmento alto **30 h con el ×2,5 acotado por fuente**; (5) **sí** al aviso «Oferta elegida
  para vos» en la Tienda de la UE; (6) **sí** a exigir los propósitos TCF {1,5,6,8,9,10} para segmentar (sin ellos, la base; sólo la 2.1);
  (7) confirmado: no se pide edad y, sin consentimiento o con señal de menor, la base; (8) abogado: **no por ahora** (cuesta plata): lo legal
  queda marcado `[VERIFICAR CON ABOGADO]` y la personalización sale **apagada** por el interruptor remoto hasta revisarlo; (9) **sí** a corregir
  la frase del §5 de E15 sobre App Store 5.6.
- **B30, sí** (02:28): el tamaño según la distancia se mergea a la integración de la 2.0.
- **«Subamos todo junto con la 2.1 si está lista»:** no lo estaba (ola 1 de 6, apagada hasta la revisión legal) → **la 2.0 sale sola**, la 2.1
  sigue en `version-2.1`.
- **B34 (desde el chat «Fisu Evolution v2 roadmap»):** el logo de Ader Games queda **blanco**, el del sitio recortado; no se recolorea. Avisó que
  B32/B33 seguían abiertas: no, se hicieron en el 59 y se marcaron en `DUENO.md`.

## Qué entró

### Los dos rojos de unit (`fix-unit-r60`, opus, `b30ac6fb`)

- `AdPlacementMapTests.everyOfferUsesItsUnit`: faltaba la fila de `GameState+March.swift` (`[.visitor]`, B25) en el mapa del test.
- `QuickHireTagContentTests.longestNameFits`: el botón de compra (B33) con «CARDBOARD COLLECTOR» medía 74,5 pt contra 59,5 en el SE. Ahora
  `QuickHireButton` pone el nombre **arriba en 2 renglones** (caja de 13 pt, escala 0,6) y el test nuevo `everyNameFitsInBothLanguages` lo
  cubre en los dos idiomas. 39 tests de 4 clases verdes. **Carry:** mirar el botón en capturas del SE y del Pro Max con un nombre largo en
  castellano. Mergeado (`5b3d2cce`).

### E10 T11 — los textos finales (`e10-t11-r60`, sonnet, `e0b42c9c`)

`reviewNotes` en 3.949/4.000 con La Marcha (B25) y el colchón gratis (B31), sin Meta; `whatsNew` ×3 (1.405 en-US, 1.459 es-MX y es-ES);
`releaseops validate` VERDE y 44 tests de releaseops. El controlador corrió `asc listing plan` en seco: 3 `whatsNew` y las notas por aplicar,
2 campos manuales (Mac y Vision Pro). **Aplicar es del día del envío, con el dueño.**

### El `completo` de integ-r59 (`20261016-011825`, sobre `5b3d2cce`)

EK 1057 ✅ · build ✅ · unit 2283 ✅ (0 rojos, 822 s) · Release 0 warnings ✅ · store-ui 3 ✅ · iPad 4 ✅ · SE 2 ✅ · pipeline 107 ✅ · pacing Dios
45,40 h / 6 reencarnaciones ✅ · store-unit 17 + 1 rojo (`StoreManagerTests.loadsTheCatalogProducts`: el timeout de StoreKit conocido, a 122 s con carga
85–93) · UI 199 + 6 rojos + 4 salteados: `AppStoreScreenshotTests` ×3 (el colchón no cae, B31; el Ministro no llega), `MarchUITests` ×2 (el chip no abre
el estado; la cobrada deja algo) y `QuickHireUITests.testCambiarDePiso…`. Se mandaron a `fix-ui-r60`. El aislamiento de StoreKit colgó 16 min con
carga 600–680 (3 simuladores, uno de otra sesión: `auditoria-17pro`); se cortó el proceso propio, se borró su simulador y se repite con menos
carga `[COMPLETAR: resultado]`.

### Los 6 rojos de UI (`fix-ui-r60`, opus, `5f813688` → `0c0676b0`)

- **March (×2) era un bug real de Observation:** `player` es `@ObservationIgnored`, así que las vistas que leen derivados de `player` no se
  refrescan; se arregló con una proyección observada (`shownMarch`).
- **Las capturas (×3) eran del fixture:** `--uitest-extra-slots` movía la cámara al piso más alto; ahora restaura `visibleFloorOrdinal` y
  `visitorOnStage` insiste.
- **QuickHire** era del test: faltaban los tipos vistos y el tier (el cambio de piso abre la torre entera y marca los tipos vistos).
- Clases verdes: `AppStoreScreenshotTests` 17/17, `ExtraSlotsLayout` 1/1, `MarchUITests` 2/2, `QuickHireUITests` 4/4,
  `QuickHireTagContentTests` 5/5. `integ-r60` avanzó por ff a `0c0676b0`.

### B34 — el logo de Ader Games (`b34-logo`, sonnet, `2ac58b41`) y su cuelgue (`ce0a5c99`)

Imageset `AderGamesLogo` de 180 pt (blanco, sin teñir: verificado que ni el script ni la vista usan `renderingMode`), `SplashView` arranca
centrado y sube en 0,4 s (con Reduce Motion, fundido), `UILaunchScreen.UIImageName`; el `logo` de `ui.atlas` queda porque lo usa `ShareArt`; test
`launchScreenLogo`. **Al integrarlo, el arranque se colgaba** y todo el UI de integ-r60 fallaba: ver la trampa de abajo. Arreglo `ce0a5c99`
(`fix-ui-r60`): placeholder medido + overlay con el offset, consejo en `@State`; la app arranca.

### B30 con el sí del dueño (`b30-merge`, opus, `ab2f41ad`)

El merge de prueba tuvo 2 conflictos (`PickupController`, `BarFlapLayoutTests`) y se delegó. Resueltos así: `PickupController` conserva B31 y suma la
escala de B30 en el colchón; `BarFlapLayoutTests` queda con la versión de la integración. Sin Meta (la rama era de antes de sacarlo); 3 aserciones
de `PickupControllerTests` escaladas. **Riesgo:** UI tests que miden tamaños o posiciones de los de atrás (hasta 15 % más chicos). `backScale` sigue
en 0,85 y es ajustable.

### El `completo --limpio` de integ-r60 (B30 + B34 + los arreglos, sobre `0c0676b0`)

Se lanzó con la máquina sola (el primer intento cayó al instante: el worktree nuevo no tenía `build/` para el log) `[COMPLETAR: EK · build · unit · Release ·
store · iPad · SE · pipeline · pacing · UI y rojos aislados; qué entró a version-2]`.

### E8d T15 y E8e T9 — las mediciones del SE

Se cierran sólo con el simulador del SE (decisión del dueño). Brief `ola-r60/gates-se.md`; se despacha con nombre cuando la máquina esté libre
`[COMPLETAR: números de fps, memoria con el tope de 3 videos, Reduce Motion, Bajo consumo y ODR]`.

### La subida del build a ASC

Preparada: `asc builds` (sólo GET) dice que el próximo build libre para 2.0.0 es **5**, igual a `CURRENT_PROJECT_VERSION`; `ExportOptions`
con `destination=upload` y la clave de la API en `~/.appstoreconnect`. **Falta el `completo` verde, el archive (E10 T12) y la subida**
`[COMPLETAR: archive, `app verify`, build subido sí/no]`. Mandar a revisión no está autorizado.

## La 2.1 (rama `version-2.1`, aparte de la 2.0)

No toca la 2.0: `tasks-v21.md` vive en esa rama y la describe. **20 de 42 tareas hechas en tres olas, todas sin compilar la app salvo EK:**

| Ola | Tareas | Verificación |
|---|---|---|
| 1 (8) | F1-T1, F1-T3, F2-T1, F3-T1, F3-T2, F4-T1, F6-T1, F6-T3 | `v21-verif-ola1` (`c633fa96`): EK 1144 verdes, pacing-sim OK, Python 54 + 15, SQL 41 casos |
| 2 (8) | F1-T2, F1-T4, F1-T6, F2-T2, F3-T3, F5-T1, F5-T2, F6-T2 | `v21-verif-ola2` (`bfa65091`): EK 1245 verdes, SQL 47, pacing igual a la 2.0 (free 45,40 h · ads 31,39 h · max 30,40 h); app revisada a ojo, **sin compilar** |
| 3 (4) | F1-T5, F2-T3, F7-T1, F7-T3 | **sin verificar**; integradas sin conflictos en `v21i/integ-ola3` = `79c1fc1a` |

Qué es cada cosa, en una línea: el **segmento de valor del jugador** (reglas con histéresis y un modelo de árboles opcional) con sus palancas de
ritmo (`SegmentLevers`, ×2,5 acotado por fuente), el **detector de momentos y el bandit de Thompson** que elige la oferta, la **audiencia en las
ofertas** y el destacado de la Tienda, la **configuración remota de personalización** (migración con interruptor apagado) y las **vistas del panel**
(`value_daily`, `offer_funnel`, retención por brazo, pacing). El simulador de pacing ya corre por segmento (`--segment`, `--segment-matrix`).

**Investigación (`Docs/v21/investigacion-R1-R8.md`):** AdMob no da el valor antes de mostrar (F3 = anuncio cargado + promedio del ledger; sin MAX);
el valor del jugador vive en el teléfono (Apple 5.1.1/5.1.2); R7 casi sin margen (ads 31,39 h; ×2,5 total ≈ 27,9 h `[SUPUESTO]`); R8: unos 5–10 mil
jugadores etiquetados.

**Lo que sigue:** verificar la ola 3 (compilar la app de la 2.1, EK, `test.sh --sql`, `pacing-sim --segment-matrix` con y sin `--caps`) y la **ola 4**
(F1-T7, F2-T6, F2-T7, F2-T8, F3-T4, F3-T5, F5-T3). El contexto pasó los 300k, así que el 60 no abrió olas nuevas de la 2.1 (regla de 250k).

**Carries de la 2.1 abiertos** (de los reportes): la migración `000002` (eventos segment/exposure/progress) **se aplica antes del binario 2.1** o los lotes
vuelven 400; `ranking_settings()` ahora arrastra la config (hasta 64 KB) en cada llamada: revisar; `pacing-sim` declara su propio `SplitMix64` (si hay
ambigüedad con el de EK, borrar la copia); `forcedSpacingScale` puede romper la monotonía high ≤ mid; `train.py` debe exportar `modelThresholds`;
el bucket/exposure lo cablea F1-T5 (hecho) y el pago de `mergeAll` lo cablea F3-T5; confirmar que XcodeGen levanta `Resources/Config` por carpeta.

## Trampas nuevas

- **`onGeometryChange` dentro de un `.offset` que depende de la medida es un bucle de layout (B34).** El splash medía el logo con una vista cuyo
  offset dependía de esa misma medida: cada pasada movía la vista, la medida cambiaba y el `body` se reevaluaba; el consejo además se sorteaba en cada
  `body`. El arranque se colgaba y **todo** el UI fallaba (parecía un montón de rojos distintos). Se mide un placeholder en su lugar y el offset va en un
  overlay; el sorteo va en `@State`. Un cambio al splash se prueba arrancando la app, no sólo con su test.
- **`player` es `@ObservationIgnored`:** las vistas que leen derivados de `player` no se refrescan solas. March lo sufrió (chip que no abre, cobrada
  que queda): hace falta una proyección observada (`shownMarch`). Quien agregue un derivado de `player` a una vista lo mira.
- **El fixture `--uitest-extra-slots` movía la cámara** al piso más alto: tres capturas dejaban de ver el colchón y al Ministro. Un fixture que cambia
  el piso visible tiene que restaurar `visibleFloorOrdinal`.
- **El cambio de piso abre la torre entera y marca los tipos vistos:** un test del atajo que no lo tiene en cuenta ve el botón sin candidatos (el
  tipo base del piso urbano no pasa la compuerta).
- **Carga alta por simuladores de otra sesión:** `auditoria-17pro` (de otra sesión) dejó la carga en 230 y hasta 600–680 con 3 simuladores; UI con
  timeouts de ~190 s y el aislamiento de StoreKit colgado 16 min. Antes de creer un rojo de UI o de StoreKit, mirar `uptime` y los simuladores
  booteados; no tocar los ajenos.
- **Un worktree nuevo no tiene `build/`:** el primer lanzamiento del `completo` falló al instante sin log. Crear `build/` antes de lanzar.
- **No se mergea a la integración mientras corre su `completo`:** B34 y B30 esperaron y se armaron en `v2i/integ-r60` aparte.
- **Un merge con conflictos de B30 conviene delegarlo con nombre** (`b30-merge`): `PickupController` y `BarFlapLayoutTests` los resolvió un agente
  que conocía los dos lados; sus asserts escalados son parte del riesgo de los UI que miden tamaños.

## Carries para decidir

- Los de B25/B29/B24/B28 del 58 y 59 siguen en pie (el visitante espejado, la oferta de compra del presentador, `flapHeight` 44, el póster de caja
  abierta, el billete que sigue al plato).
- Con B30: `backScale` 0,85 ajustable; los UI que miden posiciones de los de atrás; el botón de compra con nombre largo en castellano (capturas SE y
  Pro Max).
- Las capturas de B34 en SE y Pro Max y la tira del paso del splash a la pantalla principal: `[COMPLETAR]`.

## Descartados

- **Dejar la 2.1 en la misma rama que la 2.0:** el dueño pidió una rama aparte y que la 2.0 salga sola; la 2.1 sale apagada hasta la revisión legal.
- **Medir los gates de E8d/E8e en el iPhone 15 Pro con Bajo consumo** (propuesta del 60): el dueño eligió sólo el simulador del SE.
- **AppLovin MAX en la 2.1** y **pedir la API `mediationGroups`/OAuth**: no (trámite o costo).
- **Abogado ahora:** no; el interruptor remoto de la personalización queda apagado.
- **Subir la 2.0 junto con la 2.1:** la 2.1 no estaba lista.
- **Recolorear el logo de B34** (naranja, azul, verde, amarillo): el dueño eligió el blanco.
- **Mergear B30 por defecto:** sólo tras el sí del dueño (lo dio).

## Para el dueño

La lista completa, en orden hasta el envío, está en «Cierre de E10» del plan de E10. Lo inmediato:

1. **Sacar Meta de los grupos de mediación de AdMob** y de los socios del mensaje GDPR; aprobar la rama `sin-meta` del sitio.
2. **Los textos de La Marcha y de Novedades** (y el voseo en es-MX/es-ES); `asc listing apply` es del día del envío.
3. **La pasada G4** en su iPhone (la lista está en «Cierre de E14»); ahora incluye cómo se ven los de atrás con B30.
4. **O6 (la telemetría de E15) y la revisión legal de la 2.1** cuando decida; la 2.1 no sale hasta entonces.
