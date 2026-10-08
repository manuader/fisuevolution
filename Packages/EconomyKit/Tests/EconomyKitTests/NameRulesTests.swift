import Foundation
import Testing
@testable import EconomyKit

@Suite("NameRules: la tabla compartida con el servidor")
struct NameRulesTests {
    struct Case: Decodable, Sendable, CustomTestStringConvertible {
        let input: String
        let expect: String
        let normalized: String?
        var testDescription: String { "\(input.debugDescription) → \(expect)" }
    }

    static let cases: [Case] = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // EconomyKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // EconomyKit
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // raíz del repo
            .appending(path: "supabase/tests/fixtures/name_rules_cases.json")
        struct File: Decodable { let cases: [Case] }
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(File.self, from: data).cases
    }()

    @Test("la tabla no está vacía") func tableLoads() { #expect(Self.cases.count >= 30) }

    @Test("cada caso da lo que dice la tabla", arguments: NameRulesTests.cases)
    func everyCase(_ c: Case) {
        switch NameRules.validate(c.input) {
        case .success(let name):
            #expect(c.expect == "ok")
            #expect(name == c.normalized)
        case .failure(let rejection):
            #expect(rejection.rawValue == c.expect)
        }
    }

    @Test("lo que deja escribir el campo siempre valida (o está vacío)",
          arguments: NameRulesTests.cases)
    func typingNeverProducesForbidden(_ c: Case) {
        let typed = NameRules.filterTyping(c.input)
        #expect(typed.count <= NameRules.maxLength)
        if case .failure(let r) = NameRules.validate(typed) { #expect(r == .empty) }
    }
}
