import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los eventos que llevan a una tienda (E14 C25), contra la partida real.
@Suite("Eventos de compra en la partida")
@MainActor
struct ShopEventsRuntimeTests {
    /// Una partida veterana: tutorial cumplido, ya jugó un rato, la sesión lleva más de tres minutos y
    /// ya abrió Mejoras.
    private func seasoned() async throws -> GameState {
        let gameState = await makeGameState()
        gameState.flagDefaults = .isolatedForTest()
        TutorialFlags.setCoreCompleted(true, in: gameState.flagDefaults)
        gameState.engagementAutorun = true
        gameState.debugUnlockFloors(throughTier: 12)
        gameState.player?.meta.engagement.events.clock = 7200
        gameState.stageRuntime.sessionStartClock = 7200 - 600
        gameState.unlockedTabs.insert(.upgrades)
        return gameState
    }

    private func event(_ id: String, in gameState: GameState) throws -> EventCatalog.Event {
        try #require(gameState.content?.events.event(id: id))
    }

    private let shopIds = ["cyber_monday", "llego_el_blue", "mudanza_oficinas", "cuevita_abierta"]

    @Test("los cuatro del dato: positivos, instantáneos, de peso bajo, cada uno con su destino y su foco")
    func theFourInTheData() async throws {
        let gameState = await makeGameState()
        let offers = try shopIds.map { try #require(event($0, in: gameState).shopOffer) }
        #expect(offers == [
            .init(destination: .store, focus: "com.fisuevolution.iap.starter_pack"),
            .init(destination: .boosts, focus: "income_x2"),
            .init(destination: .permanent, focus: "extra_slots"),
            .init(destination: .store, focus: "com.fisuevolution.iap.oro_medium"),
        ])
        for id in shopIds {
            let event = try event(id, in: gameState)
            #expect(event.polarity == .positive && event.durationSeconds == 0 && event.weight <= 3 && event.minTier >= 4, "\(id)")
            #expect(event.cooldownSeconds >= gameState.content!.events.shopPolicy.minSeparationSeconds, "\(id)")
        }
        #expect(try event("cuevita_abierta", in: gameState).presenters.first == "sp_arbolito")
    }

    @Test("sus textos y los botones del popup existen en el catálogo")
    func copyExists() async throws {
        let gameState = await makeGameState()
        for id in shopIds {
            let event = try event(id, in: gameState)
            #expect(String(localized: String.LocalizationValue(event.titleKey)) != event.titleKey, "\(id)")
            #expect(String(localized: String.LocalizationValue(event.phraseKey)) != event.phraseKey, "\(id)")
        }
        #expect(String(localized: "event.shop.go") != "event.shop.go")
        #expect(String(localized: "event.shop.later") != "event.shop.later")
    }

    @Test("sin sesión, sin tutorial o en el arranque, no entran al sorteo")
    func gatedAtStartup() async throws {
        let gameState = try await seasoned()
        let boost = try event("llego_el_blue", in: gameState)
        #expect(gameState.eventIsRollable(boost), "la partida de control: sí entra")

        gameState.stageRuntime.sessionStartClock = 7200 - 60
        #expect(!gameState.eventIsRollable(boost), "el arranque")
        gameState.stageRuntime.sessionStartClock = 7200 - 600

        gameState.player?.meta.engagement.events.clock = 600
        gameState.stageRuntime.sessionStartClock = 0
        #expect(!gameState.eventIsRollable(boost), "la primera sesión")
        gameState.player?.meta.engagement.events.clock = 7200
        gameState.stageRuntime.sessionStartClock = 7200 - 600

        TutorialFlags.setCoreCompleted(false, in: gameState.flagDefaults)
        #expect(!gameState.eventIsRollable(boost), "el tutorial")
    }

    @Test("con una celebración en curso no entran al sorteo")
    func gatedDuringCelebration() async throws {
        let gameState = try await seasoned()
        let boost = try event("llego_el_blue", in: gameState)
        gameState.tutorialPhaseActive = true
        #expect(!gameState.eventIsRollable(boost))
    }

    @Test("tope de 1 por sesión: salido el primero, ninguno más hasta la sesión siguiente")
    func oncePerSession() async throws {
        let gameState = try await seasoned()
        let boost = try event("llego_el_blue", in: gameState)
        let store = try event("cyber_monday", in: gameState)
        #expect(gameState.eventIsRollable(boost) && gameState.eventIsRollable(store))
        gameState.stageRuntime.shopEventsThisSession = 1
        #expect(!gameState.eventIsRollable(boost) && !gameState.eventIsRollable(store))
    }

    @Test("separación de 4 h de juego: sale el primero y el resto espera")
    func minimumSeparation() async throws {
        let gameState = try await seasoned()
        let boost = try event("llego_el_blue", in: gameState)
        gameState.player?.meta.engagement.events.lastShopEventAt = 7200 - 3600
        #expect(!gameState.eventIsRollable(boost))
        gameState.player?.meta.engagement.events.lastShopEventAt = 7200 - 4 * 3600
        #expect(gameState.eventIsRollable(boost))
    }

    @Test("una compra con plata real silencia el de la Tienda 24 h; el de Mejoras sigue")
    func recentPurchase() async throws {
        let gameState = try await seasoned()
        let store = try event("cyber_monday", in: gameState)
        let boost = try event("llego_el_blue", in: gameState)
        gameState.noteRealPurchase(at: Date().addingTimeInterval(-3600))
        #expect(!gameState.eventIsRollable(store))
        #expect(gameState.eventIsRollable(boost))
        gameState.noteRealPurchase(at: Date().addingTimeInterval(-25 * 3600))
        #expect(gameState.eventIsRollable(store))
    }

    @Test("sin Mejoras abiertas, los de blue no aplican; el de la Tienda sí")
    func destinationMustExist() async throws {
        let gameState = try await seasoned()
        gameState.unlockedTabs.remove(.upgrades)
        #expect(!gameState.eventIsApplicable(try event("llego_el_blue", in: gameState)))
        #expect(!gameState.eventIsApplicable(try event("mudanza_oficinas", in: gameState)))
        #expect(gameState.eventIsApplicable(try event("cyber_monday", in: gameState)))
    }

    @Test("empezar un evento de compra no mueve plata, tablero ni modificadores; deja la oferta esperando")
    func startingTouchesNothing() async throws {
        let gameState = try await seasoned()
        let before = try #require(gameState.player)
        gameState.startEvent(try event("cyber_monday", in: gameState), now: Date().timeIntervalSince1970)
        let after = try #require(gameState.player)
        #expect(after.run.coins == before.run.coins)
        #expect(after.run.units == before.run.units)
        #expect(after.meta.blue == before.meta.blue)
        #expect(after.run.activeModifiers.isEmpty)
        #expect(gameState.pendingBoardChanges.isEmpty)
        #expect(gameState.stageRuntime.pendingShopOffer == "cyber_monday")
        #expect(gameState.activeBonuses.isEmpty, "sin chip y sin cuenta regresiva")
    }

    @Test("«¡Vamos!» pide la pantalla con el ítem en foco, y la pantalla lo toma una sola vez")
    func acceptRequestsTheScreen() async throws {
        let gameState = try await seasoned()
        gameState.startEvent(try event("llego_el_blue", in: gameState), now: Date().timeIntervalSince1970)
        gameState.eventPopup = EventPopup(eventId: "llego_el_blue")
        gameState.acceptShopOffer(eventId: "llego_el_blue")
        #expect(gameState.eventPopup == nil)
        #expect(gameState.stageRuntime.pendingShopOffer == nil)
        #expect(gameState.shopRequest == ShopRequest(destination: .boosts, focus: "income_x2"))
        #expect(gameState.takeShopRequest(for: .store) == nil, "otra pantalla no lo toma")
        #expect(gameState.takeShopRequest(for: .upgrades)?.focus == "income_x2")
        #expect(gameState.takeShopRequest(for: .upgrades) == nil)
    }

    @Test("la Tienda y Mejoras: cada destino cae en su pantalla")
    func destinationsMapToScreens() {
        #expect(ShopRequest(destination: .store, focus: nil).screen == .store)
        #expect(ShopRequest(destination: .boosts, focus: nil).screen == .upgrades)
        #expect(ShopRequest(destination: .permanent, focus: nil).screen == .upgrades)
    }

    @Test("«Ahora no» cierra la oferta y no pide nada")
    func declineAsksForNothing() async throws {
        let gameState = try await seasoned()
        gameState.startEvent(try event("cyber_monday", in: gameState), now: Date().timeIntervalSince1970)
        gameState.eventPopup = EventPopup(eventId: "cyber_monday")
        gameState.declineShopOffer(eventId: "cyber_monday")
        #expect(gameState.eventPopup == nil)
        #expect(gameState.shopRequest == nil)
        #expect(gameState.stageRuntime.pendingShopOffer == nil)
    }

    @Test("la oferta vive lo que dura su presentador en escena")
    func offerLivesWithItsPresenter() async throws {
        let gameState = try await seasoned()
        let cyber = try event("cyber_monday", in: gameState)
        gameState.startEvent(cyber, now: Date().timeIntervalSince1970)
        #expect(!gameState.isEventRunning(id: "cyber_monday"), "sin nadie en escena no hay oferta")
        gameState.stageVisit = StageVisit(
            id: UUID(), actorId: "npc_vendedor", role: .presenter(eventId: "cyber_monday"),
            phase: .waiting, bubble: nil, offer: nil
        )
        #expect(gameState.isEventRunning(id: "cyber_monday"))
        gameState.stageVisit?.phase = .leaving
        #expect(!gameState.isEventRunning(id: "cyber_monday"))
    }

    @Test("el popup ilustra cada evento con lo que promociona")
    func illustrationFollowsTheOffer() {
        func kind(_ destination: EventCatalog.ShopDestination, _ focus: String?) -> RewardKind {
            EventPopupView.shopIllustrationKind(for: .init(destination: destination, focus: focus))
        }
        #expect(kind(.store, "com.fisuevolution.iap.starter_pack") == .coins)
        #expect(kind(.store, "com.fisuevolution.iap.oro_medium") == .blue)
        #expect(kind(.boosts, "income_x2") == .incomeBoost)
        #expect(kind(.permanent, "extra_slots") == .freeUnit)
    }
}
