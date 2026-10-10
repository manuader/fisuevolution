# Notas a App Review — ranking de la llegada a Dios (E12)

Texto para pegar en **App Review Information → Notes** de la build 2.0 (en inglés, como las notas
de la submission anterior) y datos para la **App Privacy** de App Store Connect. Lo pega E10.

## Texto para pegar

```
LEADERBOARD ("Ranking") - user-generated content, Guideline 1.2

When a player reaches the final stage of the game ("God") they may OPTIONALLY enter a leaderboard
with a display name. There are no accounts, no sign-in and no chat; the only user-generated content
is that short name (max 15 characters: letters, digits, space . - _).

Moderation (before anything is shown to other players):
1. Rules: length and allowed-character check, run on the device and again on our server (the
   server decides).
2. Word list: names matching a blocklist are rejected.
3. AI review: the name is checked by an automated classifier (Anthropic's Claude Haiku). If it is
   unavailable, the entry is shown as "Anonimo" and re-checked automatically every 15 minutes
   until it passes or is rejected. A rejected name asks the player for another one.

Reporting: in the leaderboard, long-pressing (context menu) any row offers "Report". No account
is needed. Reports are idempotent per player.

Removal: a name is hidden automatically after 3 reports, or at any time by the developer. A hidden
run disappears from the leaderboard for everyone. The developer can be reached at the contact
below, which is also in the Terms of Service and the Privacy Policy (inside the app, Settings).

Terms: the Terms of Service state the name rules, that reported names are hidden, and the contact
for reports and deletion requests.

Contact: adermanu@gmail.com

Data: the leaderboard stores a random install identifier (not linked to the player's identity,
Apple account or advertising identifier) and the chosen name plus run times. Neither is used for
tracking. See App Privacy.

To test: the leaderboard tab is in the sliding menu.
```

## App Privacy (App Store Connect)

Se suman a lo que ya declara AdMob (que no se toca). Coincide con `NSPrivacyCollectedDataTypes` de
`PrivacyInfo.xcprivacy`, que fija `PrivacyManifestTests`.

| Tipo de dato | Categoría ASC | Vinculado a la identidad | Usado para seguimiento | Propósito |
|---|---|---|---|---|
| `installId` (aleatorio, por instalación) | Identifiers → Device ID | No | No | App Functionality |
| Nombre elegido y tiempos | User Content → Other User Content | No | No | App Functionality |

## Avisos para E10

- Llegar a Dios lleva horas, así que la nota no promete que el revisor pueda anotarse. Lo que sí
  puede ver: la pestaña **Ranking** aparece en la barra inferior apenas termina el tutorial
  (`tabs.json`: `unlockWhen: tutorialCore`), muestra el tablero y permite **Reportar** con un
  mantener apretado. El texto aplicado a ASC vive en `release.json → store.reviewNotes`
  (sección LEADERBOARD, resumida por el tope de 4000 caracteres); este archivo es la versión larga.
- **`NSPrivacyTracking` sigue en `false` a propósito (B22 pendiente de dominios).** El dueño
  aceptó pasarlo a `true`, pero Apple rechaza el build si es `true` sin `NSPrivacyTrackingDomains`
  (ITMS-91064, ya pasó dos veces en la v1: `Docs/HANDOFF-v2.md`). Ni el manifiesto de
  GoogleMobileAds ni el de UMP (SPM resuelto) declaran dominios, y los adaptadores de Unity y Meta
  no están en el proyecto, así que no hay una fuente en el repo para listarlos. Hay que sacar los
  dominios de la documentación de cada SDK (o de un reporte de privacidad de la app corriendo en
  un dispositivo), ponerlos en `NSPrivacyTrackingDomains` y recién ahí pasar a `true`.
  `PrivacyManifestTests.trackingNeedsDomains` impide que quede `true` sin dominios.
- La Política de Privacidad (`Distribution/site/privacy.md` y su copia en la app,
  `Resources/Legal/privacy.md`) nombra a Anthropic (Claude) como quien revisa los nombres y dice
  que sólo recibe el nombre elegido.
