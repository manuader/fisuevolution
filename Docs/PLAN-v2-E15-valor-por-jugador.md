# E15 — Valor por jugador: personalizar el juego según lo que vale cada usuario

**Estado:** RESPONDIDO por el dueño el 2026-10-15 (decisiones V1–V3 en §0). **Antes de lanzar va sólo F0**
(instrumentación), cargada en `DUENO.md`. El resto (investigación R1–R8 y fases F1–F7) va **en una 2.1**, con datos
reales. El número de épica (E15) lo confirma el relevo contra `Docs/PLAN-v2.md`.

**Origen:** el dueño pidió estudiar el reel de @ayoships sobre Block Blast
(<https://www.instagram.com/p/DecfvksvHiW/>) y armar una estrategia parecida para FisuEvolution: medir cuánto vale cada
jugador en anuncios y ajustar el juego según ese valor.

---

## 0. Decisiones del dueño (2026-10-15, no se vuelven a preguntar)

| # | Decisión |
|---|---|
| V1 | **Antes de lanzar la 2.0 se mide; el resto va en la 2.1.** F0 entra en la 2.0 para juntar datos desde el día 1. R1–R8 y F1–F7 van después de lanzar. |
| V2 | **Telemetría anónima a Supabase**, con un id de instalación, respetando UMP/ATT, con la política de privacidad y la etiqueta de App Store Connect actualizadas. |
| V3 | **El premio por video puede ser más grande para los jugadores de más valor, con un tope** (p. ej. de ×2 a ×2,5 según el segmento). Se calibra en F2 con el pacing-sim por segmento. |
| — | El camino es el de §4: personalizar ayudas, ofertas y anuncios según el valor, sin amañar en secreto (§5). |

### F0 en detalle (la tarea que va antes de lanzar)

1. **`AdRevenueLedger`:**
   - Se engancha a `paidEventHandler` en todos los formatos: rewarded (los 8 lugares), interstitial, rewarded
     interstitial y app open.
   - Guarda en el save, como campo opcional nuevo, el valor de cada impresión (`GADAdValue`: micros, moneda,
     precisión) con el formato, el lugar y la hora.
   - Lleva agregados por formato: los últimos N, el máximo, el promedio y el total.
   - Es lo mismo que `ad_revenue_recent`, `ad_revenue_max` y `ad_revenue_avg_reward` del reel.
   - Tests de ida y vuelta del save y de los agregados.
2. **Embudo de ofertas:** por lugar, cuántas veces se mostró, se aceptó, se completó y se cerró. Sale de
   `RewardedOfferButton` y de los pop-ups de recompensa; coordinar con B29, el ×2 en dos pasos.
3. **Telemetría a Supabase (V2):**
   - Tabla de eventos con un id de instalación anónimo (UUID propio, no el IDFA) y política RLS de sólo insertar para
     `anon`.
   - Lotes con cola offline.
   - Un interruptor remoto, apagado por default hasta que la privacidad esté al día.
   - Eventos mínimos: sesión (inicio y fin), país de la tienda (`Storefront`), rango de dispositivo, impresión con su
     valor, oferta (mostrada, aceptada, completada), compra y prestigio.
   - Sin datos personales.
   - El SQL del esquema queda en el repo para que el dueño lo corra, como `admin.sql`.
4. **Privacidad, antes de prender el interruptor:**
   - actualizar `privacy.md` y los términos;
   - actualizar la etiqueta de App Store Connect (uso y analítica, no vinculados a la identidad; se hace con
     release-ops);
   - activar «impression-level ad revenue» en la cuenta de AdMob (release-ops por Chrome; si pide la sesión del dueño,
     anotarlo en `DUENO.md`).
5. **Fuera de F0:** no cambia la economía, no hay personalización, no se toca el ritmo. Sólo se mide.

- **Listo cuando:**
  - Hay unit del ledger y de los agregados.
  - Un test de la cola de telemetría verifica que no manda nada con el interruptor apagado ni sin consentimiento.
  - Un UI test con el anuncio stub verifica que una impresión queda en el ledger.
  - El SQL está en el repo.
  - Los textos de privacidad quedan en borrador para el dueño.
- **Revisión:** opus (save, anuncios y privacidad).

---

## 1. Resumen

- **Qué muestra el reel.** Block Blast predice en el teléfono cuánto vale cada jugador en anuncios, con un modelo
  XGBoost bajado por configuración remota. Con esa predicción cambia la dificultad en secreto:
  1. te da la «mejor partida de tu vida»;
  2. cuando hay cargado un anuncio caro, amaña las piezas para que pierdas;
  3. en ese momento te ofrece revivir a cambio de ver el anuncio;
  4. si revivís, te suma a escondidas hasta un 10 % al puntaje para que vuelvas.

  Además, un bandido multibrazo prueba en qué minuto conviene hacerte perder.
- **Qué se puede traer a FisuEvolution.** La parte que más plata explica se trae completa: **medir el valor de cada
  jugador** y **personalizar según ese valor**:
  - cuántas ofertas con video ve, cuándo y de qué tamaño;
  - el ritmo de las ayudas (cajas, colchón, visitantes, Ruleta);
  - las ofertas de la Tienda;
  - los pisos de precio de los anuncios por país (los «precios dinámicos» reales del negocio de anuncios);
  - la frecuencia de los anuncios forzados.

  A quien más vale se le hace el juego **más fácil**, y ve más oportunidades de ver un video a cambio de algo.
- **Qué no propongo copiar** (sección 5):
  - amañar en secreto un resultado para forzar una «derrota» que sólo se arregla con un video;
  - falsear en secreto lo que el juego le muestra al jugador, como el puntaje +10 %.

  Esto choca con la regla de conducta del App Store (5.6: nada de engañar ni de prácticas manipuladoras), con leyes de
  defensa del consumidor, y con un juego 12+ al que entran menores. Es, además, exactamente lo que hizo viral al reel
  (1,2 M de likes, comentarios como «esto debería ser ilegal» o «borro todos los juegos con anuncios»). Para cada una
  de esas piezas hay una versión a la vista que aprovecha el mismo momento.
- **Lo que falta hoy en el juego para hacer cualquiera de las dos cosas:**
  - **no hay telemetría**;
  - **no se registra cuánto paga cada anuncio** (no se usa `paidEventHandler` de AdMob);
  - Supabase sólo se usa para el ranking.

  Sin datos no hay modelo: la Fase 0 es instrumentar.

---

## 2. El reel, cuadro por cuadro

**Ficha:** @ayoships, 65,4 s, 1080×1920, subtítulos quemados en la imagen y audio original. Al 2026-10-15 tenía 1,2 M
de likes y 9,4 K comentarios, publicado el día anterior. El autor promete «la explicación técnica completa y el código»
en su web. **Las afirmaciones no están verificadas** (ver R1).

### 2.1 Guion completo (subtítulos leídos cada 0,25 s)

| Tiempo | Original | Traducción |
|---|---|---|
| 0:00–0:07 | I reverse engineered Block Blast to figure out how a free puzzle game makes over $100 million in ads. That's more than Candy Crush. | Le hice ingeniería inversa a Block Blast para entender cómo un juego de puzzle gratis hace más de 100 millones de dólares en anuncios. Más que Candy Crush. |
| 0:07–0:12 | And it turns out how well you do in the game has less to do with your skill and more to do with how much you're worth to them in ads. | Y resulta que lo bien que te va en el juego depende menos de tu habilidad y más de cuánto valés para ellos en anuncios. |
| 0:12–0:17 | It takes your phone model, your country, how much your past ads have made them, even whether you turned off the vibration on your phone. | Toma el modelo de tu teléfono, tu país, cuánto les dejaron tus anuncios anteriores, y hasta si apagaste la vibración. |
| 0:17–0:22 | It all goes into an XGBoost model that runs locally on your phone that predicts how much you can be worth to them in ads. | Todo entra en un modelo XGBoost que corre en tu teléfono y predice cuánto podés valer para ellos en anuncios. |
| 0:22–0:25 | Then, depending on your value, it'll make the game easier or harder. | Después, según tu valor, te hace el juego más fácil o más difícil. |
| 0:25–0:31 | One rule called "Boost then kill" secretly makes it easier, so you think you're on the best run of your life, right up until you hit your average game length. | Una regla llamada «Boost then kill» (primero ayudá, después matá) lo hace más fácil en secreto, para que creas que estás en la mejor partida de tu vida, hasta que llegás a tu duración promedio de partida. |
| 0:31–0:34 | And if it detects a really expensive ad is ready, that's when it turns on you. | Y si detecta que hay listo un anuncio muy caro, ahí se da vuelta contra vos. |
| 0:34–0:40 | A rule called "High value ad harvest" confirms that you have a history of watching ads, then helps you beat your high score before it triggers something called the death algorithm, | Una regla llamada «High value ad harvest» (cosecha de anuncios de alto valor) confirma que tenés historial de ver anuncios, te ayuda a superar tu récord y recién ahí dispara algo llamado «el algoritmo de la muerte», |
| 0:40–0:43 | which rigs your next turn so there's no way to survive. | que amaña tu próximo turno para que no haya forma de sobrevivir. |
| 0:43–0:47 | And the moment you lose, the first thing you see is an offer to revive if you watch that same ad. | Y apenas perdés, lo primero que ves es una oferta para revivir si mirás ese mismo anuncio. |
| 0:47–0:51 | And if you do revive, they'll even secretly add 10% to your high score so you keep coming back for more. | Y si revivís, encima te suman a escondidas un 10 % al récord para que sigas volviendo. |
| 0:51–0:57 | In fact, they even run experiments on the exact minute to make you lose, and they measure which one gets you to watch the revive ad. | De hecho, hasta hacen experimentos sobre el minuto exacto en que te hacen perder, y miden cuál te lleva a ver el anuncio para revivir. |
| 0:57–1:03 | So all things considered, Block Blast isn't really a puzzle game. It's more of an ad harvest with a rigged game loop built to squeeze every penny out of you. | Así que, en resumen, Block Blast no es un juego de puzzle: es una cosecha de anuncios con un ciclo de juego amañado para sacarte hasta el último centavo. |
| 1:03–1:05 | Let me know in the comments what app you'd like to see decompiled next. | Dejame en los comentarios qué app querés que descompile después. |

### 2.2 Lo que se ve

| Tiempo | Imagen | Para qué está |
|---|---|---|
| 0:00 | El autor a cámara, con micrófono de mano. | Gancho: «le hice ingeniería inversa». |
| 0:01–0:03 | La ficha de Block Blast en el App Store: 4,9 estrellas, 13+, puesto 7. | Que es un juego masivo y bien puntuado. |
| 0:04–0:06 | Gráfico «Top Games by Ad Revenue, enero–mayo 2026»: Block Blast 127 M USD, Vita Mahjong 89,8 M, Candy Crush 81,1 M. | El tamaño del negocio. |
| 0:08–0:09 | Partida con una columna resaltada. | «Lo bien que te va». |
| 0:12–0:13 | Código `EcpmFeatureConfig`: tablas `PHONE` (`"iPad16,6": 1`, `"iPhone17,2": 12`, `"iPhone16,2": 23`, `"iPhone9,4": 120`) y `COUNTRY` (`ST: 1`, `US: 2`, `DZ: 238`). | El modelo y el país se codifican como un rango: los números parecen posiciones en un ranking de eCPM, no montos. |
| 0:14 | Código `packageData()`: `country`, `device_model`, `bgm_switch`, `vibrate_switch`, `ad_revenue_recent`, `ad_revenue_max`, `ad_revenue_avg_reward`. | Las variables del modelo: dispositivo, país, dos interruptores de Ajustes y el ingreso real por anuncio. |
| 0:15–0:16 | Ajustes del juego: Sound, BGM y Vibration, con la vibración marcada. | Los interruptores funcionan como señal de compromiso: quien juega con música suele jugar más tiempo. |
| 0:17–0:22 | Código: `modelUrl: ".../remote/json/xgboost_regression_model111.json"` y `runModel()`, que recorre los árboles (`left_children`, `right_children`, `split_conditions`, `base_weights`), suma y aplica `Math.expm1`. | Regresión con árboles potenciados entrenada afuera, bajada por configuración remota (se cambia sin publicar versión) y evaluada en el teléfono. El `expm1` indica que entrenaron sobre log(1+ingreso). |
| 0:23–0:24 | El autor a cámara. | «Más fácil o más difícil». |
| 0:25–0:26 y 0:35 | Lista de «Traits», reglas que se prenden por jugador: `LoginTimeFirstDifficultyRatioTrait`, `LongThinkClearAssistTrait`, `LowFeedbackPleasurableOfferTrait`, `LowHardSetFps30Trait`, `MABXiBaiTrait`, `MaturityDevelopmentV2Trait`, `MultiClearBoostThenKillTrait`, `NewBottomOfferTrait`, `NewPlayerContinuePlayIncentiveTrait`, `RewardHighValueAdHarvestTrait` y unas 40 más. | La arquitectura: decenas de reglas chicas, activables por segmento. |
| 0:27–0:29 | Partida fácil. | «La mejor partida de tu vida». |
| 0:30 | `MultiClearBoostThenKillTrait`: cuenta rondas de éxito; `checkTimeCondition` compara con `killDelaySeconds`; `setAlgorithmList([OFFER_TYPE.ZHI_SI_TI])`. | «致死题» (zhì sǐ tí) se traduce como «pieza letal». |
| 0:31–0:34 | `RewardHighValueAdHarvestTrait`: `HIGH_PRICE_MULTIPLIER = 3.5`, `MIN_HISTORY_AD_WATCH_COUNT = 3`; el anuncio cargado es «high» si vale al menos 3,5× la referencia; no se dispara si viste menos de 3 anuncios con premio. | Sólo «cosecha» a quien ya demostró que mira videos, y sólo cuando el anuncio listo es caro. |
| 0:38–0:41 | `currentScoreThreshold = récord + paso × (t + 1)`; `shouldTriggerDeath = puntaje < umbral && isTargetAdReady()`; si da verdadero, `setAlgorithmBottomList([deathAlgorithm])`. | Te deja superar el récord y, con el anuncio listo, cambia el generador de piezas. |
| 0:42–0:44 | Tablero lleno y «No Space Left». | La derrota fabricada. |
| 0:45–0:47 | `Revive_Proxy`: eventos `E_Revive_Show`, `E_Revive_Close`, `E_Advertisement_RewardOver` y `E_Revive_Success`. | La oferta de revivir con video, justo en la derrota. |
| 0:48–0:50 | `AdPlusMinusStrategyTrait.onAdd1ReviveSuccess`: `t = floor(0.1 × highScore)`, `r = random(0…t)`, `classScore = i + r`. | Al revivir, suma al azar hasta un 10 % del récord. |
| 0:51 | Pantalla «Your Best is Next»: puntaje 2, récord 2107. | El gancho para volver. |
| 0:52–0:56 | `MABXiBaiTrait`: brazos `{2: 240, 3: 360, 4: 600, 5: 1e3, 6: 1800}` segundos (4, 6, 10, 16,7 y 30 min); recompensa del brazo = `reviveSuccess / reviveShow`; `reportArm(i, r)`. | Un bandido multibrazo elige en qué minuto de la sesión matar, y optimiza la conversión del video de revivir. |
| 0:57–1:05 | Muro de código y el autor a cámara. | Cierre y llamada a la acción. |

### 2.3 La estrategia, desarmada

1. **Valor esperado por jugador, en el teléfono.**
   - Las variables: rango de eCPM del modelo de teléfono y del país, ingreso real de sus anuncios (reciente, máximo y
     promedio de los anuncios con premio) y señales de compromiso (música, vibración).
   - El modelo es una regresión XGBoost entrenada afuera con millones de jugadores, servida por configuración remota.
2. **Reglas activables por segmento** (los «Traits»): dificultad inicial, ayuda cuando el jugador piensa mucho, ofertas
   cuando hay poca recompensa, etc.
3. **Ciclo de ayuda y castigo**, sincronizado con un anuncio caro ya cargado: ayudar hasta la duración promedio de la
   partida y matar.
4. **Sólo con quien mira videos:** al menos 3 vistos.
5. **La oferta en el pico de frustración:** revivir con video.
6. **Refuerzo falso:** récord inflado en secreto.
7. **Experimentación continua:** un bandido sobre el minuto, que maximiza la conversión.

Lo que realmente mueve la plata es: **(1)** saber cuánto vale cada impresión de cada jugador; **(3)** mostrar la
oferta cuando el anuncio cargado es caro; **(5)** mostrarla en un momento de necesidad; y **(7)** optimizar con
experimentos. Las partes engañosas (el amaño y el puntaje falso) son una forma de **fabricar** ese momento de
necesidad.

---

## 3. Qué tiene hoy FisuEvolution

- **AdMob:**
  - 8 bloques rewarded: regalos, offline ×2, cofre extra, boost, Ruleta, colchón, visitante y diario.
  - Interstitial, rewarded interstitial y app open, con cadencia en `ads.json`: 120 s entre forzados, 180 s de gracia
    al abrir y 90 s después de un rewarded.
  - El consentimiento es UMP y después ATT (`AdsConsent`).
- **No se registra cuánto paga cada impresión.** No hay `paidEventHandler` / `GADAdValue`.
- **No hay telemetría ni analytics.** Supabase se usa sólo para el ranking (`HTTPRankingClient`).
- **La economía es determinista y está calibrada:** contrato de ritmo Dios ≈ 45 h en el perfil free, con el pacing-sim
  en CI.
- **El juego es un idle de merge:** no hay derrota. Los «momentos de necesidad» son naturales:
  - piso lleno;
  - pared de precio (el próximo contrato cuesta mucho más de lo que entra);
  - pared de reencarnación;
  - esperar una caja o el colchón;
  - volver después de horas.
- **Clasificación 12+.** Puede haber menores entre los jugadores.

---

## 4. La estrategia para FisuEvolution: «Valor por jugador»

Cuatro palancas, todas con un tope y con un interruptor remoto para apagarlas:

1. **Valor estimado por jugador (VEJ).** Ingreso esperado por anuncio con premio y por día, calculado en el teléfono.
   - **v1:** reglas con tablas. Rango de eCPM por país, sacado del informe de AdMob de la v1 publicada; rango por modelo
     de dispositivo; historial propio de ingreso por impresión; compras; compromiso (sesiones por día, duración,
     notificaciones, música).
   - **v2:** un modelo de árboles entrenado con datos propios, servido por configuración remota y evaluado en el
     teléfono. Es la misma técnica del reel.
2. **Más ayuda a quien más vale.** El jugador de alto valor ve **más oportunidades opt-in**:
   - más visitantes con oferta;
   - el ×2 de B29 más seguido;
   - colchón de regalo un poco más frecuente;
   - Ruleta;
   - premios un poco más grandes por video.

   **El contrato base no empeora para nadie:** la personalización sólo **suma** ayudas sobre el ritmo free de 45 h.
   Así, ver videos rinde más y se nota, en vez de que no verlos te castigue en secreto.
3. **La oferta en el momento justo.** Detectores de **necesidad natural** (piso lleno, pared de precio de más de N
   minutos, colchón listo, vuelta después de estar offline) combinados con **un anuncio cargado**, y si el SDK lo
   permite, con **un anuncio caro cargado** (ver R2).
   - La oferta va a la vista: «Mirá un video y el próximo contrato sale gratis» o «×2 a tus ganancias offline».
   - Un bandido multibrazo, como el del reel, pero optimizando el **momento, el lugar y el tamaño de la oferta**,
     medidos por conversión **y** por retención (D1/D7), para que no gane un brazo que hace abandonar el juego.
4. **Precios dinámicos donde son legítimos:**
   - **Pisos de eCPM por país** en los grupos de mediación de AdMob (se cobra más por cada impresión de los países
     caros). Se maneja con release-ops.
   - **Ofertas de la Tienda por segmento:** el pack de inicio a quien tiene probabilidad de comprar, y el pack de blue
     a quien ya compró. Los precios de App Store van por tiers fijos: cambia **qué** oferta ve cada uno, no el precio
     de un mismo producto. En la UE, si se personaliza, hay que avisarlo (ver R5).
   - **Cadencia de forzados por segmento:** por ejemplo, menos interstitials a quien mira muchos rewarded, para
     cuidarle la retención.

---

## 5. Lo que no propongo, y cómo aprovechar el mismo momento sin engañar

| Del reel | Por qué no | La versión que sí |
|---|---|---|
| **Boost then kill / algoritmo de la muerte:** amañar en secreto para que pierdas cuando hay un anuncio caro. | Engaña sobre el resultado del juego y fabrica la necesidad que se vende con el video. App Store 5.6 lo prohíbe expresamente (engañar, prácticas manipuladoras) y es una causa de rechazo o de baja de la cuenta de desarrollador. Además, es la conducta que reguladores como la FTC y las autoridades de consumo europeas están persiguiendo como «patrón oscuro», en un juego 12+. | **Momentos de necesidad naturales**, detectados, más una oferta a la vista cuando hay un buen anuncio cargado (palanca 3). |
| **+10 % secreto al récord.** | Es falsear lo que el juego le muestra al jugador. | **Bonus anunciado:** «+10 % por ver el video», que el jugador ve y elige. |
| **Dificultad peor que la base según el valor**, a escondidas. | El mismo problema, y en un idle es lo primero que se nota al comparar teléfonos (ver el comentario del reel: «258 K en el teléfono de mi novio y yo trabada en 40 K»). | **La base es igual para todos**; lo que cambia es cuánta ayuda opt-in ves (palanca 2). |
| **Bandido sobre el minuto de matar.** | Optimiza el daño. | **Bandido sobre el momento, el lugar y el tamaño de la oferta**, con la retención como límite (palanca 3). |

El riesgo de negocio concreto es que el reel existe porque alguien descompiló Block Blast, y una app de Swift también
se descompila. FisuEvolution no tiene el colchón de 127 M USD de Block Blast para aguantar una ola de reseñas de una
estrella o una baja de la cuenta.

---

## 6. Plan de investigación (antes de escribir código)

| # | Pregunta | Cómo | Entregable |
|---|---|---|---|
| R1 | ¿Es cierto lo del reel? | Seguir la publicación técnica que promete @ayoships, buscar otras descompilaciones de Block Blast (Hungry Studio) y leer su política de privacidad. | Nota: qué está confirmado y qué no. |
| R2 | ¿Qué deja saber AdMob en iOS? | Ingreso por impresión (`paidEventHandler` / `GADAdValue`; hay que activar «impression-level ad revenue» en la cuenta). Ver si **antes** de mostrar se puede saber cuánto vale el anuncio cargado: en AdMob, en principio no; AppLovin MAX expone un ingreso estimado al cargar, a verificar. Grupos de mediación por país y pisos de eCPM. | Tabla de capacidades y recomendación: quedarse en AdMob o evaluar MAX. |
| R3 | ¿Cuánto vale cada país y cada dispositivo **para nosotros**? | Informe de AdMob de la v1 (eCPM por país × formato × plataforma) con release-ops. | Tabla de rangos de país, la versión propia de `EcpmFeatureConfig`. |
| R4 | ¿Qué datos hacen falta y cómo se juntan bien? | Eventos mínimos a Supabase con un id de instalación anónimo: país, rango de dispositivo, sesiones, impresiones con su valor, ofertas mostradas y aceptadas, compras. Consentimiento UMP/ATT, y actualizar la etiqueta de privacidad de la App Store y `privacy.md`. | Esquema de eventos, cambios de privacidad y retención de datos. |
| R5 | ¿Qué dicen las reglas? | App Store 5.6, 5.1.1–5.1.2 (uso de datos) y 3.1; políticas de AdMob para rewarded (opt-in); en la UE, personalización de precios (aviso obligatorio) y la directiva de prácticas desleales; Argentina, Ley 24.240 (defensa del consumidor) y Ley 25.326 (datos personales); menores (12+, COPPA si hay menores de 13). **Con un abogado** para lo legal. | Lista de qué se puede y qué no, con los avisos necesarios. |
| R6 | ¿Qué hace la industria sin engañar? | Segmentación LiveOps, ofertas personalizadas, dificultad adaptativa orientada a la retención, pisos por país. | 1 página de referencias. |
| R7 | ¿Rompe el ritmo? | Extender el pacing-sim con segmentos (bajo, medio, alto) y con las palancas: ningún segmento más lento que free 45 h, y el alto con un piso (p. ej. Dios no antes de 30 h). | Tabla de ritmo por segmento en `balance-log.md`. |
| R8 | ¿Cuántos datos hacen falta para el modelo v2? | Con la base de jugadores de la v1, estimar cuándo hay suficientes para entrenar (orden de magnitud: miles de jugadores con ingreso por impresión). | Fecha estimada para pasar de reglas a modelo. |

---

## 7. Plan de implementación (fases)

Cada fase con su spec, sus tests y su revisión opus, porque toca la plata, los anuncios y la privacidad.

- **F0 — Instrumentación.** La única que conviene antes de lanzar, para juntar datos desde el día 1.
  1. `AdRevenueLedger` en el teléfono: el `paidEventHandler` de cada formato guarda el valor de la impresión (reciente,
     máximo y promedio por formato) en el save.
  2. Contadores de embudo de ofertas: mostrada, aceptada, completada, por lugar.
  3. Telemetría anónima a Supabase, apagable por configuración remota, que respeta UMP/ATT.
  4. Actualizar `privacy.md` y la etiqueta de privacidad de App Store Connect.
- **F1 — VEJ v1 con reglas.** `PlayerValue` en EconomyKit, determinista y con tests.
  - Entradas: rango de país, rango de dispositivo, el ledger, compras y compromiso.
  - Salida: segmento y valor esperado por video.
  - Las tablas van por configuración remota (JSON en Supabase, como el ranking).
- **F2 — Palancas de ayuda por segmento**, con tope.
  - Afecta: ofertas de visitantes, frecuencia del ×2, colchón de regalo, tamaño del premio por video y cadencia de
    forzados.
  - Todo en una tabla `segments.json` con topes. El pacing-sim corre por segmento en CI: ninguno más lento que la
    base.
- **F3 — Momento justo.**
  - Detectores de necesidad natural más el estado del anuncio cargado.
  - Una oferta a la vista en cada momento.
  - Bandido multibrazo (p. ej. Thompson) sobre el momento y el lugar, con brazos por configuración remota y la
    retención como límite.
- **F4 — Precios de anuncios por país.** Grupos de mediación y pisos de eCPM por rango de país en AdMob, gestionados
  con release-ops.
- **F5 — Ofertas de Tienda por segmento.** Qué pack ve cada uno, con aviso de personalización donde la ley lo pida (R5).
- **F6 — VEJ v2 con modelo entrenado.**
  - Entrenamiento afuera (XGBoost o LightGBM) con los datos de F0, exportado a JSON de árboles.
  - Evaluador en Swift: la misma técnica que el `runModel()` del reel.
  - El modelo se versiona y se compara por A/B contra las reglas de F1.
- **F7 — Panel.** Ingreso por jugador por segmento, conversión por oferta, retención D1/D7 y ritmo real contra el
  simulado.

**Guardarraíles para todas las fases:**
- un interruptor remoto que vuelve todo a la base;
- la base de 45 h es igual para todos;
- ningún resultado falso;
- toda oferta es opt-in y a la vista;
- sin perfilado si el jugador rechaza el consentimiento donde la ley lo exige.

---

## 8. Preguntas para el dueño

1. ¿Va el camino de la sección 4: personalizar ayudas, ofertas y anuncios según el valor, sin amañar en secreto?
2. ¿Cuándo? Recomendado: **F0 (instrumentación) antes de lanzar la 2.0**, y el resto en una 2.1 con datos reales.
3. ¿Telemetría anónima a Supabase (necesaria para el modelo v2 y para medir), o todo sólo en el teléfono (alcanza para
   las reglas v1 con las tablas de AdMob)?
4. ¿El premio por video puede ser más grande para los jugadores de más valor (dentro de un tope), o igual para todos y
   sólo cambia cuántas ofertas ve cada uno?
