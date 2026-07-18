import Foundation

/// What the spawn shop is currently offering: which type, at what price.
public struct SpawnQuote: Equatable, Sendable {
    public let type: CharacterType
    public let cost: Double
    public let purchases: Int
}

public enum SpawnError: Error, Equatable {
    case insufficientCoins
    case boardFull
    case noSpawnableType
}

public enum PassiveUnlockError: Error, Equatable {
    case unknownType
    case alreadyUnlocked
    case insufficientCoins
}

/// Player actions as pure mutations over `PlayerState` (bible §2.3 rules 1 and 4,
/// with the approved progressive-spawn extension). No UI, fully unit-tested.
extension StandardEconomy {
    /// Rule 1 — tap: `tapYield × tapMultiplier × globalMultiplier`, always available.
    /// Returns the gain so the scene can show feedback.
    public func applyTap(type: CharacterType, state: inout PlayerState) -> Double {
        let gain = type.tapYield * state.upgrades.tapMultiplier * state.globalMultiplier
        state.coins += gain
        state.lifetimeEarnings += gain
        return gain
    }

    /// Bible §2.3 rule 3 — buying a type's passive makes EVERY instance of that
    /// type on the board generate income. Per-type, independent purchases.
    public func applyPassiveUnlock(typeId: String, state: inout PlayerState, tiers: TierRepository) throws {
        guard let type = tiers.type(id: typeId) else { throw PassiveUnlockError.unknownType }
        guard state.passiveUnlocked[typeId] != true else { throw PassiveUnlockError.alreadyUnlocked }
        guard state.coins >= type.passiveUnlockCost else { throw PassiveUnlockError.insufficientCoins }
        state.coins -= type.passiveUnlockCost
        state.passiveUnlocked[typeId] = true
    }

    /// The type the progressive spawn currently offers. On career tiers (9/10) it
    /// respects the chosen path; without one it falls back to the first concrete
    /// type of that tier (only reachable in edge cases, e.g. imported saves).
    /// `costMultiplier` applies prestige spawn discounts (1.0 = none).
    public func spawnQuote(state: PlayerState, tiers: TierRepository, costMultiplier: Double = 1.0) -> SpawnQuote? {
        let tier = spawnTier(maxTierReached: state.maxTierReached)
        let candidates = tiers.concreteTypes.filter { $0.tier == tier }
        guard !candidates.isEmpty else { return nil }

        let type: CharacterType
        if candidates.count == 1 {
            type = candidates[0]
        } else if let career = state.chosenCareerPath,
                  let match = candidates.first(where: { $0.id.hasSuffix(career) }) {
            type = match
        } else {
            type = candidates[0]
        }

        let purchases: Int = switch config.spawn.costBasis {
        case .perType: state.spawnPurchases[type.id] ?? 0
        case .total: state.spawnPurchases.values.reduce(0, +)
        }
        return SpawnQuote(
            type: type,
            cost: spawnCost(spawnTier: tier, purchases: purchases) * costMultiplier,
            purchases: state.spawnPurchases[type.id] ?? 0
        )
    }

    /// Rule 4 — spawn: buys the quoted type, places it on the first free cell.
    @discardableResult
    public func applySpawn(
        quote: SpawnQuote,
        state: inout PlayerState,
        boardCapacity: Int
    ) throws -> BoardPlacement {
        guard state.coins >= quote.cost else { throw SpawnError.insufficientCoins }

        let occupied = Set(state.board.map(\.cellIndex))
        guard let freeCell = (0..<boardCapacity).first(where: { !occupied.contains($0) }) else {
            throw SpawnError.boardFull
        }

        state.coins -= quote.cost
        state.spawnPurchases[quote.type.id] = quote.purchases + 1
        let placement = BoardPlacement(cellIndex: freeCell, typeId: quote.type.id)
        state.board.append(placement)
        return placement
    }
}
