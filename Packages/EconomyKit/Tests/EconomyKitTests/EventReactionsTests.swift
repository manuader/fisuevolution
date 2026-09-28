import Foundation
import Testing
@testable import EconomyKit

@Suite("Reacciones de campo: la tabla y quién reacciona")
struct EventReactionsTests {
    private func table() -> EventReactionsConfig {
        EventReactionsConfig(reactions: [
            "devaluacion": [
                "homeless": .seAgarraLaCabeza,
                "cartonero": .indiferente,
                "fondo_buitre": .festeja,
            ],
            "blanqueo": [
                "homeless": .indiferente,
                "cartonero": .indiferente,
                "fondo_buitre": .sonrisaTorcida,
            ],
        ])
    }

    private let events: Set<String> = ["devaluacion", "blanqueo"]
    private let types: Set<String> = ["homeless", "cartonero", "fondo_buitre"]

    // MARK: La tabla

    @Test("decodifica el formato del JSON, y lo que no dice es indiferente")
    func decodesAndDefaultsToIndifferent() throws {
        let json = #"""
        {"schemaVersion": 1,
         "reactions": {"devaluacion": {"homeless": "se_agarra_la_cabeza", "fondo_buitre": "festeja"}}}
        """#
        let config = try JSONDecoder().decode(EventReactionsConfig.self, from: Data(json.utf8))
        #expect(config.emote(eventId: "devaluacion", typeId: "homeless") == .seAgarraLaCabeza)
        #expect(config.emote(eventId: "devaluacion", typeId: "cartonero") == .indiferente)
        #expect(config.emote(eventId: "no_existe", typeId: "homeless") == .indiferente)
    }

    @Test("un emote que no está en el vocabulario no decodifica")
    func unknownEmoteIsRejected() {
        let json = #"{"schemaVersion": 1, "reactions": {"devaluacion": {"homeless": "baila"}}}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(EventReactionsConfig.self, from: Data(json.utf8))
        }
    }

    @Test("la tabla completa valida")
    func completeTableValidates() throws {
        try table().validate(eventIDs: events, typeIDs: types)
    }

    @Test("un evento nuevo sin regenerar la tabla frena el arranque")
    func missingEventIsRejected() {
        #expect(throws: EventReactionsValidationError.missingEvent("corralito")) {
            try table().validate(eventIDs: events.union(["corralito"]), typeIDs: types)
        }
    }

    @Test("una fila de un evento borrado también")
    func orphanEventIsRejected() {
        #expect(throws: EventReactionsValidationError.unknownEvent("devaluacion")) {
            try table().validate(eventIDs: ["blanqueo"], typeIDs: types)
        }
    }

    @Test("un tier nuevo sin su reacción frena el arranque")
    func missingTypeIsRejected() {
        #expect(throws: EventReactionsValidationError.missingType(eventId: "blanqueo", typeId: "mantero")) {
            try table().validate(eventIDs: events, typeIDs: types.union(["mantero"]))
        }
    }

    @Test("y una reacción de un tier borrado también")
    func orphanTypeIsRejected() {
        #expect(throws: EventReactionsValidationError.unknownType(eventId: "blanqueo", typeId: "fondo_buitre")) {
            try table().validate(eventIDs: events, typeIDs: ["homeless", "cartonero"])
        }
    }

    // MARK: Quién reacciona

    @Test("los indiferentes no aparecen en el plan")
    func indifferentUnitsAreSilent() {
        let plan = EventReactionPlanner.plan(
            eventId: "devaluacion",
            onField: [(0, "homeless"), (1, "cartonero"), (2, "fondo_buitre")],
            excluded: [], config: table()
        )
        #expect(plan.map(\.slot) == [0, 2])
        #expect(plan.map(\.emote) == [.seAgarraLaCabeza, .festeja])
    }

    @Test("lo que otro gesto tiene tomado no reacciona")
    func excludedSlotsAreSkipped() {
        let plan = EventReactionPlanner.plan(
            eventId: "devaluacion",
            onField: [(0, "homeless"), (2, "fondo_buitre")],
            excluded: [0], config: table()
        )
        #expect(plan.map(\.slot) == [2])
    }

    @Test("una tabla habladora no llena el campo: tope, en orden de slot")
    func capLimitsReactors() {
        let field = (0..<10).map { (slot: $0, typeId: "fondo_buitre") }
        let plan = EventReactionPlanner.plan(eventId: "devaluacion", onField: Array(field.reversed()), excluded: [], config: table())
        #expect(plan.map(\.slot) == [0, 1, 2, 3])
        #expect(EventReactionPlanner.plan(eventId: "devaluacion", onField: field, excluded: [], config: table(), cap: 0).isEmpty)
    }

    @Test("el mismo campo reacciona igual cada vez, escalonado dentro del máximo")
    func planIsDeterministicAndStaggered() {
        let field = (0..<10).map { (slot: $0, typeId: "fondo_buitre") }
        let first = EventReactionPlanner.plan(eventId: "devaluacion", onField: field, excluded: [], config: table(), cap: 10)
        let second = EventReactionPlanner.plan(eventId: "devaluacion", onField: field, excluded: [], config: table(), cap: 10)
        #expect(first == second)
        #expect(first.allSatisfy { $0.delay >= 0 && $0.delay <= EventReactionPlanner.maxStagger })
        // Sin escalonado, todos arrancarían en el mismo frame.
        #expect(Set(first.map(\.delay)).count > 5)
    }

    @Test("sin evento conocido o sin campo, nadie reacciona")
    func nothingToReactTo() {
        #expect(EventReactionPlanner.plan(eventId: "no_existe", onField: [(0, "homeless")], excluded: [], config: table()).isEmpty)
        #expect(EventReactionPlanner.plan(eventId: "devaluacion", onField: [], excluded: [], config: table()).isEmpty)
    }
}
