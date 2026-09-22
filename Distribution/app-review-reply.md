# Respuesta a App Review — Guideline 2.1, Information Needed

_Submission ID `2a40c3f5-ceb4-4cca-b13d-d913d292a8e2` · build 1.0.0 (3)._

**No es un rechazo técnico.** Es el pedido estándar que Apple le hace a una
cuenta sin historial de review. Se contesta y se sigue.

El texto de abajo va **en los dos lugares**, como pide el mail:

1. **Reply to App Review**, en la conversación de la submission.
2. **App Review Information → Notes**, para que quede para las próximas.

⚠️ El punto 1 —el video— **no se puede generar acá**: tiene que ser una
grabación en un iPhone físico. Las instrucciones están al final.

---

## Texto para pegar (en inglés)

```
Thank you for the review. Below is the information requested.

1. SCREEN RECORDING
A screen recording captured on a physical iPhone is attached. It starts from
app launch and shows the typical user flow, including a purchase flow.

Note on the items listed in your request:
- There is no account registration, login, or account deletion flow. The app
  has no accounts of any kind (see item 3).
- There is no user-generated content. All content is authored by us and ships
  inside the binary, so there is no reporting or blocking mechanism.
- Accessing paid content is shown in the recording.

2. PURPOSE AND TARGET AUDIENCE
HoboEvolution (FisuEvolution in Spanish) is a single-player merge/idle game
with Argentine humor. The player taps a character to earn coins, hires more
characters, and drags one onto another to merge them into the next tier,
climbing 30 tiers from a homeless man to a god of the universe.

It is satire of economic precarity: the events, characters and jokes are
exaggerated takes on Argentine economic life (inflation, devaluation, a
university degree that doesn't pay rent). It solves nothing practical — the
value it provides is entertainment and humor, in a genre (merge/idle) whose
audience is casual mobile players who play in short sessions.

Target audience: casual mobile gamers aged 12+, primarily Spanish-speaking in
Latin America, with an English localization for everyone else. The app is
rated 12+ for infrequent/mild references, and is not directed at children
under 13.

3. SETUP AND ACCESS INSTRUCTIONS
No setup and no credentials are required. The app has NO account system, NO
login, NO sign-up and no server of ours — all progress is stored on the
device. There is nothing to log into, so no demo account is needed.

Everything is reachable from the first screen:
- Tap the character on the board to earn coins.
- Tap the green button at the bottom-left to hire a second character.
- Drag one character onto another to merge them and unlock the next tier.
- Bottom bar: Hire, Upgrades, Outfits, Bonus, Store, Menu.
- The Store tab contains all in-app purchases and the "Restore Purchases"
  button.
- Rewarded video ads are offered from the Bonus tab and are always opt-in.

Game Center and iCloud sync are implemented in the codebase but are DISABLED
by feature flag in this version, so they are not reachable and the app does
not use them.

4. EXTERNAL SERVICES, TOOLS AND PLATFORMS
The app uses exactly three, and nothing else:

- Google AdMob (Google Mobile Ads SDK) — serves rewarded video ads and
  interstitial ads. This is the only reason the app requests App Tracking
  Transparency permission.
- Google User Messaging Platform (UMP) — shows Google's consent form before
  serving ads, where required by law.
- Apple StoreKit 2 — all in-app purchases. Apple processes every payment; we
  never see or store payment details.

Explicitly NOT used: no analytics provider, no crash reporting service, no
backend or server of ours, no authentication provider, no AI services, no
data providers, and no third-party service other than the three above.

5. REGIONAL DIFFERENCES
The game's features and content are identical in every region. There are two
differences, both driven by law rather than by content:

- In the EU, the UK and Switzerland, Google's UMP consent form is shown before
  any ad is served. Elsewhere it is not.
- The app is localized in Spanish and English. The localizations are
  translations of the same content; no feature or item exists in one language
  and not the other.

In-app purchase prices follow Apple's standard pricing tiers per storefront.

6. REGULATED INDUSTRY / PROTECTED THIRD-PARTY MATERIAL
The app does not operate in a regulated industry and contains no protected
third-party material. Specifically:

- It is not a financial, gambling, health, or otherwise regulated product.
  The in-game currencies ("plata" and "ORO") are game items with no monetary
  value: they cannot be cashed out, transferred, or exchanged for anything
  outside the game, and the Terms of Service state this explicitly.
- There is no real-money gambling and no loot box purchasable with real money.
- All art, music, text and code are ours, produced for this game. No licensed
  or third-party creative material is included.
- Brands and institutions that appear are parodies or satire, not real
  trademarks: for example "McRonald's". Characters are cultural archetypes,
  not real identifiable people, and no real person's name or likeness is used.

If any further documentation would help, we're glad to provide it.
```

---

## El video — lo único que falta, y lo tenés que grabar vos

Tiene que ser en un **iPhone físico** con el iOS más reciente, no en el
simulador. El camino más simple es instalar el build 3 desde TestFlight y
grabar con la grabación de pantalla de iOS (Centro de Control).

Guion sugerido, **de un tirón y sin cortes**, unos 60–90 segundos:

1. Abrir la app desde el ícono de la pantalla de inicio (tiene que empezar ahí).
2. Dejar que aparezca el diálogo de **App Tracking Transparency** y responderlo.
3. Tocar el personaje varias veces para ganar plata.
4. Tocar el botón verde y contratar un segundo personaje.
5. **Arrastrar uno sobre otro** y mostrar la fusión — es el núcleo del juego.
6. Abrir **Tienda**, mostrar el catálogo y que se vea **Restaurar compras**.
7. Abrir **Bonus** y mostrar una oferta de video recompensado (que se vea que
   hay que tocarla, o sea que es opcional).
8. Volver al tablero.

⚠️ Apple pide expresamente que se vea **el acceso a contenido pago**. Si podés,
hacé una compra real en sandbox durante la grabación; si no, mostrá la ficha
del producto y el flujo hasta la hoja de pago de Apple.
