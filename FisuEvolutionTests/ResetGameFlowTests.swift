import Testing
@testable import FisuEvolution

@Suite("El reset en tres pasos")
@MainActor
struct ResetGameFlowTests {
    typealias Flow = ResetGameFlowView

    @Test("se acepta la palabra del idioma, sin importar mayúsculas ni espacios")
    func wordMatches() {
        #expect(Flow.matchesWord("RESETEAR", word: "RESETEAR"))
        #expect(Flow.matchesWord("  reseteár ", word: "RESETEAR") == false, "con tilde no es la palabra")
        #expect(Flow.matchesWord(" reset ", word: "RESET"))
        #expect(!Flow.matchesWord("RESE", word: "RESET"))
        #expect(!Flow.matchesWord("", word: "RESET"))
    }

    @Test("sin la casilla no se pasa del resumen, y con ella sí")
    func summaryNeedsTheCheckbox() {
        #expect(!Flow.canAdvance(from: .summary, understood: false, typed: "RESET", word: "RESET"))
        #expect(Flow.canAdvance(from: .summary, understood: true, typed: "", word: "RESET"))
    }

    @Test("sin la palabra no se pasa del segundo paso, y con ella sí")
    func wordStepNeedsTheWord() {
        #expect(!Flow.canAdvance(from: .word, understood: true, typed: "RESE", word: "RESET"))
        #expect(!Flow.canAdvance(from: .word, understood: true, typed: "", word: "RESET"))
        #expect(Flow.canAdvance(from: .word, understood: false, typed: "reset", word: "RESET"))
    }

    @Test("el tercer paso no avanza con un toque: sólo el mantener ejecuta")
    func holdStepHasNoNext() {
        #expect(!Flow.canAdvance(from: .hold, understood: true, typed: "RESET", word: "RESET"))
    }

    @Test("sólo .done cierra; .stale re-arma el plan; los fallos muestran su aviso y no cierran")
    func outcomesMapToReactions() {
        #expect(Flow.reaction(to: .done) == .leave)
        #expect(Flow.reaction(to: .stale) == .rearm)
        #expect(Flow.reaction(to: .noBackup) == .show(.noBackup))
        #expect(Flow.reaction(to: .writeFailed) == .show(.writeFailed))
    }
}
