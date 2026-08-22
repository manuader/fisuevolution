# Sesión 2026-08-21 — Los personajes ya no se llaman en castellano cuando el juego está en inglés

## Qué se pidió

El dueño, textual: *"por alguna razón, cuando el idioma del juego esta en ingles,
los personajes siguen con el nombre en español. corregi esto. investiga cual
seria la traduccion literal culturalmente para estados unidos"*.

O sea dos cosas: el mecanismo (que el nombre se traduzca) y el contenido (que la
traducción sea la que un jugador de Estados Unidos entiende, no la literal).

## La causa

El nombre del personaje sale de `tiers.json`, que es **dato**, y `tiers.json`
está escrito en castellano. Todas las vistas lo dibujaban `verbatim`. No había
nada roto en la localización: la clave del nombre no existía.

Lo dice el propio código que estaba ahí, en `CustomizationView`:

> El nombre sale de `tiers.json` (es dato, no catálogo de strings), así que va
> verbatim.

Era cierto y era el bug. El resto del juego está traducido entero — **475 claves,
las 475 con `en`** —, así que el catálogo no era sospechoso; el nombre nunca
pasaba por él.

**El diagnóstico que NO hubo que hacer** vale anotarlo igual: no es que el
catálogo tuviera huecos, ni que `AppleLanguages` no se aplicara (se aplica: lo
escribe `SettingsView` y lo prueba `SettingsPersistenceTests`). Con mirar de
dónde sale `displayName` alcanzó.

## Cómo estaba repartido

| | valor |
|---|---:|
| tipos en `tiers.json` | 44 (43 concretos + el nodo `junior`) |
| claves del catálogo antes | 475, todas con `es` y `en` |
| lugares que leían `CharacterType.displayName` | 15 |
| claves nuevas | 44 |
| textos en inglés que nombraban al personaje en castellano | 3 |

Los 15 lugares son 5 constructores de filas (`JobRow`, `BestHire`,
`OrgChartRow`, `CharacterUpgradeRow`, y el nombre del ascenso) y 10 vistas
—incluidas las dos de SpriteKit, que son las que más se ven: el cartelito bajo
cada personaje del tablero y el banner del reveal.

## Qué se construyó

**Una propiedad, no un campo nuevo en el dato.** `CharacterType.localizedName`
(`FisuEvolution/Utilities/CharacterTypeName.swift`) busca `tier.name.<id>` en el
bundle y cae al `displayName` del dato si la clave no está. Es la misma forma que
ya usaban las skins (`skin.name.<id>` + `skinDisplayName(for:)`), y por eso se
eligió: el repo ya tenía resuelto "el nombre visible de una cosa que viene del
JSON".

Lo que se descartó, con su razón:

- **Un campo `displayNameEN` en `tiers.json`.** Mete idiomas adentro del dato y
  deja el catálogo —que es donde iOS espera encontrarlos— fuera del asunto. Y
  `tiers.json` lo genera `Tools/generate-tiers`: cada idioma nuevo sería una
  columna más en la tabla cultural del generador.
- **Un `displayNameKey` en `CharacterType`, como en las skins.** Habría que tocar
  EconomyKit (que es puro y no sabe de localización), regenerar `tiers.json` y
  mover el test anti-drift. La clave se deduce del `id`; guardarla además es un
  dato que se puede desincronizar.
- **`Text(LocalizedStringKey("tier.name.\(id)"))`.** No funciona, y es la trampa
  5 del HANDOFF: `LocalizedStringKey` interpola, así que eso construye la clave
  `tier.name.%@` y deja la clave cruda en pantalla. Por eso el lookup va por
  `Bundle.main.localizedString(forKey:value:table:)`, igual que
  `GameState.localized(_:)`.

El `value:` del lookup es el castellano del dato: un tier que entre a
`tiers.json` antes que su string se ve en castellano, no como `tier.name.foo`.

## La traducción cultural

El criterio no fue traducir la palabra sino **el chiste**, y con una restricción
dura: el arte ya está dibujado y no se toca. El nombre tiene que describir lo que
se ve. Los prompts de `Tools/asset-pipeline/prompts/prompts.json` fueron la
fuente: cada personaje declara ahí sus props y su chiste.

Los que dejaron de ser literales, y por qué:

| id | es | en | por qué |
|---|---|---|---|
| `homeless` | El Fisura | **The Hobo** | ya era el canon del repo: `gc.ach.tier30_god.title` dice "From Hobo to God", y el nombre en inglés del juego es "Hobo Evolution" |
| `trapito` | El Trapito | **The Fake Valet** | el trapito no existe en EE.UU.; lo que sí se entiende es el que te hace señas para estacionar y te cobra. El arte tiene chaleco fluo, silbato y monedas: es un valet trucho |
| `limpiavidrios` | Limpiavidrios | **Squeegee Guy** | equivalencia 1:1 real — el *squeegee man* del semáforo es una figura reconocida en EE.UU. |
| `mantero` | El Mantero | **The Bootleg Vendor** | la manta con anteojos, fundas y juguetes a cuerda es el puesto trucho de vereda |
| `fast_food` | Empleado de Fast Food | **Burger Flipper** | "burger flipper" es el modismo yanqui para el laburo sin salida, y el arte trae la espátula |
| `oficinista` | Oficinista | **Office Drone** | "Oficinista" es neutro, pero el dibujo está muerto de cansancio |
| `administrativo` | Administrativo | **Paper Pusher** | el sello de goma y la torre de carpetas: es el burócrata |
| `junior_doctor` | Médico Jr. | **Medical Resident** | en EE.UU. el recién recibido de medicina **es** un *resident*, y el arte es literalmente la guardia de 24 h. "Junior Doctor" es británico |
| `senior_doctor` | Médico Sr. | **Attending Physician** | el escalón siguiente de verdad de esa carrera |
| `junior_lawyer` | Abogado Jr. | **Junior Associate** | en un estudio yanqui se entra de *associate*… |
| `senior_lawyer` | Abogado Sr. | **Senior Partner** | …y se llega a *partner* |
| `dueno_pyme` | Dueño de PYME | **Small Business Owner** | "PYME" no significa nada en EE.UU.; *small business owner* es la misma figura y hasta con la misma carga política |
| `emprendedor` | Emprendedor | **Hustle Guru** | el arte es megáfono, libro de mindset y cursos online: eso es *hustle culture*, no "entrepreneur" |
| `rey_ladrillo` | Rey del Ladrillo | **Real Estate King** | el ladrillo como reserva de valor es argentino; lo que queda del chiste es el rey del ladrillo, que allá es el rey del real estate |
| `magnate_petrolero` | Magnate Petrolero | **Oil Baron** | galera y bastón: es el *robber baron*, no un "tycoon" moderno |
| `estanciero_estelar` | Estanciero Estelar | **Star Rancher** | el estanciero de la pampa es el *rancher* de Texas, y el arte tiene lazo y vacas |
| `fondo_buitre` | Fondo Buitre Estelar | **Stellar Vulture Fund** | *vulture fund* existe en inglés financiero y el arte tiene el prendedor con cabeza de buitre: se conserva |

Los demás son literales porque el chiste sobrevive literal (`Trillionaire`,
`Owner of the Moon`, `Cosmic Emperor`, `Demigod`, …), y tres son la misma palabra
en los dos idiomas: `CEO`, `Director` y `Space Billionaire`.

**Tres textos ya traducidos nombraban al personaje en castellano** y se
corrigieron para que no queden contra el nombre nuevo:

| clave | antes (en) | ahora (en) |
|---|---|---|
| `tutorial.step.tap` | "Hi! I am El Fisura." | "Hi! I'm the Hobo." |
| `ach.floor_moon.title` | "One Small Step for Fisura" | "One Small Step for the Hobo" |
| `special.influencer.flavor` | "use code FISURA" | "use code HOBO" |

El tercero es un código de descuento de mentira, o sea un chiste, no un nombre:
se cambió igual porque en inglés "FISURA" no quiere decir nada.

## Qué quedó afuera, a propósito

- **La tabla de nombres NO se agregó a `Docs/content-strings.md`.** Ese doc es la
  fuente de los textos de los JSON de `Config/`; los nombres de tier viven en el
  catálogo y ya tienen un test que los ata a `tiers.json`. Copiarlos a un tercer
  lugar es garantía de que un día los tres digan cosas distintas.
- **`EconomyKit` no se tocó.** El paquete es puro y no sabe de bundles; la
  traducción es presentación y se quedó del lado de la app.
- **El castellano no se movió una coma.** Las 44 entradas `es` del catálogo se
  generaron **desde `tiers.json`**, no a mano, y el test lo pinea.

## Cómo tocar esto

Un tier nuevo necesita **dos** cosas: su fila en la tabla cultural de
`Tools/generate-tiers` y su clave `tier.name.<id>` en el catálogo. Si falta la
segunda, el juego en inglés lo muestra en castellano sin avisar — el fallback
tapa el agujero en pantalla. Lo que avisa es
`GameContentValidationTests.everyTierHasItsNameInBothLanguages`.

## Cómo terminó

Receta completa del §6 del HANDOFF, simulador propio por UDID,
`-parallel-testing-enabled NO`, unit antes que UI.

| suite | antes | ahora |
|---|---:|---:|
| app (`FisuEvolutionTests`) | 411 | **413, cero rojos** |
| UI (`FisuEvolutionUITests`) | 48 | **48, cero rojos, sin skips** |
| EconomyKit | 234 | **234** (no se tocó el paquete) |

Cero warnings de compilador. Los tres `warning:` del log son del
`appintentsmetadataprocessor` y son los de siempre.

Y se miró en pantalla, que es donde estaba el bug: partida fresca lanzada con
`xcrun simctl launch <UDID> com.manuader.fisuevolution -AppleLanguages "(en)"`.
El tutorial abre con **"Hi! I'm the Hobo."** y el botón de contratación rápida
dice **"The Hobo · 25"**.

Los dos tests que cambiaron de forma, y por qué:

- Cuatro asserts pineaban el nombre en castellano (`== "El Fisura"`,
  `== "El Mantero"`). **El runner corre la app en inglés** (trampa 6), así que
  ahora esos asserts serían falsos por la razón correcta y antes pasaban por
  casualidad: el nombre no pasaba por el catálogo. Pasaron a pinear el contraste
  que el test quería probar (`!= "???"`), y la existencia de la traducción se
  chequea una sola vez y de verdad en el test nuevo.
- `RevealBannerFitTests` medía sólo el castellano. Ahora mide **los dos
  nombres**: el banner dibuja `localizedName`, y sin eso los nombres en inglés no
  tenían quién les controlara el ancho. Todos entran — el más largo en inglés es
  "King of the Asteroids" (21), contra los 25 de "Magnate del Sistema Solar" que
  ya pasaban.
