# Integración AdMob (F5.5) — checklist

Rama A del plan aprobado (default): ads reales antes del ship. El código ya está
preparado: `AdsProvider` es la costura, `StubAdsProvider` solo corre con
`useRealAds: false`, y `remove_ads` está vendido en la tienda esperando tener
interstitials reales que apagar.

## [GATE HUMANO] Prerrequisitos (una vez)

1. Crear cuenta de **AdMob** (gratis): https://admob.google.com — con la cuenta
   de Google que quieras asociar a la app.
2. Registrar la app (iOS, `com.manuader.fisuevolution`) → anotar el **App ID**
   (formato `ca-app-pub-XXXX~YYYY`).
3. Crear 2 ad units y anotar sus IDs:
   - **Rewarded** (para los 4 efectos de `rewarded_ads.json`).
   - **Interstitial** (SOLO transiciones suaves: post-prestige y post-popup-offline).
4. Pasarme App ID + ad unit IDs (van a `feature_flags.json` extendido, no al código).

## Implementación (Claude Code, cuando estén los IDs)

- SPM `https://github.com/googleads/swift-package-manager-google-mobile-ads`
  — **excepción documentada** a "sin librerías externas": Apple no ofrece ad network.
- `AdMobAdsProvider: AdsProvider` seleccionado cuando `useRealAds: true`.
- `GADMobileAds.sharedInstance().start` DESPUÉS del prompt ATT
  (`ATTrackingManager.requestTrackingAuthorization`) + `NSUserTrackingUsageDescription`
  localizada; consentimiento UMP (GDPR) antes del primer ad.
- Si el usuario niega ATT → non-personalized ads (nunca romper la experiencia).
- `PrivacyInfo.xcprivacy`: `NSPrivacyTracking = true` + data types del SDK
  (el SDK trae su propio manifest).
- ⚠️ **REGLA REEMPLAZADA el 2026-09-02.** El dueño pidió "un anuncio normal cada
  5 o 10 minutos de juego", así que el interstitial dejó de ser sólo-transiciones
  y pasó a tener **cadencia por reloj**. Lo que NO cambió es que nunca cae en
  medio de una acción, y el mecanismo es la parte que importa:

  **El reloj ARMA, la pausa DISPARA.** `AdsCoordinator.armIfDue()` corre en
  `flushHUD()` (8 Hz) y sólo prende una bandera cuando pasaron los
  `minSecondsBetween` más las dos gracias (arranque y post-rewarded, en
  `rewarded_ads.json`). Mostrarlo lo pide la UI desde una **pausa natural** —hoy,
  cerrar una de las seis pantallas y volver al tablero—, y ahí
  `GameState.isSafeMomentForInterstitial` chequea las otras cuatro condiciones
  (nada tapando el tablero, ninguna celebración con el turno, tutorial cerrado,
  juego cargado).

  La implementación literal —un timer que presenta— es la que hay que evitar:
  un interstitial que cae encima del tablero mientras el jugador tapea genera
  **clicks accidentales**, que es política de invalid traffic de Google, y es la
  peor experiencia posible en un juego cuyo verbo es tocar la pantalla.

- Interstitials (regla vieja, ahora ADEMÁS de la cadencia): en `confirmPrestige()` (post-reset) y al cerrar
  `OfflineEarningsView` — jamás durante gameplay (regla dura del skill). Ambos
  se saltean si `player.removedAds`.
- `Info.plist` (via project.yml): `GADApplicationIdentifier` + SKAdNetwork ids.
- Max ad content rating: **T** (no romper el rating 12+ de la app).
- Test devices configurados antes de probar (nunca clicks reales en dev).

## Rama B (fallback si no querés ads en la v1)

`useRealAds` queda false y además: ocultar la sección de videos de `GiftsView` por
flag, mapear sus 4 efectos a boosts con cooldown, sacar `remove_ads` del
catálogo de ASC v1 (el .storekit local puede conservarlo). Documentado para
decisión en el gate de cierre de F5.
