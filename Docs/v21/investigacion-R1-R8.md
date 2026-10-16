# E15 · 2.1 — Investigación R1–R8

**Fecha:** 2026-10-16 · **Autor:** v21-investigador · **Spec:** `Docs/PLAN-v2-E15-valor-por-jugador.md` §6.
**Alcance:** sólo lectura y fuentes públicas. No se compiló, no se corrió el pacing-sim, no se tocó nada en remoto.

**Convenciones.** `[CONFIRMADO]` = leído en una fuente primaria (URL al lado) o en el código del repo. `[SUPUESTO]` = estimación mía o
dato que no está medido. `[VERIFICAR CON ABOGADO]` = lectura jurídica mía, sin valor legal. Lo que no pude leer entero lo digo.

## Resumen ejecutivo

| R | Conclusión en una línea | Cambia el diseño |
|---|---|---|
| R1 | El reel **no está verificado**: el código prometido no está publicado. Es plausible, no confirmado. Se corrige una cita del §5 (App Store 5.6). | No |
| R2 | AdMob iOS da el valor **sólo después** de la impresión (`paidEventHandler`). MAX no está probado que lo dé al cargar. **Quedarse en AdMob + Unity.** Los pisos van por grupos de mediación por país (UI; API con acceso limitado). | Sí: F3 usa «hay anuncio cargado» + ledger, no «anuncio caro cargado» |
| R3 | No hay datos de eCPM por país de la v1 en el repo. F1 arranca con **tiers semilla**; la tabla propia sale del `networkReport` de la 2.0. | Sí: F1 con tabla semilla |
| R4 | F0 ya cubre casi todo. Faltan 3–4 eventos (segmento, exposición a experimento, oferta con contexto). Cada evento nuevo es migración + enum. | Sí, menor |
| R5 | Lo más duro es Apple 5.1.1/5.1.2: consentimiento aun para datos anónimos, nada de perfiles reconstruidos, nada de condicionar funciones. El VEJ debe calcularse **en el teléfono**. | Sí |
| R6 | La industria segmenta frecuencia/topes por geo y por comportamiento, con A/B de 7–14 días y la retención como límite. Nada de esto requiere engañar. | No |
| R7 | **El piso «Dios no antes de 30 h» casi no deja margen:** `.ads` ya está en 31,39 h y `.max` en 30,40 h. Un ×2,5 en todas las fuentes de video lo rompe (aprox. 28 h). | Sí: hay que decidir el piso o acotar el ×2,5 por fuente |
| R8 | Con reglas basta mucho tiempo. Para un modelo útil hacen falta del orden de 5–10 mil jugadores **con etiqueta** → 20–40 mil instalaciones con telemetría consentida. Fecha = f(instalaciones/día). | Sí: criterio de paso reglas → modelo |

---

## R1 — ¿Es cierto lo del reel?

**Qué se buscó:** la publicación técnica de @ayoships, otras descompilaciones de Block Blast (Hungry Studio) y su política de privacidad.

**Hallazgos**
- `[CONFIRMADO]` La web del autor dice que el análisis de Block Blast y Duolingo, con el código, **todavía no está publicado** (sólo ofrece
  avisar por mail): <https://ayoships.com/>. Sin el código, ninguna de las reglas del reel (`MultiClearBoostThenKillTrait`,
  `RewardHighValueAdHarvestTrait`, `MABXiBaiTrait`, el +10 %) se puede contrastar. No encontré esos identificadores en ningún lado.
- `[CONFIRMADO]` Existe una discusión pública del reel (MetaFilter, 14-oct-2026, <https://www.metafilter.com/214827/Ive-reverse-engineered-Block-Blast>);
  el servidor me devolvió 403, **no pude leerla**. Un buscador la resume como centrada en la descompilación asistida por IA en general.
- `[CONFIRMADO]` Lo que sí tiene fuente nombrada es el tamaño del negocio: ~127 M USD en anuncios de enero a mayo de 2026 (Sensor Tower, citado
  por Applixir, <https://www.applixir.com/blog/the-block-blast-playbook-what-127m-in-ad-revenue-actually-bought/>, que lo llama estimación).
  Esa nota describe un único rewarded en el momento de fallar, limitado a uno por sesión, e **intersticiales saltables**; no habla de
  dificultad manipulada, XGBoost ni de @ayoships. Su descripción de la arquitectura viene de «deconstrucciones independientes» sin nombrar.
- `[CONFIRMADO]` Las acusaciones de «el juego está amañado» son de jugadores, sin metodología ni confirmación de la empresa
  (<https://playgama.com/blog/?p=11337>, un blog de una plataforma de juegos).
- Su política de privacidad no la leí: no hay una fuente que la nombre en lo que encontré. **No concluyo nada** sobre qué datos recoge. [SUPUESTO] que
  recoge país, modelo e ingreso por anuncio, como dice el reel.

**Conclusión.** Tratar el reel como *plausible y coherente con cómo funciona el negocio* (modelos de LTV, topes por geo, rewarded en el momento
de necesidad), pero **sin evidencia pública del amaño**. El diseño de E15 no depende de que sea cierto: las palancas de §4 se justifican solas.
Re-chequear <https://ayoships.com/> cuando salga el write-up (tarea barata, 5 min) por si trae algo aprovechable.

**Corrección al spec (§5).** Dice que App Store 5.6 «lo prohíbe expresamente». No pude leer el texto vigente de 5.6 (el fetch cortó antes). Lo que
se puede afirmar con fuente secundaria: 5.6 es el **Código de Conducta del desarrollador** y la conducta manipuladora o engañosa *reiterada* puede
costar la cuenta (<https://techcrunch.com/2021/06/07/apples-new-app-store-guidelines-aim-to-crack-down-on-fraud-and-scams>). No habla de dificultad
de juego. Recomiendo reescribir «lo prohíbe expresamente» como «cae en el espíritu de 5.6 (conducta engañosa) y en la regla de datos de 5.1.1–5.1.2»,
y verificar el texto en <https://developer.apple.com/app-store/review/guidelines/>.

---

## R2 — Qué deja saber AdMob en iOS

### Tabla de capacidades

| Capacidad | AdMob (SDK 13.x, el del proyecto) | AppLovin MAX | Fuente |
|---|---|---|---|
| Valor de la impresión **después** de mostrar | Sí: `paidEventHandler` con `AdValue` (valor, moneda, precisión). Requiere activar «impression-level ad revenue» en la cuenta | Sí: callback de ingreso (`didPayRevenueForAd`), `ad.revenue` en USD | <https://developers.google.com/admob/ios/impression-level-ad-revenue> |
| Precisión | `unknown`, `estimated`, `publisherProvided`, `precise`. Con bidding en pedidos de **prueba** sólo `unknown` y valor 0 | `exact` (subasta en tiempo real), `estimated`, `publisher_defined`, `undefined`; con FB Bidding el estimado es 0 | idem; <https://support.applovin.com/en/max/ios/overview/advanced-settings> |
| Valor del anuncio **cargado, antes de mostrar** | **No documentado.** La doc sólo recomienda poner el handler antes de mostrar. `[CONFIRMADO]` que no lo dice; `[SUPUESTO]` que no existe | **No confirmado.** La doc dice que el ingreso «se puede leer en todos los callbacks del ciclo de vida» pero no muestra un ejemplo en `didLoad`. **Requiere un spike** | idem |
| Qué red sirvió | `responseInfo.loadedAdNetworkResponseInfo.adSourceName` (ya lo usa `AdMobAdsProvider`) | `ad.networkName` | <https://developers.google.com/admob/ios/response-info> |
| Pisos de eCPM | Por unidad/grupo; **sólo aplican a AdMob Network y a fuentes de bidding**, no a redes de waterfall de terceros; son «best effort» | Por red/placement en el panel de MAX | <https://support.google.com/admob/answer/3418058> |
| Grupos de mediación por país | Sí: un grupo se segmenta por formato, plataforma, región e IDFA | Ad unit + segmentos de MAX | <https://support.google.com/admob/answer/3418058>, <https://developers.google.com/admob/api/v1/mediation-groups> |

### Lo que implica en este proyecto
- `[CONFIRMADO en el repo]` La mediación de la 2.0 es **AdMob + Unity Ads** (`project.yml`: sólo `GoogleMobileAdsMediationUnity`; Meta, AppLovin y
  Mintegral quedaron afuera). Pasar a MAX no es un cambio de configuración: es reemplazar el SDK, los 8+3 ad units, los adaptadores, el UMP/ATT,
  `privacy.md`, la etiqueta de ASC y el reporting. Es una épica propia.
- **F3 no puede apuntar a «anuncio caro cargado»** con AdMob. Usa: (a) hay un anuncio cargado (`isReady`), (b) el promedio y los recientes del
  `AdRevenueLedger` del jugador (formato y lugar), (c) el país. El spec ya lo preveía como «si el SDK lo permite».
- **Recomendación:** quedarse en AdMob + Unity en la 2.1. Si el dueño quiere evaluar MAX, un **spike de un día**: app de prueba con MAX, cargar un
  rewarded, imprimir `ad.revenue`/`revenuePrecision` en `didLoad` en dispositivo real con anuncios reales. Sólo si trae un valor `exact` o `estimated`
  útil antes de mostrar, vale abrir la épica. `[SUPUESTO]` Con bidding, el valor exacto sólo se conoce al ganar la subasta; es razonable que MAX
  exponga el de la puja ganadora al cargar, pero **no lo confirmé**.
- **Pisos por país:** hoy sólo el UI de AdMob lo garantiza (vía releaseops por Chrome). La AdMob API tiene `mediationGroups.create/patch` en v1beta
  pero con **acceso limitado** (403 salvo que el account manager lo habilite): <https://developers.google.com/admob/api/reference/rest/v1beta/accounts.mediationGroups/create>.
  No pude confirmar si la API maneja los floors. Para **reporting** sí hay API abierta: `accounts.networkReport.generate`
  (<https://developers.google.com/admob/api/reference/rest/v1/accounts.networkReport/generate>).
- **Riesgo:** un piso alto baja el *fill* (más pedidos sin anuncio) y, con waterfall, deja pasar a redes de tercero sin piso. Cualquier piso se
  prueba por país con el *match rate* y las impresiones/DAU como guardas, nunca a ciegas.

---

## R3 — Cuánto vale cada país y cada dispositivo para nosotros

**Datos disponibles:** `[CONFIRMADO]` el repo **no tiene** ningún informe de AdMob de la v1 (busqué en `Docs/`, `Distribution/`, sesiones y
`tasks.md`). `Docs/monetizacion-anuncios.md` sólo dice qué mirar. La v1 (1.0.0 build 4) estuvo publicada con 5 unidades y *revenue limitado* durante la
revisión de AdMob. `[SUPUESTO]` el volumen de la v1 es chico (no hay cifras); el dueño las tiene en AdMob y App Store Connect.

**Consecuencia:**
1. **F1 arranca con una tabla semilla pública** (no propia) de tiers de país por eCPM típico de rewarded en iOS: T1 (EE. UU., Canadá, Reino Unido,
   Australia, Alemania, Países Bajos, nórdicos, Suiza, Japón, Corea), T2 (resto de Europa occidental, Israel, Emiratos…), T3 (Latinoamérica
   incluida Argentina, Europa del este, Turquía…), T4 (sur de Asia, África). `[SUPUESTO]` la pertenencia exacta a cada tier: es una heurística
   conocida del negocio, no un dato mío; **no la inventé con cifras** porque no tengo una fuente primaria por país. Para modelo de dispositivo:
   tres rangos (`iPhone` de la generación actual y -1, anteriores, `iPad`) por el `device_model` que ya llega en cada evento.
2. **La tabla propia se arma con los datos de la 2.0.** Receta lista para correr:
   - `accounts.networkReport.generate` con dimensiones `COUNTRY` × `FORMAT` × `PLATFORM` (y `AD_UNIT` para el lugar), métricas ganancias estimadas
     (micros), impresiones, solicitudes y RPM/eCPM observado (la doc describe `IMPRESSION_RPM` como el eCPM de la UI; no verifiqué el nombre exacto
     de cada enum), en ventanas de 14 días, **sólo países con ≥ 1.000 impresiones** (`[SUPUESTO]` umbral para que el eCPM no sea ruido).
   - Cruzarla con el `storefront` de la telemetría (alfa-3) y con el ledger: sirve de control del `AdRevenueLedger` (suma del ledger ≈ ganancias de AdMob, con
     diferencia por redondeo/moneda; si difieren > 10 % hay un bug de medición).
   - Salida: `Docs/v21/country-tiers.json` versionado, con `generatedAt`, ventana y número de impresiones por fila.
3. **Pendiente del dueño (🔒):** AdMob API pide OAuth con la cuenta del dueño; o bien exportar el informe a CSV desde el UI y dejarlo en el repo
   (más simple, sin credenciales nuevas).

**Dispositivo vs. país:** `[SUPUESTO]` el país explica casi todo el eCPM; el dispositivo agrega poco y correlaciona con el país y con el poder
adquisitivo. Por eso F1 usa el país como señal principal y el dispositivo como desempate. Se verifica con los datos de la 2.0 (correlación por tier).

---

## R4 — Qué datos hacen falta y cómo se juntan bien

### Lo que F0 ya junta `[CONFIRMADO en el código y el SQL]`
- Tabla `public.telemetry_events` (migración `20261015000001_telemetry_schema.sql`): `install_id` (UUID propio, no IDFA/IDFV), `session_id`,
  `client_ts`, `name` (6 eventos), `app_version`, `build`, `os_version`, `device_model`, `storefront` (alfa-3), `props` con **claves cerradas**
  por evento (CHECK en SQL y `enum` en Swift: un evento o clave nueva es migración + app).
- Eventos: `session_start{n}`, `session_end{seconds}`, `ad_impression{format,site,micros,currency,precision,source}`, `offer{site,stage}`,
  `purchase{product}`, `prestige{count}`.
- Tres candados: interruptor de servidor (`settings.telemetry_enabled`), interruptor remoto y compuerta local (`TelemetryGate`: consentimiento
  vía `TelemetryConsent` — UMP más los propósitos TCF 1, 8, 9 y 10 donde aplica el RGPD —, no UI test, no DEBUG).
  Retención: 400 días (`cleanup_telemetry`).
- Insert-only para `anon`: nadie de afuera lee. Las lecturas son del dueño con `service_role` (`supabase/scripts/admin.sql`).

### Qué cubre sin cambios (para el 2.1)
Retención D1/D7 (de `session_start` por `install_id`), ARPDAU por país/modelo, impresiones por jugador, embudo por lugar, conversión a compra, ingresos
por formato. **F1 no necesita telemetría** (el VEJ vive en el teléfono con el ledger local); la telemetría la necesitan F6 (entrenar) y F7 (panel).

### Qué falta para las fases (propuesta, cada una es una migración)
| Evento nuevo | Para qué fase | Claves (todas tokens/números) |
|---|---|---|
| `segment` | F2/F7: separar métricas por segmento | `id` (token), `ver` (versión de la tabla), `src` (rules/model) — sólo al cambiar |
| `exposure` | F3/F6: A/B y bandido | `exp` (token), `arm` (token), `ver` |
| `offer` ampliado con `ctx` | F3: en qué momento natural salió | `ctx` (token: `floor_full`, `price_wall`, `mattress_ready`, `back_offline`…) |
| `ledger_summary` (opcional, 1 por sesión) | F6: etiqueta del modelo sin reconstruir el historial | `n`, `mean_micros`, `max_micros`, `ccy` por formato |

Reglas de diseño:
- **Sin datos personales ni texto libre** (mantener los tokens ASCII acotados que ya impone `TelemetryValue.token`).
- **Cola de eventos**: ya existe; subir el tope de lote sólo si crece el volumen. `[SUPUESTO]` volumen: ~30–60 eventos por jugador/día → 1.000 jugadores/día
  ≈ 30–60 mil filas/día; el plan gratuito de Supabase no alcanza para meses de histórico, hay que mirar tamaño de tabla y el cron de retención.
- **Etiqueta de ASC:** F0 la deja en «Device ID / Product interaction / …, no vinculados, sin tracking». Los eventos nuevos caen en las mismas categorías;
  revisar si el `segment` se considera «datos de uso» o «perfil» (ver R5, Apple 5.1.2(iii)).
- **Retención de datos:** 400 días hoy. Para entrenar un modelo, 90 días bastan; considerar bajar a 180 (menos riesgo, menos costo) `[SUPUESTO]`.

---

## R5 — Qué dicen las reglas

> Todo esto es una lectura técnica con fuentes. **Nada reemplaza al abogado** (el spec ya lo pide). Cada punto lleva la fuente que pude leer o la que
> hay que verificar.

### Apple (App Review Guidelines, <https://developer.apple.com/app-store/review/guidelines/>) `[CONFIRMADO, salvo 5.6]`
- **5.1.1(ii)** Si la app recoge datos de uso, hay que **obtener consentimiento aunque sean anónimos**; la funcionalidad paga no puede depender de darlo y
  tiene que haber una forma fácil de retirarlo. → el interruptor de telemetría y su pantalla en Ajustes deben poder retirar el consentimiento.
- **5.1.2(i)** No se puede condicionar el uso, el contenido o **una compensación** a habilitar el tracking. → ninguna ayuda del juego puede estar atada a aceptar ATT.
- **5.1.2(ii)** El dato recogido para un fin no se reutiliza para otro sin nuevo consentimiento. → el texto de privacidad tiene que nombrar «personalizar
  ayudas y ofertas» como uso (hoy dice «saber cómo se juega y cuánto rinden los anuncios»).
- **5.1.2(iii)** *No se pueden armar perfiles de usuario* a partir de datos recogidos ni «reconstruir perfiles» desde datos anónimos o agregados.
  → **el diseño correcto es que el VEJ se calcule en el teléfono con datos locales** (ledger, país, modelo, compras), sin que el servidor reciba
  un puntaje por jugador. La telemetría de F0 manda eventos sueltos con un id propio; el entrenamiento de F6 se hace con esos eventos agregados.
  No cruzarlos con IDFA/IDFV ni con el nombre del ranking (ya está prohibido en F0).
- **3.2.2(x)** *Incentivar* acciones como «ver un anuncio» está permitido. **3.2.2(iii)** prohíbe inflar impresiones artificialmente. →
  más ofertas opt-in está bien; forzar o disfrazar un video, no.
- **2.5.18** Los anuncios intersticiales/interruptores deben ser claramente anuncios, no engañar al toque y tener cierre accesible.
- **5.6** (Código de Conducta): no pude leer el texto vigente, ver R1.
- **Etiqueta de privacidad (2.3):** debe reflejar la realidad y mantenerse al día.

### AdMob / Google `[del conocimiento general; confirmar en <https://support.google.com/admob/answer/6128543>]`
- Los **rewarded deben ser opt-in** y el jugador debe saber de antemano cuál es el premio: la política de Google lo exige. Las ofertas de F3 («mirá un video y
  el próximo contrato sale gratis») lo cumplen; **no** se pueden mostrar como si fueran gratis ni abrirlas solas.
- No colocar anuncios donde se toquen por error ni incentivar toques. Una oferta en un pop-up debe tener un «No, gracias» visible.
- Menores: la app ya usa UMP; las marcas de tratamiento (`tagForUnderAgeOfConsent`, `tagForChildDirectedTreatment`) existen en el SDK y
  `[SUPUESTO]` no se usan porque la app no declara edad.

### UE / Reino Unido / Suiza
- **TCF v2.2** (`[CONFIRMADO]` <https://docs.didomi.io/consent-management-platform-cmp/frameworks-regulations/iab-tcf/iab-tcf-2.2/tcf-v2.2-summary-of-purposes-features>):
  los propósitos 3–6 (perfiles y personalización de anuncios y de contenido) son **sólo consentimiento**. 7 y 8 (medir anuncios y contenido), 9 (estadísticas
  de audiencia) y 10 (mejorar servicios) admiten consentimiento o interés legítimo según el proveedor. El código de F0 exige 1, 8, 9 y 10
  (`TelemetryConsent.requiredPurposes`), fail-closed.
- **¿Qué propósito cubre «personalizar ofertas del juego»?** `[SUPUESTO]` Es contenido propio del juego, no publicidad de terceros, así que los
  propósitos de publicidad (3, 4) no aplican. La lectura más conservadora la ubica en 5 y 6 (perfil de contenido y uso). **Recomendación:** exigir
  {1, 5, 6, 8, 9, 10} para activar segmentos en RGPD y, si falta alguno, segmento = base (neutro, no peor). `[VERIFICAR CON ABOGADO]` si 9 y 10 bastan.
- **RGPD art. 22** (decisiones automatizadas con efectos significativos): más ayuda opt-in en un juego no es un «efecto significativo»; no bloquea.
  `[VERIFICAR]`. <https://eur-lex.europa.eu/eli/reg/2016/679/oj>
- **ePrivacy art. 5(3):** leer información del dispositivo (modelo, país de la tienda, ledger propio) para perfilar necesita consentimiento salvo que sea
  estrictamente necesario. Mismo criterio: consentimiento.
- **Directiva Ómnibus (UE) 2019/2161, art. 6(1)(ea) de la Directiva 2011/83/UE:** obliga a avisar **antes de la compra** que *el precio* se personalizó por
  decisión automatizada. Los comentaristas coinciden en que no hay que revelar la lógica y que no vale ponerlo en los términos
  (<https://www.addleshawgoddard.com/en/insights/insights-briefings/2020/competition/the-eu-omnibus-directive--time-to-prepare-for-strengthened-consumer-laws/>;
  texto oficial <https://eur-lex.europa.eu/eli/dir/2019/2161/oj>, **no lo leí entero**). En la Tienda **el precio de un producto no cambia** (tiers de App Store),
  cambia qué pack se muestra: *estrictamente* no está en el supuesto. **Recomendación prudente:** igual poner una etiqueta visible «Oferta elegida para
  vos» en la Tienda de la UE cuando el pack mostrado viene de un segmento. `[VERIFICAR CON ABOGADO]`.
- **Prácticas desleales (Dir. 2005/29/CE) y «patrones oscuros»:** las autoridades de consumo de la UE vienen mirando las monedas virtuales y los
  juegos; ejemplos relevantes: cuenta regresiva falsa, urgencia fabricada, presión para gastar. `[VERIFICAR]` el documento de principios de la red CPC
  sobre moneda virtual en juegos (2025) — no lo leí. Las ofertas de F3 deben ser **ciertas** (lo que dice el botón es lo que pasa) y sin urgencia falsa.

### Argentina `[VERIFICAR CON ABOGADO]` (no pude leer la norma; el contenido es del conocimiento general)
- **Ley 24.240** (defensa del consumidor): información cierta, clara y detallada; trato digno; prohíbe prácticas abusivas. Una oferta «gratis» que no lo es
  o un premio que cambia en secreto chocaría con esto.
- **Ley 25.326** (datos personales): consentimiento libre, expreso e informado; finalidad; seguridad; la AAIP controla; **transferencia internacional**
  a países sin nivel adecuado requiere garantías. Supabase se aloja en una región de la nube (la del proyecto): confirmar cuál. Un id aleatorio sin cuenta
  probablemente no sea «dato personal» si no se puede vincular a una persona, pero con el modelo de dispositivo y el país `[SUPUESTO]` hay riesgo de
  re-identificación en cohortes muy chicas. Mitigación: no publicar cohortes < 20 jugadores en el panel.

### Menores (12+, sin edad)
- La app no pide edad ni cuenta. **COPPA** (EE. UU., <https://www.ecfr.gov/current/title-16/chapter-I/subchapter-C/part-312>) aplica a servicios dirigidos a
  menores de 13 o con *conocimiento real*; un 12+ no dirigido a niños suele quedar fuera, pero no hay conocimiento real si no se pregunta.
  `[VERIFICAR CON ABOGADO]`.
- Apple 1.3 y 5.1.4: las apps de la categoría Kids no pueden llevar analytics ni anuncios de terceros. FisuEvolution no está en Kids (12+), así que no aplica.
- **Respuesta a la duda de si basta no perfilar sin consentimiento:** `[VERIFICAR]` es el piso razonable. Reglas operativas: (a) sin consentimiento → base;
  (b) **no** pedir edad (pedirla crea conocimiento real y obligaciones); (c) donde el UMP marque menor de edad/consentimiento parcial → base;
  (d) nada de ofertas de compra basadas en el segmento («pack de inicio a quien tiene probabilidad de comprar») sin pasar por (a)–(c) y por legal.
  En particular F5 (Tienda por segmento) es la fase de mayor riesgo jurídico: dejarla última.

### Lista de qué se puede y qué no
| Se puede | No se puede |
|---|---|
| VEJ calculado en el teléfono con datos propios | Mandar un puntaje por jugador al servidor o reconstruir perfiles (Apple 5.1.2(iii)) |
| Más ofertas de video opt-in, más premio tope, a la vista | Condicionar ayudas a aceptar ATT o la telemetría (5.1.2(i), 5.1.1(ii)) |
| Pisos de eCPM por país en AdMob | Mostrar un rewarded como si fuera obligatorio o disfrazado; inflar impresiones (3.2.2(iii)) |
| Bandido sobre momento/lugar/tamaño con retención como límite | Bandido sobre «cuándo hacer perder»; urgencia falsa |
| Aviso «Oferta elegida para vos» en Tienda UE | Cambiar el precio de un mismo producto por segmento (el precio es del tier) |
| Segmentar con consentimiento TCF {1,5,6,8,9,10} | Segmentar sin consentimiento en RGPD |

---

## R6 — Qué hace la industria sin engañar (1 página)

Fuentes comerciales (de empresas de monetización): tratar como heurística, no como benchmark.

- **Segmentar por comportamiento y por geo, no sólo por «pagador / no pagador».** Supersonic (ironSource/Unity) aconseja no armar compartimentos rígidos
  «mira anuncios» / «compra», porque los que compran también ven videos y viceversa, y sugiere segmentar en el juego (p. ej. ayudas de dificultad a quien
  avanza rápido): <https://supersonic.com/learn/blog/the-dos-and-donts-of-hybrid-casual-monetization-how-to-create-a-profitable-hit/>.
- **Topes y ritmo por segmento.** LevelPlay documenta *capping* y *pacing* por segmento, priorizables por ingreso, retención o flujo del juego:
  <https://docs.unity.com/en-us/grow/levelplay/platform/best-practices/segments>. CAS.ai recomienda empezar conservador, subir sólo si la retención aguanta,
  y segmentar la frecuencia por geo (Tier 1 vs Tier 3): <https://cas.ai/?p=9187>.
- **A/B de 7–14 días por cohorte** (geo, canal, dispositivo) y **la regla de retención**: se acepta una caída ≤ 1 punto de D-retención si el ARPDAU sube
  (CAS.ai, misma nota). Las métricas guarda: D1/D7/D30, impresiones por DAU, ARPDAU y conversión del rewarded.
- **Casos reales con números** (Unity/LevelPlay): LBC Studios subió el tope de rewarded de un placement de tienda de 10 a 20 por día y su ARPDAU subió 37 %
  (<https://unity.com/en/resources/lbc-studios>); ZiMAD sumó intersticiales a un juego sólo rewarded: +17 % de ingreso, −2,3 % en D7
  (<https://unity.com/blog/five-a-b-tests-to-increase-revenue>). Moraleja para F2/F3: **subir topes de rewarded en el lugar que ya convierte** es la palanca
  de mayor retorno y la de menor riesgo; sumar forzados es la de más riesgo.
- **Reward → venta permanente por IAP:** dar un premio una vez por video y venderlo permanente por compra sube la primera compra sin dañar el rewarded
  (Supersonic). Candidato a F5.
- **Bandidos:** Thompson sampling es la técnica estándar y simple (<https://api.deepai.org/machine-learning-glossary-and-terms/thompson-sampling>, texto
  general); `[CONFIRMADO]` no encontré un paper específico de «momento de oferta + retención» en juegos. Para esta app: brazos pocos (3–5), recompensa
  = conversión de la oferta, **restricción dura** = retención D1/D7 del brazo no menor que la base − 1 punto; en el teléfono sólo se guarda la política
  (probabilidades por brazo), el aprendizaje es del servidor con los eventos `exposure`/`offer`.
- **Dificultad adaptativa:** la que usa la industria honesta es hacia **retención** (ayudar a quien se atasca), no hacia monetización. Acá no hay derrota:
  el equivalente son los «momentos de necesidad naturales» del spec §3.

---

## R7 — ¿Rompe el ritmo?

**No se corrió el pacing-sim** (la Mac está ocupada con la verificación de la 2.0). Esto es el diseño de la extensión y los números a correr.

### Lo medido que ya está (`Docs/balance-log.md`, B31, semilla 0,5) `[CONFIRMADO]`
| Perfil | Dios (h activas) | Notas |
|---|---|---|
| `.free` | **45,40** | define el contrato; el bot no mira videos |
| `.ads` | **31,39** | 69,1 % de `.free`; el bot **acepta todos los videos** (cada uno le cuesta 30 s de sesión) |
| `.max` | **30,40** | 67,0 % de `.free`; además tiene permanentes de la tienda |

### Hallazgo: el piso de 30 h no tiene margen
El spec pide «el alto con un piso (p. ej. Dios no antes de 30 h)». Pero `.ads` ya está en 31,39 h con **todos** los videos aceptados y `.max` en 30,40 h.
El perfil `.ads` ya es el «alto». Cualquier palanca que agrande lo que da un video lo acerca o lo cruza.
`[SUPUESTO]` Aproximación lineal: los videos ahorran 45,40 − 31,39 = 14,01 h. Si un ×2,5 en vez de ×2 agrandara en 25 % **todo** ese ahorro, quedaría
45,40 − 14,01 × 1,25 ≈ **27,9 h**: por debajo de 30. La aproximación es burda (los videos no son todos ×2 ni escalan igual), pero dice que
**el ×2,5 en todas las fuentes no cabe en un piso de 30 h**. Salidas, para decidir con el dueño:
1. **Piso 28 h** para el segmento alto (aceptar que el «alto» es 38 % más rápido que `.free`, ya lo es 31 %).
2. **Acotar el ×2,5 por fuente:** sólo ×2,5 en las fuentes de menor peso en el pacing (p. ej. offline), el resto ×2. El sim lo dice cuáles.
3. **Menos ofertas en vez de más premio:** el segmento alto ve más *oportunidades* (más visitantes con oferta) pero con premio ×2; V3 se cumple con un ×2,25 máximo.

### Diseño de la extensión del simulador
- **Entrada nueva `PacingSegment`** (struct en EconomyKit, `Codable`, sin lógica de economía): `acceptRate` (0–1, qué fracción de las ofertas acepta el bot),
  `rewardScale` (1,0–1,25; multiplica `offlineMultiplier`, `dailyMultiplier`, `careerMultiplier`, y el ×2 de los regalos `giftDoubles`: ×2 → ×2 × scale),
  `extraOffers` (multiplica la tasa de ofertas: divide `mergeAllCooldownSeconds` y `packageRainCooldownSeconds`, acorta `adBreakIntervalSeconds`),
  `mattressGiftScale` (frecuencia del colchón de regalo).
- **Segmentos a correr:** `bajo` (acceptRate 0,25, todo base: es el mismo `.free` con unos pocos videos), `medio` (acceptRate 0,6, premio base), `alto`
  (acceptRate 1,0, `rewardScale` 1,0 / 1,125 / 1,25, `extraOffers` 1,0 / 1,25 / 1,5). Matriz de 3 × 3 × 3 × 3 semillas = unas 80 corridas.
- **Cambio en el CLI:** `--segment <bajo|medio|alto>` + `--segments-file segments.json` (el mismo archivo que usará el juego, `segments.json` de F2), y
  `--accept-rate`, `--reward-scale`, `--extra-offers` para barrer. Sale en el mismo CSV de contrato.
- **`acceptRate` en el bot:** hoy `AdsSources` asume que cada video se toma. Con `acceptRate` < 1 el bot decide por una moneda determinista (semilla) por oferta.
- **Guardas en CI (nuevas):** (1) ningún segmento más lento que `.free` base 45,40 h ± 0,0 (tolerancia 0); (2) `alto` no más rápido que el piso decidido;
  (3) `medio` entre `bajo` y `alto`; (4) con el interruptor remoto apagado, todos = base.
- **Números a correr** (tabla de entrega, `Docs/balance-log.md`): Dios (h activas y de pared), reencarnaciones, % que paga la run 2, peor salto, luna,
  videos por run, para cada celda de la matriz; semillas 0,1 / 0,5 / 0,9.
- **Cómo no tocar el pacing de F0:** la extensión vive sólo en el simulador y en `segments.json`; con `segment = nil` el resultado debe ser idéntico al
  de hoy (test de regresión: `.free` 45,40, `.ads` 31,39, `.max` 30,40).

---

## R8 — ¿Cuántos datos hacen falta para el modelo v2?

**Datos medidos de la v1:** ninguno en el repo. Todo lo que sigue es `[SUPUESTO]`; el dueño tiene instalaciones/día y retención en App Store Connect.

### Cuánto hace falta
- **Qué se predice.** `[SUPUESTO]` El ingreso por anuncio acumulado a los 7 días (log(1 + ingreso)) a partir de las señales de las primeras sesiones:
  país/tier, modelo, ledger del día 0–1, sesiones, música/vibración (si se agregan), compras. La etiqueta llega recién a D7.
- **Volumen mínimo.** `[SUPUESTO]` Regla práctica para árboles potenciados con ~10–20 variables: **5.000–10.000 jugadores etiquetados** como mínimo para que
  la validación cruzada discrimine mejor que las reglas, y ≥ 1.000 por segmento que se quiera evaluar.
- **Etiquetados vs. instalaciones.** Sólo cuentan los jugadores con (a) telemetría consentida y (b) al menos una impresión pagada en D0–D7.
  `[SUPUESTO]` Consentimiento: 60 % (UE/RU/CH baja mucho con el TCF estricto; América Latina alto). Con ≥ 1 impresión en 7 días: 50 %.
  → un jugador etiquetado cuesta ≈ 1 / (0,6 × 0,5) ≈ **3,3 instalaciones**. Para 10.000 etiquetados: **~33.000 instalaciones**; para 5.000: ~17.000.

### Fecha estimada = instalaciones necesarias ÷ instalaciones por día + 7 días de etiqueta
| Instalaciones/día | 5.000 etiquetados (17 k) | 10.000 etiquetados (33 k) |
|---|---|---|
| 100 | 170 días (~5,6 meses) | 330 días (~11 meses) |
| 500 | 34 días | 66 días |
| 2.000 | 9 días | 17 días |
| 10.000 | 2 días | 3 días |

(sumar 7 días de etiqueta y 1–2 semanas de entrenamiento/validación).

### Criterio para pasar de reglas a modelo
1. Hay ≥ 5.000 etiquetados y ≥ 100 por país top.
2. **Holdout 20 %** por fecha: el modelo debe superar a F1 en correlación de rangos (Spearman) en ≥ 0,05–0,10 **y** en el ingreso capturado por el decil más alto
   (curva de ganancia).
3. **A/B real** (F6): mitad con reglas, mitad con modelo; se queda el modelo sólo si el ARPDAU sube sin bajar D1/D7 más de 1 punto.
4. Si no cumple 2 o 3: **seguir con reglas**. `[SUPUESTO]` Mi expectativa honesta: para este juego (pocos segmentos, un solo formato dominante, el ledger
   propio ya trae casi toda la señal) **las reglas alcanzan por mucho tiempo**, y el modelo agrega un porcentaje chico. F6 es la fase de menor retorno
   esperado; conviene dejarla condicionada a las instalaciones reales.

---

## Preguntas para el dueño

1. **MAX:** ¿se justifica un spike de un día para ver si MAX da el valor del anuncio al cargar? Recomendación: no en la 2.1; sólo si hay tiempo y ganas de abrir una épica de SDK.
2. **Datos de la v1:** ¿exportás de AdMob el informe 14 días por país × formato (CSV) y de ASC instalaciones/día y retención? Sin eso R3 y R8 quedan como supuestos.
3. **API de AdMob:** ¿pedís a tu account manager acceso a `mediationGroups` (v1beta) y autorizás un OAuth de lectura para el reporting? Si no, todo por UI (releaseops/Chrome).
4. **Piso de ritmo del segmento alto:** ¿30 h (con el ×2,5 acotado por fuente) o 28 h (con el ×2,5 completo)? Es una decisión de balance (R7) que el sim no puede tomar solo.
5. **Aviso «Oferta elegida para vos»** en la Tienda de la UE aunque el precio no cambie: ¿sí (prudente) o sólo si el abogado lo pide?
6. **Consentimiento para segmentar en la UE/RU/CH:** ¿exigimos {1,5,6,8,9,10} (conservador) o dejamos los de hoy {1,8,9,10}?
7. **Edad:** ¿confirmás que no se pide edad (evita «conocimiento real» de menores) y que sin consentimiento o con señal de menor el juego queda en la base?
8. **Abogado:** ¿quién y cuándo? Antes de F1 en producción hay que cerrar: propósito TCF, texto de privacidad nuevo (uso: «personalizar ayudas y ofertas»), región de Supabase y
   transferencia internacional (Ley 25.326), y el texto de ASC.
9. **Texto del spec §5:** ¿corregimos «App Store 5.6 lo prohíbe expresamente» (ver R1)?

## Qué quedó `[SUPUESTO]` (lista corta)
- Tiers de país de la tabla semilla (sin cifras de eCPM por país: no las tengo).
- Que AdMob no exponga el valor antes de mostrar (la doc no lo menciona; no está probado como negativo).
- Que MAX lo exponga al cargar (no confirmado).
- Que la API de AdMob maneje pisos (no confirmado).
- Todas las cifras de R8 (consentimiento, tasa de impresión, volumen, 3,3 instalaciones por etiqueta).
- La aproximación lineal de R7 (≈ 27,9 h con ×2,5 completo).
- El volumen de eventos por jugador/día y el plan de Supabase.
- La lectura jurídica completa (UE, Argentina, COPPA, TCF 5/6): sin abogado.
- Que 9 y 10 no alcancen para segmentar en el RGPD.

## Tareas para el plan (derivadas)
1. `PacingSegment` + flags del CLI + guardas en CI (R7). No correr hasta liberar la Mac.
2. `Docs/v21/country-tiers.json` semilla y el script de reporte `networkReport` (R3).
3. Eventos `segment`, `exposure`, `offer.ctx` como migración + enum + test del CHECK (R4).
4. Texto de `privacy.md` y de ASC para «personalizar ayudas y ofertas»; pantalla de retiro del consentimiento (R5).
5. Variable de consentimiento ampliada `{1,5,6,8,9,10}` si el dueño lo aprueba (R5).
6. Spike de MAX sólo si el dueño lo pide (R2).
