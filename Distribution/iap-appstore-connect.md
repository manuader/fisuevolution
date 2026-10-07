# Los 14 productos, para cargar a mano en App Store Connect

_Al día con la 2.0 (2026-10-06): los 11 de la v1 revisados, los packs de ORO
reescalados y las tres ofertas nuevas. El paso a paso completo del lanzamiento
(ficha, notas a App Review, AdMob y mediación) está en
`Distribution/setup-v2-asc-admob-mediacion.md`._

Salen de `FisuEvolution/Resources/Config/products.json` (lo que el juego pide)
y de `StoreKitConfig/FisuEvolution.storekit` (los textos y precios locales).
**Los tres archivos tienen que decir lo mismo**: el `productID` de acá es la
clave con la que la app pide cada producto, y StoreKit omite en silencio
—sin error— cualquier id que no exista del otro lado. Un typo no rompe: hace
desaparecer el producto de la tienda.

Hasta la v1, el jugador leía el nombre y la descripción **de StoreKit**
(`StoreView.swift`: `product.displayName`, `product.description`). Desde la
2.0 los lee del catálogo de la app (`IAPCopy`, claves
`iap.<productID>.name` y `.desc` en `Localizable.xcstrings`), con StoreKit de
respaldo. **Las fichas de abajo son la fuente de esas claves**, así que lo que
se cargue en App Store Connect y lo que dice el juego es lo mismo. El precio
sigue saliendo de StoreKit (`product.displayPrice`), y la hoja de pago de
Apple muestra el nombre de App Store Connect.

Límites del formulario: nombre ≤ 30 caracteres, descripción ≤ 45. Todas las
fichas de esta tabla entran, contadas una por una (el conteo está en el doc de
setup). ⚠️ El `.storekit` todavía trae cinco descripciones viejas que no
entran (starter en es/en, Mundialista en es/en y Diamante en es): se
sincronizan con estas fichas cuando E6 sume las ofertas al `.storekit`.

## Datos iguales para los 14

| Campo | Valor |
|---|---|
| Availability | Todos los países y regiones |
| Tax category | La que hereda de la app (no tocar) |
| Idiomas de la ficha | Español (México) + Español (España) + Inglés (EE. UU.) |
| Review screenshot | La misma captura de la tienda para los 11; cada oferta, una de su hoja |

**ES vale para los dos españoles**: el texto de es-MX y el de es-ES es el
mismo, con el voseo del juego. Si falta es-ES, un iPhone en España cae al
inglés aunque es-MX esté cargado: es la mitad del ítem 19.

## Consumibles (9)

| Reference Name | Product ID | Precio USD |
|---|---|---|
| Coins S | `com.fisuevolution.iap.coins_small` | 0.99 |
| ORO S | `com.fisuevolution.iap.oro_small` | 1.99 |
| Coins M | `com.fisuevolution.iap.coins_medium` | 4.99 |
| ORO M | `com.fisuevolution.iap.oro_medium` | 4.99 |
| Coins L | `com.fisuevolution.iap.coins_large` | 9.99 |
| ORO L | `com.fisuevolution.iap.oro_large` | 9.99 |
| Offer Bienvenida | `com.fisuevolution.iap.offer_bienvenida` | 0.99 |
| Offer Renacer | `com.fisuevolution.iap.offer_renacer` | 2.99 |
| Offer Mudanza | `com.fisuevolution.iap.offer_mudanza` | 4.99 |

## No consumibles (5)

| Reference Name | Product ID | Precio USD |
|---|---|---|
| Remove Ads | `com.fisuevolution.iap.remove_ads` | 2.99 |
| Skin Mundialista | `com.fisuevolution.iap.skin_mundialista` | 2.99 |
| Skin Parrillero | `com.fisuevolution.iap.skin_parrillero` | 2.99 |
| Starter Pack | `com.fisuevolution.iap.starter_pack` | 4.99 |
| Skins Diamante | `com.fisuevolution.iap.skins_diamante` | 19.99 |

⚠️ **Las ofertas son consumibles**, no no-consumibles: la de Renacer y la de
Mudanza vuelven a aparecer (cooldown de 3 días), y un no consumible se compra
una sola vez en la vida. Las tres son productos comunes de App Store Connect;
lo de "24 horas" lo maneja el juego (`offers.json`), no Apple.

## Fichas, para copiar y pegar

### com.fisuevolution.iap.starter_pack — No consumible — USD 4.99
- ES · Pack de Arranque
- ES · Plata, la Mundialista y sin anuncios forzados
- EN · Starter Pack
- EN · Cash, the Mundialista skin and no forced ads

### com.fisuevolution.iap.remove_ads — No consumible — USD 2.99
- ES · Sin anuncios
- ES · Chau a los anuncios que aparecen solos
- EN · Remove Ads
- EN · No more ads that pop up on their own

### com.fisuevolution.iap.coins_small — Consumible — USD 0.99
- ES · Puñado de Plata
- ES · Un vuelto para arrancar el día
- EN · Handful of Cash
- EN · Pocket change to get the day going

### com.fisuevolution.iap.coins_medium — Consumible — USD 4.99
- ES · Fajo de Plata
- ES · Un fajo que se nota en el bolsillo
- EN · Wad of Cash
- EN · A wad you can feel in your pocket

### com.fisuevolution.iap.coins_large — Consumible — USD 9.99
- ES · Bolso de Plata
- ES · El bolso entero, sin preguntar de dónde salió
- EN · Bag of Cash
- EN · The whole duffel bag, no questions asked

### com.fisuevolution.iap.oro_small — Consumible — USD 1.99
- ES · Puñado de ORO
- ES · Para un boost o esa mejora que venís mirando
- EN · Handful of ORO
- EN · For a boost or that upgrade you keep eyeing

### com.fisuevolution.iap.oro_medium — Consumible — USD 4.99
- ES · Saco de ORO
- ES · Boosts, mejoras y skins, y todavía te sobra
- EN · Sack of ORO
- EN · Boosts, upgrades and skins, with change left

### com.fisuevolution.iap.oro_large — Consumible — USD 9.99
- ES · Bóveda de ORO
- ES · Para el que quiere todo, y lo quiere ahora
- EN · Vault of ORO
- EN · For those who want it all, and want it now

### com.fisuevolution.iap.skin_mundialista — No consumible — USD 2.99
- ES · Skin Mundialista
- ES · La camiseta y una copa que no ganó él
- EN · Mundialista Skin
- EN · The jersey, and a cup he didn't win

### com.fisuevolution.iap.skin_parrillero — No consumible — USD 2.99
- ES · Skin Parrillero
- ES · Dios con delantal chamuscado y pinza de asado
- EN · Parrillero Skin
- EN · God in a scorched apron, tongs in hand

### com.fisuevolution.iap.skins_diamante — No consumible — USD 19.99
- ES · Todas las skins de Diamante
- ES · Los 43 personajes tallados en diamante
- EN · All Diamond Skins
- EN · All 43 characters carved in diamond, at once

### com.fisuevolution.iap.offer_bienvenida — Consumible — USD 0.99
- ES · Pack de Bienvenida
- ES · ORO, 2 h de ingresos y un cofre de pintas
- EN · Welcome Pack
- EN · ORO, 2 h of income and a skin chest

### com.fisuevolution.iap.offer_renacer — Consumible — USD 2.99
- ES · Pack Renacer
- ES · ORO, 4 h de ingresos y ×3 por 30 minutos
- EN · Rebirth Pack
- EN · ORO, 4 h of income and ×3 for 30 minutes

### com.fisuevolution.iap.offer_mudanza — Consumible — USD 4.99
- ES · Pack Mudanza
- ES · ORO, 8 h de ingresos y 3 Paquetes
- EN · Moving Day Pack
- EN · ORO, 8 h of income and 3 Parcels

### Lo que cambió contra la v1, y por qué

- **`oro_medium` deja de llamarse "Cofre de ORO"** (ahora "Saco de ORO" /
  "Sack of ORO"). En la 2.0, "cofre" es sólo el de pintas (HANDOFF §5), y la
  tienda de ORO vende un cofre de pintas con premio al azar. Un producto de
  plata real llamado "Cofre" se lee como una caja sorpresa paga, que Apple
  trata distinto (guía 3.1.1).
- **`remove_ads` y `starter_pack` ya no prometen "chau anuncios"**: sacan los
  tres formatos que aparecen solos (intersticial, pausa publicitaria y app
  open), y los videos con premio siguen. Una descripción que promete más de lo
  que entrega es motivo de rechazo y de reclamo.
- **Las descripciones de ORO hablan de la tienda**: en la 2.0 el ORO compra
  boosts, atajos y skins, no sólo mejoras.
- **Las descripciones no llevan montos de ORO**: los montos se calibran con el
  simulador sin tocar el precio (PLAN-v2 §2), y un número en la descripción
  obligaría a re-enviar a revisión cada vez. Los montos viven en la tabla de
  abajo y en las notas a App Review.
- ⚠️ "Parcels" es provisorio: es el nombre en inglés del Paquete de la Aduana
  hasta que E5 fije el suyo en el catálogo. Si cambia, cambia acá también.

## Qué entrega cada uno (para las notas de revisión)

La plata ya no es un factor sobre el costo del tier más alto: en la 2.0 se
paga en **minutos de producción real** (E2a, `RewardScale`), como todos los
premios del juego. Un monto fijo envejece mal en un idle exponencial; una
cantidad de tiempo de producción no. El ORO sí es fijo, porque sus sinks
(`upgrades.json`, `oro_shop.json`) tienen costos fijos.

| Product ID | Entrega en la 2.0 | En la v1 |
|---|---|---|
| `coins_small` | 1 h de producción | plata ×15 |
| `coins_medium` | 6 h de producción | plata ×90 |
| `coins_large` | 24 h de producción | plata ×220 |
| `oro_small` | 160 de ORO | 250 |
| `oro_medium` | 550 de ORO | 750 |
| `oro_large` | 1.400 de ORO | 2000 |
| `remove_ads` | saca los tres formatos forzados (intersticial, pausa publicitaria y app open), para siempre; los videos con premio siguen | saca el intersticial |
| `skin_mundialista` | la skin `mundialista` | igual |
| `skin_parrillero` | la skin `parrillero` | igual |
| `skins_diamante` | las 43 skins de diamante | igual |
| `starter_pack` | 4 h de producción + skin `mundialista` + lo mismo que `remove_ads` | plata ×40 + sin intersticial + skin |
| `offer_bienvenida` | 120 de ORO + 2 h de producción + 1 cofre de pintas | — (nueva) |
| `offer_renacer` | 300 de ORO + 4 h de producción + ingresos ×3 por 30 min | — (nueva) |
| `offer_mudanza` | 500 de ORO + 8 h de producción + 3 Paquetes de la Aduana | — (nueva) |

Los montos de ORO y las horas son los aprobados en PLAN-v2 §2; los montos de
ORO se pueden mover con el simulador (E2b) sin tocar el precio. Si se mueven,
se corrige esta tabla, no las fichas.

⚠️ **La oferta de Bienvenida trae un cofre de pintas, que es un premio al
azar pagado con plata real.** La hoja de la oferta tiene que mostrar las
probabilidades del cofre **antes** de comprar (guía 3.1.1), con la misma
`OddsDisclosureView` de la tienda de ORO.

## Dos cosas que frenan el envío si faltan

1. **Cada producto necesita una captura de revisión.** Sirve la misma para los
   once de siempre: una foto de la pantalla Tienda. Cada oferta, una de su
   hoja. Sirve cualquier tamaño de captura que la app soporte.
2. **Los productos nuevos o editados se envían JUNTO con la versión.** En la
   página de la versión 2.0.0, sección *In-App Purchases and Subscriptions*,
   hay que seleccionar las tres ofertas y los once con fichas editadas. Si no,
   quedan en "Ready to Submit" y nunca salen.
