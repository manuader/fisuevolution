# Los 11 productos, para cargar a mano en App Store Connect

Salen de `FisuEvolution/Resources/Config/products.json` (lo que el juego pide)
y de `StoreKitConfig/FisuEvolution.storekit` (los textos y precios locales).
**Los tres archivos tienen que decir lo mismo**: el `productID` de acá es la
clave con la que la app pide cada producto, y StoreKit omite en silencio
—sin error— cualquier id que no exista del otro lado. Un typo no rompe: hace
desaparecer el producto de la tienda.

El jugador lee el nombre, la descripción y el precio **de StoreKit**, no del
juego (`StoreView.swift`: `product.displayName`, `product.description`,
`product.displayPrice`). O sea: lo que cargues acá es lo que se dibuja.

Límites del formulario: nombre ≤ 30 caracteres, descripción ≤ 45. Las
descripciones de esta tabla ya vienen recortadas a esa medida — cinco del
`.storekit` no entraban.

## Datos iguales para los 11

| Campo | Valor |
|---|---|
| Availability | Todos los países y regiones |
| Tax category | La que hereda de la app (no tocar) |
| Idiomas de la ficha | Español (México) + Inglés (EE. UU.) |
| Review screenshot | La misma captura de la tienda para los 11 |

## Consumibles (6)

| Reference Name | Product ID | Precio USD |
|---|---|---|
| Coins S | `com.fisuevolution.iap.coins_small` | 0.99 |
| ORO S | `com.fisuevolution.iap.oro_small` | 1.99 |
| Coins M | `com.fisuevolution.iap.coins_medium` | 4.99 |
| ORO M | `com.fisuevolution.iap.oro_medium` | 4.99 |
| Coins L | `com.fisuevolution.iap.coins_large` | 9.99 |
| ORO L | `com.fisuevolution.iap.oro_large` | 9.99 |

## No consumibles (5)

| Reference Name | Product ID | Precio USD |
|---|---|---|
| Remove Ads | `com.fisuevolution.iap.remove_ads` | 2.99 |
| Skin Mundialista | `com.fisuevolution.iap.skin_mundialista` | 2.99 |
| Skin Parrillero | `com.fisuevolution.iap.skin_parrillero` | 2.99 |
| Starter Pack | `com.fisuevolution.iap.starter_pack` | 4.99 |
| Skins Diamante | `com.fisuevolution.iap.skins_diamante` | 19.99 |

## Fichas, para copiar y pegar

### com.fisuevolution.iap.starter_pack — No consumible — USD 4.99
- ES · Pack de Arranque
- ES · Plata, la skin Mundialista y chau anuncios
- EN · Starter Pack
- EN · Cash, the Mundialista skin and no more ads

### com.fisuevolution.iap.remove_ads — No consumible — USD 2.99
- ES · Sin anuncios
- ES · Sacá los anuncios para siempre
- EN · Remove Ads
- EN · Remove ads forever

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
- ES · Para esa mejora que venís mirando hace rato
- EN · Handful of ORO
- EN · For that upgrade you keep staring at

### com.fisuevolution.iap.oro_medium — Consumible — USD 4.99
- ES · Cofre de ORO
- ES · Alcanza para varias, y todavía te sobra
- EN · Chest of ORO
- EN · Enough for several, with change left over

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

## Qué entrega cada uno (para las notas de revisión)

La plata no es un monto fijo: es un factor sobre el costo del tier más alto
que el jugador desbloqueó, igual que el cofre de carrera. Un monto fijo
envejece mal en un idle exponencial. El ORO sí es fijo, porque sus sinks
(`upgrades.json`) tienen costos fijos.

| Product ID | Entrega |
|---|---|
| `coins_small` | plata ×15 |
| `coins_medium` | plata ×90 |
| `coins_large` | plata ×220 |
| `oro_small` | 250 de ORO |
| `oro_medium` | 750 de ORO |
| `oro_large` | 2000 de ORO |
| `remove_ads` | saca los anuncios, para siempre |
| `skin_mundialista` | la skin `mundialista` |
| `skin_parrillero` | la skin `parrillero` |
| `skins_diamante` | las 43 skins de diamante |
| `starter_pack` | plata ×40 + saca los anuncios + skin `mundialista` |

## Dos cosas que frenan el envío si faltan

1. **Cada producto necesita una captura de revisión.** Sirve la misma para los
   once: una foto de la pantalla Tienda. Mínimo 640×920.
2. **En la primera versión, los IAP se envían JUNTO con la app.** En la página
   de la versión, sección *In-App Purchases and Subscriptions*, hay que
   seleccionar los once. Si no, quedan en "Ready to Submit" y nunca salen.
