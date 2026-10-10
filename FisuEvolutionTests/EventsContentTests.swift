import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// Los 18 eventos del Anexo A, tal como quedaron en el dato.
@Suite("Eventos v2: el contenido real")
struct EventsContentTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    private func event(_ id: String) throws -> EventCatalog.Event {
        try #require(content.events.event(id: id))
    }

    @Test("los 18 del Anexo A: los 8 de siempre y los 10 nuevos")
    func theEighteen() {
        #expect(Set(content.events.events.map(\.id)) == [
            "plan_platita", "startup_comprada", "devaluacion", "blanqueo", "home_banking", "inversion_alienigena",
            "corralito", "aguinaldo", "campeones", "liquidacion", "feriado_puente", "lluvia_paquetes",
            "paro_general", "apagon", "hiperinflacion", "cepo", "piquete", "ola_calor",
        ])
        #expect(content.events.event(id: "cayo_mercado_pago") == nil, "la marca real se fue (guía 5.2.1)")
    }

    @Test("cada uno lo presenta quien dice el Anexo A")
    func presenters() {
        let expected: [String: String] = [
            "plan_platita": "npc_ministro", "startup_comprada": "npc_conductor", "devaluacion": "npc_ministro",
            "blanqueo": "npc_ministro", "home_banking": "npc_vendedor", "inversion_alienigena": "sp_alien_investor",
            "corralito": "npc_ministro", "aguinaldo": "npc_sindicalista", "campeones": "npc_conductor",
            "liquidacion": "npc_vendedor", "feriado_puente": "npc_sindicalista", "lluvia_paquetes": "npc_puntero",
            "paro_general": "npc_sindicalista", "apagon": "npc_vecina", "hiperinflacion": "npc_ministro",
            "cepo": "npc_ministro", "piquete": "npc_vecina", "ola_calor": "npc_vecina",
        ]
        #expect(Dictionary(uniqueKeysWithValues: content.events.events.map { ($0.id, $0.presenters.first ?? "") }) == expected)
    }

    /// La queja del dueño fue la FRECUENCIA (ContentSystemsTests de la v1): un evento
    /// cada 15–20 min, ahora de juego activo.
    @Test("la cadencia: uno cada 15 a 20 minutos de juego, el primero a los 15")
    func cadence() {
        #expect(content.events.intervalSeconds == 900)
        #expect(content.events.intervalJitterSeconds == 300)
        #expect(content.events.firstEventAfterSeconds == 900)
        #expect(content.events.retryWhenNoneApplicableSeconds == 30)
        #expect(content.events.resumeGraceSeconds == 60)
    }

    /// Los negativos son la tensión del juego: dosificar a los buenos no puede
    /// convertir la torre en un jardín (la regla de la v1 sigue).
    @Test("los malos pesan por lo menos lo que los buenos")
    func badEventsCarryAtLeastHalfTheWeight() {
        let good = content.events.events.filter { $0.polarity == .positive }.map(\.weight).reduce(0, +)
        let bad = content.events.events.filter { $0.polarity != .positive }.map(\.weight).reduce(0, +)
        #expect(bad >= good, "peso buenos \(good) vs malos \(bad)")
        #expect(good > 0)
    }

    @Test("todo negativo sale por video; el paro también con cuota; la hiperinflación saca sólo el ×2 de contratar")
    func escapes() throws {
        for event in content.events.events where event.polarity != .positive {
            #expect(event.escapes.contains { $0.kind == .video }, "\(event.id) sin salida por video")
        }
        let paro = try event("paro_general")
        #expect(paro.escapes.first { $0.kind == .fee }?.feeSeconds == 120)
        let hiper = try event("hiperinflacion")
        #expect(hiper.polarity == .mixed)
        #expect(hiper.escapes.first?.removes == [.spawnCostMultiplier])
    }

    @Test("los generosos siguen dosificados (los números de la v1)")
    func theGenerousEventsStayDialedDown() throws {
        #expect(try event("plan_platita").effects == [.modifier(effect: .incomeMultiplier, magnitude: 3)])
        #expect(try event("inversion_alienigena").effects == [.modifier(effect: .incomeMultiplier, magnitude: 5)])
        #expect(try event("aguinaldo").effects == [.coinsSeconds(300)])
        #expect(try event("blanqueo").effects == [.grantUnit(tiersBelowFrontier: 3)])
        #expect(try event("plan_platita").cooldownSeconds >= 1800)
        #expect(try event("startup_comprada").cooldownSeconds >= 2700)
        #expect(try event("inversion_alienigena").cooldownSeconds >= 7200)
        #expect(try event("aguinaldo").cooldownSeconds >= 5400)
        #expect(try event("blanqueo").cooldownSeconds >= 5400)
    }

    @Test("los efectos de §2: paro sobre el pasivo, corralito sobre el gasto, lluvia y piquete sobre los paquetes")
    func theNewEffects() throws {
        #expect(try event("paro_general").effects == [.modifier(effect: .passiveMultiplier, magnitude: 0)])
        #expect(try event("corralito").effects == [.modifier(effect: .spendingFrozen, magnitude: 1)])
        #expect(try event("lluvia_paquetes").effects == [.modifier(effect: .packageRateMultiplier, magnitude: 10)])
        #expect(try event("piquete").effects == [.modifier(effect: .packageRateMultiplier, magnitude: 0)])
        #expect(try event("hiperinflacion").effects == [
            .modifier(effect: .spawnCostMultiplier, magnitude: 2), .modifier(effect: .incomeMultiplier, magnitude: 3),
        ])
    }

    @Test("las escenas: el apagón con velitas, los campeones y la liquidación")
    func scenes() throws {
        #expect(try event("apagon").scene == .blackout)
        #expect(try event("apagon").candleStep == 0.07)
        #expect(try event("campeones").scene == .champions)
        #expect(try event("liquidacion").scene == .sale)
    }

    @Test("el cepo llama al blue del Arbolito")
    func cepoCallsTheArbolito() throws {
        #expect(try event("cepo").effects.contains(.callVisitor(script: "arbolito_blue")))
        #expect(content.visitors.script(id: "arbolito_blue")?.eventOnly == true)
    }
}
