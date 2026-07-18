import Foundation

/// Result of attempting to merge two board units (bible §2.3 rule 2).
public enum MergeOutcome: Equatable, Sendable {
    /// Same type, next tier resolved — replace the pair with `newTypeId`.
    case merged(newTypeId: String)
    /// The merge hits the career choice node (T8+T8) and no career is chosen yet.
    /// UI must present the options and re-run the merge after the choice.
    case requiresCareerChoice(options: [String])
    /// Different types, terminal tier, or unresolvable target.
    case invalid
}

/// Pure merge evaluation. The career path is stored as the option id's suffix
/// after its first underscore (`junior_programmer` → `programmer`), which also
/// matches the senior variant (`senior_programmer`).
public enum MergeRules {
    public static func evaluate(
        sourceTypeId: String,
        targetTypeId: String,
        chosenCareerPath: String?,
        tiers: TierRepository
    ) -> MergeOutcome {
        guard sourceTypeId == targetTypeId,
              let type = tiers.type(id: sourceTypeId),
              let nextId = type.mergesInto,
              let next = tiers.type(id: nextId)
        else { return .invalid }

        guard next.isChoiceNode else {
            return .merged(newTypeId: nextId)
        }

        guard let options = next.choiceOptions, !options.isEmpty else { return .invalid }
        if let career = chosenCareerPath,
           let match = options.first(where: { $0.hasSuffix(career) }) {
            return .merged(newTypeId: match)
        }
        return .requiresCareerChoice(options: options)
    }

    /// Career suffix derived from a chosen option id: `junior_programmer` → `programmer`.
    public static func careerPath(fromOptionId optionId: String) -> String {
        let parts = optionId.split(separator: "_").dropFirst()
        return parts.isEmpty ? optionId : parts.joined(separator: "_")
    }
}
