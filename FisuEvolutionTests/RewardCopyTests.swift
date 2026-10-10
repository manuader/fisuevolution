import EconomyKit
import Foundation
import Testing
import UIKit
@testable import FisuEvolution

@Suite("Cómo se dice un premio")
struct RewardCopyTests {
    /// Un ejemplo por tipo, con un `switch` SIN `default`: un tipo nuevo sin
    /// texto no compila (el mismo truco que `RewardSpecTests.sample` de E4a).
    static func sample(_ kind: RewardSpec.Kind) -> RewardSpec {
        switch kind {
        case .coinsSeconds: .coinsSeconds(1800)
        case .oro: .oro(3)
        case .package: .package(1)
        case .skinChest: .skinChest(2)
        case .modifier: .modifier(effect: .incomeMultiplier, magnitude: 3, seconds: 600)
        case .clearBoostCooldowns: .clearBoostCooldowns
        case .autoTap: .autoTap(perSecond: 5, seconds: 600)
        case .nextOfflineMultiplier: .nextOfflineMultiplier(3)
        case .nextDailyMultiplier: .nextDailyMultiplier(3)
        case .wheelSpin: .wheelSpin(2)
        case .extraSlots: .extraSlots(3)
        case .eventImmunity: .eventImmunity(seconds: 1800)
        }
    }

    @Test("todo premio tiene título e ícono, y ninguna clave cruda", arguments: RewardSpec.Kind.allCases)
    func everyKindHasCopy(kind: RewardSpec.Kind) {
        let reward = Self.sample(kind)
        let title = RewardCopy.title(reward)
        #expect(!title.isEmpty)
        #expect(!title.contains("reward."), "\(kind): «\(title)» es la clave cruda")
        #expect(!title.contains("%"), "\(kind): «\(title)» quedó sin interpolar")
        #expect(UIImage(systemName: RewardCopy.symbol(reward)) != nil, "\(kind): el ícono no existe")
    }

    @Test("los minutos y los números salen del dato")
    func numbersComeFromTheData() {
        #expect(RewardCopy.title(.coinsSeconds(1800)).contains("30"))
        #expect(RewardCopy.title(.oro(3)).contains("3"))
        #expect(RewardCopy.slice(.coinsSeconds(2700)) == "45 min")
        #expect(RewardCopy.slice(.modifier(effect: .incomeMultiplier, magnitude: 3, seconds: 600)) == "×3")
        #expect(RewardCopy.slice(.oro(3)) == "3")
        #expect(RewardCopy.slice(.package(1)) == nil, "el paquete se dice con el ícono")
    }

    @Test("los porcentajes no inventan decimales")
    func percents() {
        #expect(OddsDisclosureView.percent(0.18).contains("18"))
        #expect(!OddsDisclosureView.percent(0.18).contains("18,0") && !OddsDisclosureView.percent(0.18).contains("18.0"))
    }
}
