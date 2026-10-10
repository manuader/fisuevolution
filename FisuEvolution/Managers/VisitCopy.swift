import EconomyKit
import Foundation

/// Los textos de los visitantes y cómo se llenan (PLAN-v2 E4, Anexo A).
///
/// Las claves van por convención y **los números salen del dato**: el valor del
/// catálogo lleva `%1$@`, `%2$@`… y acá se llenan con `String(format:)`, como
/// `IAPCopy`. Un "30 % off" escrito a mano se quedaría viejo en silencio el día
/// que el dato cambie.
enum VisitCopy {
    /// Lo que dice un visitante fuera de su guion: al cerrar el trato, al
    /// quedarse sin él y en los retos. `LocalizationCompletenessTests` las pide.
    static let lineKeys = [
        "visit.wrong_office", "visit.deal_off", "visit.thanks", "visit.gossip.next", "visit.gossip.none",
        "visit.challenge.won", "visit.challenge.double", "visit.challenge.lost",
    ]

    static func optionKey(_ kind: VisitOption.Kind) -> String {
        switch kind {
        case .accept: "visit.option.accept"
        case .acceptWithVideo: "visit.option.accept_video"
        case .payBail: "visit.option.pay_bail"
        case .release: "visit.option.release"
        case .payFine: "visit.option.pay_fine"
        case .forgiveWithVideo: "visit.option.forgive_video"
        case .sell: "visit.option.sell"
        case .exchange: "visit.option.exchange"
        case .startChallenge: "visit.option.start_challenge"
        case .card: "visit.option.card"
        case .listen: "visit.option.listen"
        }
    }

    /// El motivo absurdo del arresto, por el piso del arrestado.
    static func reasonKey(floorID: String) -> String { "visit.reason.\(floorID)" }

    static func name(of visitor: VisitorsConfig.Visitor, bundle: Bundle = .main) -> String {
        text(visitor.nameKey, bundle: bundle)
    }

    static func bubble(for script: VisitorsConfig.Script, offer: VisitOffer, content: GameContent, bundle: Bundle = .main) -> String {
        text(script.bubbleKey, arguments(for: script, offer: offer, content: content), bundle: bundle)
    }

    static func ask(for script: VisitorsConfig.Script, offer: VisitOffer, content: GameContent, bundle: Bundle = .main) -> String {
        text(script.askKey, arguments(for: script, offer: offer, content: content), bundle: bundle)
    }

    static func optionTitle(_ option: VisitOption, script: VisitorsConfig.Script, content: GameContent, bundle: Bundle = .main) -> String {
        let amount = CoinFormatter.string(from: abs(option.coins))
        switch option.kind {
        case .payBail, .release, .payFine, .sell:
            return text(optionKey(option.kind), [amount], bundle: bundle)
        case .exchange:
            let oro = option.rewards.reduce(0) { total, reward in
                if case .oro(let amount) = reward { return total + amount }
                return total
            }
            return text(optionKey(.exchange), [amount, String(oro)], bundle: bundle)
        case .card:
            guard case .vendor(let cards) = script.mechanic,
                  let card = cards.first(where: { "card.\($0.id)" == option.id })
            else { return text(optionKey(.card), [""], bundle: bundle) }
            return text(optionKey(.card), [text(card.nameKey, bundle: bundle)], bundle: bundle)
        case .accept, .acceptWithVideo, .forgiveWithVideo, .startChallenge, .listen:
            return text(optionKey(option.kind), bundle: bundle)
        }
    }

    /// Lo que llena el globo y el popup de un guion, en orden: el empleado y su
    /// motivo; el efecto y su duración; los toques y los segundos del reto; el
    /// tope del cambio.
    static func arguments(for script: VisitorsConfig.Script, offer: VisitOffer, content: GameContent) -> [String] {
        switch script.mechanic {
        case .arrest, .sale, .take:
            guard let typeId = offer.subjectTypeId, let type = content.tiers.type(id: typeId) else { return [] }
            let floor = content.floorTable.floor(forTier: type.tier)
            return [type.localizedName, text(reasonKey(floorID: floor.id))]
        case .gift(let rewards, _):
            return modifierArguments(rewards)
        case .fine(_, _, let stamp):
            return modifierArguments([stamp])
        case .exchange(_, _, let dailyOroCap):
            return dailyOroCap.map { [String($0)] } ?? []
        case let .challenge(taps, windowSeconds, rewards, _):
            return [String(taps), String(Int(windowSeconds))] + modifierArguments(rewards)
        case .vendor, .gossip:
            return []
        }
    }

    /// Cuántos datos le llegan a los textos de un guion (lo pinea
    /// `VisitorsContentTests`: un `%3$@` sin dato sería basura en pantalla).
    static func argumentCount(for script: VisitorsConfig.Script) -> Int {
        func modifiers(_ rewards: [RewardSpec]) -> Int {
            rewards.contains { if case .modifier = $0 { return true }; return false } ? 2 : 0
        }
        switch script.mechanic {
        case .arrest, .sale, .take: return 2
        case .gift(let rewards, _): return modifiers(rewards)
        case .fine: return 2
        case .exchange(_, _, let dailyOroCap): return dailyOroCap == nil ? 0 : 1
        case .challenge(_, _, let rewards, _): return 2 + modifiers(rewards)
        case .vendor, .gossip: return 0
        }
    }

    /// "×2", "−30%": el mismo número que el chip y el menú de Bonus.
    static func effectText(_ effect: ActiveModifier.Effect, magnitude: Double) -> String {
        let boostEffect: BoostsConfig.EffectType = switch effect {
        case .tapMultiplier: .tapMultiplier
        case .spawnCostMultiplier: .spawnCostMultiplier
        default: .incomeMultiplier
        }
        return EffectFormatter.text(EffectDescriptor.amount(forBoost: boostEffect, magnitude: magnitude))
    }

    /// "10 min" o "45 s", con las mismas claves que los videos de Regalos.
    static func durationText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total >= 60, total % 60 == 0 {
            return String(localized: "ads.duration.min \(String(total / 60))")
        }
        return String(localized: "ads.duration.sec \(String(total))")
    }

    private static func modifierArguments(_ rewards: [RewardSpec]) -> [String] {
        for reward in rewards {
            if case let .modifier(effect, magnitude, seconds) = reward {
                return [effectText(effect, magnitude: magnitude), durationText(seconds)]
            }
        }
        return []
    }

    /// Un valor que ninguna traducción va a tener: `localizedString` devuelve el
    /// `value` cuando no encuentra la clave.
    private static let missing = "<visit.missing>"

    static func text(_ key: String, _ arguments: [String] = [], bundle: Bundle = .main) -> String {
        let format = bundle.localizedString(forKey: key, value: missing, table: nil)
        guard format != missing else { return key }
        // Sin datos no se formatea: `String(format:)` sobre un texto con un `%`
        // suelto se comería el carácter de al lado.
        guard !arguments.isEmpty else { return format }
        return String(format: format, arguments: arguments.map { $0 as CVarArg })
    }
}
