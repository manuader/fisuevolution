# Checklist de submission — v1.0.0

_Escrito el 2026-09-21. App record: **6814521946** (ya creado)._
_Los textos salen de `store-metadata.md`; la lista de IAP, de `StoreKitConfig/FisuEvolution.storekit`._

Todo lo de acá está medido contra el límite de caracteres de Apple y entra.

---

## A · La página de la versión — lo que se pega ya

### Promotional Text (≤170) — 76 chars

```
¡Llegó el Aguinaldo! Entrá a cobrarlo antes de que se lo lleve la inflación.
```

### Description — es (≤4000) — 712 chars

```
Tapeá, mergeá y evolucioná: de El Fisura del barrio a Dios del universo, con escalas en el kiosco, el delivery, la oficina y el título de la UBA (que no paga el alquiler, pero emociona).

• 30 niveles de evolución con la carrera que elijas: programador, arquitecto, médico o abogado
• Ingresos pasivos: tus personajes laburan solos (más que algunos conocidos)
• Eventos argentinos: Plan Platita, Devaluación, Se cayó Mercado Pago, Corralito y el Aguinaldo
• Personajes especiales: del Crypto Bro al Demonio de ARCA
• Reencarná: cada vida arranca más rápida y más absurda
• Jugá offline: tu imperio sigue girando mientras dormís

Gratis, con humor y sin vergüenza. La inflación no perdona; vos sí podés ganar.
```

### Description — en (≤4000) — 561 chars

```
Tap, merge and evolve: from neighborhood hobo to God of the universe, with stops at the corner store, the delivery bike, the office and a university diploma (doesn't pay rent, but feels great).

• 30 evolution tiers with your chosen career: coder, architect, doctor or lawyer
• Passive income: your characters work so you don't have to
• Absurd economy events inspired by very real chaos
• Special characters: from the Crypto Bro to the Tax Demon
• Reincarnate: every life starts faster and weirder
• Offline progress: your empire keeps spinning while you sleep
```

### Keywords (≤100, sin espacio después de la coma)

- **es** — 88 chars
  ```
  fisura,merge,idle,clicker,tycoon,plata,evolucion,memes,argentina,uba,ceo,millonario,dios
  ```
- **en** — 87 chars
  ```
  hobo,merge,idle,clicker,tycoon,evolution,tap,money,rich,god,upgrade,prestige,meme,funny
  ```

### Version

```
1.0.0
```

### Copyright (≤200)

```
2026 Manuel Ader
```

### Routing App Coverage File · App Clip · iMessage App

Vacío los tres. No aplican.

### App Store Version Release

**Manually release this version.** Que quede aprobada y salir cuando vos quieras,
no cuando Apple termine de revisar a las 4 de la mañana.

---

## B · App Review Information

| Campo | Qué va |
|---|---|
| **Sign-in required** | **NO** — destildado. El juego no tiene cuentas ni registro; Game Center es opcional. |
| **Contact Information** | Nombre y apellido reales + `adermanu@gmail.com` + teléfono con código de país. |
| **Attachment** | Vacío. |

### Notes (≤4000) — pegar tal cual

```
Satirical idle/merge game with Argentine humor.

- All brands shown are parodies (e.g. "McRonald's"); no real trademarks or logos are depicted.
- Alcohol references are limited to cartoon boost icons, infrequent/mild, and declared in the age rating. The store build serves only review-safe content.
- Characters are cultural archetypes, not real identifiable people.
- No account is needed and no sign-in is possible. Game Center is optional.
- In-app purchases use StoreKit 2. "Restore Purchases" is in the Store screen.

Quick test: tap the character to earn coins, buy a second one with the green button, then drag one onto the other to merge.
```

---

## C · Lo que todavía bloquea el Submit

Estos tres no se resuelven tipeando. Van en orden de cuánto tardan.

### C1 · Support URL — ✅ RESUELTO (2026-09-21)

Las cuatro URLs devuelven 200 y están verificadas en vivo:

| Ficha | Support URL | Privacy URL |
|---|---|---|
| Español (es-MX) | `https://adergames-site.vercel.app/es/support` | `https://adergames-site.vercel.app/es/privacy` |
| Inglés | `https://adergames-site.vercel.app/support` | `https://adergames-site.vercel.app/privacy` |

**Marketing URL**: opcional, dejalo vacío.
La de privacidad va también en **App Privacy**, que es otra sección.

Lo que hubo que arreglar, en `manuader/adergames-site` (commit `27f2f20`):

- **Los tres mails rebotaban.** El sitio publicaba `support@`, `contact@` y
  `press@adergames.io`, y ese dominio **no está registrado** — el registro de
  `.io` devuelve `Domain not found`. Ahora los tres son `adermanu@gmail.com`,
  que es el que usaban los textos legales originales.
- **El `TODO` estaba en vivo**, dos veces en el pie. Ahora dice `Manuel Ader`.
- **`domain` apuntaba al dominio muerto**, y de ahí salían canonical, sitemap,
  robots y JSON-LD. Ahora apunta a `adergames-site.vercel.app`.
- **`taxId` quedó vacío** a propósito y la fila de `/about` se oculta sola.
  No se inventó un CUIT.

Verificado con `curl` sobre las 9 rutas en vivo: cero `TODO`, cero
`adergames.io`, un solo mail.

### C2 · Build — hay que subirlo

El campo Build se llena solo cuando termina de procesar un archive subido.
Orden: `xcodegen generate` → Archive (Release) → Distribute → esperar el mail de
"processing complete" → recién ahí aparece para elegir.

⚠️ **Antes de archivar, dos cosas del repo:**

1. `Distribution/ExportOptions.plist` tiene `teamID` = `REEMPLAZAR_EN_F6`.
   Va el Team ID real del enrollment Individual.
2. `project.yml:31` tiene `DEVELOPMENT_TEAM: 2TS7P7VDQJ`, que está comentado como
   **Personal Team gratis**. Un Personal Team no puede distribuir a la App Store.
   Si el enrollment pagado tiene otro Team ID, va acá **y** en el plist — los dos
   a la vez, o el export falla.

Export compliance: el juego no usa criptografía propia, así que la respuesta es
**No** y no hace falta documentación.

### C3 · Screenshots 6.5" — ✅ HECHAS (2026-09-21)

Todas a 1284×2778 exactos, en `Distribution/screenshots/` (ver su README).
Hay tres juegos por idioma; **se sube uno solo**:

| Carpeta | Qué es |
|---|---|
| `ai-posters-6.5/` · `-en/` | Ilustración generada desde las referencias del juego + titular |
| `posters-6.5/` · `-en/` | Arte real del juego + titular, sin IA |
| `promo-6.5/` | Titular + la captura real en un mockup de teléfono |
| `crudas-6.5/` | La captura pelada del simulador |

⚠️ **No subas las cinco puramente ilustradas.** La guideline 2.3.3 pide que las
capturas muestren la app *en uso*. La mezcla sana: **2 pósters adelante**
(son los que se ven en la hoja de instalación y venden) y **3 de `promo-6.5/`**
atrás, que muestran interfaz real.

⚠️ `crudas-6.5/` y `promo-6.5/` tienen la **UI en español**. Para la ficha en
inglés hay que volver a sacarlas con `-AppleLanguages "(en)"`; los pósters no
dependen de eso porque no muestran interfaz.

## D · Los 11 IAP

Se cargan en su propia sección y después **se adjuntan a la versión** antes del
Submit. Si no se adjuntan, la versión sale sin tienda.

⚠️ El **tipo** importa: marcar un pack de plata como no consumible lo deja
comprable una sola vez. `Product.products(for:)` **omite en silencio** cualquier
id que no resuelva — un tipeo se ve como una tienda a la que le falta una fila.

| Product ID (prefijo `com.fisuevolution.iap.`) | Tipo | Precio |
|---|---|---|
| `starter_pack` | No consumible | 4,99 |
| `remove_ads` | No consumible | 2,99 |
| `coins_small` | **Consumible** | 0,99 |
| `coins_medium` | **Consumible** | 4,99 |
| `coins_large` | **Consumible** | 9,99 |
| `oro_small` | **Consumible** | 1,99 |
| `oro_medium` | **Consumible** | 4,99 |
| `oro_large` | **Consumible** | 9,99 |
| `skin_mundialista` | No consumible | 2,99 |
| `skin_parrillero` | No consumible | 2,99 |
| `skins_diamante` | No consumible | 19,99 |

Las descripciones es/en de cada uno están en el `.storekit`, listas para copiar.

> `Docs/HANDOFF-gates-pendientes.md` lista **10** productos: está desactualizado,
> le falta `skins_diamante`. La fuente es el `.storekit`.

---

## E · Nombre y idioma

| | |
|---|---|
| Ficha en español | **FisuEvolution** |
| Ficha en inglés | **HoboEvolution** |

El primary language se fijó al crear el app record, así que ya no se elige: se
verifica en App Information.
