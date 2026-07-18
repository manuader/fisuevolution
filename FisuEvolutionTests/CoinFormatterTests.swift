import Foundation
import Testing
@testable import FisuEvolution

@Suite("CoinFormatter")
struct CoinFormatterTests {
    private func plain(_ value: Double) -> String {
        // Normaliza el separador decimal del locale para comparar estable.
        CoinFormatter.string(from: value).replacingOccurrences(of: ",", with: ".")
    }

    @Test func smallValuesAreRaw() {
        #expect(plain(0) == "0")
        #expect(plain(15) == "15")
        #expect(plain(999) == "999")
        #expect(plain(999.9) == "999")
    }

    @Test func thousandsAndMillions() {
        #expect(plain(1000) == "1K")
        #expect(plain(1500) == "1.5K")
        #expect(plain(19_837.5) == "19.8K")
        #expect(plain(2_500_000) == "2.5M")
        #expect(plain(999_000_000_000) == "999B")
    }

    @Test func trillionsThenLetterPairs() {
        #expect(plain(1e12) == "1T")
        #expect(plain(1e15) == "1aa")
        #expect(plain(1e18) == "1ab")
        #expect(plain(6.5121e16) == "65.1aa")
    }

    @Test func hundredsScaleDropsDecimals() {
        #expect(plain(123_456) == "123K")
        #expect(plain(987_654_321) == "988M")
    }

    @Test func pathologicalInputsNeverCrash() {
        #expect(plain(.infinity) == "∞")
        #expect(plain(-5) == "∞")
        #expect(!plain(.greatestFiniteMagnitude).isEmpty)
    }
}
