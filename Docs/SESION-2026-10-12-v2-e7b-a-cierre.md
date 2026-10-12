# Sesión 2026-10-12 — Cierre de E7b-a: los anuncios forzados y la mediación

Cierra E7b-a (T7) y, con él, **E7b entera**. Sólo documentación. Complementa `Docs/SESION-2026-10-11-v2-e7b.md` (que cerró E7b-b y dejó E7b-a T6–T7 abiertas).
Plan: `Docs/superpowers/plans/2026-10-07-v2-e7b-a-forzados-mediacion.md`. La infraestructura de anuncios (protocolo, unidades, config remota, `AdsCoordinator`) es de E7a (`Docs/SESION-2026-10-06-v2-e7a-anuncios.md`).

El `completo` del paso 1 del plan lo corre el controlador sobre la punta de la épica: este documento **no** registra su resultado. No se compiló ni se corrió nada para escribirlo.

## 1. La tabla por tarea

| Tarea | Qué entregó | Commit (rama / merge) | Verificación y revisión |
|---|---|---|---|
| T1 | La config remota en marcha (`ForcedAdsSetup`): IDs remotos sólo en producción y Release (DEBUG siempre `googleTest`), desde el próximo arranque | `5fee22d` (`integ-r19`) | Carry a T2: sacar `cadence:` de `configure` y el reloj `armIfDue` (cerrado en T2) |
| T2 | Los cortes naturales (`GameState+Ads`): `sheetClosed`, `celebrationsDrained`, `reincarnation`, `offlinePopupDismissed`; el reloj de la 1.x se fue | `8f435c1` (merge `796da65`, `integ-r21c`) | Tarea VERDE (unit 109, 12 nuevos). Opus: Approved sin obligatorios. No se publica sin T3 |
| T3 | La pausa publicitaria: previa de 5 s, «No, gracias» sin castigo, piso de 5 s, premio que rota | `de150c6` + arreglos `bf63962` (merge `06379f6`, claves `1f090ef`, `integ-r26`) | `rapido` VERDE (EK 827 · unit 1329). Opus **Approved con arreglos**: `sheetOpen` mira `shareOffer`, `persistNow` tras el grant, piso de 5 s, sin premios no se elige |
| T4 | El app open al volver (se pide al irse, sale antes del popup offline) | `5618f4f` (merge `fa4a373`, `integ-r21c`) | Tarea VERDE (unit 72). Opus: Approved sin obligatorios |
| T5 | «Opciones de privacidad» (UMP) en Ajustes, con `AdsConsent.privacyRowVisible` | `86e6413` (`integ-r20`) | +3 claves. **Sin prueba en región UE con el SDK real** |
| T6 | La mediación: Unity Ads 4.21.000 y Meta Audience Network 6.22.000 por SPM, `-ObjC`, SKAdNetwork 50 → 89, Ad Inspector en el panel | `db38542b` (merge `24fce67d`) | Release 0 warnings · `.app` 247 MB · `MediationContractTests` (2 tests: la unión de SKAdNetwork y los dos adaptadores enlazados) · `Tools/v2/test_skadnetwork.py`. `Package.resolved` re-resuelto en la integración |
| T7 | Este cierre | — | `completo` a cargo del controlador |

### Lo que entró en T6 (relevo 49)

- **Dos redes, no cuatro.** Decisión del dueño (2026-10-08): sólo **Unity Ads** y **Meta Audience Network**. AppLovin rechazó la cuenta (no acepta publishers nuevos, mail del 2026-10-08) y Mintegral no dejó crearla (`release.json → mediation`).
- **Por `revision:`, no por versión.** Los tags de los paquetes de Google (`4.21.000`, `6.22.000`) llevan ceros a la izquierda: no son semver y SPM los ignora. `project.yml` los fija por el SHA del tag. Cada paquete de Google fija el SDK de su red con `exact:`: no se suma el paquete de la red aparte, o SPM no resuelve.
- **`-ObjC`** en `OTHER_LDFLAGS` de la base **y repetido en la línea de Debug**, que pisaba a la base (`-ObjC -weak_framework StoreKitTest`). Sin él los adaptadores no se enlazan en Debug y no pujan; `adapterIsLinked` lo vigila con `NSClassFromString`.
- **SKAdNetwork:** la unión de Google, Unity y los dos IDs fijos de Meta (`v9wttpbfk9`, `n38lu8286q`) son 89 IDs en `Info.plist`, escritos por `Tools/v2/skadnetwork.py actualizar` (baja la lista oficial de Unity y conserva los comentarios del archivo). `verificar` sale con 1 si falta alguno. Hay que **correrlo de nuevo en cada actualización de un adaptador**: las listas crecen y la falta no falla nada, sólo se factura menos.
- **El Ad Inspector** (`AdInspector.present()`, sólo `#if DEBUG`) cuelga de una sección «Mediación» al final de la `List` del panel de debug (`debug.ads.inspector`).
- **App Privacy de los SDK**, leída de los `PrivacyInfo.xcprivacy` resueltos (tabla en `Distribution/setup-v2-asc-admob-mediacion.md`): Unity no declara rastreo; **Meta declara `NSPrivacyTracking = true` con `ep1.facebook.com` y `ep6.facebook.com` en su propio manifiesto**, que Apple suma al de la app.

## 2. Qué se verificó por tests y qué no

Cubierto por unitarios del repo (no se re-corrieron para este documento):

- **Escenario 2 (config remota caída → rige el respaldo del bundle):** `AdsRemoteConfigTests` (sin red, `current()` devuelve el respaldo).
- **Escenario 3, las reglas:** `NaturalBreakPolicyTests` (nunca en el tutorial, nunca con una hoja abierta, nunca sobre una celebración ni con otro anuncio en pantalla, ≥ 2 min entre forzados, un formato por corte, común y pausa alternados) y `NaturalBreakWiringTests`.
- **Escenario 4:** `NaturalBreakPolicyTests` («`remove_ads` apaga los tres forzados en todos los cortes», sobre todos los cortes), `AppOpenWiringTests`, `AdBreakTests`.
- **T6:** `MediationContractTests`, `test_skadnetwork.py`.

No cubierto por ningún test: todo lo que necesita el anuncio real, un dispositivo o un panel ajeno (sección 4).

## 3. El porqué de cada default de «Para el dueño» de E7b-a

Ninguno frenó; en el árbol no hay registro de que el dueño haya cambiado alguno (aceptó además B1–B26, HANDOFF §5.22).

1. **Rechazar la pausa cuenta como el corte.** «No, gracias» no muestra ni quita nada, pero cierra la ventana de 2 min y pasa el turno al intersticial común. Si no contara, quien la rechaza la vería ofrecida otra vez al cerrar la próxima hoja, diez segundos después.
2. **La pausa avisa su premio con un aviso de la torre** y el premio rota sólo cuando se gana. Los tres premios y los 5 s viven en `rewarded_ads.json` (`adBreak`), no en la config remota: son contenido del juego, no cadencia.
3. **En Release los IDs de anuncio salen de la config remota** (caché o respaldo); los de `feature_flags.json` son el respaldo del respaldo y un test exige que los dos digan lo mismo al embarcar. Un ID nuevo rige desde el **próximo** arranque (el proveedor ya está creado); la cadencia y los interruptores, en el acto.
4. **App Privacy con la mediación.** El plan suponía que Unity, Mintegral y Meta declaraban datos usados para rastrear; leídos los manifiestos de las dos redes que quedaron, Unity no declara rastreo y el que rastrea es **Meta**. El manifiesto de la **app** sigue en `NSPrivacyTracking = false` porque describe el código propio (que no rastrea) y Meta se declara sola en el suyo; no hace falta que la app liste los dominios (**E10 T14 / B22 pasó a ⏭**, relevo 49, sin riesgo de ITMS-91064). Queda en `false` salvo que el dueño prefiera declarar tracking también en el manifiesto de la app (entonces `trackingNeedsDomains` exige `ep1`/`ep6.facebook.com`).
5. **El contador de sesiones arranca con E7b.** Un veterano de la 1.x cuenta su primer arranque de la 2.0 como sesión 1 y no ve app open hasta el segundo (prudente).
6. **Qué celebración termina en un corte (`celebrationsDrained`).** Sí: el reveal del tablero, el cofre, la pinta, el special, el diario y la carrera, y la cinemática (`.cinematic`, E8). No: el offline (tiene su corte), los avisos chicos, los logros, el tip del tutorial, la llegada de un visitante (el jugador interactúa enseguida) ni la oferta (un anuncio pegado a una oferta rechazada se lee como castigo). Cambia en un `switch`.

## 4. Escenarios a mano 🔒 del dueño

No se hicieron en device ni a mano; no se inventan resultados.

1. **Anuncios con IDs de prueba + Ad Inspector.** Build de Debug en un dispositivo o simulador → panel de debug › sección «Mediación» › «Ad Inspector (mediación)». Comprobar que lista Unity Ads y Meta como redes del inventario, y qué red sirvió cada anuncio. Con Meta sin onboarding (sección 5) se espera que no llene.
2. **Config remota caída, a mano.** Modo avión, matar la app, abrirla: arranca igual con el respaldo del bundle (el test cubre el cargador; el arranque entero no).
3. **Un intersticial y una pausa alternados en cortes reales:** cerrar el menú, cerrar el popup offline, reencarnar. Nunca encima de una celebración. Con el SDK real, no con el stub.
4. **`remove_ads` en el sandbox** (StoreKit de pruebas o sandbox real): comprarlo y ver que los tres forzados (intersticial, pausa, app open) se apagan **en la misma sesión**; los videos opt-in siguen.
5. **UMP en región UE** (simular con `UMPDebugSettings.geography = .EEA` y un dispositivo de prueba): el formulario sale antes del primer anuncio y «Opciones de privacidad» en Ajustes lo reabre.
6. **Las capturas del plan (Task 7, paso 1)** quedaron sin tomar: la pantalla previa de la pausa en el SE, el 16 Pro y el iPad 13"; Ajustes con la fila de privacidad (`--uitest-privacy-options`); el Ad Inspector.
7. **El pedido del plan de probar `BonusHUDUITests` en orden** (`testTwoBonusesShowAtTheSameTime` cayó una vez y verde sola): lo cubre el `completo` del controlador.

## 5. Carries

- **Meta tiene el onboarding pendiente** (`release.json → mediation.networks.meta.pending`): 2FA del negocio, cuenta de pagos, información fiscal, vincular la app a la cuenta de pagos y verificar la app. Hasta entonces los placements de Meta no llenan; Unity no tiene pendientes en el archivo.
- **App open sólo con AdMob.** Ni Unity ni Meta pujan en app open (`release.json → mediation._noGroup`): ese formato queda sin mediación a propósito.
- **Los grupos de mediación en AdMob, a armar a mano** (🔒 dueño). `release.json → mediation.groups` los define: «Rewarded iOS» (las ocho unidades `rewarded*`; Unity y Meta), «Interstitial iOS» (`interstitial`; Unity y Meta) y «Rewarded interstitial iOS» (`rewardedInterstitial`; sólo Meta). Unity trae los placements `BP_Rewarded_iOS` y `BP_Interstitial_iOS`; Meta, tres placements (interstitial, rewardedInterstitial, rewarded). Sin los grupos el binario trae los adaptadores pero AdMob no los llama.
- **App Privacy en App Store Connect (E10 T11):** declarar **«Data Used to Track You»** (identificador de publicidad y datos de publicidad, por Meta; la v1 ya lo declaraba), más la unión de lo que dicen Google y las dos redes. Se arma con *Generate Privacy Report* del archive (y revisar que traiga Unity y Meta; ver el doc de setup).
- **`app-ads.txt`** con las líneas de Unity (`Distribution/release/app-ads.unity.txt`) y Meta (`facebook.com, 4634477516796912, RESELLER, c3e20eee3f780d68`), según `release.json`.
- **El anuncio real con el SDK real** (pausa, botón de video, app open) y el **UMP en la UE** siguen sin verse en device (T3, T5).
- **Carries de E7b-a heredados** (tasks.md §5): el ×2 de la pausa se apila con otros ×2 (¿5 s fijos?), `canRequestAds` falta en el intersticial y el rewarded (UE), `isCalmMoment` sin unificar con `isSafeMomentForInterstitial`.
