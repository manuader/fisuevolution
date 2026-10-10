import EconomyKit
import Foundation

/// Cómo se dice un premio (`RewardSpec`) en pantalla: la ruleta, el colchón y,
/// después, la tienda y las ofertas (E6). Los números se interpolan del dato,
/// nunca se escriben en el texto (la regla de `IAPCopy`, HANDOFF §5): el valor
/// del catálogo lleva `%1$@` y esto lo llena.
enum RewardCopy {
    /// Lo que se lee en una fila de probabilidades o en un resultado.
    static func title(_ reward: RewardSpec) -> String {
        switch reward {
        case .coinsSeconds(let seconds):
            text("reward.title.coins", minutes(seconds))
        case let .modifier(effect, magnitude, seconds):
            text(effect == .incomeMultiplier ? "reward.title.income" : "reward.title.modifier",
                 multiplier(magnitude), minutes(seconds))
        case .oro(let amount):
            text("reward.title.oro", String(amount))
        case .package(let count):
            count == 1 ? text("reward.title.package") : text("reward.title.packages", String(count))
        case .skinChest(let count):
            count == 1 ? text("reward.title.chest") : text("reward.title.chests", String(count))
        case .wheelSpin(let count):
            count == 1 ? text("reward.title.spin") : text("reward.title.spins", String(count))
        case .clearBoostCooldowns:
            text("reward.title.cooldowns")
        case .eventImmunity(let seconds):
            text("reward.title.immunity", minutes(seconds))
        case let .autoTap(_, seconds):
            text("reward.title.autotap", minutes(seconds))
        case .nextOfflineMultiplier(let value):
            text("reward.title.next_offline", multiplier(value))
        case .nextDailyMultiplier(let value):
            text("reward.title.next_daily", multiplier(value))
        case .extraSlots(let count):
            text("reward.title.slots", String(count))
        }
    }

    /// Lo que entra en una rebanada de la ruleta, al lado del ícono. `nil`:
    /// el ícono solo alcanza.
    static func slice(_ reward: RewardSpec) -> String? {
        switch reward {
        case .coinsSeconds(let seconds): "\(minutes(seconds)) min"
        case let .modifier(_, magnitude, _): "×\(multiplier(magnitude))"
        case .oro(let amount): String(amount)
        case .package, .skinChest, .wheelSpin, .clearBoostCooldowns, .eventImmunity, .autoTap,
             .nextOfflineMultiplier, .nextDailyMultiplier, .extraSlots: nil
        }
    }

    /// El ícono (SF Symbols) de cada tipo.
    static func symbol(_ reward: RewardSpec) -> String {
        switch reward {
        case .coinsSeconds: "dollarsign.circle.fill"
        case .modifier: "chart.line.uptrend.xyaxis"
        case .oro: "seal.fill"
        case .package: "shippingbox.fill"
        case .skinChest: "gift.fill"
        case .wheelSpin: "arrow.clockwise.circle.fill"
        case .clearBoostCooldowns: "bolt.fill"
        case .eventImmunity: "cross.case.fill"
        case .autoTap: "hand.tap.fill"
        case .nextOfflineMultiplier: "moon.zzz.fill"
        case .nextDailyMultiplier: "calendar"
        case .extraSlots: "square.grid.3x3.fill"
        }
    }

    /// Una clave del catálogo con sus `%1$@`, `%2$@` llenos.
    static func text(_ key: String, _ arguments: String...) -> String {
        let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        return arguments.isEmpty ? format : String(format: format, arguments: arguments)
    }

    private static func minutes(_ seconds: Double) -> String {
        (seconds / 60).formatted(.number.precision(.fractionLength(0...1)))
    }

    private static func multiplier(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
