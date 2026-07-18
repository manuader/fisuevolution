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
- Interstitials: SOLO en `confirmPrestige()` (post-reset) y al cerrar
  `OfflineEarningsView` — jamás durante gameplay (regla dura del skill). Ambos
  se saltean si `player.removedAds`.
- `Info.plist` (via project.yml): `GADApplicationIdentifier` + SKAdNetwork ids.
- Max ad content rating: **T** (no romper el rating 12+ de la app).
- Test devices configurados antes de probar (nunca clicks reales en dev).

## Rama B (fallback si no querés ads en la v1)

`useRealAds` queda false y además: ocultar sección rewarded de BonusView por
flag, mapear sus 4 efectos a boosts con cooldown, sacar `remove_ads` del
catálogo de ASC v1 (el .storekit local puede conservarlo). Documentado para
decisión en el gate de cierre de F5.
