# Tasks — FisuEvolution

> Checklist vivo. ✅ = hecho y verificado. Contexto completo en `ESTADO.md`.

## F0 — Scaffold
- [x] Activar Xcode + runtime iOS 18.6 (~8GB) + `sudo xcode-select` (fix definitivo aplicado)
- [x] git init + .gitignore + XcodeGen (`project.yml`, 3 targets, Swift 6 strict, warnings-as-errors)
- [x] `Packages/EconomyKit` (Codables + fórmulas + validación de escalera)
- [x] `Tools/generate-tiers` → `tiers.json` (37 entradas, anti-drift)
- [x] App shell: GameState @Observable, BoardScene, persistencia CoreData+snapshot, HUD, String Catalog base `es`, paleta
- [x] Build + tests + board visible en Simulador

## F1 — Economía
- [x] Tap (tapYield × multiplicadores) con feedback
- [x] Spawn progresivo con curva de costos (extensión aprobada al bible)
- [x] CoinFormatter (K/M/B/T/aa…)
- [x] Autosave con debounce

## F2 — Loop completo
- [x] Merge drag&drop con snap-back + choice node de carrera T9 (merge diferido)
- [x] Pasivo por tipo + tick §2.4 con clamp de delta
- [x] Offline con cap + popup
- [x] Prestige (soul points delta, prestige_unlocks con descuento de spawn)
- [x] SaveMigrator + autosave inmediato al background + debug panel
- [x] `Tools/balance-sim` + check duro de alcanzabilidad
- [x] Balance tuneado (baseCost 50 / growth 1.022 / basis total) — gate aprobado por el usuario

## F4 — Monetización
- [x] StoreKit 2 local: 4 productos, StoreManager (updates/restore/refund), tienda con Restore
- [x] Skins por tinte en engine (golden/galaxy/god)
- [x] AdsProvider + stub dev + rewarded_ads.json (4 efectos como ActiveModifier)
- [x] Tests con SKTestSession (compra, skin, refund)

## F5 — Pulido y contenido
- [x] Schema v3 + migración v1→v2→v3
- [x] ActiveModifier (efectos temporales persistidos)
- [x] 7 JSONs de contenido (agente) + 122 strings es/en
- [x] UpgradeManager (7 líneas, derivación única) + UpgradesView
- [x] EventManager (8 eventos argentinos, 6 effect types) + banner accesible
- [x] BoostManager (6 boosts, cooldowns, review-safe por buildVariant) + BonusView
- [x] SpecialDropManager (drops en merge, secretos por prestige) + celebración
- [x] DailyRewardManager (ciclo 7 días; fresh install no reclama día 1) + popup
- [x] Golden touch + crítico en el tap
- [x] HapticsManager (CoreHaptics, 5 patterns, toggle)
- [x] ParticlePool (código, no .sks)
- [x] Reveal de evolución + share card (UIActivityViewController) + bonus viral
- [x] FTUE (3 hints, Reduce Motion)
- [x] **Rediseño de campo estilo Cow Evolution** (fondo por etapa, anclas orgánicas, wander, profundidad, sombras, modo arte-real en CharacterNode)
- [x] Audio sintetizado por código (10 SFX + 2 loops) + AudioManager + sliders
- [x] GameCenterManager + CloudSaveSync + SaveConflictResolver (clamp Int64) detrás de flags
- [x] 121 tests en verde
- [ ] Pass de performance: verificar 60fps sostenidos con overlay FPS (build debug ya lo muestra) en stress (taps + merges + evento + partículas)
- [ ] Pass de accesibilidad final: audit con VoiceOver activado en tienda/upgrades/popups
- [ ] Probar haptics en iPhone físico (firma personal gratuita)

## F3 — Arte (EN CURSO — camino Gemini)
- [x] Pipeline completo (prompts deterministas, rembg, scorer v2, regen loop, atlas, manifest --verify)
- [x] Dirección "campo": 46 poses únicas de figura completa + 11 backgrounds playfield (`cultural_dict.py`)
- [x] Descarte SD 1.5 (calidad) — evidencia en state/prompt-search/
- [x] Stack SDXL instalado como fallback (matriz lista, nunca corrida)
- [x] Cliente API Gemini (`gemini_batch.py`) + key del usuario en `.secrets/`
- [ ] **Muestras de prueba Gemini (4) → review visual de Claude → mostrar al usuario** ← en vuelo
- [ ] Si convencen: generar 3-4 heroes definitivos → `heroes/approved/` (referencias de estilo para todo lo demás)
- [ ] Tanda 1 (16 personajes T1-T10) → rembg → QA → review visual
- [ ] Tanda 2 (31 UI/boosts/logo) — nota: logo sin texto
- [ ] Tanda 3 (3 backgrounds tempranos)
- [ ] Tanda 4 (20 personajes T11-T30 + 8 bg cósmicos)
- [ ] Tanda 5 (10 specials + 5 fx + overlays de skins)
- [ ] `organize_atlases.py` (@2x/@3x, atlas lowercase) + `update_manifest.py --verify` exit 0 (93 assets)
- [ ] Verificación en juego: campo con arte real a 60fps, `git diff` solo Resources/ y Tools/
- [ ] AppIcon 1024 sin alpha desde el logo → Assets.xcassets (reemplaza placeholder)
- [ ] Cuota de la API: si el free tier limita por día, dividir tandas en días o pedir upgrade de key

## F5.5 — Ads reales (rama A, default)
- [ ] [USUARIO] Cuenta AdMob gratuita → App ID + rewarded ID + interstitial ID
- [ ] SPM GoogleMobileAds + AdMobAdsProvider tras `useRealAds`
- [ ] ATT prompt + NSUserTrackingUsageDescription + UMP consent
- [ ] PrivacyInfo con tracking + nutrition labels actualizadas
- [ ] Interstitials SOLO post-prestige y post-offline (remove_ads los apaga)
- [ ] (Rama B si no hay cuenta: ocultar rewarded, efectos→cooldowns, remove_ads fuera del catálogo v1)

## F6 — Ship
- [x] Ship-prep: PrivacyInfo.xcprivacy, ExportOptions.plist, entitlements (sin referenciar), CI workflow, privacy/support pages, store-metadata.md (ASO + Review Notes + guión de screenshots)
- [ ] [USUARIO] Apple Developer Program (USD 99) + App Store Connect API Key (.p8 fuera del repo)
- [ ] [USUARIO] Decidir nombre comercial (propuesta: "Fisura: Evolución Idle")
- [ ] App ID + capabilities (GC, CloudKit container, IAP) + app record en ASC (primary: Spanish (Mexico))
- [ ] Registrar los 4 IAP espejando el .storekit
- [ ] Game Center: crear IDs de gamecenter.json en ASC + referenciar entitlements en project.yml + flip `gameCenterEnabled`
- [ ] CloudKit: schema PlayerSave/main_save en Dashboard + flip `cloudKitEnabled` + [USUARIO] Deploy to Production
- [ ] Publicar privacy/support/marketing (repo público + GitHub Pages) + curl 200 ×3
- [ ] Rating 12+/13+ (cuestionario honesto; verificar buildVariant "store")
- [ ] Screenshots 6.9" por CLI según guión + subir metadata
- [ ] Archive + upload por CLI (ExportOptions con teamID real) → TestFlight
- [ ] [USUARIO] Probar en iPhone real: FPS, haptics, IAP sandbox, GC, sync CloudKit entre 2 instalaciones
- [ ] Checklist pre-submission ejecutable (tests 0 fallas, warnings 0, greps limpios, manifest --verify, Instruments: Leaks 0/60fps, Restore funcional)
- [ ] [USUARIO] Submit for Review (+ Review Notes ya escritas) — release manual
- [ ] (Opcional) gh repo create + push + CI activo

## Extras pendientes de decisión
- [ ] Nombre comercial final y logo definitivo
- [ ] ¿Ads v1 sí/no? (rama A vs B)
- [ ] Localización en más idiomas post-launch (bible sugiere pt/fr/de/it/ja/ko/zh)
