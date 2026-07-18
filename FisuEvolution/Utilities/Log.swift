import Foundation
import os

/// One `Logger` per subsystem. `print()` is banned in this codebase.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.manuader.fisuevolution"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let board = Logger(subsystem: subsystem, category: "board")
    static let economy = Logger(subsystem: subsystem, category: "economy")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let assets = Logger(subsystem: subsystem, category: "assets")
}
