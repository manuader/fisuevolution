import SwiftUI

@main
struct FisuEvolutionApp: App {
    @State private var gameState = GameState()
    @State private var storeManager = StoreManager()
    @State private var gameCenter = GameCenterManager()
    @State private var haptics = HapticsManager()
    @State private var audio = AudioManager()
    /// El recordatorio diario de Ajustes (T16). No pide permiso al arrancar —lo
    /// pide el toggle— así que construirlo acá no le muestra un diálogo a nadie.
    @State private var notifications = NotificationsManager()
    /// Los anuncios. Se construye acá y NO en `RootView` porque elegir entre el
    /// stub y AdMob necesita los feature flags, que recién existen después de
    /// `bootstrap()`; el coordinador arranca con el stub adentro y se resuelve
    /// abajo, en el `.task`.
    @State private var ads = AdsCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(gameState)
                .environment(storeManager)
                .environment(gameCenter)
                .environment(haptics)
                .environment(audio)
                .environment(notifications)
                .environment(ads)
                .task {
                    haptics.prepare()
                    audio.prepare()
                    // El audio se carga en paralelo con el bootstrap en vez de
                    // demorarlo: la lectura de los `.caf` corre fuera de main y
                    // deja los diez SFX listos antes de que el jugador pueda
                    // dispararlos.
                    Task {
                        await audio.startMusic()
                        await audio.preloadSFX()
                    }
                    gameState.attachHaptics(haptics)
                    gameState.attachAudio(audio)
                    await gameState.bootstrap()
                    await storeManager.start(gameState: gameState)
                    if let content = gameState.content {
                        gameState.attachGameCenter(gameCenter)
                        gameCenter.start(content: content)
                    }
                    // Los anuncios van DESPUÉS de `storeManager.start`, y el
                    // orden es lo que hace que `remove_ads` se respete desde el
                    // primer segundo: es ese start el que sincroniza los
                    // entitlements de StoreKit y escribe `meta.removedAds`.
                    // Configurar antes dejaría al comprador viendo un
                    // interstitial hasta el próximo arranque.
                    gameState.attachAds(ads)
                    if let content = gameState.content {
                        await ads.configure(
                            flags: content.flags,
                            cadence: content.rewardedAds.effectiveInterstitial,
                            removedAds: gameState.player?.meta.removedAds ?? false
                        )
                    }
                }
        }
    }
}
