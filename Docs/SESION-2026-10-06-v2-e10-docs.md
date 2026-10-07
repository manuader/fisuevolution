# Sesión 2026-10-06 — E10 en papel: el setup de la 2.0, los IAP y los Términos

## El pedido

La parte documental de E10 y la copia legal de E7, adelantadas mientras las
épicas de código arrancan. No toca código. Cuatro entregables:

1. El doc de configuración del ítem 18:
   `Distribution/setup-v2-asc-admob-mediacion.md`, con las secciones 1 a 5 de
   E10 (App Store Connect, AdMob, las 4 redes, el sitio y el futuro script).
2. `Distribution/iap-appstore-connect.md` al día con la 2.0.
3. Los Términos (es y en) corregidos en lo que saca `remove_ads`, con su copia
   del bundle.
4. El checklist del ítem 19 (los IAP en inglés), que quedó adentro del doc 1,
   sección 1.5.

## Lo que se hizo

### 1. El doc de setup

`Distribution/setup-v2-asc-admob-mediacion.md`, con 🔒 en cada paso que hace
o verifica el dueño en un panel. Arranca con un orden recomendado (las cuentas
de las redes primero, porque tardan) y después:

- **App Store Connect**: Novedades de la 2.0.0 en es y en; el idioma es-ES
  nuevo de la ficha; los cambios de la descripción; capturas de iPhone y del
  iPad 13"; la tabla de los 14 productos con su estado, sus notas de revisión
  y **el conteo de caracteres de las 42 fichas** (14 productos × es-MX, es-ES y
  en-US); el checklist del ítem 19; el cuestionario de edad; App Privacy; las
  notas a App Review en inglés, listas para pegar; y apagar Mac y Vision Pro.
- **AdMob**: las 11 unidades (las 6 que existen y las 5 nuevas), con su clave
  en `adUnitIDs`; los ajustes de cada una; los **4 grupos de mediación por
  formato**, con qué red entra en cuál; socios de GDPR y de EE. UU.; el
  bloqueo de categorías; dispositivos de prueba y Ad Inspector.
- **Por red** (AppLovin, Unity Ads, Mintegral y Meta): cuenta, registro,
  placements, las claves que pide AdMob, la línea de `app-ads.txt`, de dónde
  salen los SKAdNetwork IDs y cómo probar. Cada dato con la URL oficial de
  donde salió. Más una tabla para E7a: paquete SPM, versión mínima y última,
  y el código de privacidad que pide cada adaptador.
- **El sitio**: `app-ads.txt`, la política (`legal.ts`), los Términos
  (`terms.ts`) y `config/ads.json`, sólo descriptos.

### 2. `iap-appstore-connect.md`

- 14 productos: las 3 ofertas como consumibles, con fichas y entrega.
- Packs de ORO a 160 / 550 / 1.400 en la tabla de entrega, con los montos de
  la v1 al lado. La plata pasa a horas de producción (E2a).
- Idiomas de la ficha: es-MX + **es-ES** + en-US.
- Cuatro fichas reescritas y una renombrada (ver decisiones).
- Se mantuvo el formato de las fichas (`- ES ·` / `- EN ·`), que lee E3 para
  `IAPCopy`.

### 3. Los Términos

`Distribution/site/terms.md` y `FisuEvolution/Resources/Legal/terms.md`
(copia byte a byte, la exige `LegalDocumentTests`). La sección 4 decía que
"Sin anuncios" sacaba los videos recompensados, y era falso: ahora separa los
videos con recompensa (opcionales, siguen) de los anuncios que aparecen solos
(pantalla completa, pausa publicitaria y al volver a la app), que son los que
saca la compra. Fecha de actualización: 6 de octubre de 2026.

## Decisiones y su porqué

1. **es-ES lleva el mismo texto que es-MX, con voseo.** El castellano del
   juego es rioplatense en todos lados; una ficha "neutra" sólo para España
   sería otra voz. Lo que arregla el ítem 19 es que **exista** la
   localización es-ES, no su dialecto.
2. **"Cofre de ORO" pasa a "Saco de ORO"** (`oro_medium`). HANDOFF §5 ya dice
   que "cofre" es sólo el de pintas, y en la 2.0 la tienda de ORO vende un
   cofre al azar. Un IAP de plata real llamado "Cofre" se lee como una caja
   sorpresa paga (guía 3.1.1).
3. **Las descripciones no llevan montos de ORO.** PLAN-v2 §2 dice que los
   montos se ajustan con el simulador sin tocar el precio: con el número en la
   ficha, cada calibración obligaría a re-enviar a revisión. Los montos viven
   en la tabla de entrega y en las notas a App Review. Las horas y el ×3 de
   las ofertas sí van, porque son lo que define cada pack.
4. **`remove_ads` y `starter_pack` dicen lo que hacen**: "Chau a los anuncios
   que aparecen solos" / "sin anuncios forzados". La v1 decía "Sacá los
   anuncios para siempre", y los videos con premio nunca se fueron.
5. **Los Términos nuevos valen también para la v1**: dicen "pueden ser" y no
   prometen formatos. Se pueden publicar ya, sin esperar a la 2.0.
6. **La política de privacidad no se tocó**: la v1 no usa las 4 redes, y
   declararlas antes de tiempo es declarar mal. El doc de setup (4.2) deja
   los tres puntos que cambian, para aplicarlos el día del lanzamiento en los
   tres lugares a la vez.
7. **El esquema de `config/ads.json` no se inventó**: lo define E7a con
   `AdsRemoteConfig`, y el archivo del sitio es copia del respaldo del
   bundle. El doc sólo fija las reglas del plan (HTTPS, IDs del publisher
   propio, `BEL` y `AUS` en tres letras como `Storefront.countryCode`).
8. **"Pack de Bienvenida"** y no "Oferta de Bienvenida": así las tres ofertas
   se leen como packs ("Pack Renacer", "Pack Mudanza").
9. **Bloquear "Social Casino Games" en AdMob**: viene permitida por defecto,
   y mostrar casinos simulados en un juego que declara "sin apuesta simulada"
   es la contradicción que un revisor marca.
10. **Mac y Vision Pro apagados**: se publican solos si no se destilda, y no
    se probaron.

## Cómo se verificó

- **Fichas**: un script contó las 42 (`len()` de Python; todos los caracteres
  son del plano básico, así que coincide con App Store Connect). **0 sobre el
  tope**; la más larga, 45/45. La tabla del doc de setup se generó desde el
  archivo de IAP, no a mano, y se re-chequeó fila por fila.
- **Notas a App Review**: 3.459 caracteres, todos ASCII (tope 4000).
- **Términos**: `cmp` entre la copia del sitio y la del bundle → idénticas.
  La estructura que pinea `LegalDocumentTests` no cambió: dos títulos (el
  segundo termina en "(English)"), el contacto y viñetas con el mismo formato
  que el resto del archivo.
- **URLs citadas**: 40 únicas. 39 responden 200; la que da 404 es
  `config/ads.json`, que todavía no existe y el doc lo dice.
- **SKAdNetwork**: se bajaron las listas oficiales y se cruzaron con el
  `Info.plist`. Tenemos 50 (los de Google, que sigue publicando 50); AppLovin
  152 (102 nuevos), Unity 76 (39), Mintegral 105 (65), Meta 2 (0). Unión: 156,
  **106 nuevos**. El ID propio de cada red ya estaba.
- **El sitio publicado** (`curl`, 2026-10-06): `app-ads.txt` con una sola
  línea (Google); `/terms` y `/es/terms` con el texto viejo; `/privacy` ya con
  el texto de `privacy.md`; `config/ads.json` en 404.
- **El oráculo no se corrió**: el frente no toca código (pedido del
  coordinador). El único archivo del bundle tocado es `Resources/Legal/terms.md`,
  que cubren `LegalDocumentTests`. ⚠️ Conviene que la próxima corrida del
  oráculo `rapido` sobre la rama integrada lo confirme.

## Trampas nuevas

- **Un agente aislado en un worktree no puede trabajar en otro, ni con
  `EnterWorktree`.** Este frente se lanzó con la sesión atada a `v2-e0` y el
  encargo en `v2-e10-docs`. `EnterWorktree(path:)` cambia el directorio, pero
  Bash, `Edit` y `Write` siguen rechazando todo lo que no sea `v2-e0`, y git
  con `-C` o con `cd` también. No se esquivó: los archivos se dejaron en el
  scratchpad con la misma estructura del repo, y el coordinador los copia y
  commitea. **Lanzar cada agente con el directorio de trabajo en su propio
  worktree.**
- **El checkout local de `adergames-site` está atrasado**: es del 2026-09-02,
  sin `public/app-ads.txt` y con la política de julio, mientras el sitio
  publicado ya tiene las dos cosas. Antes de editarlo, `git pull`.
- **La doc de Mintegral no se puede leer sin JavaScript**: `WebFetch` trae
  sólo el menú. La línea de `app-ads.txt` de Mintegral quedó marcada como no
  verificada; los SKAdNetwork sí (su JSON es estático).
- **Las "5 descripciones de más de 45" del plan están en el `.storekit`, no en
  `iap-appstore-connect.md`**: el doc ya venía recortado. Las largas son
  starter (es 53, en 51), Mundialista (es 50, en 53) y Diamante (es 46).
- **Apple renombró los tamaños de captura**: ahora son *iPhone with Dynamic
  Island (large / medium display)*, y la página marca como obligatorio el
  *medium* (1206 × 2622). La v1 salió sólo con 1320 × 2868.
- **"Social Casino Games" viene permitida en AdMob**; "Gambling & Betting"
  viene bloqueada. Son dos categorías distintas.

## Qué queda

- **Gates del dueño** (todo lo marcado 🔒 en el doc de setup): cuentas de las
  4 redes, unidades nuevas de AdMob, grupos de mediación, `app-ads.txt`,
  productos y localizaciones en App Store Connect, formularios y capturas.
- **E3 (`IAPCopy`)**: tomar las fichas nuevas de `iap-appstore-connect.md`.
  Cambian el nombre de `oro_medium`, las descripciones de `starter_pack`,
  `remove_ads`, `oro_small` y `oro_medium`, y entran las 3 ofertas.
- **E6**:
  - sincronizar el `.storekit` con las fichas, incluidas las 3 ofertas;
  - **la hoja del Pack de Bienvenida tiene que mostrar las probabilidades del
    cofre antes de comprar** (3.1.1);
  - "Parcels" es provisorio hasta que E5 fije el nombre en inglés del Paquete.
- **E7a**:
  - la unión de SKAdNetwork en el `Info.plist`;
  - el código de privacidad de cada adaptador (tabla 3.6);
  - el esquema de `ads.json`;
  - los IDs nuevos en `feature_flags.json` cuando el dueño cree las unidades.
- **Al lanzar**: la política nueva (privacy.md, su copia del bundle y
  `legal.ts`); y en `store-metadata.md`, la descripción sin "Se cayó Mercado
  Pago", las notas de la 2.0 y el "12+", que la escala nueva ya no tiene.
- **Verificar en el panel de Mintegral** la línea exacta de `app-ads.txt`.

## Para el HANDOFF general

### §4 (sesión)

> ### Sesión del 2026-10-06 — E10 en papel: setup de la 2.0, IAP y Términos
>
> Sin código. Salió **`Distribution/setup-v2-asc-admob-mediacion.md`**, el
> entregable del ítem 18: App Store Connect (Novedades, ficha es-ES, capturas
> de iPad, 14 productos con el conteo de sus 42 fichas, checklist del ítem 19,
> edad, App Privacy y notas a App Review), AdMob (11 unidades y 4 grupos de
> mediación por formato) y las 4 redes paso a paso, con la URL oficial de cada
> dato y 🔒 en cada paso del dueño. `iap-appstore-connect.md` quedó con los 14
> productos (packs de ORO 160/550/1.400 y las 3 ofertas), y los Términos (es,
> en y la copia del bundle) ya no dicen que "Sin anuncios" saca los videos con
> premio. El porqué está en `Docs/SESION-2026-10-06-v2-e10-docs.md`.

### §5 (decisiones)

> - **Fichas de IAP**: es-ES lleva el mismo texto que es-MX, con voseo. Las
>   descripciones no llevan montos de ORO (se calibran sin tocar el precio).
>   `oro_medium` se llama **"Saco de ORO"**, porque "cofre" es sólo de pintas.
> - **"Sin anuncios" se describe como "chau a los anuncios que aparecen
>   solos"**: los videos con premio siguen, y la ficha no promete más.
> - **Mac y Apple Vision Pro, apagados** en App Store Connect hasta que
>   alguien los pruebe.
> - **AdMob bloquea "Social Casino Games"** además de "Gambling & Betting".

### §7 (trampas)

> - **Un agente lanzado con la sesión atada a un worktree no puede escribir
>   en otro**, ni con `EnterWorktree(path:)`: Bash, `Edit`, `Write` y git lo
>   rechazan. Lanzar cada agente con el directorio en su propio worktree; si
>   no, deja los archivos en el scratchpad y otro los commitea.
> - **El checkout local de `adergames-site` está atrasado contra lo
>   publicado**: `git pull` antes de tocarlo.
> - **Las 5 descripciones de IAP de más de 45 caracteres están en el
>   `.storekit`**, no en `iap-appstore-connect.md`.
> - **App Store Connect pide como mínimo capturas *medium display*
>   (1206 × 2622)** según la doc vigente, y las de iPad 13" (2064 × 2752) al
>   ser universal.

### §9 (mapa de documentos)

> - **`Distribution/setup-v2-asc-admob-mediacion.md`** — el paso a paso del
>   lanzamiento de la 2.0: App Store Connect, AdMob, las 4 redes de mediación
>   y el sitio, con 🔒 en lo que hace el dueño y la URL de cada dato. Es
>   también el insumo del futuro script de Selenium.
> - **`Distribution/iap-appstore-connect.md`** — los 14 productos con sus
>   fichas (fuente de `IAPCopy`) y lo que entrega cada uno.
> - `Docs/SESION-2026-10-06-v2-e10-docs.md` — el porqué de las fichas, los
>   Términos y las verificaciones (conteos, URLs, SKAdNetwork).
