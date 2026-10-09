import SwiftUI

@main
struct FisuEvolutionApp: App {
    @State private var gameState = GameState()
    @State private var storeManager = StoreManager()
    @State private var gameCenter = GameCenterManager()
    @State private var haptics = HapticsManager()
    @State private var audio = AudioManager()
    /// Los avisos de la ausencia (E11). Construirlo no pide permiso: el provisional
    /// sale al cerrar el núcleo del tutorial y el completo, de la tarjeta del popup offline.
    @State private var notifications = NotificationsManager()
    /// Los anuncios. Se construye acá y NO en `RootView` porque elegir entre el
    /// stub y AdMob necesita los feature flags, que recién existen después de
    /// `bootstrap()`; el coordinador arranca con el stub adentro y se resuelve
    /// abajo, en el `.task`.
    @State private var ads = AdsCoordinator()
    @State private var servicesStarted = false
    /// El ascensor de E13b: la placa colgante y el viaje en cabina, encima de todo.
    @State private var elevatorRide = ElevatorRide()

    var body: some Scene {
        WindowGroup {
            RootView()
                .overlay { ElevatorRideOverlay() }
                .environment(elevatorRide)
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
                    gameState.attachBackgroundTasks(UIKitBackgroundTasks())
                    attachElevator()
                    await gameState.bootstrap()
                    await startServices()
                }
                .onChange(of: gameState.phase) { _, phase in
                    if phase == .ready {
                        Task { await startServices() }
                    }
                }
        }
    }

    private func attachElevator() {
        elevatorRide.attach(ElevatorRide.Hooks(
            visibleOrdinal: { [gameState] in gameState.visibleFloorOrdinal },
            isUnlocked: { [gameState] ordinal in
                gameState.floorMap.contains { $0.ordinal == ordinal && $0.isUnlocked }
            },
            jump: { [gameState] in gameState.jumpToFloor(ordinal: $0) },
            cue: { [audio] in audio.play($0) },
            sleep: { try? await Task.sleep(for: $0) },
            reduceMotion: { UIAccessibility.isReduceMotionEnabled },
            instant: ElevatorRide.isInstantForUITests,
            slowdown: ElevatorRide.uiTestSlowdown
        ))
    }

    /// La tienda, Game Center y los anuncios arrancan sólo con una partida
    /// cargada, y una sola vez: en recuperación no hay dónde acreditar nada, y la
    /// tienda finalizaría una compra consumible que nadie recibió.
    private func startServices() async {
        guard gameState.phase == .ready, !servicesStarted else { return }
        servicesStarted = true
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
        gameState.attachNotifications(notifications)
        await gameState.notificationsLaunched()
    }
}
