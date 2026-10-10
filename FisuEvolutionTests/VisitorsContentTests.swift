import EconomyKit
import Foundation
import Testing
@testable import FisuEvolution

/// El elenco y los guiones de PLAN-v2 (Anexos A y B), tal como quedaron en el dato.
@Suite("Visitantes: el contenido real")
struct VisitorsContentTests {
    let content: GameContent

    init() throws {
        content = try GameContentLoader.load(from: .main)
    }

    @Test("los 18: los 8 nuevos del Anexo B y los 10 especiales")
    func theCast() {
        let npcs = ["npc_comisario", "npc_sindicalista", "npc_turista", "npc_puntero",
                    "npc_ministro", "npc_vecina", "npc_vendedor", "npc_conductor"]
        let ids = Set(content.visitors.visitors.map(\.id))
        #expect(ids == Set(npcs).union(content.specials.specials.map(\.id)))
        #expect(content.visitors.visitors.filter { $0.kind == .special }.count == 10)
    }

    @Test("los 26 guiones del Anexo A, cada uno con su visitante")
    func theScripts() {
        let expected: [String: String] = [
            "comisario_arresto": "npc_comisario", "comisario_multa": "npc_comisario",
            "arca_paraiso": "sp_demonio_arca", "arca_factura": "sp_demonio_arca",
            "influencer_novio": "sp_influencer", "influencer_codigo": "sp_influencer",
            "sindicalista_aumento": "npc_sindicalista", "sindicalista_asado": "npc_sindicalista",
            "turista_compra": "npc_turista", "turista_propina": "npc_turista",
            "puntero_acto": "npc_puntero", "puntero_bolson": "npc_puntero",
            "ministro_subsidio": "npc_ministro",
            "vecina_chisme": "npc_vecina", "vecina_favor": "npc_vecina",
            "vendedor_ofertas": "npc_vendedor",
            "conductor_ruleta": "npc_conductor",
            "cryptobro_senal": "sp_cryptobro", "contador_credito": "sp_contador_dios",
            "zombie_reto": "sp_zombie_ceo", "lizard_lengua": "sp_lizard",
            "alien_inversion": "sp_alien_investor", "bug_reinicio": "sp_bug_simulacion",
            "arbolito_cambio": "sp_arbolito", "arbolito_blue": "sp_arbolito",
            "coach_reto": "sp_coach",
        ]
        #expect(Dictionary(uniqueKeysWithValues: content.visitors.scripts.map { ($0.id, $0.visitor) }) == expected)
    }

    @Test("los números del Anexo A")
    func annexValues() throws {
        func mechanic(_ id: String) throws -> VisitorsConfig.Mechanic {
            try #require(content.visitors.script(id: id)).mechanic
        }
        #expect(try mechanic("comisario_arresto") == .arrest(pick: .lowestDuplicate, bailMultiplier: 1, releaseMultiplier: 2))
        #expect(try mechanic("arca_paraiso") == .arrest(pick: .highestDuplicate, bailMultiplier: 1, releaseMultiplier: 2))
        #expect(try mechanic("comisario_multa") == .fine(
            seconds: 180, capFraction: 0.08, stamp: .modifier(effect: .incomeMultiplier, magnitude: 1.25, seconds: 180)
        ))
        #expect(try mechanic("turista_propina") == .gift(rewards: [.coinsSeconds(900)], videoDoubles: true))
        #expect(try mechanic("turista_compra") == .sale(pick: .highestDuplicate, priceMultiplier: 4, tiersBelowFrontier: 2))
        #expect(try mechanic("puntero_acto") == .take(
            pick: .lowestDuplicate, count: 3, rewards: [.package(1), .coinsSeconds(600)], minValueMultiplier: 1.5
        ))
        #expect(try mechanic("arbolito_cambio") == .exchange(costSeconds: 5400, oro: 1, dailyOroCap: 3))
        #expect(try mechanic("arbolito_blue") == .exchange(costSeconds: 3600, oro: 1, dailyOroCap: nil))
        #expect(content.visitors.script(id: "arbolito_blue")?.eventOnly == true)
        #expect(try mechanic("vecina_favor") == .challenge(taps: 15, windowSeconds: 20, rewards: [.package(1)], videoDoubles: true))
        #expect(try mechanic("zombie_reto") == .challenge(
            taps: 40, windowSeconds: 30, rewards: [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 90)], videoDoubles: false
        ))
        #expect(try mechanic("coach_reto") == .challenge(
            taps: 67, windowSeconds: 30, rewards: [.modifier(effect: .incomeMultiplier, magnitude: 2, seconds: 120)], videoDoubles: false
        ))
        guard case .vendor(let cards) = try mechanic("vendedor_ofertas") else {
            Issue.record("el Vendedor no vende")
            return
        }
        #expect(cards.map(\.id) == ["mate", "cafe", "turbo"])
        #expect(content.visitors.script(id: "vendedor_ofertas")?.lane == .vendor)
    }

    @Test("los relojes de PLAN-v2: primera a los 600 s, después cada 240–360, el vendedor cada ~180, paciencia de 30")
    func theClocks() {
        let visitors = content.visitors
        #expect(visitors.firstVisitAfterSeconds == 600)
        #expect(visitors.intervalMinSeconds == 240 && visitors.intervalMaxSeconds == 360)
        #expect(visitors.vendorIntervalSeconds == 180)
        #expect(visitors.patienceSeconds == 30)
        #expect(visitors.coinsSecondsScale > 0 && visitors.coinsSecondsScale <= 1, "E2b la baja con el presupuesto (EngagementBudgetTests)")
    }

    @Test("todo texto recibe los datos que pide", arguments: ["es", "en"])
    func everyTextGetsItsArguments(language: String) throws {
        let catalog = try LocalizationCompletenessTests.catalog("Localizable")
        for script in content.visitors.scripts {
            let available = VisitCopy.argumentCount(for: script)
            for key in [script.bubbleKey, script.askKey] {
                let value = try #require(catalog.strings[key]?.localizations?[language]?.units.first?.value, "falta \(key) en \(language)")
                let wanted = Self.highestPlaceholder(in: value)
                #expect(wanted <= available, "\(key) [\(language)] pide %\(wanted)$@ y el guion da \(available)")
            }
        }
    }

    @Test("el globo del arresto nombra al empleado y un motivo de su piso")
    func arrestBubbleNamesTheWorker() throws {
        let script = try #require(content.visitors.script(id: "comisario_arresto"))
        let cartonero = try #require(content.tiers.type(id: "cartonero"))
        let offer = VisitOffer(scriptId: script.id, visitorId: script.visitor, subjectTypeId: cartonero.id, options: [])
        let bubble = VisitCopy.bubble(for: script, offer: offer, content: content)
        #expect(bubble.contains(cartonero.localizedName))
        #expect(bubble.contains(VisitCopy.text(VisitCopy.reasonKey(floorID: "alley"))))
        #expect(!bubble.contains("%"))
    }

    @Test("los textos interpolan el dato, no lo escriben")
    func textsInterpolateData() throws {
        let codigo = try #require(content.visitors.script(id: "influencer_codigo"))
        let offer = VisitOffer(scriptId: codigo.id, visitorId: codigo.visitor, subjectTypeId: nil, options: [])
        #expect(VisitCopy.bubble(for: codigo, offer: offer, content: content).contains(VisitCopy.effectText(.spawnCostMultiplier, magnitude: 0.7)))
        let coach = try #require(content.visitors.script(id: "coach_reto"))
        let coachAsk = VisitCopy.ask(for: coach, offer: VisitOffer(scriptId: coach.id, visitorId: coach.visitor, subjectTypeId: nil, options: []),
                                     content: content)
        #expect(coachAsk.contains("67"))
        #expect(coachAsk.contains(VisitCopy.durationText(120)))
        #expect(VisitCopy.durationText(90) == String(localized: "ads.duration.sec \(String(90))"))
        #expect(VisitCopy.durationText(600) == String(localized: "ads.duration.min \(String(10))"))
    }

    /// El `%N$@` más alto de un texto; un `%@` suelto cuenta como el primero.
    static func highestPlaceholder(in text: String) -> Int {
        let positional = text.matches(of: /%(\d+)\$@/).compactMap { Int($0.1) }.max() ?? 0
        return max(positional, text.contains("%@") ? 1 : 0)
    }
}
