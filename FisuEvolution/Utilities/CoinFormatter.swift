import Foundation

/// Abbreviates idle-scale numbers: 999 → "999", 1500 → "1,5K", 2.5e6 → "2,5M",
/// then B/T and letter pairs (1e15 → "aa", 1e18 → "ab", …). Values reach 10¹⁶⁺
/// (T30 tapYield), so raw formatting is never shown past 4 digits.
enum CoinFormatter {
    private static let suffixes: [String] = {
        var result = ["K", "M", "B", "T"]
        for first in UnicodeScalar("a").value...UnicodeScalar("e").value {
            for second in UnicodeScalar("a").value...UnicodeScalar("z").value {
                result.append(String(UnicodeScalar(first)!) + String(UnicodeScalar(second)!))
            }
        }
        return result
    }()

    static func string(from value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "∞" }
        if value < 1000 {
            return String(Int(value.rounded(.down)))
        }

        var scaled = value
        var suffixIndex = -1
        while scaled >= 1000 && suffixIndex < suffixes.count - 1 {
            scaled /= 1000
            suffixIndex += 1
        }

        let digits: Int = scaled < 100 ? 1 : 0
        let number = scaled.formatted(.number.precision(.fractionLength(0...digits)))
        return number + suffixes[suffixIndex]
    }
}
