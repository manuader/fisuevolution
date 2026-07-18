import Foundation

/// Typed domain errors. Every error is logged and surfaced with a friendly,
/// localized message — the game never crashes on bad content or a bad save.
enum GameError: Error, LocalizedError {
    case contentFileMissing(String)
    case contentInvalid(file: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .contentFileMissing, .contentInvalid:
            String(localized: "error.content.message")
        }
    }

    /// Precise technical detail for logs (never shown to the player).
    var debugDetail: String {
        switch self {
        case .contentFileMissing(let file):
            "bundled content file missing: \(file)"
        case .contentInvalid(let file, let reason):
            "invalid content in \(file): \(reason)"
        }
    }
}
