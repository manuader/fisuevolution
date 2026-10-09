# Sesión 2026-10-08 — release-ops: compras, ficha, anuncios y mediación como código

**Para el próximo agente: empezá por "Cómo seguir".** Todo lo comercial de la 2.0 se configuró
fuera de los relevos, desde una sesión del dueño, en la rama `v2/release-ops` (pusheada). La
fuente de verdad es `Distribution/release/release.json`; la herramienta, `Tools/releaseops/`; el
cómo, la skill `.claude/skills/release-ops/SKILL.md`; el estado detallado,
`Distribution/release/AUDITORIA-2026-10-08.md`.

## Estado al cierre (verificado, no supuesto)

| Frente | Estado | Cómo se verificó |
|---|---|---|
| 14 compras en App Store Connect | Configuradas: 11 de la v1 APPROVED con borradores 2.0 + es-ES; 3 ofertas creadas | `releaseops asc diff` → VERDE |
| Listas para revisión | 11/14: las 3 ofertas sin captura de revisión (MISSING_METADATA) | `releaseops asc ready` → ROJO esperado |
| `oro_large` | USD 9.99 (era 4.99; OK del dueño) | `asc status` |
| Versión 2.0.0 en ASC | Creada (PREPARE_FOR_SUBMISSION), ficha en-US/es-MX/**es-ES**, Novedades y notas de review | `releaseops asc listing diff` → VERDE |
| Mac y Vision Pro | **Apagados** (Pricing and Availability, guardado) | página releída: ambos destildados |
| Cuestionario de edad | Ya estaba como pide setup §1.6 (no se tocó) | API `ageRatingDeclaration` |
| AdMob: 11 unidades | 5 nuevas (ruleta, colchón, visitantes, diario, app open) + 6 de v1; "unidad" → "pausa publicitaria" | lista del panel |
| IDs en el código | `feature_flags.json` y `ads.json` (+ `switches.appOpen: true`); tests actualizados | `releaseops validate` VERDE; oráculo tarea VERDE |
| `ads.json` remoto | Publicado en `adergames-site.vercel.app/config/ads.json` | `curl` 200, idéntico |
| `app-ads.txt` | Google + 161 líneas de Unity + Meta | `curl` 200 text/plain |
| Unity Ads (mediación) | **Activa**: Game ID 800392624; `BP_Rewarded_iOS` ×8, `BP_Interstitial_iOS` ×1 | AdMob: "La asociación está activa" |
| Grupos de mediación | "Rewarded iOS" `1870390862` y "Interstitial iOS" `2477738028` (AdMob + Unity) | grupo releído |
| Meta Audience Network | Propiedad + 3 ubicaciones listas; mediación = AdMob; **alta en AdMob a medias** (paso 1 ok, paso 2 iniciado) | AdMob y Monetization Manager |
| AppLovin / Mintegral | Fuera: AppLovin no acepta publishers nuevos; Mintegral no funcionó | mail del dueño |
| Consentimiento UE | Socios: "agregar fuentes automáticamente" **encendido**. **No existe mensaje** de RGPD ni de estados de EE. UU. | Privacidad y mensajería |

## Cómo seguir (en este orden)

1. **Integrar la rama** `v2/release-ops` a `version-2` (merge --no-ff + `oraculo.sh rapido`). Lo
   tiene el relevo en `DUENO.md`. Si E7b tocó `adUnitIDs`: `releaseops admob sync-code`.
2. **🔒 Mensajes de consentimiento** (preguntar al dueño antes: es texto legal que ve el usuario).
   AdMob → Privacidad y mensajería → Reglamentos europeos → Crear (y Reglamentaciones estatales de
   EE. UU. → Crear). Valores: app HoboEvolution, política `https://adergames-site.vercel.app/privacy`,
   idiomas por defecto, botones Aceptar / No aceptar / Administrar opciones. Publicar. Sin esto, las
   notas de App Review mienten ("UMP consent form is shown").
3. **Meta**, cuando el dueño termine su onboarding (2FA, cuenta de pagos, datos fiscales, vincular
   la app al pago, verificar la app — todo suyo):
   - AdMob → Mediación → Fuentes de licitación → Configurar fuente → Meta Audience Network →
     paso 2 "Firme el acuerdo de asociación" → paso 3 "Reconozca el acuerdo de licitación" (el
     dueño ya autorizó aceptar estos acuerdos).
   - Mapeo (Placement ID por unidad, de `release.json → mediation.networks.meta.placements`):
     bonificadas ×8 → `…_1067256362983637`; "anuncio normal" → `…_1067256366316970`;
     "pausa publicitaria" → `…_1067256369650303`.
   - Sumar Meta a "Rewarded iOS" y "Interstitial iOS"; crear "Rewarded interstitial iOS" (unidad
     "pausa publicitaria", sólo Meta + AdMob).
   - Cambiar `meta.pending` en `release.json` a `[]`.
4. **Capturas de las 3 ofertas** cuando exista la hoja (E6a T11, `--uitest-offer=<id>`):
   `releaseops asc screenshot offer_bienvenida <png>` (y las otras dos) → `asc ready` verde.
5. **Código de mediación** (E7a / E7b-a T6, en `DUENO.md`): adaptadores SPM de Unity y Meta y los
   SKAdNetwork de Unity en el `Info.plist`; probar con Ad Inspector.
6. **App Privacy** (no está en la API): tras el archive de la 2.0, Organizer → Generate Privacy
   Report; declarar la unión de Google + Unity + Meta (setup §1.7).
7. **Antes de enviar:** releer Novedades y notas de review contra la build de TestFlight
   (`release.json → store`, después `releaseops asc listing apply --yes`), adjuntar las 14 compras a
   la versión y 🔒 enviar con OK del dueño.

## Credenciales y accesos

- API de App Store Connect: `~/.appstoreconnect/releaseops.json` + `private_keys/AuthKey_H3LNGX8AU7.p8`
  (600, fuera del repo). Cubre compras, ficha, versión y notas; **no** cubre Mac/Vision Pro, App
  Privacy ni el questionnaire de privacidad: eso va por navegador.
- Navegador: Claude in Chrome con la sesión del dueño (ASC, AdMob, Unity, Meta). La ventana del
  agente a veces queda angosta (500 px): los paneles cambian a vista móvil; usar `find` + refs.
- El agente no crea cuentas, no pone contraseñas ni 2FA, no carga datos de pago o fiscales.

## Trampas de la sesión (lo que costó tiempo)

- **ChatGPT web traía "You've reached your limit" en su JS**: el detector de bloqueo del generador
  leía `page_source` y daba límite con el chat libre. Arreglado (texto visible).
- **Idioma APPROVED de una IAP no se edita (409 ACTIVE)**: Apple abre un borrador al tocar el
  producto (sumar un idioma); se edita ese. `asc apply` hace la segunda pasada.
- **Crear la ficha de un idioma crea sola la localización de la versión** (409 en el POST
  siguiente): `asc listing apply` hace las fichas primero.
- **Mover carpetas a `*.nosync` rompe la `.build` de SwiftPM** (rutas absolutas): `swift package clean`.
- **AdMob**: el combo de asignaciones de un grupo no toma el click por ref (coordenadas); el
  diálogo de fuentes pagina de a 10; el ID con `~` es el de la app, el de unidad lleva `/`.
- **Meta**: "Firme el acuerdo de asociación" redirige al inicio de Monetization Manager mientras
  el onboarding esté incompleto.
