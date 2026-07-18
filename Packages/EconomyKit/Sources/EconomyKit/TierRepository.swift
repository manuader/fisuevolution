import Foundation

/// Problems found while validating `tiers.json`. Content is data, so the game
/// fails fast (in Debug) with a precise reason instead of misbehaving silently.
public enum TierValidationError: Error, Equatable, CustomStringConvertible {
    case empty
    case duplicateId(String)
    case missingTier(Int)
    case noBaseTier
    case unresolvedMergeTarget(from: String, target: String)
    case nonConsecutiveMerge(from: String, target: String)
    case malformedChoiceNode(String)
    case unresolvedChoiceOption(node: String, option: String)
    case choiceOptionWrongTier(node: String, option: String)
    case wrongTerminalCount([String])
    case unreachableTerminal(from: String)

    public var description: String {
        switch self {
        case .empty: "tiers.json has no entries"
        case .duplicateId(let id): "duplicate type id '\(id)'"
        case .missingTier(let tier): "no entry for tier \(tier)"
        case .noBaseTier: "no concrete tier-1 type to start the game with"
        case .unresolvedMergeTarget(let from, let target): "'\(from)' merges into unknown '\(target)'"
        case .nonConsecutiveMerge(let from, let target): "'\(from)' merges into '\(target)' but tiers are not consecutive"
        case .malformedChoiceNode(let id): "choice node '\(id)' is malformed (choiceOptions must be non-empty exactly when isChoiceNode)"
        case .unresolvedChoiceOption(let node, let option): "choice node '\(node)' references unknown option '\(option)'"
        case .choiceOptionWrongTier(let node, let option): "choice option '\(option)' of '\(node)' is not on the node's tier"
        case .wrongTerminalCount(let ids): "expected exactly one terminal type, found: \(ids)"
        case .unreachableTerminal(let from): "merge chain starting at '\(from)' never reaches the terminal tier"
        }
    }
}

/// Validated, indexed access to the tier table. Constructing one guarantees the
/// merge ladder is well-formed from the tier-1 base all the way to the terminal
/// tier (god), including the career choice node.
public struct TierRepository: Sendable {
    public let types: [CharacterType]
    private let byId: [String: CharacterType]

    /// The concrete tier-1 type new games start with (bible: El Fisura).
    public let baseType: CharacterType
    /// The single concrete type with no merge target (bible: Dios, tier 30).
    public let terminalType: CharacterType
    public let maxTier: Int

    public init(types: [CharacterType]) throws {
        guard !types.isEmpty else { throw TierValidationError.empty }

        var byId: [String: CharacterType] = [:]
        for type in types {
            guard byId.updateValue(type, forKey: type.id) == nil else {
                throw TierValidationError.duplicateId(type.id)
            }
        }

        let maxTier = types.map(\.tier).max() ?? 0
        for tier in 1...maxTier where !types.contains(where: { $0.tier == tier }) {
            throw TierValidationError.missingTier(tier)
        }

        for type in types {
            let hasOptions = !(type.choiceOptions ?? []).isEmpty
            guard type.isChoiceNode == hasOptions else {
                throw TierValidationError.malformedChoiceNode(type.id)
            }
        }

        guard let base = types.first(where: { $0.tier == 1 && !$0.isChoiceNode }) else {
            throw TierValidationError.noBaseTier
        }

        let terminals = types.filter { !$0.isChoiceNode && $0.mergesInto == nil }
        guard terminals.count == 1, let terminal = terminals.first, terminal.tier == maxTier else {
            throw TierValidationError.wrongTerminalCount(terminals.map(\.id))
        }

        for type in types {
            if let target = type.mergesInto {
                guard let resolved = byId[target] else {
                    throw TierValidationError.unresolvedMergeTarget(from: type.id, target: target)
                }
                guard resolved.tier == type.tier + 1 else {
                    throw TierValidationError.nonConsecutiveMerge(from: type.id, target: target)
                }
            }
            for option in type.choiceOptions ?? [] {
                guard let resolved = byId[option] else {
                    throw TierValidationError.unresolvedChoiceOption(node: type.id, option: option)
                }
                guard resolved.tier == type.tier else {
                    throw TierValidationError.choiceOptionWrongTier(node: type.id, option: option)
                }
            }
        }

        try Self.verifyChainReachesTerminal(from: base, byId: byId, terminalId: terminal.id)

        self.types = types
        self.byId = byId
        self.baseType = base
        self.terminalType = terminal
        self.maxTier = maxTier
    }

    public func type(id: String) -> CharacterType? {
        byId[id]
    }

    /// All concrete (placeable) types, i.e. everything except abstract choice nodes.
    public var concreteTypes: [CharacterType] {
        types.filter { !$0.isChoiceNode }
    }

    /// Follows every merge path (expanding choice nodes into all their options) and
    /// requires each one to end at the terminal type.
    private static func verifyChainReachesTerminal(
        from start: CharacterType,
        byId: [String: CharacterType],
        terminalId: String
    ) throws {
        var frontier = [start.id]
        var visited: Set<String> = []
        var reachedTerminal = false

        while let currentId = frontier.popLast() {
            guard visited.insert(currentId).inserted, let current = byId[currentId] else { continue }
            if currentId == terminalId {
                reachedTerminal = true
                continue
            }
            if current.isChoiceNode {
                frontier.append(contentsOf: current.choiceOptions ?? [])
            } else if let next = current.mergesInto {
                frontier.append(next)
            } else {
                throw TierValidationError.unreachableTerminal(from: currentId)
            }
        }

        guard reachedTerminal else {
            throw TierValidationError.unreachableTerminal(from: start.id)
        }
    }
}
