import Foundation
import Testing
@testable import EconomyKit

/// La cola que hace que las celebraciones se reproduzcan de a una.
///
/// Vive en EconomyKit —y no al lado de las vistas— porque opera sobre
/// IDENTIFICADORES, sin payloads ni tipos de UI. Eso la vuelve pura y la testea
/// en milisegundos en vez de con `xcodebuild`, que es la diferencia entre pinear
/// el watchdog con deltas inyectados y esperar 8 segundos reales por caso.
@Suite("Cola de celebraciones")
struct CelebrationQueueTests {
    @Test("el primero que llega se muestra solo")
    func firstOneShowsImmediately() {
        var queue = CelebrationQueue()
        #expect(queue.current == nil)
        queue.enqueue(.skinAward)
        #expect(queue.current == .skinAward)
    }

    @Test("el segundo espera su turno en vez de pisar al primero")
    func secondOneWaits() {
        var queue = CelebrationQueue()
        queue.enqueue(.skinAward)
        queue.enqueue(.dailyReward)
        #expect(queue.current == .skinAward, "el que ya estaba en pantalla no se reemplaza")
        queue.finish(.skinAward)
        #expect(queue.current == .dailyReward)
        queue.finish(.dailyReward)
        #expect(queue.current == nil)
    }

    @Test("sale primero el de más prioridad, no el que llegó antes")
    func priorityBeatsArrival() {
        var queue = CelebrationQueue()
        queue.enqueue(.boardCelebration)   // ocupa el turno
        queue.enqueue(.towerNotice)        // prioridad 6
        queue.enqueue(.offlineEarnings)    // prioridad 1
        queue.finish(.boardCelebration)
        #expect(queue.current == .offlineEarnings, "el offline no puede quedar detrás de un toast")
    }

    @Test("a igual prioridad, el que llegó antes")
    func tiesKeepArrivalOrder() {
        var queue = CelebrationQueue()
        queue.enqueue(.boardCelebration)
        queue.enqueue(.specialDrop)        // prioridad 4
        queue.enqueue(.skinAward)          // prioridad 4
        queue.finish(.boardCelebration)
        #expect(queue.current == .specialDrop)
        queue.finish(.specialDrop)
        #expect(queue.current == .skinAward)
    }

    @Test("encolar dos veces lo mismo no lo duplica")
    func enqueueIsDeduplicated() {
        var queue = CelebrationQueue()
        queue.enqueue(.boardCelebration)
        queue.enqueue(.achievements)
        queue.enqueue(.achievements)
        queue.enqueue(.achievements)
        queue.finish(.boardCelebration)
        #expect(queue.current == .achievements)
        queue.finish(.achievements)
        #expect(queue.current == nil, "tres encolados dejaron un solo casillero")
    }

    @Test("encolar lo que ya está en pantalla no lo reencola")
    func enqueueingTheCurrentOneIsIgnored() {
        var queue = CelebrationQueue()
        queue.enqueue(.skinAward)
        queue.enqueue(.skinAward)
        queue.finish(.skinAward)
        #expect(queue.current == nil)
    }

    // MARK: Liberar la cola

    @Test("finish es idempotente")
    func finishIsIdempotent() {
        var queue = CelebrationQueue()
        queue.enqueue(.towerNotice)
        queue.enqueue(.skinAward)
        queue.finish(.towerNotice)
        queue.finish(.towerNotice)
        queue.finish(.towerNotice)
        #expect(queue.current == .skinAward, "repetir finish no puede comerse el siguiente")
    }

    /// El completion de la animación, el tap del jugador y el watchdog pueden
    /// llegar los tres por el mismo ítem. Si `finish` del que NO está en pantalla
    /// avanzara la cola, esa carrera se comería una celebración.
    @Test("finish del ítem equivocado no avanza la cola")
    func finishingSomethingElseDoesNotAdvance() {
        var queue = CelebrationQueue()
        queue.enqueue(.skinAward)
        queue.enqueue(.dailyReward)
        queue.finish(.boardCelebration)
        #expect(queue.current == .skinAward)
    }

    @Test("finish de algo que espera lo saca de la fila")
    func finishingAPendingItemRemovesIt() {
        var queue = CelebrationQueue()
        queue.enqueue(.skinAward)
        queue.enqueue(.specialDrop)
        queue.finish(.specialDrop)      // p.ej. el jugador lo cerró por otro lado
        queue.finish(.skinAward)
        #expect(queue.current == nil)
    }

    // MARK: Watchdog

    @Test("un ítem que nunca avisa lo destraba el watchdog")
    func watchdogReleasesAStuckItem() {
        var queue = CelebrationQueue()
        queue.enqueue(.boardCelebration)   // tope 8 s
        queue.enqueue(.skinAward)

        let halfway = queue.tick(4)
        #expect(halfway == nil, "a mitad de camino todavía no")
        #expect(queue.current == .boardCelebration)

        let expired = queue.tick(4.1)
        #expect(expired == .boardCelebration, "devuelve el que destrabó, para loguearlo")
        #expect(queue.current == .skinAward, "y la cola sigue")
    }

    @Test("lo que cierra el jugador no tiene tope")
    func playerDismissedItemsNeverExpire() {
        var queue = CelebrationQueue()
        queue.enqueue(.skinAward)
        for _ in 0..<200 {
            let expired = queue.tick(1)
            #expect(expired == nil)
        }
        #expect(queue.current == .skinAward, "un sheet espera lo que haga falta")
    }

    @Test("el reloj arranca de cero con cada ítem")
    func elapsedResetsPerItem() {
        var queue = CelebrationQueue()
        queue.enqueue(.towerNotice)        // tope 4 s
        queue.enqueue(.eventBanner)        // tope 6 s
        _ = queue.tick(3.9)
        queue.finish(.towerNotice)
        #expect(queue.current == .eventBanner)
        let expired = queue.tick(3.9)
        #expect(expired == nil, "el banner recién empieza, no hereda los 3,9 s")
    }

    // MARK: Saltear con un tap

    @Test("el tap no saltea antes del piso de tiempo")
    func skipRespectsTheFloor() {
        var queue = CelebrationQueue()
        queue.enqueue(.boardCelebration)
        _ = queue.tick(0.3)
        let tooEarly = queue.skip()
        #expect(tooEarly == false, "sin piso, el próximo tap del jugador lo mataría a los 0,3 s")
        #expect(queue.current == .boardCelebration)

        _ = queue.tick(0.4)
        let skipped = queue.skip()
        #expect(skipped)
        #expect(queue.current == nil)
    }

    @Test("el tap no saltea lo que cierra el jugador")
    func skipLeavesSheetsAlone() {
        var queue = CelebrationQueue()
        queue.enqueue(.skinAward)
        _ = queue.tick(5)
        let skipped = queue.skip()
        #expect(skipped == false, "un sheet tiene su botón; un tap al vacío no lo cierra")
        #expect(queue.current == .skinAward)
    }

    @Test("saltear con la cola vacía no hace nada")
    func skipOnAnEmptyQueueIsHarmless() {
        var queue = CelebrationQueue()
        let skipped = queue.skip()
        #expect(skipped == false)
    }

    // MARK: La restricción del tutorial

    @Test("con la restricción puesta, lo no permitido espera sin perderse")
    func restrictionHoldsPendingKinds() {
        var queue = CelebrationQueue()
        queue.restrict(to: [.boardCelebration])
        queue.enqueue(.dailyReward)
        #expect(queue.current == nil, "el daily no puede tomar el turno con la fase del tutorial viva")
        queue.restrict(to: nil)
        #expect(queue.current == .dailyReward, "levantar la restricción lo promueve en el acto")
    }

    @Test("lo permitido toma el turno aunque haya restricción")
    func allowedKindPromotesUnderRestriction() {
        var queue = CelebrationQueue()
        queue.restrict(to: [.boardCelebration])
        queue.enqueue(.dailyReward)
        queue.enqueue(.boardCelebration)
        #expect(queue.current == .boardCelebration, "el reveal es EL momento de la fase, no un estorbo")
        queue.finish(.boardCelebration)
        #expect(queue.current == nil, "el daily sigue esperando a que la fase termine")
    }

    @Test("al levantar la restricción, lo retenido desfila por prioridad")
    func liftingRestrictionKeepsPriorityOrder() {
        var queue = CelebrationQueue()
        queue.restrict(to: [.boardCelebration])
        queue.enqueue(.towerNotice)    // prioridad 6
        queue.enqueue(.skinAward)      // prioridad 4
        queue.enqueue(.dailyReward)    // prioridad 1
        #expect(queue.current == nil)
        queue.restrict(to: nil)
        #expect(queue.current == .dailyReward)
        queue.finish(.dailyReward)
        #expect(queue.current == .skinAward)
        queue.finish(.skinAward)
        #expect(queue.current == .towerNotice)
    }

    @Test("restringir no mata lo que ya está en pantalla")
    func restrictionLeavesCurrentAlone() {
        var queue = CelebrationQueue()
        queue.enqueue(.skinAward)
        queue.restrict(to: [.boardCelebration])
        #expect(queue.current == .skinAward, "matarlo perdería una celebración que el jugador está viendo")
        queue.finish(.skinAward)
        #expect(queue.current == nil, "y al terminar, nada no-permitido lo reemplaza")
    }

    // MARK: Invariantes del catálogo

    /// Se puede saltear exactamente lo que se cierra solo. Lo que espera al
    /// jugador tiene su propio botón, así que ni se saltea ni se vence.
    @Test("salteable y con tope son la misma lista")
    func skippableMatchesSelfClosing() {
        for kind in CelebrationKind.allCases {
            #expect(
                kind.isSkippable == (kind.timeout != nil),
                "\(kind.rawValue) rompe la invariante: se cierra solo pero no se saltea, o al revés"
            )
        }
    }

    @Test("todo ítem declara una prioridad usable")
    func everyKindHasAPriority() {
        for kind in CelebrationKind.allCases {
            #expect(kind.priority >= 1)
        }
    }
}
