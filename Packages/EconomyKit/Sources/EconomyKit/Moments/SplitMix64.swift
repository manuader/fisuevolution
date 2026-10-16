import Foundation

/// Un generador con semilla (SplitMix64): la misma semilla da la misma tanda,
/// así el bandido elige igual en cada corrida de los tests. En el juego se le
/// puede pasar `SystemRandomNumberGenerator`; éste es para cuando hace falta
/// repetir.
public struct SplitMix64: RandomNumberGenerator, Sendable, Equatable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
