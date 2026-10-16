import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// C4 y el gate G2: la compuerta abre sólo con todo en orden; cada insumo dudoso cierra y deja `base`.
@Suite("Personalización: la compuerta")
struct PersonalizationGateTests {
    /// Todo en orden: un build de release, sin UI test, con interruptor y consentimiento.
    private func open(
        remoteEnabled: Bool = true,
        consentAllows: Bool = true,
        underAgeSignal: Bool = false,
        arguments: [String] = [],
        isDebug: Bool = false
    ) -> PersonalizationGate {
        PersonalizationGate(
            remoteEnabled: remoteEnabled, consentAllows: consentAllows, underAgeSignal: underAgeSignal,
            arguments: arguments, isDebug: isDebug
        )
    }

    @Test("con todo en orden abre y deja pasar el segmento de las reglas")
    func everythingInOrderOpens() {
        let gate = open()
        #expect(gate.isOpen)
        #expect(gate.segment(ruled: .high) == .high)
        #expect(gate.segment(ruled: .low) == .low)
    }

    @Test("cada insumo dudoso cierra: base (G2)")
    func eachDoubtfulInputCloses() {
        let closed = [
            open(remoteEnabled: false),
            open(consentAllows: false),
            open(underAgeSignal: true),
            open(arguments: ["--uitest-reset"]),
            open(arguments: ["--uitest-skip-tutorial"]),
            open(isDebug: true),
        ]
        for gate in closed {
            #expect(!gate.isOpen)
            #expect(gate.segment(ruled: .high) == .base)
        }
    }

    @Test("sin segmento calculado todavía: base, aunque esté abierta")
    func noRuledSegmentIsBase() {
        #expect(open().segment(ruled: nil) == .base)
    }

    @Test("DEBUG abre sólo con --personalization-debug")
    func debugNeedsOverride() {
        #expect(!open(isDebug: true).isOpen)
        #expect(open(arguments: ["--personalization-debug"], isDebug: true).isOpen)
        #expect(!open(remoteEnabled: false, arguments: ["--personalization-debug"], isDebug: true).isOpen)
    }

    @Test("--personalization-debug no salta el consentimiento ni la señal de menor")
    func debugOverrideKeepsTheRest() {
        #expect(!open(consentAllows: false, arguments: ["--personalization-debug"], isDebug: true).isOpen)
        #expect(!open(underAgeSignal: true, arguments: ["--personalization-debug"], isDebug: true).isOpen)
    }

    @Test("--uitest-segment high fuerza high y saltea todo lo demás")
    func uitestSegmentForces() {
        let gate = open(
            remoteEnabled: false, consentAllows: false, underAgeSignal: true,
            arguments: ["--uitest-reset", "--uitest-segment", "high"], isDebug: true
        )
        #expect(gate.forcedSegment == .high)
        #expect(gate.segment(ruled: .low) == .high)
        #expect(gate.segment(ruled: nil) == .high)
    }

    @Test("--uitest-segment con un valor raro o sin valor: base")
    func uitestSegmentGarbageIsBase() {
        for arguments in [["--uitest-segment", "vip"], ["--uitest-segment"], ["--uitest-segment", "--uitest-reset"]] {
            #expect(open(arguments: arguments).segment(ruled: .high) == .base)
        }
    }

    @Test("--uitest-reset sin el flag del segmento: base")
    func uitestResetWithoutFlagIsBase() {
        let gate = open(arguments: ["--uitest-reset"])
        #expect(gate.forcedSegment == nil)
        #expect(gate.segment(ruled: .mid) == .base)
    }

    @Test("la señal de menor (V10): cualquier etiqueta en true la prende; sin etiquetas, no")
    func underAgeSignalFromTags() {
        #expect(!PersonalizationGate.underAgeSignal(tagForUnderAgeOfConsent: nil, tagForChildDirectedTreatment: nil))
        #expect(!PersonalizationGate.underAgeSignal(tagForUnderAgeOfConsent: false, tagForChildDirectedTreatment: false))
        #expect(PersonalizationGate.underAgeSignal(tagForUnderAgeOfConsent: true, tagForChildDirectedTreatment: nil))
        #expect(PersonalizationGate.underAgeSignal(tagForUnderAgeOfConsent: nil, tagForChildDirectedTreatment: true))
    }
}
