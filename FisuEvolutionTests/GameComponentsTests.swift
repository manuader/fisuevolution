import EconomyKit
import Foundation
import SwiftUI
import Testing
@testable import FisuEvolution

/// El contrato de los componentes base de E14 (T9): lo que las pantallas de
/// T11–T25 van a dar por sentado. Las vistas no se assertan sin renderizar,
/// pero sí sus medidas, sus mapas y sus órdenes.
@Suite("Componentes base de E14")
@MainActor
struct GameComponentsTests {

    // MARK: - GameButton (C19)

    @Test("cada función tiene su color y no se repiten")
    func rolesHaveDistinctColors() {
        let fills = GameButton.Role.allCases.map { UIColor($0.fill) }
        for (index, fill) in fills.enumerated() {
            for other in fills[(index + 1)...] {
                #expect(fill != other)
            }
        }
    }

    @Test("el medallón por defecto sale de la función, y se puede pisar o sacar")
    func medallionDefaultsFollowTheRole() {
        #expect(GameButton.Role.free.defaultMedallion == .check)
        #expect(GameButton.Role.coins.defaultMedallion == .coin)
        #expect(GameButton.Role.blue.defaultMedallion == .blue)
        #expect(GameButton.Role.video.defaultMedallion == .video)
        #expect(GameButton.Role.neutral.defaultMedallion == nil)

        let custom = GameButton(verbatim: "x", role: .free, medallion: .glyph(.package), identifier: "t") {}
        #expect(custom.medallionGlyph == .package)
        let bare = GameButton(verbatim: "x", role: .video, medallion: .none, identifier: "t") {}
        #expect(bare.medallionGlyph == nil)
    }

    @Test("ningún tamaño de botón baja de 44 pt (D14)")
    func buttonsAreTappable() {
        #expect(GameButton.Size.regular.minHeight >= 44)
        #expect(GameButton.Size.compact.minHeight >= 44)
    }

    // MARK: - GameGlyph (C19)

    @Test("los íconos generales piden primero la clave nueva de E14")
    func glyphsChainTheNewKeysFirst() {
        #expect(GameGlyph.video.artKeys.first == "ui_icon_video")
        #expect(GameGlyph.clock.artKeys.first == "ui_icon_clock")
        #expect(GameGlyph.lock.artKeys.first == "ui_icon_lock")
        #expect(GameGlyph.check.artKeys.first == "ui_icon_check")
        #expect(GameGlyph.blue.artKeys == ["ui_dolar_blue", "ui_oro"])
        #expect(GameGlyph.offerMoving.artKeys.first == "ui_offer_mudanza")
        #expect(GameGlyph.offerWelcome.artKeys.first == "ui_offer_bienvenida")
        #expect(GameGlyph.offerRebirth.artKeys.first == "ui_offer_renacer")
    }

    @Test("sin la clave nueva, el glifo cae a la hermana integrada")
    func glyphFallsBackToAnIntegratedSibling() {
        let integrated = UIArt.bundledNames()
        if !integrated.contains("ui_dolar_blue"), integrated.contains("ui_oro") {
            #expect(GameGlyph.blue.resolvedArtKey == "ui_oro")
        }
        #expect(GameGlyph.art("clave_que_no_existe").resolvedArtKey == nil)
    }

    // MARK: - RewardIllustration (C4)

    @Test("el mapa de C4: cada efecto de los JSON va a su imagen")
    func effectNamesFollowTheC4Table() {
        let table: [String: RewardKind] = [
            "coinsSeconds": .coins, "incomeMultiplier": .incomeBoost, "passiveMultiplier": .incomeBoost,
            "tapMultiplier": .tapBoost, "spawnCostMultiplier": .hireDiscount,
            "clearBoostCooldowns": .boostRefresh, "evolveBestUnit": .evolve, "grantUnit": .freeUnit,
            "exchange": .exchange, "fine": .fine, "fee": .fine, "take": .fine, "arrest": .arrest,
            "spendingFrozen": .frozen, "oro": .blue, "package": .package,
            "packageRateMultiplier": .packageRain, "skinChest": .chest, "wheelSpin": .wheelSpin,
            "gift": .gift
        ]
        for (name, kind) in table {
            #expect(RewardKind(effectName: name) == kind, "\(name)")
        }
        for silent in ["modifier", "gossip", "callVisitor", "video"] {
            #expect(RewardKind(effectName: silent) == nil, "\(silent)")
        }
    }

    @Test("las claves nuevas de C4 encabezan la cadena de su premio")
    func rewardKindsChainTheC4Keys() {
        let expected: [RewardKind: String] = [
            .coins: "rw_coins", .incomeBoost: "rw_income_mult", .tapBoost: "rw_tap_mult",
            .hireDiscount: "rw_hire_discount", .boostRefresh: "rw_boost_refresh", .evolve: "rw_evolve",
            .freeUnit: "rw_free_unit", .exchange: "rw_exchange", .fine: "rw_fine", .arrest: "rw_arrest",
            .frozen: "rw_frozen", .blue: "ui_dolar_blue", .package: "rw_package_employee",
            .packageRain: "ui_oro_package_rain", .chest: "ui_chest_closed", .wheelSpin: "wheel_icon",
            .gift: "ui_gift_bow", .mystery: "rw_mystery_all", .mattressTreasure: "rw_mattress_treasure"
        ]
        #expect(Set(expected.keys) == Set(RewardKind.allCases))
        for (kind, key) in expected {
            #expect(kind.artKeys.first == key, "\(kind)")
        }
    }

    @Test("el vocabulario de premios de la 2.0 se ilustra; lo que no da nada, no")
    func rewardSpecsMapToKinds() {
        #expect(RewardKind(RewardSpec.coinsSeconds(900)) == .coins)
        #expect(RewardKind(RewardSpec.oro(5)) == .blue)
        #expect(RewardKind(RewardSpec.package(1)) == .package)
        #expect(RewardKind(RewardSpec.skinChest(1)) == .chest)
        #expect(RewardKind(RewardSpec.clearBoostCooldowns) == .boostRefresh)
        #expect(RewardKind(RewardSpec.wheelSpin(1)) == .wheelSpin)
        #expect(RewardKind(RewardSpec.modifier(effect: .tapMultiplier, magnitude: 2, seconds: 60)) == .tapBoost)
        #expect(RewardKind(RewardSpec.modifier(effect: .eventImmunity, magnitude: 1, seconds: 60)) == nil)
        #expect(RewardKind(RewardSpec.extraSlots(1)) == nil)
        #expect(RewardKind(event: .evolveBestUnit) == .evolve)
        #expect(RewardKind(event: .grantUnit(tiersBelowFrontier: 2)) == .freeUnit)
        #expect(RewardKind(event: .callVisitor(script: "x")) == nil)
        #expect(RewardKind(event: .openShop(destination: .store, focus: nil)) == nil)
        #expect(RewardKind(modifier: .spendingFrozen) == .frozen)
        #expect(RewardKind(modifier: .packageRateMultiplier) == .packageRain)
    }

    @Test("todo modificador tiene una decisión de imagen explícita")
    func everyModifierIsDecided() {
        let silent: Set<ActiveModifier.Effect> = [.eventImmunity, .eventPresence]
        for effect in ActiveModifier.Effect.allCases {
            #expect((RewardKind(modifier: effect) == nil) == silent.contains(effect), "\(effect)")
        }
    }

    @Test("lo negativo no lleva rayos; el marco incluye los rayos")
    func raysCelebrateOnlyGoodNews() {
        #expect(!RewardKind.fine.celebrates)
        #expect(!RewardKind.arrest.celebrates)
        #expect(!RewardKind.frozen.celebrates)
        #expect(RewardKind.coins.celebrates)
        #expect(RewardIllustration.frameSide(for: 120) > 120)
    }

    // MARK: - Estados (C29)

    @Test("el orden por estado es listo › en curso › bloqueado › hecho, estable")
    func progressOrdering() {
        let rows: [(String, ProgressState)] = [
            ("a", .done), ("b", .locked), ("c", .ready), ("d", .running), ("e", .ready), ("f", .locked)
        ]
        let sorted = rows.sortedByProgress { $0.1 }.map(\.0)
        #expect(sorted == ["c", "e", "d", "b", "f", "a"])
    }

    @Test("cada estado lleva su ícono custom; el listo, el «!»")
    func stateGlyphs() {
        #expect(ProgressState.ready.glyph == nil)
        #expect(ProgressState.running.glyph == .clock)
        #expect(ProgressState.locked.glyph == .lock)
        #expect(ProgressState.done.glyph == .check)
    }

    // MARK: - CornerSeal

    @Test("el sello se toca cómodo aunque se dibuje chico")
    func sealHitArea() {
        #expect(CornerSeal.hitSide(for: 30) == 44)
        #expect(CornerSeal.hitSide(for: CornerSeal.defaultSide) == CornerSeal.defaultSide)
        #expect(CornerSeal.Caption.timer("12:04").glyph == .clock)
        #expect(CornerSeal.Caption.text("×3").glyph == nil)
    }

    // MARK: - PopupContainer (C15)

    @Test("la tarjeta no pasa la zona segura menos el margen, en el SE ni en el iPad")
    func popupFitsTheSafeArea() {
        // SE: 375 × 647 de zona segura.
        #expect(PopupMetrics.cardWidth(available: 375) == 343)
        #expect(PopupMetrics.maxCardHeight(available: 647) == 615)
        // iPad: el ancho se topa.
        #expect(PopupMetrics.cardWidth(available: 1024) == PopupMetrics.maxCardWidth)
        // Nunca negativo.
        #expect(PopupMetrics.cardWidth(available: 10) == 0)
        #expect(PopupMetrics.maxCardHeight(available: 10) == 0)
        #expect(PopupMetrics.closeSide >= 44)
    }

    @Test("dos botones van lado a lado; tres o más, apilados")
    func popupActionsLayout() {
        #expect(!PopupMetrics.stacksActions(count: 1))
        #expect(!PopupMetrics.stacksActions(count: 2))
        #expect(PopupMetrics.stacksActions(count: 3))
    }

    // MARK: - Cero SF Symbols (C19)

    @Test("los componentes de E14 no usan SF Symbols")
    func componentsUseNoSystemSymbols() throws {
        let art = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "FisuEvolution/UI/Art")
        let files = ["GameGlyph.swift", "GameButton.swift", "PopupContainer.swift", "RewardIllustration.swift",
                     "ProgressState.swift", "CornerSeal.swift"]
        for file in files {
            let code = try String(contentsOf: art.appending(path: file), encoding: .utf8)
            #expect(!code.contains("systemName:"), "\(file)")
            #expect(!code.contains("systemImage:"), "\(file)")
        }
    }
}
