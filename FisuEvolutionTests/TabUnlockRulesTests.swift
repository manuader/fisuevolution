import Testing
@testable import FisuEvolution

/// Qué pestañas tiene un jugador según lo que hizo (PLAN-v2 E3, la barra
/// progresiva). Pura: las señales llegan resueltas.
@Suite("Las reglas de desbloqueo de las pestañas")
@MainActor
struct TabUnlockRulesTests {
    private let config = TabsConfig(schemaVersion: 1, tabs: [
        .init(id: "upgrades", unlockWhen: [.always]),
        .init(id: "skins", unlockWhen: [.firstSkin]),
        .init(id: "jobs", unlockWhen: [.always]),
        .init(id: "gifts", unlockWhen: [.tutorialCore, .firstChest]),
        .init(id: "menu", unlockWhen: [.tutorialCore]),
    ])

    private func signals(core: Bool = false, skin: Bool = false, chest: Bool = false, sessions: Int = 0) -> TabUnlockSignals {
        TabUnlockSignals(tutorialCoreDone: core, ownsAnySkin: skin, hasReceivedChest: chest, sessionsAfterCore: sessions)
    }

    @Test("un jugador nuevo ve sólo Contratar y Mejoras")
    func newPlayerSeesHiringAndUpgrades() {
        #expect(TabUnlockRules.unlocked(config: config, signals: signals()) == [.jobs, .upgrades])
    }

    @Test("el núcleo del tutorial abre Bonus y Menú")
    func coreOpensGiftsAndMenu() {
        #expect(TabUnlockRules.unlocked(config: config, signals: signals(core: true)) == [.jobs, .upgrades, .gifts, .menu])
    }

    @Test("el primer cofre abre Bonus aunque el tutorial siga")
    func firstChestOpensGifts() {
        #expect(TabUnlockRules.unlocked(config: config, signals: signals(chest: true)).contains(.gifts))
    }

    @Test("la primera pinta abre Vestimenta")
    func firstSkinOpensSkins() {
        #expect(TabUnlockRules.unlocked(config: config, signals: signals(skin: true)).contains(.skins))
    }

    @Test("el tabs.json embarcado es válido y cubre las cinco pestañas de la barra")
    func bundledConfigIsValid() throws {
        let content = try GameContentLoader.load(from: .main)
        try content.tabs.validate()
        #expect(Set(content.tabs.tabs.compactMap(\.screen)) == Set(GameScreen.barOrder))
    }

    @Test("un tabs.json con la Tienda no es válido: ya no está en la barra")
    func storeInTabsIsInvalid() {
        let withStore = TabsConfig(schemaVersion: 1, tabs: GameScreen.allCases.map {
            .init(id: $0.rawValue, unlockWhen: [.always])
        })
        #expect(throws: GameError.self) { try withStore.validate() }
    }

    @Test("una config sin Contratar siempre abierto no valida")
    func hiringMustAlwaysBeOpen() {
        let broken = TabsConfig(schemaVersion: 1, tabs: GameScreen.barOrder.map {
            .init(id: $0.rawValue, unlockWhen: [.tutorialCore])
        })
        #expect(throws: GameError.self) { try broken.validate() }
    }
}
