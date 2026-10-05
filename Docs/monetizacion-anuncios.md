# Monetización con anuncios — HoboEvolution

Cómo ganar más con los anuncios. Está dividido en dos partes:

1. **Ahora**: lo que se hace en la consola de AdMob, con la versión 1.0.0 (build 4) que ya está en la App Store. No requiere ningún build nuevo.
2. **Próximo build**: lo que hay que programar y volver a pasar por la revisión de Apple.

> Regla de oro: **todo lo que se configura en AdMob funciona ya**. Lo que agrega
> un lugar, un formato o una red de anuncios nueva necesita un build nuevo,
> porque la app sólo conoce los IDs y SDKs que trae adentro.

---

## Estado actual (octubre 2026)

App en AdMob: **HoboEvolution (iOS)**, App ID `ca-app-pub-8575641544774372~3243441080`.
Es el mismo App ID que el build trae en `Info.plist` (`GADApplicationIdentifier`).
Ya está vinculada a la App Store (ID `6814521946`), y `app-ads.txt` está publicado en
`https://adergames-site.vercel.app/app-ads.txt`.

### Unidades de anuncios

| Unidad en AdMob | ID | Formato | Dónde aparece en el juego | ¿La usa el build 4? |
|---|---|---|---|---|
| anuncio normal | `…/5270838626` | Intersticial | Entre momentos de juego | ✅ |
| boosts | `…/4913896772` | Bonificado | Activar un boost sin esperar | ✅ |
| cofre extra | `…/3981807683` | Bonificado | Abrir otro cofre | ✅ |
| offline x2 | `…/6825744243` | Bonificado | Duplicar lo ganado offline | ✅ |
| x2 de income | `…/8304196070` | Bonificado | **Toda** la lista de Regalos (5 premios) | ✅ |
| unidad | `…/1615619906` | Intersticial bonificado | Ninguno todavía | ❌ (próximo build) |

- "x2 de income" cubre los cinco regalos, no sólo el x2. Conviene renombrarla
  a **regalos**; el nombre no afecta nada.
- No borres ninguna: si borrás una que el build usa, ese lugar se queda sin
  anuncios hasta el próximo build.

### Cuántos anuncios muestra hoy el juego

Viene de `FisuEvolution/Resources/Config/rewarded_ads.json`:

- **Bonificados**: siempre los pide el jugador. Cada premio de Regalos tiene un
  cooldown de 4 horas.
- **Intersticial**: como máximo uno cada **7 minutos** (`minSecondsBetween: 420`).
  Nunca en los primeros **3 minutos** de la sesión, ni en los **90 segundos**
  después de un bonificado.

---

## Parte 1 — Ahora, sin build nuevo

En orden. Todo se hace en [admob.google.com](https://admob.google.com).

### 1. Esperar la revisión de AdMob (2–3 días)

Después de vincular la tienda, AdMob revisa la app. Mientras tanto la
publicación está **limitada**: pocos anuncios y poco revenue, y es normal.
Cuando termina, llega un mail. No hay nada que hacer, salvo los pasos 2 y 3,
que se pueden dejar listos ya.

### 2. Mensaje de consentimiento para Europa — el que más pesa

La app ya trae el SDK de consentimiento de Google (UMP, en `AdsConsent.swift`) y
lo llama antes de pedir anuncios, pero **sólo muestra lo que esté configurado
en AdMob**. Sin un mensaje creado, en la UE, el Reino Unido y Suiza no se le pide
consentimiento a nadie, y los anuncios salen sin personalizar: pagan mucho menos.

1. **Privacidad y mensajería ▸ Reglamentos europeos ▸ Crear mensaje.**
2. App: **HoboEvolution (iOS)**.
3. Idiomas: **español** e **inglés**.
4. Diseño: el que viene por defecto.
5. **Publicar.**

### 3. Mensaje de explicación de IDFA (recomendado)

Es una pantalla previa al aviso de Apple de "¿Permitir que te rastree?" que
explica por qué se pide. Sube el porcentaje de gente que acepta, y con rastreo
permitido los anuncios pagan más.

1. **Privacidad y mensajería ▸ Mensaje de explicación de IDFA ▸ Crear mensaje.**
2. App **HoboEvolution (iOS)**, español e inglés, **Publicar**.

### 4. Pisos de eCPM (cuando termine la revisión)

El piso es el precio mínimo al que se vende un anuncio. En cada una de las 5
unidades que usa el juego:

1. Abrir la unidad ▸ **Configuración avanzada**.
2. **Piso de eCPM ▸ Optimizado por Google**, en nivel *Alto* si aparece la opción.
3. Guardar.

### 5. Tipos de anuncio del intersticial

En **anuncio normal**, dejar habilitados **imagen y video**. Cuantos más tipos
acepta, más anunciantes compiten. Los anuncios jugables entran por acá
cuando los hay.

### 6. Qué NO hacer

- **No crear unidades nuevas** para esta versión: la app no las va a usar.
- **No borrar** las 5 que usa.
- **No poner límites de frecuencia** en AdMob: la cadencia ya la controla el
  juego, y un límite extra sólo resta impresiones.
- **No hacer clic en los propios anuncios** desde un iPhone de producción: es
  tráfico inválido y Google puede suspender la cuenta. Para probar, usar un
  dispositivo de prueba (ver más abajo).

### 7. Qué mirar en los primeros días

En **Informes**, filtrando por unidad de anuncios:

| Métrica | Qué dice | Para qué sirve |
|---|---|---|
| **Impresiones por unidad** | Dónde mira anuncios la gente | Decidir qué lugar potenciar |
| **eCPM** | Cuánto pagan 1000 anuncios | Comparar bonificado contra intersticial |
| **Tasa de coincidencia** (*match rate*) | % de pedidos que consiguieron anuncio | Si es baja, falta demanda: la mediación la sube |
| **Ingresos por país** | De dónde viene la plata | Priorizar idioma y precios |

Juntar **al menos una o dos semanas** de datos antes de decidir el próximo build.

### Probar anuncios sin riesgo

**AdMob ▸ Configuración ▸ Dispositivos de prueba ▸ Agregar dispositivo de
prueba**, con el IDFA del iPhone propio. Ese dispositivo ve anuncios marcados
como prueba y no genera tráfico inválido.

---

## Parte 2 — Próximo build

Ordenado por impacto en el revenue. Antes de arrancar, mirar los datos de la
Parte 1: si un lugar casi no se usa, no vale la pena optimizarlo.

### 1. Mediación — lo que más sube el revenue

Hoy cada anuncio lo vende sólo Google. Con mediación, varias redes compiten por
cada lugar (*bidding*), y gana la que más paga. Las más útiles para un juego
casual, y las que más anuncios jugables traen:

- **AppLovin**
- **Unity Ads**
- **Mintegral**
- **Meta Audience Network**

**En cada red:**

1. Crear la cuenta de publisher y registrar la app.
2. Copiar sus IDs (app key, placement IDs) en AdMob.

**En AdMob:**

1. **Mediación ▸ Crear grupo de mediación**: uno para *Bonificado* y otro
   para *Intersticial*, plataforma iOS.
2. Agregar las 5 unidades del juego al grupo que corresponde.
3. Sumar cada red como fuente de **bidding**.

**En el código:**

1. Agregar el **adaptador** de cada red como paquete en `project.yml`, al lado
   de `GoogleMobileAds`. Google publica los adaptadores de mediación para iOS.
   El SDK de AdMob los descubre solo: **no cambia** `AdMobAdsProvider.swift`.
2. Agregar los **SKAdNetworkIdentifier** de cada red al `Info.plist`. Hoy
   tiene 50, los de Google. Sin los de cada red, esas redes no pueden atribuir
   instalaciones y pagan menos.
3. Agregar las líneas de cada red a **`app-ads.txt`**, en el repo
   `adergames-site`, archivo `public/app-ads.txt`. Cada red las da en su
   panel. Sin eso, sus anunciantes no compran el inventario.
4. Actualizar el **manifiesto de privacidad** si algún SDK nuevo lo exige,
   y la sección **App Privacy** de App Store Connect, si declaran datos
   distintos a los de AdMob.
5. Actualizar la **política de privacidad** del sitio, en el repo
   `adergames-site`, archivo `content/legal.ts`, nombrando las redes nuevas.

### 2. Intersticial bonificado (*rewarded interstitial*)

Ya existe la unidad **"unidad"** (`…/1615619906`). Es un anuncio que aparece
solo en una pausa natural, con aviso previo y opción de saltearlo, y da un
premio. Paga parecido a un bonificado, sin que el jugador tenga que buscarlo.

Dónde ponerlo: **al reencarnar**, que es la pausa más natural del juego, y
eventualmente al cerrar un cofre.

En el código:

1. Agregar `rewardedInterstitial` a `adUnitIDs` en `feature_flags.json`, con
   el ID de "unidad", y a `FeatureFlags.swift`, junto con su ID de prueba de
   Google.
2. Agregar el método de carga y presentación en `AdsProvider.swift` y
   `AdMobAdsProvider.swift`, siguiendo el patrón del bonificado.
3. Llamarlo desde el flujo de reencarnación, respetando el mismo margen que el
   intersticial para no encimar anuncios.

### 3. App open

Un anuncio al volver a la app desde el segundo plano. Pagan bien, pero molestan
si se abusa:

- Crear la unidad en AdMob (formato *Inicio de aplicación*).
- Mostrarlo sólo al **volver**, nunca en el primer arranque, y como máximo una
  vez cada varias horas.

### 4. IDs de anuncios remotos (para no depender de Apple)

Hoy los IDs viven dentro de la app (`feature_flags.json`), así que cambiarlos
requiere un build y otra revisión. Se puede hacer que la app los lea al
arrancar desde un JSON publicado en `adergames-site`, por ejemplo
`/config/ads.json`, usando los del bundle como respaldo si no hay red.
Después de eso, crear o cambiar unidades **no requiere** pasar por Apple. Vale
la pena hacerlo en el mismo build que la mediación.

### Checklist del próximo build

- [ ] Datos de 1–2 semanas revisados (Parte 1, paso 7)
- [ ] Cuentas creadas en AppLovin, Unity, Mintegral y Meta
- [ ] Grupos de mediación creados en AdMob (bonificado + intersticial)
- [ ] Adaptadores agregados en `project.yml`
- [ ] SKAdNetwork IDs de cada red en `Info.plist`
- [ ] `app-ads.txt` actualizado con las líneas de cada red
- [ ] Manifiesto de privacidad, App Privacy y política del sitio actualizados
- [ ] Intersticial bonificado al reencarnar
- [ ] (Opcional) App open al volver a la app
- [ ] (Opcional) IDs de anuncios remotos
- [ ] Subir `CURRENT_PROJECT_VERSION` en `project.yml`: Apple no acepta un
      número de build repetido
- [ ] Archive limpio (borrar DerivedData), probar en un dispositivo de prueba
      y subir

---

## Lo que no se puede hacer

- **Elegir la duración** de los anuncios (por ejemplo, 45 segundos): la
  decide cada anunciante.
- **Sacar el botón de saltear** en los intersticiales: lo controla Google. Los
  bonificados ya son "no salteables" en la práctica, porque sin verlos
  completos no hay premio.
- **Pedir sólo anuncios jugables**: entran solos cuando un anunciante los ofrece.
  La mediación con Unity y Mintegral aumenta la cantidad.

Más anuncios forzados suben el revenue por sesión, pero hacen que la gente
abandone el juego, y al final se gana menos. El modelo del juego —sobre todo
bonificados opcionales y un intersticial espaciado— es el que mejor rinde a
largo plazo en un idle.
