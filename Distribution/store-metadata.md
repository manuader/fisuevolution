# Store metadata — fuente de verdad (se pega en App Store Connect en F6)

## Nombre — ✅ DECIDIDO (dueño, 2026-09-02)

**Dos marcas, una por mercado:**

| Locale de la ficha | Nombre | Chars |
|---|---|---|
| English (U.S.) | **HoboEvolution** | 13 |
| Spanish (Mexico) | **FisuEvolution** | 13 |

Las tres propuestas viejas ("Fisura: Evolución Idle", "De Fisura a Dios")
quedan descartadas.

### ⚠️ Y por eso el idioma primario se DA VUELTA: primary = English (U.S.)

Esto contradice lo que decía este doc hasta hoy (primary = Spanish (Mexico)), y
el cambio no es una preferencia: **es lo único que cumple el pedido.** En App
Store Connect el nombre se carga por locale, y para cualquier locale que la
ficha NO tenga localizado, la App Store muestra **el idioma primario**. Con
Spanish (Mexico) como primario, un iPhone en francés, alemán o japonés vería
"FisuEvolution" — exactamente el mercado para el que el dueño pidió
"HoboEvolution".

Con **English (U.S.) como primario** y **Spanish (Mexico)** como localización:

- iPhone en español → FisuEvolution ✅
- iPhone en inglés → HoboEvolution ✅
- iPhone en cualquier otro idioma → cae al primario → HoboEvolution ✅

El costo del cambio es cero: las dos localizaciones se cargan igual, sólo
cambia cuál está marcada como primaria. Todo el texto de este doc ya existe en
los dos idiomas.

### El nombre de la HOME SCREEN es otra cosa (y hoy no cierra al 100%)

El nombre bajo el ícono no sale de la ficha: sale de `CFBundleDisplayName`.
Está resuelto para los dos idiomas del juego —base/`es` = "FisuEvolution",
`en` = "HoboEvolution" en `Resources/InfoPlist.xcstrings`, **verificado en el
Info.plist compilado**— pero **el fallback de un tercer idioma es el
castellano**, no el inglés, porque `project.yml` declara
`developmentLanguage: es` (⇒ `CFBundleDevelopmentRegion` = es) y iOS resuelve
por ahí cuando no encuentra el idioma del dispositivo.

Efecto práctico: en un iPhone en alemán la **ficha** diría HoboEvolution y el
**ícono** diría FisuEvolution.

Arreglarlo es cambiar `developmentLanguage` a `en`, y **no se hizo porque no es
gratis**: eso mueve la localización base de todo el proyecto, que hoy es `es`
en `Localizable.xcstrings` (`sourceLanguage: "es"`, 540 claves con el
castellano como fuente). Es una decisión del dueño, no un olvido. Si la
incoherencia importa, el cambio es de una línea más una revisión del catálogo;
si no, queda así documentada.

## Subtítulo (≤30 chars)

es: **De fisura a Dios** · en: **From broke to God**

## Keywords (≤100 chars, sin espacios tras coma)

```
fisura,merge,idle,clicker,tycoon,plata,evolucion,memes,argentina,uba,ceo,millonario,dios
```

## Descripción (es)

> Tapeá, mergeá y evolucioná: de El Fisura del barrio a Dios del universo, con
> escalas en el kiosco, el delivery, la oficina y el título de la UBA (que no
> paga el alquiler, pero emociona).
>
> • 30 niveles de evolución con la carrera que elijas: programador, arquitecto,
>   médico o abogado
> • Ingresos pasivos: tus personajes laburan solos (más que algunos conocidos)
> • Eventos argentinos: Plan Platita, Devaluación, Se cayó Mercado Pago,
>   Corralito y el Aguinaldo
> • Personajes especiales: del Crypto Bro al Demonio de ARCA
> • Reencarná: cada vida arranca más rápida y más absurda
> • Jugá offline: tu imperio sigue girando mientras dormís
>
> Gratis, con humor y sin vergüenza. La inflación no perdona; vos sí podés ganar.

## Descripción (en)

> Tap, merge and evolve: from neighborhood hobo to God of the universe, with
> stops at the corner store, the delivery bike, the office and a university
> diploma (doesn't pay rent, but feels great).
>
> • 30 evolution tiers with your chosen career: coder, architect, doctor or lawyer
> • Passive income: your characters work so you don't have to
> • Absurd economy events inspired by very real chaos
> • Special characters: from the Crypto Bro to the Tax Demon
> • Reincarnate: every life starts faster and weirder
> • Offline progress: your empire keeps spinning while you sleep

## Promotional text (rotable sin re-review)

es: "¡Llegó el Aguinaldo! Entrá a cobrarlo antes de que se lo lleve la inflación."

## Review Notes (en, para el reviewer)

- Satirical idle/merge game with Argentine humor. All brands shown are
  **parodies** (e.g. "McRonald's"); no real trademarks or logos are depicted.
- Alcohol references are limited to cartoon boost icons, infrequent/mild,
  declared in the age rating. The store build serves only review-safe content.
- Characters are cultural archetypes, not real identifiable people.
- No account needed; Game Center is optional. IAPs: remove-ads + cosmetic skins
  via StoreKit 2 with Restore Purchases in the Store screen.
- Quick test: tap the character to earn coins, buy a second one with the green
  button, drag one onto the other to merge.

## Guión de screenshots 6.9" (es; las 3 primeras venden)

1. El Fisura en el board — "Arrancás de fisura"
2. Merge en acción con partículas — "Fusioná y evolucioná"
3. Popup de carrera UBA — "Elegí tu destino (con título)"
4. Rey del Ladrillo + income alto — "Hacete el rey del ladrillo"
5. Reveal de Dios — "Llegá a Dios (literal)"
6. Banner "Se cayó Mercado Pago" — "Sobreviví a la economía"

## URLs — el plan cambió: sitio propio de **Ader Games** (dueño, 2026-09-02)

Ya no es un repo con GitHub Pages: el juego se publica bajo la empresa
**Ader Games**, con sitio propio en **Next.js deployado en Vercel** (identidad
de marca + página del juego + las páginas que Apple exige).

- Privacy: pendiente — `Distribution/site/privacy.md` es el contenido, falta la URL
- Support: pendiente — `Distribution/site/support.md` idem
- Marketing: pendiente — la landing del juego en el sitio de Ader Games

⚠️ **La de privacidad es la única que App Store Connect exige para poder
mandar a review**, y tiene que responder 200 antes del submit. Las otras dos
son opcionales (recomendadas).

⚠️ **Y el texto de privacidad hay que actualizarlo**: `privacy.md` describe los
anuncios en condicional ("si la versión instalada muestra anuncios"). Con la
rama A confirmada (AdMob real, decisión del dueño 2026-09-02) eso pasa a ser
afirmativo, y hay que declarar el tracking de ATT — que también cambia
`PrivacyInfo.xcprivacy` (`NSPrivacyTracking` → true) y las nutrition labels de
la ficha.

## Ads — rama A confirmada (dueño, 2026-09-02)

AdMob real antes del ship, con una capa de ofertas de video durante el juego.
Consecuencias que tocan esta ficha:

- **Nutrition labels**: pasan de "Data Not Collected" a declarar identificadores
  para publicidad de terceros.
- **Rating**: el contenido de los ads se limita a **T** en la consola de AdMob
  para no romper el 12+ de la app.
- **Review Notes**: agregar que los anuncios son recompensados y opcionales, y
  que `remove_ads` los apaga.
